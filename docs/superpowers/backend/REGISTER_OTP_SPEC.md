# API Spec — Đăng ký có xác thực OTP qua Email

> **Tình trạng:** Cần Backend implement  
> Viết bởi: Client-app team  
> Ngày: 2026-08-26

---

## Tổng quan luồng mới

```
Luồng CŨ (hiện tại):
POST /auth/register → Tạo tài khoản + trả về token ngay

Luồng MỚI (yêu cầu):
POST /auth/register/send-otp  → Kiểm tra trùng + Gửi OTP về email (CHƯA tạo account)
  ↓ (user nhập OTP)
POST /auth/register/verify-otp → Xác thực OTP + Tạo tài khoản + Trả về token
```

---

## API 1 — Gửi OTP đăng ký

### `POST /auth/register/send-otp`

**Mô tả:** Kiểm tra username/email chưa tồn tại, gửi OTP 6 số về email. Chưa tạo tài khoản ở bước này.

**Request Body:**
```json
{
  "username": "nguyenvana",
  "fullname": "Nguyễn Văn A",
  "email": "nguyenvana@gmail.com",
  "password": "secret123",
  "phone": "0901234567"   // optional
}
```

**Validation (giữ nguyên như registerSchema cũ):**
- `username`: required, string, 3–50 ký tự
- `password`: required, string, 6–100 ký tự
- `fullname`: required, string, 2–100 ký tự
- `email`: required, string, 5–100 ký tự
- `phone`: optional, string, 8–15 ký tự

**Logic backend cần làm:**
1. Kiểm tra `username` đã tồn tại → 409 nếu trùng
2. Kiểm tra `email` đã tồn tại → 409 nếu trùng
3. Tạo OTP 6 số ngẫu nhiên
4. Hash OTP, lưu vào bảng `otp_code` với:
   - `email` = email đăng ký
   - `idaccount` = null (chưa có account) hoặc dùng một sentinel value
   - `purpose` = `'register'`
   - `expires_at` = `now + 10 phút`
5. **LƯU TẠM** thông tin đăng ký vào cache (Redis, TTL 15 phút):
   - Key: `register_pending:{email}`
   - Value: `{ username, fullname, email, hashedPassword, phone }`
   - Hoặc đơn giản hơn: Không lưu cache, bắt client gửi lại toàn bộ data ở bước 2
6. Gửi email OTP (dùng `emailService.sendOtp(email, otp, 'register')`)

**Response 200 OK:**
```json
{
  "success": true,
  "message": "Mã OTP đã được gửi đến email của bạn. Hiệu lực 10 phút.",
  "data": null
}
```

**Response 409 Conflict:**
```json
{
  "success": false,
  "message": "Username đã được sử dụng"
}
```

---

## API 2 — Xác thực OTP + Tạo tài khoản

### `POST /auth/register/verify-otp`

**Mô tả:** Xác thực mã OTP, nếu đúng thì tạo tài khoản và trả về token đăng nhập ngay.

**Request Body (Option A — Client gửi lại toàn bộ data, đơn giản hơn):**
```json
{
  "username": "nguyenvana",
  "fullname": "Nguyễn Văn A",
  "email": "nguyenvana@gmail.com",
  "password": "secret123",
  "phone": "0901234567",
  "otp": "123456"
}
```

> **Khuyến nghị:** Dùng Option A (client gửi lại toàn bộ). Đơn giản hơn, không cần Redis cache. Backend hash lại password khi tạo account.

**Logic backend cần làm:**
1. Hash OTP đầu vào
2. Tìm OTP record trong `otp_code` theo `email`, `purpose = 'register'`, `is_used = false`, `expires_at > now`
3. Nếu không tìm thấy → 400 "OTP không hợp lệ hoặc đã hết hạn"
4. Mark OTP là đã dùng (`is_used = true`)
5. Kiểm tra lại `username` / `email` chưa bị ai đăng ký trong lúc chờ OTP (race condition)
6. Tạo account + user (dùng lại logic của `register()` cũ)
7. Tạo JWT accessToken + refreshToken
8. Trả về giống response của `POST /auth/register` hiện tại

**Response 201 Created:**
```json
{
  "success": true,
  "message": "Đăng ký thành công",
  "data": {
    "accessToken": "eyJ...",
    "refreshToken": "eyJ...",
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

**Response 400:**
```json
{
  "success": false,
  "message": "Mã OTP không hợp lệ hoặc đã hết hạn"
}
```

---

## Xử lý bảng `otp_code` với `purpose = 'register'`

Bảng `otp_code` hiện tại đang có FK `idaccount` bắt buộc. Cần điều chỉnh:

**Option A (Khuyến nghị):** Cho phép `idaccount` nullable với `purpose = 'register'`
```sql
-- Sửa schema Prisma:
idaccount  Int?   -- nullable cho register OTP
```

**Option B:** Dùng `idaccount = 0` là sentinel value (không cần thay đổi schema)

> Hãy thống nhất với team rồi cập nhật schema tương ứng.

---

## Email template cần thêm

Hàm `emailService.sendOtp(email, otp, purpose)` hiện hỗ trợ:
- `'reset_password'`
- `'change_email'`

**Cần thêm:** `'register'` — tiêu đề email khác ("Xác thực đăng ký tài khoản FlowMoney")

---

## Giữ backward compat: `POST /auth/register` cũ

> ⚠️ **Quyết định cần thống nhất:**

| Phương án | Ưu | Nhược |
|---|---|---|
| Giữ `POST /auth/register` (không OTP) | Không breaking | Không có xác thực email |
| Deprecated `POST /auth/register`, chỉ dùng flow mới | Clean | Client cũ bị lỗi |
| Giữ cả 2, flow mới là optional (flag `requireOtp`) | Linh hoạt | Phức tạp hơn |

**Khuyến nghị client-app:** Phương án **Deprecated** (chỉ dùng flow mới), vì client-app sẽ cập nhật đồng thời khi backend deploy.

---

## Tóm tắt việc backend cần làm

- [ ] Thêm API `POST /auth/register/send-otp`
- [ ] Thêm API `POST /auth/register/verify-otp`
- [ ] Xử lý `idaccount` nullable trong `otp_code` cho purpose `'register'`
- [ ] Thêm email template cho `'register'` trong `emailService`
- [ ] (Optional) Thêm email template gửi OTP vào `email.service.js` với subject phù hợp
- [ ] Thông báo cho client-app khi API sẵn sàng để client-app cập nhật flow
