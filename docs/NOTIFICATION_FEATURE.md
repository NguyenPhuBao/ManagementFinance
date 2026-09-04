# Hệ thống thông báo — tài liệu bàn giao

> **Cập nhật:** 2026-09-04 · **Nhánh:** `TranQuangDat`
> **Trạng thái:** lát 1–3 xong và đã commit. Lát 4–7 chưa làm.
> **Mức nền khi bàn giao:** `flutter test` **479/479 pass**, `flutter analyze`
> **28 issue, KHÔNG error**, `flutter build web` xanh.

Đọc file này trước khi làm tiếp bất cứ việc gì thuộc thông báo. Mục 6 là phần
việc còn lại, mục 7 là những cái bẫy — **đọc mục 7 trước khi viết dòng đầu
tiên của lát 4**.

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
| Mục tiêu | Hoàn thành | `goalCompleted` | ⏳ Lát 6 |
| | Trễ tiến độ | `goalBehind` | ⏳ Lát 6 |
| Hệ thống | Đồng bộ hỏng | `syncFailed` | ⏳ Lát 6 |
| | Số dư ví âm | `walletNegative` | ⏳ Lát 6 |

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
├── notification_rules.dart      # Hàm THUẦN: trạng thái → danh sách ứng viên
└── notification_scanner.dart    # Nối luật với CSDL và vòng đời app

lib/core/database/
├── tables/notification_table.dart   # Bảng AppNotifications
└── daos/notification_dao.dart

lib/core/utils/relative_time.dart    # "10 phút trước" / "Hôm qua"

lib/shared/widgets/notification_bell.dart          # Chuông dùng chung

lib/features/notification/presentation/
├── pages/notification_center_page.dart   # /notifications
└── widgets/notification_panel.dart       # Panel trên Home
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
bắn ra hệ điều hành hay không (lát 4 sẽ dùng).

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

## 6. Phần việc còn lại

### Lát 4 — `OsNotifier` + thông báo hệ điều hành thật

Lát đầu tiên chạm `pubspec.yaml` và manifest, và là lát đầu tiên mà
**`flutter test` xanh không còn đủ**.

Gói cần thêm: `flutter_local_notifications`, `timezone`, `flutter_timezone`.
**Không cần `permission_handler`** — gói chính đã có sẵn đường xin quyền.

Trừu tượng theo **đúng mẫu đã có** ở `lib/core/database/connection/`:

```
lib/core/notification/os/
  os_notifier.dart        // abstract + conditional import
  os_notifier_native.dart // io — nơi DUY NHẤT import flutter_local_notifications
  os_notifier_web.dart    // no-op, isSupported => false
  os_notifier_stub.dart
```

**Android:** khai `POST_NOTIFICATIONS` + `RECEIVE_BOOT_COMPLETED` và hai
`<receiver>` của plugin. **Chủ động KHÔNG khai `SCHEDULE_EXACT_ALARM` /
`USE_EXACT_ALARM`** — Google Play chặn trừ nhóm báo thức/lịch, và Android 14
bắt người dùng bật tay trong Cài đặt. Dùng
`AndroidScheduleMode.inexactAllowWhileIdle`; nhắc hoá đơn lệch mươi phút không
sao. **Phải ghi thành chú thích trong mã** vì "nhắc hoá đơn nên chính xác"
nghe rất hợp lý và người sau sẽ muốn đổi. Kiểm `desugar_jdk_libs` trong
`build.gradle.kts` — thiếu là lỗi build khó đọc, **chỉ hỏng lúc build release**.

**iOS:** không cần key mới trong `Info.plist`, **không** thêm
`UIBackgroundModes`. Gán `UNUserNotificationCenter.delegate` trong
`AppDelegate.swift`. Xin quyền **có ngữ cảnh** (từ trang cài đặt hoặc sau khi
bật công tắc nhắc), không bao giờ lúc mở app lần đầu — từ chối là mất vĩnh viễn.

**`osScheduledId` = 4 byte đầu của `md5(dedupeKey) & 0x7fffffff`.** Gói
`crypto` đã có trong pubspec. **Không dùng `dedupeKey.hashCode`** —
`String.hashCode` của Dart không ổn định giữa các phiên chạy, nên sau khi cập
nhật app sẽ không huỷ được lịch cũ và người dùng nhận nhắc cho hoá đơn đã xoá,
không cách nào tắt.

### Lát 5 — `zonedSchedule` đặt lịch trước cho hoá đơn

Cách **duy nhất** để thông báo nổ khi app đóng mà không cần tác vụ nền.

`tz.initializeTimeZones()` + `flutter_timezone` trong `main.dart` **trước**
`setupDependencies()`. `BillReminderScheduler.resync(idaccount)` luỹ đẳng, gọi
sau mỗi lần ghi hoá đơn và sau mỗi lần pull. Cửa sổ 30 ngày, **trần 50 lịch**
(xem bẫy 7.5).

Điểm nối với phần trong app: **cùng `dedupeKey`**. Lịch OS mang
`payload = dedupeKey`. Thông báo nổ lúc app đóng → người dùng bấm → app mở →
quét chạy → `insertOrIgnore` sinh đúng hàng đó, **một lần**. Không đường nào
nhân đôi.

### Lát 6 — Mục tiêu, đồng bộ, ví âm

- Thêm `progress` / `daysLeft(now)` / `isBehindSchedule(now)` vào **chính
  `GoalEntity`** (lớp này hiện **không có** thuộc tính suy ra nào), không đặt
  trong luật thông báo — trang mục tiêu cũng sẽ cần.
- Luật `goalCompleted` / `goalBehind` cho ra đúng mục Stitch thứ ba.
- Luật `syncFailed` đọc `SyncStatus.error` — đây sẽ là **người tiêu thụ đầu
  tiên** của `statusStream` cho mục đích hiển thị.
- Luật `walletNegative`.
- Gọi `purgeOlderThan(90 ngày)` trong `NotificationScanner.start()`.

### Lát 7 — Màn cài đặt + tài liệu backend

Màn `/settings/notifications` nối vào `profile_page.dart` (mục menu hiện dẫn
tạm về `/notifications`). Công tắc tổng + bốn công tắc nhóm + **giờ nhắc trong
ngày** (thiếu nó thì `zonedSchedule` nổ lúc 00:00) + số ngày nhắc mặc định.

**Nơi lưu tuỳ chọn:** khoá JSON `notification_prefs_<idaccount>` trong
`FlutterSecureStorage` — gói **đã có**, chạy cả trên web, tách theo tài khoản.
Bọc sau một interface + bản in-memory cho test, theo mẫu `SyncCheckpointStore`.

Tài liệu backend trong `docs/superpowers/backend/`: siết xác thực Socket.io
trước tiên (đã là bước 1, và phải sửa `Admin-web/src/hooks/useSocket.js` cùng
lúc vì consumer hiện kết nối không kèm token); `bill.time_notification` nay
được client ghi nhưng **không nằm trong payload đẩy**; backend **không có
scheduler dưới bất kỳ hình thức nào** và queue `send-notification` đã khai báo
nhưng worker rỗng 0 byte.

---

## 7. Bẫy — đọc trước khi làm lát 4

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

---

## 8. Kiểm thử

| Tệp | Canh gì |
|---|---|
| `test/core/notification/notification_rules_test.dart` | Ngưỡng ngân sách; `dedupeKey` không đổi khi `spent` tăng trong cùng bậc nhưng đổi khi sang kỳ; hoá đơn so theo NGÀY; `silenceBefore` |
| `test/core/notification/notification_scanner_test.dart` | Quét lại không đẻ hàng; `stop()` cắt đứt hẳn; `start()` hai lần chỉ quét một lần |
| `test/core/database/notification_dao_test.dart` | Khoá trùng ở tầng SQLite; hàng đã xoá vẫn chặn; lọc theo `idaccount`; purge |
| `test/core/database/notification_schema_v13_test.dart` | Migration v12→v13 giữ nguyên dữ liệu cũ, không đẩy bản ghi nào vào hàng đợi |
| `test/core/database/bill_upcoming_test.dart` | `getUpcoming` lọc cả hai cột trạng thái; `markOverdue` không ghi đè lần hai |
| `test/core/utils/relative_time_test.dart` | Biên 59 giây / 60 phút / qua nửa đêm |
| `test/shared/widgets/notification_bell_test.dart` | Chấm đỏ khớp số chưa đọc, bám dòng dữ liệu |
| `test/features/notification/notification_panel_test.dart` | Rỗng → biến mất hoàn toàn; >3 mục chỉ hiện 3 |

⚠️ `.gitignore` dòng 77 có `test/` → file test mới bị bỏ qua **âm thầm**. Phải
`git add -f` **từng đường dẫn** (thêm cả thư mục thì git từ chối nguyên lệnh).

**Chỉ kiểm được bằng máy thật/giả lập** (skill `chay-app` chạy Chrome headless
nên chỉ xác minh được phần trong-app): hộp thoại quyền Android 13+/iOS và hành
vi sau khi từ chối; thông báo nổ khi app **đóng hoàn toàn**; lịch sống sót sau
khởi động lại máy; nhấn thông báo mở đúng màn (cold vs warm start).

---

## 9. Commit đã tạo trong phiên 2026-09-04

```
8f4c72b  fix(bill): vá đường đẩy, trạng thái thanh toán và chu kỳ lặp
9c09fc6  feat(budget): cảnh báo khi chu kỳ ghi đè ngày kết thúc tự chọn
ee8c9e8  feat(notification): trung tâm thông báo trong app
9691b20  feat(notification): thông báo hoá đơn sắp đến hạn và quá hạn
```

Chưa push.
