# Kế Hoạch Triển Khai Module Bank — Tích Hợp Casso

> Cập nhật lần cuối: 2026-08-17
> Trạng thái: 🔴 Chưa bắt đầu
> Spec tham khảo: `Project.md` — Section 8.4

---

## Kiến Trúc Tích Hợp (Đã chốt)

| Điểm | Quyết định |
|---|---|
| **Xác thực Casso** | `CASSO_API_KEY` lưu trong `.env` — 1 key duy nhất phía server |
| **Bảng lưu token** | ❌ Không cần — bỏ hoàn toàn `bank_connection` |
| **Bảng lưu tài khoản NH** | ✅ Giữ `bank_account` — ánh xạ tài khoản Casso với user trong app |
| **Webhook setup** | Cấu hình 1 lần trên portal Casso, cần URL công khai |

### Tại sao lưu trong `.env`?

1 API Key cấp độ server → tất cả tài khoản NH được admin liên kết qua Casso đều đi qua key này. Backend đọc key từ `process.env.CASSO_API_KEY` khi cần gọi API. Không cần DB, không cần mã hóa, không cần quản lý per-user.

---

## ⚠️ Điều Kiện Tiên Quyết — CHƯA THỂ LÀM WEBHOOK

> **Dự án chưa có URL công khai.** Casso webhook yêu cầu URL thực tế trên internet. Phải deploy trước, sau đó mới đăng ký webhook.

### Phải Làm Trước: Deploy Lên Cloud

1. **PostgreSQL → Supabase**
   - Tạo project Supabase → lấy `DATABASE_URL` dạng `postgresql://...supabase.co/postgres`
   - Chạy toàn bộ SQL scripts (`database/)1_` đến `)5_`) lên Supabase

2. **Backend → Vercel / Railway**
   - Kết nối repo lên Vercel/Railway
   - Cấu hình tất cả biến môi trường production (bao gồm `CASSO_API_KEY`, `CASSO_WEBHOOK_SECRET`)
   - Deploy → nhận URL công khai (vd: `https://wealthcommand.vercel.app`)

3. **Cấu hình Webhook trên my.casso.vn**
   - Settings → Integration → Tạo Webhook
   - Webhook URL: `https://<vercel-url>/api/bank/webhook`
   - Đặt Security Key → đây là `CASSO_WEBHOOK_SECRET`

---

## Phân Tích Thực Trạng Codebase

| File | Trạng thái |
|---|---|
| `workers/bank.worker.js` | 🔴 Rỗng |
| `modules/bank/bank.controller.js` | 🔴 Rỗng |
| `modules/bank/bank.service.js` | 🔴 Rỗng |
| `modules/bank/bank.repository.js` | 🔴 Rỗng |
| `modules/bank/bank.validation.js` | 🔴 Rỗng |
| `modules/bank/bank.jobs.js` | 🔴 Rỗng |
| `api/bank.routes.js` | 🔴 Chỉ có TODO |
| `core/queue.js` | 🟡 Thiếu queue `bank-webhook` |
| `index.js` | 🟡 Chưa đăng ký `bank.worker` |
| `.env` | 🟡 Cần cập nhật biến Casso |

---

## Cấu Hình `.env` (Đã chốt)

```env
# Xóa/bỏ qua 2 biến cũ không còn dùng:
# CASSO_CLIENT_ID=
# CASSO_CLIENT_SECRET=

# Thêm 2 biến mới:
CASSO_API_KEY=<API Key lấy từ my.casso.vn → Settings → Integration → Tạo tích hợp → API Key>
CASSO_WEBHOOK_SECRET=<chuỗi bạn tự đặt khi tạo webhook, ví dụ: my-secret-key-123>
```

> `ENCRYPTION_KEY` không còn cần thiết vì không có dữ liệu nhạy cảm nào cần mã hóa trong DB nữa.

---

## Thiết Kế CSDL (Đã đơn giản hóa)

### ❌ Bỏ hoàn toàn bảng `bank_connection`

Không cần lưu bất kỳ token hay key nào vào DB. `CASSO_API_KEY` chỉ tồn tại trong `.env`.

### ✅ Bảng `bank_account` (Giữ nguyên)

Mục đích: Lưu danh sách tài khoản NH đã được liên kết qua Casso, ánh xạ với từng user trong app.

```sql
CREATE TABLE bank_account (
    id               VARCHAR(36)    PRIMARY KEY,          -- UUID do backend sinh
    idaccount        INT            NOT NULL,              -- FK → account(idaccount)
    casso_account_id VARCHAR(100)   NOT NULL UNIQUE,       -- ID tài khoản phía Casso (để mapping)
    account_number   VARCHAR(50)    NOT NULL,              -- Số tài khoản NH (vd: 1903xxx)
    account_name     VARCHAR(255)   NOT NULL,              -- Tên chủ thẻ (vd: NGUYEN VAN A)
    bank_name        VARCHAR(100)   NOT NULL,              -- Tên NH (vd: Vietcombank, MB)
    balance          DECIMAL(15,2)  DEFAULT 0,             -- Số dư đồng bộ gần nhất từ Casso
    connect_status   VARCHAR(20)    DEFAULT 'active',      -- 'active' | 'inactive'
    created_at       TIMESTAMP      DEFAULT NOW(),
    updated_at       TIMESTAMP      DEFAULT NOW(),

    CONSTRAINT fk_bank_account_owner
        FOREIGN KEY (idaccount) REFERENCES account(idaccount) ON DELETE CASCADE
);

CREATE INDEX idx_bank_account_owner  ON bank_account(idaccount);
CREATE INDEX idx_bank_account_status ON bank_account(connect_status);
```

### ✅ ALTER bảng `transaction`

```sql
ALTER TABLE transaction
    ADD COLUMN provider                VARCHAR(30)   DEFAULT 'manual',
    -- 'manual' = người dùng nhập tay | 'casso' = tự động từ webhook
    ADD COLUMN external_transaction_id VARCHAR(100)  DEFAULT NULL,
    -- ID giao dịch phía Casso (tid) — chống trùng lặp webhook
    ADD CONSTRAINT uq_transaction_external
        UNIQUE (provider, external_transaction_id);

CREATE INDEX idx_transaction_provider ON transaction(provider);
```

---

## Luồng Hoạt Động Tổng Thể

```
[Admin] Liên kết tài khoản NH trên my.casso.vn
        ↓
[Backend] Gọi GET /v2/accounts bằng CASSO_API_KEY
        ↓
[Backend] Lưu danh sách tài khoản vào bảng bank_account (ánh xạ với user)
        ↓
[Casso] Khi có giao dịch → gửi webhook → POST /api/bank/webhook
        ↓
[Backend] Verify CASSO_WEBHOOK_SECRET → Enqueue vào BullMQ
        ↓
[bank.worker] Khử trùng → Lưu transaction → Emit event transaction.created
        ↓
[Mobile App] SyncEngine kéo về → hiển thị giao dịch + số dư mới
```

---

## Giai Đoạn 1 — Nền Móng Database & Bất Đồng Bộ (Có thể làm ngay)

### Bước 1.1 — `database/)5_Bank_Module.sql`

Tạo bảng `bank_account` + ALTER `transaction`. **Không tạo `bank_connection`.**

### Bước 1.2 — Cập nhật `prisma/schema.prisma` + `npx prisma generate`

Thêm model `bank_account`, cập nhật model `transaction`.

### Bước 1.3 — Cập nhật Module Sync (Quy tắc bắt buộc)

Vì `transaction` có thêm 2 cột mới (`provider`, `external_transaction_id`):
- `sync.validation.js`: Thêm 2 field vào allowed list
- `sync.repository.js`: Đảm bảo upsert không bỏ sót 2 cột mới

### Bước 1.4 — Thêm queue `bank-webhook` vào `core/queue.js`

### Bước 1.5 — Viết `workers/bank.worker.js` (đầy đủ logic)

Theo pattern `ai.worker.js`:
1. Lắng nghe queue `bank-webhook`
2. Parse payload webhook Casso (`tid`, `amount`, `runningBalance`, `bankAccountId`)
3. Khử trùng: kiểm tra `{provider:'casso', external_transaction_id:tid}` đã tồn tại chưa
4. Tạo `transaction` mới với `provider='casso'`
5. Cập nhật `bank_account.balance = runningBalance`
6. `EventBus.publish('transaction.created', {...})`

### Bước 1.6 — Đăng ký `bank.worker` trong `index.js`

Thêm vào khối `if (redisOk)`:
```js
logger.info('Starting Bank Worker...');
require('./workers/bank.worker');
```

### Bước 1.7 — Cập nhật `.env`

Xóa `CASSO_CLIENT_ID`, `CASSO_CLIENT_SECRET`. Thêm `CASSO_API_KEY`, `CASSO_WEBHOOK_SECRET`.

---

## Giai Đoạn 2 — Core Module Bank (Có thể làm ngay)

### Bước 2.1 — `bank.client.js`

Gọi Casso API dùng `process.env.CASSO_API_KEY`:
- `getAccounts()` → GET `api.casso.vn/v2/accounts`
- `getTransactions(since)` → GET `api.casso.vn/v2/transactions`

### Bước 2.2 — `bank.webhook.js`

Verify `Secure-Token` header bằng `CASSO_WEBHOOK_SECRET`.

### Bước 2.3 — `bank.repository.js`

- `upsertBankAccounts(idaccount, cassoAccountList[])` — Lưu/cập nhật danh sách NH
- `findTransactionByExternalId(provider, externalId)` — Kiểm tra trùng lặp
- `createTransactionFromWebhook(data)` — Tạo giao dịch mới
- `updateBankBalance(cassoAccountId, balance)` — Cập nhật số dư
- `getBankAccountsByUser(idaccount)` — Lấy danh sách NH của user

### Bước 2.4 — `bank.service.js`

- `getAccounts(idaccount)` → gọi Casso API → cập nhật DB → trả về
- `getTransactions(idaccount, since)` → gọi Casso API → trả về
- `enqueueWebhookJob(payload)` → `enqueue('bankWebhook', ...)`

### Bước 2.5 — `bank.validation.js`, `bank.jobs.js`, `bank.controller.js`, `bank.routes.js`

**Endpoints:**

| Method | Path | Auth | Mô tả |
|---|---|---|---|
| GET | `/api/bank/accounts` | Bearer (user) | Danh sách NH + số dư của user |
| GET | `/api/bank/transactions` | Bearer (user) | Lịch sử giao dịch NH |
| POST | `/api/bank/webhook` | Public (verify sig) | Nhận webhook Casso → enqueue → 200 OK |

---

## Giai Đoạn 3 — Deploy Lên Cloud (Bắt buộc trước khi webhook hoạt động)

### Bước 3.1 — PostgreSQL → Supabase
### Bước 3.2 — Backend → Vercel / Railway
### Bước 3.3 — Cấu hình Webhook Casso (cần URL public từ bước 3.2)

---

## Giai Đoạn 4 — Admin Web

### Bước 4.1 — Nhúng Widget Casso (không tự xây giao diện)
### Bước 4.2 — Audit Log Webhook Realtime (Socket.IO)

---

## Bảng Tiến Độ

| # | Việc cần làm | File | Trạng thái | Ghi chú |
|---|---|---|---|---|
| 1 | Tạo SQL Script | `database/)5_Bank_Module.sql` | 🔴 Chưa làm | Có thể làm ngay |
| 2 | Cập nhật Prisma + generate | `prisma/schema.prisma` | 🔴 Chưa làm | Có thể làm ngay |
| 3 | Cập nhật Module Sync | `modules/sync/sync.*.js` | 🔴 Chưa làm | **Quy tắc bắt buộc** |
| 4 | Thêm queue bank-webhook | `core/queue.js` | 🔴 Chưa làm | Có thể làm ngay |
| 5 | Viết bank worker | `workers/bank.worker.js` | 🔴 Chưa làm | Có thể làm ngay |
| 6 | Đăng ký bank worker | `index.js` | 🔴 Chưa làm | Có thể làm ngay |
| 7 | Cập nhật .env | `.env` | 🔴 Chưa làm | Đổi tên biến Casso |
| 8 | Viết bank.client.js | `modules/bank/bank.client.js` | 🔴 Chưa làm | Dùng CASSO_API_KEY từ .env |
| 9 | Viết bank.webhook.js | `modules/bank/bank.webhook.js` | 🔴 Chưa làm | Verify signature |
| 10 | Viết bank.repository.js | `modules/bank/bank.repository.js` | 🔴 Chưa làm | |
| 11 | Viết bank.service.js | `modules/bank/bank.service.js` | 🔴 Chưa làm | |
| 12 | Viết bank.validation.js | `modules/bank/bank.validation.js` | 🔴 Chưa làm | |
| 13 | Viết bank.jobs.js | `modules/bank/bank.jobs.js` | 🔴 Chưa làm | |
| 14 | Viết bank.controller.js | `modules/bank/bank.controller.js` | 🔴 Chưa làm | |
| 15 | Cập nhật bank.routes.js | `api/bank.routes.js` | 🔴 Chưa làm | |
| 16 | Deploy PostgreSQL → Supabase | — | 🔴 Chưa làm | **Bắt buộc trước webhook** |
| 17 | Deploy Backend → Vercel/Railway | — | 🔴 Chưa làm | **Bắt buộc trước webhook** |
| 18 | Cấu hình Webhook trên Casso | — | 🔴 Chưa làm | **Sau khi có URL public** |
| 19 | Admin: Nhúng widget Casso | `Admin-web/pages/...` | 🔴 Chưa làm | |
| 20 | Admin: Audit log realtime | `Admin-web/pages/...` | 🔴 Chưa làm | |
