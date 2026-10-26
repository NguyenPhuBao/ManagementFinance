# `docs/Notification/Notification_Client-app.md` tả client lệch mã ở ~30 chỗ — xin sửa chữ (mục 46)

> 🔎 **Client soát lại 2026-10-26** (`main` @ `5bb258ff`): **chưa làm** — tệp không đổi từ `3a5d320c` (2026-10-16). Câu
> `grep` kiểm lại ra **24** dòng: 18 là chỗ đơn nêu, số dòng trôi +3 (4, 52, 119–120, 168, 180, 185–186, 191, 210, 245–246, 261,
> 275, 284, 294–295, 358); 6 dòng (25, 68, 87–90) là phần tả đường REST của backend — câu kiểm của đơn bắt nhầm, không tính.
> Dòng 45 (`transaction`) và 50 (7 chip) cũng chưa sửa.

**Ngày:** 2026-10-17 · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat` (HEAD `172e8ee9`)
**Loại:** đơn xin — **chỉ sửa chữ** trong một tài liệu do backend quản (`docs/Notification/Notification_Client-app.md`,
commit cuối `10ab14c3`, 2026-10-03, NPBao; 380 dòng). **Không** đổi mã, lược đồ, payload, endpoint. Client không sửa thẳng
tài liệu này (quy tắc 1 `CLAUDE.md`: tài liệu do backend tạo là vùng chỉ đọc).

Mọi số dòng dưới đây là số **hiện tại** của tệp ở `10ab14c3` (hai đơn cũ dẫn số lệch một dòng). Mọi đường dẫn mã tính từ
`src/Client-app/lib/`. Mỗi hàng đã đối chiếu bằng **đọc mã** client ngày 2026-10-17.

## Vì sao client gửi đơn này

Tài liệu tự nhận là *"Đặc tả kỹ thuật & Hướng dẫn triển khai tích hợp"* cho client. Ai làm theo nó hôm nay sẽ: mở thư mục
không còn tồn tại (`core/notification/` đã dời sang `features/notification/` ngày 2026-10-15), chép mã mẫu không biên dịch
(`DioClient` không có `get/patch/post`; `switch` thiếu nhánh không có `default`), gọi đường `/api/api/notifications` (404),
và tin rằng client chưa có những thứ đã có từ lâu (số đếm trên chuông, thẻ chờ xoá). Hai đơn trước (`DA-XONG/SOAT_SAU_GOP_B350D40.md`
2026-09-30, `DA-XONG/SOAT_SAU_GOP_A7C03B7.md` 2026-10-01) đã báo một phần; backend sửa được phần payload socket và số
nhóm / số loại ở bảng đầu, phần còn lại **vẫn sai** (đánh dấu **[cũ]**). Hàng **[mới]** là chỗ chưa đơn nào nêu.

## (a) Đường dẫn / tên tệp sai

| Dòng | Câu trong tài liệu | Thực tế trong mã client | Đề nghị |
|---|---|---|---|
| 4 | Phạm vi: `src/Client-app/lib/core/notification/` | Thư mục **không còn** — dời sang `features/notification/` ngày 2026-10-15 | Bỏ `core/notification/`; nên thêm `core/database/tables/notification_table.dart`, `core/database/daos/notification_dao.dart`, `features/home/presentation/widgets/the_cho_xoa_trang_chu.dart` **[mới]** |
| 52 | `lib/core/notification/os/os_notifier_native.dart` và `reminder_scheduler.dart` | `features/notification/data/datasources/os_notifier_native.dart` · `features/notification/application/reminder_scheduler.dart` | Hai đường dẫn ấy **[mới]** |
| 291 | `NotificationTapRouter` (`lib/core/notification/notification_tap_router.dart`) | `features/notification/application/notification_tap_router.dart` | Đường dẫn ấy **[mới]** |
| 116, 117, 272 | Liên kết `file:///d:/Tai_Lieu_IUH/…/src/Client-app/…` | Đường tuyệt đối trên một máy khác — chết trong repo. Ba tệp đích có thật: `core/realtime/realtime_event.dart`, `core/realtime/realtime_channel.dart`, `shared/widgets/notification_bell.dart` | Đường tương đối `src/Client-app/lib/…` **[mới]** |
| 281 | `features/home/presentation/widgets/pending_delete_banner.dart` | Không có tệp này. Thẻ chờ xoá **đã có**: `features/home/presentation/widgets/the_cho_xoa_trang_chu.dart` (`TheChoXoaTrangChu`), gắn ở `features/home/presentation/pages/home_page.dart` | `the_cho_xoa_trang_chu.dart` **[cũ]** |
| 355 | `notification_visuals.dart` (hoặc `NotificationCenterPage`) | Không có tệp này. Màu theo `severity`, biểu tượng theo **`subjectType`** (không theo `kind`) ở `features/notification/presentation/pages/notification_center_page.dart` (`_ThongBaoTile`) và `features/notification/presentation/widgets/notification_panel.dart`; tên nhóm ở `…/widgets/cai_dat_thong_bao/ten_nhom_thong_bao.dart` | Nêu hai chỗ ấy; ghi rõ loại mới cần một `subjectType`, không thì rơi về `Icons.notifications_none` **[cũ]** |
| 146 *(gợi ý)* | Tệp mới `features/notification/data/api/notification_api_client.dart` | Không mảng nào có `data/api/`; khuôn của dự án: `data/datasources/*_remote_data_source.dart` (vd. `features/auth/data/datasources/auth_remote_data_source.dart`) | `features/notification/data/datasources/notification_remote_data_source.dart` **[mới]** |

## (b) Tên hàm / lớp / route không tồn tại

| Dòng | Câu trong tài liệu | Thực tế trong mã client | Đề nghị |
|---|---|---|---|
| 45 | Nhóm `transaction`: biến động số dư / biên lai (D1) | Nhóm thứ sáu tên **`bienDong`** (`features/notification/domain/notification_prefs.dart`, `nhomCua`) | `bienDong` **[mới]** |
| 154, 164, 177, 183, 188 | `final DioClient _dio;` rồi `_dio.get('/api/notifications', …)` … `_dio.post('/api/notifications/read-all')` | `DioClient` chỉ lộ getter `Dio get dio` (`core/api/dio_client.dart`) — mã mẫu không biên dịch. `baseUrl` đã kết thúc bằng `/api` (`core/constants/app_constants.dart`) nên đường thành `/api/api/notifications` (404). Khuôn thật: `sl<DioClient>().dio`, đường không có `/api` (vd. `dio.post('/auth/cancel-delete')`) | Nhận `Dio`; đường `'/notifications'`, `'/notifications/unread-count'`, `'/notifications/$id/read'`, `'/notifications/read-all'` **[cũ]** |
| 242 | `dao.markAsRead(id)` | `markRead(String id)` (`core/database/daos/notification_dao.dart`); giao diện gọi qua `ThongBaoRepository.markRead` / `markAllRead(idaccount)` (`features/notification/data/repositories/thong_bao_repository.dart`) | `ThongBaoRepository.markRead(id)` / `markAllRead(idaccount)` **[cũ]** |
| 254–258 | `syncMissedServerNotifications()` … `_dao.insertServerNotification(item)` | Cả hai không tồn tại. DAO có `insertIfAbsent(AppNotificationsCompanion)` / `insertAllIfAbsent(...)`; repository có `chenLai(NotificationEntity)` | Ghi rõ là **hàm cần tạo mới**, hoặc dùng `insertIfAbsent` với `dedupeKey = 'server_<id>'` **[cũ]** |
| 291 | "Mở rộng `NotificationTapRouter`" theo từng `kind` | Router không ánh xạ theo kind: nó gọi `dieuHuong(deeplinkTuDedupeKey(…))`, `dieuHuong` chỉ nhận một chuỗi route. Bảng ánh xạ là `deeplinkTuDedupeKey` (`features/notification/domain/notification_deeplink.dart`) — `switch` theo **tiền tố `dedupeKey`**, khoá lạ rơi về `/notifications`. Chạm trong app dùng cột `deeplink` của hàng | "Thêm nhánh `server_…` vào `deeplinkTuDedupeKey` (chạm thông báo hệ điều hành) và đặt cột `deeplink` khi ghi hàng (chạm trong app)". Router không mở được Modal / BottomSheet (dòng 293) — chỉ trả route **[mới]** |
| 292 | `accountCountdown` → `/profile/account-security` | Không có route này. Có: `/profile`, `/settings`, `/settings/change-password`, `/settings/delete-account` (`core/router/app_router.dart`) | `/profile` (hộp đếm ở thẻ Vùng nguy hiểm) hoặc `/settings/delete-account` **[cũ]** |
| 294 | `securityAlert` → trang Lịch sử đăng nhập / Đổi mật khẩu | Không có trang Lịch sử đăng nhập; chỉ có `/settings/change-password` | `/settings/change-password` **[mới]** |

## (c) Con số lệch

| Dòng | Câu trong tài liệu | Thực tế | Đề nghị |
|---|---|---|---|
| 207 | `// ... 19 loại hiện tại ...` | **20** loại (`NotificationKind`, phần tử cuối `bienDongSoDu`). Dòng 40 của chính tài liệu đã ghi 20 | `// ... 20 loại hiện tại ...` **[cũ]** |
| 50 | Bảy chip lọc: Tất cả · Chưa đọc · Hoá đơn · Ngân sách · Mục tiêu · Hệ thống · Tổng kết | **8** chip — thêm **Biến động** ở cuối (`notification_center_page.dart`; test canh số chip = `NotificationGroup.values.length + 2`) | Thêm `Biến động` **[mới]** |

## (d) Hành vi tả sai

| Dòng | Câu trong tài liệu | Thực tế | Đề nghị |
|---|---|---|---|
| 17 | `NotificationScanner: Quét định kỳ` | **Không** có `Timer.periodic`: quét khi `SyncEngine.statusStream` báo kết thúc một lượt và khi app trở lại `resumed` (`features/notification/application/notification_scanner.dart`) | "Quét sau mỗi lượt đồng bộ và khi app mở lại" **[mới]** |
| 18 | `ReminderScheduler: Bắn OS Notification` | `ReminderScheduler` **đặt lịch trước** (AlarmManager) cho hoá đơn, kỳ trích, nhắc ghi chép; thông báo hệ điều hành tức thời do `NotificationScanner` bắn | Tách hai vai *(thấp)* **[mới]** |
| 29 | `Sock -.->\|ocr.completed, sync.completed\| RTChan` | Client còn nhận `ocr.duplicate`, `account.upgraded`, `account.permissions_updated` (`core/realtime/realtime_event.dart`); `account.force_logout` đi luồng riêng `buocDangXuat` (`core/realtime/realtime_channel.dart`) | Liệt kê đủ sáu tên **[mới]** |
| 58 | "nó **hoàn toàn bị cô lập** khỏi luồng thông báo từ Backend và Admin-web" | Client **có** nhận sự kiện do admin / backend phát: `account.force_logout` (admin khoá / đá phiên → hộp thoại), `account.upgraded`, `account.permissions_updated`. Client chỉ chưa nhận **ba sự kiện thông báo** và REST `/notifications` | "Chưa nhận ba sự kiện thông báo và REST `/notifications`" *(thấp)* **[mới]** |
| 62 (cột Tác động) | Người dùng chờ xoá "**không nhận được** cảnh báo đếm ngược 30 ngày ân hạn trên app" | Người dùng **thấy** số ngày còn lại qua `/auth/profile` `countdown` (`features/auth/data/repositories/auth_repository_impl.dart`, `features/auth/domain/dem_nguoc_xoa.dart`): thẻ `TheChoXoaTrangChu` ở Trang chủ và hộp đếm trong thẻ Vùng nguy hiểm (`features/profile/presentation/widgets/vung_nguy_hiem_card.dart`). Chỉ **sự kiện socket** `account.countdown` bị bỏ qua | "Không nhận sự kiện socket `account.countdown`; số ngày vẫn hiện, lấy từ `/auth/profile`" **[mới]** |
| 72, 76–109 (§3) | "Client-app **cần triển khai 5 hạng mục**" | Client mới nhận **một** việc — số đếm trên chuông, xong 2026-09-30 (`shared/widgets/notification_bell.dart`); thẻ chờ xoá có từ G33. Phần socket, REST, kéo bù **chưa nhận** (đơn B350D40), vì vướng hai quy ước: payload socket là **hộp đen** (ngoại lệ duy nhất `account.force_logout`), bảng `AppNotifications` là **cục bộ**, không đồng bộ (`core/database/tables/notification_table.dart`) | Thêm dòng trạng thái đầu §3: 5A xong, 5B có sẵn (tên khác), 1–4 client chưa nhận **[mới]** |
| 274–277, 365 | §3.5 A "Thay chấm đỏ tĩnh bằng Badge đếm số"; checklist `- [ ] Nâng cấp NotificationBell…` | **Đã xong 2026-09-30**: `nhanSoChuaDoc` — 0 ẩn, 1–99 đúng số, > 99 `99+`. Dòng 66 của chính tài liệu đã ghi xong | Ghi "✅ đã làm 2026-09-30", đánh `[x]` ở dòng 365 **[mới]** (A7C03B7 chỉ báo dòng 65) |
| 283 | Banner hiện "khi nhận sự kiện `account.countdown` hoặc khi `AuthBloc` báo `PendingDelete`" | Chỉ hiện theo `AuthSuccess` có `user.dangChoXoa` (`home_page.dart`, `the_cho_xoa_trang_chu.dart`); socket `account.countdown` bị bỏ qua (`realtime_event.dart`, nhánh `default`) | Bỏ vế "khi nhận sự kiện `account.countdown`" **[mới]** |
| 284–287 | "Banner viền cam/đỏ **trên đầu trang Home / Profile**"; chữ "⚠️ Tài khoản đang trong thời gian chờ xoá! / Còn X ngày… / [Hủy xoá tài khoản ngay]" | **Home**: thẻ nền `errorContainer` viền đỏ dưới header; chữ *"Tài khoản đang chờ xoá"* và *"Còn **X ngày** nữa tài khoản và toàn bộ dữ liệu sẽ bị xoá vĩnh viễn."*; hai nút *"Để sau"* (ẩn trong lần mở app) và *"Huỷ xoá"*. **Profile**: không có banner đầu trang — chỉ hộp đếm trong thẻ Vùng nguy hiểm | Chép đúng chữ và vị trí **[mới]** |
| 288 | Bấm "Hủy xoá" **chuyển hướng** sang màn xác nhận phục hồi | Không có màn trung gian: nút gọi `repo.cancelDelete()` (`features/auth/presentation/widgets/huy_yeu_cau_xoa.dart`) → `POST /auth/cancel-delete`; thành công thì thẻ biến mất, lỗi thì hiện toast | "Gọi thẳng `POST /auth/cancel-delete`, không có màn trung gian" **[mới]** |
| 223–236 | Mã mẫu `nhomCua` kết thúc ở `case weeklySummary: return NotificationGroup.summary;` | Còn `case NotificationKind.bienDongSoDu: return NotificationGroup.bienDong;` — `switch` **không có `default`** nên mẫu chép theo không biên dịch | Thêm nhánh `bienDongSoDu` **[mới]** |
| 352–355 (checklist bước 1) | Chỉ nhắc `NotificationKind`, `nhomCua`, "visuals" | Thêm loại mới còn **bắt buộc** sửa `luonBao()` (`notification_prefs.dart`, cũng là `switch` không `default`) — thiếu là lỗi biên dịch | Thêm một dòng checklist cho `luonBao` *(thấp)* **[mới]** |
| 39, 49 | "Hỗ trợ xoá mềm `dismissedAt`"; "vuốt xoá mềm (Dismissible)" | Đúng với mọi loại **trừ** `bienDongSoDu`: vuốt là **xoá cứng** (`xoaCung`) kèm Hoàn tác bằng `chenLai`. Hàng cũ bị dọn sau 90 ngày, riêng `bienDongSoDu` 30 ngày (`notification_dao.dart`) | Thêm ngoại lệ D1 *(thấp)* **[mới]** |
| 43 | "khoản chi lớn **bất thường**" | `largeExpense` là khoản chi **vượt ngưỡng người dùng đặt** (mặc định tắt), không phải phát hiện bất thường (`notification_rules.dart`) | "khoản chi vượt ngưỡng người dùng đặt" *(thấp)* **[mới]** |
| 378 | Nội dung lưu trong SQLite "**không được chứa** … số dư cụ thể" | Thông báo **cục bộ** có số tiền: ví âm (`'… đang âm …'`), mục tiêu ("đã tích được …"), hàng D1 mang số tiền của tin ngân hàng (dọn sau 30 ngày) | Giới hạn câu ấy cho thông báo **từ server**, hoặc ghi ngoại lệ thông báo cục bộ *(thấp)* **[mới]** |
| 380 *(tuỳ chọn)* | Mọi kết nối "**bắt buộc** HTTPS/WSS với TLS 1.3" | `baseUrl` dev là `http://10.0.2.2:3000/api` / `http://127.0.0.1:3000/api`; dòng `https://…onrender.com/api` đang bị chú thích; client không ghim phiên bản TLS | "Khi triển khai cloud" *(thấp)* **[mới]** |

## Đã kiểm, đúng — không cần sửa

Dòng 36–41 (tệp bảng, khoá duy nhất `{idaccount, dedupeKey}` + `insertOrIgnore`, không cột đồng bộ, chữ ký `watchFeed`,
20 loại, 6 nhóm), 49 (trang 20 mục, nút "Tải thêm"), 62 (`default: return null`), 63–66 (chưa nghe `system.broadcast` /
`user.notification`, chưa có client REST, chuông có số), 120–121 (`buocDangXuat` luồng riêng), 147, 150, 238, 251–252
(`RealtimeChannel` nghe Connectivity, hook `onConnect` có thật — lưu ý: lớp này cố ý không gọi dịch vụ khác, nối dây ở
`main.dart`), 370 (`test/core/realtime/realtime_channel_test.dart` có thật).

## Ngoài phạm vi — phía backend, chỉ ghi để tiện soát (client không đo sâu)

- Dòng 265, lời hứa *"luôn đầy đủ thông báo … offline dài ngày"*: kho giữ 50 mục, TTL 30 ngày
  (`src/Backend/modules/notification/notification.store.js`), không Redis thì nằm trong bộ nhớ — đã báo ở A7C03B7, chưa sửa.
- Dòng 303 dẫn `notification.service.js:202` cho phần phát `account.countdown`; dòng 316 dẫn `:217-238` cho
  `system.broadcast` — số dòng đã trôi.
- Dòng 311, ví dụ `message` của `account.countdown` khác câu thật trong `core/scheduler.service.js`.

## Kiểm lại

- `grep -n "core/notification\|pending_delete_banner\|notification_visuals\|markAsRead\|insertServerNotification\|account-security\|/api/notifications\|19 loại\|file:///" docs/Notification/Notification_Client-app.md` → **0** dòng.
- Mọi đường dẫn `src/Client-app/lib/…` còn lại trong tài liệu tồn tại (`ls` từng đường).
- Mã mẫu Dart trong tài liệu (`nhomCua`, client REST) biên dịch được nếu chép vào (`switch` đủ nhánh, nhận `Dio`).

## Không chặn client

Client không chờ đơn này. Khi backend sửa xong, client soát lại bằng câu `grep` trên rồi chuyển đơn sang `DA-XONG/`.
