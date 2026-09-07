# Kế hoạch Mapping — Chuyển đổi hoàn toàn sang CSDL mới

> **Ngày:** 2026-08-26
> **Mục đích:** Thay thế CSDL hiện tại (13 models) bằng CSDL mới thiết kế lại (`New_Database.md` — 13 bảng)
> **Phạm vi:** Backend PostgreSQL + Prisma schema + Sync API

---

## 0. Tóm tắt chiến lược

| Chiến lược | Mô tả | Ưu điểm |
|---|---|---|
| **Không migrate trực tiếp dữ liệu cũ** | CSDL mới có cấu trúc khác nhiều (đổi PK category, đổi cơ chế xóa mềm, thêm enum) | Tránh rủi ro mất data, đơn giản hóa |
| **Tạo bảng mới + seed lại** | Dựng lại toàn bộ bảng theo `New_Database.md`, seed dữ liệu nền (role, danh mục default, ví Saving) | Sạch, nhất quán |
| **Giữ nguyên các dữ liệu hệ thống cần thiết** | Role, tài khoản admin/user, refresh token (đang dùng) | Không làm mất phiên đăng nhập |

> 💡 Đây là đồ án — dữ liệu người dùng thật không nhiều. Chọn **tạo mới + seed** thay vì migrate phức tạp là hợp lý. Nếu sau này cần giữ data, sẽ viết script chuyển đổi riêng.

---

## 1. Ma trận mapping bảng (Hiện tại → Mới)

### 1.1 Bảng GIỮ NGUYÊN (không đổi hoặc đổi nhẹ)

| CSDL hiện tại | CSDL mới | Loại | Ghi chú |
|---|---|---|---|
| `role` | `Role` | ✅ Giữ nguyên | Chỉ đổi tên field PascalCase |
| `account` | `Account` | 🟡 Đổi nhẹ | + `Email`, + `Type`; `scheduled_delete_at` → `Delete_at` |
| `User` | `User` | 🟡 Đổi nhẹ | `location` → `Country_code` |
| `refreshtoken` | `RefreshToken` | ✅ Giữ nguyên | Giữ y hệt CSDL cũ |
| `otp_code` | `OTP_code` | 🟡 Đổi nhẹ | + `Idaccount` FK; bỏ FK Email |

### 1.2 Bảng ĐỔI CẤU TRÚC (mapping cột)

| CSDL hiện tại | CSDL mới | Loại | Mapping cột |
|---|---|---|---|
| `auditlog` | `Audit_log` | 🔄 Đổi cột | `action` → `Request`; `time` → `TimeReq`; + `TimeRes`; bỏ `details` |
| `category` | `Category` | 🔴 Đổi lớn | `uuid` → `Idcategory` (PK); `namecategory` → `NameCategory`; `created_by` → `Create_by`; + `Is_group`, `Idgroup`, `Keyword`, `Icon`, `Delete_at` |
| `wallet` | `Wallet` | 🟡 Đổi | + `Id_bank_casso`, `Status`, `IncludeInTotal`, `Is_default`; `colour` → `Color`; `is_deleted` → `Delete_at` |
| `budget` | `Budget` | 🟡 Đổi | `amount` → `TotalAmount`; `period` → `Recurrence`+`Time_recurrence`; `start_date` → `Start`; `end_date` → `End`; + `Spent`, `Remaining`, `PercentSpent`, `OverSpending`, `OverAmount`; `is_deleted` → `Delete_at` |
| `bill` | `Bill` | 🟡 Đổi | + `Idwallet`, `Idcategory`; `is_paid` → `Pay_status`; `recurrence` → `Recurrence`+`Time_recurrence`; `colour` → `Color`; `is_deleted` → `Delete_at` |
| `goal` | `Goal` | 🟡 Đổi | + `Idwallet`; `is_completed` → `Status_complete`; `colour` → `Color`; `is_deleted` → `Delete_at` |
| `transaction` | `Transaction` | 🟡 Đổi | `date` → `Create_at`; + `Update_at`, `Delete_at`, `Wallet_Transfer`; `external_transaction_id` → `Bank_tran_id`; `provider` giữ (chuẩn hóa `manual→Manual`); `is_deleted` → `Delete_at` |
| `bank_account` | `Bank_account` | ✅ Giữ gần nguyên | `casso_account_id` → `Id_casso_account`; + `Delete_at` |

---

## 2. Mapping chi tiết từng bảng

### 2.1. Role — ✅ Giữ nguyên
| Cũ | Mới | Ghi chú |
|---|---|---|
| `idrole` | `Idrole` | int PK auto |
| `rolename` | `Rolename` | unique |
| `description` | `Description` | text NULL |

**Data seed**: giữ nguyên 2 role hiện có (admin, user).

---

### 2.2. Account — 🟡 Đổi nhẹ
| Cũ | Mới | Xử lý |
|---|---|---|
| `idaccount` | `Idaccount` | int PK auto (giữ) |
| `idrole` | `Idrole` | FK Role |
| ❌ không có | `Email` | **Thêm** — lấy từ `User.email` (nếu có) |
| `username` | `Username` | giữ |
| `password` | `Password` | giữ (hash) |
| `status` | `Status` | giữ enum |
| ❌ không có | `Type` | **Thêm** — default `Basic` |
| `created_at` | `Create_at` | default Getdate() |
| `updated_at` | `Update_at` | NULL |
| `scheduled_delete_at` | `Delete_at` | map trực tiếp |

**⚠️ Lưu ý**: `Email` cần unique — đảm bảo không trùng khi seed.

---

### 2.3. User — 🟡 Đổi nhẹ
| Cũ | Mới | Xử lý |
|---|---|---|
| `iduser` | `Iduser` | int PK |
| `idaccount` | `Idaccount` | FK Account |
| `fullname` | `Fullname` | giữ |
| `email` | `Email` | **giữ + thêm unique** — phải **đồng bộ với `Account.Email`** (cùng transaction khi đổi) |
| `phone` | `Phone` | giữ |
| `address` | `Address` | giữ |
| `location` | `Country_code` | map (char 5 → char 4) |
| `created_at` / `updated_at` | `Create_at` / `Update_at` | giữ |
| ❌ | `Delete_at` | **Thêm** |

> ⚠️ **Email đồng bộ 2 bảng**: `Account.Email` (unique) = `User.Email` (unique). Khi register/đổi email → cập nhật **cả 2 bảng** trong 1 transaction. `findAccountByEmail` query `account` (không còn `user`).

---

### 2.4. Audit_log — 🔄 Đổi cột
| Cũ | Mới | Xử lý |
|---|---|---|
| `idlog` | `Idlog` | int PK auto |
| `idaccount` | `Idaccount` | FK Account |
| `action` | `Request` | map (Varchar 200) |
| `time` | `TimeReq` | map |
| ❌ | `TimeRes` | **Thêm** |

---

### 2.5. OTP_code — 🟡 Đổi
| Cũ | Mới | Xử lý |
|---|---|---|
| `id` | `Id_otp` | int PK auto |
| ❌ | `Idaccount` | **Thêm** FK Account |
| `email` | `Email` | giữ (bỏ FK) |
| `code_hash` | `code_hash` | giữ |
| `purpose` | `purpose` | giữ |
| `is_used` | `is_used` | giữ |
| `expires_at` / `created_at` | giữ | giữ |

---

### 2.6. Category — 🔴 Đổi lớn nhất
| Cũ | Mới | Xử lý |
|---|---|---|
| `uuid` (PK) | `Idcategory` | **Giữ giá trị uuid hiện có** làm PK (tránh vỡ FK transaction/budget) |
| `idcategory` (int) | ❌ bỏ | xóa cột int |
| `namecategory` | `NameCategory` | đổi tên |
| `classify` | `Classify` | giữ |
| `is_default` | `Is_default` | giữ |
| ❌ | `Is_group` | **Thêm** (Boolean default FALSE) — phân biệt group vs con chưa nhóm |
| `created_by` | `Create_by` | giữ — **Default = `idaccount` của admin (đọc từ DB khi seed)**; danh mục default toàn cục do admin quản lý |
| ❌ | `Idgroup` | **Thêm** — tự tham chiếu |
| ❌ | `Keyword` | **Thêm** |
| ❌ | `Icon` | **Thêm** |
| `created_at` / `updated_at` | giữ | giữ |
| ❌ | `Delete_at` | **Thêm** |

**⚠️ Chiến lược PK**: Giữ `uuid` làm PK của `Category` (đổi tên cột thành `Idcategory`) — vì `transaction.category_id` và `budget.category_id` đang tham chiếu tới `category.uuid`. Tránh phải migrate lại FK.

**✅ Group & Keyword (theo CSDL mới)**: CSDL mới **KHÔNG tách bảng riêng** — `Keyword` là 1 cột (varchar 500, cách nhau dấu `,`), `Idgroup` là tự tham chiếu trong chính bảng `Category`. → **Chỉ sync entity `category` là đủ** (bao gồm group + keyword), không cần `category_keywords`/`category_group_memberships` như đề xuất cũ của teammate. (Quyết định PO 2026-08-26.)

---

### 2.7. Bank_account — ✅ Giữ gần nguyên
| Cũ | Mới | Xử lý |
|---|---|---|
| `id` | `Id_bank_account` | giữ uuid |
| `idaccount` | `Idaccount` | giữ |
| `casso_account_id` | `Id_casso_account` | đổi tên (unique) |
| `account_number` / `account_name` / `bank_name` | giữ | giữ |
| `balance` | `Balance` | giữ |
| `connect_status` | `Connect_status` | giữ |
| `created_at` / `updated_at` | giữ | giữ |
| ❌ | `Delete_at` | **Thêm** |

---

### 2.8. Wallet — 🟡 Đổi
| Cũ | Mới | Xử lý |
|---|---|---|
| `id` | `Idwallet` | giữ uuid |
| `idaccount` | `Idaccount` | giữ |
| ❌ | `Id_bank_casso` | **Thêm** FK Bank_account |
| `name` | `Name` | giữ |
| `type` | `Type` | **⚠️ đổi enum** (xem mục 4): `Bank` = user tự tạo ví ngân hàng ảo; `Banking` = CHỈ tạo từ Casso (user không tự tạo) |
| `balance` / `currency` | giữ | giữ |
| ❌ | `Status` | **Thêm** default Active |
| ❌ | `IncludeInTotal` | **Thêm** default TRUE |
| `is_default` | `Is_default` | giữ |
| `icon` / `colour` | `Icon` / `Color` | đổi tên |
| `is_deleted` | `Delete_at` | **đổi cơ chế** |
| `created_at` / `updated_at` | giữ | giữ |

---

### 2.9. Budget — 🟡 Đổi
| Cũ | Mới | Xử lý |
|---|---|---|
| `id` | `Idbudget` | giữ uuid |
| `idaccount` | `Idaccount` | giữ |
| `category_id` | `Idcategory` | giữ (tham chiếu Category.Idcategory) — **nullable** (NULL = ngân sách tổng) |
| `amount` | `TotalAmount` | đổi tên |
| ❌ | `Spent` / `Remaining` / `PercentSpent` | **Thêm** |
| ❌ | `OverSpending` / `OverAmount` | **Thêm** |
| `start_date` / `end_date` | `Start` / `End` | đổi tên |
| `period` | `Recurrence` + `Time_recurrence` | tách |
| `note` | `Note` | giữ |
| `is_deleted` | `Delete_at` | đổi cơ chế |
| `created_at` / `updated_at` | giữ | giữ |

---

### 2.10. Bill — 🟡 Đổi
| Cũ | Mới | Xử lý |
|---|---|---|
| `id` | `Idbill` | giữ uuid |
| `idaccount` | `Idaccount` | giữ |
| ❌ | `Idwallet` | **Thêm** FK Wallet (**BẮT BUỘC** — chọn ví khi tạo bill) |
| ❌ | `Idcategory` | **Thêm** FK Category (**BẮT BUỘC** — chọn danh mục khi tạo bill) |
| `name` | `Name` | giữ |
| `amount` | `Amount` | giữ |
| `due_date` | `due_date` | giữ |
| `is_paid` | `Pay_status` | đổi tên |
| `recurrence` | `Recurrence` + `Time_recurrence` | tách |
| `icon` / `colour` | `Icon` / `Color` | đổi tên |
| `note` | `Note` | giữ |
| `is_deleted` | `Delete_at` | đổi cơ chế |
| `created_at` / `updated_at` | giữ | giữ |

---

### 2.11. Goal — 🟡 Đổi
| Cũ | Mới | Xử lý |
|---|---|---|
| `id` | `Idgoal` | giữ uuid |
| `idaccount` | `Idaccount` | giữ |
| ❌ | `Idwallet` | **Thêm** FK Wallet (**NULL** = chưa liên kết ví đích; gán lần đầu khi nạp tiền) |
| `name` | `Name` | giữ |
| `target_amount` / `current_amount` | giữ | giữ |
| `target_date` | `Target_date` | giữ |
| `is_completed` | `Status_complete` | đổi tên |
| `icon` / `colour` | `Icon` / `Color` | đổi tên |
| `note` | `Note` | giữ |
| `is_deleted` | `Delete_at` | đổi cơ chế |
| `created_at` / `updated_at` | giữ | giữ |

---

### 2.12. Transaction — 🟡 Đổi
| Cũ | Mới | Xử lý |
|---|---|---|
| `id` | `Idtran` | giữ uuid |
| `idaccount` | `Idaccount` | giữ |
| `wallet_id` | `Idwallet` | giữ |
| `category_id` | `Idcategory` | giữ (có thể NULL — chờ phân loại) |
| `amount` | `Amount` | giữ + **giữ dấu ±** (dương = vào, âm = ra) |
| `type` | `Type` | **⚠️ đổi enum** (xem mục 4): `Transaction/Transfer` |
| `provider` | `Provider` | **giữ** (đã có sẵn!) |
| `note` | `Note` | giữ |
| `images` | `Images` | giữ |
| `date` | `Create_at` | **map** — date trở thành Create_at |
| ❌ | `Update_at` / `Delete_at` | **Thêm** |
| ❌ | `Wallet_Transfer` | **Thêm** |
| `external_transaction_id` | `Bank_tran_id` | đổi tên |
| `is_deleted` | `Delete_at` | đổi cơ chế |

**✅ Luồng webhook (PO quyết):** Casso bắn → **ghi transaction TRƯỚC** (Amount giữ dấu, `Idcategory=NULL`, `Provider='Casso'`, `Bank_tran_id=tid`) → **phân loại category SAU** (AI/worker cập nhật `Idcategory`). Thu/chi suy từ `Category.classify` sau khi có category (hoặc tạm suy từ dấu Amount).

**⚠️ Chống trùng**: Cũ dùng `@@unique([provider, external_transaction_id])` → Mới dùng unique `(Provider, Bank_tran_id)` + check đồng bộ.

---

### 2.13. RefreshToken — ✅ Giữ nguyên
| Cũ | Mới | Ghi chú |
|---|---|---|
| `idtoken` | `Idtoken` | giữ |
| `token_hash` | `Token_hash` | giữ unique |
| `idaccount` | `Idaccount` | giữ |
| `idrole` | `Idrole` | giữ default 2 |
| `expiry` / `revoked` / `device_name` / `ip_address` / `user_agent` | giữ | giữ |
| `created_at` / `updated_at` | `Create_at` / `Update_at` | giữ |

---

## 3. Cơ chế xóa mềm — Chuyển đổi

| Cũ | Mới | Quy tắc |
|---|---|---|
| `is_deleted Boolean default false` | `Delete_at Timestamp NULL` | NULL = đang dùng; có giá trị = đã xóa |

**Công thức chuyển đổi khi có dữ liệu cũ:**
```sql
-- is_deleted = false  → Delete_at = NULL
-- is_deleted = true   → Delete_at = updated_at (hoặc NOW())
UPDATE <table> SET delete_at = NULL WHERE is_deleted = false;
UPDATE <table> SET delete_at = COALESCE(updated_at, NOW()) WHERE is_deleted = true;
```

---

## 4. ✅ Thống nhất enum — QUYẾT ĐỊNH: tuân theo CSDL mới hoàn toàn

> ✅ **Đã PO xác nhận (2026-08-26):** Tuân theo CSDL mới hoàn toàn. Sau khi sửa CSDL sẽ sửa luôn cả Backend & Client. Không giữ enum cũ.

| Bảng/Cột | CSDL cũ (bỏ) | CSDL mới (CHUẨN — áp dụng) | Client-app (sẽ sửa sau) |
|---|---|---|---|
| `Transaction.Type` | `thu/chi/transfer` | **`Transaction/Transfer`** | Sẽ đổi theo CSDL mới |
| `Wallet.Type` | `cash/bank/ewallet/investment/debt` | **`Cash/Bank/Saving/Banking`** | Sẽ đổi theo CSDL mới |

> 💡 Hệ quả: Backend sửa trước theo enum mới; Client-app được điều chỉnh trong đợt sửa sau (xem `Mapping_Backend_Plan.md` → phần phối hợp Client).

> ✅ **Bổ sung (PO quyết 2026-08-26):**
> - Thu/chi **không phụ thuộc vào Transaction table** — suy từ `Category.classify` (Thu/Chi/Vay-no) qua `Idcategory`. `Transaction.Type` chỉ còn `Transaction/Transfer`.
> - **Giữ `Amount` dấu ±** (dương = vào, âm = ra) → xác định dòng tiền NGAY không chờ phân loại. Webhook ghi transaction TRƯỚC (`Idcategory=NULL`) → phân loại category SAU.
> - `Wallet.Type`: `Bank` = user tự tạo ví ngân hàng ảo; `Banking` = CHỈ tạo từ liên kết Casso (kèm `Id_bank_casso`).
> - Category thêm `Is_group` (phân biệt group vs con chưa nhóm).
> - `User.Email` unique + **đồng bộ với `Account.Email`**.

---

## 5. Trình tự thực hiện (các bước)

### Bước 1 — Chuẩn bị
- [ ] Xác nhận enum (mục 4) với PO
- [ ] Backup CSDL hiện tại (pg_dump / Supabase backup)

### Bước 2 — Viết lại `schema.prisma` theo CSDL mới
- [ ] 13 models mới (đặt tên theo `New_Database.md`)
- [ ] Thêm relation, index, unique, check theo ràng buộc mới
- [ ] `npx prisma validate` — kiểm tra cú pháp

### Bước 3 — Migration
- [ ] **Tạo DB mới** (hoặc reset DB) — vì cấu trúc khác quá nhiều
- [ ] `npx prisma migrate dev --name new_database_v2` (tạo schema mới)
- [ ] `npx prisma generate`

### Bước 4 — Seed dữ liệu nền
- [ ] Seed `Role` (admin, user)
- [ ] Seed `Category` default toàn cục (`Create_by` = `idaccount` admin **đọc từ DB**) + keyword
- [ ] Seed ví `Saving` cứng cho mỗi account mới
- [ ] `npx prisma db seed`

### Bước 5 — Cập nhật code backend (repository/service)
- [ ] Đổi tên field trong toàn bộ module (auth, admin, sync, bank, ai, notification)
- [ ] Cập nhật logic `is_deleted` → `Delete_at`
- [ ] Cập nhật logic chống trùng `(provider, external_transaction_id)` → `(Provider, Bank_tran_id)`
- [ ] Cập nhật sync API theo field mới

### Bước 6 — Kiểm thử
- [ ] Auth (login/register/refresh/OTP)
- [ ] Sync push/pull (6 entity)
- [ ] Bank webhook (chống trùng)
- [ ] Admin (user list, category)

### Bước 7 — Deploy
- [ ] Push code → Render
- [ ] Verify production

---

## 6. Rủi ro & Giảm thiểu

| Rủi ro | Mức độ | Giảm thiểu |
|---|---|---|
| Đổi enum Wallet.Type/Transaction.Type gây vỡ Client | 🔴 Cao | Xác nhận enum trước; cập nhật Client cùng lúc |
| Mất dữ liệu hiện có khi reset DB | 🟡 TB | Backup trước; đồ án data ít |
| Category PK đổi → vỡ FK transaction/budget | 🟡 TB | Giữ uuid làm PK (mục 2.6) |
| Cơ chế xóa mềm đổi → query cũ sai | 🟡 TB | Sửa đồng bộ trong Bước 5 |
| Partial unique không chuẩn Prisma | 🟢 Thấp | Dùng raw SQL migration |

---

## 7. Ước lượng công việc

| Hạng mục | Ước lượng |
|---|---|
| Viết schema.prisma mới (13 models) | 1 buổi |
| Migration + reset DB + seed | ½ buổi |
| Cập nhật repository/service (6 module) | 1–2 buổi |
| Cập nhật sync + bank logic | 1 buổi |
| Test toàn bộ | 1 buổi |
| **Tổng** | **~5 buổi** |
