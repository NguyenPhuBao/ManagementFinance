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

## Giai Đoạn 1 — Nền Móng Database, Bất Đồng Bộ & SQLite (Có thể làm ngay)

### Tại Backend:
- **Bước 1.1 — `database/)5_Bank_Module.sql`**: Tạo bảng `bank_account` + ALTER `transaction`. 
- **Bước 1.2 — `prisma/schema.prisma`**: Thêm model `bank_account`, cập nhật model `transaction`.
- **Bước 1.3 — Cập nhật Module Sync**: Thêm `provider` và `external_transaction_id` vào allowed list trong `sync.validation.js` và `sync.repository.js`.
- **Bước 1.4 & 1.5 & 1.6 — Worker**: Khởi tạo queue `bank-webhook`, viết `bank.worker.js` và đăng ký trong `index.js`.
- **Bước 1.7 — `.env`**: Đổi sang `CASSO_API_KEY`, `CASSO_WEBHOOK_SECRET`.

### Tại Client-app (Flutter):
- **Bước 1.8 — Cập nhật SQLite**: Thêm 2 cột `provider`, `external_transaction_id` vào bảng `transaction` trong CSDL nội bộ.
- **Bước 1.9 — Cập nhật Model & SyncEngine**: Đảm bảo luồng đồng bộ (Pull/Push) từ Backend trả về không bị rớt mất 2 trường mới này.

---

## Giai Đoạn 2 — Core Module Bank & Giao Diện Người Dùng (Có thể làm ngay)

### Tại Backend:
- **Bước 2.1 — `bank.client.js`**: Gọi API Casso (lấy accounts, transactions).
- **Bước 2.2 — `bank.webhook.js`**: Verify chữ ký `Secure-Token`.
- **Bước 2.3 & 2.4 — Repo & Service**: Xử lý logic lưu thông tin thẻ NH, cập nhật số dư, đẩy vào hàng đợi webhook.
- **Bước 2.5 — Controller & Routes**: Mở các API `/api/bank/accounts`, `/api/bank/transactions`, và `/api/bank/webhook`.

### Tại Client-app (Flutter):
- **Bước 2.6 — UI Danh sách Ngân hàng**: Thêm màn hình gọi API `/api/bank/accounts` để hiển thị các tài khoản ngân hàng đã liên kết và số dư realtime.
- **Bước 2.7 — Cập nhật UI Giao dịch**: Hiển thị badge/icon nhận diện các giao dịch có `provider='casso'` (Giao dịch tự động).

---

## Giai Đoạn 3 — Deploy Lên Cloud (Bắt buộc trước khi webhook hoạt động)

- **Bước 3.1 — PostgreSQL → Supabase**: Đẩy DB lên Cloud. (✅ Đã xong)
- **Bước 3.2 — Backend → Render**: Deploy Node.js lên Render. (✅ Đã xong)
- **Bước 3.3 — Admin-web → Vercel**: Deploy Admin-web. (✅ Đã xong)
- **Bước 3.4 — Cập nhật Config Client-app**: Đổi base URL trong Flutter trỏ về `https://managementfinance.onrender.com/api`.
- **Bước 3.5 — Cấu hình Webhook Casso**: Lên my.casso.vn nhập URL Webhook Render.

---

## Giai Đoạn 4 — Admin Web & Realtime

### Tại Admin-web (React/Vite):
- **Bước 4.1 — Nhúng Widget Casso**: Tạo màn hình cho phép Admin (hoặc người dùng) liên kết tài khoản ngân hàng qua giao diện Widget của Casso.
- **Bước 4.2 — Audit Log Realtime**: Lắng nghe Socket.IO từ Backend để báo cáo trạng thái webhook (nhận tiền) ngay lập tức trên dashboard.

### Tại Client-app (Flutter):
- **Bước 4.3 — Push Notification (Tùy chọn)**: Hiển thị thông báo cục bộ khi nhận được giao dịch từ Casso thông qua Sync/Socket.

---

## Bảng Tiến Độ Toàn Hệ Thống

| # | Nền tảng | Việc cần làm | Trạng thái | Ghi chú |
|---|---|---|---|---|
| 1 | Backend | Tạo SQL Script `)5_Bank_Module.sql` | ✅ Đã xong | |
| 2 | Backend | Cập nhật Prisma + generate | ✅ Đã xong | |
| 3 | Backend | Cập nhật Module Sync cho 2 field mới | ✅ Đã xong | **Bắt buộc** |
| 4 | Backend | Set up queue & worker (`bank.worker.js`) | ✅ Đã xong | |
| 5 | Backend | Đăng ký worker & cập nhật `.env` | ✅ Đã xong | |
| 6 | Client | Thêm 2 field mới vào SQLite & SyncEngine | 🔴 Chưa làm | Chống mất dữ liệu đồng bộ |
| 7 | Backend | Viết `bank.client.js` & `bank.webhook.js` | 🔴 Chưa làm | Dùng `CASSO_API_KEY` |
| 8 | Backend | Viết repo, service, controller, routes | 🔴 Chưa làm | Cốt lõi của webhook |
| 9 | Client | UI Quản lý tài khoản NH (gọi API) | 🔴 Chưa làm | Xem số dư NH |
| 10 | Client | UI phân biệt giao dịch thủ công / casso | 🔴 Chưa làm | |
| 11 | Backend | Deploy PostgreSQL → Supabase | ✅ Đã xong | Đã có URL Supabase |
| 12 | Backend | Deploy Backend → Render | ✅ Đã xong | URL: managementfinance.onrender.com |
| 13 | Admin | Deploy Admin-web → Vercel | ✅ Đã xong | URL: management-finance-gamma.vercel.app |
| 14 | Client | Cập nhật Base URL trỏ lên Render | 🔴 Chưa làm | Trước khi build app |
| 15 | Casso | Đăng ký Webhook trên portal my.casso.vn | 🔴 Chưa làm | Cần Backend hoàn thiện (task 7, 8) |
| 16 | Admin | Nhúng Widget Casso để link tài khoản | 🔴 Chưa làm | |
| 17 | Admin | Lắng nghe Socket.IO hiển thị audit log | 🔴 Chưa làm | |
| 18 | Client | Push notification khi nhận webhook | 🔴 Chưa làm | Tùy chọn nâng cao |
