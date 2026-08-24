# Yêu cầu Backend: Thêm cột `wallet_id` vào bảng `goal`

**Ngày:** 2026-08-23  
**Phạm vi:** Backend (PostgreSQL + Prisma + Sync API)  
**Ưu tiên:** Medium  
**Từ:** Frontend Team  

---

## 1. Bối cảnh

### Nghiệp vụ

Tính năng **Mục tiêu tiết kiệm** cho phép người dùng nạp tiền vào một mục tiêu (goal). Khi nạp tiền:

1. Tiền được **trừ từ ví nguồn** (source wallet) → tạo giao dịch `chi`
2. Tiền được **cộng vào ví tiết kiệm đích** (target/savings wallet) → tạo giao dịch `thu`
3. `currentAmount` của goal tăng lên

**`wallet_id`** lưu ví tiết kiệm đích của một goal — ví mà tiền tích lũy sẽ được chuyển vào mỗi lần người dùng nạp. Giá trị này được ghi lần đầu khi người dùng nạp tiền vào goal và ví đích được xác định (tự động hoặc người dùng chọn).

### Hiện trạng

- **Client-app (SQLite/Drift):** Đã có cột `wallet_id TEXT nullable` trong bảng `goals` từ 2026-08-12.
- **Backend (PostgreSQL):** Bảng `goal` **chưa có** cột `wallet_id`.
- **Hậu quả:** Khi sync, field `wallet_id` từ client bị bỏ qua và mất — nếu người dùng đăng nhập thiết bị khác, goal sẽ không biết ví đích là ví nào, dẫn đến phải chọn lại ví mỗi lần nạp.

---

## 2. Việc Backend cần làm

### 2.1 SQL Migration — Chạy trên PostgreSQL

```sql
-- Migration: Thêm cột wallet_id vào bảng goal
ALTER TABLE goal
  ADD COLUMN IF NOT EXISTS wallet_id VARCHAR(36) NULL
    REFERENCES wallet(id) ON DELETE SET NULL ON UPDATE NO ACTION;

CREATE INDEX IF NOT EXISTS idx_goal_wallet
  ON goal (wallet_id)
  WHERE wallet_id IS NOT NULL;

COMMENT ON COLUMN goal.wallet_id
  IS 'UUID của ví tiết kiệm đích. NULL nếu chưa liên kết. Được gán lần đầu khi user nạp tiền vào goal.';
```

> **Lưu ý `ON DELETE SET NULL`:** Nếu ví bị xóa, `wallet_id` của goal về NULL thay vì xóa goal theo.

### 2.2 Prisma Schema — Thêm field vào model `goal`

```prisma
model goal {
  id             String    @id @db.VarChar(36)
  idaccount      Int
  name           String    @db.VarChar(100)
  target_amount  Decimal   @db.Decimal(15, 2)
  current_amount Decimal?  @default(0) @db.Decimal(15, 2)
  target_date    DateTime  @db.Timestamp(6)
  wallet_id      String?   @db.VarChar(36)              // <- THÊM MỚI (nullable)
  icon           String?   @default("flag") @db.VarChar(50)
  colour         String?   @default("#4CAF50") @db.VarChar(10)
  note           String?   @default("")
  is_completed   Boolean?  @default(false)
  is_deleted     Boolean?  @default(false)
  updated_at     DateTime  @db.Timestamp(6)
  created_at     DateTime? @default(now()) @db.Timestamp(6)

  account account @relation(fields: [idaccount], references: [idaccount], onDelete: Cascade, onUpdate: NoAction, map: "fk_goal_account")
  wallet  wallet? @relation(fields: [wallet_id], references: [id], onDelete: SetNull, onUpdate: NoAction, map: "fk_goal_wallet")  // <- THÊM MỚI

  @@index([idaccount], map: "idx_goal_account")
  @@index([wallet_id], map: "idx_goal_wallet")           // <- THÊM MỚI
}
```

Thêm relation ngược vào model `wallet`:
```prisma
model wallet {
  // ... các field hiện có ...
  goal  goal[]   // <- THÊM quan hệ ngược
}
```

Sau khi sửa schema, chạy:
```bash
npx prisma migrate dev --name add_goal_wallet_id
npx prisma generate
```

### 2.3 Sync Repository — Kiểm tra upsert

`upsertGoal(data)` đang dùng pass-through toàn bộ object từ client — `wallet_id` sẽ được lưu tự động.

Cần kiểm tra `getGoalsByAccount` (dùng trong GET /sync/pull) có trả về cột `wallet_id` không. Nếu có `select` tường minh thì bổ sung field này.

---

## 3. Mapping tên field

| Client (Dart/Drift) | Server (PostgreSQL/Prisma) | Kiểu | Giá trị |
|---|---|---|---|
| `walletId` | `wallet_id` | `String?` / `VARCHAR(36) NULL` | UUID của ví hoặc null |

SyncEngine của client serialize `walletId` -> `wallet_id` (camelCase -> snake_case) khi gửi lên server.

---

## 4. Hành vi mong đợi sau khi sync

| Tình huống | Client gửi | Backend lưu |
|---|---|---|
| Tạo goal mới, chưa nạp tiền lần nào | `wallet_id: null` | `wallet_id = NULL` |
| Nạp tiền lần đầu, ví đích được xác định | `wallet_id: "uuid-ví"` | `wallet_id = "uuid-ví"` |
| Nạp tiền lần 2+ (đã có ví đích) | `wallet_id: "uuid-ví"` | Giữ nguyên hoặc update (LWW) |
| Ví đích bị xóa | Không gửi gì thêm | `wallet_id = NULL` (SET NULL) |
| Pull goal sang thiết bị khác | Nhận `wallet_id` từ backend | Nạp tiền tiếp vào đúng ví cũ |

---

## 5. Không ảnh hưởng đến

- Logic Auth / User
- Các bảng khác (wallet, transaction, budget, bill, category)
- Tính toán `current_amount` (không thay đổi)
- Tính năng giao dịch tích lũy (vẫn tạo transaction chi/thu như cũ)
