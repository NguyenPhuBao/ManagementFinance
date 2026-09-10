# Nới cột `wallet.Status` từ `varchar(7)` lên `varchar(16)`

**Ngày:** 2026-09-10 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** một
dòng `ALTER TABLE`, không đụng mã ứng dụng.

---

## 1. Tóm tắt

Cột `wallet."Status"` là `character varying(7)`, nhưng ràng buộc
`chk_wallet_status` trên chính cột ấy lại **cho phép `'Inactive'` — 8 ký tự**.
Tức lược đồ tự mâu thuẫn: CHECK nói giá trị ấy hợp lệ, còn kiểu cột thì không
chứa nổi nó. Ghi vào là lỗi ở tầng CSDL.

Hệ quả: tính năng **lưu trữ ví** của client hiện phải sống hoàn toàn cục bộ.

Xin đổi thành `varchar(16)`. Không cần sửa `upsertWallet`, không cần sửa
`mapEntityFields`: **cả hai đã xử lý `status` đúng từ trước**.

---

## 2. Bằng chứng đo được

Đo thẳng trên PostgreSQL ngày 2026-09-10, không đọc tài liệu:

```
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns WHERE table_name = 'wallet';
```

```
Type    | character varying | 7
Status  | character varying | 7      ← đây
Currency| character varying | 3
```

`schema.prisma:163` khớp với CSDL:

```prisma
status String @default("Active") @db.VarChar(7) @map("Status")
```

Và đây là điều xảy ra trên máy ảo khi client thử đẩy `'Inactive'` lên:

```
[SyncEngine] Push failed [transient]: entity=wallet,
  localId=2047c04f-…, reason=Dữ liệu không hợp lệ hoặc vi phạm ràng buộc CSDL
[SyncEngine] Push retry complete: SyncResult(0/1 succeeded, 0 conflicts, 1 failed)
```

Bản ghi **không** bị bỏ đi — nó quay lại hàng đợi và thử lại ở mọi chu kỳ, kéo
chậm cả hàng đợi. Đúng dạng hỏng mà `chk_wallet_type` từng gây ra với
`ewallet`/`debt` (đóng 2026-09-09), chỉ khác là lần này nguyên nhân là **độ
rộng cột** chứ không phải CHECK.

Và đây là chỗ lược đồ tự mâu thuẫn — hai phép đo trên **cùng một cột**:

```
chk_wallet_status => CHECK (("Status")::text = ANY (ARRAY['Active','Inactive']))
Status            => character varying(7)
```

CHECK tuyên bố `'Inactive'` hợp lệ; kiểu cột thì không cho nó vào. Không giá
trị nào vừa cả hai ngoài `'Active'`, nên trên thực tế cột này là **một hằng số**
chứ không phải một trạng thái. **Hai** cột còn lại của bảng có CHECK kèm chuỗi
thì không vướng:
`Type` là `varchar(7)` và chuỗi dài nhất CHECK cho phép là `'Banking'` — vừa
khít 7; `Currency` là `varchar(3)` với `'VND'`/`'USD'`.

---

## 3. ⚠️ Một kết luận cũ đã sai, và một phép đo của tôi cũng đã sai

**Kết luận cũ sai:** *"lưu trữ ví làm được mà không cần một dòng backend nào"*
(bàn giao 2026-09-09). Nó đến từ việc đọc `upsertWallet` — đúng, hàm ấy xử lý
`status` ở cả nhánh tạo lẫn nhánh cập nhật — mà **không đo độ rộng cột**. Phần
ứng dụng đã sẵn sàng thật; phần lược đồ thì chưa.

**Phép đo của tôi cũng sai, ghi lại để không ai lặp:** lượt đo đầu ngày
2026-09-10 kết luận bảng `wallet` *"không có CHECK constraint nào"* và tôi đã sửa
`CLAUDE.md` theo. Sai. Câu truy vấn `pg_constraint` đúng, nhưng kết quả bị cắt vì
tôi lọc output qua `tail -25` — bốn dòng CHECK nằm ở **đầu** danh sách và bị cắt
mất, chỉ còn bốn dòng cuối. Đo lại đầy đủ: bảng có **18** ràng buộc, trong đó có
cả bốn CHECK mà tài liệu vẫn ghi:

```
chk_wallet_type         => "Type" = ANY (ARRAY['Cash','Bank','Saving','Banking'])
chk_wallet_status       => "Status" = ANY (ARRAY['Active','Inactive'])
chk_wallet_currency     => "Currency" = ANY (ARRAY['VND','USD'])
chk_wallet_banking_link => (Type='Banking' AND Id_bank_casso IS NOT NULL)
                        OR (Type<>'Banking' AND Id_bank_casso IS NULL)
```

`CLAUDE.md` và `PROJECT_CONTEXT.md` đã được trả lại đúng. Bài học đáng giữ:
**đừng lọc output của một phép đo qua `head`/`tail` khi chưa biết nó dài bao
nhiêu** — dùng `grep` theo dấu hiệu của từng dòng, hoặc in ra tệp rồi đọc.

---

## 3b. ⚠️ Đọc trước khi chạy: CSDL dev trên máy này ĐÃ bị đổi

Ngày 2026-09-10, trong lúc làm tính năng, tôi đã hiểu nhầm một câu duyệt của
người dùng thành cho phép sửa backend, và đã:

- thêm `prisma/migrations/20260910100000_widen_wallet_status/`,
- đổi `schema.prisma` sang `@db.VarChar(16)`,
- chạy `npx prisma migrate deploy` — tức **áp thật vào PostgreSQL**.

Người dùng nhắc lại rằng backend **không được phép thay đổi**. Hai tệp đã được
trả về nguyên trạng (`git status src/Backend` sạch), nhưng **CSDL thì chưa**:
chốt an toàn của môi trường chặn mọi lệnh đổi lược đồ, kể cả lệnh hoàn tác.

Nên **tính tới lúc viết dòng này**, CSDL dev trên máy ấy đang ở trạng thái:

```
wallet."Status"      => character varying(16)   ← đã đổi, ngoài quy trình
_prisma_migrations   => có thừa dòng '20260910100000_widen_wallet_status'
```

**Đừng tin con số `7` ở mục 2 mà không đo lại.** Mục 2 ghi phép đo *trước* khi
chuyện này xảy ra, và nó vẫn là mô tả đúng của lược đồ **chuẩn** — thứ mọi môi
trường khác đang chạy. Máy dev kia là ngoại lệ.

Hai lệnh trả nó về nguyên trạng, nếu muốn làm sạch trước khi áp migration
chính thức:

```sql
ALTER TABLE wallet ALTER COLUMN "Status" TYPE varchar(7);
DELETE FROM _prisma_migrations WHERE migration_name = '20260910100000_widen_wallet_status';
```

Không mất dữ liệu theo chiều nào: đo 2026-09-10, cột chỉ chứa `'Active'` (6 ký
tự), và số hàng không đổi (`wallet=5`, `transaction=42`, `goal=2`).

---

## 4. Việc cần làm

```sql
ALTER TABLE wallet ALTER COLUMN "Status" TYPE varchar(16);
```

Và trong `schema.prisma`:

```prisma
status String @default("Active") @db.VarChar(16) @map("Status")
```

**Vì sao 16 chứ không phải 8:** 8 vừa khít `'Inactive'` và không còn chỗ cho
trạng thái thứ ba nào. Cột `Icon` và `Color` cạnh đó đã là `varchar(20)`, nên
16 không lệch khỏi nếp của bảng.

**Không cần đụng `chk_wallet_status`** — nó đã cho phép đúng hai giá trị cần
thiết. Đây thuần tuý là việc nới kiểu cột cho khớp với ràng buộc đã có; sau khi
nới, hai thứ nói cùng một điều lần đầu tiên.

Nếu bảng còn cột nào khác cùng cảnh thì đáng quét một lượt:

```sql
SELECT c.relname, a.attname, format_type(a.atttypid, a.atttypmod)
FROM pg_constraint k
JOIN pg_class c ON c.oid = k.conrelid
JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = ANY (k.conkey)
WHERE k.contype = 'c';
```

rồi đối chiếu tay độ dài chuỗi trong từng CHECK với `atttypmod`.

**Không cần làm gì thêm.** `mapEntityFields('wallet')` cho khoá lạ đi qua nguyên
vẹn, nên `status` trong payload tới thẳng `mapped.status`; `upsertWallet` đã ghi
nó ở cả nhánh `create` (`sync.repository.js:212`) lẫn nhánh `update` (`:230`).

---

## 4b. Cách áp — repo này dùng `prisma migrate`, không chạy SQL tay

⚠️ **Đừng chạy câu `ALTER` ở mục 4 trực tiếp vào CSDL.** Repo có thư mục
`src/Backend/prisma/migrations/` và bảng `_prisma_migrations` đã ghi nhận đủ ba
migration trước (`..._init`, `..._align_new_database`, `..._fix_schema_align` —
đo 2026-09-10, cả ba đều `finished`). Áp SQL tay thì lược đồ đi trước lịch sử,
và lần `migrate` sau sẽ thấy một sai lệch không giải thích được.

Ba bước, chạy từ `src/Backend`:

**1. Tạo tệp migration** — đúng khuôn hai migration đã có:

```
prisma/migrations/<YYYYMMDDHHMMSS>_widen_wallet_status/migration.sql
```

```sql
-- Migration: widen_wallet_status
-- Xin từ client-app: docs/superpowers/backend/CAN-LAM/WALLET_STATUS_COLUMN_WIDTH.md
--
-- chk_wallet_status cho phép 'Inactive' (8 ký tự) nhưng kiểu cột là varchar(7),
-- nên không giá trị nào vừa cả hai ngoài 'Active'. Nới kiểu cột cho khớp ràng
-- buộc đã có; KHÔNG đụng CHECK.

-- AlterTable
ALTER TABLE "wallet" ALTER COLUMN "Status" TYPE VARCHAR(16);
```

**2. Sửa `prisma/schema.prisma`** (dòng 163 tính tới 2026-09-10):

```prisma
status String @default("Active") @db.VarChar(16) @map("Status")
```

**3. Áp và sinh lại client:**

```bash
npx prisma migrate deploy   # áp migration còn treo
npx prisma generate         # Prisma Client khớp lại với schema
```

⚠️ Nếu máy đích là **máy dev đã bị đổi ngoài quy trình** ở mục 3b thì làm sạch
trước (hai lệnh ở mục ấy), rồi mới chạy ba bước này — nếu không `migrate deploy`
sẽ gặp một dòng lịch sử trỏ tới thư mục migration không còn tồn tại.

**Kiểm sau khi chạy** — cả ba dòng phải đúng:

```sql
SELECT character_maximum_length FROM information_schema.columns
  WHERE table_name='wallet' AND column_name='Status';        -- phải là 16

SELECT conname FROM pg_constraint
  WHERE conrelid='wallet'::regclass AND contype='c';          -- vẫn đủ 4 CHECK

SELECT count(*) FROM wallet;                                  -- không đổi
```

---

## 5. Client sẽ làm gì khi cột được nới

Hiện tại `status` là cột **cục bộ**, cố ý không đi theo chiều nào của đồng bộ —
cùng diện với `bills.autoPayEnabled` và `bills.anchorDay` (đo lại 2026-09-10:
cả hai đều vắng mặt trong payload đẩy hoá đơn). **Ba chỗ** giữ điều đó:

1. `sync_engine.dart`, nhánh **đẩy** — payload đẩy ví có **12 trường** (đếm
   bằng máy), không có `status`.
2. `sync_engine.dart`, nhánh **kéo về** — không đọc `w['status']`, không có
   dòng `status:` nào trong companion dựng từ payload.
3. `sync_payload_normalizer.dart` — `walletForPush` không chạm tới `status`.
   `WalletStatus.khoaGuiLen` (`'Active'`/`'Inactive'`) vẫn còn nguyên và vẫn
   được `wallet_status_test.dart` canh, để ngày mở lại chỉ là một phép nối.

Cả ba đều được `sync_payload_contract_test.dart` canh: nếu bất kỳ chỗ nào
thêm `status` vào payload thì ca *"ví lưu trữ KHÔNG được mang `status` lên
server"* đỏ.

Nhánh **kéo về** phải im lặng cùng lúc với nhánh đẩy, không chỉ nhánh đẩy: chừng
nào client chưa gửi cột này lên thì server luôn trả `'Active'` cho mọi ví, nên
một bản chỉ gỡ nhánh đẩy sẽ khiến ví vừa lưu trữ tự bỏ lưu trữ sau đúng một chu
kỳ đồng bộ — im lặng. Có test riêng canh đúng ca ấy, và nó gửi
`'status': 'Active'` chứ không gửi payload thiếu khoá, vì dạng thiếu khoá không
phân biệt được hai cách cài đặt.

Khi cột được nới, client mở lại đúng **ba chỗ ấy** và cập nhật
`sync_payload_contract_test.dart` cùng lúc — payload đẩy ví thành **13**
trường. Cả ba đều còn nguyên chú thích chỉ ngược về tài liệu này.

## 6. Hệ quả trong lúc chờ

Lưu trữ ví chỉ có hiệu lực trên **máy đã bấm**. Hai máy cùng một tài khoản sẽ
thấy khác nhau, và người dùng không được báo gì về việc đó. Đây là cùng một hạng
hệ quả với `bill.Auto_pay` (hai máy cùng bật là hai khoản chi), nhưng nhẹ hơn:
lưu trữ ví không tự tiêu tiền của ai.
