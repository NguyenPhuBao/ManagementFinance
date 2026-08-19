# Spec: Module Auth & Quản lý Tài khoản — FlowMoney
**Ngày:** 2026-08-17 | **Cập nhật lần cuối:** 2026-08-19 | **Tác giả:** AI BA  
**Phạm vi:** 7 chức năng Auth/Account — CSDL + Backend API + Flutter Client-app  
**Trạng thái:** ✅ **HOÀN THIỆN** — Backend + Client-app đã implement đầy đủ (2026-08-19)

---

## 1. Bối cảnh & Mục tiêu

Module Auth đảm nhiệm toàn bộ vòng đời tài khoản người dùng: đăng ký, đăng nhập, bảo mật phiên làm việc và quản lý thông tin cá nhân. **Tính đến 2026-08-18, toàn bộ 7/7 chức năng đã được implement đầy đủ ở cả Backend lẫn Client-app.** Spec này ghi lại thiết kế và các quyết định kỹ thuật đã được thực thi.

---

## 2. Quyết định thiết kế

| # | Câu hỏi | Quyết định |
|---|---------|-----------|
| Q1 | Kênh gửi OTP | **Email** (SMTP/SendGrid) |
| Q2 | Cơ chế xóa tài khoản | **Ân hạn 30 ngày** — `status = 'PendingDelete'` + `scheduled_delete_at = now + 30d`. Trong 30 ngày user đăng nhập lại → tự động khôi phục. Sau 30 ngày → từ chối đăng nhập. _(Thay đổi từ 2026-08-18: bỏ phương án xóa mềm ngay)_ |
| Q3 | Đổi mật khẩu | **Revoke toàn bộ session** trên mọi thiết bị |
| Q4 | Trường cho phép sửa Profile | **fullname, phone, address, location** (email cần OTP xác minh riêng) |

---

## 3. Thay đổi CSDL (Prisma Schema)

### 3.1 Bảng `account` — thêm giá trị status + trường mới

Mở rộng cột `status` lên `VarChar(20)` và thêm cột `scheduled_delete_at DateTime?`:

```prisma
model account {
  // ...
  status              String    @default("Active") @db.VarChar(20)  // Active | Inactive | PendingDelete | Deleted
  scheduled_delete_at DateTime? @db.Timestamp(6)                    // Thời điểm xóa sau 30 ngày
  // ...
}
```

**Các trạng thái hợp lệ của `status`:**
| Giá trị | Ý nghĩa |
|---|---|
| `Active` | Tài khoản hoạt động bình thường |
| `Inactive` | Bị admin khóa |
| `PendingDelete` | Đang trong thời gian ân hạn 30 ngày chờ xóa |
| `Deleted` | Đã bị xóa vĩnh viễn (không thể đăng nhập) |

Khi yêu cầu xóa tài khoản: `status = 'PendingDelete'`, `scheduled_delete_at = now + 30 ngày`, revoke tất cả refresh token. Data giữ trong DB cho mục đích audit.

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
| DELETE | `/api/auth/account` | Đặt lịch xóa: `status='PendingDelete'` + `scheduled_delete_at = +30d` + revoke tokens |
| POST | `/api/auth/cancel-delete` | Hủy yêu cầu xóa: `status='Active'` + xóa `scheduled_delete_at` |

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

**`DELETE /account`:** Verify password → `account.status = 'PendingDelete'` + `scheduled_delete_at = now + 30 ngày` → revoke toàn bộ token → HTTP 200 với message mô tả ân hạn 30 ngày.

**`POST /cancel-delete`:** Kiểm tra `status === 'PendingDelete'` + còn trong ân hạn → `status = 'Active'` + `scheduled_delete_at = null`.

**`POST /login` (logic bổ sung):** Nếu `status === 'PendingDelete'` và còn trong 30 ngày → verify password → `cancelDeletion()` → cấp token bình thường + trả `pendingDeleteCancelled: true` trong response. Client-app dùng field này để hiển thị dialog thông báo khôi phục.

---

## 5. Flutter Client-app

### 5.1 Methods trong `AuthRemoteDataSource` (đã implement)

```dart
Future<void> logout();
Future<void> changePassword(String currentPassword, String newPassword);
Future<void> forgotPassword(String email);
Future<String> verifyOtp(String email, String otp);
Future<void> resetPassword(String resetToken, String newPassword);
Future<void> deleteAccount(String password);   // Gọi DELETE /auth/account → PendingDelete
Future<void> cancelDelete();                   // Gọi POST /auth/cancel-delete → khôi phục Active
Future<Map<String, dynamic>> getProfile();
Future<void> updateProfile({String? fullname, String? phone, String? address, String? location});
Future<void> requestEmailChange(String newEmail);
Future<void> confirmEmailChange(String newEmail, String otp);
```

**`UserModel`** được bổ sung field `pendingDeleteCancelled` (bool, default=false) và method `copyWith`. Field này được set `true` khi login response từ backend trả `pendingDeleteCancelled: true` (tài khoản vừa được khôi phục tự động).

### 5.2 Trạng thái kết nối UI (cập nhật 2026-08-19)

| File | Trạng thái | Ghi chú |
|------|-----------|--------|
| `forgot_password_page.dart` | ✅ Đã kết nối API | Gọi `forgotPassword(email)` → push `/otp` |
| `otp_page.dart` | ✅ Đã kết nối API | `verifyOtp()` → nhận `resetToken` → push `/reset-password` |
| `reset_password_page.dart` | ✅ Đã kết nối API | `resetPassword(resetToken, newPwd)` → go `/login` |
| `change_password_page.dart` | ✅ Đã kết nối API | `changePassword()` + Form validation → go `/login` |
| `delete_account_page.dart` | ✅ Cập nhật UI ân hạn 30 ngày | `deleteAccount()` → dialog thông báo 30 ngày → logout. Có nút **Hủy yêu cầu** gọi `cancelDelete()`. Timeline 3 mốc trực quan. |
| `login_page.dart` | ✅ Xử lý khôi phục tự động | Khi `AuthSuccess.user.pendingDeleteCancelled == true` → hiện dialog "Tài khoản đã được khôi phục" trước khi vào `/home` |
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
- [x] Bảng `account` mở rộng `status` VarChar(20) + thêm cột `scheduled_delete_at DateTime?`
- [x] `account.status` hỗ trợ đầy đủ: `Active` | `Inactive` | `PendingDelete` | `Deleted`
- [x] 10 endpoint Auth trả đúng HTTP status và response format (thêm `POST /cancel-delete` so với spec gốc)
- [x] Email Service (`email.service.js`) dùng Nodemailer với mock mode khi chưa cấu hình SMTP
- [x] OTP hết hạn sau 10 phút, không dùng lại được
- [x] Đổi mật khẩu → revoke toàn bộ session
- [x] Xóa tài khoản → `status = 'PendingDelete'` + ân hạn 30 ngày (không xóa ngay)
- [x] Đăng nhập lại khi `PendingDelete` + còn trong 30 ngày → tự động khôi phục + trả `pendingDeleteCancelled: true`
- [x] Hủy yêu cầu xóa thủ công qua `POST /cancel-delete`
- [x] Client-app gọi API đúng, xử lý lỗi và hiển thị thông báo
- [x] Field names thống nhất camelCase giữa Client và Backend
- [x] `delete_account_page.dart` cập nhật UI ân hạn 30 ngày: timeline 3 mốc, dialog đúng nội dung, nút hủy yêu cầu
- [x] `login_page.dart` xử lý `pendingDeleteCancelled` → hiện dialog "Tài khoản đã được khôi phục"
- [x] `UserModel` bổ sung `pendingDeleteCancelled` + `copyWith`
- [x] Trang `edit_profile_page.dart` mới tạo với load/save profile
- [x] Route `/settings/edit-profile` đã đăng ký trong `app_router.dart`

> **OTP thực tế:** Email service hiện dùng mock mode (log OTP ra console) khi `SMTP_USER` chưa được cấu hình thật. Để gửi email thật, cập nhật `.env` với SMTP credentials hợp lệ.
