# CSDL dev chưa áp các tệp `database/7`–`11`, trong khi mã backend đã phụ thuộc vào chúng

**Ngày:** 2026-09-10 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** áp năm
tệp SQL **đã có sẵn** theo đúng thứ tự rồi `prisma generate`, cộng một chỗ sửa nhỏ
ở `middleware/auth.js`. Không cần viết migration mới.

---

## 1. Tóm tắt

Đợt gộp `main` về nhánh client (`bef37d3`, 2026-09-10) mang theo mã backend dùng
hai cột mới của `account` (`Reason_Inactive`, `Countdown`) và các tệp SQL mới
trong `src/Backend/database/`. **CSDL dev trên máy client chưa áp tệp nào từ 7
tới 11.**

Backend vẫn khởi động và đồng bộ bình thường — nhưng chỉ vì Prisma Client trong
`node_modules` cũng **cũ** (sinh 2026-09-07). Hai thứ cũ khớp nhau; còn những chỗ
mã **gọi tên** trường mới thì vỡ, và một chỗ vỡ **theo hướng cho qua**: phép kiểm
tài khoản ở `middleware/auth.js` hỏng ở mọi request rồi mặc định coi tài khoản là
hợp lệ.

⚠️ Client **không chạy** các tệp này — `src/Backend` và CSDL là vùng chỉ đọc với
client (quy tắc 1 của `CLAUDE.md`). Mọi phép đo dưới đây là truy vấn **đọc**.

---

## 2. Đo được gì — 2026-09-10

### 2.1. Từng tệp một

| Tệp | Dấu hiệu đo | Kết quả |
|---|---|---|
| `5_Drop_Cross_Default_Category_Trigger.sql` | `uq_category_owner_name` / `uq_category_default_name` đúng định nghĩa của tệp; 0 trigger ngoài hệ thống trên `category` | ✅ đã áp |
| `6_Drop_Category_Group_Membership.sql` | `to_regclass('public.category_group_membership')` → `null` | ✅ đã áp |
| `7_Update_Account_User_Delete_Rules.sql` | `account_Email_key`, `user_Email_key` **không** có `WHERE`; `account_Username_key` vẫn UNIQUE; `wallet."Status"` vẫn `varchar(7)` | ❌ chưa áp bước nào |
| `8_Add_Reason_Inactive_To_Account.sql` | `SELECT "Reason_Inactive" FROM account` → `42703 column does not exist` | ❌ |
| `9_Add_Countdown_To_Account.sql` | `SELECT "Countdown" FROM account` → `42703 column does not exist` | ❌ |
| `10_Data_Security_And_Retention_Triggers.sql` | 0 trigger, 0 hàm trong schema `public` | ❌ |
| `11_Data_Security_Encryption_And_Masking.sql` | không có `bank_account.Account_number_hash`; `Account_number` `varchar(50)`; `user.Phone` `varchar(15)`; 0 trigger | ❌ |

`_prisma_migrations` có 3 dòng — đúng như mong đợi, vì 5–11 **không** phải
migration Prisma (xem mục 4.2).

Các tệp 7–11 vào repo qua `7523c8c`, `6c210ac`, `af918a5` (2026-09-09) và
`1f1f938` (2026-09-10), đều của NPBao, đều đã nằm trên `origin/main`.

### 2.2. Prisma Client đang chạy là bản cũ

| | Sửa lần cuối | `model account` có `reason_inactive` / `countdown`? |
|---|---|---|
| `prisma/schema.prisma` | 2026-09-10 12:13 | có / có |
| `node_modules/.prisma/client/schema.prisma` (bản đã sinh) | 2026-09-07 16:07 | **không / không** |

`Prisma.dmmf` của client đang chạy liệt kê đúng 10 trường vô hướng cho `account`:
`idaccount, idrole, email, username, password, status, type, create_at,
update_at, delete_at`.

---

## 3. Hệ quả hôm nay

### 3.1. Đã thấy trong log — xác thực mặc định CHO QUA

Mỗi request có xác thực (thấy ở cả `/sync/push` lẫn `/sync/pull`):

```
WARN isAccountValid DB check failed, defaulting to optimistic pass {"idaccount":10,
  "error":"Invalid `prisma.account.findUnique()` invocation in
  middleware/auth.js:22:42 … Unknown field `reason_inactive` for select statement
  on model `account`."}
```

`middleware/auth.js:22-25` chọn `reason_inactive` và `countdown`; Prisma Client cũ
không biết hai trường ấy nên từ chối cả câu truy vấn; khối `catch` ở `:47-50` trả
`{ valid: true, status: 'Active' }`. Và vì nhánh lỗi **không** ghi vào
`accountCache`, việc ấy lặp lại ở **từng** request.

Hệ quả: trên bất kỳ môi trường nào đang ở trạng thái này, tài khoản `Inactive`,
`Deleted` hay `PendingDelete` đã hết hạn **vẫn qua được xác thực**. Cơ chế
`ACCOUNT_INACTIVE` / `ACCOUNT_DELETED` mô tả ở `docs/progress/Backend.md` mục 12.1
và 12.4 **không có hiệu lực**.

### 3.2. Suy từ mã và `dmmf` — chưa chạy đầu-cuối

Chưa gọi thử vì cả hai đều **ghi** vào một tài khoản thật:

- `auth.repository.js:194-214` — `scheduleDeletion` / `cancelDeletion` ghi
  `countdown`. Prisma Client cũ từ chối trường lạ, nên
  **`DELETE /api/auth/account`** và **`POST /api/auth/cancel-delete`** hỏng. Client
  **có gọi** hai đường ấy: `auth_remote_data_source.dart:164` và `:181`, từ màn
  `profile/presentation/pages/delete_account_page.dart`.
- `admin.repository.js:54-55`, `:85-86`, `:103`, `:117`, `:144` — cùng cảnh, phía
  Admin-web (danh sách người dùng, khoá tài khoản).

### 3.3. ⚠️ Cái bẫy nếu "sửa" bằng `prisma generate` trước

Prisma mặc định `SELECT` **mọi** cột vô hướng khi câu truy vấn không có `select`.
Sinh lại client theo `schema.prisma` hiện tại mà CSDL chưa có hai cột thì mọi
`prisma.account.find*` trần — **gồm cả đăng nhập** (`auth.repository.js:26-79`,
`:178`) — sẽ đòi `"Reason_Inactive"` và `"Countdown"`, và nhận đúng lỗi `42703` đã
đo ở mục 2.1.

Tức hôm nay đăng nhập còn chạy được **nhờ** Prisma Client cũ. Chạy `generate` trước
khi áp 8 và 9 là tắt đăng nhập.

---

## 4. Việc cần làm

### 4.1. Áp theo đúng thứ tự — chạy từ `src/Backend`

**Bước 0 — đặt khoá mã hoá thật TRƯỚC tệp 11.** `.env` trên máy dev có 16 biến,
**không có** `DATA_ENCRYPTION_KEY` lẫn `BLIND_INDEX_SECRET` (chỉ kiểm **tên** biến),
nên `utils/crypto.util.js:10-11` đang dùng chuỗi mặc định viết trong mã.
`scripts/apply_migration_11.js` mã hoá SĐT và địa chỉ cũ bằng **khoá đang hiệu
lực**. Chạy nó với khoá mặc định rồi mới đặt khoá thật là mọi hàng vừa mã hoá giải
mã hỏng — và `decrypt()` khi hỏng **trả nguyên chuỗi `enc:…`, không báo lỗi**
(chi tiết ở [`SYNC_NOTE_FILTER_REWRITE.md`](./SYNC_NOTE_FILTER_REWRITE.md) mục 8.1).

**Bước 1–4 — tệp 7, 8, 9, 10.** Không tệp nào có script, và không tệp nào nằm
trong `prisma/migrations/`, nên **`prisma migrate deploy` không áp chúng**. Chạy
từng tệp bằng công cụ SQL đội backend vẫn dùng, **mỗi tệp một giao tác**. Tệp 7
đặc biệt nên bọc `BEGIN … COMMIT`: nó `DROP INDEX` trước rồi mới `CREATE`, hỏng
giữa chừng là bảng `account` mất ràng buộc email.

**Bước 5 — tệp 11 qua script**, không chạy tệp SQL trần:

```bash
node scripts/apply_migration_11.js
```

Chỉ script mới mã hoá lại SĐT/địa chỉ đang ở dạng rõ (bước 2 của nó); tệp SQL chỉ
nới cột và dựng trigger. Lưu ý script **không** bọc giao tác: bước 1 (nới cột) và
bước 2 (mã hoá) được ghi riêng trước khi bước 3 chạy tệp SQL.

**Bước 6:**

```bash
npx prisma generate
```

rồi khởi động lại backend. Thứ tự **8, 9 trước `generate`** là bắt buộc — mục 3.3.

### 4.2. Ghi lại quy trình migration

Repo đang có **hai** quy ước cùng lúc:

- `prisma/migrations/` + bảng `_prisma_migrations` — 3 migration, đều đã áp.
- `database/N_*.sql` áp tay — tệp 5 tới 11, **không bảng nào ghi** tệp nào đã áp;
  script chỉ có cho 5, 6 và 11.

Hệ quả thấy ngay ở tài liệu này: không có cách nào hỏi một CSDL "đang ở tệp số
mấy", nên muốn biết phải **đo từng dấu hiệu** như mục 2.1. Xin chọn một quy ước,
hoặc ít nhất ghi **thứ tự và cách áp** vào `docs/progress/Backend.md`.
`CLAUDE.md` của client đang ghi quy ước là `prisma migrate` — sẽ sửa theo câu trả
lời.

### 4.3. `middleware/auth.js` — đừng cho qua khi lỗi là lỗi lược đồ

Có hai loại lỗi rất khác nhau đang đi chung một khối `catch`:

| Loại | Ví dụ | Tự khỏi? |
|---|---|---|
| Lỗi **cấu hình** | `PrismaClientValidationError` (trường lạ), `P2022` / SQLSTATE `42703` (cột không tồn tại) | **Không** — lặp lại ở mọi request cho tới khi có người sửa |
| Lỗi **tạm thời** | mất kết nối CSDL, hết pool | Có |

Xin tách hai loại. Loại đầu nên **từ chối** (503) và log mức `error`. Cho qua chỉ
còn hợp lý với loại sau, nếu đội backend vẫn muốn ưu tiên sẵn sàng. Hôm nay loại
đầu im lặng biến một cơ chế bảo mật thành không có gì, với một dòng `WARN` lẫn giữa
các dòng khác.

---

## 5. Kiểm lại sau khi áp

Chạy từ `src/Backend`. Chỉ đọc. Mỗi dòng in ra có tiền tố `ROW|` — lọc bằng
`grep "^ROW|"`, **đừng** cắt bằng `head`/`tail`.

```bash
node -e "
const {PrismaClient,Prisma}=require('@prisma/client');const p=new PrismaClient({log:[]});
(async()=>{
const q=(s)=>p.\$queryRawUnsafe(s);
for (const r of await q(\"SELECT table_name||'.'||column_name c, format_type(a.atttypid,a.atttypmod) t FROM information_schema.columns c JOIN pg_attribute a ON a.attrelid=('public.'||quote_ident(c.table_name))::regclass AND a.attname=c.column_name WHERE c.table_schema='public' AND (c.table_name,c.column_name) IN (('account','Reason_Inactive'),('account','Countdown'),('wallet','Status'),('user','Phone'),('bank_account','Account_number'),('bank_account','Account_number_hash'))\"))
  console.log('ROW|COL|'+r.c+'|'+r.t);
for (const r of await q(\"SELECT indexname, indexdef FROM pg_indexes WHERE schemaname='public' AND indexname IN ('account_Email_key','user_Email_key','account_Username_key','idx_account_username')\"))
  console.log('ROW|IDX|'+r.indexname+'|'+r.indexdef);
for (const r of await q(\"SELECT c.relname, t.tgname FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid WHERE NOT t.tgisinternal ORDER BY 1,2\"))
  console.log('ROW|TRG|'+r.relname+'|'+r.tgname);
const m=Prisma.dmmf.datamodel.models.find(x=>x.name==='account');
console.log('ROW|DMMF|'+m.fields.filter(f=>f.kind==='scalar').map(f=>f.name).join(','));
await p.\$disconnect();})();" | grep "^ROW|"
```

Phải thấy:

- `ROW|COL|` — `account.Reason_Inactive` `text`, `account.Countdown` `integer`,
  `wallet.Status` `character varying(20)`, `user.Phone` và
  `bank_account.Account_number` `character varying(256)`,
  `bank_account.Account_number_hash` `character varying(64)`.
- `ROW|IDX|` — `account_Email_key` và `user_Email_key` **có** `WHERE ("Delete_at"
  IS NULL)`; **không còn** `account_Username_key`; có `idx_account_username`.
- `ROW|TRG|` — đủ bốn: `audit_log|trg_protect_auditlog`,
  `transaction|trg_protect_transaction`, `user|trg_check_phone_encrypted`,
  `bank_account|trg_check_bank_account_encrypted`.
- `ROW|DMMF|` — có `reason_inactive` và `countdown`.

Rồi một phép thử sống: log backend **không còn** dòng `isAccountValid DB check
failed` sau một request có xác thực.

---

## 6. Liên quan tới client

- **G28 (lưu trữ ví):** tệp 7 nới `wallet."Status"` lên `varchar(20)` — đúng việc
  [`WALLET_STATUS_COLUMN_WIDTH.md`](./WALLET_STATUS_COLUMN_WIDTH.md) xin, và
  `schema.prisma` đã khai sẵn `VarChar(20)` từ `7523c8c`. Áp xong thì client mở lại
  ba chỗ ở mục 5 tài liệu ấy. Người dùng đã chốt để việc phía client **sau** — tài
  liệu này không mở lại nó.
- **Xoá tài khoản / huỷ xoá** phía client phụ thuộc tệp 9 (mục 3.2).
- **Bộ lọc ghi chú** ([`SYNC_NOTE_FILTER_REWRITE.md`](./SYNC_NOTE_FILTER_REWRITE.md))
  **độc lập** với 7–11: nó ở tầng ứng dụng và đã chạy thật trên CSDL chưa áp gì
  này. Áp 7–11 không sửa được nó, và sửa nó không cần chờ 7–11.
