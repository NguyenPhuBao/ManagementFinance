# Soát `7675b35` từng mục — việc còn lại sau báo cáo "15/15 hoàn tất"

**Ngày:** 2026-09-11 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** chín việc
mã/CSDL nhỏ (một `ALTER`, gỡ một lần phát sự kiện, một chốt khởi động, một tệp SQL cần
gỡ câu xoá cứng, …) cộng **45** chỗ sửa tài liệu backend. Không việc nào cần client làm
trước.

> **Đo trên `TranQuangDat` @ `66d5c97`** — mã `src/Backend` trùng `origin/main` @
> `cc65f4f` (gồm `7675b35` và `f8ab027`) — và trên **CSDL dev đã áp `database/12`** cùng
> ngày. Cách đo: đọc mã HEAD; chạy thử hàm thuần (`accountRejection`,
> `filterSensitiveNote`, `ResponseHandler`) bằng `node -e`; truy vấn **chỉ đọc**
> PostgreSQL; `prisma migrate diff` (chỉ đọc). **Không** chạy đầu-cuối: không khởi động
> backend, không ghi CSDL. Chỗ nào chỉ suy từ mã thì ghi rõ.
>
> **Bảng trạng thái của cả 15 tài liệu** nằm ở mục 2 `README.md` — tài liệu này chỉ
> giữ phần **chi tiết để làm theo**. Ba hồi quy của chính `7675b35` vẫn ở mục 17
> (`FIX_BACKEND_3_REGRESSIONS.md`), không lặp lại ở đây trừ một chỗ bổ sung (2.1).

---

## 1. Thứ tự đề xuất

| # | Việc | Mức | Mục |
|---|---|---|---|
| 1 | Bắt tay socket và `/auth/refresh` từ chối mọi tài khoản; socket mất cả `data.code` | 🔴 | 17 A + **2.1** |
| 2 | Chốt trả hai lần ở `upsertBill` chặn hoàn tác | 🔴 | 17 B |
| 3 | Giao dịch SePay ghi `type` `'Chi'`/`'Thu'` — vỡ `chk_transaction_type` (suy từ mã) | 🟠 | **2.9** |
| 4 | `bank_transaction.incoming` phát **hai lần** mỗi giao dịch, hai hình dạng | 🟡 | **2.5** |
| 5 | Khoá mã hoá dữ liệu rơi về chuỗi viết cứng | 🟡 | **2.6** |
| 6 | `database/)2_can_lam_all_migrations.sql` còn `DELETE FROM "category"`; chưa có sổ ghi tệp đã áp | 🟡 | **2.4** |
| 7 | `budget."Threshold_Warning_Percent"` vẫn `DEFAULT 0` trên CSDL | ⚪ | **2.2** |
| 8 | Cửa hậu `_mock*` mở ở mọi môi trường không phải `production`; `'ORC'` còn sót | ⚪ | **2.8** |
| 9 | `WALLET_NAME_DUPLICATE` — cần một phép thử khi chạy | ⚪ | **2.7** |
| 10 | Tài liệu backend: 45/56 chỗ chưa đúng, ba câu mã lỗi của 17 C, tám khẳng định mới sai | ⚪ | 17 C + **3** |

Màu danh mục (**2.3**) là việc của **client**, backend không cần làm gì — ✅ client đã sửa 2026-09-11.

---

## 2. Việc mã và CSDL

### 2.1. Bổ sung cho 17 A — bắt tay socket đọc sai chỗ mã

`core/socket.js:39-49` gắn `data.code = rejection.code`, nhưng `accountRejection`
(`middleware/auth.js:60-74`) trả mã trong `rejection.data.code` — nên `rejection.code`
luôn `undefined` và **mọi** lần từ chối đi ra không có mã, kể cả khi từ chối đúng (tài
khoản bị khoá hay đã xoá thật). Trước khi gộp, nhánh ấy còn gắn `ACCOUNT_DELETED`.

Sửa cùng lượt với 17 A: đọc `rejection.data.code` (và `rejection.data.reason_inactive`),
sau khi đã bọc lời gọi trong `if (!accountInfo.valid)`.

### 2.2. (D) của `2026-09-04-backend-idempotent-delete.md` — phần CSDL

- **Mã: xong.** Nhánh tạo `sync.repository.js:371` giữ `null`, nhánh sửa `:392`,
  ánh xạ `:59-65`; `schema.prisma:199` đã bỏ `@default(0)`.
- **CSDL: chưa.** `information_schema.columns` cho `budget."Threshold_Warning_Percent"`:
  `column_default = 0`. `database/12` không có bước nào cho `budget`, dù `Project.md`
  11.36 và `New_Database.md:192,381` ghi đợt này đã bỏ mặc định ấy. `prisma migrate
  diff` báo đúng câu này.

Xin: `ALTER TABLE "budget" ALTER COLUMN "Threshold_Warning_Percent" DROP DEFAULT;`
trong tệp migration kế tiếp. Đường `/sync/push` hôm nay luôn gửi giá trị tường minh nên
không dính, nhưng mọi đường ghi khác (SQL tay, Admin-web, script) vẫn nhận `0`.

**Không xin dọn dữ liệu.** CSDL dev có 3 hàng `= 0`, cả ba của tài khoản 10 (hai đã xoá
mềm, một hàng sống `399a9b54-…`). Server không phân biệt được `0` do người dùng chọn
với `0` bị ép trước bản vá, nên đổi thành `NULL` là đoán.

### 2.3. Màu danh mục — cột và đường đồng bộ đã xong, khoá lệch ở phía client

> ✅ **2026-09-11 — client đã sửa:** `categoryForPush` đổi `colour` → `color`, nhánh kéo về đọc `color`; kiểm trên máy ảo,
> `category.Color` nhận `#FF5722`. Hai việc tuỳ chọn ở đoạn cuối mục này vẫn là tuỳ chọn. Đoạn dưới là ảnh chụp trước bản sửa.

Backend nhận `color` (`sync.repository.js:149`, ghi ở `:175,196`) và trả `color` ở pull
(`:228`). Client gửi và đọc **`colour`** cho danh mục: `categoryForPush`
(`sync_payload_normalizer.dart:101-116`) không đổi khoá — khác `walletForPush` ngay trên
nó (`:82-83`) — và nhánh kéo về đọc `c['colour']` (`sync_engine.dart:603`). Nên màu danh
mục hôm nay **không đi theo chiều nào**, im lặng.

Đây là lỗi của client, client tự sửa (đổi khoá khi đẩy, đọc cả hai khoá khi kéo, cập nhật
`sync_payload_contract_test.dart`). **Backend không cần làm gì.** Tuỳ chọn: nhận thêm bí
danh `colour` để bản client cũ không mất màu; và `getDefaultCategories`
(`sync.service.js:299-311`) chưa trả `color`.

### 2.4. `database/)2_can_lam_all_migrations.sql` và sổ ghi migration (mục 4.2 của `DEV_DB_MIGRATIONS_7_11.md`)

- **Tệp `)2` vẫn còn trên HEAD, dòng 22 vẫn `DELETE FROM "category"`** — xoá cứng.
  Trên dữ liệu thật câu ấy vướng `fk_bill_category` (RESTRICT) và làm **cả tệp roll
  back** (banner đợt 2026-09-07 ở `README.md`). Bản vá xoá mềm (`ea3611a`) chỉ nằm ở
  nhánh **cục bộ** `patch2` trên máy client — không nhánh remote nào có. Xin: bỏ tệp khỏi
  `database/` (nó đã được thay bằng các tệp đánh số), hoặc thay câu `DELETE` bằng
  `UPDATE "category" SET "Delete_at" = NOW() WHERE …`. ⚠️ Đừng gộp nguyên `patch2`: nó
  không có `database/7`–`12` nên diff sẽ **xoá** các tệp ấy.
- **Chưa có sổ ghi tệp nào đã áp.** `Rule_project.md:69` chọn quy ước `database/N_*.sql`
  + `schema.prisma` + `prisma generate`, nhưng không ghi thứ tự áp, cách kiểm, hay nơi
  ghi môi trường nào đã áp tệp nào. `_prisma_migrations` trên CSDL dev chỉ có 3 dòng;
  script áp chỉ có cho tệp 5, 6, 11, 12. Xin một bảng `N → nội dung → câu truy vấn kiểm`.
- **`schema.prisma` không diễn đạt được partial index**, nên `prisma migrate diff` trên
  CSDL dev (đã áp tệp 12) luôn báo 6 câu: `budget` DROP DEFAULT (2.2), và 5 index mà CSDL
  tạo có `WHERE` — `account_Email_key`, `user_Email_key` (`WHERE "Delete_at" IS NULL`),
  `idx_bill_previous_bill`, `idx_transaction_bill`, `idx_transaction_goal`
  (`WHERE … IS NOT NULL`). Chạy `prisma migrate dev` trên CSDL này sẽ sinh migration
  tạo lại chúng. Xin ghi điều ấy vào quy trình.

### 2.5. `bank_transaction.incoming` — nay phát hai lần, vẫn hai hình dạng

Mỗi giao dịch SePay đi hai đường tới cùng phòng `account_<id>`:

1. `workers/bank.worker.js:231-232` gọi thẳng `emitBankTransaction` với `type` = `'Thu'`/`'Chi'`,
   `status`, `transaction_status`;
2. rồi `:243` publish `bank_transaction.pending` → `modules/notification/notification.service.js:15-35`
   nhận và gọi **lại** `emitBankTransaction` với `type: 'BankTransactionPending'`, không
   có `status`.

Trước khi gộp, đường 1 gọi `emitToUser` — hàm không tồn tại trong `core/socket.js` — nên
chỉ đường 2 chạy. `7675b35` đổi đường 1 sang `emitBankTransaction`, nên **từ nay mỗi
giao dịch phát hai sự kiện**. Client hôm nay chỉ đọc tên sự kiện nên nhận hai lần kích
hoạt cho một giao dịch. Xin: giữ **một** chỗ phát và một hình dạng, như mục 3 của
`SOCKET_BANK_EVENT_PAYLOAD.md`. Kèm, có từ trước: `bank.worker.js:236-237` gọi
`emitToAdmin` — `core/socket.js` không export hàm ấy — nên
`admin.bank_transaction_created` không bao giờ phát.

### 2.6. Khoá mã hoá (mục 8.1 của `SYNC_NOTE_FILTER_REWRITE.md`)

`utils/crypto.util.js:10-11` rơi về chuỗi viết cứng khi thiếu `DATA_ENCRYPTION_KEY` /
`BLIND_INDEX_SECRET`; `.env` dev và `.env.example` đều không có hai tên ấy; không có chốt
từ chối khởi động khi thiếu khoá; và `decrypt()` hỏng trả nguyên chuỗi `enc:…`
(`:87-90`). Xin: chốt không khởi động ở `production` khi thiếu khoá, và thêm hai tên
biến vào `.env.example`. ⚠️ CSDL dev đã có dữ liệu mã hoá bằng khoá mặc định (hàng
`transaction` bắt đầu `enc:`, và các cột tệp 11 mã hoá) — đổi khoá về sau phải kèm bước
mã hoá lại.

Phần còn lại của tài liệu ấy **đã xong**: bảng 15 ca ở mục 6.3 chạy đúng 15/15 (đo bằng
`filterSensitiveNote` thật), `dedup.repository.js` giải mã trước khi so khớp (8.2),
`bank.worker.js` lọc rồi mã hoá (8.3).

### 2.7. `WALLET_NAME_DUPLICATE` — cần một phép thử khi chạy

`sync.service.js:182` nhận diện bằng `/uq_wallet_name|wallet.*name/` trên thông điệp lỗi,
còn index thật là `uq_wallet_account_name_active` — partial unique index tạo bằng SQL
(`prisma/migrations/20260901090000_align_new_database/migration.sql:72`), không có trong
`schema.prisma`. Nếu thông điệp mang tên index thì nhánh `wallet.*name` vẫn khớp; nếu
Prisma chỉ liệt kê tên trường (`Idaccount`, `Name`) thì rơi về `UNIQUE_VIOLATION`. Client
không ghi CSDL nên không thử được. Xin một ca thử: đẩy hai ví trùng tên, xem mã trả về.
Client không kẹt ở cả hai kết quả (`UNIQUE_VIOLATION` và hai mã ví đều là mã vĩnh viễn ở
`sync_engine.dart`) — chỉ mất phần thông báo đúng lý do.

### 2.8. OCR/Classify (`2026-09-04-ocr-classify-review.md`)

- `_mock*` chỉ bị chặn khi `NODE_ENV === 'production'` (`ocr.controller.js:22-25`,
  `classify.controller.js:108-113`); `.env` dev đặt `development`, và không tệp triển
  khai nào trong repo đặt `production`. Xin xác nhận môi trường triển khai đặt
  `NODE_ENV=production`, hoặc chặn bằng cờ tường minh.
- `'ORC'` còn ở `sync.repository.js:308` (danh sách provider suy `status`) và chú thích
  `ocr.service.js:8`, `dedup.service.js:14`. Vô hại vì `sync.validation.js:153` đổi
  `ORC` → `OCR` trước.
- Đã xong: `classifyBatch` truyền object (`classify.service.js:376-380`); dedup Quy tắc 3
  lọc `provider` và hậu lọc (`dedup.repository.js:158-208`). `GEMINI_API_KEY` có trong
  `.env.example:57` nhưng `.env` dev chưa khai.

Client **chưa có** tính năng quét hoá đơn, nên cả mục này không chặn gì phía client.

### 2.9. Giao dịch SePay vỡ `chk_transaction_type` — có từ trước `7675b35`, suy từ mã

`bank.worker.js:193` ghi `type: type || (transfer_type === 'debit' ? 'Chi' : 'Thu')`, và
`sepay.webhook.js:147` luôn truyền `type` là `'Chi'`/`'Thu'`. `chk_transaction_type` trên
CSDL dev chỉ nhận `'Transaction'` / `'Transfer'` (đo `pg_constraint`). Nên theo mã, mọi
giao dịch SePay vỡ `23514` khi chèn. Kèm: `amount: Math.abs(amount)` ghi khoản chi thành
số dương, trong khi quy ước đồng bộ là `Transaction` + dấu của `Amount` (khoản chi âm).

Chưa chạy thật vì phải ghi CSDL. Xin một ca thử webhook `debit` trên CSDL dev.

---

## 3. Tài liệu backend — soát lại `RULE_PROJECT_DOC_DRIFT.md` sau `7675b35` / `f9d13c9`

Tài liệu ấy (nay ở `DA-XONG/`) xin **56** chỗ sửa theo dòng. Số dòng dưới đây là số dòng
**HEAD**; mã chỗ (ND/RP/DS/BK) là mã trong tài liệu ấy.

| Tệp | Đã sửa đúng | Chưa sửa | Sửa nhưng vẫn sai | Không còn áp dụng | Tổng |
|---|---|---|---|---|---|
| `New_Database.md` | 2 | 28 | 9 | 0 | 39 |
| `Rule_project.md` | 8 | 0 | 3 | 2 | 13 |
| `Data_Security.md` + `Backend.md` | 1 | 3 | 0 | 0 | 4 |
| **Tổng** | **11** | **31** | **12** | **2** | **56** |

### 3.1. Chưa sửa (31)

`New_Database.md`:
- `:51, :70, :329, :335` (ND01, 06, 24, 26) — Email ghi `Unique`; thật là partial unique
  `WHERE "Delete_at" IS NULL` (`account_Email_key`, `user_Email_key`).
- `:52, :329` (ND02, 24) — Username ghi `Unique`; thật chỉ có `idx_account_username`.
- sau `:55` (ND05) — thiếu `Reason_Inactive`, `Countdown` (CSDL có cả hai).
- Ghi "Check in" cho cột **không có CHECK nào**: `:54, :55, :330` (`account`, ND03, 04,
  25), `:88, :340` (`audit_log`, ND07, 27), `:106, :346` (`otp_code`, ND08, 28), `:193`
  (`OverSpending`, ND10), `:223` (`Time_notification`, ND14), `:250, :252, :254` (`goal`,
  ND16–18), `:283` (`transaction.Status`, ND22), `:415` (`refreshtoken`, ND38).
- `:198, :222` (ND11, 13) — còn `Day`; `chk_budget_time_recurrence` và
  `chk_bill_time_recurrence` không có `Day`.
- `:200, :230, :261` (ND12, 15, 19) — Note ghi "Plaintext"; mã mã hoá khi ghi
  (`sync.repository.js:379, 441, 521`).
- `:372` (ND30) — thiếu `chk_wallet_banking_link`.
- `:380` (ND32) — còn `Spent >= 0`, `OverSpending IN`, `Day`; thiếu
  `chk_budget_end_after_start`.
- `:423` (ND39) — "149 cột"; đo được 171.

Tệp khác:
- `Data_Security.md:223` (DS01) — vẫn "kiểm thử 100%".
- `Backend.md:176` (BK01) — chưa trỏ về danh sách CAN-LAM.
- `Backend.md:186-194` (BK02) — "100% PASS" cho script `Test/`; thư mục ấy bị
  `.gitignore` và không có trong repo.

### 3.2. Sửa nhưng vẫn sai (12)

- `New_Database.md:170` (ND09) — `Varchar(8)`; `wallet."Status"` là `varchar(20)`.
- `New_Database.md:255-258` (ND20) — `auto_deposit_amount` ghi `Decimal(15,2)` + `Check
  >0`, thật `numeric(18,2)` không CHECK; `auto_deposit_wallet_id` ghi "FK Wallet", `goal`
  chỉ có `fk_goal_account` và `fk_goal_wallet`; `auto_deposit_last_run` ghi `Date`, thật
  `timestamp`; `Priority` ghi `Smallint` + `Check >0`, thật `integer` không CHECK.
- `New_Database.md:396` (ND34) — thêm CHECK `Priority IS NULL OR Priority > 0` không tồn
  tại; `goal` chỉ có `chk_goal_target_amount` và `chk_goal_current_amount`.
- `New_Database.md:284, :404` (ND23, 36) — đổi `ORC` → `OCR` nhưng vẫn ghi CHECK cho
  `Provider`/`Status`; `transaction` chỉ có `chk_transaction_type` và
  `chk_transaction_nonzero_amount`.
- `New_Database.md:356` (ND29) — thiếu `WHERE "Is_default" = false AND "Delete_at" IS
  NULL`, thiếu `uq_category_default_name`.
- `New_Database.md:374` (ND31) — `(Idaccount, Name)` thiếu điều kiện `Delete_at`, thiếu
  `uq_wallet_default_active` (phần gỡ `uq_wallet_saving_active` thì đúng).
- `New_Database.md:388` (ND33) — `Skipped`, `Anchor_day` đúng; vẫn ghi `Day` và
  `Time_notification IN`.
- `New_Database.md:406` (ND37) — ghi `(Idaccount, Bank_tran_id) WHERE …`; thật
  `(Idaccount, Provider, Bank_tran_id)`, không `WHERE`.
- `Rule_project.md:326` (RP04), `:423` (RP11) — xem 17 C; RP11 còn ghi chốt trả hai lần
  nằm đúng chỗ.
- `Rule_project.md:539` (RP12) — ghi bắt tay socket trả `ACCOUNT_INACTIVE` kèm
  `reason_inactive`; thật từ chối mọi kết nối và không có mã (17 A, 2.1).

Không còn áp dụng (2): RP09 `:411` và RP10 `:415` — câu hiện tại đã đúng sau tệp 12.

Ba việc mã của tài liệu ấy: **5.2** (bộ lọc ghi chú) xong; **5.1** (body 401) xong ở
HTTP, hỏng ở socket/refresh (17 A); **5.3** (`'ORC'`) còn sót (2.8).

### 3.3. Khẳng định mới của `7675b35` sai so với mã hoặc CSDL

1. `budget.Threshold_Warning_Percent` "không ép default 0" (`New_Database.md:192,381`,
   `Backend.md:484`, `Project.md:2633`) — CSDL vẫn `DEFAULT 0` (2.2).
2. `goal.Priority` "ràng buộc NULL hoặc số nguyên dương" (`Backend.md:483`,
   `Project.md:2632`) — không có CHECK; tệp 12 chỉ `UPDATE` một lần; push nhận `0` và số âm
   (`sync.repository.js:124`).
3. Kiểm trạng thái tài khoản khi làm mới token và bắt tay socket được ghi là xong
   (`Backend.md:489-490,493`, `Project.md:2636-2637`) — cả hai từ chối mọi tài khoản (17 A);
   503 cho lỗi lược đồ chỉ có ở `authenticate`.
4. "Thống nhất payload `bank_transaction.incoming`" (`Backend.md:495`, `Project.md:2637`) —
   vẫn hai hình dạng, nay phát hai lần (2.5).
5. "`sync.completed` khi background worker xử lý xong" (`Backend.md:496`,
   `Project.md:2637`) — chỉ phát sau `/sync/push` (`sync.service.js:223`); worker không
   publish.
6. "OCR thay thế triệt để `ORC`" (`Backend.md:515`, `Project.md:2641`) — còn sót (2.8);
   `Backend.md:13, :157` vẫn ghi `ORC`.
7. `Project.md:2652-2653` "đồng bộ 39 điểm ND01–ND39", "13 điểm RP" — xem bảng trên.
8. "PASS 100%" (`Backend.md:518-522`, `Project.md:2646-2650`) — các script không có trong
   repo; và `Backend.md:475` ghi "16 tài liệu" trong khi `Project.md:2635,2643` ghi "15".
   Thêm: `Rule_project.md:585` ghi `account.force_logout` có trường `code`, thật tên là
   `reason` (`core/socket.js:182-186`).

---

## 4. Liên quan tới client

- **Client không bị chặn bởi việc nào ở mục 2**, trừ hai hồi quy của mục 17 (kênh thời
  gian thực và làm mới token).
- Việc phía client phát sinh từ lượt soát này: sửa khoá màu danh mục (2.3 — ✅ làm
  2026-09-11); gỡ chốt tạm "một ví Tiết kiệm" (G30 — ✅ làm cùng ngày); chờ người dùng quyết: mở đồng bộ các cột hoá đơn
  đang cục bộ. Khi mở cột hoá đơn, lưu ý hai điểm phía backend đo được: `Boolean("false")`
  thành `true` ở `sync.repository.js:103-104` nếu lỡ gửi chuỗi; và hai kỳ cùng chuỗi trong
  một lô có cùng trọng số sắp xếp, kỳ sau đứng trước thì vỡ `fk_bill_previous_bill` và chỉ
  tự lành ở chu kỳ đẩy sau.
- Spec cưỡng chế đăng xuất định viết `AUTH_PROFILE_COUNTDOWN.md` làm mục 18; từ nay nó là
  **mục 19**. Hai điểm spec dựa vào vẫn đúng trên HEAD: `getProfile` không trả `countdown`
  (`auth.service.js:552-565`), `pendingDeleteCancelled` luôn `false` (`:309`).
