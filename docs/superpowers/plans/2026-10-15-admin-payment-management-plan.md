# Kế Hoạch Triển Khai: Phân Hệ Quản Lý Lịch Sử Thanh Toán Cho Admin (Backend & Admin-Web)

> **Mục tiêu:** Xây dựng tính năng theo dõi, tra cứu và thống kê toàn bộ lịch sử thanh toán / đơn hàng gói cước (`payment_order`, `payment_transaction`) của người dùng dành cho Quản trị viên trên Backend và Admin-web.

---

## 1. Hiện Trạng CSDL & Phạm Vi Dữ Liệu
- **Tận dụng 100% CSDL có sẵn:** Hai bảng `payment_order` và `payment_transaction` đã tồn tại trên PostgreSQL Supabase cùng các index hiệu năng cao (`idx_payment_order_account`, `idx_payment_order_status`, `idx_payment_order_code`).
- **DB Guard:** Không chạy migration hay thay đổi schema DDL.

---

## 2. Thiết Kế Chi Tiết API Backend (`src/Backend`)

### 2.1. Tầng Repository (`modules/payment/payment.repository.js`)
1. **`findOrdersForAdmin(filterOptions)`**:
   - Tham số: `{ page = 1, limit = 20, search, status, packageType, fromDate, toDate }`
   - Điều kiện lọc:
     - `search`: Tìm tương đối trên `order_code` (nếu là số), hoặc `username` / `email` của tài khoản qua quan hệ `account`.
     - `status`: Lọc theo trạng thái đơn (`PENDING`, `PAID`, `CANCELLED`, `EXPIRED`).
     - `packageType`: Lọc theo gói cước (`PREMIUM_1_MONTH`, `PREMIUM_6_MONTHS`, `PREMIUM_1_YEAR`).
     - `fromDate` & `toDate`: Lọc theo trường `created_at`.
   - Quan hệ join: `account` (`idaccount`, `username`, `email`, `type`, `User: { select: { firstname: true, lastname: true } }`).
   - Sắp xếp: `created_at` giảm dần (`desc`).
   - Phân trang: `skip`, `take`, trả về `{ items, total, page, limit, totalPages }`.
2. **`getPaymentSummaryStats({ fromDate, toDate })`**:
   - Doanh thu thực nhận: `sum(amount)` các đơn có `status = 'PAID'`.
   - Tổng số đơn hàng: `count(*)` tất cả đơn.
   - Số đơn thành công: `count(*)` đơn có `status = 'PAID'`.
   - Tỷ lệ thành công: `(successCount / totalCount) * 100`.
3. **`getOrderDetailForAdmin(orderId)`**:
   - Lấy thông tin đơn hàng `payment_order`.
   - Lấy danh sách giao dịch đối soát từ `payment_transaction` (`id`, `payos_transaction_id`, `amount`, `bank_code`, `transaction_time`, `signature_verified`).

### 2.2. Tầng Controller & Routing
- Thêm các phương thức tương ứng vào `payment.controller.js` (hoặc `admin.controller.js`).
- Đăng ký routes tại `src/Backend/api/admin.routes.js`:
  - `GET /api/admin/payments/orders` -> `paymentController.getOrdersForAdmin`
  - `GET /api/admin/payments/stats` -> `paymentController.getPaymentStatsForAdmin`
  - `GET /api/admin/payments/orders/:id` -> `paymentController.getOrderDetailForAdmin`
- Middleware bảo vệ: `authenticate`, `authorize('admin')`.

---

## 3. Thiết Kế Giao Diện Admin-Web (`src/Admin-web`)

### 3.1. Routing, Navigation & API Client
- **API Client:** Tạo `src/Admin-web/src/api/payment.api.js`:
  - `getOrders(params)`: Gọi `GET /admin/payments/orders`
  - `getStats(params)`: Gọi `GET /admin/payments/stats`
  - `getOrderDetail(id)`: Gọi `GET /admin/payments/orders/${id}`
- **Navigation:** Thêm mục menu trong `src/Admin-web/src/components/layout/Sidebar.jsx`:
  - `{ key: '/payments', icon: 'receipt_long', label: t('nav.payments') }`
- **Router:** Khai báo route `/payments` trong `src/Admin-web/src/router/routes.jsx` trỏ tới `PaymentHistoryPage`.
- **Đa ngôn ngữ (i18n):** Khai báo namespace `payments` trong `src/Admin-web/src/locales/vi.js` và `en.js`.

### 3.2. Cấu Trúc Trang `PaymentHistoryPage.jsx`
*Vị trí file:* `src/Admin-web/src/pages/payments/PaymentHistoryPage.jsx`

1. **Header & Thao Tác:**
   - Tiêu đề: *Quản lý Lịch sử Thanh toán*
   - Nút "Làm mới": Reload toàn bộ danh sách & thẻ thống kê.
2. **4 Thẻ KPI Tóm Tắt (KPI Cards):**
   - *Doanh thu thực nhận:* Tổng tiền từ các đơn đã thanh toán (VNĐ).
   - *Tổng đơn hàng:* Tổng số đơn đã tạo trên hệ thống.
   - *Đơn thành công:* Số đơn trạng thái `PAID`.
   - *Tỷ lệ thành công:* Tỷ lệ hoàn tất thanh toán (%).
3. **Thanh Bộ Lọc (Filter Bar):**
   - Ô nhập tìm kiếm (Mã đơn hàng, username, email).
   - Dropdown trạng thái: Tất cả, Đã thanh toán (`PAID`), Đang chờ (`PENDING`), Đã hủy (`CANCELLED`), Hết hạn (`EXPIRED`).
   - Dropdown gói cước: Tất cả, Gói 1 tháng, Gói 6 tháng, Gói 1 năm.
   - Khoảng ngày tạo: Từ ngày - Đến ngày.
4. **Bảng Danh Sách Giao Dịch (Orders Table):**
   - Cột: Mã đơn hàng (`order_code`), Khách hàng (`username` + họ tên), Gói dịch vụ (`package_type`), Số tiền (`amount`), Trạng thái (Badge màu: Xanh lá = PAID, Vàng = PENDING, Xám/Đỏ = CANCELLED/EXPIRED), Thời gian tạo, Thời gian thanh toán.
   - Nút thao tác: "Xem chi tiết" (Icon `visibility`).
5. **Modal Chi Tiết Giao Dịch (Payment Detail Modal):**
   - Thông tin PayOS: `payment_link_id`, URL trang checkout.
   - Thông tin đối soát webhook: Ngân hàng giao dịch (`bank_code`), Mã giao dịch ngân hàng (`payos_transaction_id`), Thời gian nhận webhook, Trạng thái xác thực chữ ký.
6. **Phân Trang:** Tích hợp component `Pagination.jsx`.

---

## 4. Kế Hoạch Kiểm Thử 2 Tầng (2-Tier Testing)

### 4.1. Backend Tests
- **Tầng 1 (API Interaction & Contract):**
  - Kiểm tra status code (200, 401 khi không đăng nhập, 403 khi không phải admin).
  - Cấu trúc response JSON chuẩn `{ success: true, data: { items, total, page } }`.
- **Tầng 2 (System Impact & DB Query):**
  - Query chính xác dữ liệu từ CSDL thật: tính đúng tổng doanh thu, lọc đúng đơn hàng theo `status`, `search` và khoảng thời gian `fromDate`/`toDate`.

### 4.2. Admin-Web Tests (`PaymentHistoryPage.test.jsx`)
- **Tầng 1 (UI Rendering & Interaction):**
  - Render đầy đủ 4 thẻ KPI, bảng dữ liệu, dropdown bộ lọc, ô tìm kiếm, các badge trạng thái.
  - Thao tác click xem chi tiết mở đúng Modal hiển thị thông tin đối soát.
- **Tầng 2 (System Impact & API Verification):**
  - Thao tác lọc trạng thái hoặc nhập ô tìm kiếm kích hoạt gọi API đúng tham số (`status`, `search`).
  - Thao tác đổi trang phân trang kích hoạt tải dữ liệu trang kế tiếp.
  - Hiển thị Toast thông báo lỗi khi API phản hồi thất bại.

---

## 5. Danh Sách Tác Vụ Triển Khai (Checklist)

- [x] **Tác vụ 1 (Backend):** Bổ sung các hàm truy vấn `findOrdersForAdmin`, `getPaymentSummaryStats`, `getOrderDetailForAdmin` trong `payment.repository.js`.
- [x] **Tác vụ 2 (Backend):** Bổ sung controller và đăng ký các routes trong `admin.routes.js`.
- [x] **Tác vụ 3 (Backend Test):** Viết unit/integration test cho các endpoints admin payment (7/7 tests PASS).
- [x] **Tác vụ 4 (Admin-Web Service & Config):** Tạo `payment.api.js`, cấu hình route `/payments` trong `routes.jsx`, thêm mục menu trong `Sidebar.jsx`, cập nhật từ điển i18n (`vi.js`, `en.js`).
- [x] **Tác vụ 5 (Admin-Web UI):** Xây dựng component `PaymentHistoryPage.jsx` hoàn chỉnh (KPI cards, filter bar, data table, detail modal, pagination).
- [x] **Tác vụ 6 (Admin-Web Test):** Viết bài test 2 tầng cho `PaymentHistoryPage.test.jsx` (Vitest: 11/11 tests PASS, Full suite 194/194 tests PASS).
- [x] **Tác vụ 7 (Live PayOS Payment Channel Integration):** Tích hợp endpoint `GET /api/admin/payments/payos-qr` kết nối trực tiếp kênh thanh toán PayOS MB Bank (`2512070399999` - `NGUYEN PHU BAO`), hỗ trợ sinh link thanh toán PayOS thật (`checkoutUrl`), mã QR Napas 247 thật và chọn linh hoạt mức tiền thử nghiệm (2.000 ₫, 49.000 ₫, 270.000 ₫) phục vụ kiểm thử luồng chuyển khoản thực và đối soát Webhook tự động.
- [x] **Tác vụ 8 (Verification & CodeGraph):** Chạy toàn bộ test suite (Backend: 11/11 tests PASS; Admin-web: 11/11 tests PASS, build PASS), cập nhật `Project.md`, chạy `rtk npx codegraph build`.
