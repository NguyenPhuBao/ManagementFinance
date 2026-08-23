# Backend Sync Specification — FlowMoney

> Tạo: 2026-08-10  
> Trạng thái: **📋 CHƯA IMPLEMENT — Xem `PROGRESS-BACKEND.md` để theo dõi tiến độ**

---

## 1. Tổng Quan Kiến Trúc Sync

### Mô hình: Offline-First / Client-Led Sync

```
[Flutter Client — SQLite]  ──POST /api/sync/push──►  [NestJS Backend — PostgreSQL]
                           ◄──GET  /api/sync/pull──
```

**Nguyên tắc thiết kế:**

| Nguyên tắc | Mô tả |
|---|---|
| **Client tự tạo UUID** | Tất cả records có `id` là UUID v4 do Flutter tạo trước khi gửi lên |
| **Last-Write-Wins** | Resolve conflict bằng `updatedAt` — bản nào mới hơn thắng |
| **Soft delete** | Không xóa cứng — chỉ set `is_deleted = true` |
| **Batch sync** | Gom nhiều thay đổi gửi 1 lần — không gửi từng request |
| **Idempotent** | Gửi cùng record nhiều lần không gây lỗi |

---

## 2. Database Schema Cần Thêm (PostgreSQL)

> Backend hiện có: `account`, `user`, `category`, `role`, `refreshtoken`, `auditlog`
>
> Cần thêm 5 bảng mới:

### 2.1 `wallet`

```sql
CREATE TABLE wallet (
    id          VARCHAR(36)   PRIMARY KEY,        -- UUID do client tạo
    idaccount   INT           NOT NULL,
    name        VARCHAR(100)  NOT NULL,
    type        VARCHAR(20)   NOT NULL DEFAULT 'cash',
    -- 'cash' | 'bank' | 'ewallet' | 'investment' | 'debt'
    balance     DECIMAL(15,2) NOT NULL DEFAULT 0,
    currency    VARCHAR(10)   NOT NULL DEFAULT 'VND',
    icon        VARCHAR(50)   DEFAULT 'wallet',
    colour      VARCHAR(10)   DEFAULT '#4CAF50',
    is_default  BOOLEAN       DEFAULT false,
    is_deleted  BOOLEAN       DEFAULT false,
    updated_at  TIMESTAMP     NOT NULL,
    created_at  TIMESTAMP     DEFAULT NOW(),

    CONSTRAINT fk_wallet_account
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE
);

CREATE INDEX idx_wallet_account ON wallet(idaccount);
CREATE INDEX idx_wallet_updated ON wallet(updated_at);
```

### 2.2 `transaction`

```sql
CREATE TABLE transaction (
    id          VARCHAR(36)   PRIMARY KEY,        -- UUID do client tạo
    idaccount   INT           NOT NULL,
    wallet_id   VARCHAR(36)   NOT NULL,
    category_id VARCHAR(36)   NULL,              -- null cho transfer/adjustment
    amount      DECIMAL(15,2) NOT NULL,
    type        VARCHAR(20)   NOT NULL,
    -- 'thu' | 'chi' | 'transfer' | 'adjustment'
    note        TEXT          DEFAULT '',
    date        TIMESTAMP     NOT NULL,
    images      TEXT          DEFAULT '[]',       -- JSON array string
    is_deleted  BOOLEAN       DEFAULT false,
    updated_at  TIMESTAMP     NOT NULL,
    created_at  TIMESTAMP     DEFAULT NOW(),

    CONSTRAINT fk_transaction_account
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE,
    CONSTRAINT fk_transaction_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallet(id) ON DELETE CASCADE
);

CREATE INDEX idx_transaction_account ON transaction(idaccount);
CREATE INDEX idx_transaction_wallet  ON transaction(wallet_id);
CREATE INDEX idx_transaction_date    ON transaction(date);
CREATE INDEX idx_transaction_updated ON transaction(updated_at);
```

### 2.3 `budget`

```sql
CREATE TABLE budget (
    id          VARCHAR(36)   PRIMARY KEY,
    idaccount   INT           NOT NULL,
    category_id VARCHAR(36)   NULL,
    amount      DECIMAL(15,2) NOT NULL,
    period      VARCHAR(20)   NOT NULL DEFAULT 'monthly',
    -- 'weekly' | 'monthly' | 'yearly'
    start_date  TIMESTAMP     NOT NULL,
    end_date    TIMESTAMP     NULL,
    note        TEXT          DEFAULT '',
    is_deleted  BOOLEAN       DEFAULT false,
    updated_at  TIMESTAMP     NOT NULL,
    created_at  TIMESTAMP     DEFAULT NOW(),

    CONSTRAINT fk_budget_account
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE
);

CREATE INDEX idx_budget_account ON budget(idaccount);
```

### 2.4 `bill`

```sql
CREATE TABLE bill (
    id          VARCHAR(36)   PRIMARY KEY,
    idaccount   INT           NOT NULL,
    name        VARCHAR(100)  NOT NULL,
    amount      DECIMAL(15,2) NOT NULL,
    due_date    TIMESTAMP     NOT NULL,
    is_paid     BOOLEAN       DEFAULT false,
    recurrence  VARCHAR(20)   DEFAULT 'monthly',
    -- 'once' | 'weekly' | 'monthly' | 'yearly'
    icon        VARCHAR(50)   DEFAULT 'receipt',
    colour      VARCHAR(10)   DEFAULT '#4CAF50',
    note        TEXT          DEFAULT '',
    is_deleted  BOOLEAN       DEFAULT false,
    updated_at  TIMESTAMP     NOT NULL,
    created_at  TIMESTAMP     DEFAULT NOW(),

    CONSTRAINT fk_bill_account
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE
);

CREATE INDEX idx_bill_account ON bill(idaccount);
```

### 2.5 `goal`

```sql
CREATE TABLE goal (
    id              VARCHAR(36)   PRIMARY KEY,
    idaccount       INT           NOT NULL,
    name            VARCHAR(100)  NOT NULL,
    target_amount   DECIMAL(15,2) NOT NULL,
    current_amount  DECIMAL(15,2) DEFAULT 0,
    target_date     TIMESTAMP     NOT NULL,
    icon            VARCHAR(50)   DEFAULT 'flag',
    colour          VARCHAR(10)   DEFAULT '#4CAF50',
    note            TEXT          DEFAULT '',
    is_completed    BOOLEAN       DEFAULT false,
    is_deleted      BOOLEAN       DEFAULT false,
    updated_at      TIMESTAMP     NOT NULL,
    created_at      TIMESTAMP     DEFAULT NOW(),

    CONSTRAINT fk_goal_account
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE
);

CREATE INDEX idx_goal_account ON goal(idaccount);
```

### 2.6 Ghi chú về bảng `category` hiện có

Bảng `category` hiện dùng `idcategory` (INT auto-increment). Client đang dùng UUID string cho `categoryId` trong Transaction.

**Phương án được chọn:** Client tự quản lý category bằng UUID local. Khi sync category lên server sẽ cần thêm cột `uuid VARCHAR(36) UNIQUE` vào bảng `category` hoặc tạo bảng mới. *(Thảo luận với team trước khi migrate.)*

---

## 3. API Endpoints

> **Base path:** `/api/sync`  
> **Auth:** Tất cả endpoints đều yêu cầu `Authorization: Bearer <accessToken>`

### 3.1 `POST /api/sync/push` — Client gửi dữ liệu lên server

**Request Body:**

```json
{
  "clientId": "device-fingerprint-hoặc-uuid",
  "pushedAt": "2026-08-10T10:30:00.000Z",
  "operations": [
    {
      "localId": "550e8400-e29b-41d4-a716-446655440000",
      "entity": "wallet",
      "operation": "create",
      "payload": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "idaccount": 1,
        "name": "Tiền mặt",
        "type": "cash",
        "balance": 5000000,
        "currency": "VND",
        "icon": "payments",
        "colour": "#4CAF50",
        "isDefault": true,
        "isDeleted": false,
        "updatedAt": "2026-08-10T10:25:00.000Z"
      }
    },
    {
      "localId": "tx-uuid-abc123",
      "entity": "transaction",
      "operation": "create",
      "payload": {
        "id": "tx-uuid-abc123",
        "idaccount": 1,
        "walletId": "550e8400-e29b-41d4-a716-446655440000",
        "categoryId": "cat_food",
        "amount": 150000,
        "type": "chi",
        "note": "Ăn trưa",
        "date": "2026-08-10T12:00:00.000Z",
        "isDeleted": false,
        "updatedAt": "2026-08-10T12:01:00.000Z"
      }
    },
    {
      "localId": "wallet-uuid-to-delete",
      "entity": "wallet",
      "operation": "delete",
      "payload": {
        "id": "wallet-uuid-to-delete",
        "idaccount": 1,
        "isDeleted": true,
        "updatedAt": "2026-08-10T10:28:00.000Z"
      }
    }
  ]
}
```

**Giá trị hợp lệ:**

| Field | Giá trị |
|---|---|
| `entity` | `wallet` \| `transaction` \| `category` \| `budget` \| `bill` \| `goal` |
| `operation` | `create` \| `update` \| `delete` |

**Response (200 OK):**

```json
{
  "syncedAt": "2026-08-10T10:30:05.000Z",
  "results": [
    {
      "localId": "550e8400-e29b-41d4-a716-446655440000",
      "status": "synced"
    },
    {
      "localId": "tx-uuid-abc123",
      "status": "synced"
    },
    {
      "localId": "some-conflict-uuid",
      "status": "conflict",
      "serverRecord": {
        "id": "some-conflict-uuid",
        "name": "Ví ngân hàng",
        "balance": 10000000,
        "updatedAt": "2026-08-10T10:29:00.000Z"
      }
    }
  ],
  "summary": {
    "total": 3,
    "synced": 2,
    "conflicts": 1,
    "errors": 0
  }
}
```

**Status trong `results[]`:**

| Status | Ý nghĩa |
|---|---|
| `synced` | Ghi thành công |
| `conflict` | Server có version mới hơn — client cần dùng `serverRecord` |
| `error` | Lỗi server — có thêm field `error: string` giải thích lý do |

---

### 3.2 `GET /api/sync/pull?since=<ISO>&entities=<list>` — Kéo data từ server

Client gọi sau khi login hoặc khi cần lấy data từ thiết bị khác.

**Query Parameters:**

| Param | Bắt buộc | Mô tả |
|---|---|---|
| `since` | ✅ | ISO datetime — lấy records có `updated_at > since`. Dùng `1970-01-01T00:00:00Z` để lấy tất cả |
| `entities` | ❌ | Comma-separated, ví dụ `wallet,transaction`. Mặc định: tất cả |

**Ví dụ request:**
```
GET /api/sync/pull?since=2026-08-09T00:00:00.000Z&entities=wallet,transaction
Authorization: Bearer eyJhbGc...
```

**Response (200 OK):**

```json
{
  "pulledAt": "2026-08-10T10:30:05.000Z",
  "hasMore": false,
  "data": {
    "wallets": [
      {
        "id": "uuid",
        "idaccount": 1,
        "name": "Tiền mặt",
        "type": "cash",
        "balance": 5000000,
        "currency": "VND",
        "icon": "payments",
        "colour": "#4CAF50",
        "isDefault": true,
        "isDeleted": false,
        "updatedAt": "2026-08-10T10:25:00.000Z"
      }
    ],
    "transactions": [],
    "categories": [],
    "budgets": [],
    "bills": [],
    "goals": []
  }
}
```

> `hasMore: true` khi có nhiều hơn N records — backend cần implement cursor-based pagination nếu cần.

---

### 3.3 `GET /api/sync/status` — Trạng thái sync (Optional)

```
GET /api/sync/status
Authorization: Bearer eyJhbGc...
```

**Response:**

```json
{
  "idaccount": 1,
  "lastSyncedAt": "2026-08-10T10:30:05.000Z"
}
```

---

## 4. Business Logic

### 4.1 Conflict Resolution — Last-Write-Wins (LWW)

```
Client gửi record có updatedAt = T_client
Server đang có record với updatedAt = T_server

Nếu T_client > T_server  →  Ghi đè bản của client lên DB
Nếu T_client ≤ T_server  →  Giữ nguyên bản server, trả về status: "conflict"
```

**Pseudocode:**

```typescript
async function upsertWithConflict(entity, clientPayload) {
  const existing = await db.findById(entity, clientPayload.id);

  if (!existing) {
    // Record mới — tạo luôn
    await db.insert(entity, clientPayload);
    return { status: 'synced' };
  }

  const clientTime = new Date(clientPayload.updatedAt);
  const serverTime = new Date(existing.updatedAt);

  if (clientTime > serverTime) {
    // Client mới hơn → ghi đè
    await db.update(entity, clientPayload);
    return { status: 'synced' };
  } else {
    // Server mới hơn → conflict
    return { status: 'conflict', serverRecord: existing };
  }
}
```

### 4.2 Soft Delete

Khi client gửi `operation: "delete"` (hoặc payload có `isDeleted: true`):

```typescript
// ĐÚNG — soft delete
await db.update('wallet', { id, is_deleted: true, updated_at: new Date() });

// SAI — không làm thế này
await db.delete('wallet', { id });
```

**Lý do:** Các client khác cần biết record đã bị xóa để xóa khỏi local DB của họ khi pull.

### 4.3 Security — Validate Ownership

```typescript
// Bắt buộc validate idaccount khớp với JWT token
const tokenAccountId = req.user.idaccount;

for (const op of operations) {
  if (op.payload.idaccount !== tokenAccountId) {
    // Trả về 403 — không được phép write dữ liệu của người khác
    throw new ForbiddenException(`Cannot modify data of account ${op.payload.idaccount}`);
  }
}
```

### 4.4 Default Categories

Client đã có sẵn 18 danh mục mặc định trong local SQLite (seed cứng). Khi cần sync categories từ server, gọi pull với `entities=category`.

Danh mục mặc định trên server nên có `idaccount = 0` (không thuộc user nào):

```
Chi tiêu: cat_food, cat_transport, cat_shopping, cat_health,
          cat_education, cat_entertain, cat_housing, cat_bill_chi, cat_other_chi
Thu nhập: cat_salary, cat_bonus, cat_freelance, cat_invest, cat_other_thu
Vay/nợ:  cat_lend, cat_borrow, cat_repay, cat_collect
```

---

## 5. Authentication & Security

```typescript
// NestJS — bảo vệ toàn bộ sync module
@UseGuards(JwtAuthGuard)
@Controller('sync')
export class SyncController { ... }
```

Client đã có `AuthInterceptor` tự động attach `Authorization: Bearer <token>` vào mọi request. Backend không cần làm gì thêm về phía xác thực — chỉ cần đảm bảo JWT Guard được áp dụng.

---

## 6. Prisma Schema (copy vào `schema.prisma`)

```prisma
model Wallet {
  id           String        @id                     // UUID từ client
  idaccount    Int
  name         String        @db.VarChar(100)
  type         String        @default("cash")        @db.VarChar(20)
  balance      Decimal       @default(0)             @db.Decimal(15, 2)
  currency     String        @default("VND")         @db.VarChar(10)
  icon         String?       @default("wallet")      @db.VarChar(50)
  colour       String?       @default("#4CAF50")     @db.VarChar(10)
  isDefault    Boolean       @default(false)         @map("is_default")
  isDeleted    Boolean       @default(false)         @map("is_deleted")
  updatedAt    DateTime                              @map("updated_at") @db.Timestamp(6)
  createdAt    DateTime?     @default(now())         @map("created_at") @db.Timestamp(6)
  account      account       @relation(fields: [idaccount], references: [idaccount], onDelete: Cascade)
  transactions Transaction[]

  @@index([idaccount])
  @@index([updatedAt])
  @@map("wallet")
}

model Transaction {
  id         String    @id
  idaccount  Int
  walletId   String    @map("wallet_id")
  categoryId String?   @map("category_id")
  amount     Decimal   @db.Decimal(15, 2)
  type       String    @db.VarChar(20)
  note       String?   @default("")
  date       DateTime  @db.Timestamp(6)
  images     String?   @default("[]")
  isDeleted  Boolean   @default(false)   @map("is_deleted")
  updatedAt  DateTime                    @map("updated_at") @db.Timestamp(6)
  createdAt  DateTime? @default(now())   @map("created_at") @db.Timestamp(6)
  account    account   @relation(fields: [idaccount], references: [idaccount], onDelete: Cascade)
  wallet     Wallet    @relation(fields: [walletId],  references: [id],         onDelete: Cascade)

  @@index([idaccount])
  @@index([walletId])
  @@index([date])
  @@index([updatedAt])
  @@map("transaction")
}

model Budget {
  id         String    @id
  idaccount  Int
  categoryId String?   @map("category_id")
  amount     Decimal   @db.Decimal(15, 2)
  period     String    @default("monthly") @db.VarChar(20)
  startDate  DateTime  @map("start_date")  @db.Timestamp(6)
  endDate    DateTime? @map("end_date")    @db.Timestamp(6)
  note       String?   @default("")
  isDeleted  Boolean   @default(false)     @map("is_deleted")
  updatedAt  DateTime                      @map("updated_at") @db.Timestamp(6)
  createdAt  DateTime? @default(now())     @map("created_at") @db.Timestamp(6)
  account    account   @relation(fields: [idaccount], references: [idaccount], onDelete: Cascade)

  @@index([idaccount])
  @@map("budget")
}

model Bill {
  id         String    @id
  idaccount  Int
  name       String    @db.VarChar(100)
  amount     Decimal   @db.Decimal(15, 2)
  dueDate    DateTime  @map("due_date")   @db.Timestamp(6)
  isPaid     Boolean   @default(false)    @map("is_paid")
  recurrence String    @default("monthly") @db.VarChar(20)
  icon       String?   @default("receipt") @db.VarChar(50)
  colour     String?   @default("#4CAF50") @db.VarChar(10)
  note       String?   @default("")
  isDeleted  Boolean   @default(false)    @map("is_deleted")
  updatedAt  DateTime                     @map("updated_at") @db.Timestamp(6)
  createdAt  DateTime? @default(now())    @map("created_at") @db.Timestamp(6)
  account    account   @relation(fields: [idaccount], references: [idaccount], onDelete: Cascade)

  @@index([idaccount])
  @@map("bill")
}

model Goal {
  id            String    @id
  idaccount     Int
  name          String    @db.VarChar(100)
  targetAmount  Decimal   @map("target_amount")  @db.Decimal(15, 2)
  currentAmount Decimal   @default(0) @map("current_amount") @db.Decimal(15, 2)
  targetDate    DateTime  @map("target_date")    @db.Timestamp(6)
  icon          String?   @default("flag")       @db.VarChar(50)
  colour        String?   @default("#4CAF50")    @db.VarChar(10)
  note          String?   @default("")
  isCompleted   Boolean   @default(false)        @map("is_completed")
  isDeleted     Boolean   @default(false)        @map("is_deleted")
  updatedAt     DateTime                         @map("updated_at") @db.Timestamp(6)
  createdAt     DateTime? @default(now())        @map("created_at") @db.Timestamp(6)
  account       account   @relation(fields: [idaccount], references: [idaccount], onDelete: Cascade)

  @@index([idaccount])
  @@map("goal")
}
```

> Sau khi thêm vào `schema.prisma`, chạy:
> ```bash
> npx prisma migrate dev --name add_sync_tables
> npx prisma generate
> ```

---

## 7. Cấu Trúc Module NestJS (Gợi ý)

```
src/
└── sync/
    ├── sync.module.ts
    ├── sync.controller.ts        -- @Post('push'), @Get('pull'), @Get('status')
    ├── sync.service.ts           -- Core logic, gọi Prisma
    ├── dto/
    │   ├── push-sync.dto.ts      -- Validate request push
    │   └── pull-sync.dto.ts      -- Validate query params pull
    └── helpers/
        └── conflict.helper.ts    -- Last-Write-Wins logic
```

**`sync.module.ts` mẫu:**

```typescript
@Module({
  imports: [PrismaModule],
  controllers: [SyncController],
  providers: [SyncService],
})
export class SyncModule {}
```

**Đăng ký trong `app.module.ts`:**

```typescript
import { SyncModule } from './sync/sync.module';

@Module({
  imports: [
    AuthModule,
    SyncModule,   // ← thêm dòng này
    // ...
  ],
})
export class AppModule {}
```

---

## 8. Testing Checklist

### Functional
- [ ] `POST /push` — tạo wallet mới → xuất hiện trong DB PostgreSQL
- [ ] `POST /push` — update wallet → `updated_at` thay đổi
- [ ] `POST /push` — delete → `is_deleted = true`, record vẫn còn trong DB
- [ ] `POST /push` — record cũ hơn server → nhận `status: "conflict"` + `serverRecord`
- [ ] `GET /pull?since=epoch` → nhận toàn bộ data của user
- [ ] `GET /pull?since=T` → chỉ nhận records có `updated_at > T`
- [ ] `GET /pull?entities=wallet` → chỉ nhận wallets

### Security
- [ ] Không có token → `401 Unauthorized`
- [ ] Token hợp lệ nhưng push record của `idaccount` khác → `403 Forbidden`
- [ ] Token hết hạn → `401` (client sẽ tự refresh)

### Edge cases
- [ ] Push cùng record 2 lần → không bị duplicate (idempotent)
- [ ] `operations: []` (mảng rỗng) → `200 OK` với `summary.total = 0`
- [ ] `since` không hợp lệ → `400 Bad Request`

---

## 9. Liên Hệ Client

Các file Flutter liên quan:

| File | Mô tả |
|---|---|
| `lib/core/sync/sync_engine.dart` | Gửi batch `POST /sync/push`, xử lý response |
| `lib/core/sync/sync_models.dart` | `SyncOperation`, `SyncResult`, `SyncStatus` |
| `lib/core/database/tables/*.dart` | Schema SQLite local — align với schema trên |
| `lib/core/api/dio_client.dart` | HTTP client — tự attach Bearer token |
