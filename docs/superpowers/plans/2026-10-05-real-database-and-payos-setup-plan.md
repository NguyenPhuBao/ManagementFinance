# Kế Hoạch Triển Khai: Cập Nhật CSDL PostgreSQL Thật & Tích Hợp Cổng PayOS Thực Tế (100% Real Data)

> **Mục tiêu:** 
> 1. Cập nhật cấu trúc CSDL PostgreSQL Supabase thật (bảng `payment_order`, `payment_transaction` và cột `premium_expires_at`), loại bỏ mọi mockup, kiểm tra tính toàn vẹn 100%.
> 2. Hướng dẫn thiết lập kênh thanh toán PayOS thật, lấy bộ khóa bảo mật (`CLIENT_ID`, `API_KEY`, `CHECKSUM_KEY`), cấu hình Webhook và kiểm thử tích hợp thực tế (End-to-End).

---

## PHẦN 1: CẬP NHẬT CƠ SỞ DỮ LIỆU POSTGRESQL SUPABASE THẬT

### 1.1. Nguyên tắc An toàn Dữ liệu (Rule 10 - DB Guard)
- **Tuyệt đối KHÔNG** chạy `prisma migrate dev` hoặc `prisma db push` trên CSDL Cloud Supabase để tránh làm mất các Partial Indexes và Triggers bảo mật.
- Thực thi trực tiếp file DDL [`src/Backend/database/19_create_payment_subscription_tables.sql`](file:///d:/Tai_Lieu_IUH/Tailieu_Nam5_HK1/DoAnTotNghiep/Personal_Finance_Management/src/Backend/database/19_create_payment_subscription_tables.sql) thông qua kết nối PostgreSQL an toàn (`pool.query`).

### 1.2. Các bước triển khai cập nhật CSDL
1. **Bước 1.1: Thực thi SQL DDL trên Supabase Cloud:**
   - Chạy script thực thi nội dung file `19_create_payment_subscription_tables.sql` trực tiếp vào Supabase Tokyo Database qua `DIRECT_URL`.
2. **Bước 1.2: Thẩm tra cấu trúc CSDL thật:**
   - Kiểm tra `information_schema.columns` để xác nhận cột `premium_expires_at` đã tồn tại trên bảng `account`.
   - Kiểm tra `information_schema.tables` để xác nhận 2 bảng `payment_order` và `payment_transaction` đã được khởi tạo thành công.
3. **Bước 1.3: Thẩm tra toàn vẹn Indexes & Triggers:**
   - Chạy script kiểm tra chỉ mục: `rtk npm run db:verify-indexes` đảm bảo 100% không ảnh hưởng tới các thành phần cũ.
4. **Bước 1.4: Viết bài test tích hợp CSDL thật (Integration Test):**
   - Tạo bài test `tests/integration/payment.db.integration.test.js`:
     - Kết nối trực tiếp vào PostgreSQL Supabase qua Prisma Client thật.
     - Tạo một đơn hàng thật trong `payment_order`.
     - Kích hoạt giao dịch trong `payment_transaction`.
     - Cập nhật tài khoản `account` lên `Premium` và dọn dẹp sạch sẽ (rollback/cleanup) sau khi test.
     - **Không sử dụng bất kỳ mock nào.**

---

## PHẦN 2: HƯỚNG DẪN THIẾT LẬP KÊNH THANH TOÁN PAYOS & LIÊN KẾT BACKEND

### 2.1. Đăng ký & Tạo Kênh thanh toán trên PayOS
1. Truy cập [https://my.payos.vn](https://my.payos.vn) và đăng nhập bằng tài khoản Google.
2. Vào mục **Kênh thanh toán (Payment Channels)** $\rightarrow$ Bấm **Tạo kênh thanh toán mới**.
3. Điền thông tin kênh:
   - **Tên kênh thanh toán:** `WealthCommand Payment` (hoặc tên dự án).
   - **Chọn loại tài khoản:** Bạn có thể chọn chế độ **Thử nghiệm (Sandbox/Test)** hoặc liên kết tài khoản ngân hàng thật (MB Bank, VietinBank, TPBank, v.v.).
4. Nhấn **Xác nhận & Hoàn tất**.

### 2.2. Lấy Bộ Khóa Bảo Mật (API Credentials)
Tại trang chi tiết Kênh thanh toán vừa tạo, tìm mục **Thông tin tích hợp**:
- `Client ID`: Sao chép chuỗi mã định danh (VD: `550e8400-e29b-41d4-...`).
- `API Key`: Bấm nút sao chép API Key.
- `Checksum Key`: Bấm hiển thị và sao chép Checksum Key bí mật (dùng để sinh và thẩm tra chữ ký số HMAC-SHA256).

### 2.3. Cấu hình vào tệp `.env` của Backend
Mở tệp `src/Backend/.env` và thêm vào cuối tệp:
```env
# ====================================================
# CỔNG THANH TOÁN PAYOS (VIETQR / NGÂN HÀNG)
# ====================================================
PAYOS_CLIENT_ID=<Dán_Client_ID_vào_đây>
PAYOS_API_KEY=<Dán_API_Key_vào_đây>
PAYOS_CHECKSUM_KEY=<Dán_Checksum_Key_vào_đây>
PAYOS_RETURN_URL=https://managementfinance-admin.vercel.app/payment/success
PAYOS_CANCEL_URL=https://managementfinance-admin.vercel.app/payment/cancel
PREMIUM_PRICE_VND=49000
PREMIUM_PACKAGE_DAYS=30
```

### 2.4. Thiết lập Webhook URL trên PayOS Dashboard
PayOS cần biết địa chỉ máy chủ Backend của bạn để bắn thông báo khi người dùng chuyển tiền thành công:
1. **Nếu chạy trên môi trường Development (Local):**
   - Do PayOS ở trên Internet không thể gọi trực tiếp vào `http://localhost:10000`, cần mở tunnel bằng **Ngrok** hoặc **Cloudflare Tunnel**:
     ```bash
     ngrok http 10000
     ```
   - Lấy URL dạng: `https://xxxx-xx-xx.ngrok-free.app/api/payment/webhook`.
2. **Nếu chạy trên môi trường Production (Render Cloud):**
   - Điền URL: `https://managementfinance.onrender.com/api/payment/webhook`.
3. Nhập URL này vào ô **Webhook URL** trên PayOS Dashboard $\rightarrow$ Bấm **Lưu & Xác nhận Webhook**.

---

## PHẦN 3: BÀI TEST TÍCH HỢP ĐẦU CUỐI (END-TO-END VERIFICATION)

1. **Test 1: Gọi PayOS API thật:**
   - Chạy script gọi PayOS SDK thật với API Key thật $\rightarrow$ Nhận về link VietQR thật từ PayOS.
2. **Test 2: Giao dịch thanh toán thật:**
   - Dùng app ngân hàng thật quét mã QR chuyển khoản thật (ví dụ 2,000 VNĐ hoặc 49,000 VNĐ).
   - Quan sát Webhook PayOS bắn về Backend $\rightarrow$ Server thẩm tra chữ ký HMAC-SHA256 thành công.
   - Kiểm tra CSDL PostgreSQL Supabase: Tài khoản được chuyển sang `Premium`, `premium_expires_at` tăng 30 ngày.
