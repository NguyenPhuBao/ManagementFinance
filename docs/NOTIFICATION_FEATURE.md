# Hệ thống thông báo — tài liệu bàn giao

> **Cập nhật:** 2026-09-08 · **Nhánh:** `TranQuangDat`
> **Trạng thái:** cả bảy lát đã xong, **đã kiểm trên máy ảo Android**, có thêm
> **dải báo kết nối** (mục 9), **mốc kích hoạt quét đã được sửa lại cho
> offline-first** (mục 4.5), **cú chạm vào thông báo hệ điều hành nay điều
> hướng thật** (mục 5b), **bốn loại báo tiền vừa rời ví nay bỏ qua công tắc
> nhóm** (mục 3), và **giờ im lặng · gộp thông báo · hoàn tác vuốt xoá**
> (mục 5c). Đọc bốn mục ấy trước nếu định đụng vào vùng này.
>
> **Thêm ngày 2026-09-07 (tối):** **lọc + phân trang + đánh dấu chưa đọc** cho
> trung tâm thông báo (mục 4.6), **nhắc ghi chép hằng ngày** — loại nhắc duy
> nhất suy từ việc *không có* dữ liệu, và cố ý **không** phải một
> `NotificationKind` nào cả (mục 4.7), và **nút hành động** *Trả ngay* /
> *Hoãn 1 ngày* chạy trong isolate nền (mục 4.8). Số bẫy ở mục 7 nay là
> **mười một** — bẫy **7.11**
> mới nói về `AndroidManifest.xml`, vùng mù của mọi công cụ trong dự án này.
>
> **Thêm ngày 2026-09-08:** `NotificationKind` **thứ mười lăm** —
> **`goalMilestone`**, cột mốc 25/50/75% của mục tiêu tiết kiệm. Trước nó app
> chỉ lên tiếng ở 100% và khi chậm tiến độ. Lý do và bảng xếp hạng ở mục **10**
> `docs/GOAL_FEATURE.md`; khoá chống trùng ở mục 6 dưới đây.
>
> **Mức nền hiện tại:** `flutter test` **1513/1513 pass**, `flutter analyze`
> **25 issue, KHÔNG error** (đo lại 2026-09-08, cuối ngày).

Đọc file này trước khi làm tiếp bất cứ việc gì thuộc thông báo. Mục 6 ghi lại
từng lát đã làm gì và vì sao; mục 7 là những cái bẫy — **đọc mục 7 trước khi
sửa bất cứ thứ gì trong vùng này**.

> ⚠️ **Lát 7 được làm TRƯỚC lát 5, có chủ ý.** Lát 5 cần "giờ nhắc trong ngày"
> mà nơi lưu tuỳ chọn ấy nằm ở lát 7 — thiếu nó thì `zonedSchedule` nổ lúc
> 00:00 (bẫy 7.3). Và lát 4 không kiểm chứng được trên máy thật cho tới khi có
> một chỗ xin quyền, mà chỗ ấy cũng là lát 7. Làm ngược lại thì phải quay lại
> sửa cả hai điểm.

---

## 1. Vì sao có tính năng này

App trước đây có **ba biểu tượng chuông chết** và một mục menu trống:
`home_page.dart` vẽ một `Container` không có `onTap` kèm chấm đỏ **hard-code
luôn sáng**; `goal_page.dart` và `profile_page.dart` dùng `onPressed: () {}`;
mục "Thông báo" trong Profile cũng vậy.

Trong khi đó dữ liệu để sinh thông báo **đã nằm sẵn trong SQLite** mà không ai
đọc — `BudgetEntity.isNearLimit` cài đủ luật ngưỡng nhưng chỉ một widget dùng,
`Bills.timeNotification` có cột ở cả hai đầu CSDL mà `lib/` không đọc,
`BillDao.getUpcoming()` chưa ai gọi, `SyncEngine.statusStream` và cột
`syncError` ở cả sáu bảng không có người tiêu thụ nào.

**Thiết kế Stitch đã vẽ sẵn khu thông báo** trên màn Home: chuông ở header,
panel "Thông báo" với ba mục mẫu — *"Bạn đã chi tiêu vượt 80% ngân sách Ăn
uống"*, *"Nhắc nhở: Hóa đơn tiền điện sắp đến hạn"*, *"Tiết kiệm thêm 500k để
đạt mục tiêu MacBook"* — và liên kết "Xem tất cả". Màn "Xem tất cả" thì Stitch
**chưa thiết kế**; bản hiện tại bám `AppColors` và kiểu thẻ đang dùng thật.

---

## 2. Quyết định đã chốt với người dùng

| | |
|---|---|
| **Kênh** | Trung tâm thông báo trong app **+** thông báo hệ điều hành trên Android/iOS. **Không FCM.** Web chỉ có phần trong app. |
| **Đồng bộ** | **Không** đồng bộ giữa thiết bị. Bảng cục bộ, **không** thêm vào `SyncEntityType`, **không** chạm `sync_payload_contract_test.dart`. |
| **Phạm vi** | Bốn nhóm: hoá đơn, ngân sách, mục tiêu, hệ thống. |
| **Cài đặt** | Công tắc theo từng nhóm + một công tắc tổng cho thông báo hệ điều hành. |
| **Backend** | Viết tài liệu yêu cầu, chừa chỗ sẵn. **Không nối socket.** |

---

## 3. Danh mục thông báo

**Mười bốn loại**, xếp vào **bốn nhóm** công tắc. Cột cuối đánh dấu những loại
**không chịu công tắc nhóm** — xem `luonBao()` trong `notification_prefs.dart`.

| Nhóm | Loại | `kind` | Luôn báo |
|---|---|---|---|
| Ngân sách | Chạm ngưỡng | `budgetNearLimit` | |
| | Vượt hạn mức | `budgetOverspent` | |
| Hoá đơn | Sắp đến hạn | `billDueSoon` | |
| | Quá hạn | `billOverdue` | |
| | **Đã tự thanh toán** | `billAutoPaid` | ⚠️ có |
| | **Chưa tự trả được** | `billAutoPayFailed` | ⚠️ có |
| Mục tiêu | Hoàn thành | `goalCompleted` | |
| | Bắt đầu vòng mới | `goalCycleReady` | |
| | Trễ tiến độ | `goalBehind` | |
| | **Cột mốc 25/50/75%** | `goalMilestone` | |
| | **Đã trích tự động** | `goalAutoDeposited` | ⚠️ có |
| | **Chưa trích được** | `goalAutoDepositFailed` | ⚠️ có |
| Hệ thống | Đồng bộ hỏng | `syncFailed` | |
| | Số dư ví âm | `walletNegative` | |
| | Số dư ví sắp cạn | `walletLowBalance` | |

**`walletLowBalance`** (2026-09-07) là loại duy nhất **tắt sẵn**: nó chỉ sinh
khi `NotificationPrefs.nguongSoDuThap > 0`, mà mặc định là `0`. Con số ấy vừa
là ngưỡng vừa là công tắc — một cặp công tắc-cộng-số biểu diễn được trạng thái
vô nghĩa "bật nhưng ngưỡng bằng 0", còn một con số thì không. Mặc định tắt vì
mọi bản ghi có sẵn trên máy người dùng đều thiếu trường này, và bật sẵn là lặng
lẽ đổi hành vi của mọi bản đã cài — cùng lý lẽ với giờ im lặng.

⚠️ **Ví loại `debt` không sinh cảnh báo ví nào cả**, kể cả `walletNegative`.
Ví nợ mang số dư âm là đúng bản chất của nó; trước 2026-09-07 nó bị nhắc lại
**mỗi ngày** cho tới khi trả hết nợ. Đây là đổi hành vi có chủ ý, không phải
tác dụng phụ.

Thứ tự loại trừ trong `_walletCandidates` là thứ giữ cho mỗi ví ra **một**
thông báo: số dư âm cũng thoả điều kiện "dưới ngưỡng", nên thiếu `continue` ở
nhánh trên là mỗi ví âm đẻ hai thông báo nói cùng một chuyện.

⚠️ **Bốn loại "luôn báo" là những loại DUY NHẤT báo việc tiền thật rời ví** khi
người dùng vắng mặt. Trước 2026-09-06 chúng chịu chung công tắc với phần còn
lại của nhóm, nghĩa là ai tắt nhóm Hoá đơn vì thấy nhắc hạn phiền thì **mất
luôn cảnh báo app vừa trừ tiền** — và vì bộ lọc chạy *trước khi ghi*, trung tâm
thông báo cũng không còn dấu vết nào; họ chỉ thấy số dư ví hụt đi. "Đừng nhắc
tôi hoá đơn sắp tới hạn" và "đừng cho tôi biết app vừa rút tiền của tôi" là hai
câu khác nhau.

Muốn im hẳn thì vẫn còn **công tắc tổng** cho thông báo hệ điều hành — nó chỉ
chặn bước bắn ra ngoài, hàng vẫn được ghi lại trong app. Trang cài đặt nói rõ
ngoại lệ này bằng một dòng chú thích; im lặng về nó là để người dùng gạt tắt
rồi tin rằng mình đã tắt.

⚠️ **Đừng nới `luonBao()` ra cả nhóm.** Công tắc mất tác dụng thì người dùng sẽ
tắt luôn công tắc tổng, và khi ấy họ mất mọi thứ.

Giao dịch ngân hàng và OCR **không** làm được ở client: backend có phát
ba sự kiện đó qua Socket.io nhưng client chưa có `socket_io_client`, và quan
trọng hơn là kênh socket đó đang là **bước 1 trong chín bước sửa backend** vì
handshake không xác thực và mỗi sự kiện còn `io.emit` toàn cục. ✅ **Đã sửa 2026-09-07** — JWT ở handshake, `join_account` gỡ hẳn, không còn `io.emit` nào; nay chỉ còn chờ client dựng luồng OCR/ngân hàng (backend đã đổi nhà cung cấp **Casso → SePay**).

---

## 4. Kiến trúc hiện tại

```
lib/core/notification/
├── notification_rules.dart       # Hàm THUẦN: trạng thái → danh sách ứng viên
├── notification_scanner.dart     # Nối luật với CSDL và vòng đời app
├── reminder_scheduler.dart      # Đặt lịch trước với hệ điều hành (lát 5)
├── notification_deeplink.dart    # go hay push — xem mục 7.8
├── os/                           # Cửa ra hệ điều hành (lát 4) — xem mục 6
└── prefs/                        # Tuỳ chọn của người dùng (lát 7)

lib/core/network/connection_monitor.dart  # Ngưỡng ổn định — xem mục 9

lib/core/database/
├── tables/notification_table.dart   # Bảng AppNotifications
└── daos/notification_dao.dart

lib/core/utils/relative_time.dart    # "10 phút trước" / "Hôm qua"

lib/shared/widgets/notification_bell.dart      # Chuông dùng chung
lib/shared/widgets/connection_banner.dart      # Dải báo kết nối — mục 9

lib/features/notification/presentation/
├── pages/notification_center_page.dart      # /notifications
├── pages/notification_settings_page.dart    # /settings/notifications
└── widgets/notification_panel.dart          # Panel trên Home
```

### 4.1 Bảng `AppNotifications` — cục bộ, không đồng bộ

⚠️ **Tên là `AppNotifications`, KHÔNG phải `Notifications`.** Drift sinh data
class số ít, và `Notification` là lớp có thật trong `package:flutter/widgets`.
Dự án đã dính đúng vết này với `Category` — xem dòng đầu `sync_engine.dart`:
`import 'package:flutter/foundation.dart' hide Category;`.

Bảng **cố ý không có** `syncStatus` / `syncError` / `updatedAt` / `isDeleted`.
Việc vắng mặt chúng chính là tài liệu sống nói: bảng này không đi qua
`SyncEngine`.

`schemaVersion` **12 → 13**. Migration chỉ `createTable` + tạo index; không có
dữ liệu cũ để chép vì thông báo đều suy lại được.

### 4.2 Khoá chống trùng — trái tim của thiết kế

Thông báo là dữ liệu **suy ra được**, nên mỗi lượt quét nhìn thấy lại đúng sự
kiện cũ. Toàn bộ độ khó nằm ở đây, không ở giao diện.

**Lớp 1 — ràng buộc ở SQLite:** `UNIQUE(idaccount, dedupeKey)` +
`InsertMode.insertOrIgnore`. Kiểm bằng Dart (`SELECT` rồi `INSERT`) **không
đủ**: quét kích hoạt từ nhiều nguồn, hai nguồn nổ gần nhau sẽ cùng qua nhánh
"chưa có" trước khi bên nào kịp ghi.

`insertIfAbsent` dùng **`insertReturningOrNull`**, không đọc rowid: với
`OR IGNORE`, khi đụng ràng buộc SQLite không chèn gì và `last_insert_rowid()`
**giữ nguyên giá trị lần chèn trước** — đọc nó sẽ tưởng vừa chèn thành công và
bắn lại thông báo cũ.

**Lớp 2 — công thức khoá.** Gồm *loại + chủ thể + đơn vị lặp lại*, và **tuyệt
đối không chứa giá trị biến thiên liên tục**:

| Loại | dedupeKey | Lặp lại |
|---|---|---|
| `budgetNearLimit` | `budgetNear:<id>:<đầu kỳ>:<bậc>` | mỗi kỳ × mỗi bậc |
| `budgetOverspent` | `budgetOver:<id>:<đầu kỳ>` | 1 lần/kỳ |
| `billDueSoon` | `billDue:<id>:<hạn>:<số ngày nhắc>` | 1 lần/hạn |
| `billOverdue` | `billOverdue:<id>:<hạn>` | 1 lần/hạn |

- `<đầu kỳ>` lấy từ **`BudgetEntity.currentPeriod(now).from`** — hàm đã xử lý
  ngân sách hết hạn, ngân sách không chu kỳ, và chống trôi ngày 31 → 28.
- `<bậc>` lấy từ **`budgetHealthOf()`**: `caution` (≥70%) → `critical` (≥90%)
  → `over`. Mỗi ngân sách được nhắc tối đa **một lần mỗi bậc mỗi kỳ**.

### 4.3 Xoá là xoá MỀM

`dismissedAt`, không DELETE. Hàng chính là bản ghi khoá trùng — xoá hẳn thì
lần quét sau sinh lại ngay, người dùng xoá mãi không hết.

Hệ quả: bảng chỉ lớn lên. `NotificationDao.purgeOlderThan(cutoff)` đã có
nhưng **chưa ai gọi** — xem lát 6.

### 4.4 Bộ luật

`buildNotificationCandidates(NotificationRuleInput)` là hàm thuần: `now` được
tiêm, không đọc đồng hồ, không chạm CSDL. Đây là nơi đặt gần như toàn bộ test.

Nó **GỌI** `BudgetEntity.isNearLimit` / `isOverBudget` / `budgetHealthOf()`
thay vì cài lại mốc 70/90, để màu trên thẻ và thông báo không bao giờ nói hai
chuyện khác nhau. Có test canh chính xác điều đó ("ngưỡng theo số tiền thắng
ngưỡng phần trăm" — ai cài lại bằng `rawPercentSpent >= 0.9` sẽ làm nó đỏ).

> Lệch nhỏ so với kế hoạch: luật **có** import Flutter, vì `budgetHealthOf()`
> nằm trong `budget_visuals.dart` (file import `material.dart`). Chấp nhận có
> chủ ý — một định nghĩa duy nhất của ngưỡng quan trọng hơn sự thuần khiết, và
> test vẫn chạy trong mili giây vì không chạm CSDL lẫn widget.

### 4.5 Khi nào quét

**Ba mốc, vẫn không có `Timer.periodic`** (sửa 2026-09-06 — trước đó chỉ có mốc
thứ ba):

| Mốc | Ghi chú |
|---|---|
| `start(idaccount)` | Quét ngay, `await` bên trong `start()`. Đây là mốc duy nhất chạy được khi máy hoàn toàn không có mạng |
| `AppLifecycleState.resumed` | App quay lại từ nền — mốc duy nhất bắt được quãng app nằm trong nền, quãng mà hạn hoá đơn trôi qua, ngày đổi và kỳ trích tới nơi |
| `SyncEngine.statusStream` ở trạng thái `isTerminal` | Giữ nguyên; cần cho lượt quét ngay sau khi pull mang dữ liệu mới về |

⚠️ **Vì sao phải thêm hai mốc kia.** Bản đầu buộc vòng quét vào một sự kiện
**mạng**, trong một app **offline-first** — và đó là chỗ hỏng. Khi không có kết
nối, `SyncEngine._runSync()` thoát sớm ở `SyncStatus.pending`
(`sync_engine.dart:360`), một trạng thái **không** nằm trong `isTerminal`
(`sync_models.dart:134`). Hệ quả: cả một phiên offline **không có lượt quét
nào** — không thông báo, `markOverdue` không chạy, và **hai bộ tự chuyển tiền
nằm bên trong `scan()` cũng đứng im**, nên hoá đơn bật tự trả không được trả.
Người dùng đi vùng sóng yếu một tuần thì mất cả hai.

Chỉ nghe `resumed`. `paused` và `detached` là lúc hệ điều hành sắp đóng băng
hoặc giết tiến trình; khởi động hai bộ tự chuyển tiền ở đó là chọn đúng thời
điểm chúng dễ bị cắt ngang nhất.

Nguồn sự kiện vòng đời là `lib/core/notification/app_lifecycle_watcher.dart` —
**file duy nhất** trong vùng này chạm `WidgetsBinding`, cùng lý lẽ với
`os_notifier_factory.dart`. Scanner nhận nó **qua tham số** (`appLifecycle`),
đúng khuôn `syncStatus`, nên test bơm được `StreamController` mà không phải
dựng binding. Stream **phải là broadcast**: `start()` huỷ rồi nghe lại ở mỗi
lời gọi, và stream một-người-nghe sẽ ném ngay trên đường đăng nhập.

`scan()` trả **số hàng thật sự được ghi** — tín hiệu duy nhất để quyết định có
bắn ra hệ điều hành hay không. Từ lát 4, chính danh sách hàng vừa ghi ấy (chứ
không phải danh sách ứng viên) là thứ được đẩy sang `OsNotifier.show()`.

`start()` **huỷ cả hai subscription cũ trước khi tạo mới**, và `stop()` cắt cả
hai. Được gọi ở `auth_bloc.dart` cạnh `SyncEngine.start()`; `stop()` ở hai chỗ
đăng xuất / phiên chết. **Cố ý KHÔNG gắn ở `home_page.dart`** — chỗ đó gọi
`SyncEngine.start()` ngay trong `build()`.

⚠️ Lượt quét mở màn được **`await`** bên trong `start()`, và `auth_bloc.dart`
await `start()`. Nghĩa là **hai bộ tự chuyển tiền nay chạy ngay khi đăng nhập**
chứ không phải sau chu kỳ đồng bộ đầu tiên — đó chính là điều cần sửa, nhưng nó
làm tiền chuyển sớm hơn trước ở một số tình huống. Lỗi bị nuốt tại chỗ: một
lượt quét hỏng không được phép chặn đường đăng nhập.

`silenceBefore = now − 30 ngày` chặn cơn lũ ở lần bật đầu tiên.

### 4.6 Đường đọc: `watchFeed` — lọc, phân trang (2026-09-07)

`NotificationDao.watchFeed(idaccount, {limit, kinds, chiChuaDoc})` là đường
đọc **duy nhất** của cả trung tâm thông báo lẫn panel trên Home. Ba quyết định
đáng nhớ:

- **Nhận `List<String>? kinds`, KHÔNG nhận `NotificationGroup`.** DAO nằm ở
  tầng CSDL; kéo `notification_prefs.dart` vào đó là buộc tầng lưu trữ phụ
  thuộc tầng thông báo. Trang tự quy đổi nhóm sang danh sách `kind`, và nó quy
  đổi **qua `nhomCua()`** chứ không chép tay — bảng ấy dùng `switch` không có
  `default`, nên thêm một `NotificationKind` mà quên xếp nhóm là lỗi biên dịch.
  Một danh sách chép tay ở tầng giao diện sẽ bỏ mất đúng cái lưới ấy.
- **`kinds == null` nghĩa là *không lọc*, khác hẳn danh sách rỗng** (không loại
  nào khớp). Hiểu nhầm hai thứ này là chip "Tất cả" cho ra màn hình trắng và
  không có lối quay lại. Có test canh riêng cho cả hai vế.
- **Lọc và `limit` phải nằm trong cùng một câu SQL.** Lọc ở tầng Dart sau khi
  đã cắt là truy vấn lấy đúng `limit` hàng mới nhất rồi vứt gần hết đi, trong
  khi những hàng khớp vẫn nằm nguyên trong bảng — người dùng bấm "Tải thêm"
  mãi mà danh sách không dài ra.

Trang tải **20 hàng một lần** và biết "còn hàng chưa tải" bằng cách hỏi *trang
này có đầy không* (`items.length >= _gioiHan`), không bằng một truy vấn `COUNT`
riêng. Đánh đổi đã biết và đã chấp nhận: khi số hàng chia hết cho bước trang
thì nút "Tải thêm" thừa ra một lượt — bấm vào thì danh sách không dài thêm và
nút biến mất. Rẻ hơn hẳn cái giá của một stream thứ hai đánh thức mỗi khung
hình.

Đổi bộ lọc thì **`_gioiHan` về lại trang đầu**; giữ nguyên giới hạn cũ là đổi
chip xong tải luôn sáu chục hàng của nhóm mới — đúng thứ phân trang sinh ra để
tránh.

### 4.7 Nhắc ghi chép hằng ngày (2026-09-07) — **KHÔNG đi qua bộ luật**

Vẫn **không** là một `NotificationKind`. Lời nhắc này cố ý đứng ngoài bảng ấy,
và đó là quyết định trung tâm của nó. (Lúc viết dòng này bảng có mười bốn loại;
nay là **mười lăm** sau khi thêm `goalMilestone` ngày 2026-09-08 — con số thì
đổi, còn lý lẽ dưới đây thì không.)

**Vì sao đứng ngoài bộ luật.** Mọi loại trong bảng đều là *bản ghi* một việc đã
xảy ra, và người dùng đọc lại chúng trong trung tâm thông báo. Lời nhắc này
ngược lại: nó chỉ có nghĩa khi người dùng **đang không mở app**, nên đúng lúc
họ mở ra xem trung tâm thông báo thì nó đã hết lý do tồn tại. Một dãy hàng
"hôm thứ Ba bạn không ghi gì" là nhiễu thuần tuý. Vì thế nó **không sinh hàng
nào** trong `AppNotifications`, không có `dedupeKey` ứng với hàng nào, và
không chịu công tắc nhóm nào — chỉ `osBat` và công tắc riêng của nó.

**Nó cũng là loại duy nhất suy từ việc KHÔNG có dữ liệu.** Đầu vào là
`TransactionDao.getLastTransactionDate()`. `null` trả về từ hàm ấy nghĩa là
*chưa từng ghi gì* và phải đọc thành **cần nhắc** — người mới cài app chính là
người cần nhắc nhất. Đừng lẫn với việc bỏ trống callback `loadLastTransactionAt`
của `ReminderScheduler`, vốn nghĩa là *tính năng không được nối vào*.

**Ba lịch rời, không phải một lịch lặp.** `flutter_local_notifications` có
`matchDateTimeComponents: DateTimeComponents.time` để lặp hằng ngày bằng **một**
suất lịch. Không dùng, vì lịch lặp **không bỏ qua được ngày nào**: nó nhắc cả
những hôm người dùng đã ghi rồi, mà nhắc người vừa ghi xong là đúng kiểu làm
phiền khiến họ tắt hẳn thông báo. Ba lịch rời thì `resync()` — vốn luỹ đẳng và
tự huỷ cái không còn cần — **gỡ được** lịch của hôm nay ngay khi người dùng ghi
một giao dịch, vì ghi giao dịch nghĩa là mở app, và mở app nghĩa là có lượt quét.

**Vì sao đúng ba ngày.** Trần `tranSoLich = 50` tính trên **tổng ba** nguồn, và
phép cắt sắp theo *thời gian* nên lịch hằng ngày luôn nằm gần nhất và **thắng**
nhắc hoá đơn. Hoá đơn là tiền, nhắc ghi chép là thói quen — không được đảo thứ
tự ấy. Ba suất trên năm mươi thì không đe doạ gì, mà vẫn phủ được người mở app
vài ngày một lần. Chỉ đặt **một** lịch rồi chờ lượt sau gia hạn thì người không
mở app được nhắc đúng một lần rồi im — mà đó chính là người cần nhắc nhất.

**Giờ riêng, không dùng chung `gioNhac`.** Giờ nhắc chung mặc định 08:00 vì nó
là của hoá đơn. Một câu "hôm nay ghi chép chưa" lúc 8h sáng là hỏi trước khi có
gì để ghi. Mặc định **20:00**, và **giờ im lặng không chặn nó** — đây là mốc
người dùng tự chọn và đang nhìn thấy trên màn hình.

**Câu chữ là câu HỎI** ("Hôm nay bạn đã ghi gì chưa?"). Hai lịch của ngày mai và
ngày kia được đặt lúc chưa ai biết hôm ấy có ghi gì không, nên một câu khẳng
định "hôm nay bạn chưa ghi gì" có thể nói sai — và một thông báo nói sai là thứ
người dùng tắt ngay lần đầu gặp.

**Chạm vào thì mở `/add`,** không phải `/notifications`. Đây là loại nhắc duy
nhất bảo người dùng đi làm một việc cụ thể; đổ họ về trung tâm thông báo là bắt
tự tìm đường tới chỗ ghi. `/add` nằm **ngoài** `StatefulShellRoute` nên `push`
chạy tốt — kéo nó vào một nhánh tab thì phải cập nhật `nhanhThanhTab` cùng lúc
(bẫy 7.8).

⚠️ **Đổi tuỳ chọn KHÔNG đặt lại lịch ngay.** `_ghi()` ở trang cài đặt chỉ ghi
`NotificationPrefs`; lịch chỉ theo kịp ở lượt `resync()` kế tiếp, tức lần quét
sau (mở lại app, đồng bộ xong, hoặc `start()`). Đây là **hành vi có sẵn**, đúng
như vậy với `gioNhac` và giờ im lặng từ trước — ghi lại vì trên máy thật nó
trông hệt một lỗi: gạt công tắc xong `dumpsys alarm` chưa thấy gì.

**Đã đo trên `emulator-5554`** (2026-09-07, đồng hồ máy ảo 21:34): bật → đúng
**hai** lịch 20:00 cho 08/09 và 09/09, lịch 20:00 của **hôm nay bị bỏ vì đã trôi
qua**; tắt → cả hai biến mất; bật lại → cả hai trở về. Bốn lịch hoá đơn 08:00
nguyên vẹn suốt cả ba lượt — bằng chứng rằng nguồn mới không chen mất suất của
hoá đơn.

### 4.8 Nút hành động trên thông báo (2026-09-07)

Hai nút, **chỉ** trên nhắc hoá đơn (`billDue` / `billOverdue` — xem
`coHanhDong()`): **"Trả ngay"** và **"Hoãn 1 ngày"**.

**Không có nút "Đã trả", và đó là quyết định sản phẩm chứ không phải giới hạn
kỹ thuật.** `payBill` chuyển tiền thật: tạo giao dịch, trừ ví thanh toán. Chạy
nó trong isolate nền nghĩa là chuyển tiền ở nơi không có giao diện, không xác
nhận ví, không chỗ báo lỗi khi ví thiếu tiền — đi ngược đúng nguyên tắc mà
`GOAL_FEATURE.md` mục 3.12 và spec tự trả hoá đơn đã chốt cho **hai** chỗ còn
lại trong app tự chuyển tiền. Ai muốn một chạm là trả thì đã có
`bills.autoPayEnabled`. "Trả ngay" vì thế **không ghi gì**: nó chỉ mở đúng hoá
đơn ấy.

**Mọi phép quyết định nằm ở `notification_actions.dart`** — file thuần, không
import plugin. Lý do kép: bẫy 7.7, và handler chạy trong isolate nền nơi
`flutter test` không dựng được ngữ cảnh. `os_notifier_native.dart` chỉ còn là
lớp vỏ gọi plugin.

**"Trả ngay" không nới `payloadDaCham`.** Nó đổi khoá thành `billOpen:<billId>`
rồi đi tiếp qua đúng đường cũ, vì `deeplinkTuDedupeKey()` là nơi **duy nhất**
suy route từ khoá. Nhờ vậy stream vẫn là `Stream<String>` và
`NotificationTapRouter` không phải biết nút là gì.

**"Hoãn" chạy hoàn toàn trong isolate nền** và **không** phát gì ra
`payloadDaCham` — cả điểm của nó là xong việc mà không mở màn nào. Nó dời lịch
đúng 24 giờ kể từ lúc **bấm** (một khoảng tuyệt đối, nên không cần múi giờ —
`tz.local` trong isolate nền rơi về UTC, bẫy 7.3) và **giữ nguyên khoá**.

#### Ba thứ đã hỏng trên máy thật mà `flutter test` không thấy

Cả ba đều im lặng, và cả ba chỉ lộ ra khi chạy trên `emulator-5554`.

**1. Thiếu `ActionBroadcastReceiver` trong `AndroidManifest.xml`.** Nút hiện
đúng, `dumpsys notification` cho thấy `actions=2` với `PendingIntent` kiểu
`broadcastIntent` — nhưng **không tiến trình nào nhận**: không log, không
`logcat`, thông báo cũng không tự tắt. Plugin **không tự khai báo** receiver
này; đó là bước phải làm tay, y như hai receiver kia của nó. Nay
`android_manifest_receivers_test.dart` canh **cả ba**.

**2. `resync()` huỷ mất lịch vừa hoãn.** Lý lẽ ban đầu — "cùng khoá nên cùng
id, mà resync bỏ qua id đã nằm trong hàng chờ" — **sai**, và sai theo cách chỉ
lộ ra ở ca duy nhất có thật. Nhánh bỏ qua ấy chỉ chạy cho lịch resync **muốn**,
mà một hoá đơn chỉ được muốn khi mốc nhắc còn ở **tương lai**; trong khi người
dùng chỉ bấm "Hoãn" được **sau khi** thông báo đã nổ, nên mốc gốc **luôn** đã
qua. Sửa bằng tập `khongHuy` trong `resync()`: id của mọi hoá đơn **còn sống**
(chưa trả, chưa xoá), tính **không** lọc theo mốc, và bước dọn dẹp bỏ qua
chúng. Ngoại lệ giữ **hẹp** — trả hoặc xoá hoá đơn là lịch hoãn bị dọn như mọi
lịch thừa khác, phép dọn dẹp của resync không được nới lỏng.

**3. "Trả ngay" ở cold start mở nhầm danh sách.** Một cú bấm nút có **hai**
đường vào, và bản đầu chỉ xử lý một: app đang sống thì qua
`onDidReceiveNotificationResponse`, còn app đã đóng thì nền tảng mở app rồi
`payloadKhoiDong()` hỏi `getNotificationAppLaunchDetails()` — chỗ ấy đọc
`payload` mà bỏ qua `actionId`. Nay cả hai đường gọi chung
`khoaSauChamNut()`.

> **Bằng chứng đã đo** (2026-09-07, `emulator-5554`, đồng hồ máy ảo 22:28):
> `am kill` rồi `pidof` trống → bấm "Hoãn" → `logcat` có
> `Start proc … for broadcast {…/ActionBroadcastReceiver}` và
> `I flutter : [Hoãn] isolate nền nhận "billDue:56bc…:2026-09-10:3"`, lịch mới
> ở `2026-09-08 22:28:12` (đúng +24h), thông báo tự tắt, **app không mở lên**.
> Mở app hai lượt sau đó, lịch hoãn **vẫn còn**. Bấm "Trả ngay" từ trạng thái
> app đã chết thì mở thẳng trang chi tiết đúng hoá đơn, không màn đỏ.

---

### 4.9 Badge số trên icon app (2026-09-08)

Badge mang **số chưa đọc trong app** — đúng con số `watchUnreadCount` mà chuông
trên Home đang hiện. Không có phép đếm thứ hai: hai phép đếm sẽ trôi khỏi nhau
và không ai phát hiện, vì badge sai **không ném lỗi, không ghi log**.

#### Android không có API badge thật

Điều app điều khiển được chắc chắn là **có thông báo trên khay hay không** —
Android suy chấm trên icon từ đó. Con số thì đi kèm bản tóm tắt nhóm
(`AndroidNotificationDetails.number`) và **launcher tự quyết định** vẽ số, vẽ
chấm, hay bỏ qua hẳn; chú thích của gói nói thẳng: *"Numbers are only displayed
if the launcher application supports the display of badges and numbers."*

Nên tách bạch khi đọc mã: **chấm là phần chắc chắn, số là phần có thể**. iOS thì
đặt được thẳng qua `badgeNumber`, nhưng cũng **không có API riêng** — đường duy
nhất là một thông báo mang con số ấy, tắt hết phần hiển thị (`idBadge = -2`).

> ⚠️ **Đo được trên máy thật (2026-09-08): con số gần như KHÔNG BAO GIỜ hiện
> trên Android.** Nó nằm trên bản tóm tắt nhóm, mà Android **tự gỡ bản tóm tắt
> khi nhóm chỉ còn một thông báo con** — và một là số lượng thường gặp nhất.
> `getActiveNotifications()` đếm 2 ngay sau khi bắn (con + tóm tắt), rồi
> `dumpsys notification` chỉ còn 1 vài giây sau. Thêm nữa, khi khay **trống**
> thì `datBadge(6)` chạy trót lọt nhưng chẳng hiện gì cả: không có thông báo con
> thì bản tóm tắt cũng không được hiển thị.
>
> **Hệ quả cần nhớ:** trên Android badge thực chất là **chấm**, và chấm suy từ
> *thông báo đang trên khay*, không từ số chưa đọc. Nghĩa là còn 6 mục chưa đọc
> trong app mà khay trống thì **không có chấm** — Android không cho làm khác,
> trừ khi đăng một thông báo trống chỉ để giữ chấm, và điều đó tệ hơn hẳn thứ nó
> đổi lấy. Con số vì thế là phần **thêm vào cho launcher nào vẽ được và cho
> iOS**, không phải phần chính.

#### Vì sao đọc hết trong app phải dọn khay

Đọc hết mà không đụng tới khay thì thông báo vẫn nằm nguyên đó, nên **chấm sáng
vĩnh viễn** — badge chỉ đúng một nửa. Đây là lý do mục này từng bị xếp là "nửa
việc riêng".

#### ⚠️ Nhưng dọn SẠCH khay là sai — có thông báo mà bảng không biết

Ca hỏng nguy hiểm nhất của cả mục này, và nó **im lặng**:

- **Lịch nhắc hoá đơn nổ lúc app đóng.** Hàng trong bảng chỉ sinh *sau đó*, khi
  app mở và vòng quét chạy (xem đầu `reminder_scheduler.dart`). Trước lúc ấy
  khay có, bảng trống.
- **Nhắc ghi chép hằng ngày** thì *không bao giờ* sinh hàng — mục 4.7.

Nghĩa là **số chưa đọc bằng 0 KHÔNG có nghĩa là khay phải trống**. Dọn sạch ở
đó là xoá mất một lời nhắc thật trước khi người dùng kịp nhìn.

`BadgeUpdater.dongBo()` vì thế đi từ **chiều ngược lại**: chỉ huỷ những id suy
ra được từ `dedupeKey` của một hàng **đã đọc hoặc đã xoá mềm**, rồi giao tập ấy
với khay. Id nào không khớp hàng nào thì **được giữ nguyên** — nên nhắc ghi chép
miễn nhiễm **theo cấu trúc**, không nhờ một điều kiện `if` mà người sau có thể
dọn nhầm.

#### Ba thứ dễ làm hỏng nhất

**1. `cancelAll()` — tuyệt đối không dùng để dọn khay.** Nó cuốn theo **cả lịch
đang chờ** trong AlarmManager, tức xoá sạch mọi nhắc hoá đơn chưa nổ. Cùng họ
với lỗi đã làm mất lịch vừa hoãn ở phiên trước, và nó **không lộ ra cho tới ngày
lời nhắc lẽ ra phải tới**. Có test canh riêng.

**2. Bản tóm tắt chỉ được gỡ khi không còn thông báo con nào.** Còn con mà gỡ
tóm tắt là chúng bung ra nằm rời rạc — đúng thứ `groupKey` sinh ra để tránh. Và
"còn con" là chuyện thường, xem ca nhắc ghi chép ở trên.

**3. Duyệt khay phải duyệt trên bản sao.** `cancel()` làm thông báo rời khay,
nên một bản cài đặt trả về tập sống sẽ bị sửa ngay giữa vòng lặp. Lỗi ấy rơi
thẳng vào `catch` bao ngoài, tức badge **lặng lẽ ngừng cập nhật**. Đã vấp đúng
một lần khi viết test: bản giả trả thẳng tập gốc, `ConcurrentModificationError`
bị nuốt, và một test lẽ ra phải đỏ thì **xanh oan**.

#### Vòng đời

`NotificationScanner` **sở hữu** `BadgeUpdater`: `start()`/`stop()` lan truyền
xuống. Lý do là `auth_bloc` đã có bốn chỗ gọi start/stop, và một lối song song
nghĩa là bốn chỗ nữa phải nhớ — chỗ bị quên sẽ cập nhật badge của người vừa đăng
xuất bằng dữ liệu người mới. `stop()` gọi **trước** `cancelAll()`, nếu không lượt
đẩy cuối dựng lại đúng bản tóm tắt vừa gỡ đi.

#### `catch` phải ghi log, không được câm

`dongBo()` nuốt lỗi có chủ ý (nó chạy trong một stream suốt vòng đời app), nhưng
nó **ghi lại bằng `debugPrint`**. Badge lệch không ném ra đâu cả, nên một `catch`
câm biến mọi trục trặc ở đây thành thứ không chẩn đoán được — đã mất một vòng
dựng lại APK vì đúng điều đó. Dòng log ấy (`badge=N, khay=M, đã huỷ=K`) chính là
thứ đã phân định được "code không chạy" với "code chạy đúng nhưng Android không
vẽ".

> **Bằng chứng đã đo** (2026-09-08, `emulator-5554`, Pixel Launcher):
> tạo hoá đơn tuần hạn 10/09 → `[BadgeUpdater] badge=7, khay=2, đã huỷ=0`, và
> **icon app hiện chấm**. Bấm "Đọc tất cả" → `badge=0, khay=1, đã huỷ=1`,
> `dumpsys notification` còn **0** record của app, và **chấm tắt**. Ảnh so sánh
> hai trạng thái icon đã chụp. Ca "khay trống nhưng còn 6 chưa đọc" cũng đo
> được: `badge=6, khay=0` — chạy trót lọt, không hiện gì, đúng như giới hạn nền
> tảng nói ở trên.

---

## 5. Đã làm gì cho hoá đơn (lát 3)

- `BillDraft` mang `timeNotification`; **cả hai form ghi thật**. Đường Sửa ghi
  `Value(null)` chứ không bỏ trống companion — `updateFields` chỉ ghi cột **có
  mặt**, nên vắng mặt thì tắt nhắc nhở không có tác dụng gì.
- Bổ sung mốc **'7 ngày'** mà CSDL cho phép ở cả hai đầu nhưng UI đang thiếu.
- **Vá `BillDao.getUpcoming`**: nó lọc `isPaid` mà không lọc `payStatus`. Hàng
  kéo về từ backend có thể mang `payStatus = 'Payed'` trong khi `isPaid` còn
  false → người dùng bị giục trả hoá đơn đã thanh toán.
- **`BillDao.markOverdue`** ghi `payStatus = 'Overdue'` — giá trị chưa bao giờ
  được ghi trong toàn bộ `lib/`. **Có điều kiện `payStatus = 'Pending'`**: xem
  bẫy 7.4.

---

## 5b. Chạm vào thông báo hệ điều hành (2026-09-06)

Trước ngày này, `onDidReceiveNotificationResponse` là một **callback rỗng**:
cú chạm mở app ra trang chủ và người dùng phải tự đi tìm lại thứ vừa hiện trên
màn hình khoá. Hạ tầng đã có sẵn (`payload = dedupeKey`, và `thuocThanhTab()`
đã giải xong phần khó là `go` hay `push`), chỉ thiếu đoạn nối.

```
lib/core/notification/notification_tap_router.dart   # nơi DUY NHẤT điều hướng
lib/core/notification/notification_deeplink.dart     # + deeplinkTuDedupeKey()
lib/core/notification/os/os_notifier.dart            # + payloadDaCham, payloadKhoiDong
```

**`deeplinkTuDedupeKey()` là một bản SAO của `NotificationCandidate.deeplink`,
và đó là chủ ý.** Ở **cold start** — lịch nhắc nổ khi app đã đóng hẳn, tức là
ca *chính* của lịch đặt trước — hàng tương ứng còn chưa tồn tại trong SQLite:
vòng quét mới sinh ra nó *sau khi* app khởi động xong. Tra cột `deeplink` ở đó
là một cuộc đua, và thua cuộc đua ấy nghĩa là cú chạm không đi đâu cả.

Bản sao ấy được canh bằng một test duyệt **cả 15 loại**: nó dựng ứng viên thật
từ bộ luật rồi khẳng định hàm suy ra đúng cột `deeplink`. Thêm loại thứ 14 mà
quên ánh xạ là test đỏ ngay.

**Hai đường vào, một lối ra.** `payloadDaCham` (app đang sống) và
`payloadKhoiDong()` (app mở lên *vì* cú chạm) cùng đổ vào `NotificationTapRouter`.

⚠️ **Trên Android một cú chạm có thể đến bằng CẢ HAI đường.** `start()` vì thế
đọc chi tiết khởi động **trước** khi nghe stream, rồi nhớ payload ấy để bỏ qua
**đúng một lần**. Nhớ mãi thì thông báo ấy chết vĩnh viễn trong cả phiên chạy;
không nhớ thì màn hình nhảy hai lần, và với route dùng `push()` là chồng hai
trang lên nhau.

⚠️ **Chưa đăng nhập thì GIỮ LẠI, không vứt đi.** Token hết hạn sau vài ngày app
đóng là chuyện thường, và điều hướng lúc ấy chỉ bị guard của router đá về
`/login`. Chỉ giữ cú chạm **mới nhất**: xả cả hàng đợi sau khi đăng nhập là app
tự nhảy qua mấy màn liên tiếp.

**Chạm KHÔNG đánh dấu đã đọc.** Ở cold start hàng chưa tồn tại, nên đánh dấu
đúng lúc lại là một cuộc đua nữa — đổi lấy quá ít. Thông báo ở lại trung tâm
như lịch sử.

⚠️ `FlowMoneyApp` nay là **StatefulWidget**, đừng đổi ngược lại.
`AppRouter.createRouter()` trước đây bị gọi ngay trong `build()` — mỗi lần
widget gốc dựng lại là một `GoRouter` mới và mất cả stack điều hướng. Nay nó
được tạo một lần trong `initState`, và chính tham chiếu ấy cho phép điều hướng
từ ngoài cây widget: cú chạm đến từ nền tảng, không kèm `BuildContext` nào.

---

## 5c. Giờ im lặng, gộp thông báo, hoàn tác vuốt xoá (2026-09-06)

**Giờ im lặng** — `NotificationPrefs.dangImLang(luc)`, chặn ngay trước
`_banRaHeDieuHanh`. Chỉ chặn **bước bắn ra hệ điều hành**; hàng vẫn ghi vào
trung tâm trong app, đúng ngữ nghĩa công tắc tổng: "đừng đánh thức tôi", không
phải "đừng ghi lại gì". Người dùng ngủ dậy mở app vẫn thấy đủ những gì đã xảy
ra đêm qua.

- **Mặc định TẮT.** Bật sẵn là lặng lẽ đổi hành vi của mọi bản đã cài — cùng lý
  lẽ với việc lưu *nhóm bị tắt* thay vì *nhóm được bật*.
- Hai mốc lưu bằng **số phút từ nửa đêm**, một trục duy nhất. Khoảng giờ im
  lặng gần như luôn **vắt qua nửa đêm**, và đó là nơi phép so trần
  (`tu <= x < den`) trả sai đúng nửa khoảng — có test canh riêng.
- Hai mốc **trùng nhau** nghĩa là khoảng rỗng, **không phải cả ngày**: người
  dùng lỡ tay đặt bằng nhau không được mất sạch thông báo.
- **Lịch đặt trước không đi qua đây.** Giờ nhắc là do người dùng tự chọn và
  đang nhìn thấy trên màn hình; app không đoán lại hộ họ.

**Gộp thông báo Android** — mọi thông báo mang chung `khoaNhom`, kèm một **bản
tóm tắt**. Từ Android 7, đặt `groupKey` mà không có bản tóm tắt thì chúng vẫn
nằm rời và công sức gộp coi như không có.

- Id bản tóm tắt là **số âm** (`-1`). `osScheduledId()` xoá bit dấu nên luôn
  trả 0..2^31-1; chọn số âm là cách **duy nhất** bảo đảm nó không bao giờ ghi
  đè một thông báo thật — mà nếu đụng thì hỏng hoàn toàn im lặng.
- Bản tóm tắt đăng **sau** thông báo thật, để mọi phép kiểm và mọi người đọc
  log đều thấy lời gọi đầu tiên là thứ nơi gọi vừa yêu cầu.
- ⚠️ **Chỉ Android.** iOS gộp theo `threadIdentifier` và không có khái niệm bản
  tóm tắt; đăng thêm ở đó là một thông báo **trống** trên màn hình khoá, và nó
  không bao giờ lộ ra trong một lần kiểm chạy trên Android. Có test canh.

⚠️ **Đổi chi tiết thông báo KHÔNG áp dụng ngược cho lịch đã đặt.** Đo được trên
emulator-5554 ngày 2026-09-06: hai lịch nhắc nổ ra **không mang `khoaNhom`**,
và `run-as … cat shared_prefs/scheduled_notifications.xml` cho thấy bản ghi
lưu sẵn không có trường ấy.

Lý do nằm ở chính tính **luỹ đẳng** của `resync()`: nó chỉ đặt những id **chưa**
có trong `pendingIds()`. Lịch đã nằm trong hàng đợi giữ nguyên bộ chi tiết mà
`flutter_local_notifications` đã *tuần tự hoá lúc đặt* — tức là của bản app cũ.
Chúng chỉ nhận cấu hình mới khi `dedupeKey` đổi (hạn trả mới, số ngày nhắc mới)
hoặc sau một lần `cancelAll()` (đăng xuất).

Hệ quả thực tế: mọi thay đổi về hình thức thông báo **đến dần** với người dùng
cũ, không đến ngay. Ai sửa phần này rồi kiểm trên một máy đã cài bản trước sẽ
thấy "không có tác dụng" và đi tìm lỗi ở sai chỗ.

Riêng phần hiển thị thì Android 16 **tự gộp** thông báo cùng app
(`AUTOGROUP_SUMMARY`), nên người dùng vẫn thấy một cụm ngay cả khi khoá nhóm
của app chưa tới. Đừng vì thế mà kết luận `khoaNhom` đang chạy — kiểm bằng
`dumpsys notification` chứ không bằng mắt.

✅ **Đã kiểm bằng `dumpsys` ngày 2026-09-07** trên `emulator-5554`, và bằng
chứng quyết định **không** phải hai dòng `groupKey` mà là bảng nhóm→tóm tắt của
hệ điều hành:

```
0|com.flowmoney.flowmoney|g:flowmoney_alerts_group -> 0|com.flowmoney.flowmoney|-1|null|10227
```

Nó trỏ vào **bản tóm tắt id −1 của app**, tức nhóm này do app cầm chứ không
phải `AUTOGROUP_SUMMARY` của Android — đây mới là chỗ tách bạch được hai khả
năng. Kèm theo: bản tóm tắt mang `flags=AUTO_CANCEL|GROUP_SUMMARY`,
`android.text=null`, `groupAlertBehavior=2`, còn `mSoundNotificationKey` và
`mVibrateNotificationKey` đều trỏ về **thông báo thật** — `children` chạy đúng,
bản tóm tắt im lặng.

Đường `zonedSchedule` cũng xác nhận, và xác nhận luôn cảnh báo ngay trên: trong
ba lịch đang chờ lúc ấy, hai lịch do bản hiện tại đặt **có** `groupKey` trong
`scheduled_notifications.xml`, còn lịch đặt từ bản trước thì **không**.

**Hoàn tác vuốt xoá** — `NotificationDao.khoiPhuc(id)` gỡ `dismissedAt`, kèm
SnackBar "Đã xoá thông báo · Hoàn tác". Cần thiết vì hàng đã xoá **vẫn nằm
trong bảng** để chặn trùng: lượt quét sau nhìn thấy `dedupeKey` ấy rồi bỏ qua,
nên không có hàm này thì một cú vuốt nhầm làm thông báo mất khỏi giao diện
**vĩnh viễn**.

⚠️ `NotificationCenterPage` nay nhận `idaccount` từ **route**, không tự hỏi
`AuthBloc` — cùng mẫu `NotificationSettingsPage`. Bản đầu viết
`idaccount ?? currentAccountIdOrNull(context)` và đó là lỗi thật: `null` khi ấy
mang **hai nghĩa** ("chưa đăng nhập" và "chưa truyền, đi hỏi AuthBloc"), nên
trạng thái chưa đăng nhập không biểu diễn được nếu cây không có provider — nó
ném `ProviderNotFoundException` ngay giữa `build`.

---

## 6. Từng lát đã làm gì

### Lát 4 — `OsNotifier` + thông báo hệ điều hành thật ✅ XONG

Gói đã thêm: `flutter_local_notifications ^22.3.0`, `timezone ^0.11.1`,
`flutter_timezone ^5.1.0` (hai gói sau chưa dùng — chúng là của lát 5, thêm
sẵn để chỉ chạm `pubspec.yaml` một lần).

```
lib/core/notification/os/
  os_notifier.dart          // abstract OsNotifier + NoopOsNotifier
  os_notifier_factory.dart  // conditional import — file DUY NHẤT dẫn tới native
  os_notifier_native.dart   // io — nơi DUY NHẤT import flutter_local_notifications
  os_notifier_web.dart      // no-op
  os_notifier_stub.dart     // no-op
  os_scheduled_id.dart      // md5(dedupeKey) -> int 31 bit
```

⚠️ **Lệch một điểm so với kế hoạch, có chủ ý.** Kế hoạch nói gộp trừu tượng và
conditional import vào `os_notifier.dart` theo mẫu
`lib/core/database/connection/`. Đã tách làm hai file. Lý do: gộp lại thì mọi
file nhắc tới kiểu `OsNotifier` — kể cả `notification_scanner.dart` và các test
của nó — đều kéo theo nhánh native, tức là kéo `flutter_local_notifications`.
Tách ra thì chỉ đúng **một** file trong toàn dự án chạm gói ấy, và bẫy 7.7
kiểm được bằng mắt trong một giây.

**API của plugin bản 22 khác bản cũ** — `initialize(settings: ...)` và
`cancel(id: ...)` đều là tham số **có tên**, không phải vị trí. Mọi ví dụ tìm
được trên mạng đều viết theo bản cũ; đọc thẳng
`lib/src/flutter_local_notifications_plugin.dart` trong pub cache.

Đã làm: `POST_NOTIFICATIONS` + `RECEIVE_BOOT_COMPLETED` và hai `<receiver>`
trong manifest; `isCoreLibraryDesugaringEnabled` + `desugar_jdk_libs:2.1.4`
trong `build.gradle.kts`; gán `UNUserNotificationCenter.delegate` trong
`AppDelegate.swift`; đăng ký `OsNotifier` trong `injection_container.dart` và
truyền vào `NotificationScanner`. **Không** khai `SCHEDULE_EXACT_ALARM` /
`USE_EXACT_ALARM` — lý do ghi thành chú thích ở cả manifest lẫn
`os_notifier_native.dart`, vì "nhắc hoá đơn nên chính xác" nghe rất hợp lý và
người sau sẽ muốn đổi.

`NotificationScanner` giờ: bắn `show()` cho **danh sách vừa ghi** (không phải
danh sách ứng viên — ứng viên chứa lại sự kiện cũ ở mọi lượt quét), nuốt lỗi
từng cái một, và `stop()` gọi `cancelAll()`.

**Còn thiếu để chạy thật:** không nơi nào gọi `requestPermission()` — trang
cài đặt là lát 7. Xem cảnh báo ở đầu tài liệu.

### Lát 5 — `zonedSchedule` đặt lịch trước cho hoá đơn ✅ XONG

`lib/core/notification/reminder_scheduler.dart`. Cách **duy nhất** để
thông báo nổ khi app đóng mà không cần tác vụ nền: scanner chỉ chạy khi app mở,
nên người dùng đóng app ba ngày là không có lượt quét nào.

`main.dart` gọi `_khoiTaoMuiGio()` (`tzdata.initializeTimeZones()` +
`flutter_timezone`) **trước** `setupDependencies()`. Nuốt lỗi và lùi về UTC:
không đọc được múi giờ thì nhắc sai giờ, còn ném thì app không khởi động được.

**`resync()` luỹ đẳng theo tập id, không phải huỷ-rồi-đặt-lại.** Nó đọc
`osNotifier.pendingIds()`, huỷ những id không còn cần và chỉ đặt những id chưa
có. `resync` chạy sau **mỗi** lượt quét, tức sau mỗi lần đồng bộ; huỷ-rồi-đặt-
lại toàn bộ ở mỗi lượt là mỗi lượt thêm một cơ hội để lịch rơi mất. Đó là lý do
`OsNotifier` có thêm `pendingIds()`.

Trần **50 lịch**, cắt bỏ những mốc **xa** nhất (bẫy 7.5). Cửa sổ 30 ngày, khớp
`NotificationScanner.cuaSoSuKien`.

**Điểm nối với thông báo trong app: `billDueDedupeKey()`** — hàm công khai
trong `notification_rules.dart`, dùng bởi **cả** bộ luật lẫn bộ đặt lịch. Lịch
mang `payload = dedupeKey`; lịch nổ lúc app đóng → người dùng bấm → app mở →
quét chạy → `insertOrIgnore` sinh đúng hàng ấy, một lần. Trước lát này khoá
được dựng bằng chuỗi nội tuyến trong bộ luật; trích ra thành hàm là để hai nơi
không thể lệch nhau.

Tuỳ chọn **"nhắc trước N ngày"** của lát 7 nay được tiêu thụ thật:
`NotificationRuleInput.defaultBillLeadDays` và `billLeadDays()`. Số ngày đặt
riêng cho một hoá đơn vẫn thắng giá trị mặc định chung.

`AndroidScheduleMode.inexactAllowWhileIdle`, có test canh riêng — xem lát 4.

### Lát 6 — Mục tiêu, đồng bộ, ví âm ✅ XONG

**`GoalEntity` nay có `progress` / `daysLeft(now)` / `isBehindSchedule(now)`**,
đặt trong chính entity chứ không trong bộ luật: trang mục tiêu cũng cần đúng
những con số này, và hai nơi tự tính là thẻ nói "đúng tiến độ" còn thông báo
nói "đang trễ".

⚠️ **`GoalEntity` phải thêm trường `startDate`** — cột đã có trong Drift nhưng
entity không mang, và `toCompanion()` cũng không ghi nó, nên mỗi lần ghi lại
mục tiêu là mốc bắt đầu bị xoá. Không có mốc ấy thì `isBehindSchedule` không có
nhịp để so. Trường là **nullable**: mục tiêu tạo bởi bản app cũ không có nó, và
khi thiếu thì hàm trả `false` chứ không đoán bừa.

**Biên dung sai 5%** (`GoalEntity.bienDungSai`). Nhịp kỳ vọng là tuyến tính
theo ngày còn người dùng nhận lương theo tháng, nên tiến độ thật luôn dao động
quanh đường ấy. Bản đầu không có biên và một mục tiêu lệch **0,6%** đã bị báo
"chậm tiến độ" — test bắt được, và đó là loại nhiễu dạy người dùng rằng thông
báo của app không đáng tin.

**Đơn vị lặp lại trong `dedupeKey` — điểm khó nhất của lát này.** Bốn loại mới
không có "kỳ" tự nhiên như ngân sách (chu kỳ) hay hoá đơn (hạn trả):

| Loại | dedupeKey | Lặp lại | Vì sao |
|---|---|---|---|
| `goalCompleted` | `goalDone:<id>` | **một lần trong đời** | Thêm mốc thời gian là mỗi kỳ lại chúc mừng lại cùng một việc |
| `goalBehind` | `goalBehind:<id>:<yyyy-MM>` | mỗi tháng | Trễ tiến độ kéo dài hàng tháng trời |
| `goalMilestone` | `goalMilestone:<id>:<startDate>:<25\|50\|75>` | **một lần mỗi mốc, mỗi vòng** | Hai đoạn đuôi phục vụ hai việc khác nhau: `<mốc>` giữ ba mốc không nuốt nhau, còn `<startDate>` là thứ khiến mục tiêu **lặp lại** được báo lại từ vòng hai — cùng khuôn `goalCycle:`, cố ý KHÁC khuôn `goalDone:` |
| `goalAutoDeposited` | `goalAuto:<id>:<yyyy-MM-dd của KỲ>` | mỗi kỳ trích | Quét chạy sau mọi lần đồng bộ; thiếu đơn vị lặp là mỗi lần mở app thêm một "Đã trích" cho việc chỉ xảy ra một lần. Hai kỳ khác nhau vẫn phải ra hai thông báo — trích bù hai tháng là hai lần tiền rời ví |
| `goalAutoDepositFailed` | `goalAutoFail:<id>:<yyyy-MM-dd của KỲ>` | mỗi kỳ trích | Như trên |
| `walletNegative` | `walletNeg:<id>:<yyyy-MM-dd>` | mỗi ngày | Ví âm cho tới khi người dùng nạp tiền |
| `walletLowBalance` | `walletLow:<id>:<yyyy-MM-dd>` | mỗi ngày | Ví cạn cho tới khi người dùng nạp tiền — cùng lý lẽ (thêm 2026-09-07) |
| `syncFailed` | `syncFailed:<yyyy-MM-dd>` | mỗi ngày | Mất mạng là hỏng ở **mọi** chu kỳ đồng bộ |

`syncFailed` là **người tiêu thụ đầu tiên** của `SyncEngine.statusStream` cho
mục đích hiển thị. Cờ được **đặt lại về false** khi lượt đồng bộ kế tiếp thành
công; không xoá là mỗi lượt quét về sau đều báo lại một sự cố đã qua.

`NotificationScanner.start()` nay gọi `purgeOlderThan(90 ngày)` — một lần mỗi
phiên, nuốt lỗi. Bảng chỉ lớn lên vì hàng đã xoá mềm phải giữ để chặn trùng.

### Lát 7 — Màn cài đặt ✅ XONG · tài liệu backend ⏳ CÒN

```
lib/core/notification/prefs/
  notification_prefs.dart        # Model thuần + enum NotificationGroup
  notification_prefs_store.dart  # Interface + bản SecureStorage + bản in-memory

lib/features/notification/presentation/pages/
  notification_settings_page.dart   # /settings/notifications
```

**Nơi lưu:** khoá JSON `notification_prefs_<idaccount>` trong
`FlutterSecureStorage`, đúng mẫu `SecureStorageSyncCheckpointStore`.

**Lưu nhóm bị TẮT chứ không phải nhóm được bật.** Nhờ vậy mặc định là "bật
hết" mà không cần biết trước danh sách nhóm: thêm nhóm thứ năm ở bản sau thì
mọi bản ghi cũ tự động bật nhóm ấy. Lưu danh sách bật thì mọi bản ghi cũ sẽ
thiếu nhóm mới và nó chết ngay từ đầu.

**Hai công tắc có ý nghĩa khác nhau, đừng gộp:**

| Công tắc | Hiệu lực |
|---|---|
| Bốn công tắc **nhóm** | Không **sinh** thông báo nhóm ấy — cả trong app lẫn ra hệ điều hành. Lọc ngay sau bộ luật, trước khi ghi. **Trừ bốn loại `luonBao()`** — xem mục 3. |
| Công tắc **tổng** cho OS | Vẫn ghi vào trung tâm trong app, chỉ **không bắn** ra ngoài. Đây là "đừng làm phiền tôi", không phải "đừng ghi lại gì". Đây cũng là **lối thoát duy nhất** cho bốn loại `luonBao()`. |

⚠️ **Công tắc tổng hiển thị SỰ THẬT, không phải chỉ ý muốn.** `OsNotifier`
có `daCoQuyen()` — câu **hỏi**, khác hẳn `requestPermission()` là câu **xin** —
và trang cài đặt gọi nó mỗi lần mở. Người dùng có thể thu hồi quyền trong Cài
đặt của máy sau khi đã bật công tắc; để nó sáng khi ấy là nói dối, và họ sẽ
không bao giờ đi tìm lý do vì sao chẳng nhận được gì. Đã gặp thật trên
emulator-5554 ngày 2026-09-06: `importance=NONE` mà công tắc vẫn bật.

Giá trị hiển thị là `_prefs.osBat && _coQuyenOs`, nhưng **`osBat` trong kho giữ
nguyên**: cấp lại quyền trong Cài đặt máy là thông báo chạy lại ngay, không bắt
người dùng vào gạt lại lần nữa. Tuyệt đối **không xin quyền** lúc mở trang — iOS
chỉ hỏi một lần trong cả vòng đời cài đặt.

**Bật công tắc tổng là chỗ DUY NHẤT trong app xin quyền thông báo** — mắt xích
còn thiếu của lát 4. Xin đúng lúc người dùng vừa chủ động bật, không phải lúc
mở app: trên iOS họ chỉ được hỏi **một lần** trong cả vòng đời cài đặt. Hệ điều
hành từ chối thì công tắc **quay về tắt** kèm một SnackBar chỉ đường sang Cài
đặt máy — để nó sáng là nói dối, người dùng sẽ không bao giờ đi tìm lý do vì
sao chẳng nhận được gì.

**Trang không có nút Lưu**, mỗi thay đổi ghi thẳng xuống kho. Trang cài đặt
kiểu này không ai đi tìm nút lưu.

⚠️ **Trang không tự hỏi `AuthBloc`** — route đọc `currentAccountIdOrNull(ctx)`
rồi truyền `idaccount` vào, cùng mẫu `NotificationPanel`. Bản đầu làm ngược
lại và test "chưa đăng nhập" treo ở `pumpAndSettle`: không có `AuthBloc` trong
cây thì `context.read` ném **trong** `postFrameCallback`, cờ `_dangNap` kẹt
`true`, và vòng quay tải chạy mãi. Trạng thái "chưa đăng nhập" phải test được
thật sự chứ không phải suy ra từ một ngoại lệ thiếu provider.

Mục "Thông báo" trong Profile nay dẫn tới **trang cài đặt**; lối vào trung tâm
thông báo là chuông ở trang chủ.

**Số ngày nhắc là danh sách rời (0/1/2/3/5/7), không phải ô nhập số.** Nhập tay
mở đường cho những giá trị mà `NotificationPrefs` sẽ lặng lẽ quy về mặc định —
người dùng gõ 400 rồi thấy số nhảy về 3 và không hiểu vì sao.

Stitch **không có** màn này; bố cục bám đúng kiểu thẻ của `settings_page.dart`.

#### Tài liệu backend ✅ XONG

`docs/superpowers/backend/DA-XONG/2026-09-04-notification-backend.md`, đã nối vào mục 3
của README backend.

**Kết luận: backend không cần làm gì để tính năng này chạy.** Thông báo là cục
bộ trên từng máy, nên PostgreSQL **cố ý không có** bảng `notification`.

⚠️ **Một trong bốn việc dự kiến hoá ra là nhận định SAI.** Bản bàn giao trước
ghi `bill.time_notification` "không nằm trong payload đẩy". Kiểm lại mã thật:
nó có ở **cả sáu chặng** — client dựng payload (`sync_engine.dart:1089`), hợp
đồng tên trường (`sync_payload_contract_test.dart:251`), backend chuẩn hoá tên
(`sync.repository.js:71`), ghi khi tạo (`:385`), ghi khi cập nhật (`:406`), và
client đọc lại khi pull (`sync_engine.dart:741`). Không có việc gì phải làm.
Đính chính được ghi lại trong tài liệu backend thay vì xoá lặng lẽ, vì nhận
định sai ấy đã đi qua ít nhất hai bản tài liệu.

Ba việc còn lại là thật nhưng **không chặn gì hôm nay**. ⚠️ Cập nhật 2026-09-07: **socket đã được xác thực** (JWT ở handshake, 0 `io.emit`), nên vế "chưa xác thực" trong đoạn dưới đã hết đúng — phần còn thiếu chỉ là client chưa có luồng OCR/ngân hàng. 
(đã là bước 1 vì lý do khác, và client **cố ý chưa nối socket**), backend không
có scheduler, queue `send-notification` rỗng cả ba phía — không ai đẩy việc
vào, worker 0 byte, và `index.js` cũng không nạp worker ấy.

#### Khoảng trống đã biết của lát 7

- `NotificationPrefsStore.clear()` đã có nhưng **chưa ai gọi**. Hiện tuỳ chọn
  ở lại máy sau khi đăng xuất — đúng ý (đăng nhập lại thì còn nguyên), nhưng
  nếu sau này có luồng "xoá sạch dữ liệu tài khoản" thì phải gọi nó.
- Giờ nhắc và số ngày nhắc **được lưu nhưng chưa ai đọc** — lát 5 là nơi tiêu
  thụ chúng.

## 7. Bẫy — đọc trước khi sửa bất cứ thứ gì trong vùng này

**7.1 Trùng lặp.** Ba cách hỏng: khoá trùng chỉ ở tầng Dart; `dedupeKey` chứa
số biến thiên (`spent`, phần trăm thô); vuốt xoá bằng DELETE thay vì
`dismissedAt`. Cả ba **không làm app chết**, chỉ khiến người dùng tắt thông báo
và không bao giờ bật lại.

**7.2 Đổi người đăng nhập — lỗ nghiêm trọng nhất, CHƯA XỬ LÝ HẾT.**
`purgeDataForOtherAccounts` đã thêm bảng thông báo và có test canh. Nhưng khi
làm lát 4, **`stop()` PHẢI gọi `osNotifier.cancelAll()`**. Không có nó thì lịch
hoá đơn của người trước vẫn nổ **trên màn hình khoá** sau khi người khác đăng
nhập — dữ liệu tài chính ra khỏi app hoàn toàn, và `purgeDataForOtherAccounts`
không cứu được vì lịch nằm trong AlarmManager/UNUserNotificationCenter chứ
không trong SQLite.

**7.3 Múi giờ.** Quên `tz.initializeTimeZones()` + `tz.setLocalLocation()` thì
`zonedSchedule` chạy theo UTC, nhắc lệch 7 tiếng ở Việt Nam — **không có lỗi
nào báo ra**. Người dùng đổi múi giờ thì lịch cũ neo múi giờ cũ; chữa bằng
`resync()` mỗi lần `start()`.

**7.4 Đừng bỏ điều kiện của `markOverdue`.** Nó ghi có điều kiện
`payStatus = 'Pending'`. Quét chạy sau **mọi** lần đồng bộ, nên ghi lại vô điều
kiện là bản ghi luôn ở trạng thái `pending` — đẩy lên rồi lại `pending` — một
vòng lặp đẩy vô tận không có lỗi nào báo ra.

**7.5 Giới hạn 64 lịch chờ trên iOS.** Vượt thì iOS **âm thầm** giữ 64 cái gần
nhất và bỏ phần còn lại — không lỗi, không log.

**7.6 `home_page.dart` gọi `SyncEngine.start()` trong `build()`.**
`SyncEngine` chịu được vì `start()` gần như luỹ đẳng. Chép mẫu đó cho
`NotificationScanner` thì mỗi lần Home rebuild là thêm một listener → n thông
báo cho một sự kiện. Đã chặn hai lớp, nhưng đây là chỗ người bảo trì sau sẽ vô
tình phá.

**7.7 Import `flutter_local_notifications` lọt ra ngoài
`os_notifier_native.dart`** → gãy `flutter build web`, và **`flutter test` vẫn
xanh** nên không ai biết cho tới lúc phát hành. Từ lát 4 trở đi, chạy
`flutter build web` sau mỗi lát.

**7.8 `push` một route nằm TRONG `StatefulShellRoute` từ một trang ngoài shell
→ app chết màn đỏ.** go_router phải dựng thêm một bản shell thứ hai chồng lên
bản đang có, hai bản trùng page key, và `Navigator` ném
`!keyReservation.contains(key)`. Đây là chuyện đã xảy ra: bấm vào thông báo
ngân sách từ `/notifications` (ngoài shell) sang `/budget` (trong shell).

Dùng `thuocThanhTab()` trong `notification_deeplink.dart` để chọn `go` hay
`push`. Bốn nhánh tab là `/home`, `/analytics`, `/budget`, `/profile` — danh
sách ấy giữ đồng bộ **tay** với `app_router.dart`.

⚠️ Ba deeplink còn lại (`/bills`, `/goals/<id>`, `/wallets`) đều **ngoài** shell
nên `push` chạy tốt. Ba phần tư đường đi đúng chính là lý do lỗi này lọt qua mọi
vòng kiểm trước đó.

⚠️ **`ReminderScheduler` đặt lịch cho CẢ HAI loại**, và đó không phải lựa chọn
thẩm mĩ. `resync()` huỷ **mọi** lịch chờ không nằm trong tập nó muốn — tách
thành hai bộ đặt lịch riêng là mỗi bên xoá sạch lịch của bên kia ở mỗi lượt
chạy, im lặng, và chỉ lộ ra khi người dùng phàn nàn rằng nhắc hoá đơn đã ngừng
hoạt động. Trần 50 cũng vì thế phải tính trên **tổng** hai loại: iOS đếm chung
một hàng đợi 64 lịch.

Lịch nhắc kỳ trích nổ vào **mốc của chính kỳ** (giờ người dùng chọn), không phải
`prefs.gioNhac` — giờ nhắc chung là của hoá đơn. Nó mang **đúng khoá**
`goalAuto:<...>` của thông báo "đã trích" cho kỳ ấy, nên cùng `osScheduledId`:
khi khoản trích chạy xong, thông báo kia **thay chỗ** lời nhắc thay vì nằm cạnh
nó. Hai thông báo cho một sự việc là thứ người dùng đọc thành "app trích hai
lần".

⚠️ Hai loại `goalAuto*` lấy **mốc của KỲ TRÍCH** làm `createdAt`, không phải lúc
quét. Lấy lúc quét thì `silenceBefore` (cửa sổ 30 ngày) không loại được những kỳ
trích bù từ nửa năm trước, và lần mở app đầu tiên sẽ đổ ra cả chục thông báo
cùng lúc. Chúng cũng là **sự kiện**, không phải trạng thái như bảy loại còn lại
— `NotificationRuleInput.autoDeposits` là danh sách việc *vừa xảy ra*, do
`GoalAutoDepositRunner` chạy ngay trong `scan()` trước khi nạp mục tiêu.

⚠️ Thông báo mục tiêu dẫn tới **`/goals/<id>`**, không phải `/goals` — nó đã
biết chính xác mục tiêu nào (`subjectId`), nên đổ người dùng xuống danh sách là
vứt đi thông tin mình đang cầm. Route ấy nằm ngoài shell y như `/goals`; kéo nó
vào một nhánh tab thì **phải** cập nhật `nhanhThanhTab` cùng lúc, nếu không bấm
thông báo sẽ làm app chết màn đỏ. `notification_deeplink_test.dart` canh chỗ đó.

**7.9 Đừng buộc vòng quét vào một sự kiện MẠNG.** Đây là lỗi đã xảy ra và đã
sửa ngày 2026-09-06 — ghi lại vì nó rất dễ tái phạm: `SyncEngine.statusStream`
trông như một tín hiệu "dữ liệu vừa đổi", nhưng nó là tín hiệu "một chu kỳ mạng
vừa kết thúc". Hai thứ ấy chỉ trùng nhau khi có mạng.

Không có kết nối, `_runSync()` thoát sớm ở `SyncStatus.pending` — **không** nằm
trong `isTerminal` — nên nghe riêng `isTerminal` là cả phiên offline không có
lượt quét nào. Và vì `GoalAutoDepositRunner` với `BillAutoPayRunner` chạy **bên
trong** `scan()`, mất luôn cả hai bộ tự chuyển tiền: người dùng bật tự trả hoá
đơn rồi đi vùng sóng yếu, hoá đơn không được trả và cũng không có thông báo nào
nói vì sao. Toàn bộ hỏng hóc này **im lặng** — không exception, không log.

Quy tắc rút ra: mọi mốc kích hoạt mới phải trả lời được câu "mốc này còn nổ khi
máy ở chế độ máy bay không?". Ba mốc hiện tại ở mục 4.5; hai trong ba mốc ấy
độc lập hoàn toàn với mạng.

**7.10 Widget test của trung tâm thông báo — bốn cái bẫy nằm chồng nhau.** Ghi
lại vì cả ba đều làm test *treo* hoặc đỏ ở một chỗ hoàn toàn khác chỗ hỏng, và
một buổi đã mất vì chúng.

1. **`tester.pump()` không tham số KHÔNG đẩy đồng hồ** — nó chỉ dựng lại khung
   hình. Drift đặt `Timer.run` khi `StreamBuilder` huỷ đăng ký
   (`StreamQueryStore.markAsClosed`), mà Timer chỉ nổ khi có thời gian trôi
   qua. Thiếu `Duration` là test đỏ với **"Pending timers"**, và từ đó **cả
   file kẹt**: các test sau chỉ báo "did not complete". Dùng
   `pump(Duration(milliseconds: 1))` sau khi gỡ cây.
2. **`pumpAndSettle` không dùng được ở trang này.** Trang hiện
   `CircularProgressIndicator` khi stream chưa phát, và vòng quay là animation
   **vô hạn** — `pumpAndSettle` pump tới khi hết hạn 10 phút của chính nó, và
   `--timeout` của `flutter test` không cắt được.
3. **SnackBar trượt lên từ dưới đáy.** Màn hình test cao 600px; chạm vào nó
   giữa chừng hoạt ảnh sẽ rơi **ra ngoài** cây dựng hình, và `tap()` chỉ in một
   dòng cảnh báo rồi đi tiếp — test đỏ ở phép kiểm phía sau, không ở dòng
   `tap()`. Cho hoạt ảnh chạy xong trước khi chạm.
4. **`longPress` kích hoạt luôn `onTap` khi chưa có `onLongPress`** (thêm
   2026-09-07). Không có recognizer nào tranh chấp thì `TapGestureRecognizer`
   thắng arena kể cả với một cú nhấn dài, nên một test nhấn giữ rồi kiểm
   **trạng thái CSDL** có thể xanh trong khi cử chỉ ấy chưa được nối vào đâu
   cả — ở đây cả `onTap` lẫn `onLongPress` đều dẫn tới `markRead`, hai đường
   khác hẳn nhau cho ra cùng một hàng. Phải kiểm thêm thứ **chỉ đường mới sinh
   ra** (dải báo "Đã đánh dấu…"). Đã tự chứng minh: gỡ `onLongPress` ra thì
   phép kiểm CSDL vẫn xanh, chỉ phép kiểm dải báo mới đỏ.

⚠️ Và một bài học về cách chạy: **đừng nối `flutter test` qua `| tail`.** Pipe
gom hết output tới khi tiến trình kết thúc, nên một lượt treo trông y hệt một
lượt đang chạy. Ghi thẳng ra file rồi đọc file.

**7.11 `AndroidManifest.xml` là vùng mù của mọi công cụ trong dự án này.**
`flutter test` không đọc nó, `flutter analyze` không đọc nó, `flutter build apk`
vẫn thành công. `flutter_local_notifications` cần **ba** receiver được khai báo
tay và **không tự khai báo cái nào**:

| Receiver | Thiếu thì hỏng thế nào |
|---|---|
| `ScheduledNotificationReceiver` | Lịch đặt trước báo "đặt thành công" nhưng **không bao giờ nổ** |
| `ScheduledNotificationBootReceiver` | Mọi lịch đang chờ mất sạch sau khi khởi động lại máy |
| `ActionBroadcastReceiver` | Nút hành động **vẫn hiện**, hệ điều hành **vẫn dựng đúng** `PendingIntent`, nhưng broadcast không tới ai: isolate nền không chạy, thông báo cũng không tự tắt |

Cả ba đều hỏng **hoàn toàn im lặng** — không exception, không log, không một
dòng trong `logcat`. Cái thứ ba mất một lúc mới lần ra vì **mọi tầng đều trông
như đúng**: `dumpsys notification` báo `actions=2` kèm `PendingIntent` đúng
kiểu, còn `dumpsys package` thì **không** liệt kê receiver không có
`intent-filter`, nên vắng mặt ở đó chẳng chứng minh gì. Phép kiểm dứt điểm là
`grep dexterous` trong manifest **đã trộn** ở
`build/app/intermediates/merged_manifest/`.

`android_manifest_receivers_test.dart` nay canh cả ba. Nó đọc XML bằng chuỗi và
xấu xí, nhưng đó là lưới duy nhất giăng được ở vùng này.

---

## 8. Kiểm thử

| Tệp | Canh gì |
|---|---|
| `test/core/notification/notification_rules_test.dart` | Ngưỡng ngân sách; `dedupeKey` không đổi khi `spent` tăng trong cùng bậc nhưng đổi khi sang kỳ; hoá đơn so theo NGÀY; `silenceBefore` |
| `test/core/notification/badge_updater_test.dart` | Badge mang đúng số chưa đọc và lọc theo `idaccount`; **huỷ CHỌN LỌC** trên khay — hàng đã đọc bị huỷ, hàng chưa đọc giữ nguyên, và **thông báo mà bảng không biết thì không bị đụng tới** (nhắc ghi chép, lịch nổ lúc app đóng); **KHÔNG BAO GIỜ gọi `cancelAll()`** vì nó cuốn theo cả lịch đang chờ; `start()` luỹ đẳng, `stop()` cắt đứt hẳn |
| `test/core/notification/notification_scanner_test.dart` | Ngưỡng số dư ví thấp đi được **từ kho tuỳ chọn tới bộ luật** (và không đặt thì im) — cùng phép canh đã có cho số ngày nhắc hoá đơn; quét lại không đẻ hàng; **`start()` quét ngay không chờ sự kiện đồng bộ nào**; **`resumed` kích hoạt quét còn `paused`/`detached` thì không**; `stop()` cắt đứt hẳn **cả hai nhánh** và gọi `cancelAll()`; `start()` hai lần không nhân đôi listener nào; bắn ra hệ điều hành đúng một lần cho mỗi hàng mới, và lỗi nền tảng không làm hỏng lượt quét |
| `test/core/notification/app_lifecycle_watcher_test.dart` | Watcher thật sự được đăng ký vào `WidgetsBinding` (không thì stream im lặng mãi, **không lỗi không log**); stream là **broadcast** nên nghe lại được sau khi huỷ; `dispose()` gỡ observer và luỹ đẳng |
| `test/core/notification/os/os_scheduled_id_test.dart` | Bốn giá trị **golden** của `md5(dedupeKey)` — khoá cứng để việc đổi thuật toán trở nên ồn ào; dải 31 bit; phân tán trên 1000 khoá |
| `test/core/notification/os/os_notifier_native_test.dart` | Chặn ở tầng `MethodChannel`: `init()` luỹ đẳng, `show()` đẩy đúng id/tiêu đề/nội dung/payload, id kênh Android không đổi, `cancelAll()`, và **không** xin quyền báo thức chính xác |
| `test/core/database/notification_dao_test.dart` | Khoá trùng ở tầng SQLite; hàng đã xoá vẫn chặn; lọc theo `idaccount`; purge. Từ 2026-09-07 canh thêm **bộ lọc và phân trang của `watchFeed`**: `kinds` `null` là *không lọc* chứ không phải *không khớp gì*, `chiChuaDoc` bỏ hàng đã đọc, và ca quan trọng nhất — **`limit` phải chạy SAU điều kiện lọc** (hàng mới nhất cố ý thuộc loại bị lọc ra, nên nếu cắt trước thì kết quả rỗng). Cùng `markUnread` hai chiều |
| `test/core/database/notification_schema_v13_test.dart` | Migration v12→v13 giữ nguyên dữ liệu cũ, không đẩy bản ghi nào vào hàng đợi |
| `test/core/database/bill_upcoming_test.dart` | `getUpcoming` lọc cả hai cột trạng thái; `markOverdue` không ghi đè lần hai |
| `test/core/utils/relative_time_test.dart` | Biên 59 giây / 60 phút / qua nửa đêm |
| `test/shared/widgets/notification_bell_test.dart` | Chấm đỏ khớp số chưa đọc, bám dòng dữ liệu |
| `test/features/notification/notification_panel_test.dart` | Rỗng → biến mất hoàn toàn; >3 mục chỉ hiện 3 |
| `test/core/notification/prefs/notification_prefs_test.dart` | Mặc định là **bật hết**; JSON hỏng/sai kiểu/ngoài dải quy về mặc định chứ không ném; ánh xạ **mười lăm** `kind` sang bốn nhóm; **ngưỡng số dư ví thấp** mặc định `0` và mọi dữ liệu hỏng (thiếu / sai kiểu / âm / vượt trần) đều về `0` — tức là **tắt**. Từ 2026-09-07 canh thêm ba trường **nhắc ghi chép**: mặc định TẮT và 20:00, bản ghi cũ thiếu trường thì rơi về tắt, giờ/phút ngoài dải quy về mặc định mà **không** kéo cả bản ghi theo, và hai bản chỉ khác ba trường ấy thì **không bằng nhau** (phép so `==`/`hashCode` — đây là chỗ test đi-một-vòng KHÔNG canh được) |
| `test/core/notification/prefs/notification_prefs_store_test.dart` | **Tách khoá theo tài khoản**; JSON hỏng trên đĩa; `clear()` không đụng tài khoản khác |
| `test/features/notification/notification_settings_page_test.dart` | Ngưỡng số dư ví hiện đúng thứ đã lưu và ghi ngay khi đổi (⚠️ thẻ ấy nằm cuối trang cuộn, ở 800px của môi trường test nó dưới mép màn hình nên phải `ensureVisible` trước khi `tap`, nếu không cú chạm trượt ra nền); công tắc phản ánh đúng thứ đã lưu; ghi ngay không cần nút Lưu; **bật công tắc OS thì xin quyền, tắt thì không**; bị từ chối thì công tắc quay về tắt; chưa đăng nhập thì không ghi gì. Từ 2026-09-07 canh thêm thẻ **NHẮC GHI CHÉP**: công tắc tắt sẵn, bật thì ghi ngay, hàng chọn giờ **chỉ hiện khi công tắc bật**, và giờ hiển thị là 20:00 chứ không phải 08:00 của hoá đơn. ⚠️ Thẻ này cũng nằm cuối trang cuộn nên vẫn phải `ensureVisible` |
| `test/core/notification/reminder_scheduler_test.dart` | **Luỹ đẳng** (chạy lại không đặt lại lịch nào); trần 50 và cắt bỏ mốc **xa** nhất; giờ nhắc từ tuỳ chọn; mốc quá khứ và ngoài cửa sổ 30 ngày bị bỏ; hoá đơn trả/xoá thì huỷ lịch cũ; tắt công tắc thì dọn sạch. Từ 2026-09-07 canh thêm **nhắc ghi chép hằng ngày** (mục 4.7): tắt sẵn; bật thì đúng **ba** lịch; giờ lấy từ tuỳ chọn **riêng** chứ không phải `gioNhac`; hôm nay đã có giao dịch thì bỏ lịch hôm nay còn giữ hai lịch sau; giao dịch **hôm qua** không cứu được hôm nay (so theo NGÀY, không theo 24 giờ); `null` = chưa từng ghi = **vẫn nhắc**; giờ đã trôi qua thì bỏ hôm nay; và ca quan trọng nhất — **ghi giao dịch xong thì lượt sau HUỶ lịch hôm nay**, chính là lý do chọn ba lịch rời thay vì một lịch lặp |
| `test/core/notification/reminder_scheduler_test.dart` (nhóm *lịch hoãn*) | Ca đã **hỏng thật** trên máy ảo: lịch người dùng vừa hoãn phải sống sót qua `resync()` **dù mốc nhắc gốc đã trôi qua** — và đó là ca duy nhất có thật, vì chỉ hoãn được sau khi thông báo đã nổ. Kèm ba ranh giới giữ cho ngoại lệ **hẹp**: hoá đơn đã trả, đã xoá, và lịch lạ không thuộc hoá đơn nào thì **vẫn bị dọn** |
| `test/core/notification/notification_actions_test.dart` | Toàn bộ phép quyết định của nút hành động, tách khỏi tầng plugin: loại nào **được** gắn nút (chỉ nhắc hoá đơn); `payloadTraNgay` dựng khoá mở đúng hoá đơn và trả `null` khi khoá thiếu id; `khoaSauChamNut` — **một** hàm cho **cả hai** đường vào của một cú bấm; và `lichHoan` dời đúng 24 giờ, **giữ nguyên khoá** nên cùng `osScheduledId` |
| `test/core/notification/os/android_manifest_receivers_test.dart` | **Ba** receiver của `flutter_local_notifications` phải có mặt trong `AndroidManifest.xml`, và không cái nào được `exported="true"`. Vùng mà không công cụ nào khác chạm tới — đọc bẫy **7.11**. ⚠️ Bản đầu của test này tìm `exported="true"` trên **cả file** và đỏ oan vì `MainActivity` bắt buộc phải xuất; nay chỉ xét bên trong thẻ `<receiver>` |
| `test/core/database/transaction_last_date_test.dart` | `getLastTransactionDate` — đầu vào **duy nhất** của lời nhắc ghi chép, và cả ba cách hỏng đều im lặng: đọc cả hàng đã xoá mềm, đọc lẫn tài khoản khác, hoặc trả `null` sai. ⚠️ `forTesting` bật `PRAGMA foreign_keys = ON` nên phải dựng hàng `wallets` trước, nếu không mọi lệnh chèn nổ `SqliteException(787)` |
| `test/core/notification/notification_rules_goal_wallet_test.dart` | Bốn luật của lát 6, trọng tâm là **đơn vị lặp lại trong `dedupeKey`**: chúc mừng một lần trong đời, trễ tiến độ mỗi tháng, ví âm và đồng bộ hỏng mỗi ngày. Từ 2026-09-07 canh thêm **ví sắp cạn**: biên **đóng** ở đúng ngưỡng, ngưỡng `0` im hoàn toàn, ví âm chỉ ra **một** thông báo chứ không ra cả hai, và ví loại `debt` im ở **cả hai** luật |
| `test/features/goal/goal_entity_progress_test.dart` | `progress` kẹp [0,1] và không ra `Infinity` khi `targetAmount = 0`; `daysLeft` so theo NGÀY; `isBehindSchedule` có biên dung sai, im lặng khi thiếu `startDate`, không NaN khi kỳ dài 0 ngày |
| `test/core/notification/notification_deeplink_test.dart` | Route nào kéo theo thanh tab; **không được so khớp bằng `startsWith` trần** (`/budgets` ≠ `/budget`); và phép canh **cả 15 loại**: `deeplinkTuDedupeKey()` phải trả đúng cột `deeplink` mà bộ luật đặt — bản sao duy nhất trong vùng này, tồn tại vì cold start không tra CSDL được. Từ 2026-09-07 thêm nhánh `ghiChep` → **`/add`**: nó KHÔNG phải một `NotificationKind` nên phép canh 15 loại không chạm tới, phải có test riêng, và test ấy khẳng định luôn `/add` nằm ngoài thanh tab (bẫy 7.8) |
| `test/features/notification/notification_center_page_test.dart` | Vuốt xoá là xoá **mềm**; SnackBar có nút Hoàn tác; bấm vào thì hàng quay lại **và danh sách tự vẽ lại** qua `watchFeed`; chưa đăng nhập thì không đọc gì. Từ 2026-09-07 canh thêm: chip nhóm thu hẹp danh sách, chip "Chưa đọc" bỏ mục đã đọc, **quay lại "Tất cả" thì danh sách đầy đủ trở lại** (canh chỗ `null` bị hiểu nhầm thành danh sách rỗng), nút "Tải thêm" hiện/biến mất đúng lúc, nhấn giữ đảo được cả hai chiều, và **hàng chip không tràn ở 411dp**. Đọc bẫy **7.10** trước khi sửa file này — nay có **bốn** mục, mục 4 nói vì sao một test nhấn giữ có thể xanh giả |
| `test/core/notification/notification_tap_router_test.dart` | Cold start điều hướng được; **cùng payload đến bằng cả hai đường chỉ điều hướng một lần**, nhưng lần chạm sau vẫn chạy; chưa đăng nhập thì giữ lại và xả sau `AuthSuccess`, chỉ giữ **cái mới nhất**; `stop()` cắt hẳn |
| `test/core/network/connection_monitor_test.dart` | **Ngưỡng ổn định**: mất mạng chớp nhoáng và chuỗi nhấp nháy đều không sinh sự kiện; đang online lúc khởi động thì không báo "khôi phục" |
| `test/core/sync/sync_push_result_test.dart` | `pushResultStream` phát số thao tác đã lên; **không phát khi không có gì để đẩy**; server từ chối thì vẫn phát kèm số thất bại |
| `test/shared/connection_banner_test.dart` | Ba dải và thứ tự ưu tiên giữa chúng; dải không được **đè lên** nội dung màn hình |
| `test/features/layout/no_overflow_test.dart` | Ba hàng từng tràn, dựng ở **320/360/411dp** — bắt bằng `tester.takeException()` |

⚠️ `.gitignore` dòng 77 có `test/` → file test mới bị bỏ qua **âm thầm**. Phải
`git add -f` **từng đường dẫn** (thêm cả thư mục thì git từ chối nguyên lệnh).

### ⚠️ `flutter test` xanh KHÔNG đủ cho vùng này

Bốn lỗi dưới đây chỉ lộ ra khi chạy trên **máy ảo Android**, và cả bốn đều để
bộ test xanh. Ghi lại vì chúng cùng một bài học: có những thứ chỉ tồn tại khi
có cây widget thật, cây route thật, và một màn hình 411dp thật.

| Lỗi | Vì sao bộ test không thấy |
|---|---|
| Bấm thông báo ngân sách → **app chết màn đỏ** (`!keyReservation.contains(key)`) | `/budget` nằm trong `StatefulShellRoute` còn `/notifications` ở ngoài. `push` bắt go_router dựng **shell thứ hai** trùng page key. Ba deeplink còn lại đều ngoài shell nên chạy tốt — ba phần tư đường đi đúng |
| Ba chỗ **tràn bố cục** (21px · 3,9px · 0,315px) | Bộ test chạy Chrome ở **1280px**, rộng gấp ba lần chỗ bắt đầu tràn |
| Dải báo kết nối **đè lên tiêu đề và nút chuông** | Chỉ thấy khi có `Scaffold` thật bên dưới |
| Dải "đã đồng bộ" **bị ghi đè** mất | Cả hai stream đều đúng; chỉ **thứ tự thực tế** mới lộ — đo được: `Network restored` 22:30:11.268, `Push complete` 22:30:11.643, còn dải kết nối báo ở giây thứ 3 |

### Đã kiểm được trên máy ảo

- Quyền `POST_NOTIFICATIONS` xin **có ngữ cảnh**; **từ chối** → công tắc quay
  về tắt kèm SnackBar; **cho phép** → `granted=true`.
- Kênh Android `flowmoney_alerts`, `importance=4`.
- Lịch vào AlarmManager đúng **08:00 giờ địa phương** (không neo UTC → bẫy 7.3
  không xảy ra); đổi số ngày nhắc thì lịch cũ bị huỷ, lịch mới đặt, vẫn **một**
  mốc duy nhất.
- Thông báo hệ điều hành **nổ thật**, đúng kênh, id trong dải 31 bit.
- **Lịch sống sót sau khi khởi động lại máy**: `adb reboot` rồi đọc lại
  `dumpsys alarm` — mốc y nguyên, và logcat cho thấy tiến trình được khởi động
  **cho broadcast của `ScheduledNotificationBootReceiver`**, với **0 dòng
  `I/flutter`** → Dart không chạy, đúng cơ chế mong muốn.
- Toàn bộ đường đi của phần thông báo: chuông (kể cả bấm hai lần thật nhanh),
  "Xem tất cả", "Đọc tất cả", bấm từng loại thông báo, vuốt xoá
  (`endToStart` — vuốt phải sang trái), trang cài đặt.

### Kiểm bổ sung ngày 2026-09-07 — ba việc còn treo, nay đã có bằng chứng

**Thông báo nổ khi app đóng hoàn toàn.** Tiến trình bị giết bằng
`adb shell am kill` (**không** `force-stop` — xem dưới), `pidof` rỗng suốt quãng
chờ. Khi mốc lịch qua:

```
ActivityManager: Start proc 7727:com.flowmoney.flowmoney/u0a227
  for broadcast {com.flowmoney.flowmoney/...ScheduledNotificationReceiver}
```

Thông báo nổ ra với **0 dòng `I/flutter`** — Dart không chạy, đúng cơ chế mong
muốn, cùng dấu hiệu như phép kiểm `adb reboot` ở trên.

⚠️ **Nhảy đồng hồ tới đúng giờ hẹn thì lịch KHÔNG nổ.** `zonedSchedule` dùng
`AndroidScheduleMode.inexactAllowWhileIdle`, và `dumpsys alarm` cho thấy mốc ấy
mang `window=+1h0m0s0ms`: Android được phép hoãn tới **một tiếng**. Đo được:
đặt đồng hồ tới 08:00 rồi chờ hơn hai phút — không nổ, alarm vẫn nằm trong danh
sách chờ với `maxWhenElapsed=+57m`; đẩy tiếp qua 09:00 (cuối cửa sổ) thì nổ
**ngay lập tức**. Ai kiểm lại phần này mà chỉ nhảy tới đúng giờ hẹn sẽ kết luận
nhầm là hỏng.

**Giờ im lặng, bằng một thông báo thật trong khoảng giờ ấy.** Cùng một luật
(`walletNegative`), cùng một cái ví, chỉ khác cái công tắc:

| Lúc | Giờ im lặng | Lượt quét ghi được | Thông báo hệ điều hành mới |
|---|---|---|---|
| 09:06, trong khoảng 07:00→11:00 | **BẬT** | 2 hàng | **0** |
| 09:00 hôm sau | **TẮT** | 1 hàng | **1** (`Số dư ví đang âm`) |

Cả hai hàng ở lượt đầu đều thấy trong trung tâm thông báo trong app — đúng ngữ
nghĩa "đừng đánh thức tôi", không phải "đừng ghi lại gì". Đối chứng ở dòng thứ
hai là phần bắt buộc: không có nó thì "0 thông báo" chỉ chứng minh được rằng
không có gì để bắn.

Trong **chính** khung giờ im lặng ấy, lịch nhắc hoá đơn **vẫn nổ** (mốc 09:05) —
đúng quyết định "lịch đặt trước không đi qua giờ im lặng" ở mục 5c.

**`khoaNhom`** — xem mục 5c, bằng chứng ghi ở đó cạnh phần thiết kế.

### Kỹ thuật máy ảo dùng cho ba phép kiểm trên

- **Đặt đồng hồ:** `adb shell settings put global auto_time 0` rồi
  `adb shell cmd alarm set-time <epoch_ms>`. (`adb shell date` **không** dùng
  được vì máy ảo không root.) Trả lại bằng `settings put global auto_time 1`,
  máy ảo tự đồng bộ lại từ host sau vài giây.
- ⚠️ **`am force-stop` huỷ sạch lịch trong AlarmManager** và đưa app vào
  `stopped=true` khiến Android chặn luôn broadcast — dùng nó là tự phá phép
  kiểm. `am kill` giết tiến trình mà giữ nguyên lịch, đó mới là thứ mô phỏng
  đúng "người dùng đóng app".
- **Trước khi nhảy đồng hồ phải biết mốc ấy chạm vào cái gì.** Hai bộ tự chuyển
  tiền nằm trong `scan()`, và `scan()` chạy ngay khi app quay lại tiền cảnh
  (mục 4.5) — nhảy qua một hạn hoá đơn hoặc một kỳ trích là **tiền thật rời
  ví** trong tài khoản kiểm thử. Lần này mốc 11–12/09 được chọn vì hạn chưa trả
  gần nhất là 18/09 và kỳ trích gần nhất là 06/10; kiểm lại tổng số dư trước và
  sau đều là 8.890.081đ.
- Đọc dữ liệu riêng của app: `adb shell run-as com.flowmoney.flowmoney cat
  shared_prefs/scheduled_notifications.xml` (bản debug). Máy ảo **không có**
  `sqlite3`.
- AVD của dự án là **`FlowMoney_16G`** (dữ liệu ở `D:\Android\avd\`).

### Cách chạy trên máy ảo

```bash
flutter build apk --debug
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"   # adb KHÔNG có trong PATH
"$ADB" -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
"$ADB" shell am start -n com.flowmoney.flowmoney/.MainActivity
```

Mẹo đã dùng: sọc cảnh báo tràn của Flutter là **vàng thuần** và không màn nào
của app dùng màu ấy, nên đếm pixel vàng trong ảnh `screencap` là phép dò tràn
rẻ hơn hẳn việc mở từng ảnh ra nhìn. Cẩn thận dương tính giả với **màn hình
launcher** của Android (biểu tượng Google có vàng).

---

## 9. Dải báo kết nối — kênh thứ hai, KHÔNG đi qua bảng thông báo

Yêu cầu của người dùng: đang dùng app mà mất mạng thì phải biết, có mạng lại
thì phải biết, và việc đồng bộ sau đó cũng phải biết.

```
lib/core/network/connection_monitor.dart     # Ngưỡng ổn định, tách khỏi SyncEngine
lib/shared/widgets/connection_banner.dart    # Dải, bọc ngoài router
```

### Vì sao KHÔNG dùng bảng `AppNotifications`

Bảng ấy dành cho **sự kiện tài chính đáng lưu lại**, với khoá chống trùng theo
kỳ. Trạng thái mạng thì ngược lại: tức thời, lặp nhiều, hết ý nghĩa sau vài
giây. Đi tàu hoả có thể mất/có mạng chục lần trong một giờ; mỗi lần một hàng
thì trung tâm thông báo ngập rác và người dùng sẽ tắt cả nhóm "Hệ thống" —
mất luôn cảnh báo đồng bộ hỏng vốn đáng giá.

### Ngưỡng ổn định — lý do `ConnectionMonitor` tồn tại

`onConnectivityChanged` bắn rất nhiều: thang máy, hầm, chuyển Wi-Fi sang 4G.
Báo thẳng ra giao diện thì dải nhấp nháy liên tục và người dùng học được cách
phớt lờ nó, kể cả lúc mất mạng thật. Nên chỉ báo khi trạng thái **giữ nguyên**
đủ lâu (3 giây).

⚠️ **Tách khỏi `SyncEngine` có chủ ý.** `SyncEngine` cũng nghe cùng luồng ấy,
nhưng để trả lời câu **"lúc nào nên đồng bộ"** — ở đó, phản ứng ngay với cú
nhấp nháy đầu tiên là **đúng**. Dải báo trả lời câu **"có đáng nói với người
dùng không"** — ở đó, phản ứng ngay là **sai**. Trộn hai mục đích vào một chỗ
thì một trong hai phải chịu thiệt.

### Ba dải, và thứ tự ưu tiên giữa chúng

| Dải | Khi nào | Nội dung |
|---|---|---|
| Mất kết nối | Sau ngưỡng ổn định | "Không có kết nối — thay đổi vẫn được lưu trên máy" |
| Đã kết nối lại | Sau ngưỡng ổn định | "Đã kết nối lại" |
| Kết quả đồng bộ | `SyncEngine.pushResultStream` | "Đã đồng bộ xong" / "Một số thay đổi chưa lên được máy chủ" |

**Cả ba đều tự ẩn sau vài giây.** Bản đầu giữ dải mất kết nối cho tới khi có
mạng, với lập luận "trạng thái kéo dài thì phải hiển thị kéo dài". Người dùng
thử trên máy thật và yêu cầu đổi: một dải đứng mãi trên đầu màn hình gây khó
chịu hơn là hữu ích.

**Không nêu số lượng** trong thông báo đồng bộ — con số là chi tiết cài đặt.
Nhưng **vẫn phân biệt** "xong" với "còn kẹt lại": gộp hai trạng thái ấy vào
một câu là để người dùng tưởng dữ liệu đã an toàn.

⚠️ **"Đã kết nối lại" KHÔNG được ghi đè dải kết quả đồng bộ.** Đo trên máy
thật: `SyncEngine` đẩy xong sau **0,4 giây**, còn `ConnectionMonitor` phải chờ
hết ngưỡng **3 giây**. Không có quy tắc ưu tiên thì dải giàu thông tin ra
trước rồi bị dải nghèo hơn nuốt mất — đúng thứ người dùng yêu cầu lại là thứ
biến mất.

### `SyncEngine.pushResultStream`

Kênh **riêng**, không nhét vào `statusStream` (cùng lý do như
`sessionInvalidStream`). **Không phát khi không có gì để đẩy** — phần lớn chu
kỳ là như vậy, và phát mọi lần là ép nơi nhận tự lọc, sớm muộn sẽ có chỗ quên
lọc rồi hiện "đã đồng bộ 0 thay đổi".

### Quan hệ với thông báo `syncFailed`

Hai thứ **bổ sung** nhau, không trùng: dải là tức thời, còn hàng `syncFailed`
trong trung tâm thông báo là lịch sử và gộp theo ngày.

---

## 10. Commit đã tạo trong phiên 2026-09-04

Lát 1–3 và phần hoá đơn:

```
8f4c72b  fix(bill): vá đường đẩy, trạng thái thanh toán và chu kỳ lặp
9c09fc6  feat(budget): cảnh báo khi chu kỳ ghi đè ngày kết thúc tự chọn
ee8c9e8  feat(notification): trung tâm thông báo trong app
9691b20  feat(notification): thông báo hoá đơn sắp đến hạn và quá hạn
54eb1a2  docs: bàn giao hệ thống thông báo và cập nhật trạng thái
```

Lát 4–7:

```
4876fd1  feat(notification): thông báo hệ điều hành Android/iOS
862d090  docs(notification): cập nhật trạng thái lát 4
e08ce68  feat(notification): trang cài đặt và tuỳ chọn theo từng tài khoản
9dcc586  docs(notification): tài liệu backend và đính chính time_notification
4be4f15  feat(notification): lịch nhắc đặt trước và bốn loại thông báo còn lại
a26d78d  docs(notification): cả bảy lát đã xong
```

Sau khi chạy trên máy ảo Android:

```
f08ee0d  fix(ui): vá ba chỗ tràn bố cục chỉ lộ ra trên màn điện thoại
db4966b  fix(notification): bấm thông báo ngân sách làm app chết màn đỏ
03418a4  feat(network): báo mất mạng, có mạng lại và kết quả đồng bộ
06f2499  refactor(network): dải báo kết nối tối giản hơn theo yêu cầu người dùng
```

Chưa push.
