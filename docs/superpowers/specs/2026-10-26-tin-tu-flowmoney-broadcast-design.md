# Tin từ FlowMoney — hiện thông báo admin phát (`system.broadcast`) trên app

> Spec 2026-10-26 (phiên 11). Người dùng chốt qua câu hỏi chọn được: **chỉ tin admin gõ tay** · **Trung tâm thông báo + khay hệ
> điều hành** · **tin lúc không nối socket thì mất** (không đơn backend) · **nhóm riêng "Tin từ FlowMoney"** · hướng **A** (luồng
> riêng trên kênh thời gian thực). Bối cảnh: lượt soát năm mục tài liệu v4 (khối 🛰️ mục 14 `PROJECT_CONTEXT.md`).

## 1. Mục tiêu

Admin gõ một tin ở màn *Phát thông báo* (Admin-web) → người dùng đang mở app thấy tin ấy trong Trung tâm thông báo và trên khay /
màn khoá máy, như mọi thông báo khác của app. Hôm nay client bỏ qua `system.broadcast` (`realtime_event.dart`, nhánh `default`).

**Ngoài phạm vi:** tin bảo trì tự động (5 chỗ phát ở `maintenance.manager.js` — đã có dòng nhắc G89, và G89 đã chốt *không* hiện lý
do admin gõ cho bảo trì) · nhận bù tin phát lúc máy không nối socket · bản iOS (chưa có mã gốc thông báo) · màn chi tiết tin.

## 2. Backend hôm nay (đo mã `36f1ea43`, chỉ đọc)

- `POST /api/notifications/broadcast` (chỉ admin) → `notification.controller.js:151` → `notificationService.broadcast({title,
  message, level, sender_username, metadata: req.body.metadata || {}})`. Admin-web (`BroadcastPage.jsx:541`) gửi `{title, message,
  level}` — tiêu đề ≤ 120 ký tự, `level` **chữ thường** `info | warning | critical`; không gửi `metadata`.
- `notification.service.js:205-244`: dựng `{id (UUID), title, message, level, category: 'BROADCAST', metadata, isRead, readAt,
  createdAt}` (`notification.store.js:230` hoặc dự phòng cùng dạng) → `emitSystemBroadcast` → `io.emit('system.broadcast', …)` tới
  **mọi** socket đang nối (`core/socket.js:251`). Không có endpoint cho người dùng thường lấy lại tin (`/broadcast/history` chỉ admin).
- 5 tin bảo trì đi **cùng** đường, `metadata.type` ∈ `EMERGENCY_MAINTENANCE · SYSTEM_UPGRADE · SCHEDULED_MAINTENANCE ·
  UPGRADE_COMPLETED · MAINTENANCE_RESTORED`.
- Sự kiện có thể tới **hai lần** (event bus phát cục bộ rồi phát lại qua Redis — đơn 43 bảng §1) — cùng payload, cùng `id`.

## 3. Thiết kế

### 3.1 Bắt sự kiện — luồng riêng, ngoại lệ hộp đen thứ hai

`RealtimeChannel._khiCoSuKien` bắt tên `system.broadcast` **trước** `realtimeEventFromName`, đúng chỗ `account.force_logout` đang
đứng: không bao giờ vào `events`, không đánh thức đồng bộ, không toast. Cam kết *"`events` không đọc payload"* giữ nguyên; chú thích
đầu `realtime_event.dart` và `realtime_channel.dart` sửa từ *"một ngoại lệ"* thành **hai**, mỗi ngoại lệ một cửa riêng.

Phát ra luồng mới `RealtimeChannel.tinHeThong` (broadcast) mang `(idaccount của phiên đang nối, TinHeThong)`. Sau `stop()` không phát.

### 3.2 Đọc payload — một hàm thuần

`core/realtime/tin_he_thong.dart`: `TinHeThong? docTinHeThong(Object? payload)` → `TinHeThong {id, tieuDe, noiDung, mucDo}`:

| Đầu vào | Kết quả |
|---|---|
| payload không phải `Map` | `null` |
| `metadata` là `Map` và `metadata['type']` là chuỗi khác rỗng | `null` — tin bảo trì tự động |
| `id` không phải chuỗi khác rỗng | `null` — `id` là khoá chống trùng |
| `title` và `message` cùng rỗng sau `trim` | `null` |
| tiêu đề rỗng, nội dung có | tiêu đề `"Tin từ FlowMoney"` |
| tiêu đề dài > 120 / nội dung > 1.000 code point | cắt theo code point (`runes`) — không bao giờ cắt đôi cặp surrogate (emoji) |
| `level` (không phân biệt hoa thường) `info` / `warning` / `critical` | `NotificationSeverity` cùng tên |
| `level` thiếu / lạ | `info` |

Không đọc trường nào khác (`category`, `createdAt`, `sender_username`…).

### 3.3 Bộ nhận — `NhanTinHeThong` (`features/notification/application/`)

Nghe `RealtimeChannel.tinHeThong`; với mỗi tin:

1. Đọc `NotificationPrefs` của **idaccount kèm theo tin** (danh tính chỉ từ phiên — quy tắc 2).
2. `!prefs.chapNhan(NotificationKind.tinHeThong)` (nhóm `tinFlowMoney` tắt) → bỏ hẳn: không hàng, không khay.
3. `notificationDao.insertIfAbsent` một hàng: `kind: tinHeThong`, `dedupeKey: 'tinHeThong:<id>'`, `title`, `body`, `severity` theo
   `mucDo`, `subjectType: 'tinHeThong'`, **không** `deeplink` (chạm trong Trung tâm = đánh dấu đã đọc; nội dung đã hiện trọn ở hàng).
4. **Chỉ khi** `insertIfAbsent` trả `true` (hàng mới — tin tới lần hai bị nuốt) **và** `prefs.osBat && !prefs.dangImLang(bayGio)`:
   `OsNotifier.show(id: osScheduledId(dedupeKey), title, body, payload: dedupeKey)`; có quyền thì `danhDauDaBan` — đúng luật
   `NotificationScanner` (`notification_scanner.dart:712`, `_banRaHeDieuHanh`). Tắt công tắc tổng / đang giờ im lặng: tin vẫn vào
   Trung tâm.
5. Mọi lỗi nuốt có log — không làm hỏng kênh thời gian thực.

Nối dây **một lần** ở `main.dart` (cạnh `noiRealtimeVaoDongBo`). Engine nền (WorkManager) không mở socket → không đổi.
Bảng vẫn **cục bộ** (quy tắc 9) — máy thứ hai của cùng tài khoản, nếu đang mở app, nhận qua socket của chính nó.

### 3.4 Loại + nhóm mới

- `NotificationKind.tinHeThong` (loại thứ **21**). Hai `switch` không `default` ở `notification_prefs.dart`: `nhomCua` →
  `NotificationGroup.tinFlowMoney`; `luonBao` → `false` (chịu công tắc nhóm).
- `NotificationGroup.tinFlowMoney` — **mặc định BẬT** (kho lưu nhóm bị *tắt*, nên mọi tài khoản cũ tự bật; `batNhom` không đổi).
- `loaiTuKhoa` (`nhom_tu_khoa.dart`): `'tinHeThong' => NotificationKind.tinHeThong` (nhật ký B5a, học giờ).
- Chạm trên khay: khoá `tinHeThong:` rơi vào nhánh mặc định của `notification_deeplink.dart` → **Trung tâm thông báo** (`routeThongBao`).
- `notification_deeplink_test`: thêm `tinHeThong` vào `ngoaiBoQuet` (kèm lý do: không do bộ quét sinh) + ca canh khoá → Trung tâm.

### 3.5 Giao diện

- **Cài đặt thông báo** (`ten_nhom_thong_bao.dart`): tên **"Tin từ FlowMoney"**, mô tả **"Thông báo chung do đội ngũ FlowMoney
  gửi."**, biểu tượng `Icons.campaign_outlined` — hàng cuối khối *Loại thông báo*.
- **Trung tâm thông báo** (`notification_center_page.dart`): chip **"FlowMoney"** cuối dải lọc (`_Loc.tinFlowMoney`); hàng loại này
  biểu tượng `Icons.campaign_outlined` (nhánh `subjectType: 'tinHeThong'` của `_bieuTuong`), màu dải theo `severity` như sẵn có.
- **Stitch trước khi viết mã giao diện** (nếp dự án): thêm hàng vào màn *Cài đặt thông báo* `065eccd853504825b3148db4adaf5569` và chip
  vào màn *Trung tâm thông báo* `65dab65688594043ad53997cfd3547f3` (dự án `5106367939423432838`) — chỉ phần của việc này (hai màn còn
  thiếu cả nhóm *Biến động*, ngoài phạm vi). `edit_screens` hay báo thành công mà chưa đổi / có độ trễ → **hỏi người dùng nhìn xác nhận**.

## 4. Giới hạn (ghi vào `NOTIFICATION_FEATURE.md`)

- Chỉ máy **đang nối socket** nhận tin: app đóng hẳn, mất mạng, chưa đăng nhập lúc phát → **mất tin**, không nhận bù.
- Không đồng bộ giữa các máy; mỗi máy đang mở app nhận riêng.
- Người dùng đăng nhập tài khoản khác trên cùng máy không thấy tin đã nhận của tài khoản trước (hàng gắn `idaccount`).
- Không có màn chi tiết; nội dung dài hiện trọn trong hàng Trung tâm, khay hệ điều hành tự cắt.

## 5. Kiểm thử

- `test/core/realtime/tin_he_thong_test.dart` — mọi hàng bảng 3.2.
- `realtime_channel` — `system.broadcast` không lọt `events`; phát `tinHeThong` kèm idaccount; sau `stop()` không phát; tin bảo trì
  không phát.
- `nhan_tin_he_thong_test.dart` — nhóm tắt → không hàng / không `show`; cùng `id` hai lần → một hàng, một `show`; `osBat` tắt hoặc giờ
  im lặng → có hàng, không `show`; lỗi DAO / OS không ném.
- `notification_prefs` — nhóm mới mặc định bật; `nhomCua` / `luonBao`.
- Trung tâm — số chip = `NotificationGroup.values.length + 2` (ca sẵn có tự đếm); chip *FlowMoney* lọc đúng loại; Cài đặt có hàng mới.
- `notification_deeplink_test` — `ngoaiBoQuet` + khoá → Trung tâm; `loaiTuKhoa('tinHeThong:x')`.
- Nghiệm thu máy thật / máy ảo: backend dev chạy, admin phát tin `critical` → hàng + khay; tin bảo trì không hiện; phát hai lần
  cùng tin (giả lập) → một hàng.

## 6. Tài liệu cần sửa khi thi công

`NOTIFICATION_FEATURE.md` (bảng loại mục 3 + mục mới 5l), chú thích hộp đen ở `realtime_event.dart` / `realtime_channel.dart`,
hàng *kênh thời gian thực* và hàng *thông báo* (*"nay 20 loại"* → 21) trong `CLAUDE.md`, khối 🛰️ mục 14 `PROJECT_CONTEXT.md`.
