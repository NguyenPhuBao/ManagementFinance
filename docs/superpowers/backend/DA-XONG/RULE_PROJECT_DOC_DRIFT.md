# Tài liệu backend nói ngược mã và CSDL — hướng dẫn sửa từng dòng

**Ngày:** 2026-09-10 (đo lại tối cùng ngày, **sau** khi CSDL dev áp `database/7`–`11`)
· **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** 56 chỗ sửa tài liệu ở bốn tệp,
cộng ba việc sửa mã (hai việc đã có tài liệu xin riêng).

> ⛔ **2026-09-11 — soát lại sau `7675b35` / `f9d13c9`:** trong 56 chỗ, **11** đã sửa đúng,
> **31** chưa sửa, **12** sửa nhưng vẫn sai, **2** không còn áp dụng. Danh sách theo số dòng
> HEAD, cùng các khẳng định mới sai: `CAN-LAM/VERIFY_7675B35_REMAINING.md` mục 3. Số dòng trong tài liệu này là số
> dòng trước khi backend sửa.

> **Client không sửa tài liệu của backend.** `docs/Rule_Project/New_Database.md`,
> `Rule_project.md`, `Data_Security.md` và `docs/progress/Backend.md` do đội backend
> tạo, nên chỗ sai được ghi ở đây để backend tự sửa. Mục 8 liệt kê các dòng client
> **từng** viết thẳng vào các tệp ấy trước khi quy tắc này được đặt — từ nay không còn.

---

## 1. Tóm tắt

`New_Database.md` tự nhận là **Source of Truth** và `Rule_project.md` là quy tắc bắt
buộc; người mới và trợ lý AI của cả hai phía đọc chúng **trước** mã. Đo lại tối
2026-09-10, sau khi áp `database/7`–`11`:

| Nhóm | Nghĩa | Tệp | Số chỗ sửa |
|---|---|---|---|
| **Sửa tài liệu** | mã và CSDL đúng, tài liệu sai | `New_Database.md` (mục 2) | 39 |
| | | `Rule_project.md` (mục 3) | 13 |
| | | `Data_Security.md` (mục 4) | 2 |
| | | `docs/progress/Backend.md` (mục 4) | 2 |
| **Sửa mã** | tài liệu đúng ý đồ, mã chưa làm đúng | mục 5 | 3 |

So với bản đo buổi chiều (31 chỗ): **nhóm B** (3 chỗ) đã tự khớp khi áp
`database/7`–`11`; **25 mục cũ** của nhóm A và C được tách thành đúng những dòng cần
sửa; A23, D1, D2 chuyển sang mục 5 (việc của mã); và lượt đo lại tìm thêm **13 chỗ
mới** cùng loại mà bản chiều bỏ sót — đánh dấu *mới* trong cột "Mục cũ".

### Cách dùng tài liệu này

- Mỗi dòng ghi **số dòng đo ngày 2026-09-10 tối**, **nguyên văn** phần phải thay, và
  **nguyên văn** phần thay vào. Sửa **từ dưới lên** trong mỗi tệp để số dòng phía trên
  không trôi.
- Làm **mục 5.3** (`'ORC'` hay `'OCR'`) **trước** ND23 và RP06.
- RP12 chỉ sửa **sau** khi xong mục 5.1.
- Xong thì đổi *Ngày cập nhật* ở `New_Database.md` dòng 4 và `Rule_project.md`
  dòng 4, rồi chạy các câu kiểm ở mục 7.

---

## 2. `docs/Rule_Project/New_Database.md` — 39 chỗ

### 2.1. Mục 2 — bảng cột

| # | Dòng | Thay | Bằng | Căn cứ đo | Mục cũ |
|---|---|---|---|---|---|
| ND01 | 51 (`Account.Email`) | ô Ràng buộc `Unique` | `Unique khi Delete_at IS NULL (partial index account_Email_key)` | `pg_indexes`: `account_Email_key … WHERE ("Delete_at" IS NULL)` | A15 |
| ND02 | 52 (`Account.Username`) | ô Ràng buộc `Unique` | `Index idx_account_username — không unique (trùng Username hợp lệ nếu khác mật khẩu, Rule_project.md 11.4)` | `account_Username_key` không còn; có `idx_account_username` | A15 |
| ND03 | 54 (`Account.Status`) | ô Ràng buộc `` Check in (`Active`, `Inactive`, `PendingDelete`, `Deleted`) `` | `` Default 'Active'. Không có CHECK trong CSDL (quy ước: `Active`, `Inactive`, `PendingDelete`, `Deleted`) `` | `pg_constraint`: bảng `account` không có CHECK nào | A10 |
| ND04 | 55 (`Account.Type`) | ô Ràng buộc `` Check in (`Basic`, `Premium`) `` | `Default 'Basic'. Không có CHECK trong CSDL` | như ND03 | A10 |
| ND05 | chèn **sau** 55 | — | hai dòng ở 2.3 bên dưới | `information_schema.columns` | A3 |
| ND06 | 70 (`User.Email`) | ô Ràng buộc `Unique` | `Unique khi Delete_at IS NULL (partial index user_Email_key)` | `user_Email_key … WHERE ("Delete_at" IS NULL)` | A15 |
| ND07 | 88 (`Audit_log.Req_status`) | ô Ràng buộc `` Check in (`Accepted`, `Rejected`, `Interrupted`, `Pending`, `Processing`, `Pass`, `Fail`) `` | `` Default 'Pass'. Không có CHECK trong CSDL (quy ước: `Accepted`, `Rejected`, `Interrupted`, `Pending`, `Processing`, `Pass`, `Fail`) `` | bảng `audit_log` không có CHECK | mới |
| ND08 | 106 (`OTP_code.purpose`) | ô Ràng buộc `` Check in (`Register`, `Reset_password`, `Change_email`) `` | `` Không có CHECK trong CSDL (quy ước: `Register`, `Reset_password`, `Change_email`) `` | bảng `otp_code` không có CHECK | mới |
| ND09 | 169 (`Wallet.Status`) | ô Kiểu `Varchar(7)` | `Varchar(20)` | `character varying(20)`; `schema.prisma` `VarChar(20)`; `database/7` bước 4 | A4 |
| ND10 | 192 (`Budget.OverSpending`) | ô Ràng buộc `` Check in (`Stop`, `Over`) `` | `` Default 'Over'. Không có CHECK trong CSDL; `sync.validation.js:148` chỉ nhận `Stop`, `Over` `` | bảng `budget` chỉ có 4 CHECK, không cái nào cho cột này | mới |
| ND11 | 197 (`Budget.Time_recurrence`) | `` Check in (`Day`, `Week`, `Month`, `Quarter`, `Year`), NULL `` | `` Check in (`Week`, `Month`, `Quarter`, `Year`), NULL `` | `chk_budget_time_recurrence` không có `Day` | A6 |
| ND12 | 199 (`Budget.Note`) | ô Bảo mật `✅ Cho phép. Plaintext` | `✅ Cho phép. **ĐÃ MÃ HÓA AT-REST (AES-256-GCM)** & **Lọc sạch thẻ/CVV/pwd trước khi lưu**` (chép dòng 274) | `sync.repository.js:354, 375` gọi `prepareSafeNote` | A11 |
| ND13 | 221 (`Bill.Time_recurrence`) | như ND11 | như ND11 | `chk_bill_time_recurrence` không có `Day` | A6 |
| ND14 | 222 (`Bill.Time_notification`) | `` Check in (`1`, `3`, `5`, `7`), NULL `` | `` Default '3', NULL. Không có CHECK trong CSDL (quy ước: `1`, `3`, `5`, `7`) `` | `bill` chỉ có `chk_bill_amount`, `chk_bill_pay_status`, `chk_bill_time_recurrence` | A7 |
| ND15 | 225 (`Bill.Note`) | như ND12 | như ND12 | `sync.repository.js:416, 437` | A11 |
| ND16 | 245 (`Goal.Cycle_take_money`) | `` Check in (`Day`, `Week`, `Month`, `Quarter`, `Year`), NULL `` | `NULL. Không có CHECK trong CSDL` | `goal` chỉ có `chk_goal_current_amount`, `chk_goal_target_amount` | A8 |
| ND17 | 247 (`Goal.Status_complete`) | `` Check in (`True`, `False`) `` | `` Default 'False'. Không có CHECK trong CSDL (quy ước: `True`, `False`) `` | như ND16 | A8 |
| ND18 | 249 (`Goal.Time_recurrence`) | như ND16 | `NULL. Không có CHECK trong CSDL` | như ND16 | A8 |
| ND19 | 252 (`Goal.Note`) | như ND12 | như ND12 | `sync.repository.js:483, 509` | A11 |
| ND20 | chèn **sau** 252 | — | bốn dòng ở 2.3 bên dưới | `information_schema.columns`; `schema.prisma:268-271` | A1 |
| ND21 | chèn **sau** 268 | — | một dòng ở 2.3 bên dưới | `fk_transaction_goal … ON DELETE SET NULL`; `schema.prisma:292` | A2 |
| ND22 | 272 (`Transaction.Status`) | `` Check in (`Pending`, `Confirmed`, `Rejected`, `Fail`) `` | `` Default 'Confirmed'. Không có CHECK trong CSDL; `sync.validation.js:131` chỉ nhận `Pending`, `Confirmed`, `Rejected`, `Fail` `` | `transaction` chỉ có `chk_transaction_type`, `chk_transaction_nonzero_amount` | A5 |
| ND23 | 273 (`Transaction.Provider`) | `` Check in (`Manual`, `BankSync`, `SMS`, `ORC`, `Bill`) `` | `` Default 'Manual'. Không có CHECK trong CSDL; `sync.validation.js:125` nhận `Manual`, `BankSync`, `Casso`, `SMS`, `OCR`, `Bill` `` — **sau** mục 5.3 | như ND22; mục 5.3 | A5 |

### 2.2. Mục 3 — tóm tắt ràng buộc

| # | Dòng | Thay | Bằng | Căn cứ đo | Mục cũ |
|---|---|---|---|---|---|
| ND24 | 318 | `` - **Unique**: `Email`, `Username` `` | `` - **Unique**: `Email` khi `Delete_at IS NULL` (partial index `account_Email_key`) \| **Index**: `Username` (`idx_account_username`, **không** unique — `Rule_project.md` 11.4) `` | như ND01, ND02 | A15 |
| ND25 | 319 | `` - **Check**: `Status IN ('Active', 'Inactive', 'PendingDelete', 'Deleted')`; `Type IN ('Basic', 'Premium')` `` | `- **Check**: không có (giá trị Status, Type do tầng ứng dụng giữ)` | như ND03 | A10 |
| ND26 | 324 | `` - **Unique**: `Idaccount` (1 User ↔ 1 Account), `Email` `` | `` - **Unique**: `Idaccount` (1 User ↔ 1 Account), `Email` khi `Delete_at IS NULL` (partial index `user_Email_key`) `` | như ND06 | A15 |
| ND27 | 329 | `` - **Check**: `Req_status IN ('Accepted', 'Rejected', 'Interrupted', 'Pending', 'Processing', 'Pass', 'Fail')` `` | `- **Check**: không có` | như ND07 | mới |
| ND28 | 335 | `` - **Check**: `purpose IN ('Register', 'Reset_password', 'Change_email')`; `expires_at > created_at` `` | `- **Check**: không có` | như ND08 | mới |
| ND29 | 344 | `` - **Unique**: `(Create_by, NameCategory, Classify)` — Không trùng tên danh mục trong cùng phân loại của 1 tài khoản `` | xem 2.4 | `pg_indexes` | A12 |
| ND30 | 360 | cuối dòng, sau `` `Status IN ('Active', 'Inactive')` `` | thêm `` ; `(Type = 'Banking' AND Id_bank_casso IS NOT NULL) OR (Type <> 'Banking' AND Id_bank_casso IS NULL)` (`chk_wallet_banking_link`) `` | `chk_wallet_banking_link` có thật, tài liệu thiếu | mới |
| ND31 | 362 | cả dòng `- **Unique**: (Idaccount, Name) …` | xem 2.4 | `pg_indexes`: bốn partial unique index | A13 |
| ND32 | 368 | cả dòng `- **Check**: TotalAmount > 0; Spent >= 0; …` | `` - **Check**: `TotalAmount > 0`; `Threshold_Warning_Percent IS NULL OR (Threshold_Warning_Percent >= 0 AND Threshold_Warning_Percent <= 100)`; `Time_recurrence IS NULL OR Time_recurrence IN ('Week', 'Month', 'Quarter', 'Year')`; `End IS NULL OR End > Start`. (**Không** có CHECK cho `Spent`, `OverSpending`) `` | bốn `chk_budget_*`; tài liệu thiếu `chk_budget_end_after_start` | A6, A9, mới |
| ND33 | 375 | cả dòng `- **Check**: Amount > 0; Pay_status IN …; Time_recurrence IN ('Day', …); Time_notification IN …` | `` - **Check**: `Amount > 0`; `Pay_status IN ('Pending', 'Payed', 'Overdue')`; `Time_recurrence IS NULL OR Time_recurrence IN ('Week', 'Month', 'Quarter', 'Year')`. (**Không** có CHECK cho `Time_notification`) `` | ba `chk_bill_*` | A6, A7 |
| ND34 | 382 | cả dòng `- **Check**: Target_amount > 0; Current_amount >= 0; Status_complete IN …; Cycle_take_money IN …` | `` - **Check**: `Target_amount > 0`; `Current_amount >= 0`. (**Không** có CHECK cho `Status_complete`, `Cycle_take_money`, `Time_recurrence`) `` | hai `chk_goal_*` | A8 |
| ND35 | 388 | cuối dòng, sau `` `Idwallet_transfer` $\rightarrow$ `Wallet(Idwallet)` (`ON DELETE SET NULL`) `` | thêm `` ; `Idgoal` $\rightarrow$ `Goal(Idgoal)` (`ON DELETE SET NULL`) `` | `fk_transaction_goal` | A2 |
| ND36 | 389 | cả dòng `- **Check**: Type IN …; Status IN …; Provider IN (…'ORC'…); Amount != 0` | `` - **Check**: `Type IN ('Transaction', 'Transfer')`; `Amount != 0`. (**Không** có CHECK cho `Status`, `Provider`) `` | như ND22 | A5 |
| ND37 | 391 | `` - **Unique**: `(Provider, Bank_tran_id)` **WHERE Bank_tran_id IS NOT NULL** `` | `` - **Unique**: `uq_transaction_external ("Idaccount", "Provider", "Bank_tran_id")` — **không** có mệnh đề `WHERE` (hàng có `Bank_tran_id IS NULL` không va nhau vì PostgreSQL coi các NULL là khác nhau) `` | `pg_indexes`; `schema.prisma:310` | A14 |
| ND38 | 400 | `` - **Check**: `Expired > Create_at` `` | `- **Check**: không có` | bảng `refreshtoken` không có CHECK | mới |
| ND39 | 408 | `Toàn bộ 13 bảng (149 cột)` | `Toàn bộ 13 bảng (165 cột — đếm bằng câu truy vấn ở mục 7, CSDL dev, 2026-09-10 sau khi áp database/7–11)` | mục 7 → `13 bảng, 165 cột` | A16 |

### 2.3. Các dòng chèn thêm (ND05, ND20, ND21)

**ND05** — chèn sau dòng 55 (bảng `Account`):

```
| `Reason_Inactive` | text | NULL | Lý do Admin vô hiệu hoá tài khoản | ✅ Cho phép. Kiểm duyệt SĐT/Email/CCCD/thẻ/từ ngữ thô tục qua `validateReasonInactive` (`utils/content-filter.util.js`) | Xoá về NULL khi kích hoạt lại |
| `Countdown` | int | NULL | Số ngày còn lại của thời hạn chờ xoá (30 → 1); `0` sau khi xoá hẳn; NULL khi không chờ xoá | ✅ Cho phép. Plaintext | Theo trạng thái `PendingDelete` |
```

Đo: `Reason_Inactive` `text` NULL, `Countdown` `integer` NULL; `scheduleDeletion` ghi
`30` (`auth.repository.js:200`), `cancelDeletion` ghi `null` (`:212`),
`processFullSoftDelete` ghi `0` (`scheduler.service.js:49`).

**ND20** — chèn sau dòng 252 (bảng `Goal`):

```
| `Priority` | int | NULL | Thứ tự ưu tiên hiển thị: số thưa cách nhau 100; **NULL = chưa sắp, xếp cuối**; trùng số được phép | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `auto_deposit_amount` | decimal(18,2) | NULL | Số tiền trích tự động mỗi kỳ | ✅ Cho phép. Phân quyền `Idaccount` | Theo mục tiêu |
| `auto_deposit_wallet_id` | varchar(36) | NULL — **không có FK** | Ví nguồn bị trích tự động | ✅ Cho phép. Plaintext | Theo mục tiêu |
| `auto_deposit_last_run` | Timestamp | NULL | Lần trích tự động thành công gần nhất | ✅ Cho phép. Plaintext | Theo mục tiêu |
```

Đo: `integer`, `numeric(18,2)`, `character varying(36)`, `timestamp without time zone`,
đều NULL. Bảng `goal` chỉ có hai khoá ngoại (`fk_goal_account`, `fk_goal_wallet`) —
`auto_deposit_wallet_id` **không** có FK. Quy ước `Priority`:
`DA-XONG/2026-09-05-backend-goal-priority.md` mục 4.

**ND21** — chèn sau dòng 268 (bảng `Transaction`):

```
| `Idgoal` | varchar(36) | FK - Goal (`Idgoal`), NULL, `ON DELETE SET NULL` | Mục tiêu tiết kiệm mà khoản này nạp hoặc rút | ✅ Cho phép. Plaintext | Tối thiểu 5 năm |
```

### 2.4. Hai dòng unique dài (ND29, ND31)

**ND29** — thay cả dòng 344:

```
- **Unique** (hai partial index, **không** có `Classify`): `uq_category_owner_name ("Create_by", lower(regexp_replace(btrim(NORMALIZE("NameCategory", NFC)), '\s+', ' ', 'g'))) WHERE "Is_default" = false AND "Delete_at" IS NULL` — tên danh mục người dùng không trùng trong một tài khoản; `uq_category_default_name` cùng biểu thức, `WHERE "Is_default" = true AND "Delete_at" IS NULL` — danh mục mẫu không trùng nhau. Người dùng **được** trùng tên với danh mục mẫu (`Rule_project.md` 1.2).
```

**ND31** — thay cả dòng 362:

```
- **Unique** (bốn partial index, đều kèm `"Delete_at" IS NULL`): `uq_wallet_account_name_active ("Idaccount", "Name")` — không trùng tên ví trong một tài khoản; `uq_wallet_bank_active ("Id_bank_casso") WHERE "Id_bank_casso" IS NOT NULL` — một tài khoản ngân hàng chỉ tạo một ví Banking; `uq_wallet_default_active ("Idaccount") WHERE "Is_default" = true` — một ví mặc định mỗi tài khoản; `uq_wallet_saving_active ("Idaccount") WHERE "Type" = 'Saving'` — một ví Tiết kiệm mỗi tài khoản (đang xin bỏ: `CAN-LAM/WALLET_SAVING_INDEX.md`).
```

---

## 3. `docs/Rule_Project/Rule_project.md` — 13 chỗ

| # | Dòng | Thay | Bằng | Căn cứ đo | Mục cũ |
|---|---|---|---|---|---|
| RP01 | 69 | `3. **Migration:** Thực thi qua lệnh chuẩn hóa của Prisma để cập nhật lược đồ CSDL.` | Ghi quy trình **thật**: hiện có hai đường — `prisma/migrations/` (3 migration, ghi trong `_prisma_migrations`) và `database/N_*.sql` áp tay (tệp 5–11, không bảng nào ghi tệp nào đã áp). Backend chọn một quy ước rồi viết thứ tự áp tại đây — `CAN-LAM/DEV_DB_MIGRATIONS_7_11.md` mục 4.2 | `_prisma_migrations`: 3 dòng, dừng ở `20260901191107_fix_schema_align` | A19 |
| RP02 | 84 | `` `Account` $\rightarrow$ `Wallet` $\rightarrow$ `Category` $\rightarrow$ `CategoryGroup` $\rightarrow$ `CategoryGroupMembership` $\rightarrow$ `Goal` $\rightarrow$ `Bill` $\rightarrow$ `Budget` $\rightarrow$ `Transaction`. `` | `` `category` (10) $\rightarrow$ `wallet` (20) $\rightarrow$ `budget`, `bill`, `goal` (30) $\rightarrow$ `transaction` (40). Thao tác **xoá** chạy ngược lại: `transaction` (60) $\rightarrow$ `budget`/`bill`/`goal` (70) $\rightarrow$ `wallet` (80) $\rightarrow$ `category` (90) — `sync.service.js:46-63`. `` | `ENTITY_PRIORITY` và `getOperationWeight`; hai bảng nhóm đã DROP (`database/6`); mục 1.6 cùng tệp nói "không có bảng trung gian" | A17 |
| RP03 | 89 | `  * Sử dụng Database Trigger để ngăn người dùng tạo danh mục cá nhân trùng tên với danh mục mặc định của hệ thống.` | `  * Người dùng **được phép** tạo danh mục cá nhân trùng tên với danh mục mẫu hệ thống — trigger chéo cũ đã gỡ (database/5), xem mục 1.2.` | mục 1.2 cùng tệp (dòng 256); CSDL dev chỉ có 4 trigger, không cái nào trên `category` | A18 |
| RP04 | chèn **sau** 321 (hết mục 2.4) | — | khối ở 3.1 bên dưới | `uq_wallet_account_name_active` | A20 |
| RP05 | 334–344 (mục 3.2) | toàn bộ các gạch đầu dòng `Expense`/`Income`/`Transfer`/`Debt`/`Loan` | khối ở 3.2 bên dưới | `chk_transaction_type` chỉ nhận `Transaction`, `Transfer`; client đổi `thu` → `Transaction` + số dương, `chi` → `Transaction` + số âm (`sync_payload_normalizer.dart:65-72`); `/sync/push` không cộng trừ số dư — `wallet.balance` do client đẩy (`sync.repository.js:224, 242`) | mới |
| RP06 | 350–354 (mục 3.4) | danh sách `Provider` | khối ở 3.3 bên dưới — **sau** mục 5.3 | mục 5.3 | mới |
| RP07 | 395 | `* Sử dụng đánh số thứ tự thưa (10, 20, 30...) để người dùng có thể dễ dàng chèn một mục tiêu mới vào giữa danh sách mà không cần cập nhật lại toàn bộ các bản ghi khác.` | `* Đánh số thưa **cách nhau 100** (100, 200, 300…): chèn giữa hai mục tiêu chỉ ghi một hàng (150). **NULL = chưa sắp, xếp cuối.** Trùng số được phép — không đặt UNIQUE. Server phải giữ nguyên NULL khi đồng bộ (CAN-LAM/GOAL_PRIORITY_NULL_TO_ZERO.md).` | `DA-XONG/2026-09-05-backend-goal-priority.md` mục 4 — quy ước client đang ghi | mới |
| RP08 | 406 | `` * `'Paid'`: Đã thanh toán (đã sinh ra khoản chi tương ứng). `` | `` * `'Payed'`: Đã thanh toán (đã sinh ra khoản chi tương ứng). `` | `chk_bill_pay_status`; `sync.validation.js:140` | C1 |
| RP09 | 408 | `` * `'Skipped'`: Người dùng chủ động bỏ qua kỳ hóa đơn này (không thanh toán và không tính nợ). `` | `` * `'Skipped'`: **chưa có** — CHECK và `sync.validation.js:140` chỉ nhận `Pending`, `Payed`, `Overdue` (xin ở `CAN-LAM/README.md` mục 5). `` | như RP08 | C1 |
| RP10 | 412 | `` * `previous_bill_id`: Cột liên kết ID tới hóa đơn của kỳ liền trước. Dùng để: `` | `` * `previous_bill_id`: **chưa có** ở CSDL lẫn `schema.prisma` (xin ở `CAN-LAM/README.md` mục 3). Mục đích dự kiến: `` | `information_schema.columns`: bảng `bill` không có cột này | C2 |
| RP11 | 417 | `` * Khi tiếp nhận yêu cầu thanh toán hóa đơn hoặc đẩy giao dịch có gắn `Idbill`, Sync Engine kiểm tra … `'Paid'` … `` | `` * **Chưa có.** `transaction` chưa có cột `Idbill`, và `upsertTransaction` (`sync.repository.js:269-316`) không kiểm hoá đơn đã trả (xin ở `CAN-LAM/README.md` mục 3 và 4). Khi làm: từ chối khoản thanh toán thứ hai nếu hoá đơn kỳ đó đã `'Payed'`. `` | `transaction` không có `Idbill` | C3 |
| RP12 | 533–542 (11.3) | câu handshake ở 533 và khối JSON 535–542 | **Sau** mục 5.1: câu 533 thành "…từ chối kết nối kèm mã `ACCOUNT_DELETED` hoặc `ACCOUNT_INACTIVE` (kèm `reason_inactive`)"; khối JSON thay bằng hình dạng ở `CAN-LAM/AUTH_401_BODY_CODE.md` mục 4.1 — bỏ `"statusCode"`, thêm `"idaccount"`, `"reason_inactive"`, `"errors": null`, `"timestamp"` | `AUTH_401_BODY_CODE.md` mục 2.1, 2.3 | D1 |
| RP13 | 641 | `4. **Xác thực & Thu hồi phiên:** Token rotation, reuse detection, thu hồi toàn bộ token khi đổi mật khẩu hoặc xóa tài khoản.` | `4. **Xác thực & Thu hồi phiên:** Token rotation, reuse detection. Thu hồi toàn bộ token khi đổi mật khẩu, đặt lại mật khẩu, đăng xuất, và khi tài khoản bị xoá hẳn (hết 30 ngày chờ xoá). Gửi yêu cầu xoá **không** thu hồi token — người dùng dùng tiếp trong 30 ngày (mục 11.6).` | `revokeAllTokens` ở `auth.service.js:435` (đổi mật khẩu), `:489` (đặt lại), `auth.controller.js:90` (đăng xuất), `scheduler.service.js:89-96` (xoá hẳn); `deleteAccount` (`auth.service.js:494-511`) không gọi | mới |

### 3.1. RP04 — khối chèn sau dòng 321

```
### 2.5. Tên ví duy nhất trong một tài khoản
* Hai ví **đang hoạt động** (`Delete_at IS NULL`) của cùng một tài khoản không được trùng `Name` — thi hành bằng partial unique index `uq_wallet_account_name_active ("Idaccount", "Name")`. So khớp **chính xác** (phân biệt hoa thường).
* Ví đã xoá mềm không giữ chỗ tên.
* Vi phạm trả SQLSTATE `23505`; `/sync/push` hiện ánh xạ thành `UNIQUE_VIOLATION` (xin mã riêng `WALLET_NAME_DUPLICATE`: `CAN-LAM/WALLET_SAVING_INDEX.md`).
* Luật "một ví Tiết kiệm mỗi tài khoản" (`uq_wallet_saving_active`) **chưa** ghi thành luật ở đây — đang chờ quyết định giữ hay bỏ (`CAN-LAM/README.md` mục 12).
```

### 3.2. RP05 — khối thay dòng 334–344 (mục 3.2)

```
Cột `Type` chỉ nhận **hai** giá trị (`chk_transaction_type`):
* **`Transaction`** — thu hoặc chi, phân biệt bằng **dấu của `Amount`**: dương là thu, âm là chi (`chk_transaction_nonzero_amount` cấm `0`).
* **`Transfer`** — chuyển giữa hai ví: bắt buộc có `Idwallet` (ví nguồn) và `Idwallet_transfer` (ví đích).
* Không có loại riêng cho vay/nợ.

Số dư ví **không** do `/sync/push` cộng trừ: client tính số dư và đẩy lên qua `wallet.balance` như một trường thường (`sync.repository.js:224, 242`).
```

⚠️ `sync.validation.js:119` còn nhận `Expense`, `Income`, `Debt`, `Loan` — bốn giá trị
vượt qua lớp kiểm tra rồi vỡ CHECK. Đã xin sửa ở `CAN-LAM/SYNC_PUSH_ERROR_MAPPING.md`.

### 3.3. RP06 — khối thay dòng 350–354 (mục 3.4)

Viết **sau** mục 5.3. Nếu chọn `'OCR'`:

```
* `'Manual'`: Người dùng tự tạo trên ứng dụng — mặc định khi không gửi `provider` (`sync.repository.js:285`).
* `'BankSync'`: Webhook ngân hàng (SePay / Casso) — `workers/bank.worker.js:192`.
* `'OCR'`: Trích từ hoá đơn bằng AI OCR — `modules/ai/features/classify/classify.service.js`.
* `'SMS'`, `'Casso'`, `'Bill'`: lớp kiểm tra `sync.validation.js:125` nhận, nhưng hiện **không** mã backend nào ghi các giá trị này.
* Cột **không** có CHECK trong CSDL.
```

---

## 4. `Data_Security.md` và `docs/progress/Backend.md` — 4 chỗ

| # | Tệp : dòng | Thay | Bằng | Căn cứ đo | Mục cũ |
|---|---|---|---|---|---|
| DS01 | `Data_Security.md` : 219 | `Hệ thống đã hoàn tất triển khai và kiểm thử 100% các biện pháp kỹ thuật bảo mật sau:` | `Các biện pháp dưới đây đã có trong mã; bốn trigger ở 10.1 có trên CSDL dev từ 2026-09-10 (áp database/10, 11). Chưa có bộ test tự động nào trong repo cho các biện pháp này.` | quét `*.test.js`/`*.spec.js` trong `src/Backend`: 2 tệp, cả hai của AI phân loại | mới (từng là ghi chú dưới nhóm B) |
| DS02 | `Data_Security.md` : 226 | `` `trg_protect_audit_log` `` | `` `trg_protect_auditlog` `` | `pg_trigger`: `audit_log.trg_protect_auditlog` | mới |
| BK01 | `Backend.md` : 176 | `Để hỗ trợ đầy đủ các màn hình và chức năng trên **Client-app**, Backend tiếp tục triển khai các tính năng AI bổ trợ:` | `Để hỗ trợ đầy đủ Client-app, Backend còn **mười lăm** mục chờ làm ở docs/superpowers/backend/CAN-LAM/README.md mục 2 (đếm 2026-09-10) — đọc ở đó trước. Ngoài ra là các tính năng AI bổ trợ:` | README ấy, mục 2 | A21 |
| BK02 | `Backend.md` : 186–194 | tiêu đề `(100% PASS)` và năm dòng `Test/test_*.js` | Ghi rõ năm script **không có trong repo**: `.gitignore` dòng 76–77 bỏ qua `Test/` có chủ ý ("Local test scripts"), nên chúng chỉ chạy trên máy người viết. Muốn giữ làm bằng chứng thì `git add -f` các tệp ấy; nếu không, bỏ chữ "100% PASS" khỏi tiêu đề | không có thư mục `src/Backend/Test` trên máy client; `.gitignore:76-77` | A22 |

`Backend.md` dòng 237 và 265 (401 mang `code`) và `Rule_project.md` dòng 570, 672,
`Data_Security.md` dòng 242, `New_Database.md` dòng 422 **đúng ý đồ** — giữ nguyên câu,
sửa mã ở mục 5.1 và 5.2.

---

## 5. Sửa mã — 3 việc

### 5.1. Body 401 không mang `code` (D1, A23)

`ResponseHandler.unauthorized(res, message)` ở `core/response-handler.js:32` chỉ nhận
hai tham số, nên `code`, `idaccount`, `reason_inactive` mà `middleware/auth.js:89-93`
truyền vào **rơi mất**. Đo lại 2026-09-10 tối: chữ ký hàm vẫn như cũ. Hướng dẫn đầy đủ:
[`AUTH_401_BODY_CODE.md`](./AUTH_401_BODY_CODE.md) (mục 13 của `README.md`).

### 5.2. Bộ lọc ghi chú bắt nhầm (D2)

`utils/content-filter.util.js` vẫn ở commit `1f1f938`. Hướng dẫn đầy đủ:
[`SYNC_NOTE_FILTER_REWRITE.md`](./SYNC_NOTE_FILTER_REWRITE.md) (mục 10 của `README.md`).

### 5.3. `Provider`: `'ORC'` hay `'OCR'` — chọn một (mới)

Hệ thống đang tự mâu thuẫn:

| Chỗ | Ghi |
|---|---|
| Migration `20260901090000_align_new_database` dòng 64 | đổi dữ liệu `'ORC'` → `'OCR'` |
| `Rule_project.md` 3.4 (dòng 354) | `'OCR'` |
| `modules/ai/features/classify/classify.service.js:419` và `:471` | **ghi `'ORC'`** |
| `modules/sync/sync.validation.js:125` | nhận **cả hai** |
| `modules/sync/sync.repository.js:284` | coi cả hai là nguồn tự động (`Pending`) |
| CSDL dev hôm nay | 44 giao dịch, **đều** `Manual` — chưa hàng nào mang `ORC`/`OCR` |

Đề xuất chọn **`'OCR'`** (khớp migration và `Rule_project.md`): sửa hai chỗ ở
`classify.service.js`, bỏ `'ORC'` khỏi `sync.validation.js:125` (và câu báo lỗi dòng
127) cùng `sync.repository.js:284`. CSDL dev chưa có hàng nào phải đổi. Rồi làm ND23
và RP06.

Client **không** gửi `provider` lên (hợp đồng đồng bộ không có trường này), nên việc
đổi không cần client làm gì.

---

## 6. Thứ tự đề xuất

1. Mục 5.3, rồi ND23, ND36, RP06.
2. Các dòng còn lại của mục 2, 3, 4 — sửa từ dưới lên trong từng tệp.
3. Mục 5.1, rồi RP12.
4. Mục 5.2.
5. Đổi *Ngày cập nhật* ở hai tệp, chạy mục 7.

---

## 7. Kiểm lại sau khi sửa

Chạy trên CSDL, **chỉ đọc**, rồi so từng dòng với tài liệu.

Đếm bảng và cột (ND39):

```sql
SELECT COUNT(DISTINCT table_name) AS bang, COUNT(*) AS cot
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name <> '_prisma_migrations';
```

Mọi CHECK (ND03–ND04, ND07–ND08, ND10–ND11, ND13–ND14, ND16–ND18, ND22–ND23, ND25, ND27–ND28, ND30, ND32–ND34, ND36, ND38):

```sql
SELECT conrelid::regclass AS bang, conname, pg_get_constraintdef(oid)
FROM pg_constraint WHERE contype = 'c' ORDER BY 1, 2;
```

Mọi unique index, kể cả partial (ND01–ND02, ND06, ND24, ND26, ND29, ND31, ND37) — dùng
`pg_indexes`, **không** dùng `pg_constraint` (partial index không hiện ở đó):

```sql
SELECT tablename, indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND indexdef ILIKE '%UNIQUE%'
ORDER BY 1, 2;
```

Cột và khoá ngoại (ND05, ND09, ND20, ND21, ND35):

```sql
SELECT table_name, column_name, data_type, character_maximum_length, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name, column_name) IN (('account','Reason_Inactive'), ('account','Countdown'),
       ('wallet','Status'), ('goal','Priority'), ('goal','auto_deposit_amount'),
       ('goal','auto_deposit_wallet_id'), ('goal','auto_deposit_last_run'), ('transaction','Idgoal'));

SELECT conrelid::regclass, conname, pg_get_constraintdef(oid)
FROM pg_constraint WHERE contype = 'f' AND conrelid IN ('goal'::regclass, 'transaction'::regclass);
```

Trigger (DS02):

```sql
SELECT c.relname, t.tgname FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
WHERE NOT t.tgisinternal ORDER BY 1, 2;
```

Kỳ vọng hôm nay (CSDL dev, 2026-09-10 tối): 13 bảng, 165 cột; 17 CHECK; bốn trigger
`audit_log.trg_protect_auditlog`, `bank_account.trg_check_bank_account_encrypted`,
`transaction.trg_protect_transaction`, `user.trg_check_phone_encrypted`.

---

## 8. Các dòng client từng viết thẳng vào tài liệu backend

Trước khi quy tắc "client không sửa tài liệu backend" được đặt (2026-09-10), client đã
chèn hoặc sửa các dòng dưới đây. Đo bằng `git blame -e` trên `HEAD` ngày 2026-09-10 tối
(tác giả `quangtadd`; các dòng mang commit gộp `bef37d3` là do giải xung đột khi gộp
`main`, nội dung gốc của backend nên không liệt kê).

| Tệp | Dòng | Commit | Nội dung |
|---|---|---|---|
| `Rule_project.md` | 195 | `6af737e` | sửa đường dẫn liên kết tới `Project.md` |
| `Rule_project.md` | 294–295 | `e36c555`, `1f04f27` | ghi chú ⚠️ về luật ví mặc định và các partial unique index của `wallet` |
| `Rule_project.md` | 302–317 | `8490caa`, `8449323` | mục 2.3 "Loại ví" viết lại theo `chk_wallet_type` (ba loại chọn được, `Banking` do hệ thống tạo), trỏ về mã client và G27 |
| `docs/progress/Backend.md` | 115, 123 | `6af737e` | sửa đường dẫn liên kết |
| `docs/progress/Client-app.md` | 4–31 | `6af737e`, `a9e1e70` | khối ⚠️ "đây là kế hoạch, không phải bảng trạng thái" |
| `docs/progress/Client-app.md` | 83–93 | `6863db6` | khối ⚠️ `join_account` đã gỡ, mâu thuẫn với mục 8 |
| `docs/progress/Client-app.md` | 286–296 | `a9e1e70` | khối ⚠️ `notification.new` không tồn tại, payload hai hình dạng |

Nội dung các dòng ấy đúng với hệ thống lúc viết. Backend tự quyết **giữ**, **viết
lại theo giọng của tài liệu**, hay **xoá**; client sẽ không sửa chúng thêm.

---

## 9. Vì sao client quan tâm

Client không đọc các tệp này lúc chạy, nhưng tài liệu của client trỏ vào
`New_Database.md` như nguồn sự thật về lược đồ, và hai lỗi im lặng của client từng bắt
nguồn từ việc tin một tài liệu thay vì đo: bốn loại ví của giao diện cũ (`ewallet`,
`debt`) vỡ CHECK mà không ai biết, và kết luận "không có unique index nào" ngày
2026-09-09. Mỗi dòng sai ở đây là một lần như thế đang chờ.
