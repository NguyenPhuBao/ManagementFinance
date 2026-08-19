# Backend Guide: Xóa tài khoản với thời gian ân hạn 30 ngày

**Ngày:** 2026-08-18 | **Yêu cầu từ:** Client-app team  
**Phạm vi:** Thay đổi logic `DELETE /api/auth/account` + thêm endpoint `POST /api/auth/cancel-delete`  
**Trạng thái:** ✅ **ĐÃ IMPLEMENT** — Backend (2026-08-18) + Client-app (2026-08-19)

---

## 1. Mô tả tính năng

Thay vì xóa ngay (`status = 'Deleted'`), khi người dùng yêu cầu xóa tài khoản:

- Đặt `status = 'PendingDelete'` và ghi lại `scheduled_delete_at = now + 30 ngày`
- Revoke tất cả token (đăng xuất ngay)
- Trong 30 ngày: nếu người dùng **đăng nhập lại** → tài khoản được **khôi phục tự động** (`status = 'Active'`, xóa `scheduled_delete_at`)
- Sau 30 ngày: từ chối đăng nhập với thông báo "Hết thời gian khôi phục"

---

## 2. Thay đổi Database — `prisma/schema.prisma`

Thêm trường mới và mở rộng `status` vào model `account`:

```prisma
model account {
  idaccount           Int       @id @default(autoincrement())
  username            String    @unique @db.VarChar(50)
  password            String    @db.VarChar(255)
  status              String    @default("Active") @db.VarChar(20)  // Mở rộng từ VarChar(10) lên VarChar(20)
  scheduled_delete_at DateTime? @db.Timestamp(6)                    // THÊM MỚI
  created_at          DateTime? @default(now()) @db.Timestamp(6)
  updated_at          DateTime? @default(now()) @db.Timestamp(6)
  // ... các relation giữ nguyên
}
```

Sau khi chỉnh sửa schema, chạy:

```bash
npx prisma db push
```

Các giá trị hợp lệ của `status`: `'Active'` | `'Inactive'` | `'PendingDelete'` | `'Deleted'`

---

## 3. Thay đổi `auth.repository.js`

### 3.1 Thay `softDeleteAccount` → `scheduleDeletion`

```js
// THAY THẾ method softDeleteAccount hiện tại bằng:
async scheduleDeletion(idaccount) {
  const scheduledAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // +30 ngày
  return prisma.account.update({
    where: { idaccount },
    data: {
      status: 'PendingDelete',
      scheduled_delete_at: scheduledAt,
      updated_at: new Date(),
    },
  });
},
```

### 3.2 Thêm `cancelDeletion`

```js
async cancelDeletion(idaccount) {
  return prisma.account.update({
    where: { idaccount },
    data: {
      status: 'Active',
      scheduled_delete_at: null,
      updated_at: new Date(),
    },
  });
},
```

---

## 4. Thay đổi `auth.service.js`

### 4.1 Sửa `deleteAccount` — dùng `scheduleDeletion`

```js
async deleteAccount(idaccount, password) {
  const account = await authRepository.findAccountById(idaccount);
  if (!account) throw Object.assign(new Error("Tài khoản không tồn tại"), { statusCode: 404 });

  const isMatch = await bcrypt.compare(password, account.password);
  if (!isMatch) throw Object.assign(new Error("Mật khẩu không đúng"), { statusCode: 400 });

  // THAY: softDeleteAccount → scheduleDeletion
  await authRepository.scheduleDeletion(idaccount);
  await this.revokeAllTokens(idaccount);
  logger.info("Account scheduled for deletion (30 days grace period)", { idaccount });
},
```

### 4.2 Sửa `login` — xử lý `PendingDelete`

Thay thế dòng `if (account.status !== "Active")` hiện tại bằng đoạn sau:

```js
// Xử lý PendingDelete TRƯỚC khi check Active
if (account.status === 'PendingDelete') {
  if (account.scheduled_delete_at && account.scheduled_delete_at > new Date()) {
    // Còn trong 30 ngày → cho đăng nhập, tự động hủy yêu cầu xóa
    const isMatch = await bcrypt.compare(password, account.password);
    if (!isMatch) throw Object.assign(new Error("Sai tai khoan hoac mat khau"), { statusCode: 401 });

    await authRepository.cancelDeletion(account.idaccount);

    const payload = {
      idaccount: account.idaccount,
      username: account.username,
      idrole: account.idrole,
      rolename: account.role.rolename,
    };
    const { accessToken, refreshToken } = generateTokens(payload, account.idrole);
    await saveRefreshToken(refreshToken, payload, req);
    logger.info("PendingDelete account recovered on login", { username: account.username });

    return {
      accessToken,
      refreshToken,
      pendingDeleteCancelled: true,   // ← Client-app dùng field này để hiển thị thông báo
      user: {
        idaccount: account.idaccount,
        username: account.username,
        rolename: account.role.rolename,
        fullname: account.User ? account.User.fullname : "",
        email: account.User ? account.User.email : "",
      },
    };
  } else {
    // Hết 30 ngày → từ chối đăng nhập
    throw Object.assign(
      new Error("Tài khoản đã hết thời gian khôi phục (30 ngày). Vui lòng liên hệ hỗ trợ."),
      { statusCode: 403 }
    );
  }
}
if (account.status === 'Deleted') {
  throw Object.assign(new Error("Tài khoản đã bị xóa vĩnh viễn"), { statusCode: 403 });
}
if (account.status !== 'Active') {
  throw Object.assign(new Error("Tai khoan da bi vo hieu hoa"), { statusCode: 403 });
}
// ... (giữ nguyên phần còn lại)
```

Thêm `pendingDeleteCancelled: false` vào return object của login thông thường:

```js
return {
  accessToken,
  refreshToken,
  pendingDeleteCancelled: false,   // ← Luôn trả field này
  user: { ... }
};
```

### 4.3 Thêm method `cancelDeletion` vào service

```js
async cancelDeletion(idaccount) {
  const account = await authRepository.findAccountById(idaccount);
  if (!account) throw Object.assign(new Error("Tài khoản không tồn tại"), { statusCode: 404 });

  if (account.status !== 'PendingDelete') {
    throw Object.assign(new Error("Tài khoản không ở trạng thái chờ xóa"), { statusCode: 400 });
  }
  if (account.scheduled_delete_at && account.scheduled_delete_at <= new Date()) {
    throw Object.assign(new Error("Đã hết thời gian khôi phục (30 ngày)"), { statusCode: 403 });
  }

  await authRepository.cancelDeletion(idaccount);
  logger.info("Account deletion cancelled by user", { idaccount });
},
```

---

## 5. Thêm Controller + Route mới

### 5.1 Thêm vào `auth.controller.js`

```js
async cancelDelete(req, res) {
  try {
    await authService.cancelDeletion(req.user.idaccount);
    res.json({ message: "Yêu cầu xóa tài khoản đã được hủy thành công" });
  } catch (err) {
    res.status(err.statusCode || 500).json({ message: err.message });
  }
},
```

### 5.2 Thêm vào `auth.routes.js`

```js
// Sau dòng: router.delete('/account', authenticate, ...)
router.post('/cancel-delete', authenticate, authController.cancelDelete);
```

---

## 6. Tóm tắt các thay đổi

| File | Thay đổi |
|------|---------|
| `prisma/schema.prisma` | Thêm `scheduled_delete_at DateTime?`, mở rộng `status` VarChar(20) |
| `auth.repository.js` | `softDeleteAccount` → `scheduleDeletion` + thêm `cancelDeletion` |
| `auth.service.js` | `deleteAccount` gọi `scheduleDeletion`, `login` xử lý `PendingDelete`, thêm `cancelDeletion` |
| `auth.controller.js` | Thêm handler `cancelDelete` |
| `auth.routes.js` | Thêm `POST /cancel-delete` (yêu cầu authenticate) |

---

## 7. Response format Client-app cần

### `POST /api/auth/login` — khi tài khoản được khôi phục

```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "pendingDeleteCancelled": true,
  "user": { "idaccount": 1, "username": "...", ... }
}
```

> **Quan trọng:** Luôn trả `pendingDeleteCancelled` (true/false) trong **mọi** response login thành công.

### `POST /api/auth/cancel-delete` — hủy xóa thủ công từ Settings

```json
{ "message": "Yêu cầu xóa tài khoản đã được hủy thành công" }
```

### `DELETE /api/auth/account` — đặt lịch xóa thành công (HTTP 200)

```json
{ "message": "Tài khoản của bạn sẽ bị xóa sau 30 ngày. Đăng nhập lại để hủy yêu cầu." }
```
