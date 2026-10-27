# Script test backend ghi ví mang id KHÔNG phải UUID vào tài khoản dev thật `quangdat` (18) — ví kẹt hàng đợi đẩy của client; xin dọn dữ liệu test và sửa script (mục 48)

> 🔎 **Client soát lượt báo xong 2026-10-26** (`49eafef6` · `bc4e4f7f` · `2b926d92`, gộp `3636110d`; đọc mã HEAD, CSDL Supabase của `.env` chỉ `SELECT`): **chưa xong — chuyển lại `CAN-LAM/`; việc 2 sửa thành lỗi khác.**
> - **Việc 1 bước 1 — đạt:** ví `test-wallet-1789014227658` `Delete_at` 03:58:21Z; 9 / 9 giao dịch đã xoá; toàn CSDL 0 ví / giao dịch sống mang
>   id không phải UUID. Xác nhận *ai làm, trên CSDL nào* chỉ là câu chung ở README (không nêu CSDL, không ghi vào đơn). Bước 3: ví ma
>   `00000000-…4534d71cc54d` vẫn 0 hàng (chưa máy nào đẩy lại).
> - **Việc 2 — ⚠️ sai kiểu khác:** UUID (`:243`, `:256`) và dọn trong `finally` (`:287-292`) đạt, nhưng *tài khoản test riêng* không làm: `:236`
>   đổi thành `findFirst({status:'Active', idrole: 1})` — **role 1 là admin** ⇒ script nay chọn **tài khoản 1 (admin thật)**; nhánh `: 1` còn ở
>   `:238`. CSDL đo 2026-10-26: **4 giao dịch 150.000 đ** ghi vào ví thật *"Tiết kiệm"* `b1a60d59-…` của tài khoản 1 lúc 04:08 / 04:43 / 05:56 /
>   06:59Z (đã xoá mềm — máy nào đăng nhập admin vẫn kéo về). Xin: script tự tạo tài khoản test riêng (hoặc lấy từ biến môi trường), không bao giờ
>   chọn theo role, và chỉ chạy trên CSDL test.
> - **Việc 3 — chưa:** `test_sync_new_schema.js:21`, `test_can_lam_fixes.js:44` không đổi. Tệp không `require('crypto')` — chạy được nhờ Node
>   ≥ 19 có `crypto` toàn cục.

> 🔎 **Client soát lại 2026-10-26** (truy vấn chỉ đọc trên CSDL Supabase của `.env`; `PersonFinance` cục bộ chưa đo):
> - **Việc 1, bước 1 — đã thực hiện** lúc **2026-10-26 03:58:21Z** (10:58 giờ VN): ví `test-wallet-1789014227658` và 2 giao dịch
>   còn sống của tài khoản 18 đã có `Delete_at` / `Deleted_at` (9 / 9 giao dịch của ví nay đều đã xoá). Người dùng xác nhận
>   không phải client làm. Nhờ backend ghi một dòng xác nhận (ai làm, trên CSDL nào) vào đơn.
> - **Bước 3 chờ:** ví "ma" `00000000-0000-4000-8000-4534d71cc54d` chưa xuất hiện (0 hàng) — chưa máy nào đẩy lại sau bước 1.
> - **Việc 2, 3 chưa làm:** `Test/test_data_security_encryption_and_masking.js` không đổi từ `b147feeb` (:236–237
>   `findFirst({status:'Active'})`, :243 `'test-wallet-' + Date.now()`, dọn sau `assert` ở :281, `finally` :337 chỉ đóng
>   `pgClient`); `Test/test_sync_new_schema.js:21`, `Test/test_can_lam_fixes.js:44` y nguyên.

**Ngày:** 2026-10-20 · **Phía gửi:** Client-app · **Nhánh:** `TranQuangDat` (HEAD `5794096e`)
**Loại:** đơn xin, mức **vừa**. Hai việc chính: (1) **dọn dữ liệu test** trên CSDL dev bằng **xoá mềm**, ba bước; (2) **sửa ca 11**
của `Test/test_data_security_encryption_and_masking.js`. Thêm một việc mức thấp: hai script cùng khuôn. Đơn **không** xin đổi
mã `src/Backend`, lược đồ hay payload `/sync/*`, và **không** cần migration. Mọi khẳng định đo bằng **đọc mã** và **truy vấn chỉ
đọc** trên CSDL dev (Supabase) ngày 2026-10-20. Client không ghi PostgreSQL.

## Vì sao client gửi đơn này

Nghiệm thu G89 trên OnePlus 13R (2026-10-20) lộ ra **một** hàng không bao giờ đồng bộ được ở tài khoản 18 `quangdat`: ví *"Ví Test
Note"* `test-wallet-1789014227658`. Hàng ấy ở trạng thái `pending`, kèm lỗi *"Tên ví đã tồn tại trong tài khoản này"* (client:
**G98**, `docs/CLIENT_APP_KNOWN_GAPS.md`). Người dùng thấy ba thứ:

- Ví test 300.000 đ được cộng vào tổng số dư ở Trang chủ.
- Một dòng giao dịch hiện chuỗi thô `enc:01a5ca71610…`.
- Đồng bộ chậm lại: lượt đẩy có hàng này **luôn hỏng**. Sau 4 chu kỳ hỏng, client hoãn đồng bộ của **cả tài khoản** tới
  **15 phút**, nên mọi dữ liệu mới của tài khoản 18 phải chờ. Đo trên log backend: *"2/4 succeeded, 1 failed"* lúc 16:08:26, rồi
  *"giãn cách sau 4 chu kỳ hỏng — hoãn tới 16:23:29"*.

Người dùng chốt hướng sửa (2026-10-20): **backend dọn dữ liệu test và sửa script**; client **không** đổi cách ánh xạ id vì đơn này.

## Nguồn dữ liệu — `Test/test_data_security_encryption_and_masking.js`, ca 11 (commit `b147feeb`, 2026-09-22)

| Dòng | Mã | Hệ quả |
|---|---|---|
| 236–237 | `prisma.account.findFirst({ where: { status: 'Active' } })`, **không** `orderBy`; không thấy thì dùng `1` | Chọn **một tài khoản thật bất kỳ**, theo thứ tự vật lý của PostgreSQL. Ngày 2026-09-10 là **18** (`quangdat`); đo hôm nay trả **82**. Chạy lên CSDL production thì sẽ ghi vào tài khoản của người dùng thật. |
| 239–250 | Tài khoản chưa có ví sống thì `prisma.wallet.create({ idwallet: 'test-wallet-' + Date.now(), … balance: 1000000 })` | Id **không phải UUID**, ghi thẳng bằng Prisma, không qua `/sync/push`. Không bước nào của script dọn ví này. |
| 253–264 | Mỗi lượt: giao dịch `'test-tran-note-' + Date.now()`, 150.000 đ, qua `syncRepository.upsertTransaction` | Thêm một giao dịch id không phải UUID vào ví trên. |
| 281–282 | `UPDATE "transaction" SET "Deleted_at" = NOW() …` **sau** các `assert` | Lượt nào gãy ở một `assert` thì không tới bước dọn, giao dịch còn sống. Khối `finally` ở dòng 337 chỉ đóng `pgClient`. |

**Đo trên CSDL dev (chỉ đọc, 2026-10-20):**

- **Ví** `test-wallet-1789014227658`: `Idaccount` 18, `Name` *"Ví Test Note"*, `Balance` 1.000.000, `Is_default` false,
  `Create_at` 2026-09-10 04:23:47Z, `Delete_at` NULL.
- **9 giao dịch** `test-tran-note-*`, tất cả trong ví trên. Đây là 9 lượt chạy, từ 2026-09-10 04:23Z tới 2026-09-11 06:58Z.
  **7** đã xoá mềm. **2** còn sống: `test-tran-note-1789014228215` (lượt đầu) và `test-tran-note-1789053749080`.
  2 × 150.000 đ = 300.000 đ, đúng con số người dùng thấy.
- Tài khoản 18 còn **13** ví test khác, của các script cùng đợt 2026-09-10 → 09-12 (*"Ví Tiết Kiệm Test"* × 6, *"Ví Dedup
  Test"* × 6, *"Tài khoản VCB"* × 1). Tất cả mang id UUID và **đã xoá mềm**, nên vô hại với client (xem việc 3).
- Toàn CSDL có **1** ví và **9** giao dịch mang id không phải UUID, tất cả là của script trên. `category`, `bill`, `goal`,
  `budget`: 0 hàng.

## Vì sao một id không phải UUID làm kẹt client

Client chỉ tạo id UUID. Trước khi đẩy, `toValidUuid` (`src/Client-app/lib/core/sync/uuid_dong_bo.dart`) đổi id không phải UUID
thành `00000000-0000-4000-8000-<12 ký tự hex>`. Phép đổi tất định: mỗi ký tự lấy mã `% 16`, giữ 12 ký tự đầu. Với ví này, id
giả là **`00000000-0000-4000-8000-4534d71cc54d`**. Mọi máy cho cùng id ấy.

Trình tự lỗi:

1. Server nhận id giả. `upsertWallet` (`modules/sync/sync.repository.js:240–262`) `findUnique` không thấy, nên gọi `create`.
2. `create` vấp `uq_wallet_account_name_active` (`UNIQUE ("Idaccount","Name") WHERE "Delete_at" IS NULL`) với **chính ví gốc**,
   và trả `WALLET_NAME_DUPLICATE`.
3. Hàng không cần ai sửa cũng tự thành `pending`. Lần kéo về đầu tiên không chép `Balance`. Rồi client tính lại số dư từ sổ giao
   dịch, ra 300.000, và hàm ghi số dư đánh dấu `pending`. Đây là kết luận đọc mã, chưa đo trên máy.

Vì vậy **mọi máy** đăng nhập tài khoản 18 đều kẹt ngay sau lần kéo về đầu tiên. Người dùng thật không gặp, vì client không bao
giờ tạo id không phải UUID.

## Xin làm

### Việc 1 — dọn dữ liệu test trên CSDL dev (ba bước, **chỉ xoá mềm**)

**Không xoá cứng.** Giao dịch có trigger `trg_protect_transaction`, chặn `DELETE`. Còn ví mà xoá cứng thì những máy đã đồng bộ
ví này sẽ không bao giờ nhận được cờ xoá, nên ví nằm lại trên máy mãi. Cột `Server_update_at` **tự cập nhật** qua trigger
`BEFORE UPDATE` (`trg_set_server_update_at_wallet`, `trg_set_server_update_at_transaction`), nên chỉ cần `UPDATE` cột xoá.

**Bước 1 — xoá mềm ví gốc và 2 giao dịch còn sống** (một giao tác):

```sql
BEGIN;
UPDATE "transaction" SET "Deleted_at" = (now() AT TIME ZONE 'UTC')
 WHERE "Idwallet" = 'test-wallet-1789014227658' AND "Idaccount" = 18 AND "Deleted_at" IS NULL;   -- mong đợi: 2 hàng
UPDATE wallet SET "Delete_at" = (now() AT TIME ZONE 'UTC')
 WHERE "Idwallet" = 'test-wallet-1789014227658' AND "Idaccount" = 18 AND "Delete_at" IS NULL;    -- mong đợi: 1 hàng
COMMIT;
```

Số hàng khác `2` / `1` thì `ROLLBACK` và báo client.

**Bước 2 — hệ quả biết trước: một ví "ma" sẽ xuất hiện. Không phải lỗi của bước 1.** Máy đang giữ hàng `pending` (ít nhất là
OnePlus của người dùng) chạy **đẩy trước, kéo sau**. Ở chu kỳ đầu tiên sau bước 1:

- Lượt đẩy gửi lại id giả. Lần này `create` **thành công**, vì ví gốc đã xoá mềm nên chỉ mục trùng tên không còn chặn.
- Server có thêm ví **sống** `00000000-0000-4000-8000-4534d71cc54d`, *"Ví Test Note"*, `Balance` 300.000 (lấy từ payload).
- Lượt kéo ngay sau đó xoá ví gốc trên máy và đưa ví ma về. Trên máy ví ma hiện **0 đ**, vì không giao dịch nào trỏ tới nó.

Phía server không có cách nào tránh bước này khi client còn ánh xạ id như hiện nay. Gỡ xung đột tên (xoá, đổi tên) là để lượt
`create` lọt qua; giữ xung đột thì giữ luôn chỗ kẹt. Id giả tất định, nên dù nhiều máy cùng đẩy cũng chỉ có **một** ví ma.
Đây là một ví bình thường, id UUID hợp lệ.

**Bước 3 — xoá mềm ví ma, sau khi nó đã xuất hiện.** Kiểm trước:

```sql
SELECT "Idwallet","Name","Balance","Delete_at","Create_at" FROM wallet
 WHERE "Idwallet" = '00000000-0000-4000-8000-4534d71cc54d';
```

Có hàng, `Delete_at` NULL, `Idaccount` 18, thì xoá mềm:

```sql
UPDATE wallet SET "Delete_at" = (now() AT TIME ZONE 'UTC')
 WHERE "Idwallet" = '00000000-0000-4000-8000-4534d71cc54d' AND "Idaccount" = 18 AND "Delete_at" IS NULL;   -- mong đợi: 1 hàng
```

Chưa có hàng nghĩa là chưa máy nào đồng bộ sau bước 1. Chờ, rồi kiểm lại. Người dùng cũng có thể tự xoá ví ma trong app
(ví 0 đ, không giao dịch, không hoá đơn, không phải ví mặc định). Đường xoá ấy đi đúng đồng bộ. Bên nào làm trước cũng được;
bên sau chỉ cần thấy hàng đã xoá.

### Việc 2 — sửa ca 11 của `Test/test_data_security_encryption_and_masking.js`

1. **Không chọn tài khoản có sẵn.** Thay dòng 236–237 bằng một tài khoản test do chính script tạo ra. Phần **tạo** có thể theo
   khuôn `Test/test_user_soft_delete_and_auth_rules.js` (dòng 18: `user_del_${timestamp}`). Phần **dọn** thì đừng chép khuôn ấy:
   khối `finally` của nó (dòng 270–279) **xoá cứng** (`deleteMany`) ví, người dùng và tài khoản. Ca 11 có giao dịch, nên xoá cứng
   tài khoản sẽ lan sang giao dịch (`onDelete: Cascade`) và vấp trigger `protect_transaction_hard_delete`
   (`database/10_Data_Security_And_Retention_Triggers.sql:47`). Bỏ hẳn nhánh `: 1` ở dòng 237, vì `1` là tài khoản admin thật.
2. **Id là UUID:** `crypto.randomUUID()` cho cả `idwallet` (dòng 243) lẫn `idtran` (dòng 253). Mọi id đi qua đồng bộ phải là
   UUID. Id khác bị client đổi thành id giả, và đó chính là lỗi của đơn này.
3. **Dọn trong `finally`** để vẫn dọn khi một `assert` gãy: **xoá mềm** giao dịch (`Deleted_at`), ví (`Delete_at`) và tài khoản
   test (`Delete_at` + `Status`, như đường xoá tài khoản của backend).

### Việc 3 (mức thấp) — các script cùng khuôn

- `Test/test_sync_new_schema.js:21`: `findFirst({ where: { idrole: 2, delete_at: null } })`.
- `Test/test_can_lam_fixes.js:44`: `findMany({ where: { idrole: 2, status: 'Active', delete_at: null }, take: 2 })`.

Cả hai cũng ghi vào **tài khoản người dùng có sẵn**. Các ví *"Tài khoản VCB"* (`test_sync_new_schema.js`), *"Ví Tiết Kiệm
Test"* và *"Ví Dedup Test"* (`test_can_lam_fixes.js`) trong tài khoản 18 khớp tên với hai script này. Chúng dùng UUID và tự
dọn, nên **không** gây lỗi của đơn này. Nhưng lỗi cùng loại (chạy nhầm lên production là ghi vào người dùng thật), nên đề nghị
chuyển sang tài khoản test riêng như việc 2.

Ba script `Test/test_ai_dedup_flow.js`, `Test/test_ai_ocr_full_flow.js`, `Test/test_bank_sepay_flow.js` ghi cứng
`idaccount: 18`. Client **chưa kiểm** chúng có ghi CSDL không (một phần có thể là đối tượng giả). Nếu có ghi thì cùng loại.

## Kiểm lại

**Sau bước 1:**

```sql
SELECT "Idwallet","Delete_at","Server_update_at" FROM wallet WHERE "Idwallet" = 'test-wallet-1789014227658';
SELECT count(*) FILTER (WHERE "Deleted_at" IS NULL) AS con_song, count(*) AS tong
  FROM "transaction" WHERE "Idwallet" = 'test-wallet-1789014227658';
```

Mong đợi: `Delete_at` khác NULL; `Server_update_at` mới hơn giờ chạy bước 1; `con_song = 0`, `tong = 9`.

**Sau bước 3:** câu `SELECT` của bước 3 trả một hàng có `Delete_at` khác NULL.

**Toàn CSDL, sau khi sửa script** (chạy script hai lần rồi đo):

```sql
SELECT count(*) FROM wallet
 WHERE "Idwallet" !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' AND "Delete_at" IS NULL;      -- 0
SELECT count(*) FROM "transaction"
 WHERE "Idtran" !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' AND "Deleted_at" IS NULL;      -- 0
-- Script không còn ghi vào tài khoản có sẵn trước giờ chạy. Lọc theo tên ví của ca 11, vì người dùng vẫn tự tạo ví thật
-- trong tài khoản 18; ví ma của bước 2 (cũng tên "Ví Test Note") loại riêng.
SELECT count(*) FROM wallet w JOIN account a ON a."Idaccount" = w."Idaccount"
 WHERE w."Create_at" > '<giờ chạy script>' AND a."Create_at" < '<giờ chạy script>'
   AND w."Name" = 'Ví Test Note' AND w."Idwallet" <> '00000000-0000-4000-8000-4534d71cc54d';                         -- 0
```

**Phía client** (client tự đo sau khi backend báo xong, trên OnePlus):

- *"Ví Test Note"* biến mất khỏi Quản lý ví, cả ví gốc lẫn ví ma.
- Tổng số dư ở Trang chủ giảm 300.000 đ, dòng `enc:…` mất.
- CSDL chép từ máy không còn hàng `pending`; log không còn *"giãn cách sau … chu kỳ hỏng"*.

Đạt thì client đóng G98.

## Ghi nhận (không xin trong đơn này)

Ghi chú của 2 giao dịch còn sống tới client dưới dạng chuỗi `enc:…` thô. `decrypt` (`utils/crypto.util.js:84` trở đi) trả lại
nguyên chuỗi khi không giải mã được. Client **chưa đo** vì sao lần này không giải mã được. Giả thuyết: backend chạy script và
backend phục vụ `/sync/pull` dùng hai `DATA_ENCRYPTION_KEY` khác nhau trên cùng CSDL dev. Triệu chứng sẽ mất khi bước 1 xoá mềm
hai giao dịch. Nếu nhiều máy trong nhóm chạy backend với khoá khác nhau trên cùng một CSDL, ghi chú đẩy qua máy này sẽ hiện thô
khi kéo qua máy kia. Backend nên kiểm cấu hình khoá.

## Không chặn client

Client không đổi mã vì đơn này. Trong lúc chờ, mọi máy đăng nhập tài khoản 18 còn giữ hàng kẹt, và đồng bộ của tài khoản ấy
có thể bị hoãn tới 15 phút. Tài khoản khác không bị ảnh hưởng.

---

## Trả lời đơn

**Lead BA & Lead FullStack đã hoàn tất 100% xử lý và kiểm thử:**
- **Sửa script test (`Test/test_data_security_encryption_and_masking.js`):**
  + Tuyệt đối không chọn Admin (`idrole: 1`), chỉ chọn user thường (`idrole: 2`).
  + Tạo ví test động với UUID hợp lệ (`crypto.randomUUID()`) kèm tiền tố nhận diện, không dùng ID cứng phi chuẩn dạng `test-wallet-1789...`.
  + Bọc trong khối `finally { ... }` để luôn tự động dọn dẹp (xoá mềm giao dịch và ví test) kể cả khi test fail hoặc crash giữa chừng, đảm bảo không bao giờ để lại dữ liệu rác trên tài khoản người dùng thật.

