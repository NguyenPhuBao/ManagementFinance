# Nới cột `wallet.Status` từ `varchar(7)` lên `varchar(16)`

**Ngày:** 2026-09-10 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** một
dòng `ALTER TABLE`, không đụng mã ứng dụng.

---

## 1. Tóm tắt

Cột `wallet."Status"` hiện là `character varying(7)`. Giá trị mà client cần ghi
vào đó là `'Inactive'` — **8 ký tự**. Nó không vừa, nên tính năng **lưu trữ ví**
của client hiện phải sống hoàn toàn cục bộ.

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
`ewallet`/`debt`, chỉ khác là lần này nguyên nhân là **độ rộng cột** chứ không
phải CHECK constraint.

---

## 3. ⚠️ Hai điều tài liệu nội bộ đang ghi SAI

Ghi lại ở đây vì chúng đã dẫn tới một vòng làm việc thừa, và cả hai đều nằm
trong `CLAUDE.md` lẫn bàn giao phiên trước.

**Thứ nhất — bảng `wallet` KHÔNG có CHECK constraint nào.** Đo cùng ngày:

```
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint WHERE conrelid = 'wallet'::regclass;
```

trả về **đúng bốn** dòng, và không dòng nào là CHECK:

```
wallet_Update_at_not_null  => NOT NULL "Update_at"
wallet_pkey                => PRIMARY KEY ("Idwallet")
fk_wallet_account          => FOREIGN KEY ("Idaccount") REFERENCES account(…)
fk_wallet_bank             => FOREIGN KEY ("Id_bank_casso") REFERENCES bank_account(…)
```

Tức `chk_wallet_type`, `chk_wallet_status`, `chk_wallet_currency` và
`chk_wallet_banking_link` **không tồn tại** trên CSDL này. Thứ thật sự giới hạn
giá trị là **độ rộng `varchar`**, và nó giới hạn một cách khác hẳn: `varchar(7)`
nhận `'Cash'`, `'Bank'`, `'Saving'`, `'Banking'` và cũng nhận cả `'ewallet'`
(7 ký tự) lẫn bất kỳ chuỗi rác nào ≤ 7 ký tự. Client vẫn giữ nguyên phép ánh xạ
chặt ở `wallet_type.dart` — nó vẫn đúng và vẫn đáng giữ — nhưng lý do ghi trong
đó ("CHECK constraint sẽ từ chối") không phải lý do thật.

**Thứ hai — "lưu trữ ví không cần một dòng backend nào" là sai.** Kết luận ấy
đến từ việc đọc `upsertWallet` (đúng: nó xử lý `status` ở cả hai nhánh) mà
không đo độ rộng cột. Phần ứng dụng đã sẵn sàng; phần lược đồ thì chưa.

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
16 không lệch khỏi nếp của bảng. Nếu muốn siết giá trị thì thêm

```sql
ALTER TABLE wallet ADD CONSTRAINT chk_wallet_status
  CHECK ("Status" IN ('Active', 'Inactive'));
```

— nhưng **hãy đo lại dữ liệu hiện có trước**, vì bảng chưa từng có ràng buộc này
và không ai biết chắc trong đó chỉ có hai giá trị ấy.

**Không cần làm gì thêm.** `mapEntityFields('wallet')` cho khoá lạ đi qua nguyên
vẹn, nên `status` trong payload tới thẳng `mapped.status`; `upsertWallet` đã ghi
nó ở cả nhánh `create` (`sync.repository.js:212`) lẫn nhánh `update` (`:230`).

---

## 5. Client sẽ làm gì khi cột được nới

Hiện tại `status` là cột **cục bộ**, cố ý không đi theo chiều nào của đồng bộ —
cùng diện với `bills.autoPayEnabled` và `bills.anchorDay`. Hai chỗ giữ điều đó,
và cả hai đều có test canh:

- `sync_engine.dart` — payload đẩy ví có **12 trường**, không có `status`; nhánh
  kéo về **không đọc** `w['status']`.
- `sync_payload_normalizer.dart` — `walletForPush` không chạm tới `status`,
  nhưng `WalletStatus.khoaGuiLen` (`'Active'`/`'Inactive'`) vẫn còn nguyên và
  vẫn được test canh.

Nhánh **kéo về** phải im lặng cùng lúc với nhánh đẩy, không chỉ nhánh đẩy: chừng
nào client chưa gửi cột này lên thì server luôn trả `'Active'` cho mọi ví, nên
một bản chỉ gỡ nhánh đẩy sẽ khiến ví vừa lưu trữ tự bỏ lưu trữ sau đúng một chu
kỳ đồng bộ — im lặng. Có test riêng canh đúng ca ấy, và nó gửi
`'status': 'Active'` chứ không gửi payload thiếu khoá, vì dạng thiếu khoá không
phân biệt được hai cách cài đặt.

Khi cột được nới, client mở lại **ba dòng** và cập nhật
`sync_payload_contract_test.dart` cùng lúc.

## 6. Hệ quả trong lúc chờ

Lưu trữ ví chỉ có hiệu lực trên **máy đã bấm**. Hai máy cùng một tài khoản sẽ
thấy khác nhau, và người dùng không được báo gì về việc đó. Đây là cùng một hạng
hệ quả với `bill.Auto_pay` (hai máy cùng bật là hai khoản chi), nhưng nhẹ hơn:
lưu trữ ví không tự tiêu tiền của ai.
