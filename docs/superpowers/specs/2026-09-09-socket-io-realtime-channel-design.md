# Thiết kế: kênh thời gian thực Socket.io phía client

**Ngày:** 2026-09-09 · **Soát lại:** 2026-09-11 (sau khi gộp `main` @ `cc65f4f`) · **Nhánh:** `TranQuangDat` · **Phạm vi:** chỉ `src/Client-app`

> Tệp này nằm trong `docs/superpowers/specs/`, **bị `.gitignore` chặn** (dòng 67)
> nên không commit được — đúng như mọi spec khác của dự án. Bản tóm tắt đi vào
> git nằm ở `docs/PROJECT_CONTEXT.md` mục 14 và ở hai tệp `SOCKET_*` (nay ở
> `docs/superpowers/backend/DA-XONG/`).

> 🛑 **2026-09-18 — `bank_transaction.incoming` KHÔNG CÒN ĐƯỢC CLIENT DỊCH.**
> Nhóm bỏ tính năng liên kết ngân hàng, và client gỡ phần của mình cùng ngày.
> `RealtimeEvent` nay có **ba** giá trị (`ocrXong`, `ocrTrung`, `dongBoXong`) chứ
> không bốn, dòng `giaoDichNganHang` ở bảng mục 3 và ở đoạn mã mục 3 là **ảnh
> chụp**, và toast *"Vừa có giao dịch mới từ ngân hàng"* không còn. Backend **vẫn
> phát** sự kiện ấy, nên nó rơi vào nhánh `null` sẵn có cho mọi tên lạ — đúng cơ
> chế mà mục 2 thiết kế ra. ⚠️ **Cam kết "payload là hộp đen" GIỮ NGUYÊN**, dù ví
> dụ nêu ở mục 1 điểm 3 (phát từ hai đường với hai hình dạng) không còn kiểm
> chứng được: một tên sự kiện đi qua EventBus vẫn không bảo đảm một hình dạng
> payload. Việc số 2 ở mục 8 ("thống nhất một hình dạng payload cho
> `bank_transaction.incoming`") **bỏ theo** — đừng viết tài liệu xin backend cho
> nó. Xem khối "🏦 Gỡ phần client của liên kết ngân hàng" mục 14
> `docs/PROJECT_CONTEXT.md`.

> ✅ **2026-09-12:** kênh **nối được** sau gộp `main` @ `cbbeeb4` — máy ảo `[RealtimeChannel] Đã nối
> (idaccount=11)` sau 51 lần bị từ chối, nối lại sau 2 giây khi mạng về; `bank_transaction.incoming`
> chỉ còn **một** chỗ phát (18 §2.5 xong). G34 ✅ **đóng tối cùng ngày**: `sync.completed` →
> `RealtimeEvent.dongBoXong`, đánh thức `syncNow()`, **không toast** (lý do ở mục 4); kiểm máy ảo hai máy
> cùng tài khoản — máy kia kéo về **cùng giây** backend phát (khối "Nghe `sync.completed`" mục 14
> `docs/PROJECT_CONTEXT.md`).
>
> ⚠️ **Đo lại 2026-09-11.** Phát hiện (3) ở mục 1 **vẫn đúng**, và từ `7675b35`
> mỗi giao dịch ngân hàng còn phát **hai lần**. Phát hiện (4) **đã hết**: backend
> phát `sync.completed` sau mỗi `/sync/push`. Nhưng hôm nay kênh không nối được —
> bắt tay socket từ chối **mọi** tài khoản (CAN-LAM 17 A) — và client **chưa nghe**
> `sync.completed` (**G34** `docs/CLIENT_APP_KNOWN_GAPS.md`). Chi tiết ở từng chỗ
> đánh dấu 2026-09-11 bên dưới.

---

## 1. Vấn đề

Backend đã có Socket.io từ lâu (`src/Backend/core/socket.js`), client thì
**chưa có gói `socket_io_client`** và không dòng nào trong `lib/` nối tới. Đây là
mục 4 và mục 8 của `docs/progress/Client-app.md`, và là hạng mục cuối cùng còn
lại trong thứ tự đã duyệt.

Nhưng đọc kỹ hai phía thì hạng mục này **không phải như tài liệu mô tả**. Bốn
điều đo được ngày 2026-09-09, bằng cách mở mã nguồn chứ không đọc tài liệu:

1. **Server phát ba sự kiện tới người dùng thường**, không phải bốn:
   `bank_transaction.incoming`, `ocr.completed`, `ocr.duplicate` — tất cả tới
   room `account_<idaccount>`. Sự kiện thứ tư trong bảng ở mục 8
   `docs/progress/Client-app.md`, **`notification.new`, không tồn tại**: không
   dòng nào phát nó. (`audit_activity` có thật nhưng chỉ tới `admin_room`, tức
   dành cho Admin-web.)

2. **Cả ba đều thuộc tính năng client chưa có.** Client không có liên kết ngân
   hàng, không có OCR, không có màn duyệt giao dịch chờ. Các cột `status`,
   `provider`, `bank_tran_id` tồn tại trong SQLite nhưng **không nằm trong hợp
   đồng đồng bộ theo chiều nào** (quy tắc 4 `CLAUDE.md`).

3. **`bank_transaction.incoming` được phát từ hai đường với hai hình dạng
   payload khác nhau.** `workers/bank.worker.js` gửi snake_case
   (`date_transaction`, `account_number`, `gateway`, `suggested_category`);
   `modules/notification/notification.service.js` gửi camelCase kèm hai trường
   hiển thị (`bankName`, `accountNumber`, `createdAt`, `title`, `message`).
   Cùng một tên sự kiện. Đây đúng loại lỗi mà quy tắc 4 cảnh báo: sai tên trường
   thì **im lặng**, không báo lỗi.
   ⚠️ *2026-09-11:* vẫn hai hình dạng, và từ `7675b35` **phát hai lần** mỗi giao
   dịch — `bank.worker.js` gọi thẳng `emitBankTransaction` rồi publish
   `bank_transaction.pending` để `notification.service.js` phát lại (mục 2.5
   `docs/superpowers/backend/CAN-LAM/VERIFY_7675B35_REMAINING.md`). Client chỉ đọc
   tên sự kiện nên nhận hai lần kích hoạt cho một giao dịch.

4. **Không có sự kiện nào cho "máy khác vừa đổi dữ liệu".** `sync.completed`
   chỉ được `publish` vào EventBus nội bộ của backend
   (`modules/sync/sync.service.js`), không ai bắc nó ra socket. Đây mới là chỗ
   thời gian thực có giá trị thật với một app offline-first đa thiết bị — và nó
   cần backend làm.
   ✅ *2026-09-11:* backend đã làm — `sync.service.js:223` publish,
   `notification.service.js:79-90` nghe và `core/socket.js:203-215` phát
   `sync.completed` (payload `{summary, timestamp}`) tới `account_<idaccount>`.
   Tới được client từ 2026-09-12 (17 A đóng, kênh nối); ✅ client nghe từ **tối
   cùng ngày** (**G34** đóng) — im lặng, chỉ kéo về.

Vì (2) và (4), hạng mục này **tự nó không tạo ra giá trị nhìn thấy được** trừ
khi hạ thấp kỳ vọng cho đúng: xây **hạ tầng đúng** và **một hiệu ứng nhỏ nhìn
thấy được**, rồi xin backend phần còn lại.

## 2. Phạm vi đã chốt với người dùng

**Làm:** kênh socket có xác thực JWT, vòng đời gắn với phiên đăng nhập, tự nối
lại; mọi sự kiện nhận được đều **đánh thức đồng bộ**; và một **toast nổi** báo
cho người dùng biết vừa có gì đó xảy ra.

**Không làm (đã cân nhắc và loại):**

- **Ghi sự kiện vào bảng `AppNotifications`.** Bảng ấy cố ý là dữ liệu **suy ra
  được** từ ngân sách/hoá đơn/mục tiêu trên từng máy — việc nó vắng
  `syncStatus`/`isDeleted` chính là tài liệu sống nói điều đó (quy tắc 9
  `CLAUDE.md`). Thông báo đến từ server là loại **không suy lại được**, nên nhét
  vào đây là phá đúng bất biến ấy để đổi lấy một dòng trong trung tâm thông báo.
  Không đáng.
- **Màn "Giao dịch chờ duyệt".** Backend đã có sẵn `pending-transactions`,
  `confirm-transaction`, `reject-transaction`, nhưng đó là **một tính năng
  mới**, không phải "nối socket". Ghi vào `docs/CLIENT_APP_KNOWN_GAPS.md` để làm
  sau, và theo nếp dự án thì phải lên Stitch trước.
- **Bắt sẵn `sync.completed` / `notification.new`.** Không tồn tại ở server thì
  không có gì để kiểm chứng; một nhánh mã không bao giờ chạy tới còn tệ hơn là
  không có. Khi backend làm xong, việc thêm là **một dòng** trong bảng ánh xạ ở
  mục 4 dưới đây. ⚠️ *2026-09-11:* `sync.completed` nay **có** ở server
  (`notification.new` thì vẫn không); dòng ánh xạ cho nó ✅ thêm tối 2026-09-12 — **G34** đóng.

---

## 3. Kiến trúc

### 3.1 `RealtimeChannel` là một lớp riêng

Tệp mới `lib/core/realtime/realtime_channel.dart`. Giao diện công khai gọn
đúng ba thứ:

```dart
Future<void> start({required int idaccount});
Future<void> stop();
Stream<RealtimeEvent> get events;
```

**Vì sao không nhét vào `SyncEngine`:** cùng lý lẽ đã ghi trong
`lib/core/network/connection_monitor.dart` khi tách bộ theo dõi kết nối ra khỏi
`SyncEngine` — hai câu hỏi khác nhau. `SyncEngine` trả lời *khi nào thì đồng
bộ*; `RealtimeChannel` chỉ thuật lại *server vừa nói gì*. Trộn vào một chỗ thì
một trong hai phải chịu thiệt. Thêm nữa `sync_engine.dart` đã hơn 1.600 dòng;
không nên bồi thêm.

`RealtimeChannel` **không tự gọi** `SyncEngine`. Nó chỉ phát ra `events`; việc
nối `events` vào `syncNow()` và vào toast do lớp trên làm (DI + `main.dart`).
Nhờ vậy nó test được mà không cần dựng cả `SyncEngine`.

### 3.2 Vòng đời bám đúng `NotificationScanner`

Cả hai đường vào và cả hai đường ra đều **đã có sẵn** trong
`lib/features/auth/presentation/bloc/auth_bloc.dart`:

| Chỗ | Việc thêm |
|---|---|
| `_onLoginSubmitted` | `start()` cạnh `NotificationScanner.start(idAcc)` |
| `_onAuthCheckRequested` | `start()` cạnh `NotificationScanner.start(idAcc)` |
| `_onLogoutRequested` | `stop()` cạnh `NotificationScanner.stop()` |
| `_onSessionInvalidated` | `stop()` cạnh `NotificationScanner.stop()` |

Mọi lời gọi bọc `sl.isRegistered<RealtimeChannel>()` như ba lớp kia, để bộ test
nào không đăng ký nó vẫn chạy được. Đăng ký lazy singleton trong
`lib/core/di/injection_container.dart`.

**Sót một đường ra là lỗi bảo mật, không phải lỗi giao diện:** socket còn sống
sau khi đăng xuất nghĩa là máy vẫn nằm trong room của người vừa rời đi. Cùng
loại với bài học `NotificationScanner.stop()` phải gọi `cancelAll()`.

---

## 4. Hợp đồng sự kiện: payload là hộp đen

**Client không đọc một trường nào trong payload.** Đây là quyết định trung tâm
của thiết kế này.

Lý do là phát hiện (3) ở mục 1: cùng tên sự kiện, hai hình dạng payload. Nếu
client đọc `data['bankName']` thì nửa số sự kiện cho `null` — và theo quy tắc 4
thì nó **im lặng**, không có exception, không có log. Chọn không đọc gì cả thì
cái bẫy ấy **không còn tồn tại**.

Cụ thể: chữ hiện ra là **hằng số tiếng Việt do client chọn**, còn dữ liệu thật
đi đường `/sync/pull` như mọi khi. Điều này cũng khớp sẵn với nếp đã có của dự
án — thông báo tạm thời nói đủ ý, không nêu số liệu.

```dart
enum RealtimeEvent { giaoDichNganHang, ocrXong, ocrTrung, dongBoXong }
// dongBoXong thêm 2026-09-12 (G34); loiNhan của nó là null = im lặng
// ⚠️ 2026-09-18: giaoDichNganHang ĐÃ BỎ — enum nay còn ba giá trị
```

| Tên sự kiện server | `RealtimeEvent` | Đánh thức đồng bộ | Toast |
|---|---|---|---|
| ~~`bank_transaction.incoming`~~ | ~~`giaoDichNganHang`~~ | — | 🛑 **bỏ 2026-09-18** — client thôi dịch tên này, nó rơi vào nhánh `null` như mọi tên lạ |
| `ocr.completed` | `ocrXong` | ✅ | xanh — *"Đã bóc tách xong hoá đơn"* |
| `ocr.duplicate` | `ocrTrung` | ❌ | hổ phách — *"Hoá đơn này đã được ghi nhận trước đó"* |
| `sync.completed` *(2026-09-12)* | `dongBoXong` | ✅ | ❌ **im lặng** — `loiNhan == null` |
| bất kỳ tên nào khác | *(bỏ qua)* | ❌ | ❌ |

`ocr.duplicate` **không** gọi `syncNow()` vì đúng nghĩa của nó là *không có gì
mới được tạo*. Đồng bộ ở đó là một vòng mạng thừa.

Tên lạ thì bỏ qua và ghi log — backend thêm sự kiện mới sẽ không làm client vỡ.

**Vì sao `sync.completed` im lặng** (2026-09-12, G34): backend phát tới **mọi**
socket trong phòng, kể cả máy vừa đẩy — và vì payload là hộp đen, client không
phân biệt được máy gửi. Một toast "máy khác vừa đổi dữ liệu" sẽ hiện **sai** trên
đúng máy vừa ghi, sau mỗi lần ghi. Kết quả đồng bộ đã có dải riêng ở bậc cao nhất
(§6.3). Cơ chế: `loiNhan` là `String?`, và **`null` là định nghĩa duy nhất của
"không toast"** — `AppToast` chỉ đọc getter ấy, không tự liệt kê sự kiện.

---

## 5. Xác thực và nối lại

### 5.1 Bắt tay

```dart
IO.io(socketBaseUrl, IO.OptionBuilder()
    .setTransports(['websocket', 'polling'])
    .disableAutoConnect()
    .disableReconnection()
    .setAuth({'token': accessToken})
    .build());
```

Token đọc từ `FlutterSecureStorage` khoá `AppConstants.accessTokenKey` **ngay
tại thời điểm nối**, không phải lúc dựng đối tượng. Không có token thì không
nối — và đó không phải lỗi, chỉ là chưa tới lúc.

### 5.2 Tự nối lại — tự viết, không dùng của thư viện

**Tắt** `reconnection` của socket_io_client và tự làm backoff:
**2s → 5s → 15s → 30s → 60s**, chạm trần thì giữ 60s; nối được thì reset về đầu.

Lý do (đây là điểm dễ làm sai nhất của mục này): **token truy cập có hạn**, nên
mỗi lần nối lại **bắt buộc phải đọc lại token** từ kho — `AuthInterceptor` có
thể đã làm mới nó trong lúc socket đứt. Cơ chế nối lại của thư viện dùng lại
nguyên tham số bắt tay cũ, tức một token đã chết sẽ bị thử lại vô hạn với đúng
chuỗi đã hỏng, và server từ chối ở tầng middleware trước cả khi vào room. Tự
viết thì mỗi lần thử là một lần đọc token mới, chỉ có **một** cơ chế giãn cách
thay vì hai cái đánh nhau, và **test được** bằng đồng hồ giả.

`stop()` phải huỷ được cả hẹn giờ đang chờ, không chỉ ngắt socket đang mở. Một
lần nối lại nổ **sau** khi đăng xuất là nối lại bằng token của người vừa rời đi.

### 5.3 ⚠️ Địa chỉ socket không phải `baseUrl`

`AppConstants.baseUrl` kết thúc bằng **`/api`** (`http://10.0.2.2:3000/api` trên
máy ảo Android, `http://127.0.0.1:3000/api` trên web/desktop). Socket.io phải
nối vào **gốc**, không có `/api`.

Nên có một hàm thuần riêng, ví dụ `socketBaseUrlFrom(String apiBaseUrl)`, **có
test**, thay vì cắt chuỗi tại chỗ. Nó phải chịu được cả trường hợp không có
`/api` ở cuối (khi chuyển sang bản cloud) và cả dấu `/` thừa.

---

## 6. Giao diện: `ConnectionBanner` thành toast nổi ở đáy

### 6.1 Vì sao đổi cả widget dùng chung

Dải hiện tại là một thanh **đặc màu, kín chiều ngang**, nằm trong `Column` nên
**đẩy cả trang xuống** khi xuất hiện, và không có hiệu ứng vào–ra. Người dùng
xem bản mô tả và yêu cầu đổi sang **popup / thông báo nhỏ** cho đẹp hơn.

Vì đây là widget dùng chung ở `MaterialApp.builder`, đổi nó là đổi **cả ba** dải
— mất kết nối, kết quả đồng bộ, và realtime mới. Đó là chủ ý: một ngôn ngữ thị
giác cho mọi thông báo tạm thời.

⚠️ **`Column` vốn là lựa chọn có chủ ý**, ghi ngay trong tệp: bản đầu cho dải
nổi đè lên nội dung và trên máy thật nó **che mất thanh tiêu đề và nút chuông**.
Lý lẽ ấy vẫn đúng — nhưng chỉ đúng với dải nổi **ở đỉnh**. Đặt ở **đáy** thì
không đụng vào thanh tiêu đề. Đó là lý do chọn đáy chứ không phải vì thẩm mỹ.

### 6.2 Thông số (dựng trên Stitch, màn `a8964749665d4a05a8d3e2833dfbe872`)

Màn *"Thông báo nổi (toast) - FlowMoney"*, design system **Kinetic Finance**
(`assets/e8b7d56ef9284443bfacb7474e52c74a`).

| Thuộc tính | Giá trị |
|---|---|
| Hình dạng | viên thuốc, bo tròn hoàn toàn |
| Nền | `#FFFFFF` |
| Viền | 1px `#E3E3DF` |
| Bóng | `0 8px 24px rgba(0,0,0,0.12)` (Level 2 của design system) |
| Cao tối thiểu | 48 |
| Đệm | trái 6 · phải 16 · trên/dưới 6 |
| Huy hiệu | tròn 36, nền màu ngữ nghĩa, icon trắng 18 |
| Chữ | 13px, weight 500, `#1A1C1A` |
| Bề ngang | thu gọn theo nội dung, tối đa 90% màn |
| Vị trí | căn giữa ngang; cách đáy = chiều cao thanh điều hướng (**80**, từ `main_shell.dart`) + 12 |

Ba màu ngữ nghĩa của huy hiệu: `AppColors.income` (tin tốt), `AppColors.expense`
(hỏng), `AppColors.warning` (cảnh báo). Không nút đóng, không nút hành động.

### 6.3 Hành vi

- Trượt lên + mờ dần khi vào, ngược lại khi ra.
- **Vẫn tự ẩn sau 4 giây**, mọi loại, không đổi.
- Luật ưu tiên phải nêu thành **một thứ tự dứt khoát**, vì nay có ba nguồn cùng
  tranh một chỗ. Bậc cao hơn ghi đè bậc thấp hơn; **bằng bậc thì cái đến sau
  thắng** (nó mới hơn):

  1. **Kết quả đồng bộ** (`laKetQuaDongBo`) — cao nhất, vì nó trả lời đúng câu
     người dùng lo: dữ liệu vừa ghi đã an toàn chưa. Luật này đã có sẵn và giữ
     nguyên nguyên nhân: đo trên máy thật, `SyncEngine` đẩy xong sau ~0,4 giây
     còn bộ theo dõi kết nối phải chờ hết ngưỡng ổn định 3 giây, nên không xếp
     bậc thì dải đồng bộ luôn bị dải kết nối nuốt.
  2. **Realtime** — giữa. Được ghi đè dải kết nối, nhưng phải nhường dải đồng bộ.
  3. **Trạng thái kết nối** — thấp nhất.

  Hệ quả cần một dòng test riêng: một sự kiện realtime tới trong lúc dải "Đã
  đồng bộ xong" đang hiện thì **không** hiện ra, và nó **không** được xếp hàng
  để hiện sau — thông báo tạm thời trễ vài giây là thông báo sai ngữ cảnh.

### 6.4 ⚠️ Đánh đổi đã biết

Widget nằm ở `MaterialApp.builder`, **trên** router, nên nó không biết trang
hiện tại có thanh điều hướng hay không. Trang **ngoài** shell sẽ thấy toast nổi
cao hơn mức cần thiết. Chấp nhận, thay vì dựng thêm cơ chế truyền chiều cao
ngược lên từ shell.

Con số 80 + 12 và khoảng đệm vùng an toàn **phải kiểm bằng mắt trên máy ảo
411dp**. Đây đúng loại lỗi thứ nhất trong ba loại `flutter test` không bắt được.

---

## 7. Kiểm thử

Viết đỏ trước, và mỗi luật hỏng-im-lặng phải có **bản sai có chủ ý** chứng minh
test thật sự bắt được — kèm kiểm rằng bản sai ấy *có đổi hành vi thật*.

**`RealtimeChannel`** (socket giả, đồng hồ giả):

1. Ba tên sự kiện → đúng ba `RealtimeEvent`; **tên lạ bị bỏ qua**.
2. `bank_transaction.incoming` và `ocr.completed` đánh thức đồng bộ;
   `ocr.duplicate` **không**.
3. Payload rác (thiếu trường, sai kiểu, `null`) **không** làm vỡ gì — hệ quả
   trực tiếp của quyết định "hộp đen" ở mục 4, phải có test canh.
4. Token được đọc lại ở **mỗi** lần nối, không phải một lần lúc `start()`.
5. Backoff giãn đúng 2 → 5 → 15 → 30 → 60 → 60 và **reset** sau khi nối được.
6. `stop()` huỷ được hẹn giờ đang chờ: không có lần nối nào sau khi đã dừng.
7. Không có token thì không nối và không ném lỗi.

**Địa chỉ:** `socketBaseUrlFrom` cắt đúng `/api` ở cả hai dạng baseUrl, chịu
được chuỗi không có `/api` và dấu `/` thừa.

**Toast:** cập nhật `test/shared/connection_banner_test.dart` đang có. Thêm:
hiện đúng nội dung theo từng nguồn, tự ẩn sau 4 giây, luật ưu tiên ba nguồn,
và **test tràn bố cục** với chuỗi dài trong `SizedBox` hẹp, bắt bằng
`tester.takeException()`.

⚠️ Mọi tệp test mới phải `git add -f` **từng đường dẫn một**.

**Ngoài bộ test — bắt buộc trước khi báo xong:** chạy trên máy ảo và kích chuỗi
thật bằng `POST /api/bank/webhook` (endpoint có thật, xác thực bằng ApiKey), đi
qua worker → EventBus → socket → client. Đây là cách duy nhất chứng minh kênh
chạy đầu-cuối chứ không chỉ chạy trong bộ test.

---

## 8. Việc gửi sang backend

> ⚠️ **2026-09-11:** hai tệp dưới nay ở `docs/superpowers/backend/DA-XONG/`
> (`SOCKET_SYNC_COMPLETED.md`, `SOCKET_BANK_EVENT_PAYLOAD.md`). Việc 1 **backend đã
> làm** (17 A đóng 2026-09-12; G34 ✅ client xong tối cùng ngày); việc 2 ✅ **xong 2026-09-12** — một chỗ phát,
> một hình dạng (`notification.service.js`; mục 2.5 `DA-XONG/VERIFY_7675B35_REMAINING.md`). Phần dưới giữ
> nguyên văn bản gửi đi ngày 2026-09-09.

Hai tệp mới trong `docs/superpowers/backend/CAN-LAM/` (thư mục này **có** trong
git, khác với `specs/`):

1. **Bắc `sync.completed` ra socket** tới `account_<idaccount>`. Đây là thứ
   biến kênh này từ hạ tầng thành giá trị thật: một máy đẩy xong thì máy kia
   pull ngay, thay vì chờ hết chu kỳ 15 phút. Sự kiện đã được `publish` vào
   EventBus nội bộ rồi — việc còn lại chỉ là thêm một listener như ba cái đang
   có trong `notification.service.js`.
2. **Thống nhất một hình dạng payload** cho `bank_transaction.incoming`. Hiện
   hai đường phát hai kiểu khác nhau. Client hôm nay không đọc trường nào nên
   không vỡ, nhưng bất kỳ ai đọc payload sau này sẽ dính bẫy im lặng.

Ngoài `CAN-LAM/`, hai việc dọn tài liệu **của client**:

- `docs/progress/Client-app.md` mục 8 đang liệt kê `notification.new` như một
  sự kiện có thật — sửa lại.
- `docs/CLIENT_APP_KNOWN_GAPS.md`: ghi màn "Giao dịch chờ duyệt" thành một mục
  còn treo, kèm ba endpoint đã có sẵn ở backend và ghi chú phải lên Stitch
  trước.

---

## 9. Rủi ro đã biết

| Rủi ro | Cách xử lý |
|---|---|
| Ba sự kiện hầu như không bao giờ nổ trong sử dụng thật (không có SePay thật, không có OCR ở client) | Chấp nhận. Kênh vẫn chạy đúng và chứng minh được bằng webhook; giá trị thật tới khi backend làm việc số 1 ở mục 8. ⚠️ *2026-09-11:* backend đã làm việc ấy; giá trị thật nay chờ sửa 17 A (bắt tay socket) và client nghe `sync.completed` (**G34**). ✅ *2026-09-12:* cả hai xong — đo máy ảo hai máy cùng tài khoản, máy kia kéo về cùng giây |
| Socket giữ kết nối tốn pin khi app chạy nền | Ngoài phạm vi lần này. Đã có `app_lifecycle_watcher.dart` nếu sau này cần ngắt lúc nền |
| Đổi widget dùng chung làm hỏng hai dải đang chạy tốt | `test/shared/connection_banner_test.dart` đã có sẵn, cập nhật cùng lúc; và kiểm mắt trên máy ảo |
| Toast nổi sai chỗ ở trang ngoài shell | Đã chấp nhận có ý thức, mục 6.4 |
