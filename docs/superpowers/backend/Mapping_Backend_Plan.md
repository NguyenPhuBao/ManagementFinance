# Kế hoạch Sửa Backend theo CSDL mới

> **Ngày:** 2026-08-26
> **Mục đích:** Sửa toàn bộ Backend (Node.js/Express/Prisma) để khớp CSDL mới (`New_Database.md`) — sau khi đã thay thế schema.
> **Tham chiếu:** `MIGRATION_MAPPING_PLAN.md` (mapping bảng/cột), `New_Database.md` (CSDL chuẩn)
> **Nguyên tắc:** Tuân theo CSDL mới **hoàn toàn**. Client-app sẽ được sửa riêng trong đợt sau.

---

## 0. Tóm tắt phạm vi

Backend hiện tại (Node.js Express + Prisma + BullMQ) có **6 module internet**: `auth`, `admin`, `sync`, `bank`, `ai`, `notification`. Tất cả đều dùng field theo schema cũ → cần cập nhật sang field CSDL mới.

**2 nhóm thay đổi chính:**
1. **Đổi tên field** (Prisma model + toàn bộ repository/service/controller)
2. **Đổi logic nghiệp vụ** (xóa mềm `Delete_at`, enum mới, chống trùng `(Provider, Bank_tran_id)`, ví Saving, OTP Idaccount...)

---

## 1. Ma trận thay đổi field (Cũ → Mới) áp dụng cho Backend

| Bảng | Field cũ (đang dùng) | Field mới (CSDL) | Module bị ảnh hưởng |
|---|---|---|---|
| `account` | `username/password/status/scheduled_delete_at` | `Username/Password/Status/Delete_at` + `Email` + `Type` | auth, admin |
| `User` | `fullname/email/phone/address/location` | `Fullname/Email/Phone/Address/Country_code` + `Delete_at` | auth, admin |
| `auditlog` | `action/details/time` | `Request/TimeReq/TimeRes` | (middleware nếu dùng) |
| `otp_code` | `email` (FK) | + `Idaccount` FK, bỏ FK email | auth |
| `category` | `uuid` (PK), `namecategory`, `created_by` | `Idcategory`, `NameCategory`, `Create_by` + `Idgroup/Keyword/Icon/Delete_at` | admin, sync |
| `wallet` | `id`, `colour`, `is_deleted` | `Idwallet`, `Color`, `Status`, `IncludeInTotal`, `Is_default`, `Delete_at`, `Id_bank_casso` | sync, bank |
| `budget` | `amount/period/start_date/end_date` | `TotalAmount/Start/End` + `Spent/Remaining/PercentSpent/OverSpending/OverAmount/Recurrence/Time_recurrence` | sync |
| `bill` | `is_paid/recurrence` | `Pay_status` + `Idwallet/Idcategory` (**BẮT BUỘC** — chọn ví + danh mục khi tạo bill) + `Recurrence/Time_recurrence` | sync |
| `goal` | `is_completed` | `Status_complete` + `Idwallet` (**NULL** = chưa liên kết ví đích) | sync |
| `transaction` | `date/external_transaction_id/is_deleted` | `Create_at/Update_at/Delete_at/Bank_tran_id` + `Wallet_Transfer`; `Provider` giữ | sync, bank, ai |
| `bank_account` | `casso_account_id` | `Id_casso_account` + `Delete_at` | bank |

---

## 2. Thay đổi theo từng module

### 2.1. Prisma Schema — `src/Backend/prisma/schema.prisma`

> Chi tiết 13 models mới đã có trong `MIGRATION_MAPPING_PLAN.md` + `New_Database.md`. Đây là phần tóm tắt.

- [ ] Viết lại toàn bộ 13 models theo CSDL mới (tên field PascalCase hoặc giữ snake_case theo quyết định — **đề xuất giữ snake_case DB + `@map` cho Prisma field camelCase** để code đỡ rối)
- [ ] Thêm relation: `Category.Idgroup` tự tham chiếu; `Wallet.Id_bank_casso` → Bank_account (**varchar(36)** — khớp `Id_bank_account`); `Bill.Idwallet/Idcategory`; `Goal.Idwallet`; `Transaction.Wallet_Transfer`
- [ ] Thêm check/unique mới: `(Provider, Bank_tran_id)`, partial unique ví Saving/Is_default, unique `Id_bank_casso`, unique category default toàn cục
- [ ] `Budget.Idcategory` **nullable** — NULL = ngân sách tổng (không phá vỡ tính năng Client)
- [ ] `Goal.Idwallet` **nullable** — NULL = chưa liên kết ví đích (gán lần đầu khi nạp tiền); `Bill.Idwallet` + `Bill.Idcategory` **bắt buộc** (chọn khi tạo bill)
- [ ] `Wallet.Name` **nvarchar(40)** — Client giới hạn tên ví ≤ 40 ký tự
- [ ] `npx prisma validate`

### 2.2. Module Auth — `src/Backend/modules/auth/`

| File | Thay đổi |
|---|---|
| `auth.repository.js` | **`createAccountWithUser`: thêm `email` + `type: 'Basic'` vào `tx.account.create`** (CSDL mới Account bắt buộc có Email — lấy từ `user.email`); `createOtp` thêm `idaccount`; `findValidOtp` tra theo `(idaccount, purpose)`; `scheduleDeletion` ghi `Delete_at` thay `scheduled_delete_at`; field User đổi `location→Country_code`, `fullname→Fullname` |
| `auth.service.js` | Cập nhật payload field mới; `cleanPayload` theo field mới |
| `auth.validation.js` | Validate `Type`, `Idaccount` khi gửi OTP |

**⚠️ Email (2 thay đổi quan trọng):**
1. **`findAccountByEmail`** hiện đang query `prisma.user` → phải đổi sang **`prisma.account.findUnique({ where: { email } })`** (Account.Email giờ unique — không còn ở User).
2. **Login**: CSDL mới Account có cả `Username` + `Email` → có thể cho phép **đăng nhập bằng email hoặc username** (find theo `OR: [{username}, {email}]`).

**⚠️ OTP**: Bảng mới có `Idaccount` FK — luồng gửi OTP phải truyền `idaccount` (không chỉ email). Khi user quên mật khẩu (chưa đăng nhập) → tìm `account` theo email → lấy `idaccount` → tạo OTP với `idaccount`.

### 2.3. Module Admin — `src/Backend/modules/admin/`

| File | Thay đổi |
|---|---|
| `admin.repository.js` | `addCategory`/`updateCategory` dùng `NameCategory/Idcategory/Keyword/Icon`; bỏ `idcategory` int; xóa mềm `Delete_at` |
| `admin.service.js` | Map field mới khi trả response (`is_default`, `created_by` giữ — khớp CSDL mới `Create_by`) |
| `admin.controller.js` | Payload `name/classify/is_default` → field mới |

**⚠️ Category default toàn cục**: `Create_by` = **`idaccount` của admin đọc từ DB khi seed** (không cứng giá trị — an toàn nếu admin không có id=1). Danh mục mặc định do admin quản lý. User tạo danh mục riêng → `Create_by = idaccount` của user đó.

### 2.4. Module Sync — `src/Backend/modules/sync/` 🔴 (ảnh hưởng nhiều nhất)

| File | Thay đổi |
|---|---|
| `sync.repository.js` | `upsertCategory` dùng `Idcategory` PK (thay `uuid`); thêm field mới `Idgroup/Keyword/Icon/Is_group/Delete_at`; xử lý đầy đủ: **group** (`Is_group=true`, `Idgroup=null`) + **con** (`Idgroup` trỏ group) + **con chưa nhóm** (`Is_group=false`, `Idgroup=null`) + unique theo ràng buộc mới; `upsertWallet` thêm `Status/IncludeInTotal/Is_default`; `upsertTransaction` `Create_at/Update_at/Delete_at/Wallet_Transfer`, Amount giữ dấu; `softDelete` đổi `is_deleted=true` → `Delete_at=now()`; category xóa mềm thay vì hard delete |
| `sync.service.js` | Map entity/pull giữ; cập nhật field mới khi trả `serverRecord`; category sync **bao gồm group + keyword** (1 entity, không tách bảng) |
| `sync.controller.js` | Không đổi nhiều (pass-through) |
| `sync.validation.js` | `VALID_ENTITIES` giữ 6 entity; cập nhật schema field mới cho `category` (thêm `idgroup`, `keyword`, `is_group`) |

**⚠️ LWW**: Giữ nguyên so sánh `updated_at` → `Update_at`.

### 2.5. Module Bank — `src/Backend/modules/bank/` + `workers/bank.worker.js` (✅ ĐÃ HOÀN THÀNH)

| File | Thay đổi & Trạng thái |
|---|---|
| `bank.repository.js` | ✅ `upsertBankAccounts` tự sinh `id_bank_account: uuidv4()`, map `id_casso_account`, fallback tên trường; `createTransactionFromWebhook` dùng `Create_at`, `Bank_tran_id`, `Provider='Casso'`, `Idcategory=NULL` |
| `bank.service.js` | ✅ `enqueueWebhookJob` bóc tách linh hoạt payload (Array / Single Object / Direct Array) đẩy vào BullMQ queue |
| `bank.controller.js` | ✅ `handleWebhook` xác thực qua `casso.webhook.js`, trả về 200 graceful khi có lỗi nội bộ để tránh loop retry |
| `casso/casso.webhook.js` | ✅ `verifySignature` dùng `crypto.timingSafeEqual` chống Timing Attacks |
| `workers/bank.worker.js` | ✅ Tạo transaction: `Create_at` (từ `when`), `Bank_tran_id` (từ `tid`/`id`), `type='Transaction'`; **Amount giữ dấu ±**; tìm/tạo ví `Type='Banking'` + `Id_bank_casso` (tên ví truncate ≤ 100); fallback `cusum_balance` + log warning; phát sự kiện `transaction.created` (`transactionId: newTx.idtran`) |
| `casso/casso.client.js` | ✅ Tương thích 100% |

**✅ Luồng webhook (PO quyết):** Ghi transaction TRƯỚC (Amount giữ dấu, `Idcategory=NULL`) → sau đó worker phân loại category (`Idcategory`) cập nhật — giao dịch không chờ phân loại.

**⚠️ Chống trùng**: `findTransactionByExternalId` → tìm theo `(Provider='Casso', Bank_tran_id)` khớp unique constraint `uq_transaction_external`.

### 2.6. Module AI — `src/Backend/modules/ai/`

| File | Thay đổi |
|---|---|
| `ai.jobs.js` | Payload field mới (`Category.Idcategory` thay `uuid`) |
| `ai.service.js` | Map category id mới |

*(AI hiện ở shell mode — thay đổi nhẹ.)*

### 2.7. Module Notification — `src/Backend/modules/notification/`

- [ ] Kiểm tra field tham chiếu (nếu dùng `account/idaccount`) — không đổi cấu trúc lớn.

### 2.8. Workers khác — `src/Backend/workers/`

| File | Thay đổi |
|---|---|
| `ai.worker.js` | Shell — cập nhật field nếu có |
| `notification.worker.js` | Kiểm tra field account |

---

## 3. Thay đổi cross-cutting (dùng chung)

### 3.1. Cơ chế xóa mềm (`is_deleted` → `Delete_at`)

| File | Thay đổi |
|---|---|
| Tất cả repository | Mọi query filter `is_deleted: false` → thêm `Delete_at: null` |
| `sync.repository.softDelete` | `data: { is_deleted: true }` → `data: { Delete_at: new Date() }` |
| `bank.worker`/query khác | Lọc ví đang dùng: `Delete_at: null` |

### 3.2. Enum mới

| Enum | Giá trị cũ → mới | Nơi thay đổi |
|---|---|---|
| `Wallet.Type` | `cash/bank/ewallet/investment/debt` → `Cash/Bank/Saving/Banking` | sync, bank, seed |
| `Transaction.Type` | `thu/chi/transfer` → `Transaction/Transfer` | sync, bank.worker, ai |

**✅ Thu/chi (đã PO quyết):** `Transaction.Type` chỉ còn `Transaction/Transfer`. **Thu/chi được suy ra từ `Category.classify`** (Thu/Chi/Vay-no) qua `Idcategory` — không còn phụ thuộc vào Transaction table. Bank webhook sẽ để `Idcategory` trống (chờ AI phân loại), thu/chi xác định sau khi có category.

### 3.3. Seed — `src/Backend/prisma/seed.js`, `seed_user.js`

| Việc | Chi tiết |
|---|---|
| Seed Role | admin, user (giữ) |
| Seed Category default | `Create_by` = `idaccount` admin (đọc từ DB), `Is_default=true`, kèm `Keyword`, `Icon` |
| Seed ví Saving cứng | Mỗi account mới tạo 1 ví `Type='Saving'` |
| Seed account admin | `Email`, `Type='Basic'` |

---

## 4. Trình tự thực hiện

| Bước | Công việc | Ước lượng |
|---|---|---|
| **B1** | Viết lại `schema.prisma` (13 models) + `npx prisma validate` | 1 buổi |
| **B2** | Migration/reset DB + `prisma generate` | ½ buổi |
| **B2b** | **Backfill `Account.Email = User.Email`** (trước seed — đảm bảo NOT NULL/unique) | ½ buổi |
| **B3** | Sửa `auth` module (Account/User/OTP/Delete_at + đồng bộ email 2 bảng) | ½ buổi |
| **B4** | Sửa `admin` module (Category field mới + Is_group) | ½ buổi |
| **B5** | Sửa `sync` module (6 entity, xóa mềm, field mới, group+keyword) | 1 buổi |
| **B6** | Sửa `bank` module + worker (Provider/Bank_tran_id/Type/Amount dấu ±) | 1 buổi |
| **B7** | Sửa `ai`/`notification` (field tham chiếu) | ½ buổi |
| **B8** | Cập nhật `seed.js` (role, category default, ví Saving, backfill email) | ½ buổi |
| **B9** | Test toàn bộ (auth, sync, bank, admin) | 1 buổi |
| **B10** | Deploy lên Render + verify | ½ buổi |
| **Tổng** | | **~7.5 buổi** |

---

## 5. Checklist test sau khi sửa

- [ ] `POST /auth/register` → tạo account + user + **ví Saving cứng** + category default; **Account.Email == User.Email**
- [ ] Đổi email → cập nhật đồng bộ cả `Account.Email` + `User.Email`
- [ ] `POST /auth/login` / `refresh` / `forgot-password` (OTP theo Idaccount)
- [ ] `POST /api/sync/push` — 6 entity (wallet/transaction/budget/bill/goal/category) với field mới (category có `is_group`, `idgroup`, `keyword`)
- [ ] `GET /api/sync/pull` — trả field mới
- [ ] Xóa mềm: `Delete_at` được set, query lọc `Delete_at: null`
- [ ] Bank webhook: chống trùng `(Provider='Casso', Bank_tran_id)`, `Type='Transaction'`, **Amount giữ dấu ±**, `Create_at=when`, `Idcategory=NULL` (chờ phân loại) → worker phân loại sau
- [ ] Wallet: `Type='Banking'` chỉ tạo từ Casso (có `Id_bank_casso`); `Type='Bank'` user tự tạo không cần `Id_bank_casso`
- [ ] Admin: CRUD category field mới + Is_group, user list field mới

---

## 6. ⚠️ Rủi ro & điểm cần lưu ý

| # | Rủi ro | Ảnh hưởng | Giải pháp |
|---|---|---|---|
| 1 | **`Transaction.Type` mới không còn Thu/Chi** | Analytics A8 cần thu/chi | ✅ **Đã PO quyết**: suy thu/chi từ `Category.classify` (qua `Idcategory`). Đảm bảo mọi transaction có `Idcategory` hợp lệ (hoặc để trống chờ AI phân loại, không tính vào báo cáo cho tới khi có category). |
| 2 | **Category PK đổi từ `uuid` → `Idcategory`** | Admin/sync code cũ tham chiếu `uuid` | Đã xử lý trong mapping (giữ uuid làm PK, chỉ đổi tên) |
| 3 | **OTP cần Idaccount** — luồng quên mật khẩu phải tìm account trước | Auth | Thêm bước lookup account theo email trước khi tạo OTP |
| 4 | **Ví Saving cứng khi register** — cần seed đồng bộ | Wallet sync | Xử lý trong `auth.repository.createAccountWithUser` |
| 5 | **Partial unique không chuẩn Prisma** | Migration | Dùng raw SQL hoặc xử lý ở service |
| 6 | **Client-app chưa đổi** — gửi enum cũ | Sync lỗi | Lên kế hoạch riêng cho Client (đợt sau theo chỉ đạo PO) |

---

## 7. Phối hợp với Client-app (đợt sau)

> PO xác nhận: sửa CSDL → sửa backend → **sau đó** sửa Client-app. Kế hoạch Client sẽ lập riêng.

- [ ] Client `Wallet.type`: `cash/bank/ewallet/investment/debt` → `Cash/Bank/Saving/Banking`
- [ ] Client `Transaction.type`: `thu/chi/transfer` → `Transaction/Transfer` (thu/chi giờ suy từ `Category.classify`)
- [ ] Client field xóa mềm: `isDeleted` → `deleteAt`
- [ ] Client sync payload: field mới (`includeInTotal`, `walletId`, `provider`, `bankTranId`, `idgroup`, `keyword`...)
- [ ] Client Category: đồng bộ đầy đủ `idgroup` + `keyword` (theo quyết định PO — không giữ local-only)

---

## 8. ✅ Quyết định của PO (đã chốt 2026-08-26)

| # | Câu hỏi | Quyết định PO | Hệ quả triển khai |
|---|---|---|---|
| 1 | Phân biệt group vs con chưa nhóm trong Category | **Phương án A — thêm cột `Is_group`** | Category có `Is_group Boolean default FALSE`. Group: `Is_group=true`, `Idgroup=null`. Con: `Is_group=false`, `Idgroup` trỏ group (hoặc null nếu chưa nhóm). |
| 2 | User.Email vs Account.Email | **Cả 2 đều có email, PHẢI đồng bộ nhau. Thêm unique cho `User.Email`** | `Account.Email` (unique) = `User.Email` (unique). Register/đổi email → cập nhật cả 2 bảng cùng transaction. |
| 3 | `Wallet.Type` Bank vs Banking | **`Bank` = user tự tạo ví ngân hàng ảo; `Banking` = CHỈ tạo từ Casso (liên kết NH), user không tự tạo** | `Type='Banking'` → bắt buộc `Id_bank_casso NOT NULL`; `Type != 'Banking'` → `Id_bank_casso NULL`. |
| 4 | Thu/chi & giao dịch chưa phân loại | **Giữ `Amount` dấu ± — giao dịch webhook ghi TRƯỚC (chưa vội phân loại), phân loại category SAU** | `Amount` dương = vào, âm = ra (xác định dòng tiền ngay, không chờ category). Webhook: `Idcategory=NULL` lúc ghi → worker cập nhật `Idcategory` sau. Thu/chi hoàn chỉnh từ `Category.classify`. |
| 5 | Reset DB + seed | **Đồng ý — phải backfill `Account.Email = User.Email`** | Thêm bước backfill trước khi seed; không để NULL/trùng. |
| 6 | Tên field Prisma | **PO giao cho tôi quyết** | **Chốt: DB snake_case** (đúng `New_Database.md`), **Prisma field camelCase + `@map`** — code sạch, DB đúng chuẩn. |
| 7 | Có đồng bộ Category hoàn chỉnh ngay không? | **Đồng bộ hoàn chỉnh** — đảm bảo không xung đột sau này | CSDL mới gộp `Keyword` vào cột `Category.Keyword` + `Idgroup` tự tham chiếu → **chỉ cần sync entity `category` là đủ** (bao gồm group + keyword). KHÔNG tách bảng riêng. |

---

> 📌 Đã chốt đủ 7 điểm. Tôi bắt đầu B1 (viết schema.prisma mới) theo quyết định này.
