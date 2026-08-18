# Spec: Module Auth & Quản lý Tài khoản — FlowMoney
**Ngày:** 2026-08-17 | **Cập nhật lần cuối:** 2026-08-18 | **Tác giả:** AI BA  
**Phạm vi:** 7 chức năng Auth/Account — CSDL + Backend API + Flutter Client-app  
**Trạng thái:** ✅ **HOÀN THIỆN** — Backend + Client-app đã implement đầy đủ (2026-08-18)

---

## 1. Bối cảnh & Mục tiêu

Module Auth đảm nhiệm toàn bộ vòng đời tài khoản người dùng: đăng ký, đăng nhập, bảo mật phiên làm việc và quản lý thông tin cá nhân. **Tính đến 2026-08-18, toàn bộ 7/7 chức năng đã được implement đầy đủ ở cả Backend lẫn Client-app.** Spec này ghi lại thiết kế và các quyết định kỹ thuật đã được thực thi.

---

## 2. Quyết định thiết kế

| # | Câu hỏi | Quyết định |
|---|---------|-----------|
| Q1 | Kênh gửi OTP | **Email** (SMTP/SendGrid) |
| Q2 | Cơ chế xóa tài khoản | **Xóa mềm ngay** — `status = 'Deleted'` |
| Q3 | Đổi mật khẩu | **Revoke toàn bộ session** trên mọi thiết bị |
| Q4 | Trường cho phép sửa Profile | **fullname, phone, address, location** (email cần OTP xác minh riêng) |

---

## 3. Thay đổi CSDL (Prisma Schema)

### 3.1 Bảng `account` — thêm giá trị status mới

Thêm `'Deleted'` vào CHECK constraint của cột `status`.  
Khi xóa tài khoản: cập nhật `account.status = 'Deleted'` và revoke tất cả refresh token. Data vẫn giữ lại trong DB cho mục đích audit.

### 3.2 Bảng `otp_code` — MỚI

```prisma
model otp_code {
  id         Int       @id @default(autoincrement())
  email      String    @db.VarChar(100)
  code_hash  String    @db.VarChar(255)   // SHA-256 hash của OTP
  purpose    String    @db.VarChar(30)    // 'reset_password' | 'change_email'
  is_used    Boolean   @default(false)
  expires_at DateTime  @db.Timestamp(6)
  created_at DateTime  @default(now()) @db.Timestamp(6)

  @@index([email, purpose])
  @@index([expires_at])
}
```

- Lưu `code_hash` (không lưu OTP gốc)
- Trường `purpose` phân biệt OTP dùng cho reset mật khẩu vs đổi email  
- TTL: OTP hết hạn sau **10 phút**
- Sau khi dùng: set `is_used = true`, không xóa để audit log

---

## 4. Backend API

### 4.1 Endpoints đã có (không thay đổi)

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| POST | `/api/auth/register` | Đăng ký |
| POST | `/api/auth/login` | Đăng nhập |
| POST | `/api/auth/logout` | Đăng xuất (revoke tokens) |
| POST | `/api/auth/refresh` | Làm mới access token |
| GET | `/api/auth/me` | Lấy thông tin tài khoản |

### 4.2 Endpoints cần thêm mới

**Quên mật khẩu (Public):**

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| POST | `/api/auth/forgot-password` | Nhận email → tạo OTP → gửi mail |
| POST | `/api/auth/verify-otp` | Xác minh OTP → trả về `reset_token` JWT 15 phút |
| POST | `/api/auth/reset-password` | Nhận `reset_token` + mật khẩu mới → cập nhật |

**Quản lý tài khoản (JWT required):**

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| PATCH | `/api/auth/change-password` | Đổi mật khẩu + revoke tất cả session |
| DELETE | `/api/auth/account` | Xóa mềm: `status='Deleted'` + revoke tokens |

**Quản lý Profile (JWT required):**

| Method | Endpoint | Trạng thái |
|--------|----------|----------|
| GET | `/api/auth/profile` | ✅ Implemented |
| PATCH | `/api/auth/profile` | ✅ Implemented |
| POST | `/api/auth/profile/request-email-change` | ✅ Implemented |
| PATCH | `/api/auth/profile/confirm-email-change` | ✅ Implemented |

### 4.3 Logic nghiệp vụ quan trọng

**`POST /forgot-password`:** Tạo OTP 6 số → hash SHA-256 → lưu DB → gửi email. Nếu email không tồn tại vẫn trả 200 (không tiết lộ).

**`POST /verify-otp`:** Kiểm tra `is_used=false`, `expires_at > now`, hash khớp → set `is_used=true` → trả `reset_token` JWT.

**`PATCH /change-password`:** Verify mật khẩu cũ → hash mới → cập nhật → **revoke toàn bộ refresh token** (Q3=A).

**`DELETE /account`:** Verify password → `account.status = 'Deleted'` → revoke toàn bộ token.

---

## 5. Flutter Client-app

### 5.1 Methods cần thêm vào `AuthRemoteDataSource`

```dart
Future<void> logout();
Future<void> changePassword(String currentPassword, String newPassword);
Future<void> forgotPassword(String email);
Future<String> verifyOtp(String email, String otp);
Future<void> resetPassword(String resetToken, String newPassword);
Future<void> deleteAccount(String password);
Future<Map<String, dynamic>> getProfile();
Future<void> updateProfile({String? fullname, String? phone, String? address, String? location});
Future<void> requestEmailChange(String newEmail);
Future<void> confirmEmailChange(String email, String otp);
```

### 5.2 Trạng thái kết nối UI (2026-08-18)

| File | Trạng thái | Ghi chú |
|------|-----------|--------|
| `forgot_password_page.dart` | ✅ Đã kết nối API | Gọi `forgotPassword(email)` → push `/otp` |
| `otp_page.dart` | ✅ Đã kết nối API | `verifyOtp()` → nhận `resetToken` → push `/reset-password` |
| `reset_password_page.dart` | ✅ Đã kết nối API | `resetPassword(resetToken, newPwd)` → go `/login` |
| `change_password_page.dart` | ✅ Đã kết nối API | `changePassword()` + Form validation → go `/login` |
| `delete_account_page.dart` | ✅ Đã kết nối API | `deleteAccount(password)` + AuthBloc.logout → go `/login` |
| `edit_profile_page.dart` | ✅ Trang mới tạo | `getProfile()` khi init + `updateProfile()` khi save |
| `settings_page.dart` | ✅ Đã kết nối nav | Nút "Thông tin cá nhân" + icon edit → `/settings/edit-profile` |

**Lưu ý field mapping (Backend dùng camelCase):**
- `changePassword`: gửi `currentPassword`, `newPassword` (không phải snake_case)
- `resetPassword`: gửi `resetToken`, `newPassword`
- `requestEmailChange`: gửi `newEmail`
- `confirmEmailChange`: gửi `newEmail`, `otp`

### 5.3 Truyền data giữa màn hình OTP

Dùng GoRouter `extra` parameter:
- `ForgotPasswordPage` → `OtpPage`: truyền `{ email: string }`
- `OtpPage` → `ResetPasswordPage`: truyền `{ reset_token: string }`

---

## 6. Email Service (Backend)

Thêm vào `.env`:
```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM="FlowMoney <no-reply@flowmoney.app>"
```

Tạo `core/email.service.js` dùng **Nodemailer**. Template email OTP bằng tiếng Việt, hiển thị mã 6 số, hết hạn sau 10 phút.

---

## 7. Thứ tự implementation

1. **CSDL** → Thêm `otp_code` vào schema + `prisma migrate dev`
2. **Backend: Email Service** → `core/email.service.js`
3. **Backend: Auth Endpoints** → theo thứ tự: `change-password` → quên mật khẩu (3 endpoints) → `DELETE /account` → `profile` endpoints
4. **Client-app** → Cập nhật `AuthRemoteDataSource` → kết nối từng màn hình

---

## 8. Definition of Done

- [x] Migration `otp_code` thành công
- [x] `account.status` nhận thêm giá trị `'Deleted'`
- [x] 9 endpoint mới trả đúng HTTP status và response format
- [x] Email Service (`email.service.js`) dùng Nodemailer với mock mode khi chưa cấu hình SMTP
- [x] OTP hết hạn sau 10 phút, không dùng lại được
- [x] Đổi mật khẩu → revoke toàn bộ session
- [x] Xóa tài khoản → status Deleted, không đăng nhập lại được
- [x] Client-app gọi API đúng, xử lý lỗi và hiển thị thông báo
- [x] Field names thống nhất camelCase giữa Client và Backend
- [x] Trang `edit_profile_page.dart` mới tạo với load/save profile
- [x] Route `/settings/edit-profile` đã đăng ký trong `app_router.dart`

> **OTP thực tế:** Email service hiện dùng mock mode (log OTP ra console) khi `SMTP_USER` chưa được cấu hình thật. Để gửi email thật, cập nhật `.env` với SMTP credentials hợp lệ.
