# KẾ HOẠCH TRIỂN KHAI TINH CHỈNH TRANG LỊCH SỬ THANH TOÁN (PAYMENT HISTORY REFINEMENT PLAN)

> **Mục tiêu:** Khảo sát chi tiết, giải quyết triệt để 3 vấn đề PO phản hồi trên trang Quản lý Lịch sử thanh toán (`/payments`): Bỏ nút "Làm mới" dư thừa ở Header, đồng bộ gói cước hiển thị theo chuẩn CSDL (2 gói: Basic & Premium), và lưu vết sự kiện hết hạn gói hạ cấp về Basic vào CSDL PostgreSQL (`payment_order`).
> **Tiêu chuẩn tuân thủ:** 3 Quy tắc Tối cao (PO First, Dual-Axis, Ask PO), DB Guard (Rule 10), Kiểm thử 2 Tầng (Rule 11).

---

## 1. KHẢO SÁT & XÁC NHẬN VẤN ĐỀ TỪ PO (SURVEY & CONFIRMATION)

### 1.1. Issue 1: Bỏ nút "Làm mới" tại Header
- **Vị trí hiện tại:** `src/Admin-web/src/pages/payments/PaymentHistoryPage.jsx` (dòng 574 - 584).
- **Hiện trạng:** Nút "Làm mới" đứng cạnh nút "Mã QR mẫu thử nghiệm" và "Xuất CSV". Trang đã được trang bị Socket.IO realtime nhận diện biến động thanh toán PayOS và chuyển trạng thái tức thời, đồng thời bộ lọc đã có nút "Đặt lại", khiến nút "Làm mới" trở nên dư thừa và gây rối mắt.
- **Giải pháp:** Lược bỏ hoàn toàn nút `<button onClick={handleRefresh}>` tại Header.

### 1.2. Issue 2: Bộ lọc gói cước hiển thị theo chuẩn CSDL (2 gói: Basic & Premium)
- **Hiện trạng CSDL:**
  - Bảng cấu hình quyền `account_type_permission`: Đã định danh chuẩn 2 gói `Basic` và `Premium`.
  - Bảng tài khoản `account`: Cột `type` chỉ gồm `Basic` và `Premium`.
  - Bảng đơn hàng `payment_order`: 19 bản ghi lịch sử hiện đang mang chuỗi giá trị cũ `PREMIUM_1_MONTH` và `PREMIUM_6_MONTHS`.
- **Hiện trạng giao diện:**
  - Header/Modal đang gán cứng nhãn `PREMIUM_1_MONTH` -> "Gói 1 Tháng".
  - Bộ lọc dropdown và bảng hiển thị "Gói 1 Tháng" thay vì tên gói cước thống nhất.
- **Giải pháp:**
  - Cập nhật 19 bản ghi cũ trong `payment_order` từ `PREMIUM_1_MONTH` / `PREMIUM_6_MONTHS` thành `'Premium'`.
  - Chuẩn hóa Backend `createOrder`, `getOrCreatePayosQr`: Mặc định lưu `package_type = 'Premium'`. Nếu Client Mobile (Flutter) gửi `PREMIUM_1_MONTH`, Backend tự động chuẩn hóa về `'Premium'`.
  - Đồng bộ `PaymentHistoryPage.jsx`:
    - Dropdown gói cước hiển thị từ API CSDL: `Tất cả các gói cước`, `Gói Basic (Mặc định)` và `Gói Premium`.
    - Bảng hiển thị cột Gói dịch vụ:
      + `Basic`: Badge màu trung tính/slate kèm icon `inventory_2` và nhãn `Gói Basic`.
      + `Premium`: Badge màu xanh/tím thương hiệu kèm icon `workspace_premium` và nhãn `Gói Premium`.
    - Modal thử nghiệm (Sandbox QR): Đồng bộ tạo đơn hàng gói `Premium`.

### 1.3. Issue 3: Ghi nhận lịch sử hết gói chuyển về gói cơ bản (Lưu vào CSDL)
- **Hiện trạng:**
  - Khi gói Premium của tài khoản hết hạn, hàm `downgradeExpiredPremiumAccounts` (`src/Backend/modules/payment/payment.repository.js`) và `scheduler.service.js` chỉ âm thầm thực thi:
    `prisma.account.updateMany({ where: { idaccount: { in: ids } }, data: { type: 'Basic', premium_expires_at: null } })`.
  - **Hệ thống hoàn toàn chưa ghi nhận bất kỳ dòng lịch sử nào vào CSDL!** Do đó, quản trị viên khi xem danh sách "Lịch sử thanh toán" chỉ thấy các lần nạp tiền, mà không thể theo dõi thời điểm tài khoản hết hạn và chuyển về Basic.
- **Giải pháp:**
  - Trong `downgradeExpiredPremiumAccounts`:
    Khi phát hiện các tài khoản `type === 'Premium'` có `premium_expires_at <= now`, bên cạnh việc cập nhật `account.type = 'Basic'`, hệ thống sẽ **INSERT ngay vào bảng `payment_order`** một bản ghi sự kiện hết hạn:
    + `id`: UUID định danh duy nhất.
    + `idaccount`: ID tài khoản hết hạn.
    + `order_code`: Mã giao dịch duy nhất sinh tự động (BigInt timestamp-based).
    + `package_type`: `'Basic'` (Chuyển về gói Basic).
    + `amount`: `0` (Sự kiện chuyển đổi dòng đời, không phát sinh chi phí).
    + `amount_received`: `0`.
    + `fee`: `0`.
    + `currency`: `'VND'`.
    + `status`: `'EXPIRED'` (Đã hết hạn gói).
    + `transfer_content`: `'Hết hạn gói Premium, chuyển về gói cơ bản'`.
    + `recognition_code`: `'EXP'`.
    + `created_at`: Thời điểm hết hạn (`now`).
    + `expired_at`: Thời điểm hết hạn (`now`).
    + `is_template`: `false`.
  - Kích hoạt kiểm tra tự động:
    Bên cạnh tác vụ chạy hàng ngày của cronjob lúc 00:00 (`scheduler.service.js`), hàm `findOrdersForAdmin` tại Backend cũng sẽ gọi `await downgradeExpiredPremiumAccounts()` để đảm bảo dữ liệu luôn được cập nhật và lưu vết tức thời khi Admin truy cập trang Lịch sử thanh toán.

---

## 2. PHÂN TÍCH QUY TẮC TỐI CAO 2 (DUAL-AXIS REASONING)

### 2.1. Phân tích Chiều Ngang (Horizontal Reasoning)
- **CSDL PostgreSQL (Supabase):**
  - Không cần sửa DDL bảng `payment_order`, bảo toàn 100% DB Guard (Rule 10). Trường `status` là `VARCHAR(25)` và `package_type` là `VARCHAR(30)` đã đáp ứng hoàn hảo việc lưu `status = 'EXPIRED'`, `package_type = 'Basic'`.
- **Giao diện Admin-web:**
  - Dropdown lọc theo gói cước: Lọc `Basic` sẽ hiển thị lịch sử các lần hết hạn chuyển về gói cơ bản; lọc `Premium` sẽ hiển thị các đơn đăng ký/thanh toán gói Premium.
  - Thống kê KPI Doanh thu (`getPaymentSummaryStats`): Doanh thu thực nhận chỉ tính đơn `status: 'PAID'`, nên bản ghi hết hạn (`amount: 0`, `status: 'EXPIRED'`) **không làm sai lệch doanh thu**.
- **Module Client-app (Mobile Flutter):**
  - Giữ tương thích ngược tối đa: Nếu Client gửi `packageType: 'PREMIUM_1_MONTH'`, Backend tự động chuẩn hóa thành `'Premium'`.

### 2.2. Phân tích Chiều Sâu (Vertical / Deep-impact Reasoning)
- **Toàn vẹn dữ liệu lịch sử:**
  - Thao tác chuẩn hóa 19 bản ghi cũ không làm mất tiền tệ, không ảnh hưởng đến liên kết đối soát bảng `payment_transaction`.
- **Hiệu năng & Tránh lặp bản ghi (Idempotency):**
  - `downgradeExpiredPremiumAccounts` chỉ quét tài khoản có `type = 'Premium'` và `premium_expires_at <= now`, sau đó set ngay `type = 'Basic'` và `premium_expires_at = null`. Do đó mỗi đợt hết hạn chỉ sinh **duy nhất 1 bản ghi** vào `payment_order`, hoàn toàn không thể bị lặp lại.

---

## 3. KẾ HOẠCH HÀNH ĐỘNG CHI TIẾT (ACTIONABLE WORKFLOW)

- [ ] **Task 1: Chuẩn hóa dữ liệu gói trong CSDL (Database Script)**
  - Chạy script cập nhật 19 bản ghi `payment_order` có `package_type IN ('PREMIUM_1_MONTH', 'PREMIUM_6_MONTHS')` sang `'Premium'`.
  - Kiểm tra lại phân phối dữ liệu trong `payment_order` bảo đảm chỉ còn 2 loại gói `Basic` và `Premium`.

- [ ] **Task 2: Backend — Ghi nhận lịch sử hết gói chuyển về Basic vào CSDL**
  - Cập nhật `src/Backend/modules/payment/payment.repository.js`:
    + Trong `downgradeExpiredPremiumAccounts`: Thêm thao tác tạo bản ghi `payment_order` với `package_type: 'Basic'`, `amount: 0`, `status: 'EXPIRED'`, `transfer_content: 'Hết hạn gói Premium, chuyển về gói cơ bản'`.
    + Trong `findOrdersForAdmin`: Gọi `await downgradeExpiredPremiumAccounts()` trước khi truy vấn danh sách để đồng bộ tức thì.
    + Trong `findOrdersForAdmin` điều kiện `packageType`: Hỗ trợ tìm kiếm `package_type` khớp chính xác hoặc tương thích (`where.package_type = packageType`).
    + Trong `createOrder` & `getOrCreatePayosQr`: Mặc định chuẩn hóa `package_type = 'Premium'`.

- [ ] **Task 3: Backend — Bổ sung Unit Test cho cơ chế lưu vết hết hạn gói**
  - Viết test bổ sung cho `downgradeExpiredPremiumAccounts` xác nhận bản ghi `payment_order` được lưu thành công vào CSDL khi tài khoản hết hạn.
  - Chạy `rtk npm test` toàn bộ test suite Backend (đảm bảo 71/71 suites pass).

- [ ] **Task 4: Admin-web Frontend — Bỏ nút "Làm mới" tại Header**
  - Trong `src/Admin-web/src/pages/payments/PaymentHistoryPage.jsx`:
    + Xóa bỏ nút `<button onClick={handleRefresh}>` tại Header.

- [ ] **Task 5: Admin-web Frontend — Chuẩn hóa hiển thị 2 gói cước trong Bộ lọc & Bảng**
  - Trong `PaymentHistoryPage.jsx`:
    + Dropdown gói cước: Hiển thị nhãn trực tiếp từ `packageTypes` nạp từ API CSDL (`Gói Basic (Mặc định)` và `Gói Premium`).
    + Cột "Gói dịch vụ" trong bảng: Phân biệt rõ Badge `Basic` (màu slate/trung tính, icon `inventory_2`) và Badge `Premium` (màu thương hiệu, icon `workspace_premium`).
    + Modal QR mẫu thử nghiệm (Sandbox): Chuẩn hóa gói tạo thành `Premium`.
  - Cập nhật bản dịch `vi.js` và `en.js`: Bổ sung các nhãn `packageBasic`, `packagePremium`, `packageBasicDefault`.

- [ ] **Task 6: Kiểm thử 2 Tầng (2-Tier Testing Architecture - Rule 11)**
  - Viết bài test 2 tầng `src/Admin-web/src/tests/payment.refinement.2tier.test.jsx`:
    + **Tầng 1 (UI Rendering & Interaction):**
      - Header không còn nút "Làm mới".
      - Dropdown gói cước hiển thị đủ `Basic` và `Premium`.
      - Bảng hiển thị đúng badge cho cả gói Basic và Premium.
    + **Tầng 2 (Real System Impact):**
      - Chọn gói `Basic` trong bộ lọc -> Gửi query param `packageType=Basic` đến API backend.
      - Chọn gói `Premium` trong bộ lọc -> Gửi query param `packageType=Premium`.
      - Khi tài khoản hết hạn -> CSDL `payment_order` xuất hiện bản ghi hạ cấp `amount=0`, `status=EXPIRED`, `package_type=Basic`.
  - Chạy `rtk npm test` xác nhận 100% test pass.

- [ ] **Task 7: Hoàn tất & Cập nhật Nguồn sự thật (Rule 8)**
  - Cập nhật `Project.md` mục Lịch sử thanh toán.
  - Chạy `rtk npx codegraph build` đồng bộ CodeGraph.
  - Báo cáo kết quả chi tiết cho PO nghiệm thu.

---

## 4. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)
1. Header trang Lịch sử thanh toán không còn nút "Làm mới".
2. Bộ lọc gói cước hiển thị chính xác các gói từ CSDL (`Gói Basic (Mặc định)`, `Gói Premium`), lọc dữ liệu mượt mà, chính xác.
3. CSDL lưu vết rõ ràng mỗi khi có tài khoản hết hạn gói chuyển về Basic vào bảng `payment_order`, hiển thị đầy đủ trên giao diện quản trị.
4. Toàn bộ test suites Backend và Admin-web đều pass 100%, không phát sinh lỗi phụ (Zero Regressions).
