# G89 + phần client của đơn 43 — máy chủ chặn (bảo trì / phong toả) và tài khoản bị từ chối

**Ngày:** 2026-10-20 · **Nhánh:** `TranQuangDat` · **Trạng thái:** người dùng duyệt bản viết 2026-10-20; ✅ MÃ XONG + NGHIỆM THU OnePlus 13R ĐẠT 2026-10-20 (Task 12 — kết quả ở mục 12) (12 commit `b7ca4512..98d58c64`). **Phạm vi do người dùng chốt 2026-10-18:** một lượt gồm G89 (`docs/CLIENT_APP_KNOWN_GAPS.md`) và ba việc client
của đơn 43 (`docs/superpowers/backend/CAN-LAM/LICH-SU/SOAT_SAU_GOP_CD2EE572.md`): xét lại xoá SQLite khi `ACCOUNT_DELETED` · `connect_error`
có `data.code` → dừng nối lại + đăng xuất · `account.downgraded` → làm mới gói. Phần dư của đơn 43 phía backend **không** chặn lượt
này (người dùng chốt 2026-10-18).

## 1. Quyết định người dùng (2026-10-20)

| # | Câu hỏi | Chốt |
|---|---|---|
| 1 | Bảo trì: người dùng thấy gì | **Dòng nhắc ở Trang chủ**, cùng họ *Premium sắp hết hạn* / *ví trùng tên*; tự ẩn khi request kế thành công; toast đồng bộ nói lý do |
| 2 | Giãn cách đồng bộ lúc bảo trì | **Bảo trì không tính là lượt hỏng** — thử lại theo `Retry-After` |
| 3 | Phong toả AIOps | **Cùng dòng nhắc, nêu giờ hết hạn**; đồng bộ hẹn đúng lúc hết hạn, đổi mạng thì thử ngay |
| 4 | `ACCOUNT_DELETED` | **Không xoá SQLite ngay ở mọi nguồn** — mở rộng ngoại lệ G36 (2026-09-13) cho socket và request thường |
| 5 | Kiến trúc | **Một mô hình trạng thái chung** (hàm phân loại thuần + `ValueNotifier` không dính Dio, interceptor ghi) |
| 6 | Phần A · B · C của thiết kế | Duyệt từng phần trong phiên |

Hai việc đã chốt từ trước, không hỏi lại: `connect_error` có `data.code` → dừng nối lại + đăng xuất; `account.downgraded` →
làm mới gói (2026-10-15).

## 2. Sự thật đo được (đọc mã backend trên nhánh, 2026-10-20)

Bốn mục đầu (503 bảo trì, 503 đăng nhập, bắt tay socket, 403 phong toả) tự đọc lại sau báo cáo agent con; còn lại theo báo cáo
agent con (đọc mã, chỉ đọc), kế hoạch đo lại trước khi viết test phụ thuộc vào chúng.

- **503 bảo trì** — `src/Backend/middleware/maintenance.middleware.js:35-47`: body **phẳng**, `code: 'MAINTENANCE_MODE'` ở cấp
  gốc, `message` (lý do admin gõ hoặc câu mặc định), `isEmergency`, `activatedAt`; header `Retry-After: '60'` là **hằng**, không
  suy từ giờ kết thúc. Giờ kết thúc của phiên bảo trì **không** có trong body. Được đi qua: admin, `/health*`,
  `POST /api/auth/login`; `/sync/*` và `/auth/refresh` của người thường nhận 503.
- **503 lúc đăng nhập** — `src/Backend/modules/auth/auth.controller.js:61-73`: cùng hình dạng, có `code` + `Retry-After: 60`.
  ⚠️ Câu *"503 đăng nhập mất `code`"* trong G89 đã cũ (đơn 43 vế C đạt).
- **Bắt tay socket** — `src/Backend/core/socket.js:41-50`: từ chối vì tài khoản thì
  `Object.assign(new Error(...), {data: {code, idaccount, reason_inactive}})`, `code` ∈ {`ACCOUNT_INACTIVE`, `ACCOUNT_DELETED`};
  lỗi lược đồ / token / nội bộ là `Error` **không có `data`**. Socket không bị kiểm bảo trì, không bị kiểm phong toả.
- **403 phong toả** — `src/Backend/modules/aiops/aiops.quarantine.js:1096-1105`: `code` **và** `error` đều là
  `'AIOPS_QUARANTINED'`, `quarantineExpiresAt` (ISO hoặc `null`), `reason`; **không** có `Retry-After`. Xét **theo IP**
  (`req.ip`), miễn admin. Thời hạn: tự động 15–30 phút, admin mặc định 4 giờ. Phong toả theo **tài khoản** không ra 403 — nó
  ghi `Inactive` nên client thấy 401 `ACCOUNT_INACTIVE`.
- **Các 503 khác** (giữ nguyên hành vi hôm nay): `SERVER_OVERLOADED`, `DB_POOL_OVERLOADED`, và 503 lỗi lược đồ ở `auth.js`
  **không có `code`**. ⚠️ *2026-10-26 (sau spec này):* hai mã quá tải nay được `SyncEngine` miễn lượt hỏng ở lượt đẩy (tối
  đa 3 chu kỳ liên tiếp, `mocThuLaiKhiQuaTai`) — vẫn **không** qua `TrangThaiMayChu`, không dòng nhắc; xem bảng *Phân loại
  lỗi đẩy dữ liệu* `PROJECT_CONTEXT.md`.
- **`account.downgraded`** — `src/Backend/core/scheduler.service.js:319`: chỉ phát từ job 00:00 giờ VN, tới `account_<id>`.
  Từ lúc hết hạn tới khi job chạy, middleware đã trả 403 `{code: 'FEATURE_DISABLED', featureId, accountType}`
  (`src/Backend/middleware/feature-permission.middleware.js:51`). Hoàn tiền không đổi gói. Admin đổi ma trận quyền phát
  `account.upgraded` tới **mọi** socket (client đã `lamMoi` qua `taiKhoanNangCap`).
- **`accountRejection`** (`src/Backend/middleware/auth.js`): `Deleted` hoặc không có hàng → `ACCOUNT_DELETED`; mọi trạng thái
  khác ngoài `Active` / `PendingDelete` còn hạn → `ACCOUNT_INACTIVE`. Nhánh `delete_at` là mã chết (`getAccountValidity` không
  trả cột ấy). Request thường nhận 401, `code` ở cấp gốc.

**Phía client hôm nay:** `AuthInterceptor` chỉ xử lý 401; `GuiLoDongBo` xếp 403/503 vào `transportFailed` + `transient`, nên
`failed > 0` kéo engine vào giãn cách 30 giây → 60 phút; `ApDuLieuKeoVe.pullFromBackend` nuốt mọi lỗi; `RealtimeChannel`
`onConnectError` chỉ `debugPrint` rồi hẹn nối lại (2 → 60 giây, mãi); không ai nghe `account.downgraded`; `AuthBloc` gọi
`xoaDuLieu` khi `daXoa` ∧ nguồn ≠ `lamMoi`; Trang chủ chưa có dải / dòng nhắc nào về máy chủ.

## 3. Kiến trúc — mô hình trạng thái máy chủ (Phần A)

### 3.1 Hàm phân loại + mô hình — `lib/core/network/trang_thai_may_chu.dart` (không import Dio)

```dart
sealed class TinhTrangMayChu {}
final class MayChuBinhThuong extends TinhTrangMayChu {}
final class MayChuBaoTri extends TinhTrangMayChu { final DateTime thuLaiLuc; }
final class MayChuPhongToa extends TinhTrangMayChu { final DateTime? hetHanLuc; }

/// `null` = phản hồi này KHÔNG nói gì về trạng thái máy chủ → không đổi.
TinhTrangMayChu? phanLoaiPhanHoi({required int? status, Object? body, String? retryAfter, required DateTime bayGio});

class TrangThaiMayChu extends ValueNotifier<TinhTrangMayChu> { ... }   // DI, sống trong bộ nhớ
```

- 503 ∧ `body['code'] == 'MAINTENANCE_MODE'` → `MayChuBaoTri(thuLaiLuc: bayGio + max(Retry-After, kSanThuLai))`; `Retry-After`
  thiếu / không phải số nguyên dương → **60 giây**. **`kSanThuLai` = 30 giây** — server hôm nay gửi hằng 60, nhưng một bản sau
  gửi `Retry-After: 1` thì không có sàn là vòng request mỗi giây.
- 403 ∧ `body['code'] == 'AIOPS_QUARANTINED'` → `MayChuPhongToa(hetHanLuc: parse(quarantineExpiresAt))`; thiếu / rác → `null`.
- Chỉ đọc `code` ở **cấp gốc** của body là `Map`; mọi phản hồi khác trả `null` — kể cả 503 quá tải, 503 không `code`, 403
  `FEATURE_DISABLED`, 403 trạng thái tài khoản lúc đăng nhập. **Không bao giờ phân loại theo mã HTTP một mình.**
- Trạng thái **không gắn tài khoản** (bảo trì là chung, phong toả theo IP) — đăng xuất không xoá nó. Không lưu xuống đĩa.
- Vì sao ở `core/network`: chủ đề đã có (`ConnectionMonitor`), trang được đọc (`AppToast`, Trợ lý AI đang đọc) — dòng nhắc
  không phải chạm `core/api` (tinh thần quét 31), không thêm chủ đề `core` (quét 25), không thêm tệp `core/sync` (quét 35).

### 3.2 Interceptor ghi — `lib/core/api/interceptors/may_chu_interceptor.dart`

- Gắn vào Dio chung của app (`DioClient`), cạnh `AuthInterceptor`, không đụng nó.
- `onError`: `phanLoaiPhanHoi(...)` khác `null` → ghi vào `TrangThaiMayChu`.
- `onResponse` 2xx → `MayChuBinhThuong` (dòng nhắc tự ẩn).
- **Giả định ghi rõ:** Dio chung **chỉ** nói chuyện với backend của app — host bên thứ ba đã cấm trên nó (`AuthInterceptor` gắn
  token người dùng cho mọi host; bộ tải ảnh / mô hình dùng Dio riêng). Một lời gọi CDN đi qua Dio chung sẽ trả 2xx và **xoá nhầm**
  dòng nhắc; ca test canh rằng interceptor chỉ gắn vào `DioClient`.
- Phủ mọi request đi qua Dio chung: đồng bộ (đẩy **và** kéo), Trợ lý online, thanh toán, đăng nhập, `/auth/refresh`.
- Cũng là chỗ bắt 403 `FEATURE_DISABLED` cho mục 6.2 (hook, không ghi trạng thái máy chủ).

### 3.3 Đồng bộ — `SyncEngine` nhận cổng tuỳ chọn `trangThaiMayChu`

- Không truyền → hành vi y như cũ (test cũ không đổi). DI truyền bản thật.
- Cuối `_runSync`, nếu trạng thái là `MayChuBaoTri` → **không** `_registerFailedCycle`, hẹn thử lại đúng `thuLaiLuc` qua
  `_scheduleBackoffRetry` sẵn có (getter `backoffRetryAt` đo được). Áp cả khi **không có gì để đẩy** mà lượt kéo nhận 503.
- `MayChuPhongToa` có `hetHanLuc` → như trên, hẹn lúc **`max(hetHanLuc, bayGio + kSanThuLai)`**. Đổi mạng (`onConnectivityChanged`)
  thử ngay vì không còn giãn cách chặn. `hetHanLuc == null` → giãn cách như hôm nay.
- ⚠️ **Sàn là bắt buộc**: `_scheduleBackoffRetry` với mốc ở quá khứ hẹn `Duration.zero` (đọc mã 2026-10-20). `hetHanLuc` là giờ
  **server** — máy chạy nhanh giờ, hoặc 403 cũ về muộn, là mốc đã qua → thử ngay → 403 → thử ngay: vòng request dồn dập vào đúng
  IP mà AIOps đang theo dõi vì nghi DoS. Đây là kết cục duy nhất tính năng này không được phép sinh ra.
- Lượt bị chặn kết thúc bằng `SyncStatus.pending` (như mất mạng), **không** `error` — toast lý do do `TrangThaiMayChu` phát
  (mục 4.2); để `error` là bộ quét thông báo nổ "Đồng bộ hỏng" (`NotificationKind.syncFailed`) — `AppToast` không đọc `SyncStatus`.
- Thao tác đẩy hỏng lúc bảo trì vẫn `transient` (không đổi `GuiLoDongBo`).
- Hệ quả: tắt bảo trì xong khoảng 1 phút dữ liệu lên server, dòng nhắc ẩn.
- ⚠️ Quy ước *payload socket là hộp đen* giữ nguyên: **không** nghe `system.maintenance_changed` / `system.broadcast` (quyết
  định 2026-09-30) — nên client **không biết giờ kết thúc bảo trì**, và không chữ nào hứa giờ ấy.

## 4. Giao diện (Phần B) — Stitch `006c5a2eafc9461ab630163d1ff85de9`

Màn Stitch *"Trang chủ - Dòng nhắc máy chủ (3 biến thể) - FlowMoney"* (tạo 2026-10-20, lượt gọi báo timeout, người dùng xác nhận
màn đã có; chữ ba biến thể đối chiếu khớp HTML). Khuôn theo `f21e76fa…` *"Trang chủ - Dòng nhắc Premium sắp hết hạn"*.

### 4.1 `DongNhacMayChu` — `lib/features/home/presentation/widgets/dong_nhac_may_chu.dart`

- `ValueListenableBuilder` trên `sl<TrangThaiMayChu>()`; `MayChuBinhThuong` → không dựng gì (không đệm).
- Đứng **đầu** chồng dòng nhắc ở `home_page.dart` (nó giải thích vì sao mọi thứ khác chưa đồng bộ).
- Thẻ trắng, viền `outline-variant` 30 %, bo 12, đệm ngang 14, huy hiệu 24 × 24 bo 6; chữ **hai dòng**: tiêu đề 13 px
  `on-surface`, dòng phụ 11 px `#454743`. **Không** nút, **không** ✕ (tự ẩn).

| Trạng thái | Huy hiệu | Tiêu đề | Dòng phụ |
|---|---|---|---|
| `MayChuBaoTri` | `construction`, nền `amber-100` | Máy chủ đang bảo trì | Dữ liệu trên máy vẫn dùng được, tự đồng bộ khi xong |
| `MayChuPhongToa` có giờ | `shield`, `#ba1a1a` trên `#ffdad6` | Mạng này đang bị tạm chặn | Tới 15:30 · dữ liệu trên máy vẫn dùng được |
| `MayChuPhongToa` không giờ | như trên | Mạng này đang bị tạm chặn | Dữ liệu trên máy vẫn dùng được |

- Giờ hết hạn khác ngày hôm nay → *"Tới 09:00 21/10"*. Mọi định dạng giờ qua `DateFormatter` (quét 32).
- Không hiện lý do admin gõ (thông báo tối giản).

### 4.2 Toast đồng bộ

- Một lần khi **chuyển sang** trạng thái chặn (không lặp ở mỗi lượt thử lại 60 giây): *"Chưa đồng bộ được: máy chủ đang bảo
  trì"* / *"Chưa đồng bộ được: mạng này đang bị tạm chặn"*. Qua `AppToast` hiện có.

### 4.3 Màn Đăng nhập

- 503 `MAINTENANCE_MODE` → *"Máy chủ đang bảo trì. Thử lại sau ít phút."*
- 403 `AIOPS_QUARANTINED` → *"Mạng này đang bị máy chủ tạm chặn tới 15:30. Thử lại sau hoặc đổi mạng (Wi-Fi ↔ 4G)."*
  (không giờ → bỏ vế *"tới…"*).
- 403 vì trạng thái tài khoản lúc đăng nhập: như cũ. Câu hiện đúng chỗ đang hiện `message` của server.

### 4.4 Không đổi

Trợ lý online đã rơi về mô hình trên máy khi máy chủ hỏng (mục 15 `AI_EDGE_FEATURE.md`).

## 5. Socket bị từ chối bắt tay (Phần C.1)

- `RealtimeChannel.onConnectError`: lỗi mang `data` là `Map` có `code` chuỗi khác rỗng → `tuBody401(data, nguon:
  NguonBuocDangXuat.socket)` (`lib/core/auth/buoc_dang_xuat.dart` — cùng khoá `code` · `idaccount` · `reason_inactive` ở cấp
  gốc như body 401) → phát lên `buocDangXuat` (đường `account.force_logout` đang dùng) và **dừng nối lại** tới lần `start()`
  sau. `idaccount` khác phiên → bỏ qua (khuôn `force_logout`).
- `loiNhan` ra rỗng (câu nằm ở `err.message` dạng *"Authentication error: …"*, không nằm trong `data` — cố ý không đọc tiền tố ấy)
  → `HopThoaiBiDayRa` dùng câu mặc định theo lý do, như 401 không kèm câu.
- Lỗi không `data` → giãn cách nối lại như cũ.
- ⚠️ **Chưa đo** gói `socket_io_client` chuyển lỗi `connect_error` lên Dart bằng hình dạng nào (`Map` có `data`? chuỗi?). Kế
  hoạch có bước đo trên máy / bằng ca test với payload thật trước khi viết bộ đọc; bộ đọc phải chịu cả hai dạng.
- Hệ quả: tài khoản bị khoá lúc máy offline → có mạng là bị đăng xuất kèm lý do, thay vì kênh nối lại mỗi 60 giây mãi.

## 6. Gói (Phần C.2)

1. `account.downgraded` → giá trị mới `RealtimeEvent.taiKhoanHaCap`: im lặng (`loiNhan == null`, `canDongBoLai == false`),
   không đọc payload; `GoiRepository` nghe → `lamMoi()`. Màn Nâng cấp / Chờ thanh toán **không** nghe (đó là luồng
   `taiKhoanNangCap`).
2. 403 `FEATURE_DISABLED` (cấp gốc) từ bất kỳ request → `MayChuInterceptor` gọi hook `khiBiTatQuyen` (DI nối
   `sl<GoiRepository>().lamMoi()`), hai lần gọi cách nhau **≥ 30 giây**. Lý do: `account.downgraded` chỉ phát lúc 0 giờ, còn
   server đã trả 403 từ lúc hết hạn / admin đổi quyền.

## 7. Không xoá SQLite khi `ACCOUNT_DELETED` (Phần C.3)

- `AuthBloc` bỏ nhánh `xoaDuLieu` (`auth_bloc.dart`, khối *"Người dùng chốt 2026-09-13: GIỮ ngoại lệ"*): vẫn đăng xuất, vẫn
  hộp thoại, chữ không đổi. Dữ liệu nằm lại tới khi tài khoản khác đăng nhập trên máy (`purgeDataForOtherAccounts`).
- Gỡ chuỗi chết: `PhienDieuPhoi.xoaDuLieu` + bản thật, tham số `xoaBanSao` của `PhienDieuPhoiThat` + DI; `AppDatabase.
  purgeDataForAccount` nếu ngoài test của chính nó không còn chỗ gọi (đo lúc lập kế hoạch) — kèm docstring năm bảng nhắc tên hàm.
  Bốn tệp test nhắc `xoaDuLieu` / `xoaBanSao` (đo 2026-10-20): `core/auth/phien_dieu_phoi_that_test.dart`,
  `features/auth/auth_bloc_buoc_dang_xuat_test.dart`, `features/auth/auth_bloc_cho_xoa_test.dart`,
  `features/auth/session_validation_test.dart`.
- Chú thích cũ *"Đừng gỡ điều kiện `nguon != lamMoi`"* thay bằng lý do mới (luật một cho ba nguồn, người dùng chốt 2026-10-20).

## 8. Kiểm thử và nghiệm thu (Phần C.4)

Mọi ca canh phải thử bằng một bản sai và thấy đỏ.

- `phanLoaiPhanHoi`: bảng ca — 503 có / không `code` / `code` khác; 403 `AIOPS_QUARANTINED` / `FEATURE_DISABLED` / tài khoản;
  body không phải `Map`; `Retry-After` số / thiếu / rác / âm / **`1` (→ sàn 30 s)**; `quarantineExpiresAt` có / `null` / rác.
- **Sàn thử lại**: phong toả với `hetHanLuc` ở **quá khứ** → `backoffRetryAt == bayGio + 30 s` (bản sai bỏ `max` → hẹn ngay, đỏ);
  `Retry-After: 1` → `thuLaiLuc == bayGio + 30 s`.
- `MayChuInterceptor`: lỗi được phân loại → ghi; 2xx → xoá; lỗi không phân loại → giữ; `FEATURE_DISABLED` → hook, giãn 30 s.
- `SyncEngine`: bảo trì → `consecutiveFailures` không tăng, `backoffRetryAt == thuLaiLuc`; chỉ lượt kéo 503 (không thao tác
  chờ) cũng hẹn; phong toả có / không giờ; không cổng → như cũ.
- `RealtimeChannel`: `connect_error` có `data.code` → một `ThongBaoBuocDangXuat` nguồn socket + không hẹn nối lại; không `data`
  → hẹn như cũ; `idaccount` khác → bỏ qua.
- `RealtimeEvent`: `account.downgraded` → `taiKhoanHaCap`, im lặng; `GoiRepository` gọi `lamMoi`.
- `AuthBloc`: `daXoa` × ba nguồn → không xoá; vẫn đăng xuất + hộp thoại.
- Widget `DongNhacMayChu` ở 360 dp, `AppTheme.lightTheme`: ba biến thể + ẩn; đo **chiều cao thật** (chữ dài không ngắt dòng im
  lặng); khổ hẹp 320 dp không tràn (`takeException`).
- Màn Đăng nhập: hai câu lỗi mới; 403 tài khoản giữ nguyên.
- **Nghiệm thu OnePlus 13R** (bản `--release` hoặc debug; backend dev chạy — cần phép **đích danh** của người dùng cho mọi việc ở
  `src/Backend`): (1) admin bật bảo trì (Admin-web) → dòng nhắc + toast một lần; tắt → ≤ ~1 phút dòng nhắc ẩn, thao tác ghi lúc
  bảo trì lên server; (2) admin phong toả IP LAN của máy → dòng nhắc có giờ; gỡ → ẩn ở lượt kế; (3) khoá tài khoản lúc máy tắt
  mạng → bật mạng → đăng xuất + hộp thoại từ socket; (4) đăng nhập lúc bảo trì → câu mới.

## 9. Tài liệu

- G89 mã xong, nghiệm thu OnePlus đạt 2026-10-20 (mục 12); sửa năm câu cũ: *"503 đăng nhập mất `code`"* · *"`user.notification` sống"* (hàm gửi không chỗ gọi) · *"`RealtimeEvent`
  chỉ dịch 5 tên"* (5 giá trị, 11 tên) · *"loopback miễn ở mọi môi trường"* (tầng kiểm request chỉ miễn khi `development`; mọi
  môi trường là nhờ lớp từ chối thêm IP được bảo vệ) · đường `core/api/auth_interceptor.dart` (thật: `core/api/interceptors/`).
- Ba chú thích client dẫn số dòng backend đã lệch → dẫn **tên hàm**: `buoc_dang_xuat.dart` (`tuSuKienSocket`),
  `realtime_event.dart` (nguồn `account.upgraded` — thiếu hai nguồn), `realtime_channel.dart` (đầu tệp).
- `CLAUDE.md` hàng *xác thực* (chốt *"dọn SQLite chỉ khi `daXoa` và nguồn khác `lamMoi`"*), `KIEN_TRUC_CLIENT_APP.md`
  (`core/network`, `core/api/interceptors`), `NOTIFICATION_FEATURE.md` nếu chạm toast, `PREMIUM_FEATURE.md` (`taiKhoanHaCap`,
  hook `FEATURE_DISABLED`), mục 14 `PROJECT_CONTEXT.md`, README `CAN-LAM/` (đơn 43: phần client xong).
- **Không xin backend gì.** Thiếu giờ kết thúc bảo trì là chấp nhận theo thiết kế; phần dư đơn 43 (A1, A3–A6, D) vẫn mở phía backend.

## 10. Ngoài phạm vi

- Nghe `system.maintenance_changed` / `system.broadcast` / `user.notification` (quyết định 2026-09-30, payload hộp đen).
- Dải trên mọi trang; nút ✕ cho dòng nhắc; hiện lý do admin gõ.
- 503 / 429 / 504 khác (`SERVER_OVERLOADED`, `DB_POOL_OVERLOADED`, `RETRY_LIMIT_EXCEEDED`, `REQUEST_TIMEOUT`) — giữ hành vi hôm nay.
- Đổi chữ hộp thoại tài khoản bị xoá.

## 11. Chỗ bản thi công khác bản viết

Đánh số 1–13 theo thứ tự trong kế hoạch, các mục sau thêm dần khi review (đếm 2026-10-20).

1. **`/auth/refresh` tới interceptor gián tiếp.** Nó đi Dio riêng của `AuthInterceptor`; 503 của nó chỉ tới `MayChuInterceptor` vì
   lỗi được chép sang request gốc (`_loiTamThoiChoRequest`) — nên interceptor phải đứng **sau** `AuthInterceptor`. Lượt phát lại
   thành công sau làm mới token đi `handler.resolve` → không qua `onResponse` → 2xx ấy không xoá dòng nhắc; request kế xoá.
2. **Chỉ ghi từ request mang phiên** (header `Authorization`). Đăng nhập / đăng ký / quên mật khẩu không ghi — tránh toast
   *"Chưa đồng bộ được…"* chồng lên câu lỗi màn Đăng nhập. Mục 3.2 ghi *"phủ … đăng nhập"*.
3. **Lý do kết thúc `pending`**: `error` làm `NotificationScanner` nổ `NotificationKind.syncFailed` (không phải `AppToast`).
   Hệ quả: chu kỳ bị chặn không kích hoạt lượt quét thông báo (vẫn quét lúc mở app / `resumed`); thông báo "Đồng bộ hỏng" không
   nổ lúc bảo trì (hôm nay có).
4. **Chỉ tính lời chặn ghi TRONG chu kỳ** (`identical` với trạng thái lúc vào chu kỳ) — một 503 cũ còn sót không biến lỗi mạng
   thường thành hẹn 30 s. Hai lớp chặn vì thế không có constructor `const`.
5. **Lượt bị chặn không đụng `_nextAllowedSyncAt` / `_consecutiveFailures`** — để đổi mạng thử ngay; mốc bảo trì trượt theo mỗi
   503 mới (vô hại).
6. **Dòng nhắc phong toả khi giờ đã qua** → biến thể không giờ (không hứa một giờ đã trôi). Câu màn Đăng nhập cùng luật.
7. Hàm thêm ngoài spec: `mocThuLaiKhiBiChan` (sàn ở MỘT chỗ), `chuGioHetHan`, `DateFormatter.formatTime` / `formatTimeDayMonth`.
8. **Ca canh "interceptor chỉ gắn vào `DioClient`"** là **test quét 36**; `DioClient` tự dựng interceptor từ tham số
   `trangThaiMayChu` + `khiBiTatQuyen` (DI không dựng nó).
9. **Hình dạng `connect_error`** đã đo bằng mã (người dùng cho phép đọc pub cache 2026-10-20) — xem #18. Nghiệm thu (3) chỉ
   còn xác nhận trên máy.
10. **Lỗi SSE** (trợ lý online, body là luồng) không phân loại được — trợ lý đã tự rơi về mô hình trên máy.
11. `AppDatabase.purgeDataForAccount` gỡ hẳn cùng `purge_data_for_account_test.dart` và năm ca schema (đo lúc lập kế hoạch: ngoài
    DI chỉ test của chính nó gọi).
12. Toast dùng bậc + nguồn **đồng bộ** có sẵn; màu `AppColors.warning` (bảo trì) / `AppColors.expense` (phong toả).
13. Engine nền (`cheDoNen`) cũng gắn interceptor + hook (trạng thái RAM riêng isolate; `lamMoi` ở nền vô hại).
14. **Trần `Retry-After` 1 ngày** (`kTranRetryAfter`, `trang_thai_may_chu.dart`): `Retry-After` dài hơn 86.400 s → 60 s mặc
    định. Lý do: review Task 2 đo `'9000000000000'` làm `DateTime.add` ném `RangeError` ra khỏi interceptor. Thêm cùng commit
    Task 3 (`4782f447`).
15. **Interceptor không bao giờ đổi lỗi của nơi gọi** (`6aad1f12`): phân loại + hook `khiBiTatQuyen` (và thân `onResponse`) bọc
    `try/catch` có log; `retry-after` đọc dạng danh sách lấy phần tử đầu — `Headers.value` của Dio NÉM khi header lặp (đo bằng
    script Dio 5.11). Màn Đăng nhập đọc cùng cách (`98d58c64`).
16. **Bản sai "bỏ `maxLines: 1` → đỏ" của kế hoạch không thể đỏ**: `maxLines: 1` và `overflow: ellipsis` thay được cho nhau
    (ellipsis tự cắt ở dòng tràn đầu khi `maxLines` null). Ca 320 dp canh bằng bản sai bỏ CẢ HAI, ở cỡ chữ 1,0 và 1,5
    (`fe3da95b`). Tiêu đề rộng tự nhiên 331 px trong vùng chữ 206 px (font test).
17. **Ca màn Đăng nhập "giờ phong toả đã qua"** thêm sau review (`98d58c64`) — nhánh `isAfter` trước đó không ca nào phân biệt.
18. **Hình dạng `connect_error`** đo bằng mã gói: `socket.io` 4.8.3 `namespace.js:229-238` gửi `{message, data}`;
    `socket_io_client` 3.1.6 `socket.dart:426-429` chuyển nguyên `packet['data']`. Bộ đọc giữ nhánh phẳng cho giao thức 3.
    (Thay cho điều "chưa đo" ở bản viết.)
19. **Task 5 không có bước RED thật** (mã viết trước test) — bù bằng ba bản sai đỏ; ca "start() lại sau khi bị từ chối" chạy async
    thật thay FakeAsync (cancel của luồng kết nối giả hoàn tất bằng future null dùng chung của SDK, FakeAsync không bơm được).
20. **Phong toả KHÔNG nói giờ giữ đúng hành vi trước G89** (ruling 2026-10-20, spec mục 3.3 *"`hetHanLuc == null` → giãn cách như
    hôm nay"*): lượt hỏng được tính, giãn cách luỹ tiến, chu kỳ kết thúc `error` → bộ quét có thể nổ `syncFailed`. Câu *"lượt bị
    chặn kết thúc `pending`"* (mục 3, #3, #5) chỉ áp cho bảo trì và phong toả CÓ giờ. Ca canh: `sync_may_chu_chan_test`
    *"phong toả KHÔNG giờ"*.
21. **Dòng `Nối hỏng: $e` thô trên máy thật** (OnePlus 13R, 2026-10-20 16:18:06, `socket.io` của backend dev nhánh này) — khớp
    dạng đã đo bằng mã ở #18, `data` lồng trong `{message, data}`:
    `[RealtimeChannel] Nối hỏng: {message: Authentication error: Tài khoản đã bị vô hiệu hóa. Lý do: Nghiệm thu G89 (3b) — đường socket, data: {code: ACCOUNT_INACTIVE, idaccount: 18, reason_inactive: Nghiệm thu G89 (3b) — đường socket}}`
    rồi `[RealtimeChannel] Bắt tay bị từ chối: biKhoa — dừng nối lại`; 47 s sau đó không dòng `Thử nối lại` nào.

Ghi nhận cho người đọc sau: (a) lúc máy chủ chặn, `SyncEngine` không dựng `_nextAllowedSyncAt` → mọi nguồn kích hoạt gửi request
thẳng, sàn 30 s chỉ áp cho hẹn giờ (đánh đổi "đổi mạng thử ngay"); (b) toast bảo trì có thể không hiện cả đợt nếu lúc 503 đầu
đang có toast phản hồi bậc cao (chính sách `_hien` không xếp hàng) — dòng nhắc Trang chủ vẫn nói trạng thái; (c) `idaccount`
trong lời từ chối bắt tay khác phiên → bỏ qua và vẫn nối lại mỗi 60 s (khuôn `force_logout`).

## 12. Nghiệm thu OnePlus 13R — 2026-10-20 15:59–16:20 · ✅ ĐẠT cả bốn kịch bản

Bản **debug** (`--debug`, tài khoản 18 `quangdat`), `baseUrl` sửa **tạm** sang IP LAN `172.31.98.144` (không commit — điện thoại và máy
tính cùng dải `/23`; đi `adb reverse` thì server thấy `127.0.0.1`, địa chỉ không bao giờ bị phong toả). Backend dev nhánh này chạy thật
sau `npm install` (người dùng cho phép đích danh; thiếu gói `resend` từ gộp `e7570e16` là backend sập lúc khởi động); thao tác admin qua
API (`/admin/system/maintenance`, `/admin/aiops/quarantine`, `/admin/updatestatus/18`) — người dùng cho phép đích danh.

| Kịch bản | Đo được | Kết quả |
|---|---|---|
| (1) bảo trì | Bật 16:04:05 → ghi khoản thu 12.000 đ → lượt đẩy 16:06:21 nhận 503 `MAINTENANCE_MODE`: dòng nhắc *"Máy chủ đang bảo trì — Dữ liệu trên máy vẫn dùng được, tự đồng bộ khi xong"* + toast *"Chưa đồng bộ được: máy chủ đang bảo trì"*; lý do admin gõ **không** hiện. `SyncEngine`: *"Máy chủ đang chặn — không tính lượt hỏng, thử lại lúc 16:07:21"* (`Retry-After` 60). Lượt 16:07:21 nhận 503 lần hai — **không** toast thứ hai (đo bằng kích thước khung: 268 KB có toast, 248 KB không, 10 khung quanh lượt ấy đều ~248 KB). Tắt 16:07:56 → lượt hẹn 16:08:22 đẩy được, khoản 12.000 đ có trên server (truy vấn đọc), dòng nhắc ẩn (ảnh 16:08:30) — ~34 s vì `Retry-After` là 60, không phải một trần chung | ✅ |
| (2) phong toả có giờ | `POST /admin/aiops/quarantine` IP `172.31.99.230` 20 phút (⚠️ `temporary-ip` chỉ sửa mục **đã có** — `count: 0`, không chặn gì). Mở lại app 16:09:55: dòng nhắc *"Mạng này đang bị tạm chặn — Tới 16:29 · dữ liệu trên máy vẫn dùng được"* + toast *"Chưa đồng bộ được: mạng này đang bị tạm chặn"*; `SyncEngine` hẹn đúng giờ hết hạn *16:29:42.594*. Gỡ (`unblock-ip`) 16:10:32 → đưa app xuống nền rồi mở lại → dòng nhắc ẩn (ảnh 16:10:36). Request nào xoá nó — **không đo được** (logcat im, backend không ghi access log) | ✅ |
| (3) khoá lúc mất mạng | Tắt Wi-Fi + dữ liệu di động → khoá `quangdat` 16:12:07 → bật Wi-Fi 16:12:22. **HTTP thắng cuộc đua**: lượt đẩy lúc có mạng nhận 401 `ACCOUNT_INACTIVE` (16:12:29.3) → hộp thoại *"Tài khoản đã bị vô hiệu hoá"* kèm lý do; socket bị dừng trước khi bắt tay trả lời; SQLite tài khoản 18 **giữ nguyên** (đọc CSDL chép từ máy: 2 ví, 3 giao dịch, 18 danh mục sống — dòng log *"Wallets count: 0"* là log gỡ lỗi đếm theo phiên đã đóng) | ✅ |
| (3b) đường socket | Ép socket thắng: **phong toả AIOps chặn HTTP nhưng KHÔNG chặn bắt tay socket** (đo 16:10:01 — socket *"Đã nối"* lúc IP đang bị chặn). Tắt Wi-Fi → phong toả IP → khoá tài khoản → bật Wi-Fi 16:18:03: HTTP 403 `AIOPS_QUARANTINED` (không đăng xuất), bắt tay → dòng thô ở mục 11 #21 → *"Bắt tay bị từ chối: biKhoa — dừng nối lại"* → hộp thoại câu mặc định *"Tài khoản của bạn đã bị vô hiệu hoá."* (cố ý không đọc `message` của bắt tay; `data.reason_inactive` có sẵn nếu muốn hiện lý do như đường HTTP); 47 s sau không `Thử nối lại`; SQLite giữ nguyên | ✅ |
| (4) đăng nhập lúc bảo trì | `quangdat` đúng mật khẩu → *"Máy chủ đang bảo trì. Thử lại sau ít phút."*, một thông báo, không toast chồng (khung `m2`–`m4` một toast, `m5`+ không). Ghi nhận: tên đăng nhập **không tồn tại** lúc bảo trì nhận 401 — backend kiểm thông tin đăng nhập trước bảo trì | ✅ |

Bẫy đo của lượt này: OnePlus chụp màn **đen** khi ô mật khẩu đang mở bàn phím bảo mật — Back đóng bàn phím rồi mới chụp; mất mạng thật
phải tắt **cả** Wi-Fi lẫn dữ liệu di động, và bật lại dữ liệu cuối buổi. Lượt đo cũng lộ **G98** (`CLIENT_APP_KNOWN_GAPS.md`): ví test
`test-wallet-1789014227658` kẹt hàng đợi đẩy và đẩy giãn cách đồng bộ của tài khoản 18 lên 15 phút.
