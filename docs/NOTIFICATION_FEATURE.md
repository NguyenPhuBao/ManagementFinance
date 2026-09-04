# Hệ thống thông báo — tài liệu bàn giao

> **Cập nhật:** 2026-09-04 · **Nhánh:** `TranQuangDat`
> **Trạng thái:** cả bảy lát đã xong, **đã kiểm trên máy ảo Android**, và có
> thêm **dải báo kết nối** (mục 9).
> **Mức nền hiện tại:** `flutter test` **651/651 pass**, `flutter analyze`
> **28 issue, KHÔNG error**, `flutter build web` xanh.

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

| Nhóm | Loại | `kind` | Trạng thái |
|---|---|---|---|
| Ngân sách | Chạm ngưỡng | `budgetNearLimit` | ✅ Xong |
| | Vượt hạn mức | `budgetOverspent` | ✅ Xong |
| Hoá đơn | Sắp đến hạn | `billDueSoon` | ✅ Xong |
| | Quá hạn | `billOverdue` | ✅ Xong |
| Mục tiêu | Hoàn thành | `goalCompleted` | ✅ Xong |
| | Trễ tiến độ | `goalBehind` | ✅ Xong |
| Hệ thống | Đồng bộ hỏng | `syncFailed` | ✅ Xong |
| | Số dư ví âm | `walletNegative` | ✅ Xong |

Enum `NotificationKind` **đã khai đủ tám giá trị** — lát 6 chỉ việc thêm luật,
không phải sửa enum hay migration.

Giao dịch ngân hàng Casso và OCR **không** làm được ở client: backend có phát
ba sự kiện đó qua Socket.io nhưng client chưa có `socket_io_client`, và quan
trọng hơn là kênh socket đó đang là **bước 1 trong chín bước sửa backend** vì
handshake không xác thực và mỗi sự kiện còn `io.emit` toàn cục.

---

## 4. Kiến trúc hiện tại

```
lib/core/notification/
├── notification_rules.dart       # Hàm THUẦN: trạng thái → danh sách ứng viên
├── notification_scanner.dart     # Nối luật với CSDL và vòng đời app
├── bill_reminder_scheduler.dart  # Đặt lịch trước với hệ điều hành (lát 5)
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

Chỉ **một** mốc, **không có `Timer.periodic`**: `NotificationScanner` nghe
`SyncEngine.statusStream` và quét khi trạng thái `isTerminal`. Dữ liệu chỉ đổi
khi có ghi cục bộ hoặc pull về, mà cả hai đều kết thúc bằng sự kiện đó.

`scan()` trả **số hàng thật sự được ghi** — tín hiệu duy nhất để quyết định có
bắn ra hệ điều hành hay không. Từ lát 4, chính danh sách hàng vừa ghi ấy (chứ
không phải danh sách ứng viên) là thứ được đẩy sang `OsNotifier.show()`.

`start()` **huỷ subscription cũ trước khi tạo mới**. Được gọi ở
`auth_bloc.dart` cạnh `SyncEngine.start()`; `stop()` ở hai chỗ đăng xuất /
phiên chết. **Cố ý KHÔNG gắn ở `home_page.dart`** — chỗ đó gọi
`SyncEngine.start()` ngay trong `build()`.

`silenceBefore = now − 30 ngày` chặn cơn lũ ở lần bật đầu tiên.

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

`lib/core/notification/bill_reminder_scheduler.dart`. Cách **duy nhất** để
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
| `walletNegative` | `walletNeg:<id>:<yyyy-MM-dd>` | mỗi ngày | Ví âm cho tới khi người dùng nạp tiền |
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
| Bốn công tắc **nhóm** | Không **sinh** thông báo nhóm ấy — cả trong app lẫn ra hệ điều hành. Lọc ngay sau bộ luật, trước khi ghi. |
| Công tắc **tổng** cho OS | Vẫn ghi vào trung tâm trong app, chỉ **không bắn** ra ngoài. Đây là "đừng làm phiền tôi", không phải "đừng ghi lại gì". |

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

`docs/superpowers/backend/2026-09-04-notification-backend.md`, đã nối vào mục 3
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

Ba việc còn lại là thật nhưng **không chặn gì hôm nay**: socket không xác thực
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

⚠️ Ba deeplink còn lại (`/bills`, `/goals`, `/wallets`) đều **ngoài** shell nên
`push` chạy tốt. Ba phần tư đường đi đúng chính là lý do lỗi này lọt qua mọi
vòng kiểm trước đó.

---

## 8. Kiểm thử

| Tệp | Canh gì |
|---|---|
| `test/core/notification/notification_rules_test.dart` | Ngưỡng ngân sách; `dedupeKey` không đổi khi `spent` tăng trong cùng bậc nhưng đổi khi sang kỳ; hoá đơn so theo NGÀY; `silenceBefore` |
| `test/core/notification/notification_scanner_test.dart` | Quét lại không đẻ hàng; `stop()` cắt đứt hẳn **và gọi `cancelAll()`**; `start()` hai lần chỉ quét một lần; bắn ra hệ điều hành đúng một lần cho mỗi hàng mới, và lỗi nền tảng không làm hỏng lượt quét |
| `test/core/notification/os/os_scheduled_id_test.dart` | Bốn giá trị **golden** của `md5(dedupeKey)` — khoá cứng để việc đổi thuật toán trở nên ồn ào; dải 31 bit; phân tán trên 1000 khoá |
| `test/core/notification/os/os_notifier_native_test.dart` | Chặn ở tầng `MethodChannel`: `init()` luỹ đẳng, `show()` đẩy đúng id/tiêu đề/nội dung/payload, id kênh Android không đổi, `cancelAll()`, và **không** xin quyền báo thức chính xác |
| `test/core/database/notification_dao_test.dart` | Khoá trùng ở tầng SQLite; hàng đã xoá vẫn chặn; lọc theo `idaccount`; purge |
| `test/core/database/notification_schema_v13_test.dart` | Migration v12→v13 giữ nguyên dữ liệu cũ, không đẩy bản ghi nào vào hàng đợi |
| `test/core/database/bill_upcoming_test.dart` | `getUpcoming` lọc cả hai cột trạng thái; `markOverdue` không ghi đè lần hai |
| `test/core/utils/relative_time_test.dart` | Biên 59 giây / 60 phút / qua nửa đêm |
| `test/shared/widgets/notification_bell_test.dart` | Chấm đỏ khớp số chưa đọc, bám dòng dữ liệu |
| `test/features/notification/notification_panel_test.dart` | Rỗng → biến mất hoàn toàn; >3 mục chỉ hiện 3 |
| `test/core/notification/prefs/notification_prefs_test.dart` | Mặc định là **bật hết**; JSON hỏng/sai kiểu/ngoài dải quy về mặc định chứ không ném; ánh xạ tám `kind` sang bốn nhóm |
| `test/core/notification/prefs/notification_prefs_store_test.dart` | **Tách khoá theo tài khoản**; JSON hỏng trên đĩa; `clear()` không đụng tài khoản khác |
| `test/features/notification/notification_settings_page_test.dart` | Công tắc phản ánh đúng thứ đã lưu; ghi ngay không cần nút Lưu; **bật công tắc OS thì xin quyền, tắt thì không**; bị từ chối thì công tắc quay về tắt; chưa đăng nhập thì không ghi gì |
| `test/core/notification/bill_reminder_scheduler_test.dart` | **Luỹ đẳng** (chạy lại không đặt lại lịch nào); trần 50 và cắt bỏ mốc **xa** nhất; giờ nhắc từ tuỳ chọn; mốc quá khứ và ngoài cửa sổ 30 ngày bị bỏ; hoá đơn trả/xoá thì huỷ lịch cũ; tắt công tắc thì dọn sạch |
| `test/core/notification/notification_rules_goal_wallet_test.dart` | Bốn luật của lát 6, trọng tâm là **đơn vị lặp lại trong `dedupeKey`**: chúc mừng một lần trong đời, trễ tiến độ mỗi tháng, ví âm và đồng bộ hỏng mỗi ngày |
| `test/features/goal/goal_entity_progress_test.dart` | `progress` kẹp [0,1] và không ra `Infinity` khi `targetAmount = 0`; `daysLeft` so theo NGÀY; `isBehindSchedule` có biên dung sai, im lặng khi thiếu `startDate`, không NaN khi kỳ dài 0 ngày |
| `test/core/notification/notification_deeplink_test.dart` | Route nào kéo theo thanh tab; **không được so khớp bằng `startsWith` trần** (`/budgets` ≠ `/budget`) |
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

### Chưa kiểm được

Thông báo nổ khi app **đóng hoàn toàn** — phải chờ tới mốc lịch thật, hoặc
chỉnh đồng hồ máy ảo (việc này đụng đồng hồ hệ thống nên cần người dùng đồng ý).

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
