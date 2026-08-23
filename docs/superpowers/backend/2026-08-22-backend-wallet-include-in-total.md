# Yêu cầu Backend: Thêm cột `include_in_total` vào bảng `wallet`

**Ngày:** 2026-08-22  
**Phạm vi:** Backend (PostgreSQL + Prisma + Sync API)  
**Ưu tiên:** Medium  
**Từ:** Frontend Team

---

## 1. Bối cảnh

Frontend đã triển khai tính năng "Tính vào tổng tài sản" cho ví ở phía client:
- Cột `include_in_total BOOLEAN DEFAULT TRUE` đã được thêm vào SQLite local (Drift)
- `getTotalBalance()` đã lọc chỉ tính ví có `includeInTotal = true`
- Switch UI trong màn hình thêm/sửa ví đã được nối vào logic lưu DB

**Backend cần thêm cột tương ứng để đồng bộ được trường này lên server.**

---

## 2. Việc Backend cần làm

### 2.1 SQL Migration — Chạy trên PostgreSQL

```sql
-- Migration: Thêm cột include_in_total vào bảng wallet
ALTER TABLE wallet
  ADD COLUMN IF NOT EXISTS include_in_total BOOLEAN NOT NULL DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_wallet_include_in_total
  ON wallet (idaccount, include_in_total);

COMMENT ON COLUMN wallet.include_in_total
  IS 'Nếu TRUE: số dư ví được cộng vào tổng tài sản hiển thị. Mặc định TRUE.';
```

### 2.2 Prisma Schema — Thêm field vào model `wallet`

```prisma
model wallet {
  id          String        @id @db.VarChar(36)
  idaccount   Int
  name        String        @db.VarChar(100)
  type        String        @default("cash") @db.VarChar(20)
  balance     Decimal       @default(0) @db.Decimal(15, 2)
  currency    String        @default("VND") @db.VarChar(10)
  icon        String?       @default("wallet") @db.VarChar(50)
  colour      String?       @default("#4CAF50") @db.VarChar(10)
  is_default       Boolean?  @default(false)
  is_deleted       Boolean?  @default(false)
  include_in_total Boolean   @default(true)   // ← THÊM MỚI
  updated_at  DateTime      @db.Timestamp(6)
  created_at  DateTime?     @default(now()) @db.Timestamp(6)
  transaction transaction[]
  account     account       @relation(...)
  ...
}
```

Sau khi sửa schema, chạy:
```bash
npx prisma migrate dev --name add_wallet_include_in_total
```

### 2.3 Sync Repository — Không cần thay đổi

`sync.repository.js` → `upsertWallet(data)` đã dùng `prisma.wallet.create({ data })` — pass-through toàn bộ object từ client. Khi client gửi `include_in_total` lên, nó sẽ được lưu tự động.

Tuy nhiên, cần **kiểm tra** `getWalletsByAccount` có trả về cột `include_in_total` trong response không (Prisma mặc định `select *` nên OK, nhưng nếu có `select` tường minh thì cần thêm).

---

## 3. Mapping tên field

| Client (Dart/Drift) | Server (PostgreSQL/Prisma) | Giá trị |
|---|---|---|
| `includeInTotal` | `include_in_total` | `true` / `false` |
| Default | Default | `TRUE` |

> **Lưu ý:** SyncEngine của client sẽ serialize `includeInTotal` → `include_in_total` (snake_case) khi gửi lên server. Backend nhận đúng tên cột.

---

## 4. Hành vi mong đợi sau khi sync

| Client action | Backend lưu |
|---|---|
| Tạo ví mới, switch ON | `include_in_total = true` |
| Tạo ví mới, switch OFF | `include_in_total = false` |
| Ví cũ (trước khi có tính năng) | `include_in_total = true` (default) |
| Chỉnh sửa ví, toggle switch | Cập nhật `include_in_total` khi sync |

---

## 5. Không ảnh hưởng đến

- Logic transaction
- Logic auth/user
- Các bảng khác
