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
| `Modal` | lớp phủ, tiêu đề, thân, chân; đóng bằng Esc và nút đóng; khóa cuộn nền |
| `ConfirmModal` | dựng trên `Modal`, thay mọi hộp xác nhận tự dựng |
| `SecurityConfirmModal` | dựng trên `Modal`, giữ luồng xác thực PIN `verifySecurityAction`; Danh mục dùng lại thay hộp PIN riêng |
| `Spinner`, `EmptyState` | trạng thái tải / rỗng thống nhất |

Khung trang danh sách (Người dùng, Danh mục, Thanh toán, Nhật ký): `PageHeader` → hàng `StatCard` (nếu trang có số liệu) → `Card` chứa thanh lọc (`Tabs` trạng thái + `SearchInput` + nút Bộ lọc / bộ lọc riêng của trang) → `DataTable` → `Pagination`.

## 5. Danh mục chức năng phải giữ (chuẩn nghiệm thu)

Nguồn: lời gọi API, sự kiện socket và hàm xử lý trong mã ngày 2026-11-12.

| Màn hình | API | Socket | Thao tác |
|---|---|---|---|
| Đăng nhập | `authApi` qua `auth.context` | — | đăng nhập, đổi ngôn ngữ, sang Quên mật khẩu |
| Quên mật khẩu | (đối chiếu khi làm) | — | gửi yêu cầu khôi phục, đổi ngôn ngữ |
| Khung (AppLayout, Sidebar, Header) | `getMaintenanceStatus`, `setMaintenanceStatus`, `getStatus`, `getAdminAlerts`, `markAdminAlertAsRead` | `admin.maintenance_changed`, `admin.security_alert`, `admin.security_blocked`, `admin.notification` | 8 mục menu, thu gọn sidebar, đăng xuất, banner bảo trì, giảm thiểu nhanh khi có cảnh báo an ninh, danh sách cảnh báo + đánh dấu đã đọc, trạng thái kết nối realtime, đổi ngôn ngữ, mở Cài đặt |
| Khóa màn hình | — | — | mở khóa, đăng xuất |
| Đăng nhập lần đầu | `firstLoginSetup` | — | thiết lập lần đầu |
| Cài đặt | `changePassword`, `changePin`, `createAdmin` | `connect`, `disconnect` | đổi mật khẩu, đổi PIN, tạo admin (nhiều bước), chế độ Sáng/Tối, mật độ, âm thanh + nghe thử, thời gian thông báo, nhịp tim, tự khóa + khóa ngay, kiểm tra ping, xóa bộ nhớ đệm, khôi phục mặc định |
| Tổng quan | `getLoginStats`, `getRecentActivities`, `getRequestStats`, `getSystemHealth`, `getTotalCategories`, `getTotalUsers`, `getUserToTime` | `admin.maintenance_changed`, `admin.metrics_stream`, `audit_activity`, `connect`, `disconnect` | lọc Hôm nay / 7 ngày / 1 tháng / 1 năm, chọn ngày / tháng / năm, 4 KPI, biểu đồ đăng nhập + request (tooltip), hoạt động gần đây cập nhật realtime |
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

## 8. Tiến độ (cập nhật 2026-11-12)

Mức hiện tại: `npm test` 80/80 ca (7 tệp), `npm run lint` 0 lỗi, `npm run build` qua.

### 8.1 Đã xong

| Bước | Commit | Nội dung | Kiểm trên trình duyệt (CSDL cục bộ) |
|---|---|---|---|
| G0 Nền | `92d29c61` | Gỡ 52 tệp test cũ; token sáng/tối (`styles/theme.css`, `tailwind.config.js`); 16 thành phần `components/ui`; 5 tệp `components/common` tái xuất từ `ui` | — |
| G1 Khung | `43ef61df` | Sidebar, Header (trạng thái realtime, chuông, ngôn ngữ, cài đặt, tên admin), banner bảo trì / báo động, xác nhận bảo trì khẩn cấp qua `ConfirmModal` | Sáng, Tối, thu gọn menu, điện thoại |
| G2.1 Người dùng | `1ce28def` | Trang dựng bằng `ui`; xóa mềm một bước qua PIN; `UserDetailModal` dùng khóa ngôn ngữ; `AlertToast` theo token; gỡ `/users/:id` | Vô hiệu hóa rồi kích hoạt `nckh_h3`: HTTP 200, CSDL đúng |
| G2.2 Danh mục | `f832176a` | Bản nháp + thanh "N thay đổi chưa lưu"; lưu bằng `SecurityConfirmModal`; lỗi trùng tên hiện trong biểu mẫu | Thêm rồi xóa danh mục thử, lưu bằng PIN thật: CSDL đúng, xóa mềm |
| G2.3 Thanh toán | `56befb6a` | Tách `components/OrderDetailModal`, `RefundModal` (hai bước: điền rồi PIN), `SampleOrderModal`, `paymentFormat.js`; `axios-client` xuất `baseURL` | Trạng thái rỗng (CSDL chưa có đơn); không bấm tạo đơn thử vì gọi PayOS thật |
| G2.4 Nhật ký | `4ea70c7f` | Bộ lọc gửi máy chủ, banner "N hoạt động mới", gộp hai cột thời gian; `audit-tags.util.js` bỏ chú thích, thêm `tone` | 10 bản ghi thật, lọc "Thất bại" đúng |
| G2.5 Xóa đơn mẫu | commit kế sau `4ea70c7f` | Backend `deleteSampleOrders` lọc `is_template: true`; nút "Xóa đơn mẫu" + `ConfirmModal`, báo số đơn đã xóa, tải lại bảng và KPI | Chèn tay 2 đơn mẫu (1 đã thanh toán, có giao dịch) + 1 đơn thật: bấm xóa → `DELETE` 200, CSDL còn đúng đơn thật, giao dịch đơn mẫu xóa theo |

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

### 8.3 Quyết định trải nghiệm đã áp (Chủ dự án đã duyệt khuôn trang Người dùng)

- Thẻ số liệu không còn bấm để lọc; lọc qua tab.
- Thao tác trong bảng là nút biểu tượng có `aria-label`; thao tác chính của trang nằm ở `PageHeader`.
- Hộp thoại dùng `Modal` / `ConfirmModal` / `SecurityConfirmModal`; không còn lớp phủ chặn toàn màn hình khi xử lý.
- Trạng thái realtime chỉ hiện ở Header, các trang không lặp lại.

### 8.4 Còn phải làm

| Bước | Tệp chính | Ghi chú |
|---|---|---|
| G3.1 Tổng quan | `pages/dashboard/DashboardPage.jsx` (1.350 dòng) | tách biểu đồ `LineChart`; bỏ `RealtimeStatusBadge` riêng; dùng `tagInfo.tone` thay `bg/text/border` |
| G3.2 Phân quyền | `pages/system/PermissionManagementPage.jsx` + 4 tệp `pages/system/components/Permission*.jsx` | có chữ lộ kỹ thuật ("PostgreSQL", "Socket.IO", "50ms") |
| G3.3 Bảo trì & Thông báo | `pages/system/BroadcastPage.jsx` (1.500 dòng) | tách hai tab |
| G4.1 AIOps | `pages/system/AIOpsPage.jsx` (3.956 dòng) + `components/common/ServerHealthPanel.jsx` | tách theo khối |
| G4.2 Cài đặt | `components/layout/SettingsModal.jsx` (1.498 dòng) | gồm chế độ Tối |
| G4.3 Đăng nhập, Quên mật khẩu, Khóa màn hình, Đăng nhập lần đầu | `pages/auth/*`, `components/layout/LockScreenModal.jsx`, `FirstLoginModal.jsx` | |
| G5 Dọn | `tailwind.config.js`, `index.css` (luật `.dark` cũ, `bento-grid`…), `components/common/*` tái xuất, khóa ngôn ngữ thừa | sau đó cập nhật `Project.md` mục 3.4, `docs/Admin-web/README.md` |

### 8.5 Quyết định của Chủ dự án (2026-11-12)

- Thêm nút "Xóa đơn mẫu" kèm `ConfirmModal` ở trang Thanh toán.
- Duyệt sửa Backend: `deleteSampleOrders` đang lọc `payment_link_id` bắt đầu bằng `sample-link-` (quy ước cũ), trong khi `createSampleOrder` hiện lấy mã liên kết thật từ PayOS và đánh dấu `is_template = true`, nên lệnh xóa không trúng đơn mẫu mới. Sửa thành lọc `is_template: true`, giữ xóa vật lý (đơn mẫu là dữ liệu thử của admin, `findOrdersByAccount` đã lọc `is_template = false` nên không tới Client-app; `payment_transaction` xóa theo nhờ `onDelete: Cascade`).
- Rủi ro đã nêu: Backend không hủy liên kết PayOS khi xóa; đơn mẫu hết hạn sau 10 phút.
- G2.2, G2.3, G2.4 commit riêng từng trang; khối khóa ngôn ngữ của từng trang đi theo commit của trang đó.
