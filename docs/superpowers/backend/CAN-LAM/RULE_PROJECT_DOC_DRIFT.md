# `docs/Rule_Project/` và tài liệu tiến độ backend nói ngược mã và CSDL — bảng đối chiếu

**Ngày:** 2026-09-10 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** chỉ
sửa tài liệu, không đụng mã, không migration.

Các tệp dưới đây do **đội backend giữ**, nên client không sửa thẳng mà ghi lại ở
đây. Ngoại lệ duy nhất: một ghi chú client chèn vào `Rule_project.md` 2.1 (dòng
294) hôm 2026-09-10, về các partial unique index của `wallet`.

---

## 1. Tóm tắt

`New_Database.md` tự nhận là **Source of Truth** và ghi *Ngày cập nhật:
2026-09-10* (dòng 2 và 4). `Rule_project.md` là quy tắc bắt buộc. Người mới — và
trợ lý AI của cả hai phía — đọc chúng **trước** mã. Đo ngày 2026-09-10, sau lần
gộp `main` (`bef37d3`), thấy **31** chỗ lệch, chia bốn nhóm theo *cần sửa ở đâu*:

| Nhóm | Nghĩa là | Việc | Số chỗ |
|---|---|---|---|
| **A** | Tài liệu sai hoặc lạc hậu so với **cả** mã lẫn CSDL | Sửa tài liệu | 23 |
| **B** | Tài liệu đúng với tệp `database/7`–`11`, chỉ là CSDL dev chưa áp | **Không** sửa tài liệu — tự khớp khi xong mục 11 `README.md` | 3 |
| **C** | Tài liệu mô tả tính năng **chưa có** như thể đã có | Ghi rõ "chưa có", trỏ về mục `CAN-LAM` | 3 |
| **D** | Tài liệu đúng ý đồ, **mã** chưa làm đúng | Sửa mã — đã có tài liệu xin riêng | 2 |

**Cách đo:** truy vấn chỉ đọc qua Prisma trên CSDL dev `PersonFinance`
(`pg_indexes`, `pg_constraint`, `pg_trigger`, `information_schema.columns`), đọc
`prisma/schema.prisma`, `database/*.sql`, `prisma/migrations/`, và mã
`modules/`. Không con số nào chép từ tài liệu.

⚠️ Đo index thì dùng **`pg_indexes`**, không dùng `pg_constraint`: partial unique
index không hiện ở `pg_constraint`. Client đã vấp đúng chỗ ấy ngày 2026-09-09 và
kết luận nhầm rằng bảng `wallet` không có unique index nào.

---

## 2. Nhóm A — tài liệu sai so với mã và CSDL

### 2.1. `New_Database.md`

| # | Dòng | Tài liệu nói | Thực tế | Sửa thành |
|---|---|---|---|---|
| A1 | 232–255 (bảng 2.11 `Goal`) | Không có `Priority`, `auto_deposit_amount`, `auto_deposit_wallet_id`, `auto_deposit_last_run` | Có ở CSDL và `schema.prisma:268-271`; client đẩy và kéo cả bốn | Thêm bốn dòng. `Priority` là `int NULL`, **NULL = chưa sắp** (xem `GOAL_PRIORITY_NULL_TO_ZERO.md`) |
| A2 | 259–278 (2.12 `Transaction`) | Không có `Idgoal` | Có ở CSDL và `schema.prisma:292`, FK `fk_transaction_goal` `ON DELETE SET NULL` | Thêm dòng |
| A3 | 44–58 (2.2 `Account`) | 10 cột, không có `Reason_Inactive`, `Countdown` | `schema.prisma:30-31` khai cả hai; `database/8`, `9` thêm chúng. Chính mục 4 STT 4 (dòng 421) nhắc `Reason_Inactive` | Thêm hai dòng |
| A4 | 169 (2.8 `Wallet`) | `Status` `Varchar(7)` | `schema.prisma:168` `VarChar(20)`; `database/7` dòng 24 nới lên 20. `Varchar(7)` không chứa nổi `'Inactive'` mà chính CHECK của cột cho phép | `Varchar(20)` |
| A5 | 272–273, 389 | CHECK `Status IN (…)` và `Provider IN ('Manual','BankSync','SMS','ORC','Bill')` | Bảng `transaction` chỉ có `chk_transaction_type` và `chk_transaction_nonzero_amount` — **không** CHECK trên hai cột này. Migration `20260901090000_align_new_database` dòng 64 đổi dữ liệu `'ORC'` thành `'OCR'`; `Rule_project.md` dòng 354 viết `OCR`; `sync.validation.js:125` nhận cả hai cộng `Casso` | Viết `OCR`. Rồi hoặc thêm CHECK, hoặc bỏ chữ "Check" khỏi hai dòng |
| A6 | 197, 221, 368, 375 | `Time_recurrence IN ('Day','Week','Month','Quarter','Year')` cho `budget` và `bill` | `chk_budget_time_recurrence` và `chk_bill_time_recurrence` chỉ nhận `Week, Month, Quarter, Year`, cho phép NULL — **không có `Day`** | Bỏ `Day` |
| A7 | 222, 375 | `Time_notification IN ('1','3','5','7')` | Không có CHECK (`bill` chỉ có `chk_bill_amount`, `chk_bill_pay_status`, `chk_bill_time_recurrence`) | Bỏ chữ "Check", hoặc thêm CHECK |
| A8 | 245, 247, 249, 382 | CHECK cho `Cycle_take_money`, `Status_complete`, `Time_recurrence` của `goal` | `goal` chỉ có `chk_goal_current_amount`, `chk_goal_target_amount` | Như A7 |
| A9 | 368 | `Spent >= 0` | `budget` có bốn CHECK (`end_after_start`, `threshold_percent`, `time_recurrence`, `total_amount`), không cái nào cho `Spent` | Như A7 |
| A10 | 54–55 | `Status` CHECK bốn giá trị, `Type` CHECK `Basic, Premium` | Bảng `account` **không có CHECK nào** | Như A7 |
| A11 | 199, 225, 252 | `Note` của `budget`, `bill`, `goal` là "Plaintext" | `sync.repository.js` chạy `prepareSafeNote` (lọc rồi mã hoá) khi ghi và `restoreSafeNote` khi đọc cho **cả bốn** bảng có `Note` | Ghi như dòng `Note` của `transaction` (dòng 274) |
| A12 | 344 (3.2.6) | Unique `(Create_by, NameCategory, Classify)` | Hai partial unique index, **không** có `Classify`: `uq_category_owner_name ("Create_by", lower(regexp_replace(btrim(NORMALIZE("NameCategory", NFC)), '\s+', ' ', 'g'))) WHERE "Is_default" = false AND "Delete_at" IS NULL`, và `uq_category_default_name` cùng biểu thức cho hàng mặc định | Chép từ `Rule_project.md` 1.2 (dòng 240–256), vốn đã đúng |
| A13 | 362 (3.2.8) | Unique `(Idaccount, Name)`; `Id_bank_casso` WHERE NOT NULL | **Bốn** partial unique index, đều kèm `"Delete_at" IS NULL`: `uq_wallet_account_name_active`, `uq_wallet_bank_active`, `uq_wallet_default_active`, `uq_wallet_saving_active` | Ghi đủ bốn, kèm mệnh đề `WHERE`. Nếu bỏ index Tiết kiệm (mục 12 `README.md`) thì ba |
| A14 | 391 (3.2.12) | `(Provider, Bank_tran_id)` WHERE `Bank_tran_id IS NOT NULL` | `uq_transaction_external ("Idaccount", "Provider", "Bank_tran_id")`, không mệnh đề `WHERE` | Chép định nghĩa thật |
| A15 | 318, 324 (3.2.2, 3.2.3) | Unique `Email`, `Username` (account); `Email` (user) | `database/7` dòng 11–19: `Email` thành partial `WHERE "Delete_at" IS NULL`, `Username` **thôi unique**. `Rule_project.md` 11.4 (dòng 551–565) mô tả đúng như tệp 7 | Theo tệp 7 |
| A16 | 408 | "Toàn bộ 13 bảng (149 cột)" | 13 bảng, **162** cột trên CSDL dev (câu truy vấn ở mục 6); các tệp 8, 9, 11 còn thêm cột | Đếm lại **sau** khi áp mục 11, ghi kèm ngày và câu truy vấn |

### 2.2. `Rule_project.md`

| # | Dòng | Tài liệu nói | Thực tế | Sửa thành |
|---|---|---|---|---|
| A17 | 82–84 (3.3) | `ENTITY_PRIORITY`: `Account → Wallet → Category → CategoryGroup → CategoryGroupMembership → Goal → Bill → Budget → Transaction` | `sync.service.js:48-55`: `category` 10 → `wallet` 20 → `budget`/`bill`/`goal` 30 → `transaction` 40; xoá thì ngược lại. Hai bảng nhóm đã DROP (`database/6`). Mục 1.6 **cùng tệp** (dòng 282–285) nói "không có bảng trung gian" | Chép thứ tự từ mã |
| A18 | 89 (3.3) | "Sử dụng Database Trigger để ngăn người dùng tạo danh mục cá nhân trùng tên với danh mục mặc định" | Mục 1.2 **cùng tệp** (dòng 256): trigger ấy "đã chính thức được gỡ bỏ" (`database/5`). CSDL dev có **0** trigger không nội bộ | Xoá dòng |
| A19 | 69 (3.2) | "Migration: Thực thi qua lệnh chuẩn hoá của Prisma" | `_prisma_migrations` có 3 dòng, dừng ở `20260901191107_fix_schema_align`. Các tệp `database/5`–`11` là SQL áp tay, không bảng nào ghi tệp nào đã áp | Ghi quy trình đang dùng thật — xem `DEV_DB_MIGRATIONS_7_11.md` mục 4.2 |
| A20 | 288–323 (mục 2) | Không có luật tên ví duy nhất, không có luật "một ví Tiết kiệm" | CSDL thi hành cả hai (`uq_wallet_account_name_active`, `uq_wallet_saving_active`). Hai luật chỉ xuất hiện trong ghi chú client ở dòng 294, không thành luật | Thêm luật tên ví; luật Tiết kiệm chờ quyết định ở `WALLET_SAVING_INDEX.md` |

### 2.3. `Data_Security.md`

Nhóm A không có dòng nào ở tệp này. Hai chỗ lệch của nó nằm ở nhóm B (B2) và
nhóm D (D2).

### 2.4. `docs/progress/Backend.md`

| # | Dòng | Tài liệu nói | Thực tế | Sửa thành |
|---|---|---|---|---|
| A21 | 174–184 (mục 9) | "Các hạng mục backend cần làm tiếp để khớp Client-App" — chỉ ba tính năng AI | `CAN-LAM/README.md` mục 2 có **mười lăm** mục chờ backend (đếm 2026-09-10), không mục nào được nhắc ở đây. Đội backend có thể chưa thấy chúng | Trỏ về `docs/superpowers/backend/CAN-LAM/README.md` |
| A22 | 186–195 (mục 10) | Năm script `Test/test_*.js` "PASS 100%" | **Không tệp nào có trong repo lẫn trên máy này.** `.gitignore` dòng 76–77 bỏ qua `Test/` có chủ ý ("Local test scripts"). Quét `*.test.js` / `*.spec.js` trong `src/Backend`: 2 tệp, cả hai của AI phân loại | Hoặc commit các script bằng `git add -f`, hoặc ghi rõ chúng chỉ chạy trên máy người viết |
| A23 | 237 (12.1), 265 (12.4) | `middleware/auth.js` trả 401 `{ code: 'ACCOUNT_DELETED' }` / `{ code: 'ACCOUNT_INACTIVE', reason_inactive }` | Body thật không có mã nào — `AUTH_401_BODY_CODE.md` mục 2.1 | Giữ nguyên câu, sửa mã (nhóm D1) |

---

## 3. Nhóm B — đúng với tệp `database/7`–`11`, CSDL dev chưa áp

**Không sửa tài liệu.** Ghi ra đây để không ai "sửa" tài liệu cho khớp CSDL dev.

| # | Tài liệu | Nói | CSDL dev | Tệp mang thay đổi |
|---|---|---|---|---|
| B1 | `New_Database.md` 71, 143–144, 353 | `Phone` `varchar(256)`, `Account_number` `varchar(256)`, có `Account_number_hash` | `varchar(15)`, `varchar(50)`, không có cột hash | `database/11` dòng 16, 19, 22 |
| B2 | `New_Database.md` 354, 392, 418, 425; `Data_Security.md` 221–226; `Rule_project.md` 652–653, 662, 665 | Bốn trigger bảo vệ "đã triển khai" | **0** trigger không nội bộ (`pg_trigger`) | `database/10` dòng 35, 60; `database/11` dòng 51, 80 |
| B3 | `Rule_project.md` 553 (11.4) | `Email` là partial unique, `Username` được trùng | `account_Email_key`, `user_Email_key` unique **toàn phần**; `account_Username_key` vẫn unique | `database/7` dòng 11–19 |

⚠️ Riêng câu *"đã hoàn tất triển khai và **kiểm thử 100%**"* ở `Data_Security.md`
dòng 219 thì sai với mọi CSDL chưa áp tệp 10 và 11, không riêng CSDL dev.

---

## 4. Nhóm C — mô tả tính năng chưa có như thể đã có

| # | Dòng `Rule_project.md` | Nói | Thực tế | Sửa thành |
|---|---|---|---|---|
| C1 | 406, 408 (6.2) | `pay_status`: `'Paid'`, `'Skipped'` | `chk_bill_pay_status` và `sync.validation.js:140` chỉ nhận `Pending, Payed, Overdue` | Viết `'Payed'`. `'Skipped'` ghi "chưa có — `CAN-LAM/README.md` mục 5" |
| C2 | 412 (6.3) | Cột `previous_bill_id` | Không có ở CSDL lẫn `schema.prisma` | "Chưa có — mục 3" |
| C3 | 417 (6.4) | Chốt chặn trả hai lần theo `Idbill` | `transaction` không có `Idbill`; `upsertTransaction` không kiểm gì | "Chưa có — mục 4" |

---

## 5. Nhóm D — tài liệu đúng ý đồ, mã chưa làm đúng

| # | Tài liệu | Mã sai ở đâu | Tài liệu xin |
|---|---|---|---|
| D1 | `Rule_project.md` 535–542 (11.3) và 570 (11.5); `docs/progress/Client-app.md` 10.3, 11.3; `docs/progress/Backend.md` 237, 265 | `ResponseHandler.unauthorized` nhận hai tham số, `code` và `reason_inactive` rơi mất | `AUTH_401_BODY_CODE.md` |
| D2 | `Data_Security.md` 240–242 (10.4); `New_Database.md` 422 (mục 4 STT 5) | Bộ lọc `Note` bắt nhầm số tài khoản, "mật khẩu wifi", hậu tố `(tự động)` của app, rồi bản đã lọc đè lên máy người dùng | `SYNC_NOTE_FILTER_REWRITE.md` |

---

## 6. Việc cần làm

1. Sửa các dòng nhóm **A** và **C** theo cột "Sửa thành". Đổi *Ngày cập nhật*
   ở đầu `New_Database.md` trong cùng lần sửa.
2. Để nguyên nhóm **B**. Sau khi áp mục 11, đo lại để chắc tài liệu và CSDL đã
   khớp.
3. Nhóm **D** theo hai tài liệu riêng.

Đếm cột bằng câu truy vấn, đừng đếm tay:

```sql
SELECT COUNT(DISTINCT table_name) AS bang, COUNT(*) AS cot
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name <> '_prisma_migrations';
```

Liệt kê unique index (kể cả partial):

```sql
SELECT tablename, indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND indexdef ILIKE '%UNIQUE%'
ORDER BY 1, 2;
```

Liệt kê CHECK:

```sql
SELECT conrelid::regclass AS bang, conname, pg_get_constraintdef(oid)
FROM pg_constraint WHERE contype = 'c' ORDER BY 1, 2;
```

---

## 7. Vì sao client quan tâm

Client không đọc các tệp này lúc chạy. Nhưng tài liệu của client trỏ vào
`New_Database.md` như nguồn sự thật về lược đồ, và hai lỗi im lặng của client
từng bắt nguồn từ việc tin một tài liệu thay vì đo: bốn loại ví của giao diện cũ
(`ewallet`, `debt`) vỡ CHECK mà không ai biết, và kết luận "không có unique
index nào" ngày 2026-09-09. Mỗi dòng sai ở đây là một lần như thế đang chờ.
