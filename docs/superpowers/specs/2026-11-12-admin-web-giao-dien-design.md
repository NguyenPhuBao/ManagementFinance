# Đặc tả: làm lại giao diện Admin-web

- Ngày: 2026-11-12. Trạng thái: Chủ dự án đã duyệt phương án và mockup.
- Mockup: https://claude.ai/artifact/CMuRNJCzF45LJYtyBjs9k8 (màn hình Quản lý người dùng, Tổng quan hệ thống).
- Kế hoạch thi công: `docs/superpowers/plans/2026-11-12-admin-web-lam-lai-giao-dien.md`.

## 1. Mục tiêu

1. Giao diện đơn giản, tinh gọn, theo mockup đã duyệt.
2. Thao tác và hiển thị đồng nhất trên mọi màn hình.
3. Bỏ chú thích trong mã và chữ dài dòng trên màn hình.
4. **Chức năng giữ đầy đủ** (mục 5 là chuẩn nghiệm thu).

Ngoài phạm vi: Backend, Client-app, đổi nghiệp vụ, đổi API, đổi sự kiện socket.

## 2. Hiện trạng (khảo sát 2026-11-12)

| Vấn đề | Số đo |
|---|---|
| Bộ màu | 2 hệ chồng nhau (~50 token kiểu Material + bảng màu Tailwind), 12 họ màu, 120 mã hex viết cứng |
| Cỡ chữ | >15 cỡ; `text-[10px]`/`text-[11px]` 326 lần |
| Nút chính | 104 tổ hợp class khác nhau, không có `Button` chung |
| Tiêu đề trang | 4 kiểu, lẫn `h1`/`h2` |
| Hộp thoại | 22 hộp thoại tự dựng; `ConfirmModal` chỉ AIOps dùng; Danh mục tự dựng hộp PIN riêng |
| Kích thước trang | AIOps 3.956 dòng, Payment 1.944, Broadcast 1.500, Settings 1.498 |
| Chú thích trong mã | 951 dòng (AIOps 202) |
| Chữ dài trên màn hình | 56 chuỗi >120 ký tự, có chuỗi lộ chi tiết kỹ thuật (PostgreSQL, Socket.IO, 50ms) |
| Chế độ tối | Settings có lựa chọn Sáng/Tối nhưng chỉ 22 chỗ dùng `dark:` |
| Trang thừa | `/users/:id` (`UserDetailPage`): không liên kết nào dẫn tới, inline style; chi tiết người dùng đã có `UserDetailModal` |
| Test | 52 tệp / 383 ca xanh, toàn bộ mock API (không ghi CSDL); Chủ dự án quyết định bỏ vì lỗi thời |
| Lint | 4 lỗi `afterEach is not defined` có sẵn |

## 3. Hệ thiết kế

**Màu** (biến CSS, có giá trị sáng và tối; Tailwind đọc qua tên ngữ nghĩa):

Tên lớp Tailwind tránh trùng token cũ (`surface`, `primary`, `background`…) để trang chưa làm lại vẫn chạy tới G5. Biến CSS ở `src/styles/theme.css` (tiền tố `--ui-`), ánh xạ ở `tailwind.config.js`.

| Lớp | Sáng | Dùng cho |
|---|---|---|
| `canvas` | `#f8fafc` | nền trang |
| `card` | `#ffffff` | thẻ, bảng, hộp thoại, sidebar |
| `muted` | `#f1f5f9` | nền tab, hàng tiêu đề bảng |
| `line` | `#e2e8f0` | viền |
| `ink` / `ink-muted` / `ink-faint` | `#0f172a` / `#475569` / `#64748b` | chữ chính / phụ / chú thích nhỏ (đạt 4.5:1 trên nền trắng) |
| `brand` / `brand-hover` / `brand-soft` / `brand-on` | `#047857` / `#065f46` / `#ecfdf5` / `#ffffff` | nút chính, mục menu đang chọn |
| `success`, `success-soft` | `#047857` trên `#ecfdf5` | hoạt động, thành công |
| `warning`, `warning-soft` | `#b45309` trên `#fffbeb` | chờ xóa, cảnh báo |
| `danger`, `danger-hover`, `danger-soft` | `#b91c1c` trên `#fef2f2` | thất bại, đã xóa, nút nguy hiểm |
| `quiet`, `quiet-soft` | `#334155` trên `#f1f5f9` | vô hiệu hóa |
| `info`, `info-soft` | `#2563eb` trên `#eff6ff` | biểu đồ thứ hai, thông tin |
| `overlay` | `rgba(15,23,42,.5)` | lớp phủ hộp thoại |

Giá trị tối định nghĩa cùng tệp (lớp `.dark` trên `<html>`, `settings.context` đã gắn sẵn). Chữ trên nút màu dùng `brand-on` / `card` để đạt tương phản ở cả hai chế độ.

**Chữ:** Inter; 5 cỡ: 12 (nhãn, chú thích), 14 (thân, bảng), 16 (tiêu đề khối), 20, 24 (tiêu đề trang). Số dùng `tabular-nums`.

**Khoảng cách và bo góc:** bước 4px; thẻ và bảng bo 12px, nút và ô nhập bo 8px; nút cao 40px (nhỏ 36px).

**Biểu tượng:** giữ font Material Symbols Outlined đang có sẵn cục bộ, gọi qua `<Icon name>`; nút chỉ có biểu tượng luôn có `aria-label`.

## 4. Bộ thành phần dùng chung `src/components/ui/`

| Thành phần | Trách nhiệm |
|---|---|
| `Icon` | bọc Material Symbols, `aria-hidden` |
| `Button` | biến thể `primary` / `secondary` / `ghost` / `danger`, cỡ `md` / `sm`, `icon` (bắt buộc `aria-label`), `loading` (khóa nút, hiện Spinner) |
| `PageHeader` | `h1` + mô tả 1 dòng (tùy chọn) + vùng nút bên phải |
| `StatCard` | nhãn, giá trị, dòng phụ (tùy chọn) |
| `Tabs` | `role="tablist"`, `aria-selected`, dạng segmented như mockup |
| `SearchInput` | ô tìm có nhãn ẩn cho trình đọc màn hình |
| `Card` | khối nền `surface`, tiêu đề khối (tùy chọn), vùng hành động |
| `DataTable` | cột khai báo, hàng, trạng thái tải, trạng thái rỗng (`EmptyState`), bọc cuộn ngang |
| `Pagination` | làm lại từ `components/common/Pagination.jsx`, giữ API đang dùng |
| `Badge` | tông `success` / `warning` / `danger` / `neutral` / `info` |
| `Modal` | lớp phủ, tiêu đề, thân, chân; đóng bằng Esc và nút đóng; khóa cuộn nền; `hideClose` ẩn nút đóng, `backdrop="solid"` dùng nền đặc che hẳn trang phía sau (Khóa màn hình, Đăng nhập lần đầu) |
| `PasswordInput` | ô mật khẩu kèm nút ẩn / hiện có `aria-label`, chuyển tiếp mọi thuộc tính của `input` |
| `ConfirmModal` | dựng trên `Modal`, thay mọi hộp xác nhận tự dựng |
| `SecurityConfirmModal` | dựng trên `Modal`, giữ luồng xác thực PIN `verifySecurityAction`; Danh mục dùng lại thay hộp PIN riêng |
| `Spinner`, `EmptyState` | trạng thái tải / rỗng thống nhất |

Khung trang danh sách (Người dùng, Danh mục, Thanh toán, Nhật ký): `PageHeader` → hàng `StatCard` (nếu trang có số liệu) → `Card` chứa thanh lọc (`Tabs` trạng thái + `SearchInput` + nút Bộ lọc / bộ lọc riêng của trang) → `DataTable` → `Pagination`.

## 5. Danh mục chức năng phải giữ (chuẩn nghiệm thu)

Nguồn: lời gọi API, sự kiện socket và hàm xử lý trong mã ngày 2026-11-12.

| Màn hình | API | Socket | Thao tác |
|---|---|---|---|
| Đăng nhập | `authApi` qua `auth.context` | — | đăng nhập, đổi ngôn ngữ, sang Quên mật khẩu |
| Quên mật khẩu | — (trang tĩnh, đối chiếu mã 2026-11-13) | — | xem hướng dẫn liên hệ hỗ trợ, gọi số điện thoại hỗ trợ, về Đăng nhập, đổi ngôn ngữ |
| Khung (AppLayout, Sidebar, Header) | `getMaintenanceStatus`, `setMaintenanceStatus`, `getStatus`, `getAdminAlerts`, `markAdminAlertAsRead` | `admin.maintenance_changed`, `admin.security_alert`, `admin.security_blocked`, `admin.notification` | 8 mục menu, thu gọn sidebar, đăng xuất, banner bảo trì, giảm thiểu nhanh khi có cảnh báo an ninh, danh sách cảnh báo + đánh dấu đã đọc, trạng thái kết nối realtime, đổi ngôn ngữ, mở Cài đặt |
| Khóa màn hình | — | — | mở khóa, đăng xuất |
| Đăng nhập lần đầu | `firstLoginSetup` | — | thiết lập lần đầu |
| Cài đặt | `changePassword`, `changePin`, `createAdmin` | `connect`, `disconnect` | đổi mật khẩu, đổi PIN, tạo admin (nhiều bước), chế độ Sáng/Tối, mật độ, âm thanh + nghe thử, thời gian thông báo, nhịp tim, tự khóa + khóa ngay, kiểm tra ping, xóa bộ nhớ đệm, khôi phục mặc định |
| Tổng quan | `getLoginStats`, `getRecentActivities`, `getRequestStats`, `getSystemHealth`, `getTotalCategories`, `getTotalUsers`, `getUserToTime` | `admin.metrics_stream`, `audit_activity` (`admin.maintenance_changed` do `ServerHealthPanel` nghe; trạng thái kết nối ở Header) | lọc Hôm nay / 7 ngày / 1 tháng / 1 năm, chọn ngày / tháng / năm, 4 KPI, biểu đồ đăng nhập + request (tooltip), hoạt động gần đây cập nhật realtime |
| AIOps | `getStatus`, `getHistory`, `getIncidents`, `clearIncidents`, `getForensics`, `getQuarantineList`, `quarantineActor`, `getVectorConfig`, `toggleVector`, `setScale`, `calibrate`, `temporaryBlockIp`, `permanentBanIp`, `unblockIp`, `temporaryBlockAccount`, `permanentBanAccount`, `unblockAccount`, `getMaintenanceStatus`, `setMaintenanceStatus` | `admin.anomaly_detected`, `admin.maintenance_changed`, `admin.metrics_stream`, `admin.quarantine_updated`, `admin.security_alert`, `admin.security_blocked`, `admin.vector_config_changed` | đặt quy mô + hiệu chuẩn, chỉ số an ninh, biểu đồ xu hướng (khoảng thời gian có sẵn + tùy chọn), danh sách sự cố + xóa, điều tra (forensics), cách ly thủ công, chặn tạm / cấm vĩnh viễn / gỡ chặn IP và tài khoản, bật / tắt vector, kích hoạt giảm thiểu, làm mới tay, bảng sức khỏe máy chủ + giảm tải |
| Người dùng | `getUsers`, `updateUserStatus`, `deleteUser`, `getUserById` (hộp chi tiết) | `admin.user_registered`, `admin.user_status_changed` | 4 thẻ số liệu, 5 tab trạng thái (mặc định ẩn "Đã xóa"), tìm kiếm, bộ lọc (gói, trạng thái), phân trang, xem chi tiết (hộp thoại), vô hiệu hóa (bắt buộc lý do), kích hoạt lại (xác nhận), xóa mềm (xác thực PIN, chỉ với tài khoản đã vô hiệu hóa), che số điện thoại, cập nhật realtime |
| Phân quyền | `getPermissions`, `updatePermissions`, `resetPermissionsDefault` | `account.permissions_updated` | bảng ma trận theo nhóm, lọc, bật / tắt, giới hạn + không giới hạn, chính sách hạ cấp, ngăn phạm vi (drawer), hoàn tác từng hàng, lưu có xác nhận, đặt lại mặc định |
| Thanh toán | `getOrders`, `getStats`, `getOrderDetail`, `getPackageTypes`, `processRefund`, `confirmUpgrade`, `createSampleOrder`, `deleteSampleOrders` | `payment.order_created`, `payment.order_expired`, `payment.overpaid_confirmation`, `payment.refunded`, `payment.success`, `payment.underpaid_warning` | 4 KPI, lọc (tìm, trạng thái, gói, khoảng ngày) + đặt lại, xem chi tiết, sao chép mã nhận diện, hoàn tiền (khởi tạo + thực hiện), xác nhận nâng cấp, xuất CSV, tạo đơn thử chờ thanh toán, xóa đơn mẫu (có xác nhận, xem 8.5), cập nhật realtime |
| Danh mục | `getCategories`, `createCategory`, `updateCategory`, `deleteCategory`, `restoreCategory`, `verifySecurityAction` | — | thẻ số liệu, tab, tìm + lọc, thêm / sửa (kế thừa từ khóa từ danh mục đã xóa mềm cùng tên), xóa mềm, khôi phục, đặt lại mặc định, chỉnh trong bản nháp rồi lưu một lần bằng PIN |
| Nhật ký | `getAuditLogs` | `audit_activity`, `connect`, `disconnect` | tìm, lọc trạng thái, khoảng ngày, đặt lại, thông báo có bản ghi mới realtime, phân trang, xuất CSV |
| Bảo trì & Thông báo | `getMaintenanceStatus`, `setMaintenanceStatus`, `cancelScheduledMaintenance`, `getMaintenanceHistory`, `broadcastToAll`, `getBroadcastHistory` | `admin.maintenance_changed` | 2 tab; bật / tắt bảo trì khẩn cấp có xác nhận, lập lịch (nhiều lịch), hủy lịch, cảnh báo lịch sắp tới (≤ 1 giờ), lịch sử bảo trì; gửi thông báo toàn hệ thống, lịch sử thông báo |

Bỏ: trang `/users/:id` (route, tệp, khóa ngôn ngữ `users.detail.*` chỉ trang này dùng; `UserDetailModal` giữ nguyên chức năng).

## 6. Quy tắc nội dung

**Chú thích trong mã:** xóa hết; chỉ giữ chỉ thị công cụ (`eslint-disable…`, `@vite-ignore`…).

**Chữ trên màn hình** (sửa đồng thời `locales/vi.js` và `locales/en.js`):
- Tiêu đề trang ≤ 5 từ; mô tả dưới tiêu đề tối đa 1 câu, ≤ 80 ký tự.
- Không tên công nghệ, giao thức, bảng, thời gian xử lý (PostgreSQL, Socket.IO, Redis, cache, ms, Client-app…), không viết hoa từng chữ.
- Hộp xác nhận: 1 câu nêu hậu quả chính; thao tác nguy hiểm vẫn phải nói rõ hậu quả không đảo ngược được.
- Không emoji trong chữ.

## 7. Kiểm thử

Bộ test cũ (`src/Admin-web/src/tests/*.test.jsx`, 52 tệp) bị gỡ theo quyết định của Chủ dự án; `setup.js` giữ lại. Bộ test mới viết theo từng màn hình khi làm lại, hai tầng theo `.claude/rules/kiem-thu-2-tang.md`:
- Tầng 1: mọi control của màn hình hiện đủ, thao tác không lỗi, trạng thái tải / rỗng / khóa nút đúng.
- Tầng 2: API được gọi đúng tên và tham số; sự kiện socket làm đổi dữ liệu hiển thị.
- Test mock API, không gọi Backend thật, không ghi CSDL.
- Mỗi màn hình một tệp `src/tests/<man-hinh>.test.jsx`; thành phần ui một tệp `src/tests/ui.test.jsx`.

## 8. Tiến độ (cập nhật 2026-11-13)

Mức hiện tại: `npm test` 141/141 ca (12 tệp), `npm run lint` 0 lỗi, `npm run build` qua.

### 8.1 Đã xong

| Bước | Commit | Nội dung | Kiểm trên trình duyệt (CSDL cục bộ) |
|---|---|---|---|
| G0 Nền | `92d29c61` | Gỡ 52 tệp test cũ; token sáng/tối (`styles/theme.css`, `tailwind.config.js`); 16 thành phần `components/ui`; 5 tệp `components/common` tái xuất từ `ui` | — |
| G1 Khung | `43ef61df` | Sidebar, Header (trạng thái realtime, chuông, ngôn ngữ, cài đặt, tên admin), banner bảo trì / báo động, xác nhận bảo trì khẩn cấp qua `ConfirmModal` | Sáng, Tối, thu gọn menu, điện thoại |
| G2.1 Người dùng | `1ce28def` | Trang dựng bằng `ui`; xóa mềm một bước qua PIN; `UserDetailModal` dùng khóa ngôn ngữ; `AlertToast` theo token; gỡ `/users/:id` | Vô hiệu hóa rồi kích hoạt `nckh_h3`: HTTP 200, CSDL đúng |
| G2.2 Danh mục | `f832176a` | Bản nháp + thanh "N thay đổi chưa lưu"; lưu bằng `SecurityConfirmModal`; lỗi trùng tên hiện trong biểu mẫu | Thêm rồi xóa danh mục thử, lưu bằng PIN thật: CSDL đúng, xóa mềm |
| G2.3 Thanh toán | `56befb6a` | Tách `components/OrderDetailModal`, `RefundModal` (hai bước: điền rồi PIN), `SampleOrderModal`, `paymentFormat.js`; `axios-client` xuất `baseURL` | Trạng thái rỗng (CSDL chưa có đơn); không bấm tạo đơn thử vì gọi PayOS thật |
| G2.4 Nhật ký | `4ea70c7f` | Bộ lọc gửi máy chủ, banner "N hoạt động mới", gộp hai cột thời gian; `audit-tags.util.js` bỏ chú thích, thêm `tone` | 10 bản ghi thật, lọc "Thất bại" đúng |
| G2.5 Xóa đơn mẫu | `2ee34db5` | Backend `deleteSampleOrders` lọc `is_template: true`; nút "Xóa đơn mẫu" + `ConfirmModal`, báo số đơn đã xóa, tải lại bảng và KPI | Chèn tay 2 đơn mẫu (1 đã thanh toán, có giao dịch) + 1 đơn thật: bấm xóa → `DELETE` 200, CSDL còn đúng đơn thật, giao dịch đơn mẫu xóa theo |
| G3.1 Tổng quan | `abd7b496` | Tách `components/LineChart` (đo bề rộng thật, màu theo token), `PeriodPicker`, `dashboardFormat.js`; `RequestCell` và `AUDIT_STATUS_TONE` chuyển ra dùng chung với Nhật ký; bỏ lớp phủ chặn màn hình, `RealtimeStatusBadge` riêng và hai nghe sự kiện không còn tác dụng (`admin.maintenance_changed` chỉ ghi vào state không hiển thị, `connect`/`disconnect`); bố cục: biểu đồ xếp dọc cạnh sức khỏe máy chủ, bảng hoạt động rộng hết trang có liên kết sang Nhật ký | Hôm nay → 7 ngày → ngày 10/11: API 200 đúng tham số; tooltip, Sáng / Tối, điện thoại không cuộn ngang |
| G3.2 Phân quyền | `d5a959ef` | Trang + 3 thành phần dựng lại bằng `ui`, thêm `components/permissionFormat.js`; một cách vẽ dòng cho cả chế độ một gói và hai gói (bỏ 3 đoạn mã trùng); hộp phạm vi dùng `Modal`, lưu / đặt lại dùng `ConfirmModal`; bỏ chữ "Trụ 1–4", PostgreSQL, Socket.IO, 50ms; nhãn truy cập tiếng Việt cho mọi ô điều khiển; gỡ `PermissionGroupSection.jsx` (không nơi nào dùng). `Modal` / `ConfirmModal` thêm `testId`, `SearchInput` chuyển tiếp thuộc tính để giữ `data-testid` cũ | Đổi hạn mức 6 → 7 rồi trả 6 trên CSDL cục bộ: `PUT` 200, tải lại đúng; hộp phạm vi, Sáng / Tối, điện thoại không cuộn ngang |
| G3.3 Bảo trì & Thông báo | `b4118641` | Tách `pages/system/broadcast/`: `MaintenanceTab`, `MaintenanceHistory`, `BroadcastTab`, `maintenanceFormat.js`; trang chính giữ trạng thái, banner, socket và hàm `act` dùng chung; hủy lịch qua `ConfirmModal` thay `window.confirm`; bảo trì khẩn cấp qua `SecurityConfirmModal` (sửa prop sai `actionDescription` → `description`); lỗi nhập lịch hiện ngay trong biểu mẫu; thời lượng của lịch đã đặt tính đúng (trước luôn ghi "Chưa diễn ra"); lý do mặc định gửi người dùng bỏ chữ kỹ thuật; `DataTable` thêm `label` | Lên lịch rồi hủy, bật khẩn cấp rồi kết thúc trên CSDL cục bộ: 4 lời gọi 200; Sáng / Tối, điện thoại không cuộn ngang; không bấm gửi thông báo thật |
| G4.2 Cài đặt | `a0c15b0d` | `SettingsModal` dựng trên `Modal` + `Tabs` (5 tab: Giao diện, Thông báo, Kết nối, Bảo mật, Quản trị viên), tách `components/layout/settings/`: `SettingsSections`, `AccountModals` (đổi PIN, đổi mật khẩu), `CreateAdminModal` (3 bước), `settingsUi`; bỏ khung đổi PIN thứ hai nằm sẵn trong tab Bảo mật (nay mở cùng hộp đổi PIN); xóa bộ nhớ đệm và khôi phục mặc định qua `ConfirmModal` thay `window.confirm`; hộp con chỉ dựng khi mở; bỏ chữ kỹ thuật ("Socket.IO", "Cổng 3000" viết cứng, "PostgreSQL Supabase (Tokyo, AWS)", "Bcrypt", số phiên bản giả); `Tabs` thêm `testId` theo mục. 1.498 → 791 dòng | Đổi PIN 246810 → 135790 rồi trả 246810 trên CSDL cục bộ: 2 lời gọi 200; đo độ trễ; Esc ở hộp con chỉ đóng hộp con; Tối gắn `.dark`; điện thoại không cuộn ngang; không cấp admin thật |
| G4.3 Đăng nhập, Quên mật khẩu, Khóa màn hình, Đăng nhập lần đầu | (chưa commit) | Hai trang auth dùng chung khung `pages/auth/AuthShell` (logo, `LanguageToggle`, thẻ giữa màn hình); bỏ nửa trang minh họa tải ảnh ngoài và chữ "mã hóa 256-bit", "realtime"; Khóa màn hình và Đăng nhập lần đầu dựng trên `Modal` (`hideClose`, `closeDisabled`, `backdrop="solid"`); đăng xuất từ màn hình khóa qua `ConfirmModal` thay `window.confirm`; Đăng nhập lần đầu giữ chặn Esc, 7 lỗi kiểm tra, 6 `data-testid`, bỏ lộ mật khẩu / PIN mặc định trên màn hình; `ui` thêm `PasswordInput`, `Modal` thêm `hideClose`, `backdrop`. Bốn tệp 746 → 441 dòng (kể cả `AuthShell`) | Đăng nhập sai rồi đúng (401, 200); Khóa ngay: token bị xóa, Esc không đóng, mở khóa trống / sai / đúng, hộp xác nhận đăng xuất bấm Hủy; Quên mật khẩu VI / EN, liên kết `tel:`; Đăng nhập lần đầu giả lập cờ bằng chặn phản hồi `/auth/me` trong trình duyệt (CSDL không đổi, chặn mọi lời gọi `first-login-setup`), báo lỗi không khớp; Sáng / Tối; điện thoại không cuộn ngang |

### 8.2 Lỗi sẵn có đã sửa

1. `vi.js` / `en.js` khai báo khóa `appLayout` hai lần, khối sau đè khối trước (banner báo động luôn hiện chữ tiếng Việt viết cứng).
2. Menu điện thoại tự mở che kín trang khi tải (dùng chung trạng thái thu gọn của máy tính).
3. Chữ ligature của biểu tượng lọt vào tên truy cập của nút và nhãn ô nhập.
4. Xóa người dùng truyền nhầm prop `actionDescription`, nhật ký kiểm toán ghi đối tượng "N/A".
5. Ảnh minh chứng hoàn tiền trỏ cứng `http://localhost:5000`.
6. Nhãn gói trong hộp đơn thử luôn là "1 tháng".
7. Danh mục trùng tên hiện cả thông báo nổi lẫn `window.alert`.
8. Mũi tên ô chọn đè chữ (đã thêm `pr-9` / `pr-8`).
9. Backend `deleteSampleOrders` lọc tiền tố `sample-link-` cũ nên không xóa được đơn mẫu tạo qua PayOS thật.
10. Cột Số tiền ở trang Thanh toán in thừa số "0" khi `amount_received = 0`.
11. Thẻ "Thời gian hoạt động" ở Tổng quan ghi "Đã trừ 0 phút bảo trì" khi thời gian bảo trì dưới 30 giây (sửa trong G4.2, có test).
12. Hộp đổi PIN / đổi mật khẩu mở lại còn giữ mật khẩu và PIN lần trước trong chốc lát (lỗi sinh ra lúc làm G4.2, phát hiện khi chạy thật, đã sửa và có test hồi quy).
13. Khối khóa ngôn ngữ `firstLogin` không có trong `vi.js` / `en.js`: hộp Đăng nhập lần đầu luôn hiện chữ dự phòng tiếng Việt viết cứng, kể cả khi chọn EN (G4.3 thêm khối ở cả hai tệp).
14. Lớp phủ 50% của `Modal` để lộ số liệu trang phía sau Khóa màn hình (lỗi sinh ra lúc làm G4.3, phát hiện khi chạy thật; thêm `backdrop="solid"`, có test).

### 8.3 Quyết định trải nghiệm đã áp (Chủ dự án đã duyệt khuôn trang Người dùng)

- Thẻ số liệu không còn bấm để lọc; lọc qua tab.
- Thao tác trong bảng là nút biểu tượng có `aria-label`; thao tác chính của trang nằm ở `PageHeader`.
- Hộp thoại dùng `Modal` / `ConfirmModal` / `SecurityConfirmModal`; không còn lớp phủ chặn toàn màn hình khi xử lý.
- Trạng thái realtime chỉ hiện ở Header, các trang không lặp lại.

### 8.4 Còn phải làm

| Bước | Tệp chính | Ghi chú |
|---|---|---|
| G4.1 AIOps | `pages/system/AIOpsPage.jsx` (3.956 dòng) + `components/common/ServerHealthPanel.jsx` (606) | làm kế tiếp (chờ lệnh Chủ dự án); tách theo khối, chia 2–3 commit; bảng sức khỏe máy chủ hiện còn lệch màu ở chế độ Tối (cả trang Tổng quan) |
| G5 Dọn | `tailwind.config.js`, `index.css` (luật `.dark` cũ, `bento-grid`…), `components/common/*` tái xuất, khóa ngôn ngữ thừa | sau đó cập nhật `Project.md` mục 3.4, `docs/Admin-web/README.md`; chuyển `Field`, `FormError`, `inputClass` từ `components/layout/settings/settingsUi` sang `components/ui` (trang auth đang mượn) |

### 8.5 Quyết định của Chủ dự án (2026-11-12)

- Thêm nút "Xóa đơn mẫu" kèm `ConfirmModal` ở trang Thanh toán.
- Duyệt sửa Backend: `deleteSampleOrders` đang lọc `payment_link_id` bắt đầu bằng `sample-link-` (quy ước cũ), trong khi `createSampleOrder` hiện lấy mã liên kết thật từ PayOS và đánh dấu `is_template = true`, nên lệnh xóa không trúng đơn mẫu mới. Sửa thành lọc `is_template: true`, giữ xóa vật lý (đơn mẫu là dữ liệu thử của admin, `findOrdersByAccount` đã lọc `is_template = false` nên không tới Client-app; `payment_transaction` xóa theo nhờ `onDelete: Cascade`).
- Rủi ro đã nêu: Backend không hủy liên kết PayOS khi xóa; đơn mẫu hết hạn sau 10 phút.
- G2.2, G2.3, G2.4 commit riêng từng trang; khối khóa ngôn ngữ của từng trang đi theo commit của trang đó.
- 2026-11-13: thứ tự G4 đổi thành G4.2 → G4.3 → G4.1 (AIOps làm sau cùng). Kế hoạch không có G6.
