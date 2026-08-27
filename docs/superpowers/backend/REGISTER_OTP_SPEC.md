# API Spec — Đăng ký có xác thực OTP qua Email

> **Tình trạng:** ✅ **Backend ĐÃ TRIỂN KHAI & TEST HOÀN TẤT (100% PASS)**  
> **Backend Base URL:** `http://localhost:3000/api` (Local) / `https://managementfinance.onrender.com/api` (Cloud)  
> **Cập nhật lần cuối:** 2026-08-27  

---

## 📌 1. Tổng quan luồng đăng ký mới

```
Người dùng điền form đăng ký
  ↓
Client App gọi: POST /api/auth/register/send-otp
  ↓ (Backend kiểm tra trùng lặp email/username, tạo OTP & gửi email xác thực)
Client App chuyển sang màn hình nhập OTP (Đếm ngược 10 phút)
  ↓ (Người dùng nhập OTP 6 số)
Client App gọi: POST /api/auth/register/verify-otp (gửi kèm toàn bộ form + OTP)
  ↓ (Backend xác thực OTP, tạo Account + User, cấp token)
Client App nhận JWT accessToken + refreshToken, lưu vào local storage và chuyển vào trang chủ!
```

---

## 🚀 2. Chi tiết các Endpoint cho Client-App

### 🔹 API 1: Gửi OTP Đăng ký

* **Endpoint:** `POST /api/auth/register/send-otp`
* **Quyền hạn (Auth):** Public (Không cần token)
* **Tác dụng:** 
  - Kiểm tra xem `username` và `email` đã bị ai sử dụng chưa.
  - Sinh mã OTP 6 số ngẫu nhiên, lưu vào bảng `otp_code` với hiệu lực 10 phút.
  - Gửi email chứa mã OTP đến địa chỉ email đăng ký.
  - **CHƯA** tạo tài khoản ở bước này.

#### Request Header:
```http
Content-Type: application/json
```

#### Request Body:
```json
{
  "username": "nguyenvana",
  "fullname": "Nguyễn Văn A",
  "email": "nguyenvana@gmail.com",
  "password": "secretPassword123",
  "phone": "0901234567"
}
```

* **Validation Rules:**
  - `username`: Bắt buộc, chuỗi từ 3 đến 50 ký tự.
  - `password`: Bắt buộc, chuỗi từ 6 đến 100 ký tự.
  - `fullname`: Bắt buộc, chuỗi từ 2 đến 100 ký tự.
  - `email`: Bắt buộc, định dạng email hợp lệ, từ 5 đến 100 ký tự.
  - `phone`: Tùy chọn (optional), chuỗi từ 8 đến 15 ký tự.

#### Response Thành công (HTTP 200 OK):
```json
{
  "success": true,
  "message": "Mã OTP đã được gửi đến email của bạn. Hiệu lực 10 phút.",
  "data": null
}
```

#### Response Lỗi (HTTP 409 Conflict):
* Khi username đã tồn tại:
```json
{
  "success": false,
  "message": "Username đã được sử dụng"
}
```
* Khi email đã tồn tại:
```json
{
  "success": false,
  "message": "Email đã được sử dụng"
}
```

#### Response Lỗi (HTTP 400 Bad Request):
* Khi thiếu trường dữ liệu hoặc sai định dạng validation:
```json
{
  "success": false,
  "message": "Validation error: email must be a valid email"
}
```

---

### 🔹 API 2: Xác thực OTP & Tạo tài khoản

* **Endpoint:** `POST /api/auth/register/verify-otp`
* **Quyền hạn (Auth):** Public (Không cần token)
* **Tác dụng:**
  - Kiểm tra tính hợp lệ và thời hạn của mã OTP.
  - Đánh dấu mã OTP đã được sử dụng.
  - Kiểm tra lại race condition username/email.
  - Tạo bản ghi mới trong bảng `account` và `user` (CSDL Supabase).
  - Cấp cặp JWT `accessToken` (thời hạn 7 ngày) và `refreshToken` (thời hạn 90 ngày).
  - Trả về thông tin người dùng và token để Client App tự động đăng nhập.

#### Request Header:
```http
Content-Type: application/json
```

#### Request Body:
```json
{
  "username": "nguyenvana",
  "fullname": "Nguyễn Văn A",
  "email": "nguyenvana@gmail.com",
  "password": "secretPassword123",
  "phone": "0901234567",
  "otp": "654321"
}
```

* **Validation Rules:**
  - Tất cả các trường của API 1.
  - `otp`: Bắt buộc, chuỗi đúng 6 chữ số.

#### Response Thành công (HTTP 201 Created):
```json
{
  "success": true,
  "message": "Đăng ký thành công",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "idaccount": 5,
      "username": "nguyenvana",
      "rolename": "user",
      "fullname": "Nguyễn Văn A",
      "email": "nguyenvana@gmail.com"
    }
  }
}
```

#### Response Lỗi (HTTP 400 Bad Request):
* Khi mã OTP không đúng hoặc đã quá hạn 10 phút:
```json
{
  "success": false,
  "message": "Mã OTP không hợp lệ hoặc đã hết hạn"
}
```

#### Response Lỗi (HTTP 409 Conflict):
* Nếu tài khoản bị đăng ký trùng trước đó:
```json
{
  "success": false,
  "message": "Email đã được sử dụng"
}
```

---

## ⚙️ 3. Chi tiết Thay đổi Kỹ thuật phía Backend

1. **CSDL (Supabase PostgreSQL)**:
   - Cột `otp_code.Idaccount` đã được đổi thành `INT NULL` (cho phép `NULL` khi đăng ký vì người dùng chưa có tài khoản).
   - Đã thêm index `idx_otp_email_purpose` trên `(Email, purpose)` để tối ưu tốc độ tra cứu OTP.
   - Đã chạy `prisma db push` thành công lên Supabase.

2. **Email Service (`email.service.js`)**:
   - Thêm template gửi OTP đăng ký với tiêu đề: *"Mã OTP xác thực đăng ký tài khoản — FlowMoney"*.
   - Hỗ trợ gửi qua SMTP Gmail (hoặc Mock log nếu không cấu hình SMTP).

3. **Backward Compatibility**:
   - Endpoint `POST /api/auth/register` (luồng cũ không OTP) vẫn được giữ lại với trạng thái `@deprecated` để đảm bảo hệ thống không bị lỗi nếu client phiên bản cũ gọi vào.

---

## ✅ 4. Checklist Hoàn thành Backend

- [x] Sửa schema Prisma `otp_code.idaccount` nullable & chạy `prisma db push`.
- [x] Tạo `sendRegisterOtpSchema` và `verifyRegisterOtpSchema` trong `auth.validation.js`.
- [x] Thêm hàm `findValidOtpByEmail` trong `auth.repository.js`.
- [x] Thêm `sendRegisterOtp` và `verifyRegisterOtp` trong `auth.service.js`.
- [x] Thêm Controller handlers trong `auth.controller.js`.
- [x] Khai báo routes trong `api/auth.routes.js`.
- [x] Cập nhật `email.service.js` với tiêu đề email đăng ký.
- [x] Chạy kiểm thử tự động toàn diện: **100% PASS** (Gửi OTP, Check trùng, Chặn sai OTP, Xác thực đúng OTP, Cấp token, Đăng nhập ngay sau khi tạo).

