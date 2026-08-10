# Backend Progress — FlowMoney NestJS

> Cập nhật lần cuối: 2026-08-10  
> Người phụ trách: _(tên thành viên backend)_  
> Spec chi tiết: [`2026-08-10-backend-sync-spec.md`](./2026-08-10-backend-sync-spec.md)

---

## 📊 Tổng Quan Tiến Độ

| Task | Tên | Trạng thái | Ngày hoàn thành |
|---|---|---|---|
| **B0** | Auth API (login, register, refresh token) | ✅ HOÀN THÀNH | — |
| **B1** | Prisma models: Wallet, Transaction, Budget, Bill, Goal | 🔴 CHƯA LÀM | — |
| **B2** | `POST /api/sync/push` — nhận batch từ client | 🔴 CHƯA LÀM | — |
| **B3** | `GET /api/sync/pull` — trả data mới cho client | 🔴 CHƯA LÀM | — |
| **B4** | Conflict resolution (Last-Write-Wins) | 🔴 CHƯA LÀM | — |
| **B5** | `GET /api/sync/status` | 🟡 Nice-to-have | — |
| **B6** | Default categories endpoint | 🟡 Nice-to-have | — |
| **B7** | ForgotPassword endpoint | 🔴 CHƯA LÀM | — |

---

## ✅ B0: Auth API (Đã có sẵn)

### Đã hoàn thành
- `POST /auth/login` — trả về `accessToken` + `refreshToken`
- `POST /auth/register` — tạo account + user
- `POST /auth/refresh` — đổi refresh token mới
- JWT Guard bảo vệ các route cần auth
- `refreshtoken` table với các index tối ưu

---

## 🔴 B1: Prisma Models (VIỆC ĐẦU TIÊN)

**Spec:** [Section 6 — Prisma Schema](./2026-08-10-backend-sync-spec.md#6-prisma-schema-để-thêm-vào-schemaprisma)

### Cần làm

Thêm 5 models vào `prisma/schema.prisma`:

```
Wallet       — ví tài chính (UUID id do client tạo)
Transaction  — giao dịch thu/chi/transfer
Budget       — ngân sách theo category + kỳ
Bill         — hóa đơn định kỳ
Goal         — mục tiêu tiết kiệm
```

> ⚠️ Lưu ý quan trọng: `id` của tất cả bảng là **VARCHAR(36) UUID**, không phải auto-increment.  
> Client tự tạo UUID trước khi gửi lên server.

### Checklist
- [ ] Copy models từ spec vào `schema.prisma`
- [ ] Thêm relation ngược vào model `account` (account có nhiều wallet, transaction...)  
- [ ] Chạy `npx prisma migrate dev --name add_sync_tables`
- [ ] Chạy `npx prisma generate`
- [ ] Verify bảng xuất hiện trong DB

### Lệnh chạy
```bash
cd src/Backend
npx prisma migrate dev --name add_sync_tables
npx prisma studio   # kiểm tra bảng trực quan
```

---

## 🔴 B2: POST /api/sync/push

**Spec:** [Section 3.1](./2026-08-10-backend-sync-spec.md#31-post-apisyncpush--client-gửi-dữ-liệu-local-lên-server)

### Mô tả
Client gửi batch các thao tác (create/update/delete) lên server sau khi có mạng.

### Request body mẫu
```json
{
  "clientId": "device-fingerprint",
  "pushedAt": "2026-08-10T10:30:00.000Z",
  "operations": [
    {
      "localId": "uuid-của-record",
      "entity": "wallet",
      "operation": "create",
      "payload": { "id": "uuid", "name": "Tiền mặt", ... }
    }
  ]
}
```

**`entity`:** `wallet` | `transaction` | `category` | `budget` | `bill` | `goal`  
**`operation`:** `create` | `update` | `delete`

### Response mẫu
```json
{
  "syncedAt": "2026-08-10T10:30:05.000Z",
  "results": [
    { "localId": "uuid", "status": "synced" },
    { "localId": "uuid2", "status": "conflict", "serverRecord": { ... } }
  ],
  "summary": { "total": 2, "synced": 1, "conflicts": 1, "errors": 0 }
}
```

### Checklist
- [ ] Tạo `src/sync/sync.module.ts`
- [ ] Tạo `src/sync/sync.controller.ts` với `@Post('push')`
- [ ] Tạo `src/sync/sync.service.ts` với method `processPush()`
- [ ] Tạo `src/sync/dto/push-sync.dto.ts` (validate request)
- [ ] Bảo vệ bằng `@UseGuards(JwtAuthGuard)`
- [ ] Validate `idaccount` trong payload == `idaccount` của token → 403 nếu không khớp
- [ ] Xử lý từng entity trong `operations[]` bằng switch-case
- [ ] Upsert vào DB (insert nếu chưa có, update nếu đã có)
- [ ] Test với Postman/Insomnia

---

## 🔴 B3: GET /api/sync/pull

**Spec:** [Section 3.2](./2026-08-10-backend-sync-spec.md#32-get-apisyncpullsincetimestamp--kéo-data-mới-từ-server)

### Mô tả
Client gọi sau khi login hoặc khi cần lấy data từ thiết bị/session khác.

### Query params
- `since` (required): ISO timestamp — chỉ lấy records có `updated_at > since`
- `entities` (optional): comma-separated, ví dụ `wallet,transaction`

### Response mẫu
```json
{
  "pulledAt": "2026-08-10T10:30:05.000Z",
  "hasMore": false,
  "data": {
    "wallets": [ { "id": "uuid", "name": "Tiền mặt", ... } ],
    "transactions": [],
    "categories": [],
    "budgets": [],
    "bills": [],
    "goals": []
  }
}
```

### Checklist
- [ ] Thêm `@Get('pull')` vào `sync.controller.ts`
- [ ] Validate query param `since` là ISO datetime hợp lệ
- [ ] Query DB: `WHERE idaccount = :id AND updated_at > :since`
- [ ] Phân trang nếu data lớn (`hasMore: true`)
- [ ] Test với `since=1970-01-01` để lấy toàn bộ

---

## 🔴 B4: Conflict Resolution

**Spec:** [Section 4.1](./2026-08-10-backend-sync-spec.md#41-conflict-resolution-last-write-wins)

### Chiến lược: Last-Write-Wins (LWW)

```
Client gửi record có updatedAt = T_client
Server có record với updatedAt = T_server

T_client > T_server  →  Ghi đè (client thắng)
T_client < T_server  →  Giữ bản server, trả về conflict + serverRecord
T_client = T_server  →  Coi là synced (idempotent)
```

### Checklist
- [ ] Implement hàm `resolveConflict(clientRecord, serverRecord)` trong `sync.service.ts`
- [ ] Khi conflict: không ghi đè, trả về `status: "conflict"` + `serverRecord`
- [ ] Client (Flutter) sẽ tự xử lý — cập nhật local theo server record khi nhận về

---

## 🟡 B5: GET /api/sync/status

Trả về số records pending của user (để debug, không bắt buộc cho MVP).

```json
{
  "idaccount": 1,
  "lastSyncedAt": "2026-08-10T10:30:05.000Z",
  "pendingCount": 0
}
```

---

## 🟡 B6: Default Categories Endpoint

Client đã seed sẵn 18 danh mục mặc định vào local SQLite (không cần sync).  
Endpoint này chỉ cần khi muốn đồng bộ danh mục từ server thay vì hardcode.

**Spec:** [Section 4.3](./2026-08-10-backend-sync-spec.md#43-dữ-liệu-category-mặc-định)

---

## 🔴 B7: ForgotPassword

Client đã có UI sẵn (`ForgotPasswordPage`), chỉ thiếu backend endpoint.

### Cần implement
- `POST /auth/forgot-password` — nhận `email`, gửi reset link/OTP
- `POST /auth/reset-password` — nhận token + password mới

---

## 📋 Thứ Tự Implement Khuyến Nghị

```
B1 (Prisma schema + migrate)
  │
  └─► B2 (POST /sync/push)
        │
        └─► B4 (Conflict resolution)  ←── Làm cùng B2
              │
              └─► B3 (GET /sync/pull)
                    │
                    └─► B5, B6, B7 (theo nhu cầu)
```

**MVP tối thiểu để client hoạt động đầy đủ:** B1 + B2 + B4

---

## 🔗 Tài Liệu Tham Khảo

| Tài liệu | Mô tả |
|---|---|
| [`2026-08-10-backend-sync-spec.md`](./2026-08-10-backend-sync-spec.md) | Spec đầy đủ: schema, API, request/response |
| `src/Backend/prisma/schema.prisma` | Schema hiện tại của backend |
| `src/Client-app/lib/core/sync/sync_engine.dart` | Cách client gửi batch |
| `src/Client-app/lib/core/sync/sync_models.dart` | Data models phía client |
