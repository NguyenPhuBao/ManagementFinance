# Việc còn lại sau `cbbeeb4` — chốt chống trả hai lần chưa có, năm việc mã nhỏ, sổ ghi migration, tám chỗ tài liệu

**Ngày:** 2026-09-12 · **Xin từ:** client (`src/Client-app`) · **Cỡ việc:** **một** chốt ở
`upsertTransaction` (mục 2.1 — việc duy nhất chặn tính năng phía client); năm việc mã nhỏ
(mỗi việc vài dòng, gồm 2.7 thêm chiều cùng ngày); một bảng sổ ghi migration; **tám** câu tài liệu. Không migration mới.

> **Đo trên `TranQuangDat` @ `216775c`** — mã `src/Backend` trùng `origin/main` @ `b7024f9`
> (= `cbbeeb4`, PR #79; `git diff cbbeeb4 b7024f9` rỗng) — và trên **CSDL dev đã áp
> `database/13`** (2026-09-12). Cách đo: đọc diff `16bd5b3..cbbeeb4` (14 tệp backend); chạy
> `accountRejection` thật bằng `node -e`; truy vấn **chỉ đọc** PostgreSQL (`pg_constraint`,
> `pg_indexes`, `information_schema`); và **đầu-cuối trên máy ảo `emulator-5554`**, tài khoản
> 11, đọc `adb logcat`. Bảng soát đầy đủ 19/19 ở banner `README.md` cùng thư mục — tài liệu
> này chỉ giữ phần **chi tiết để làm theo** cho những gì còn lại.

---

## 1. Tóm tắt — thứ tự đề xuất

| # | Việc | Mức | Mục |
|---|---|---|---|
| 1 | **Chốt chống trả hai lần chưa có ở đâu cả** — `cbbeeb4` bỏ chốt sai chỗ ở `upsertBill` (đúng) nhưng chưa đặt chốt ở `upsertTransaction`; `BILL_ALREADY_PAID` nay là mã chết | 🔴 chặn client mở đồng bộ `Auto_pay` | **2.1** |
| 2 | Hai câu tài liệu mô tả chốt ấy như đã có (`Rule_project.md:430`, `Backend.md:511`) | 🟡 | **4.3** |
| 3 | `BLIND_INDEX_SECRET` vẫn rơi về chuỗi cứng im lặng — `DATA_ENCRYPTION_KEY` đã có chốt, khoá thứ hai thì chưa | 🟡 | **2.2** |
| 4 | Sổ ghi tệp `database/N` đã áp ở môi trường nào; `Rule_project.md:69` còn "đến migration 12" | 🟡 | **3** |
| 5 | Hai lỗi **mới** trong `New_Database.md`: ví "không có CHECK `Status`" (có), `goal` "có FK `auto_deposit_wallet_id`" (không) | 🟡 | **4.1**, **4.2** |
| 6 | `_mock*` ở OCR/Classify vẫn mở ở mọi môi trường không phải `production`; `'ORC'` còn 3 chỗ | ⚪ | **2.3**, **2.4** |
| 7 | Một ca thử khi chạy cho `WALLET_NAME_DUPLICATE` | ⚪ | **2.5** |
| 7b | `/auth/refresh` với token **đã thu hồi** của tài khoản `Deleted`/`Inactive` trả 401 **không mã** → app đăng xuất không hộp thoại (G36 client) | 🟡 | **2.7** |
| 8 | Bốn chỗ tài liệu còn lại (`ORC`, `sync.completed`, "16 tài liệu", "PASS 100%") | ⚪ | **4.4–4.7** |
| — | *Ngoài phạm vi xin:* `deleteCategory` ném lỗi ở mọi nhánh | ⚪ | **2.6** |

---

## 2. Việc mã

### 2.1. Chốt chống trả hai lần — đặt ở `upsertTransaction` (17 B bước 2)

**Đo được.** `cbbeeb4` xoá `sync.repository.js:451-455` (chốt ở `upsertBill` từ chối đổi
`Pay_status` khỏi `'Payed'`) — **đúng**, đó là bước 1 của mục 17 B: hoàn tác thanh toán nay
lên server được (đo thật 15:10:21 — hoá đơn `3c90acfa…` kẹt 7 lần đẩy lên `Payed → Pending`).
Nhưng bước 2 chưa làm: `grep -rn BILL_ALREADY_PAID` chỉ còn nhánh **ánh xạ** ở
`sync.service.js:171-172` — không chỗ nào **ném** mã ấy. `upsertTransaction`
(`sync.repository.js:292-340`) ghi `idbill` ở `:304` (tạo) và `:326` (sửa) mà không kiểm hàng
khác cùng `idbill`.

**Vì sao gấp.** Client gửi `idbill` trong payload giao dịch từ 2026-09-12 (13 trường,
`sync_payload_contract_test.dart`), đo thấy tới server đúng giá trị. Tình huống chốt sinh ra
để chặn (`DA-XONG/2026-09-06-bill-chuoi-ky-va-an-han.md` mục 6.2): hai máy cùng bật tự thanh
toán, cùng ngoại tuyến qua ngày đến hạn, rồi lần lượt trực tuyến — mỗi máy đẩy **khoản chi
của riêng nó**, server nhận cả hai. Client vì thế **chưa mở** đồng bộ `bill.Auto_pay`
(cột `autoPayEnabled` vẫn cục bộ), và sẽ mở ngay khi chốt này có.

**Sửa** — chép lại từ mục 3.6 `DA-XONG/FIX_BACKEND_3_REGRESSIONS.md`, không đổi:

```js
// sync.service.js — processPush (:69), trước vòng lặp: giao dịch đang bị xoá trong cùng lô
const dangXoaTrongLo = new Set(
  operations
    .filter((o) => o?.entity === 'transaction' && o?.operation === 'delete')
    .map((o) => o.payload?.id || o.payload?.idtran)
    .filter(Boolean),
);
// ... truyền dangXoaTrongLo vào upsertTransaction(data, dangXoaTrongLo)

// sync.repository.js — gọi TRƯỚC prisma.transaction.create (:296) và .update (:319)
async function chanTraHaiLan({ idtran, idbill, deleted_at }, dangXoaTrongLo = new Set()) {
  if (!idbill || deleted_at) return;
  const khac = await prisma.transaction.findFirst({
    where: { idbill, deleted_at: null, idtran: { notIn: [idtran, ...dangXoaTrongLo] } },
    select: { idtran: true },
  });
  if (khac) {
    throw Object.assign(new Error('Hóa đơn đã được thanh toán bằng một giao dịch khác'), {
      code: 'BILL_ALREADY_PAID',
    });
  }
}
```

Ở nhánh sửa, `idbill` và `deleted_at` của hàng **kết quả** là
`mapped.x !== undefined ? mapped.x : existing.x` — cùng quy ước `:326` và `:335` đang dùng.

**Bẫy thứ tự trong lô** (mục 3.5 tài liệu cũ, vẫn nguyên): `getOperationWeight`
(`sync.service.js:57-63`) cho *xoá* giao dịch trọng số `100 − 40 = 60`, chạy **sau** mọi
*ghi* giao dịch (40). Người dùng hoàn tác rồi trả lại trước khi kịp đồng bộ → lô có *xoá T1*
và *ghi T2* cùng `idbill`; T2 xử lý khi T1 còn sống. Tập `dangXoaTrongLo` ở trên là để loại
trừ đúng ca này — **không bỏ** nó.

**Kiểm lại** (mục 3.7 tài liệu cũ; tài khoản thử, `<hd>`/`<t1>`/`<t2>`/`<t3>` là UUID v4 mới):

1. Hoàn tác: đẩy hoá đơn `pay_status: 'Payed'`, rồi đẩy `'Pending'` với `updatedAt` mới hơn →
   cả hai `synced`; `SELECT "Pay_status" FROM bill WHERE "Idbill"='<hd>'` ra `Pending`.
   *(Đã chạy đúng trên backend thật 2026-09-12 — giữ làm ca hồi quy.)*
2. Trả hai lần: hai khoản chi `type: 'Transaction'`, `amount` âm, cùng `billId: '<hd>'`,
   hai lô riêng → lô đầu `synced`, lô sau `error` với `code: 'BILL_ALREADY_PAID'`;
   `SELECT count(*) FROM transaction WHERE "Idbill"='<hd>' AND "Deleted_at" IS NULL` ra `1`.
3. Hoàn tác rồi trả lại **trong cùng lô**: `{entity:'transaction', operation:'delete',
   payload:{id:'<t1>'}}` + khoản chi `<t3>` cùng `billId` → cả hai `synced`; phép đếm vẫn `1`.

Xoá mềm hàng thử sau khi kiểm — không xoá vật lý (quy tắc 5 `CLAUDE.md`).

### 2.2. `BLIND_INDEX_SECRET` chưa có chốt (18 §2.6, nửa còn lại)

`utils/crypto.util.js:15-24` chặn khởi động ở `production` khi thiếu `DATA_ENCRYPTION_KEY` —
✅. Nhưng `:26` vẫn `RAW_BLIND_SECRET = _rawBlindSecret || 'blind-index-default-secret-salt-2026'`
mà không một dòng cảnh báo. Blind index là thứ dùng để **tra soát** webhook SePay
(`bank_account.Account_number_hash`, tệp 11): production chạy với secret mặc định thì mọi hash
đều đoán được từ mã nguồn mở. Xin: lặp lại đúng khối `:15-24` cho `_rawBlindSecret`, cùng
thông điệp `[SECURITY]`. Lưu ý đi kèm, đã ghi ở tài liệu cũ: CSDL dev đã có hash tính bằng
secret mặc định — đổi secret về sau phải kèm bước tính lại `Account_number_hash`.

### 2.3. Cửa hậu `_mock*` (18 §2.8)

`ocr.controller.js:22-25` và `classify.controller.js:108-113` nhận `_mockExtraction`,
`_mockUser`, `_mockWallets`, `_mockBankAccounts` từ body khi `NODE_ENV !== 'production'`.
`.env` dev đặt `development`; **không tệp triển khai nào trong repo đặt `production`**
(`grep -rn NODE_ENV` ngoài `node_modules`: chỉ hai chỗ này và `crypto.util.js`). Xin **một**
trong hai: (a) ghi vào `Rule_project.md` rằng môi trường triển khai **bắt buộc**
`NODE_ENV=production` và nêu tệp nào đặt nó; hoặc (b) chặn bằng cờ tường minh
`ALLOW_MOCK_INPUT=true` chỉ có trong `.env` của máy dev/test.

### 2.4. `'ORC'` còn ba chỗ mã (18 §2.8)

`Backend.md:514` và `Project.md:2647` ghi *"thay thế triệt để `'ORC'`"*, nhưng `grep -rn ORC
--include=*.js modules workers utils core` (2026-09-12) còn:

| Tệp | Dòng | Loại | Sửa |
|---|---|---|---|
| `modules/sync/sync.repository.js` | 308 | mã — danh sách provider suy `status` có cả `'ORC'` và `'OCR'` | bỏ `'ORC'` (`sync.validation.js:153` đã đổi `ORC → OCR` trước khi tới đây) |
| `modules/ai/features/ocr/ocr.service.js` | 8 | chú thích | `'ORC'` → `'OCR'` |
| `modules/ai/features/dedup/dedup.service.js` | 14 | chú thích JSDoc | `'ORC'` → `'OCR'` |

(`ocr.service.js:25` và `vision.extractor.js:56` nhắc tên tệp `docs/AI/ORC.md` — đó là tên
tệp thật, không đổi.) Vô hại khi chạy; xin sửa để câu "triệt để" thành đúng.

### 2.5. Một ca thử cho `WALLET_NAME_DUPLICATE` (18 §2.7)

`sync.service.js:176-186` (`cbbeeb4`) nhận diện rộng hơn: `uq_wallet_account_name`,
`err.meta.target` có `'Name'`, hoặc `isWallet && /name/i`. Đọc mã thì đủ, nhưng chưa ai chạy.
Xin một ca: đẩy hai ví cùng `idaccount`, cùng `name`, `deleted_at: null`, hai lô → lô sau phải
`error` với `code: 'WALLET_NAME_DUPLICATE'` (không phải `UNIQUE_VIOLATION`). Ghi kết quả vào
tài liệu này hoặc `Backend.md`. Client không kẹt ở cả hai mã (đều vĩnh viễn ở
`sync_engine.dart`), chỉ mất phần thông báo đúng lý do.

### 2.6. *Ngoài phạm vi xin* — `deleteCategory` không còn đường nào chạy được

`modules/admin/admin.service.js:336-342` (thêm ở `4796f94`): `if (!cat.is_default) throw 403`
rồi ngay dưới `if (cat.is_default) throw 400`. Một danh mục hoặc mặc định hoặc không, nên
`adminRepository.deleteCategory(idcategory)` ở `:343` **không bao giờ** được gọi. Nếu đây là
chủ ý ("danh mục hệ thống không xoá được", `Rule_project.md` 1.3) thì xin gỡ endpoint hoặc
ghi rõ; nếu không thì bỏ nhánh 400. Không ảnh hưởng client — ghi vì thấy khi đọc diff.

### 2.7. `/auth/refresh` với token đã thu hồi của tài khoản đã xoá — trả kèm mã tài khoản (mới, đo 2026-09-12 chiều)

**Đo được.** Tạo tài khoản thử `kiemthu_xoa` (idaccount 12), đăng nhập giữ refresh token, admin
`DELETE /api/admin/deleteuser/12` (200), rồi `POST /auth/refresh` bằng token ấy:

```
401 {"success":false,"message":"Refresh token khong hop le","errors":null}
```

Không `code`, không `idaccount`. Cùng lúc `GET /auth/profile` (token truy cập cũ) trả đúng
`401 {"code":"ACCOUNT_DELETED","idaccount":12,"reason_inactive":null,...}`. Nguyên nhân: xoá mềm thu
hồi **cả 5** refresh token của tài khoản (`refreshtoken.Status = true`), và `auth.service.js:375-387`
kiểm `storedToken.status === true` rồi ném ngay — **trước** đoạn `getAccountValidity` /
`accountRejection` ở `:404-418` (chính đoạn 17 A vừa sửa).

**Vì sao đáng sửa.** Client hiện hộp thoại "vì sao bị đẩy ra" từ `code` của ba nguồn (spec cưỡng chế
đăng xuất §3.5). App **đang mở** thì socket `account.force_logout` tới trước, mọi thứ đúng (đo thật cùng
ngày). Nhưng app **ngoại tuyến lúc bị xoá/khoá** rồi mở lại sau khi access token hết hạn: request đầu
→ 401 "Token expired" → `/auth/refresh` → 401 không mã → app đăng xuất **trơn, không hộp thoại**;
người dùng chỉ biết lý do khi thử đăng nhập lại. Client không tự sửa được: lúc ấy không token nào còn
sống để hỏi. (Ghi ở `docs/CLIENT_APP_KNOWN_GAPS.md` G36.)

**Sửa** — `auth.service.js`, nhánh `if (!storedToken || storedToken.status === true)` (`:378`): khi
`storedToken` **có** (chỉ là đã thu hồi), kiểm tài khoản trước khi ném lỗi token:

```js
if (storedToken && storedToken.status === true) {
  // ... giữ nguyên phần thu hồi toàn bộ token của tài khoản (:379-386)
  const accountInfo = await getAccountValidity(storedToken.idaccount);
  if (accountInfo.errorType !== 'SCHEMA_ERROR') {
    const rejection = accountRejection(accountInfo, storedToken.idaccount);
    if (rejection) {
      // Tài khoản không còn dùng được: nói lý do ấy, không nói "token sai".
      throw Object.assign(new Error(rejection.message), { statusCode: 401, ...rejection.data });
    }
  }
}
throw Object.assign(new Error("Refresh token khong hop le"), { statusCode: 401 });
```

Token thu hồi của tài khoản **còn sống** vẫn trả câu cũ, không mã — đúng như hôm nay. Không đổi
`accountRejection`, không đổi controller (đã đọc `code`/`idaccount`/`reason_inactive`).

**Kiểm lại.** Lặp đúng phép đo ở trên với một tài khoản thử mới (đăng ký qua OTP mock — `.env` dev
không có SMTP nên `email.service.js` ghi OTP ra log): sau `DELETE /admin/deleteuser/<iduser>`,
`/auth/refresh` bằng token cũ phải trả 401 **kèm** `"code":"ACCOUNT_DELETED"` và `"idaccount"` ở cấp
gốc. Lặp với `PATCH /admin/updatestatus/<iduser>` `Inactive`: nếu khoá **không** thu hồi token thì
kết quả đã đúng từ 17 A (đo cùng ngày: 401 + `ACCOUNT_INACTIVE`); nếu có thu hồi thì phải ra
`ACCOUNT_INACTIVE` + `reason_inactive`. Tài khoản 12 (`kiemthu_xoa`) đang xoá mềm trên CSDL dev —
để nguyên, không xoá cứng (quy tắc 5).

---

## 3. Sổ ghi migration và ghi chú partial index (18 §2.4)

`Rule_project.md:69` chọn quy ước `database/N_*.sql` + `schema.prisma` + `prisma generate`,
nhưng (a) còn ghi *"đến migration 12"* trong khi đã có tệp 13; (b) không có bảng nào ghi
**tệp nào đã áp ở môi trường nào**, nên mỗi lần gộp `main` client phải tự đo từng cột;
(c) `_prisma_migrations` trên CSDL dev chỉ có 3 dòng, `scripts/apply_migration_*.js` chỉ có
cho 5, 6, 11, 12, 13.

**Xin một bảng** trong `Rule_project.md` §3.2, khuôn dưới — client điền phần **đã đo trên CSDL
dev** (2026-09-12), backend điền cột môi trường của mình:

| N | Nội dung | Câu kiểm (ra ≥ 1 hàng là đã áp) | Dev client | Supabase |
|---|---|---|---|---|
| 5 | Gỡ trigger cấm trùng chéo danh mục người dùng ↔ mặc định | `SELECT tgname FROM pg_trigger WHERE tgrelid='category'::regclass AND NOT tgisinternal` → **không** còn trigger chéo | ✅ | ? |
| 6 | Bỏ bảng `category_group_membership` | `SELECT 1 FROM information_schema.tables WHERE table_name='category_group_membership'` → **0 hàng** | ✅ | ? |
| 7 | Email partial unique (`account_Email_key`, `user_Email_key` `WHERE "Delete_at" IS NULL`); `idx_account_username` thường; `wallet.Status` → `varchar(20)` | `SELECT indexdef FROM pg_indexes WHERE indexname='account_Email_key'` có `WHERE`; `SELECT character_maximum_length FROM information_schema.columns WHERE table_name='wallet' AND column_name='Status'` = 20 | ✅ | ? |
| 8 | `account.Reason_Inactive` | `… WHERE table_name='account' AND column_name='Reason_Inactive'` | ✅ | ? |
| 9 | `account.Countdown` | `… column_name='Countdown'` | ✅ | ? |
| 10 | Trigger bảo vệ dữ liệu (`trg_check_phone_encrypted`, `trg_protect_auditlog`, …) | `SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg_%'` | ✅ | ? |
| 11 | `Phone`/`Account_number` → `varchar(256)`; `bank_account.Account_number_hash` + index | `… table_name='bank_account' AND column_name='Account_number_hash'` | ✅ | ? |
| 12 | `category.Color`; `transaction.Idbill` + `fk_transaction_bill`; `bill.Previous_bill_id`/`Period_end`/`Auto_pay`/`Anchor_day`; `chk_bill_pay_status` có `'Skipped'`; bỏ `uq_wallet_saving_active` | `SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='chk_bill_pay_status'` có `Skipped` | ✅ 2026-09-11 | ✅ (backend báo) |
| 13 | Bỏ `DEFAULT 0` của `budget.Threshold_Warning_Percent`; hai index ví `IF NOT EXISTS` | `SELECT column_default FROM information_schema.columns WHERE table_name='budget' AND column_name='Threshold_Warning_Percent'` → `NULL` | ✅ 2026-09-12 | ✅ (backend báo) |

**Ghi chú xin thêm vào cùng mục:** `schema.prisma` không diễn đạt được partial index, nên trên
CSDL đã áp đủ tệp, `prisma migrate diff` **luôn** báo lệch 5 index (`account_Email_key`,
`user_Email_key`, `idx_bill_previous_bill`, `idx_transaction_bill`, `idx_transaction_goal`) —
chạy `prisma migrate dev` sẽ sinh migration **tạo lại** chúng không có `WHERE`. Quy trình phải
ghi rõ: **không** dùng `migrate dev`/`db push` trên CSDL này; chỉ `generate`.

---

## 4. Tám chỗ tài liệu backend còn sai (số dòng HEAD `216775c` = `b7024f9`)

Mỗi mục: câu hiện tại → câu đề nghị, kèm phép đo.

### 4.1. `New_Database.md:172` và `:374` — ví "không có CHECK cho `Status`" (lỗi **mới**)

Đo `pg_constraint`: `wallet` có **bốn** CHECK, trong đó
`chk_wallet_status CHECK ("Status" IN ('Active','Inactive'))`.
- `:172` → `| \`Status\` | Varchar(20) | Default 'Active'. Check in (\`Active\`, \`Inactive\`) — \`chk_wallet_status\` | Trạng thái ví | ✅ Cho phép. Plaintext | Theo ví |`
- `:374` cuối câu: `(**Không** có CHECK cho \`Status\`)` → `; \`Status IN ('Active', 'Inactive')\` (\`chk_wallet_status\`)`.

### 4.2. `New_Database.md:396` — FK `auto_deposit_wallet_id → Wallet` không tồn tại (lỗi **mới**)

Đo: `SELECT conname FROM pg_constraint WHERE conrelid='goal'::regclass AND contype='f'` ra
đúng hai hàng `fk_goal_account`, `fk_goal_wallet`. Dòng 397 ngay dưới đã ghi đúng
*"`auto_deposit_wallet_id` (varchar(36) không có FK)"* — hai dòng kề nhau mâu thuẫn.
Xin bỏ vế `; \`auto_deposit_wallet_id\` → \`Wallet(Idwallet)\` (\`ON DELETE SET NULL\`)` khỏi `:396`.
(Client **cố ý** không xin FK này — `docs/GOAL_FEATURE.md` mục 4; nếu backend muốn thêm thì
là một migration mới, không phải sửa tài liệu.)

### 4.3. `Rule_project.md:430` và `Backend.md:511` — mô tả chốt chưa có

Hai câu này viết theo đề nghị 17 C của client, với giả định 17 B bước 2 đã làm. Hôm nay
không đúng. Hai lối: **(a)** làm mục 2.1 rồi giữ nguyên câu; **(b)** chưa làm thì sửa tạm —
`Rule_project.md:430` → *"Từ `cbbeeb4`, `/sync/push` **không** chặn giao dịch thứ hai cùng
`Idbill` (chốt cũ ở `upsertBill` đã bỏ vì chặn cả hoàn tác; chốt ở giao dịch chưa đặt — xem
CAN-LAM 20 §2.1). Mã `BILL_ALREADY_PAID` được ánh xạ nhưng hiện không nơi nào ném."*;
`Backend.md:511` bỏ `BILL_ALREADY_PAID (giao dịch thứ hai cùng Idbill)` khỏi danh sách "ba mã
riêng" hoặc ghi chú tương tự. Client đề nghị **(a)**.

### 4.4. `Rule_project.md:69` — "đến migration 12"

→ *"(đến migration **13**; sổ ghi tệp đã áp ở bảng dưới)"* kèm bảng mục 3.

### 4.5. `Backend.md:13`, `:157`, `:514` và `Project.md:2647` — `ORC`

- `:13` `\`ORC\` (OCR hình ảnh)` → `\`OCR\` (hoá đơn/biên lai quét ảnh)`.
- `:157` `provider = 'ORC'` → `provider = 'OCR'`.
- `:514`, `Project.md:2647` *"thay thế triệt để"* — đúng **sau** khi làm mục 2.4; tới lúc đó là sai.

### 4.6. `Backend.md:495` — `sync.completed` "khi background worker xử lý xong"

Đo: sự kiện chỉ publish ở `sync.service.js:232`, **sau mỗi `/sync/push`**;
`workers/bank.worker.js` publish `bank_transaction.pending` và `transaction.created`, không
`sync.completed`. → *"phát `sync.completed` qua EventBus → Socket.IO tới phòng `account_<id>`
**sau mỗi `/sync/push`** (worker ngân hàng không phát sự kiện này)"*. `Project.md:2643` đã
ghi đúng ("sau khi đồng bộ dữ liệu").

### 4.7. `Backend.md:475` — "16 tài liệu trong CAN-LAM"

`CAN-LAM/README.md` và `Project.md:2635,2643` ghi 15 (đợt trước) và 19 (nay). → *"19 tài
liệu (15 đợt 2026-09-10, thêm 17–19 đợt 2026-09-12)"*.

### 4.8. `Backend.md:186-193`, `Project.md:2646-2650` — "PASS 100%" cho `Test/`

Thư mục `Test/` bị `.gitignore`, không có trong repo (`ls src/Backend/Test` trên máy client:
không tồn tại). Câu "PASS 100%" không ai ngoài máy tác giả kiểm được. Xin **một** trong hai:
đưa các script ấy vào repo (bỏ khỏi `.gitignore`, hoặc chuyển sang `src/Backend/tests/`), hoặc
sửa câu thành *"chạy trên máy dev của backend, script không nằm trong repo"* — đúng như
`Data_Security.md:223` đã sửa ngày 2026-09-12.

---

## 5. Liên quan tới client

- **Việc duy nhất chặn client là 2.1.** Có chốt ấy, client mở đồng bộ `bill.Auto_pay` (bước 12
  hàng đợi `PROJECT_CONTEXT.md`) và đón `BILL_ALREADY_PAID` theo đúng nghĩa mới — tự hoàn tác
  khoản trả cục bộ khi server báo hoá đơn đã có khoản chi khác.
- **2.7** không chặn tính năng nhưng là lỗ hổng trải nghiệm đang chạy (G36); client **không đổi mã** khi backend sửa — `tuBody401(nguon: lamMoi)` đã đọc đúng hình dạng.
- Mọi việc khác ở đây **không** chặn gì phía client; client không cần đổi mã cho chúng.
- Khi backend sửa xong 2.1, xin **báo** — client sẽ đo lại bằng ba ca ở 2.1 trước khi mở
  `Auto_pay`, giống cách đã đo hoàn tác ngày 2026-09-12.
