# B5a — Nhật ký thông báo: ghi phản ứng của người dùng và lúc thông báo tới máy — thiết kế

**Ngày:** 2026-09-28 (tối), soạn trong lúc đo mốc 72 câu sau cổng F. **Người dùng duyệt** bản thiết kế trong chat cùng
ngày, với bốn lựa chọn: **bảng riêng** · giữ **180 ngày** · nút *Hoãn* lúc app đóng ghi qua **tệp hàng chờ** · **ghi
luôn** mốc thông báo tới máy (cột `osDeliveredAt` chưa từng được ghi). Vị trí trong lộ trình 28/09: B1 → **B5a** → B2 →
B3 → B4 → B5b (bản đồ `plans/2026-09-28-nhom-b-sau-b1-ban-do.md`, gitignore).

## 1. Vì sao

B5b (học giờ nhắc, đề xuất tắt nhóm thông báo bị lờ) cần **dữ liệu về phản ứng**, mà hôm nay app không ghi gì cả:

- `AppNotifications.readAt` gộp *mở thông báo*, *nhấn giữ đánh dấu đã đọc* và *Đọc tất cả* làm **một** dấu.
- Cú chạm thông báo hệ điều hành đi thẳng từ `OsNotifier` qua `NotificationTapRouter` tới router mà không để lại gì.
  Nút *Hoãn* cũng vậy, và khi app đã đóng thì nó chạy trong isolate nền không có CSDL.
- ⚠️ Cột `AppNotifications.osDeliveredAt` (chú thích: *"Đã bắn ra hệ điều hành chưa"*) **không được ghi ở đâu cả**:
  quét `lib/` ngày 2026-09-28 chỉ thấy khai báo. Không biết thông báo nào đã tới máy thì không suy ra được *"người dùng
  lờ đi"*.
- Lịch đặt trước (nhắc hoá đơn, kỳ trích, nhắc ghi chép, tổng kết tuần) nổ trong AlarmManager lúc app không chạy. Nhắc
  ghi chép **không bao giờ** có hàng `AppNotifications`, nên riêng cột `osDeliveredAt` không chứa được thông tin này.

B5a chỉ **ghi**. Không chỗ nào đọc bảng mới (B5b mới đọc), không đổi `dedupeKey`, không đổi luật sinh thông báo, không
có giao diện mới nên không cần Stitch.

## 2. Bảng `AppNotificationEvents` — schema v26, cục bộ, chỉ thêm hàng

Tệp `core/database/tables/notification_event_table.dart`, theo khuôn `ai_feedback_table.dart`: **không** có
`syncStatus` / `syncError` / `updatedAt` / `isDeleted` (quy tắc 9 `CLAUDE.md`). Tiền tố `App` theo `AppNotifications`,
vì Drift sinh data class số ít.

| Cột | Kiểu | Ý nghĩa |
|---|---|---|
| `id` | text, khoá chính | UUID |
| `idaccount` | int | từ phiên đăng nhập (quy tắc 2). Mọi phép đọc **bắt buộc** lọc theo cột này |
| `dedupeKey` | text | khoá của thông báo, đúng chuỗi payload của hệ điều hành. Nhóm suy từ tiền tố lúc đọc (B5b) |
| `suKien` | text | một trong chín mã ở mục 3 |
| `luc` | datetime | lúc xảy ra; riêng `dat_lich` là **mốc hẹn nổ** |
| `osId` | int, nullable | `osScheduledId(dedupeKey)`, chỉ `dat_lich` / `huy_lich` — để `huy_lich` tra ngược khoá từ id |

- Không lưu `kind` hay *giờ trong ngày*: cả hai suy ra được lúc đọc, và cú chạm hệ điều hành chỉ mang `dedupeKey`.
- Migration `from < 26` → `createTable` (v25 thuộc B1). Thêm vào `purgeDataForOtherAccounts` và `purgeDataForAccount`.
  Test quét 15 (`ai_edge_cuc_bo_khong_dong_bo_test.dart`) thêm `AppNotificationEvent`, `app_notification_events`,
  `appNotificationEvents`, `NotificationEventDao` vào danh sách cấm.
- **Giữ 180 ngày**: `NotificationScanner`, ngay sau `dao.purgeOlderThan(clock().subtract(giuThongBao))`, dọn thêm hàng
  có `luc` cũ hơn `giuSuKien = Duration(days: 180)`. Thông báo chỉ giữ 90 ngày, nhưng lịch sử phản ứng phải sống lâu hơn
  chính thông báo, vì B5b học trên nhiều quý.
- `NotificationEventDao`: `ghi(...)`, `ghiNhieu(...)` (một giao tác), `datLichGanNhat(idaccount, osId)` (cho `huy_lich`),
  `coDatLich(idaccount, dedupeKey)` (cho bộ nhập tệp hàng chờ), `purgeOlderThan(cutoff)`.

## 3. Chín sự kiện và nơi ghi

| `suKien` | Nghĩa | Ghi ở đâu |
|---|---|---|
| `mo_trong_app` | chạm một dòng ở trung tâm thông báo | `notification_center_page.dart`, `onTap` (cạnh `dao.markRead`) |
| `gat_bo` | vuốt xoá một dòng | `_xoaCoHoanTac`, sau `dao.dismiss` |
| `khoi_phuc` | bấm *Hoàn tác* sau khi vuốt | `SnackBarAction.onPressed`, sau `dao.khoiPhuc` |
| `doc_tat_ca` | bị *Đọc tất cả* đánh dấu — **một hàng mỗi thông báo** chưa đọc lúc bấm | nút *Đọc tất cả*: đọc danh sách chưa đọc → `markAllRead` → `ghiNhieu` |
| `cham_hdh` | chạm thân thông báo hệ điều hành | `NotificationTapRouter` (mục 4) |
| `nut_tra_ngay` | bấm nút *Trả ngay* | `NotificationTapRouter` (mục 4) |
| `hoan` | bấm nút *Hoãn 1 ngày* | app sống: `NotificationTapRouter`; app đóng: tệp hàng chờ (mục 5) |
| `dat_lich` | một lịch vừa được đặt, `luc` = mốc hẹn | `ReminderScheduler.resync` sau `zonedSchedule` (mục 6) |
| `huy_lich` | một lịch bị huỷ trước khi nổ | `resync` khi `cancel`; `NotificationScanner.stop` trước `cancelAll` (mục 6) |

- **Một cửa ghi:** lớp `NhatKyThongBao` (`core/notification/nhat_ky_thong_bao.dart`, đăng ký DI) bọc
  `NotificationEventDao`. Trang trung tâm, hook của router, scanner và scheduler đều gọi qua nó. Nó nhận `idaccount`
  qua một hàm đọc phiên (`int? Function()`, cùng khuôn `dangDangNhap` của router) và nuốt lỗi. Riêng scanner và
  scheduler đã biết `idaccount` nên truyền thẳng vào.
- **Không ghi** thao tác nhấn giữ đổi đã đọc / chưa đọc: đó là dọn danh sách, không phải phản ứng với nội dung.
- **Không ghi** *"không phản ứng"*. B5b suy ra nó lúc đọc: thông báo đã tới máy mà không có phản ứng nào sau đó.
- Mọi lời ghi **nuốt lỗi** kèm một dòng `debugPrint`. Nhật ký hỏng không được làm hỏng thao tác của người dùng.
- `idaccount` lấy từ phiên như mọi chỗ khác; không có phiên thì **không ghi**.

## 4. Cú chạm thông báo hệ điều hành — một chỗ khử trùng

Hôm nay `OsNotifier` chỉ phát chuỗi **đã biến đổi** (`khoaSauChamNut`: *Trả ngay* thành `billOpen:<id>`), còn *Hoãn*
khi app đang sống thì không phát gì. Nhật ký cần payload **gốc** và `actionId`, nên:

- `OsNotifier` **thay** `Stream<String> payloadDaCham` và `Future<String?> payloadKhoiDong()` bằng kiểu
  `ChamHdh(payload, actionId)` cùng hai lối **thô**: `Stream<ChamHdh> get chamTho` (app đang sống, **kể cả** *Hoãn*)
  và `Future<ChamHdh?> chamKhoiDong()` (khởi động nguội; **không bao giờ ném**, như lối cũ). Router là người dùng
  **duy nhất** của hai lối cũ (quét 2026-09-28), nên giữ chúng là để lại API chết. `LocalOsNotifier._khiChamVaoThongBao`
  vẫn tự đặt lịch hoãn như hôm nay, nhưng **luôn** phát vào `chamTho`, kể cả với *Hoãn*.
- `khoaSauChamNut` chuyển từ `LocalOsNotifier` sang **router**, vẫn là hàm thuần ở `notification_actions.dart`. Bẫy
  *"hai đường vào của một cú bấm phải quyết định giống nhau"* (vấp 2026-09-07) giờ được giữ **bằng cấu trúc**: cả hai
  đường đổ về cùng **một** `_xuLy`.
- `NotificationTapRouter` nhận thêm một hook tuỳ chọn `ghiCham(ChamHdh)`, mặc định không làm gì. **Một** hàm `_xuLy`
  làm ba việc: khử trùng bằng đúng `_boQuaMotLan` hiện có, gọi `ghiCham`, rồi điều hướng bằng `khoaSauChamNut` (bỏ qua
  *Hoãn*, như hôm nay). Như vậy một cú chạm Android vừa nằm trong chi tiết khởi động vừa đi qua callback vẫn chỉ thành
  **một** hàng.
- ⚠️ **Bảy** tệp test tự viết bản giả `OsNotifier` phải đổi hai thành viên (`notification_tap_router_test`,
  `notification_scanner_test`, `badge_updater_test`, `reminder_scheduler_test`, `reminder_scheduler_auto_pay_test`,
  `notification_settings_page_test`, và các ca `payloadDaCham` / `payloadKhoiDong` của `os_notifier_native_test`).
  Kỳ vọng **route** của bộ test router không đổi; chỉ cách bơm cú chạm đổi (`ChamHdh(khoa, null)` thay cho `khoa`).
- Mã sự kiện: `actionId == hanhDongTraNgay` → `nut_tra_ngay`; `== hanhDongHoan` → `hoan`; còn lại → `cham_hdh`. Đây là
  hàm thuần `suKienTuCham(ChamHdh)`, có test.
- ⚠️ Cú chạm tới **trước khi đăng nhập** (token hết hạn) vẫn được ghi **sau khi** có phiên, cùng lúc router xả
  `_choDoi`. Không ghi được thì bỏ, không đoán tài khoản.

## 5. *Hoãn* lúc app đã đóng — tệp hàng chờ

`khiChamNutLucAppDong` chạy trong isolate nền: không DI, không CSDL, không phiên.

- **Ghi:** ngay sau khi dựng `LichHoan`, nối **một dòng JSON** `{"k": dedupeKey, "t": <ISO-8601 lúc bấm>}` vào tệp
  `<getApplicationDocumentsDirectory()>/su_kien_thong_bao_cho.jsonl` (`FileMode.append`, `flush: true`). Nuốt mọi lỗi,
  như `_datLichHoanTuIsolateNen`. Việc dựng dòng là hàm thuần `dongHangCho(...)`, có test.
- **Nhập:** trong `NotificationScanner.start(idaccount)`, trước lượt quét đầu. `AuthBloc` khởi động scanner ngay khi có
  phiên (`auth_bloc.dart`, hai chỗ), nên không phải đụng vào `AuthBloc`. Đổi tên tệp sang `.dang_nhap` trước khi đọc,
  để một cú *Hoãn* đúng lúc ấy ghi vào tệp mới thay vì bị xoá mất. Mỗi dòng chỉ được nhận khi `dedupeKey` khớp một
  `dat_lich` **hoặc** một hàng `AppNotifications` của **tài khoản đang đăng nhập**. Dòng không khớp (người khác đăng
  nhập giữa chừng) và dòng hỏng thì bỏ. Nhập xong thì xoá tệp `.dang_nhap`. Phần lọc là hàm thuần `locHangCho(...)`, có
  test cả ba ca.
- ⚠️ **Rủi ro chưa đo:** `path_provider` có gọi được trong isolate nền của `flutter_local_notifications` hay không. Đây
  là **task đầu** của kế hoạch, làm dạng spike trên Realme: thử bằng một bản build ghi một dòng, bấm *Hoãn* lúc app
  đóng, rồi kiểm tệp (bản debug `run-as` được). Không được thì dừng lại hỏi người dùng. Lối dự phòng là dựng đường dẫn
  `app_flutter` từ `Platform`, nhưng phải được duyệt trước.
- ✅ **Spike 2026-09-29 (Realme RMX2205, Android 13, bản debug): `path_provider` CHẠY trong isolate nền**, tệp ở
  `/data/user/0/com.flowmoney.flowmoney/app_flutter/`. Log: `[Hoãn] isolate nền nhận "billDue:…:2026-10-06:7"` rồi
  `[SPIKE] isolate nền ghi …/app_flutter/spike_hang_cho.jsonl OK`; tệp có đúng một dòng JSON. Thông báo thử sinh bằng
  một hoá đơn *Hàng tuần* hạn 7 ngày tới, nhắc trước 7 ngày — vòng quét bắn ngay, có đủ hai nút.
  ⚠️ **Phát hiện đổi giả định của mục 4:** cú bấm *Hoãn* tới **isolate nền** (`ActionBroadcastReceiver`) **kể cả khi
  tiến trình app còn sống** (app ở nền sau phím Home, cùng pid) — nhánh *Hoãn* trong `_khiChamVaoThongBao` của isolate
  chính **không** chạy trên Android. Nên trên Android **mọi** hàng `hoan` đi qua tệp hàng chờ, không riêng lúc app đóng;
  tệp chỉ được nhập ở `NotificationScanner.start`, nên hàng có thể vào bảng muộn tới lần khởi động sau — không sai, vì
  mỗi dòng mang mốc `t` của chính cú bấm. Chưa đo ca app đang **mở trên màn** rồi kéo khay bấm *Hoãn*.
  ⚠️ Không "đóng app" được bằng `am force-stop` hay vuốt khỏi Recents trên Realme: cả hai **force-stop**, mà force-stop
  huỷ luôn thông báo và `PendingIntent` của nút. `am kill` không giết tiến trình còn là *previous process*, và
  `run-as … kill` bị SELinux chặn trên Android 13 (`Permission denied`) — khác máy ảo API 36.

## 6. Thông báo tới máy lúc nào

**Thông báo bắn ngay** (`NotificationScanner._banRaHeDieuHanh`):

- Sau mỗi `os.show` thành công, ghi `osDeliveredAt = clock()` cho hàng ấy. `NotificationDao` thêm hàm
  `danhDauDaBan(idaccount, dedupeKey, luc)`.
- Chỉ ghi khi `os.daCoQuyen()` trả `true`. Gọi **một lần** cho cả lô, vì Android 13 trở lên nhận `show` im lặng mà không
  hiện gì khi quyền bị tắt.
- Sửa chú thích cột theo đúng nghĩa: *"đã giao cho hệ điều hành lúc quyền đang bật"*.

**Lịch đặt trước** (`ReminderScheduler.resync`):

- Sau mỗi `zonedSchedule` thành công, ghi `dat_lich` với `luc = l.when` và `osId = l.id`.
- Trước mỗi `cancel(id)`, tra `datLichGanNhat(idaccount, id)`. Có hàng mà mốc còn ở tương lai thì ghi `huy_lich` với
  cùng `dedupeKey` và `osId`, `luc = at`.
- Chỉ ghi `dat_lich` khi `daCoQuyen()` trả `true` (hỏi một lần mỗi lượt `resync`).
- `NotificationScanner.stop()`: **trước** `cancelAll()`, ghi `huy_lich` cho mọi `dat_lich` có mốc ở tương lai của tài
  khoản đang đăng xuất. Nếu không làm vậy, lần đăng nhập lại sẽ đọc những lịch đã bị huỷ thành *"đã tới máy"*.
- *Hoãn* đặt lại lịch cùng khoá, nhưng **không** ghi `dat_lich`: hàng `hoan` đã mang đủ thông tin, lịch mới nổ ở
  `luc + buocHoan`.
- B5b suy *"đã tới máy lúc T"* khi có một `dat_lich` mốc T đã qua và không có `huy_lich` nào của cùng `dedupeKey` sau
  nó. Phép suy này thuộc B5b, không nằm trong B5a.

## 7. Giới hạn nói trước

- Vuốt bỏ thông báo khỏi **khay hệ điều hành** không ghi được, vì plugin không báo sự kiện này. B5b sẽ đọc nó thành
  *"không phản ứng"*.
- Quyền thông báo bị tắt **sau** khi lịch đã đặt: `dat_lich` vẫn nằm đó, nên B5b sẽ đọc thành *"đã tới máy"*. Quyền được
  bật **sau** khi lịch đã đặt thì lịch vẫn nổ, nhưng không có `dat_lich`, vì `resync` không đặt lại id đang chờ.
- iOS chưa được đo. Dự án đo trên Android; tệp hàng chờ dùng `path_provider` nên về nguyên tắc chạy được trên cả hai.

## 8. Kiểm thử

- **DAO + migration:** v25 → v26 tạo bảng; những test đang khoá số phiên bản (`schema_v24_test`,
  `bill_schema_v21_test`, sau B1 là 25) đổi sang 26. Hai hàm purge xoá bảng
  mới; dọn 180 ngày không đụng hàng 179 ngày.
- **Hàm thuần:** `suKienTuCham` (ba mã, `actionId` lạ → `cham_hdh`); `dongHangCho` và `locHangCho` (khớp `dat_lich`,
  khớp thông báo, không khớp, dòng hỏng).
- **Router:** chi tiết khởi động và callback cùng một payload → `ghiCham` đúng **một** lần; *Hoãn* được ghi mà không
  điều hướng; chưa đăng nhập → ghi sau khi đăng nhập; *Trả ngay* ở **cả hai** đường → route `billOpen:` như nhau. Mọi
  kỳ vọng route của bộ test router cũ giữ nguyên.
- **Trung tâm thông báo (widget):** chạm → `mo_trong_app`; vuốt → `gat_bo`; hoàn tác → `khoi_phuc`; *Đọc tất cả* với
  ba thông báo chưa đọc và một đã đọc → **ba** hàng `doc_tat_ca`; nhấn giữ → **không** ghi gì.
- **Scanner / scheduler:** `show` khi có quyền → `osDeliveredAt` được ghi; không quyền → không ghi; `resync` đặt một
  lịch → một `dat_lich`; `resync` huỷ một lịch → một `huy_lich` đúng khoá; `stop()` → `huy_lich` cho lịch tương lai,
  không cho lịch đã qua.
- **Test quét 15** đỏ khi thêm một tên cấm vào `sync_engine.dart` (thử bằng bản sai).
- **Máy thật (Realme):** spike ở mục 5; rồi một buổi nghiệm thu gồm bấm *Hoãn* lúc app đóng rồi mở app (một hàng
  `hoan`), chạm thông báo lúc app đóng (một hàng `cham_hdh`, không phải hai), *Trả ngay* (`nut_tra_ngay`). Bản debug
  cho phép `run-as` để đọc SQLite, nhớ chép cả `-wal` (bẫy 4.9).

## 9. Tài liệu đi kèm

`NOTIFICATION_FEATURE.md` thêm một mục về nhật ký thông báo: chín mã, hai chỗ ghi đặc biệt (router, tệp hàng chờ), giới
hạn ở mục 7, và câu *"bảng chỉ ghi, B5b mới đọc"*. `CLAUDE.md`: schema v26 và mốc test mới.
