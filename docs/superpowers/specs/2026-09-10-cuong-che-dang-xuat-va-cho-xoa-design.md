# Cưỡng chế đăng xuất và tài khoản chờ xoá — thiết kế

> **Trạng thái: CHỜ NGƯỜI DÙNG DUYỆT SPEC** (2026-09-10). Mọi quyết định sản
> phẩm ở mục 2 đã chốt qua hỏi–đáp; Phần 1 (mục 3) được duyệt riêng trong phiên.
> Phần 2–4 viết thẳng vào đây theo yêu cầu "làm đi" của người dùng, duyệt cùng
> lúc với thiết kế Stitch ở mục 5.
>
> Yêu cầu gốc: `docs/progress/Client-app.md` mục 10–12. Hạng mục 5 của kế hoạch
> cá nhân `docs/superpowers/plans/2026-09-10-ra-soat-csdl-moi.md` (gitignore).

---

## 1. Vì sao làm — một lỗi đang chạy, không chỉ tính năng còn thiếu

### 1.1. Client đang hứa một điều backend không làm — G33

Có **hai** đặc tả nói ngược nhau về giai đoạn chờ xoá:

| | Bản cũ (`docs/superpowers/auth/2026-08-17-auth-account-design.md`) | Bản mới (`docs/progress/Client-app.md` mục 12) |
|---|---|---|
| Đăng nhập lại trong 30 ngày | **tự khôi phục**, trả `pendingDeleteCancelled: true` | vẫn `PendingDelete`, dùng app bình thường |
| Gửi yêu cầu xoá | thu hồi mọi token | không thu hồi |
| Huỷ xoá | đăng nhập lại | bấm nút → `POST /auth/cancel-delete` |

**Backend đang chạy theo bản mới** (đọc mã 2026-09-10):
`auth.service.js:309` khai `let pendingDeleteCancelled = false` và **không chỗ
nào gán lại**; nhánh `PendingDelete` của `login` (`:311-322`) chỉ ghi log rồi cấp
token; `deleteAccount` (`:494-511`) không gọi `revokeAllTokens`.

**Client đang chạy theo bản cũ**:
- `delete_account_page.dart:80-119` — gửi yêu cầu xong thì `LogoutRequested`
  và nói *"hãy đăng nhập lại trong vòng 30 ngày — hệ thống sẽ tự động khôi
  phục tài khoản cho bạn"*; dòng thời gian của trang ghi *"Ngay lập tức: bạn sẽ
  bị đăng xuất khỏi tất cả thiết bị"*.
- `auth_repository_impl.dart:137-140` — `deleteAccount` xoá sạch token.
- `login_page.dart:36-71` — hộp thoại "Tài khoản đã được khôi phục" chờ một cờ
  không bao giờ bật.

**Hậu quả:** người dùng tin lời hứa, đăng nhập lại, thấy app chạy bình thường.
Tài khoản vẫn `PendingDelete`; 30 ngày sau `scheduler.service.js:processFullSoftDelete`
ẩn danh hoá dữ liệu và xoá mềm tài khoản. Không một chữ nào báo trước.

### 1.2. Phần còn thiếu

- `realtime_event.dart` chỉ nhận ba sự kiện; `account.force_logout` rơi vào
  nhánh "sự kiện lạ" (`realtime_channel.dart:193-195`).
- `auth_interceptor.dart:53-85` gặp mọi 401 là đi làm mới token, không đọc `code`.
- `UserModel.fromJson` bỏ `status` và `countdown` mà `/auth/login` trả về
  (`auth.service.js:362-363`).
- Không có chỗ nào hiện số ngày còn lại, không có nút huỷ xoá ngoài trang Xoá
  tài khoản (và nút ấy hiện cả khi tài khoản đang `Active`).

### 1.3. Vì sao chưa kiểm được đầu-cuối trên CSDL dev

CSDL dev chưa áp `database/8`, `9` (`CAN-LAM/DEV_DB_MIGRATIONS_7_11.md`), Prisma
Client cũ không biết `reason_inactive`/`countdown`. Nên hôm nay **mọi** đường
backend dẫn tới sự kiện này đều vỡ: `DELETE /auth/account`, `POST
/auth/cancel-delete`, admin khoá (`admin.service.js:134`), admin xoá
(`softDeleteUser`), và bộ đếm ngược hằng ngày. Không có `account.force_logout`
nào được phát ra; `middleware/auth.js:47-50` cho mọi request đi qua. Cách kiểm
chứng thay thế: mục 7.3.

✅ **Cập nhật tối 2026-09-10:** người dùng yêu cầu áp `database/7`–`11`; đã áp,
sinh lại Prisma Client và chạy lại backend (banner đầu
`CAN-LAM/DEV_DB_MIGRATIONS_7_11.md`). Mọi đường kể trên nay **chạy được** trên
backend thật — trừ body 401 vẫn thiếu mã (CAN-LAM 13). Mục 7.3 đã sửa theo.

---

## 2. Quyết định đã chốt với người dùng (2026-09-10)

| # | Câu hỏi | Chốt | Lý do chính |
|---|---|---|---|
| Q1 | Đăng nhập lại khi đang chờ xoá | **Dùng tiếp 30 ngày + lời nhắc** — theo bản mới | Khớp backend đang chạy, không cần backend sửa. Loại "đăng nhập là khôi phục" (người chỉ vào xem lại dữ liệu sẽ vô tình huỷ yêu cầu) và "hỏi ngay khi đăng nhập" (ngược mục 12.3) |
| Q2 | Dữ liệu SQLite khi bị đẩy ra | **Bị khoá thì giữ, bị xoá thì dọn** | Admin có thể mở khoá, thay đổi chưa đồng bộ còn đẩy lên được. Tài khoản đã xoá thì server đã ẩn danh hoá (xoá `note`, `images`) mà máy vẫn giữ bản rõ. Loại mục 12.5 "đánh dấu ví Inactive, ngân hàng Disconnected": người dùng đã bị đăng xuất nên không ai thấy cờ ấy, `wallet.status` là cột cục bộ (G28), và client **không có** bảng ngân hàng cục bộ |
| Q3 | Hình thức báo lý do | **Hộp thoại phải bấm "Đã hiểu"** | Theo mục 11.2/11.3. Người dùng chọn thay cho thẻ cảnh báo trên form mà tôi đề xuất |
| Q4 | Chỗ đặt lời nhắc chờ xoá | **Thẻ trên Trang chủ, đóng được** (+ trạng thái cố định ở Cài đặt) | Hành động không hoàn tác nên lời nhắc phải tới được Trang chủ; đóng được vì người dùng đã gỡ khối thông báo khỏi Trang chủ ngày 2026-09-08 (`home_page.dart:53-55`) |
| Q5 | Kiến trúc | **Hướng A — một kiểu thông báo chung, một cửa vào `AuthBloc`** | Loại B (dùng lại `SessionInvalidated`: lý do mất giữa đường, và bước hỏi lại `/auth/profile` phụ thuộc vào việc middleware không cho qua — lúc chốt thì CSDL dev đang cho qua ở mọi request; nay đã áp mục 11 nhưng nhánh cho qua khi lỗi lược đồ vẫn còn trong mã, CAN-LAM 11 mục 4.3). Loại C (cubit riêng: hai bloc phải phối hợp thứ tự dừng — loại lỗi `flutter test` không bắt được) |

**Đối chiếu thị trường** (2026-09-10): Facebook đăng nhập lại trong 30 ngày thì
hiện nút *Cancel deletion*
([Facebook Help](https://www.facebook.com/help/224562897555674)); TikTok đăng
nhập lại là tự kích hoạt lại
([ForestVPN](https://forestvpn.com/en/blog/social-media/tiktok-account-deletion-30-day-grace-period-explained/)).
Money Lover không có tài liệu công khai. Các app lớn nhắc **đúng lúc đăng nhập**;
"dùng tiếp 30 ngày" thì không ai có — nên lời nhắc phải đủ mạnh (Q4).

---

## 3. Phần 1 — Cưỡng chế đăng xuất (đã duyệt riêng)

### 3.1. Một kiểu dữ liệu, hai hàm đọc

Tệp Dart **thuần** `lib/core/auth/buoc_dang_xuat.dart`:

```dart
enum LyDoBuocDangXuat { biKhoa, daXoa }

class ThongBaoBuocDangXuat {
  final LyDoBuocDangXuat lyDo;
  final String loiNhan;   // câu server gửi; rỗng thì câu mặc định của client
  final int? idaccount;
}

ThongBaoBuocDangXuat? tuSuKienSocket(Object? payload);   // account.force_logout
ThongBaoBuocDangXuat? tuBody401(Object? body);            // body HTTP 401
```

- `reason`/`code` bằng `ACCOUNT_DELETED` → `daXoa`. **Mọi giá trị khác**, kể cả
  giá trị lạ hoặc thiếu, → `biKhoa`. Đọc nhầm thành "bị khoá" chỉ giữ lại dữ
  liệu; đọc nhầm thành "đã xoá" là xoá mất dữ liệu.
- `idaccount` đọc được cả `int` lẫn chuỗi số.
- `tuBody401` chỉ nhận `code` ở **cấp gốc** (hình dạng mục 4.1
  `CAN-LAM/AUTH_401_BODY_CODE.md`). `code` nằm dưới `errors` thì **không** nhận:
  đó là hình dạng của lối tắt `ResponseHandler.error(...)` mà tài liệu ấy đã bác.
  Body không có `code` → `null` → interceptor đi đường làm mới token như cũ.

### 3.2. Nguồn socket

`RealtimeChannel` có thêm `Stream<ThongBaoBuocDangXuat> buocDangXuat`, **tách
riêng** khỏi `events`:

- `events` giữ nguyên cam kết "không đọc payload" của `realtime_event.dart` —
  lý do cam kết ấy là `bank_transaction.incoming` phát từ **hai** chỗ với hai
  hình dạng. `account.force_logout` thì chỉ phát qua **một** hàm
  (`core/socket.js:170-191`, gọi từ `admin.service.js:140`, `:199` và
  `scheduler.service.js:116`), nên đọc payload ở đây là an toàn.
- `_khiCoSuKien` bắt tên `account.force_logout` **trước** `realtimeEventFromName`.
- Bỏ qua khi `idaccount` trong payload khác `_idaccount` của phiên đang chạy.
- Server phát xong thì `disconnectSockets(true)` — kênh sẽ hẹn nối lại; `AuthBloc`
  gọi `stop()` là huỷ hẹn ấy (đã có ở `realtime_channel.dart:121-122`).

### 3.3. Nguồn HTTP

`AuthInterceptor.onError`: 401 mà `tuBody401` trả khác `null` thì **không** gọi
`/auth/refresh`, phát `Stream<ThongBaoBuocDangXuat> taiKhoanBiTuChoi`, rồi
`handler.next(err)`. Interceptor **không** tự xoá token — việc ấy của `AuthBloc`.

Nhánh này **nằm im** cho tới CAN-LAM 13 (body 401 hiện không có `code`). CAN-LAM
11 đã áp tối 2026-09-10 nên tài khoản bị khoá nay **có** nhận 401 — chỉ là body
chưa mang mã. Không cần đổi gì khi backend sửa xong.

### 3.4. Cố ý bỏ qua lỗi bắt tay socket

`core/socket.js:39-44` luôn gắn `code: 'ACCOUNT_DELETED'` cho handshake bị từ
chối, **kể cả** tài khoản chỉ bị khoá. Tin mã ấy thì một người bị khoá tạm bị
**xoá sạch dữ liệu trên máy**. Người mở app sau khi đã bị khoá vẫn bị đăng xuất
qua nhánh HTTP (khi backend sửa) hoặc qua `verifySession` như hôm nay.

### 3.5. `AuthBloc`

Event mới `TaiKhoanBiBuocDangXuat(ThongBaoBuocDangXuat)`, nguồn là cả hai luồng
trên (nối trong constructor, cùng khuôn với `sessionExpiredStream`).

1. Chỉ xử lý khi state là `AuthSuccess` hoặc `AuthChecking`. Khác thì bỏ qua —
   lần nhận thứ hai (socket rồi HTTP) không làm gì.
2. Dừng `SyncEngine`, `NotificationScanner` (đã `cancelAll`), `RealtimeChannel`
   qua **một** hàm `_dungMoiThuCuaPhien()` — chuỗi này đang chép ở
   `_onSessionInvalidated` và `_onLogoutRequested`; lần này là lần thứ ba.
3. `daXoa` → `AppDatabase.purgeDataForAccount(idaccount)` (mục 3.6).
4. `AuthRepository.xoaPhienTrenMay()` — xoá token và bộ nhớ đệm người dùng,
   **không** gọi `/auth/logout`: route ấy đi qua `authenticate`
   (`auth.routes.js:33`), sẽ 401 rồi quay vòng qua interceptor.
5. Phát `AuthUnauthenticated(thongBao: …)`. Router sẵn có đưa về `/login`.

⚠️ Bloc chạy các handler **đồng thời**. Lúc mở app, `_onAuthCheckRequested` có
thể phát `AuthUnauthenticated()` trơn trước khi event này chạy xong. Vì vậy
`thongBao` **phải** nằm trong `props`: lần phát sau vẫn là state mới, hộp thoại
vẫn hiện.

`idaccount` để dọn lấy từ thông báo; thiếu thì từ `getCurrentUser()`. Không suy
từ SQLite, không mặc định (quy tắc 2 `CLAUDE.md`). Không có id hợp lệ → **không
dọn**, vẫn đăng xuất.

### 3.6. `purgeDataForAccount`

Hàm mới ở `app_database.dart`, **ngược chiều** `purgeDataForOtherAccounts`: xoá
hàng **thuộc** `idaccount` trong đúng chín bảng ấy, cùng thứ tự con → cha, giữ
`idaccount = 0`. `id <= 0` → không làm gì. Đây là xoá bản sao cục bộ của một tài
khoản server đã ẩn danh hoá — cùng loại với hàm sẵn có, không phải xoá dữ liệu
người dùng trên server (quy tắc 5).

### 3.7. Màn Đăng nhập

`BlocListener` thấy `AuthUnauthenticated` có `thongBao` → `showDialog`, thiết kế
ở mục 5. Tiêu đề theo lý do ("Tài khoản đã bị vô hiệu hoá" / "Tài khoản đã bị
xoá"), thân là `loiNhan` (lý do nằm sẵn trong câu server gửi,
`admin.service.js:140`), một nút **Đã hiểu**.

---

## 4. Phần 2 — Trạng thái chờ xoá

### 4.1. Trạng thái nằm trong `UserModel`

Thêm ba trường, lưu cùng JSON người dùng sẵn có (`offlineUserDataKey`):

| Trường | Khoá JSON | Nguồn |
|---|---|---|
| `status` | `status` | server; thiếu → `'Active'` |
| `countdown` | `countdown` | server; có thể `null` |
| `countdownNhanLuc` | `countdown_nhan_luc` (ISO 8601) | **cục bộ** — lúc client nhận `countdown` |

`_cacheOfflineCredentials` hiện ghi nguyên `userJson` của server; đổi sang ghi
`user.toJson()` để giữ `countdown_nhan_luc`. JSON cũ thiếu cả ba trường vẫn đọc
được (→ `Active`).

`bool get dangChoXoa` so `status` **không phân biệt hoa thường** với
`pendingdelete` — cùng cách `middleware/auth.js:26-29`.

### 4.2. Số ngày còn lại — hàm thuần

Không endpoint nào trả `countdown` mới: `/auth/profile` không có trường này
(`auth.service.js:537-547`), còn JWT mang `countdown` **lúc cấp** và `refresh`
cấp lại đúng payload cũ (`auth.service.js:396-406`). Nên client tự tính:

```
soNgayConLai = max(0, countdown − (ngàyVN(now) − ngàyVN(countdownNhanLuc)))
ngayXoa      = ngàyVN(countdownNhanLuc) + countdown ngày
```

- `ngàyVN` = ngày lịch ở UTC+7 cố định (Việt Nam không đổi giờ), khớp
  `scheduler.service.js:8-21` chạy lúc 00:00 giờ Việt Nam và trừ 1 mỗi lần.
- Trừ ngày bằng `DateTime.utc(y, m, d)` để khỏi lệch do múi giờ của máy.
- `countdown == null` → không có số, chỉ hiện câu chung (mục 5.2, 5.3).
- Đặt ở `lib/core/auth/dem_nguoc_xoa.dart`.

### 4.3. Trạng thái đến từ đâu

| Lúc | Việc |
|---|---|
| Đăng nhập | lấy `status`, `countdown` từ response; `countdownNhanLuc = now` |
| Mở app (`verifySession` gọi `/auth/profile`) | repository cập nhật `status` vào bộ nhớ đệm khi profile thành công: server `Active` mà máy đang chờ xoá → về `Active` (đã huỷ ở máy khác); server `PendingDelete` mà máy không biết → `PendingDelete`, `countdown = null` (yêu cầu gửi từ máy khác). `_onAuthCheckRequested` đọc lại `getCurrentUser()` **sau** `verifySession` |
| Gửi yêu cầu xoá thành công | ghi `PendingDelete`, `countdown` từ response (30), `countdownNhanLuc = now`; **không** xoá token, **không** đăng xuất |
| Huỷ xoá thành công | ghi `Active`, `countdown = null` |
| Huỷ xoá thất bại vì bất kỳ lý do gì | gọi lại `verifySession` (tức `/auth/profile`, cập nhật `status` như dòng hai). Server đã `Active` → thẻ tự biến mất, **không** báo lỗi (đã huỷ ở máy khác). Còn chờ xoá → báo lỗi. **Không** nhận diện bằng mã 400 hay câu chữ: `cancelDelete` ném `Exception(msg)` làm mất mã HTTP, và backend dùng 400 cả cho lỗi kiểm tra đầu vào |

Sau mỗi lần ghi, trang gọi `AuthBloc.add(ThongTinTaiKhoanThayDoi())`; handler
đọc lại `getCurrentUser()` và phát `AuthSuccess(user)` mới. Trang vẫn tự giữ
trạng thái đang tải và lỗi của nó, như hiện nay.

`AuthRemoteDataSource.deleteAccount` và `cancelDelete` đổi sang **trả về**
`data` thay vì `void`.

### 4.4. Gỡ mã chết của đặc tả cũ

- `UserModel.pendingDeleteCancelled`, nhánh gắn cờ ở `auth_repository_impl.dart:42-45`,
  chú thích ở `auth_remote_data_source.dart:67`.
- Hộp thoại "Tài khoản đã được khôi phục" ở `login_page.dart:36-71`.
- Đầu `docs/superpowers/auth/2026-08-17-auth-account-design.md` thêm dòng báo
  đã bị thay bởi tài liệu này (kiểm `git check-ignore` trước).

---

## 5. Phần 3 — Giao diện

Mọi khối mới đã (hoặc sẽ) thiết kế vào dự án Stitch `FlowMoney`
(`projects/5106367939423432838`) trước khi dựng.

### 5.1. Hộp thoại bị đẩy ra — màn Đăng nhập

Stitch: `97dd48e7154446168767cf80480bff85` — *"Đăng nhập - Tài khoản bị vô hiệu
hoá - FlowMoney"* (vẽ ca bị khoá; ca đã xoá chỉ khác biểu tượng và tiêu đề).
⚠️ Stitch dựng màn này ở khung **máy tính** (`deviceType: DESKTOP`, rộng 2560)
dù yêu cầu là mobile. Chỉ lấy **hộp thoại** làm chuẩn — nó là lớp nổi nên không
phụ thuộc khung; chiều rộng thật trên máy là `AlertDialog` mặc định trong 411dp.

Nền mờ phủ màn Đăng nhập; hộp thoại trắng bo 16px: biểu tượng tròn nền
`#FFDAD6` (icon `block` cho bị khoá, `delete_forever` cho đã xoá), tiêu đề theo
lý do, thân là `loiNhan`, dòng phụ *"Bạn đã được đăng xuất khỏi thiết bị này.
Liên hệ hỗ trợ nếu bạn cho rằng đây là nhầm lẫn."*, một nút **Đã hiểu**.

### 5.2. Thẻ nhắc trên Trang chủ

Stitch: `657d29a8f89e4750ae6f878d096aa94e` — *"Trang chủ - Tài khoản đang chờ
xoá"* (dựng từ `6c692ef11f2d4f40aee3666449b4988d` với ngăn kéo đóng).

- Vị trí: ngay dưới `_buildHeader`, trên `_buildHeroSection`.
- Thẻ thu gọn theo nội dung (không phải dải kín ngang): nền `#FFDAD6`, bo 8px,
  đệm 16px. Tiêu đề "Tài khoản đang chờ xoá"; thân *"Còn **N ngày** nữa tài
  khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn."*; `countdown == null` thì
  *"Tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn khi hết thời hạn chờ."*
- Nút **Để sau** (ghost) và **Huỷ xoá** (chính, có trạng thái đang tải).
- "Để sau" ẩn thẻ tới lần mở app kế tiếp: cờ **trong bộ nhớ** (một
  `ValueNotifier<bool>` đăng ký ở `sl`), đặt lại khi đăng nhập thành công. Cố ý
  không lưu xuống đĩa.
- Huỷ xoá thành công thì thẻ tự biến mất — chính việc biến mất là phản hồi,
  không thêm toast. Lỗi → `SnackBar` như các trang khác.
- Chỉ hiện khi `AuthSuccess.user.dangChoXoa`.

### 5.3. Thẻ "Vùng nguy hiểm" ở Cài đặt

Stitch: `13a6c1f6adac41ce8ed89e6f248f511f` — *"Cài đặt - Tài khoản đang chờ xoá"*
(bản gốc `05fc2d46c5544f1d95fec14421e1d467` giữ nguyên cho trạng thái `Active`).

- `Active`: như hiện nay.
- Chờ xoá: giữ khung, viền, tiêu đề; hộp đếm nền `#FFDAD6` với số lớn **N** +
  "ngày còn lại" và dòng *"Tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn vào
  dd/MM/yyyy."*; dòng *"Trong thời gian này bạn vẫn dùng app bình thường. Huỷ
  yêu cầu để giữ lại tài khoản."*; nút chính **Huỷ yêu cầu xoá** thay nút viền đỏ.
  `countdown == null` thì bỏ hộp đếm, giữ hai dòng chữ.

⚠️ Stitch tự áp design system "Kinetic Clarity" (`assets/1f1ef0da…`) cho màn
sửa này, khác "Kinetic Finance" (`assets/e8b7d56e…`) của dự án. Khi dựng, lấy
**màu và cỡ chữ đã ghi ở trên**, không lấy token của hệ kia.

### 5.4. Trang Xoá tài khoản — chỉ sửa chữ và luồng

- Hộp thoại xác nhận: bỏ câu *"bạn có thể đăng nhập lại để hủy yêu cầu"*.
- Thành công: hộp thoại *"Yêu cầu đã được ghi nhận. Bạn vẫn dùng app bình thường
  trong 30 ngày, và huỷ được bất cứ lúc nào ở Trang chủ hoặc Cài đặt."* → về
  `/home`. **Không** đăng xuất.
- Dòng thời gian: "Ngay lập tức — tài khoản chuyển sang chờ xoá, bạn vẫn dùng
  app bình thường"; "Trong 30 ngày — huỷ yêu cầu ở Trang chủ hoặc Cài đặt";
  "Sau 30 ngày" giữ nguyên.
- Bỏ nút "Hủy yêu cầu xóa tài khoản" ở cuối trang: khi đang chờ xoá, Cài đặt
  không còn dẫn vào trang này nữa (mục 5.3).

---

## 6. Phần 4 — Việc cho backend

Viết **`CAN-LAM/AUTH_PROFILE_COUNTDOWN.md`** (mục **17** của `README.md`),
không đụng `src/Backend`:

1. `getProfile` (`auth.service.js:537-547`) trả thêm `countdown` — một dòng.
   Để máy không gửi yêu cầu xoá vẫn hiện được số ngày (mục 4.3 dòng hai).
2. `pendingDeleteCancelled` luôn `false`: xin gỡ trường khỏi response hoặc ghi
   rõ là đã bỏ, vì `Rule_project.md`/đặc tả 2026-08-18 còn mô tả nó.
3. Ghi nhận client đã theo đặc tả mục 12 (không tự khôi phục khi đăng nhập),
   để backend không "sửa" ngược lại.

Kèm cập nhật `README.md` mục 2 và mọi con số đếm mục CAN-LAM trong
`CLAUDE.md`/`PROJECT_CONTEXT.md` (đếm bằng script).

---

## 7. Kiểm thử và kiểm chứng

### 7.1. Test thuần (viết đỏ trước)

- `buoc_dang_xuat_test`: payload socket đủ/thiếu trường; `idaccount` là chuỗi;
  `reason` lạ → `biKhoa`; `message` rỗng → câu mặc định; body 401 có `code` ở
  gốc / dưới `errors` (→ `null`) / không phải `Map` / không có `code`.
- `dem_nguoc_xoa_test`: cùng ngày; qua 00:00 giờ VN (23:59 → 00:01 VN, tức
  16:59Z → 17:01Z); cuối tháng 30/31 ngày; **28/02 → 01/03 năm 2026 và năm
  nhuận 2028**; qua năm; `now` trước `nhanLuc` (đồng hồ máy lùi) → không vượt
  `countdown`; kết quả âm → 0; `ngayXoa` rơi sang tháng/năm sau.
- `user_model_test`: JSON cũ không có ba trường → `Active`; vòng
  `toJson`/`fromJson` giữ `countdown_nhan_luc`; `dangChoXoa` với
  `PendingDelete`/`pendingdelete`/`Active`/thiếu.

### 7.2. Test tích hợp và widget

- `AuthInterceptor`: 401 có `code` → **không** gọi refresh (Dio làm mới giả đếm
  0), phát `taiKhoanBiTuChoi`, không xoá token; 401 không `code` → đường cũ (test
  sẵn có vẫn xanh).
- `RealtimeChannel` (socket giả sẵn có): `account.force_logout` khớp id → phát
  `buocDangXuat`, **không** phát vào `events`; lệch id → im; sau `stop()` → im.
- `AuthBloc` (khuôn `session_validation_test.dart`): `biKhoa` → dừng ba thành
  phần, **không** gọi `logout()` từ xa, không dọn SQLite, state có `thongBao`;
  `daXoa` → dọn đúng tài khoản; không có phiên → bỏ qua; hai lần liên tiếp →
  lần hai không làm gì; `AuthUnauthenticated()` trơn rồi tới `thongBao` → hai
  state khác nhau.
- `purgeDataForAccount` trên Drift trong RAM: đủ chín bảng, giữ `idaccount = 0`
  và tài khoản khác, `id <= 0` → không xoá gì.
- Widget, dựng bằng `AppTheme.lightTheme` trong `SizedBox(width: 411)` và bắt
  `tester.takeException()` (bẫy tràn bố cục): hộp thoại Đăng nhập theo hai lý
  do; thẻ Trang chủ có số / không số / "Để sau" / "Huỷ xoá" thành công và lỗi;
  thẻ Cài đặt hai trạng thái; trang Xoá tài khoản thành công **không** phát
  `LogoutRequested`.

### 7.3. Kiểm chứng ngoài bộ test

Sau khi áp `database/7`–`11` (tối 2026-09-10, mục 1.3), backend thật dựng được mọi
tình huống **trừ** body 401 có mã (CAN-LAM 13). Đề xuất, theo thứ tự:

- **Backend thật, tài khoản thử riêng.** Máy ảo đang giữ phiên tài khoản **10
  không có mật khẩu** — cưỡng chế đăng xuất trên đó là mất phiên ấy. Cần một tài
  khoản thử có mật khẩu (hỏi người dùng cách tạo), rồi: gửi yêu cầu xoá → thẻ Trang
  chủ và Cài đặt hiện đúng số; huỷ → thẻ biến mất; khoá qua Admin-web → về Đăng
  nhập, hộp thoại đúng câu, SQLite còn dữ liệu; mở khoá rồi đăng nhập lại được.
- **Ca *đã xoá* không làm trên backend thật** — admin xoá mềm tài khoản là không
  hoàn tác được bằng giao diện. Ca này kiểm bằng test (mục 7.2); nếu cần nhìn tận
  mắt thì dùng một backend giả trong scratchpad phát `account.force_logout` với
  `ACCOUNT_DELETED` — cần tạm dừng backend thật, **hỏi người dùng trước**.
- **Nhánh HTTP 401** chỉ kiểm được sau CAN-LAM 13, theo mục 5 của
  `AUTH_401_BODY_CODE.md`.
- Không sọc vàng tràn bố cục ở 411dp.

`flutter test` và `flutter analyze` đối chiếu mức nền 2026/2026 và 25 issue.

---

## 8. Ngoài phạm vi

- Đăng nhập bị từ chối 403 vẫn dùng `SnackBar` hiện có — đã hiện đủ câu có lý do.
- Bố cục trang Xoá tài khoản lệch màn Stitch `8a2c9ba…` (Stitch gọn hơn nhiều).
  Chỉ sửa chữ và luồng; dựng lại theo Stitch là việc riêng nếu người dùng muốn.
- Mã lỗi của handshake socket, `/auth/refresh` không kiểm trạng thái tài khoản,
  403 đăng nhập không có `code` — đã xin ở `AUTH_401_BODY_CODE.md` 4.2, 4.3.
- Thông báo cấp hệ điều hành khi sắp hết hạn chờ xoá.

## 9. Bẫy đã thấy trước

- **Handler đồng thời của Bloc** — mục 3.5. Test phải dựng đúng thứ tự
  `AuthUnauthenticated()` trơn rồi mới tới thông báo.
- **`disconnectSockets(true)` ngay sau `emit`** (`core/socket.js:184-187`): nếu
  gói tin rơi trước khi tới client thì nhánh socket không nổ. Engine.io chờ
  `drain` trước khi đóng nên lý thuyết là tới được; chỉ kiểm được bằng backend
  giả làm đúng thứ tự ấy.
- **`purgeDataForAccount` đọc nhầm lý do là xoá dữ liệu** — vì thế mặc định mọi
  thứ không rõ về `biKhoa` (mục 3.1) và bỏ qua mã handshake (mục 3.4).
- **Hai chỗ sửa `status` đồng thời**: người dùng bấm Huỷ xoá trong lúc
  `verifySession` đang chạy. Bộ nhớ đệm là "ai ghi sau thắng"; chấp nhận, vì lần
  mở app kế tiếp tự lành theo server.
