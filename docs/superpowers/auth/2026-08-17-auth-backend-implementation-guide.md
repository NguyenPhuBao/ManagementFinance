# Tài liệu Backend — Module Auth & Quản lý Tài khoản
**Dự án:** FlowMoney  
**Ngày:** 2026-08-17  
**Người viết:** AI BA  
**Dành cho:** Team Backend Developer

---

## 📋 Danh sách file cần đọc & chỉnh sửa

### File cần sửa (theo thứ tự thực hiện)

| # | Đường dẫn | Việc cần làm |
|---|-----------|-------------|
| 1 | `src/Backend/prisma/schema.prisma` | Thêm model `otp_code` + sửa CHECK constraint `account.status` |
| 2 | `src/Backend/.env` | Thêm 5 biến `SMTP_*` (xem mục 3.1 bên dưới) |
| 3 | `src/Backend/config/index.js` | Thêm block `smtp:` vào config object (xem mục 3.2) |
| 4 | `src/Backend/core/email.service.js` | **Tạo file mới** — Nodemailer service (xem mục 3.3) |
| 5 | `src/Backend/modules/auth/auth.repository.js` | Thêm 10 method mới (xem mục 4) |
| 6 | `src/Backend/modules/auth/auth.validation.js` | Thêm 8 schema validation mới (xem mục 8) |
| 7 | `src/Backend/modules/auth/auth.service.js` | Thêm 9 hàm nghiệp vụ mới (xem mục 5) |
| 8 | `src/Backend/modules/auth/auth.controller.js` | Thêm 9 controller handler mới (xem mục 6) |
| 9 | `src/Backend/api/auth.routes.js` | Đăng ký toàn bộ route mới (xem mục 7) |

### File chỉ cần đọc để hiểu pattern (không sửa)

| Đường dẫn | Mục đích |
|-----------|---------|
| `src/Backend/modules/auth/auth.service.js` | Hiểu pattern `bcrypt`, `jwt`, `revokeAllTokens` hiện có |
| `src/Backend/middleware/auth.js` | Hiểu cách `authenticate` middleware hoạt động |
| `src/Backend/middleware/validator.js` | Hiểu format schema validation để viết đúng |
| `src/Backend/core/response-handler.js` | Dùng đúng `ResponseHandler.success/error` |
| `src/Backend/core/logger.js` | Log đúng format đang dùng trong project |

### Lệnh cần chạy sau khi sửa schema

```bash
cd src/Backend
npm install nodemailer
npx prisma migrate dev --name add_otp_code_and_deleted_status
npx prisma generate
```

---


---

## 1. Thay đổi CSDL (Prisma Schema)

### 1.1 Bảng `otp_code` — Tạo mới

Thêm vào `prisma/schema.prisma`:

```prisma
model otp_code {
  id         Int       @id @default(autoincrement())
  email      String    @db.VarChar(100)
  code_hash  String    @db.VarChar(255)
  purpose    String    @db.VarChar(30)
  is_used    Boolean   @default(false)
  expires_at DateTime  @db.Timestamp(6)
  created_at DateTime  @default(now()) @db.Timestamp(6)

  @@index([email, purpose])
  @@index([expires_at])
}
```

**Giải thích:**
- `code_hash`: lưu `SHA-256(otp_plaintext)` — không bao giờ lưu OTP gốc
- `purpose`: `'reset_password'` hoặc `'change_email'`
- `expires_at`: thời điểm hết hạn, set = `now() + 10 phút` khi tạo
- `is_used`: set `true` ngay sau khi OTP được verify thành công

### 1.2 Bảng `account` — Thêm giá trị status `'Deleted'`

Cột `status` hiện chỉ nhận `'Active'` | `'Inactive'`. Cần bổ sung `'Deleted'`.

Nếu DB dùng CHECK constraint (PostgreSQL), chạy migration SQL thủ công hoặc cập nhật Prisma schema rồi `migrate dev`:

```sql
-- Chạy nếu cần update CHECK constraint thủ công:
ALTER TABLE account 
DROP CONSTRAINT IF EXISTS account_status_check;

ALTER TABLE account 
ADD CONSTRAINT account_status_check 
CHECK (status IN ('Active', 'Inactive', 'Deleted'));
```

### 1.3 Chạy migration

```bash
cd src/Backend
npx prisma migrate dev --name add_otp_code_and_deleted_status
npx prisma generate
```

---

## 2. Cài đặt Dependencies

```bash
npm install nodemailer
```

---

## 3. Cấu hình Email (SMTP)

### 3.1 Thêm vào `.env`

```env
# Email (SMTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password        # Dùng App Password của Gmail, không phải mật khẩu thường
SMTP_FROM="FlowMoney <no-reply@flowmoney.app>"
```

> **Lưu ý:** Với Gmail, cần bật **2-Step Verification** và tạo **App Password** tại https://myaccount.google.com/apppasswords

### 3.2 Thêm vào `config/index.js`

```js
smtp: {
  host:  process.env.SMTP_HOST  || 'smtp.gmail.com',
  port:  parseInt(process.env.SMTP_PORT, 10) || 587,
  user:  process.env.SMTP_USER,
  pass:  process.env.SMTP_PASS,
  from:  process.env.SMTP_FROM  || '"FlowMoney" <no-reply@flowmoney.app>',
},
```

### 3.3 Tạo `core/email.service.js`

```js
const nodemailer = require('nodemailer');
const config = require('../config');
const logger = require('./logger');

const transporter = nodemailer.createTransport({
  host: config.smtp.host,
  port: config.smtp.port,
  secure: false, // true nếu port 465
  auth: { user: config.smtp.user, pass: config.smtp.pass },
});

const emailService = {
  async sendOtp(email, otp, purpose) {
    const subject = purpose === 'reset_password'
      ? 'Mã OTP khôi phục mật khẩu — FlowMoney'
      : 'Mã OTP xác nhận đổi email — FlowMoney';

    const html = `
      <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;border:1px solid #e0e0e0;border-radius:8px;">
        <h2 style="color:#1565C0;">FlowMoney</h2>
        <p>Xin chào,</p>
        <p>Mã OTP của bạn là:</p>
        <div style="font-size:36px;font-weight:bold;letter-spacing:12px;color:#1565C0;text-align:center;padding:16px 0;">
          ${otp}
        </div>
        <p>Mã này có hiệu lực trong <strong>10 phút</strong>. Vui lòng không chia sẻ mã này với bất kỳ ai.</p>
        <p style="color:#999;font-size:12px;">Nếu bạn không yêu cầu hành động này, vui lòng bỏ qua email này.</p>
      </div>
    `;

    try {
      await transporter.sendMail({ from: config.smtp.from, to: email, subject, html });
      logger.info('OTP email sent', { email, purpose });
    } catch (err) {
      logger.error('Failed to send OTP email', { email, error: err.message });
      throw new Error('Không thể gửi email. Vui lòng thử lại sau.');
    }
  },
};

module.exports = emailService;
```

---

## 4. OTP Repository — Thêm vào `auth.repository.js`

```js
// Thêm các method sau vào authRepository object:

async createOtp(email, codeHash, purpose, expiresAt) {
  return prisma.otp_code.create({
    data: { email, code_hash: codeHash, purpose, expires_at: expiresAt, is_used: false },
  });
},

async findValidOtp(email, codeHash, purpose) {
  return prisma.otp_code.findFirst({
    where: {
      email,
      code_hash: codeHash,
      purpose,
      is_used: false,
      expires_at: { gt: new Date() },
    },
    orderBy: { created_at: 'desc' },
  });
},

async markOtpUsed(id) {
  return prisma.otp_code.update({ where: { id }, data: { is_used: true } });
},

async findAccountById(idaccount) {
  return prisma.account.findUnique({
    where: { idaccount },
    include: {
      role: { select: { idrole: true, rolename: true } },
      User: true,
    },
  });
},

async findAccountByEmail(email) {
  // Đã có, nhưng cần sửa để trả về thêm idaccount:
  return prisma.user.findFirst({
    where: { email },
    include: {
      account: {
        include: { role: { select: { idrole: true, rolename: true } } },
      },
    },
  });
},

async updatePassword(idaccount, hashedPassword) {
  return prisma.account.update({
    where: { idaccount },
    data: { password: hashedPassword, updated_at: new Date() },
  });
},

async softDeleteAccount(idaccount) {
  return prisma.account.update({
    where: { idaccount },
    data: { status: 'Deleted', updated_at: new Date() },
  });
},

async getProfile(idaccount) {
  return prisma.user.findUnique({
    where: { idaccount },
  });
},

async updateProfile(idaccount, data) {
  return prisma.user.update({
    where: { idaccount },
    data: { ...data, updated_at: new Date() },
  });
},

async updateEmail(idaccount, newEmail) {
  return prisma.user.update({
    where: { idaccount },
    data: { email: newEmail, updated_at: new Date() },
  });
},
```

---

## 5. Auth Service — Logic nghiệp vụ

### 5.1 Thêm helper function `hashOtp` vào `auth.service.js`

```js
function hashOtp(otp) {
  return crypto.createHash('sha256').update(otp).digest('hex');
}
```

### 5.2 Thêm các service methods

```js
// === CHANGE PASSWORD ===
async changePassword(idaccount, currentPassword, newPassword) {
  const account = await authRepository.findAccountById(idaccount);
  if (!account) throw Object.assign(new Error('Tài khoản không tồn tại'), { statusCode: 404 });

  const isMatch = await bcrypt.compare(currentPassword, account.password);
  if (!isMatch) throw Object.assign(new Error('Mật khẩu hiện tại không đúng'), { statusCode: 400 });

  const salt = await bcrypt.genSalt(10);
  const hashedNew = await bcrypt.hash(newPassword, salt);
  await authRepository.updatePassword(idaccount, hashedNew);

  // Revoke toàn bộ refresh token
  await authService.revokeAllTokens(idaccount);
  logger.info('Password changed, all tokens revoked', { idaccount });
},

// === FORGOT PASSWORD ===
async forgotPassword(email) {
  const userRecord = await authRepository.findAccountByEmail(email);
  // Không tiết lộ email có tồn tại hay không (security)
  if (!userRecord) return;

  const otp = Math.floor(100000 + Math.random() * 900000).toString(); // 6 số
  const codeHash = hashOtp(otp);
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // +10 phút

  await authRepository.createOtp(email, codeHash, 'reset_password', expiresAt);
  await emailService.sendOtp(email, otp, 'reset_password');
  logger.info('OTP sent for forgot password', { email });
},

// === VERIFY OTP ===
async verifyOtp(email, otp) {
  const codeHash = hashOtp(otp);
  const record = await authRepository.findValidOtp(email, codeHash, 'reset_password');
  if (!record) throw Object.assign(new Error('Mã OTP không hợp lệ hoặc đã hết hạn'), { statusCode: 400 });

  await authRepository.markOtpUsed(record.id);

  // Tạo reset_token JWT ngắn hạn (15 phút), không lưu vào refreshtoken table
  const resetToken = jwt.sign({ email, purpose: 'reset_password' }, config.jwt.accessSecret, { expiresIn: '15m' });
  logger.info('OTP verified, reset token issued', { email });
  return resetToken;
},

// === RESET PASSWORD ===
async resetPassword(resetToken, newPassword) {
  let payload;
  try {
    payload = jwt.verify(resetToken, config.jwt.accessSecret);
  } catch {
    throw Object.assign(new Error('Token không hợp lệ hoặc đã hết hạn'), { statusCode: 401 });
  }
  if (payload.purpose !== 'reset_password') throw Object.assign(new Error('Token không hợp lệ'), { statusCode: 401 });

  const userRecord = await authRepository.findAccountByEmail(payload.email);
  if (!userRecord) throw Object.assign(new Error('Tài khoản không tồn tại'), { statusCode: 404 });

  const idaccount = userRecord.account.idaccount;
  const salt = await bcrypt.genSalt(10);
  const hashedNew = await bcrypt.hash(newPassword, salt);
  await authRepository.updatePassword(idaccount, hashedNew);
  await authService.revokeAllTokens(idaccount);
  logger.info('Password reset successfully', { email: payload.email });
},

// === DELETE ACCOUNT ===
async deleteAccount(idaccount, password) {
  const account = await authRepository.findAccountById(idaccount);
  if (!account) throw Object.assign(new Error('Tài khoản không tồn tại'), { statusCode: 404 });

  const isMatch = await bcrypt.compare(password, account.password);
  if (!isMatch) throw Object.assign(new Error('Mật khẩu không đúng'), { statusCode: 400 });

  await authRepository.softDeleteAccount(idaccount);
  await authService.revokeAllTokens(idaccount);
  logger.info('Account soft-deleted', { idaccount });
},

// === GET PROFILE ===
async getProfile(idaccount) {
  const user = await authRepository.getProfile(idaccount);
  if (!user) throw Object.assign(new Error('Không tìm thấy thông tin người dùng'), { statusCode: 404 });
  return {
    fullname: user.fullname,
    email:    user.email,
    phone:    user.phone,
    address:  user.address,
    location: user.location,
  };
},

// === UPDATE PROFILE ===
async updateProfile(idaccount, data) {
  // Chỉ cho phép sửa các trường: fullname, phone, address, location
  const allowed = {};
  if (data.fullname !== undefined) allowed.fullname = data.fullname;
  if (data.phone    !== undefined) allowed.phone    = data.phone;
  if (data.address  !== undefined) allowed.address  = data.address;
  if (data.location !== undefined) allowed.location = data.location;

  const updated = await authRepository.updateProfile(idaccount, allowed);
  return { fullname: updated.fullname, email: updated.email, phone: updated.phone, address: updated.address, location: updated.location };
},

// === REQUEST EMAIL CHANGE ===
async requestEmailChange(idaccount, newEmail) {
  // Kiểm tra email mới chưa được dùng
  const existing = await authRepository.findAccountByEmail(newEmail);
  if (existing) throw Object.assign(new Error('Email này đã được sử dụng bởi tài khoản khác'), { statusCode: 409 });

  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  const codeHash = hashOtp(otp);
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

  // Lưu email mới vào purpose field để tiện retrieve (format: 'change_email:<newEmail>')
  await authRepository.createOtp(newEmail, codeHash, `change_email`, expiresAt);
  await emailService.sendOtp(newEmail, otp, 'change_email');
  logger.info('Email change OTP sent', { idaccount, newEmail });
},

// === CONFIRM EMAIL CHANGE ===
async confirmEmailChange(idaccount, newEmail, otp) {
  const codeHash = hashOtp(otp);
  const record = await authRepository.findValidOtp(newEmail, codeHash, 'change_email');
  if (!record) throw Object.assign(new Error('Mã OTP không hợp lệ hoặc đã hết hạn'), { statusCode: 400 });

  await authRepository.markOtpUsed(record.id);
  await authRepository.updateEmail(idaccount, newEmail);
  logger.info('Email changed successfully', { idaccount, newEmail });
},
```

---

## 6. Auth Controller — `auth.controller.js`

Thêm các controller methods sau:

```js
async changePassword(req, res) {
  try {
    const { current_password, new_password } = req.body;
    await authService.changePassword(req.user.idaccount, current_password, new_password);
    return ResponseHandler.success(res, null, 'Đổi mật khẩu thành công. Vui lòng đăng nhập lại.');
  } catch (error) {
    return ResponseHandler.error(res, error.message, error.statusCode || 500);
  }
},

async forgotPassword(req, res) {
  try {
    await authService.forgotPassword(req.body.email);
    return ResponseHandler.success(res, null, 'Nếu email tồn tại, mã OTP đã được gửi.');
  } catch (error) {
    return ResponseHandler.error(res, error.message, error.statusCode || 500);
  }
},

async verifyOtp(req, res) {
  try {
    const resetToken = await authService.verifyOtp(req.body.email, req.body.otp);
    return ResponseHandler.success(res, { reset_token: resetToken }, 'OTP hợp lệ');
  } catch (error) {
    return ResponseHandler.error(res, error.message, error.statusCode || 500);
  }
},

async resetPassword(req, res) {
  try {
    await authService.resetPassword(req.body.reset_token, req.body.new_password);
    return ResponseHandler.success(res, null, 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập lại.');
  } catch (error) {
    return ResponseHandler.error(res, error.message, error.statusCode || 500);
  }
},

async deleteAccount(req, res) {
  try {
    await authService.deleteAccount(req.user.idaccount, req.body.password);
    return ResponseHandler.success(res, null, 'Tài khoản đã được xóa.');
  } catch (error) {
    return ResponseHandler.error(res, error.message, error.statusCode || 500);
  }
},

async getProfile(req, res) {
  try {
    const profile = await authService.getProfile(req.user.idaccount);
    return ResponseHandler.success(res, profile, 'Lấy thông tin thành công');
  } catch (error) {
    return ResponseHandler.error(res, error.message, error.statusCode || 500);
  }
},

async updateProfile(req, res) {
  try {
    const updated = await authService.updateProfile(req.user.idaccount, req.body);
    return ResponseHandler.success(res, updated, 'Cập nhật thông tin thành công');
  } catch (error) {
    return ResponseHandler.error(res, error.message, error.statusCode || 500);
  }
},

async requestEmailChange(req, res) {
  try {
    await authService.requestEmailChange(req.user.idaccount, req.body.new_email);
    return ResponseHandler.success(res, null, 'Mã OTP xác nhận đã được gửi đến email mới.');
  } catch (error) {
    return ResponseHandler.error(res, error.message, error.statusCode || 500);
  }
},

async confirmEmailChange(req, res) {
  try {
    await authService.confirmEmailChange(req.user.idaccount, req.body.new_email, req.body.otp);
    return ResponseHandler.success(res, null, 'Cập nhật email thành công.');
  } catch (error) {
    return ResponseHandler.error(res, error.message, error.statusCode || 500);
  }
},
```

---

## 7. Auth Routes — `api/auth.routes.js`

Cập nhật toàn bộ file routes:

```js
const express = require('express');
const router = express.Router();
const authController = require('../modules/auth/auth.controller');
const validate = require('../middleware/validator');
const { authenticate } = require('../middleware/auth');
const {
  loginSchema, refreshSchema, registerSchema,
  changePasswordSchema, forgotPasswordSchema, verifyOtpSchema,
  resetPasswordSchema, deleteAccountSchema, updateProfileSchema,
  requestEmailChangeSchema, confirmEmailChangeSchema,
} = require('../modules/auth/auth.validation');

// --- Public routes (không cần JWT) ---
router.post('/register',         validate(registerSchema),       authController.register);
router.post('/login',            validate(loginSchema),          authController.login);
router.post('/refresh',          validate(refreshSchema),        authController.refresh);
router.post('/forgot-password',  validate(forgotPasswordSchema), authController.forgotPassword);
router.post('/verify-otp',       validate(verifyOtpSchema),      authController.verifyOtp);
router.post('/reset-password',   validate(resetPasswordSchema),  authController.resetPassword);

// --- Protected routes (cần JWT) ---
router.get('/me',                authenticate, authController.me);
router.post('/logout',           authenticate, authController.logout);
router.patch('/change-password', authenticate, validate(changePasswordSchema), authController.changePassword);
router.delete('/account',        authenticate, validate(deleteAccountSchema),  authController.deleteAccount);
router.get('/profile',           authenticate, authController.getProfile);
router.patch('/profile',         authenticate, validate(updateProfileSchema),  authController.updateProfile);
router.post('/profile/request-email-change',  authenticate, validate(requestEmailChangeSchema),  authController.requestEmailChange);
router.patch('/profile/confirm-email-change', authenticate, validate(confirmEmailChangeSchema), authController.confirmEmailChange);

module.exports = router;
```

---

## 8. Validation Schemas — `auth.validation.js`

Thêm các schema sau:

```js
const changePasswordSchema = {
  current_password: { required: true, type: 'string', minLength: 6, maxLength: 100 },
  new_password:     { required: true, type: 'string', minLength: 8, maxLength: 100 },
};

const forgotPasswordSchema = {
  email: { required: true, type: 'string', minLength: 5, maxLength: 100 },
};

const verifyOtpSchema = {
  email: { required: true, type: 'string', minLength: 5, maxLength: 100 },
  otp:   { required: true, type: 'string', minLength: 6, maxLength: 6 },
};

const resetPasswordSchema = {
  reset_token:  { required: true, type: 'string', minLength: 10 },
  new_password: { required: true, type: 'string', minLength: 8, maxLength: 100 },
};

const deleteAccountSchema = {
  password: { required: true, type: 'string', minLength: 6, maxLength: 100 },
};

const updateProfileSchema = {
  fullname: { required: false, type: 'string', minLength: 2, maxLength: 100 },
  phone:    { required: false, type: 'string', minLength: 8, maxLength: 15 },
  address:  { required: false, type: 'string', maxLength: 255 },
  location: { required: false, type: 'string', maxLength: 5 },
};

const requestEmailChangeSchema = {
  new_email: { required: true, type: 'string', minLength: 5, maxLength: 100 },
};

const confirmEmailChangeSchema = {
  new_email: { required: true, type: 'string', minLength: 5, maxLength: 100 },
  otp:       { required: true, type: 'string', minLength: 6, maxLength: 6 },
};
```

---

## 9. API Reference (dành cho Client-app tích hợp)

### Base URL: `http://localhost:3000/api/auth`

---

### POST `/forgot-password`
**Auth:** Không cần  
**Body:**
```json
{ "email": "user@example.com" }
```
**Response 200** (luôn trả 200 dù email có tồn tại hay không):
```json
{ "success": true, "message": "Nếu email tồn tại, mã OTP đã được gửi." }
```

---

### POST `/verify-otp`
**Auth:** Không cần  
**Body:**
```json
{ "email": "user@example.com", "otp": "123456" }
```
**Response 200:**
```json
{ "success": true, "data": { "reset_token": "<JWT 15 phút>" }, "message": "OTP hợp lệ" }
```
**Response 400:** OTP sai hoặc hết hạn

---

### POST `/reset-password`
**Auth:** Không cần  
**Body:**
```json
{ "reset_token": "<JWT từ verify-otp>", "new_password": "NewPassword123" }
```
**Response 200:**
```json
{ "success": true, "message": "Đặt lại mật khẩu thành công. Vui lòng đăng nhập lại." }
```

---

### PATCH `/change-password`
**Auth:** JWT (Bearer token)  
**Body:**
```json
{ "current_password": "OldPass123", "new_password": "NewPass456" }
```
**Response 200:**
```json
{ "success": true, "message": "Đổi mật khẩu thành công. Vui lòng đăng nhập lại." }
```
**Lưu ý:** Server sẽ revoke toàn bộ refresh token → client phải xóa local token và redirect về login.

---

### DELETE `/account`
**Auth:** JWT (Bearer token)  
**Body:**
```json
{ "password": "CurrentPassword123" }
```
**Response 200:**
```json
{ "success": true, "message": "Tài khoản đã được xóa." }
```
**Lưu ý:** Tài khoản bị soft-delete (`status = 'Deleted'`). Không thể đăng nhập lại.

---

### GET `/profile`
**Auth:** JWT (Bearer token)  
**Response 200:**
```json
{
  "success": true,
  "data": {
    "fullname": "Nguyễn Văn A",
    "email": "user@example.com",
    "phone": "0901234567",
    "address": "123 Đường ABC",
    "location": "HCM"
  }
}
```

---

### PATCH `/profile`
**Auth:** JWT (Bearer token)  
**Body** (tất cả optional, chỉ gửi trường cần sửa):
```json
{
  "fullname": "Nguyễn Văn B",
  "phone": "0987654321",
  "address": "456 Đường XYZ",
  "location": "HN"
}
```
**Lưu ý:** Trường `email` **không thể sửa qua endpoint này**. Phải dùng luồng đổi email riêng.

---

### POST `/profile/request-email-change`
**Auth:** JWT (Bearer token)  
**Body:**
```json
{ "new_email": "newemail@example.com" }
```
**Response 200:**
```json
{ "success": true, "message": "Mã OTP xác nhận đã được gửi đến email mới." }
```
**Lưu ý:** OTP được gửi đến `new_email` (không phải email cũ).

---

### PATCH `/profile/confirm-email-change`
**Auth:** JWT (Bearer token)  
**Body:**
```json
{ "new_email": "newemail@example.com", "otp": "654321" }
```
**Response 200:**
```json
{ "success": true, "message": "Cập nhật email thành công." }
```

---

## 10. Checklist hoàn thành cho Backend

- [ ] `prisma migrate dev` thành công với bảng `otp_code`
- [ ] CHECK constraint `account.status` nhận thêm `'Deleted'`
- [ ] `npm install nodemailer` thành công
- [ ] `.env` có đủ biến `SMTP_*`
- [ ] `core/email.service.js` gửi mail thực tế (test bằng email thật)
- [ ] Tất cả 9 endpoint mới hoạt động đúng
- [ ] OTP hết hạn sau 10 phút, không dùng lại được sau khi verify
- [ ] Đổi/reset mật khẩu → revoke toàn bộ session
- [ ] Xóa tài khoản → `status = 'Deleted'`, không thể đăng nhập lại
