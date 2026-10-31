# Việc backend còn phải làm — MỘT tệp (đơn 52 · 55 · 57 · 58 · 59 + việc nhỏ 48.1 + tài liệu T1–T3, T6)

> **Người nhận:** backend (NPBao). Tệp này **chỉ còn việc phải làm** — client soát PR #172 ngày **2026-10-31** (backend `5ff06db4`).
> **Kết quả soát 24 việc PR #172 báo `✅ ĐÃ XONG`: 5 đạt · 15 một phần · 4 chưa.** Đạt (đã xoá khỏi tệp): 57.4, 58.1, 58.2 (đã chạy thật với payload app), 57.5, 49.F(1) (đọc mã).
> Việc đã đạt không còn ở đây — xem git log: bản có báo cáo của backend `git show 5ff06db4:docs/superpowers/backend/CAN-LAM/VIEC_BACKEND_CON_LAI.md`, bản đề bài trước đó `git show 55c727d9:…` / [`LICH-SU/`](./LICH-SU/).
> Mỗi việc có **mã** giữ số đơn cũ (`57.2`, `52.3`…). Tám tệp đơn gốc ở `LICH-SU/` là lịch sử, không cập nhật — đừng ghi trả lời vào đó.
>
> **Lưu ý chung cho mọi việc:**
> - 🛑 **Hai lỗi đang làm hỏng đường chạy do chính PR #172 — sửa trước tiên:** 57.2 (`GET /invitations`, `…/accept`, `…/decline` 500; app gọi `/invitations` mỗi lần đăng nhập) và 57.6 (`POST /dissolve` luôn 500).
> - **Ca test đi đường thật** (route HTTP / `syncService.processPush`, CSDL riêng hoặc giả ở tầng Prisma; không giả chính hàm cần chứng minh) với **payload như app gửi** — `src/Client-app/test/core/sync/sync_payload_contract_test.dart`. App luôn gửi `idaccount` **của hàng** (người ghi) và `operation: 'update'` / `'delete'` — **không bao giờ** `'create'`. Ca xanh cả trên mã cũ là chưa canh gì.
> - Migration theo tệp `src/Backend/database/N_*.sql` áp tay (`docs/Rule_Project/Rule_project.md` §3.2). Không xoá cứng dữ liệu người dùng. Thử trên **CSDL riêng**, không trên Supabase dùng chung.
> - **Trả lời** ghi vào bảng mục 10. Bảng mục 0, văn ở các mục khác và README mục 0 + banner là vùng client cập nhật — đừng ghi đè.
>
> Mọi `tệp:dòng` của backend đọc ở HEAD `5ff06db4`. Đơn mới thêm mục vào tệp này — số kế tiếp **60**.

---

## Cách làm — đọc trước

Client đã **thử toàn bộ phần sửa mã trên một bản sao + CSDL tạm** (không đụng `src/Backend`, Supabase, `PersonFinance`). Trong thư mục [`KIEM-THU/`](./KIEM-THU/):

| Tệp | Là gì |
|---|---|
| [`ban_sua_pr172.patch`](./KIEM-THU/ban_sua_pr172.patch) | Bản vá 23 tệp, áp sạch lên `5ff06db4` (đã kiểm `git apply`). Phủ các việc đánh dấu **[vá]** ở bảng mục 0 |
| [`chay_kiem.js`](./KIEM-THU/chay_kiem.js) | Kịch bản nghiệm thu 50 ca chạy **thật** trên CSDL riêng, payload như app; thay socket + email bằng bản ghi nhận; tự từ chối chạy nếu `DATABASE_URL` không phải CSDL `flowmoney_kiem_thu` trên máy này |
| [`ket_qua_ma_hien_tai_5ff06db4.txt`](./KIEM-THU/ket_qua_ma_hien_tai_5ff06db4.txt) | Kết quả trên mã hiện tại, để đối chiếu: **23 đạt / 50 ca** |

Số đo của client: mã hiện tại **23 / 50**, sau bản vá **50 / 50**; `tests/unit/*.test.js` **481 / 486 trước và sau bản vá**. Ba ca hỏng ở cả hai bản đều do môi trường đo, không do bản vá: `data_encryption_group4_audit` ca 5, 8 cần khoá `.env` / dữ liệu Supabase (client đo không có `.env`); `household_and_aiops_v2` ca 2 dùng id cứng 104 mà gọi thật `findActiveMemberByAccount`, nên hỏng khi CSDL thử đã có tài khoản ấy (vì thế bước 5 dùng CSDL mới). Bản vá đã sửa kèm 4 tệp test đang khẳng định hành vi cũ.

⚠️ **Đặt `DATABASE_URL` TRƯỚC mọi lệnh `prisma`.** Thiếu biến thì Prisma rơi về `.env` = **Supabase dùng chung**. Không dùng `--force-reset` ở đâu trong việc này. Dòng `Datasource "db"` Prisma in ra phải ghi đúng tên CSDL thử.

**Các bước** (Git Bash, từ gốc repo; PowerShell thì đặt biến bằng `$env:TEN = '…'`):

```bash
# 1. Tạo CSDL riêng. Prisma tự tạo CSDL; dòng in ra phải ghi "flowmoney_kiem_thu" — sai thì DỪNG.
cd src/Backend
export DATABASE_URL="postgresql://postgres:<mật khẩu>@127.0.0.1:5432/flowmoney_kiem_thu"
export DIRECT_URL="$DATABASE_URL" NODE_ENV=development LOG_LEVEL=error REDIS_PROVIDER=none REDIS_URL=
npx prisma db push --skip-generate --schema prisma/schema.prisma

# 2. Đo mốc trên mã hiện tại: phải ra "TỔNG: 23 đạt / 50 ca"
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem.js . kq_truoc.txt

# 3. Áp bản vá (từ gốc repo). Mã đã đổi so với 5ff06db4 mà không áp được thì sửa tay theo "Cách sửa" từng việc bên dưới.
cd ../.. && git apply --ignore-whitespace docs/superpowers/backend/CAN-LAM/KIEM-THU/ban_sua_pr172.patch && cd src/Backend

# 4. Chạy lại: phải ra "TỔNG: 50 đạt / 50 ca". Không xoá ca nào cho xanh.
node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem.js . kq_sau.txt

# 5. Bộ test đơn vị, trên một CSDL riêng MỚI (bước 2, 4 đã ghi dữ liệu vào CSDL kia)
export DATABASE_URL="postgresql://postgres:<mật khẩu>@127.0.0.1:5432/flowmoney_kiem_thu_unit"
export DIRECT_URL="$DATABASE_URL"
npx prisma db push --skip-generate --schema prisma/schema.prisma
NODE_ENV=test node --test --test-force-exit tests/unit/*.test.js
```

6. Làm các việc **ngoài bản vá** (bảng mục 0, cột *Phần tay*): ca test, tài liệu, khoá.
7. Chép `chay_kiem.js` vào `src/Backend/scripts/verify_household_contract.js` (sửa đường dẫn trong lời dặn đầu tệp) và thêm `"verify:household"` vào `package.json`, để lần sau chạy lại được.
8. Commit, ghi mục 10 (dán dòng `TỔNG:` của bước 4). **Không cần** `npm install`, `prisma generate` hay migration mới: `schema.prisma` không đổi; ba tệp SQL trong bản vá (33, 41, 44) chỉ có tác dụng khi áp trên CSDL mới hoặc áp lại.

---

## 0. Bảng việc — xếp theo mức

**[vá]** = mã đã có trong `ban_sua_pr172.patch` và đã chạy thử.

| Mã | Việc | Mức | Mục | Bản vá | Phần tay |
|---|---|---|---|---|---|
| 57.6 | `POST /dissolve` **luôn 500** — `transaction` dùng sai cột `delete_at` (hồi quy PR #172) | **CAO** | 1 | [vá] | — |
| 57.2 | `GET /invitations` **500 với mọi tài khoản**; `…/accept`, `…/decline` 500 với lời mời hợp lệ (hồi quy PR #172) | **CAO** | 1 | [vá] | — |
| 59.1 | Hàng mới mang `idhousehold` không kiểm `idaccount` ⇒ ghi được hoá đơn vào tài khoản người khác (hồi quy PR #172) | **CAO** | 1 | [vá] | — |
| 58.5 | AIOps: admin khoá rồi AIOps ghi đè ⇒ **tự mở sau hạn** (hồi quy PR #172); khởi động lại không mở; dấu lộ ra app | **CAO** | 2 | [vá] | — |
| 58.3 | `HOUSEHOLD_DISSOLVED` không bao giờ chạy vì 57.6 | VỪA | 1 | [vá] | — |
| 58.4 | Nhà của `sync.completed` vẫn lấy từ `payload.idhousehold` | VỪA | 1 | [vá] | — |
| 59.3 | Tài khoản nào cũng đẩy được danh mục mới thành khuôn toàn cục (có sẵn) | VỪA | 1 | [vá] | — |
| 57.7 | Nhà `ReadOnly` `/join` được (hồi quy PR #172); mã lệch; chưa có bảng mã chốt | VỪA | 1 | [vá] | Dán bảng mã chốt vào mục 10 |
| 57.1 | Hàm đạt; #15 hỏng theo 57.2; test còn hình dạng phẳng | VỪA | 1 | [vá] | Sửa `household.api.test.js` |
| 57.3 | Tên nhà chèn HTML không thoát; không có ca test | VỪA | 1 | [vá] | Thêm một ca test |
| 55.A3 | Hàm chung, job hạ cấp hàng hạn NULL; chưa ghi hợp đồng | VỪA | 5 | [vá] | Ghi hai tài liệu |
| 52.1 | `mask*` có `context` nhưng 6 chỗ gọi không truyền | VỪA | 4 | [vá] | Thêm một ca test |
| 52.3 | Chưa chốt khoá cho `PersonFinance` ở tài liệu nào | VỪA | 4 | — | Dán câu chốt, chạy kiểm |
| 52.4 | Chưa xác nhận khoá **trên Render** | VỪA | 4 | — | So vân tay khoá |
| 52.5 | Supabase + khoá `.env` đạt; còn `/sync/pull` 200, `PersonFinance`, mã thoát của script | VỪA | 4 | — | Sửa script, ghi mục 10 |
| T1 | `Event-Notification-to-ClientApp.md` — 0 dòng sửa, banner phủ 3 / 18, banner sai hai mục | VỪA | 8.1 | — | Sửa tại dòng |
| T2 | `IP-Device-ClientApp.md` — banner phủ 1 / 3, banner sai cơ chế throttle | VỪA | 8.2 | — | Sửa tại dòng |
| T3 | `4_TRU_COT.md` — banner phủ 5 / 19 | VỪA | 8.3 | — | Sửa tại dòng |
| 57.8 | Đạt #1–#4; #6 `memberCount` luôn 1 | THẤP | 1 | [vá] #6 | Ba câu trả lời #5, #7, #8 |
| 58.6 | Đạt `chuConPremium`, thứ tự mã, vế AIOps; 41 + 44 `DO UPDATE`, 33 lọc rộng | THẤP | 1 | [vá] 33, 41, 44 | Hai script `Test/`, script nghiệm thu |
| 59.2 | Xoá hàng chưa từng lên server bị tính là hàng mới (hồi quy PR #172) | THẤP | 1 | [vá] | — |
| 48.1 | Ô trả lời viện dẫn `scripts/cleanup` không tồn tại, ngày lệch, không có tên | THẤP | 6 | — | Một câu ở mục 10 |
| T6 | Câu sai mới viết ở `Backend.md`, `Project.md`; ca test PayOS không đi nhánh nó nêu | THẤP | 8.6 | — | Sửa tại dòng |

---

## 1. Gia đình phần 1 — chặn client mở đường ghi vào nhà (lát 2)

**Đặc tả** (không đổi): `docs/Family/01_NEN_MONG.md` (thắng khi lệch) và đơn 50 —
[`LICH-SU/GIA_DINH_NEN_MONG.md`](./LICH-SU/GIA_DINH_NEN_MONG.md). Supabase đo 2026-10-31: 0 nhà, 0 thành viên, 0 lời mời; migration 44 đã áp. Đóng 57 + 58.3 / 58.4 / 58.6 là đóng 56 và 50.

Viết tắt: **SS** = `modules/sync/sync.service.js`, **SR** = `modules/sync/sync.repository.js`, **HS** = `modules/household/household.service.js`,
**HR** = `modules/household/household.repository.js`, **HC** = `modules/household/household.controller.js`.

### Đơn 57 — hợp đồng API `/api/households`

#### 57.6 (CAO, hồi quy PR #172) — `POST /dissolve` luôn 500 · [vá]

**Chỗ sai:** HR:310-313 dùng `delete_at` cho bảng `transaction`; cột là `deleted_at` (`prisma/schema.prisma:351`; ví, ngân sách, mục tiêu, danh mục đúng là `delete_at`). Cả lô `$transaction` bị từ chối, không giải tán được nhà nào, HS:512 không chạy. Trước PR đường này chạy. Ca `household_group1_completion.test.js:18-110` mock Prisma rồi khẳng định đúng cột sai (`:85`).
**Đã chạy xác nhận:** `PrismaClientValidationError: Unknown argument delete_at. Did you mean deleted_at?`.

**Cách sửa** — trong `dissolveHousehold` của HR:

```js
prisma.wallet.updateMany({
  where: { idhousehold: hhId, delete_at: null },
  data: { delete_at: now, update_at: now, server_update_at: now },
}),
// Bảng transaction dùng cột deleted_at, khác bốn bảng còn lại
prisma.transaction.updateMany({
  where: { idhousehold: hhId, deleted_at: null },
  data: { deleted_at: now, update_at: now, server_update_at: now },
}),
// budget, goal, category: như wallet, thêm server_update_at: now
```

`server_update_at` đặt tường minh: `/sync/pull` lọc theo cột ấy, đừng chỉ dựa vào trigger. Ca test `:85` đổi sang `updatedTx.data.deleted_at` + `updatedTx.where.deleted_at === null`.
**Kiểm lại:** `chay_kiem.js` các ca 57.6.

#### 57.2 (CAO, hồi quy PR #172) — `getCallerEmail` không tồn tại trên đối tượng service · [vá]

**Chỗ sai:** `getCallerEmail` là hàm cấp module (HS:28), nhưng HS:696, :715, :741 gọi `householdService.getCallerEmail(...)`. JWT không có `email` (`auth.service.js:197-204`) nên nhánh ấy luôn chạy. Trước PR ba đường này chạy.
**Đã chạy xác nhận:** `TypeError: householdService.getCallerEmail is not a function`.

**Cách sửa:** ở HS:696, :715, :741:

```js
resolvedEmail = await getCallerEmail(idaccount);   // bỏ tiền tố householdService.
```

và HS:744, để email rỗng không còn được bỏ qua kiểm:

```js
if (invite.email) {
  if (!resolvedEmail || resolvedEmail.trim().toLowerCase() !== invite.email.toLowerCase()) {
    throw createError('Lời mời này được gửi đích danh cho tài khoản email khác', 'HOUSEHOLD_INVITE_WRONG_ACCOUNT', 403);
  }
}
```

**Kiểm lại:** `chay_kiem.js` các ca 57.2: người đăng ký sau thấy lời mời; người khác `/join`, `/accept`, `/decline` ⇒ 403; đúng người `/accept` 200 hình dạng lồng, `/decline` 200.

#### 57.1 (VỪA) — phần còn lại

Hàm dựng hình dạng đạt (HS:138-184, đối chiếu từng khoá với bộ đọc của app: không khoá nào đọc thành null). #15 tới được hàm ấy sau khi sửa 57.2.
**Cách sửa (tay):** `tests/unit/household.api.test.js:29-36, :170-174, :214-218, :329-348` đang giả service trả hình dạng phẳng và kiểm `data.ownerIdaccount` (`:227`). Đổi bản giả sang `{ household: { id, name, status, maxMembers, ownerId, createAt, maxSharedWallets, contributionDueDay }, myRole, members, formerMembers }`, đổi `:227` thành `data.household.ownerId`.
**Kiểm lại:** `chay_kiem.js` hai ca 57.1 và ca *"đúng người /accept"*; `household.api.test.js` xanh.

#### 57.3 (VỪA) — phần còn lại · [vá] phần thoát HTML

Mã gửi thư đạt. Còn: thư HTML nhúng `householdName`, `inviterName` không thoát (HS:660) — Chủ nhà đặt tên nhà chứa `<a href=…>` rồi gửi tới địa chỉ bất kỳ, từ miền gửi thật của FlowMoney. Không có ca test nào nhắc `sendInviteEmailAsync`.

**Cách sửa:**

```js
function escapeHtml(value) {
  return String(value ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
// HS:660
<p><strong>${escapeHtml(inviterName)}</strong> đã mời bạn tham gia vào tổ ấm <strong>"${escapeHtml(householdName)}"</strong> …
// cuối thư (mẫu docs/Family/01 mục 2.6)
<p style="font-size:12px;color:#888;">Nếu bạn không biết người mời, hãy bỏ qua thư này.</p>
```

`subject` và `text` là chữ thuần, giữ nguyên. **Ca test thêm tay** (`tests/unit/household_group1_completion.test.js`):

```js
const emailService = require('../../core/email.service');
const goc = emailService.sendMail; const da = [];
emailService.sendMail = async (m) => { da.push(m); };
await householdService.sendInviteEmailAsync({ toEmail: 'a@b.c', householdName: '<a href=x>n</a>', inviterName: 'B', role: 'Member', code: 'ABCD2345', expiresAt: new Date() });
emailService.sendMail = goc;
assert.strictEqual(da[0].to, 'a@b.c');
assert.ok(da[0].html.includes('ABCD2345'));
assert.ok(!da[0].html.includes('<a href=x>'));
```

#### 57.7 (VỪA) — phần còn lại · [vá] mã; bảng mã chốt dán tay

**Chỗ sai:** HS:278, :325 đổi từ `status !== 'Active'` sang `status === 'Dissolved'` ⇒ nhà `ReadOnly` xem trước và **tham gia được** (đã chạy xác nhận). HS:198, :546 gộp ReadOnly + Dissolved thành `HOUSEHOLD_NOT_ACTIVE` 400. Mã đã huỷ ra `_USED` (HS:286, :333, :731; tài liệu `_INVALID` 404). Limiter (`rate-limiter.js:80`) dùng lại `HOUSEHOLD_INVITE_RATE_LIMIT` ⇒ người gõ sai mã 30 lần nhận câu *"Nhà này đã gửi quá nhiều lời mời"*.

**Cách sửa:**

```js
// HS, cạnh createError
function assertHouseholdWritable(status) {
  if (status === 'ReadOnly') throw createError('Nhà đang ở chế độ chỉ xem', 'HOUSEHOLD_READ_ONLY', 409);
  if (status !== 'Active') throw createError('Nhà đã giải tán', 'HOUSEHOLD_CLOSED', 410);
}
// HS:198, :546: thay khối HOUSEHOLD_NOT_ACTIVE
assertHouseholdWritable(membership.household.status);

// previewInvite và joinByCode, ngay sau khối HOUSEHOLD_INVITE_INVALID
if (invite.household.status === 'ReadOnly') {
  throw createError('Nhà đang ở chế độ chỉ xem', 'HOUSEHOLD_READ_ONLY', 409);
}

// HS:286, :333, :731: tách đôi
if (invite.revoked_at) throw createError('Mã mời không còn hiệu lực', 'HOUSEHOLD_INVITE_INVALID', 404);
if (invite.used_at) throw createError('Mã mời đã được sử dụng', 'HOUSEHOLD_INVITE_USED', 409);

// rate-limiter.js:80
code: 'HOUSEHOLD_INVITE_ATTEMPT_LIMIT',
```

**Dán vào mục 10 làm bảng mã chốt** (đã khớp mã sau bản vá; các tên khác `docs/Family` được giữ vì app đã đọc cả hai bộ tên — `cau_loi_nha.dart`; sửa bảng nếu đổi mã):

| Mã | HTTP | Endpoint | Khi nào |
|---|---|---|---|
| `HOUSEHOLD_INVITE_INVALID` | 404 | #6, #7, #15, #16 | Không có mã, nhà đã giải tán, mã đã huỷ |
| `HOUSEHOLD_INVITE_EXPIRED` | 410 | #6, #7, #15, #16 | Quá hạn |
| `HOUSEHOLD_INVITE_USED` | 409 | #6, #7, #15, #16 | Đã dùng |
| `HOUSEHOLD_INVITE_DECLINED` | 409 | #6, #7, #15, #16 | Đã từ chối |
| `HOUSEHOLD_INVITE_WRONG_ACCOUNT` | 403 | #6, #7, #15, #16 | Email tài khoản khác email lời mời |
| `HOUSEHOLD_INVITE_RATE_LIMIT` | 429 | #13 | 20 thư / nhà / 24 giờ hoặc 5 thư / giờ |
| `HOUSEHOLD_INVITE_ATTEMPT_LIMIT` | 429 | #6, #7 | 30 lượt / 15 phút / IP |
| `HOUSEHOLD_READ_ONLY` | 409 | #3, #6, #7, #13, #15 | Nhà `ReadOnly` |
| `HOUSEHOLD_CLOSED` | 410 | #3, #13 | Nhà đã giải tán |
| `HOUSEHOLD_ALREADY_IN_ONE` | 409 | #1, #7, #15 | Đang ở nhà khác |
| `HOUSEHOLD_FULL` | 409 | #3, #7, #13, #15 | Đủ người |
| `FEATURE_DISABLED` | 403 | #1, #7, #15 | Gói không có `household` / `household_join` |
| `FORBIDDEN_NOT_OWNER` | 403 | #3, #4, #5, #8, #9, #10, #12, #13 | Không phải Chủ nhà |
| `NOT_IN_HOUSEHOLD` | 404 | #11 | Không ở nhà nào |
| `OWNER_CANNOT_LEAVE` | 400 | #11 | Chủ nhà rời |
| `HOUSEHOLD_INVITE_NOT_FOUND` | 404 | #5 | Huỷ mã không có |
| `MEMBER_NOT_IN_HOUSEHOLD` / `TARGET_NOT_IN_HOUSEHOLD` | 404 | #8, #10 / #9 | Đích không ở nhà |
| `INVALID_HOUSEHOLD_NAME`, `INVALID_INVITE_CODE`, `INVALID_INVITE_ROLE`, `INVALID_MEMBER_ROLE`, `INVALID_TARGET_USER`, `INVALID_EMAIL` | 400 | #1, #7, #3 + #13, #8, #9, #13 | Dữ liệu sai |
| `CANNOT_CHANGE_OWNER_ROLE`, `CANNOT_TRANSFER_TO_SELF`, `CANNOT_REMOVE_SELF` | 400 | #8, #9, #10 | Thao tác lên chính mình / Chủ |

**Kiểm lại:** `chay_kiem.js` ca 57.7; bảng có ở mục 10. Client sẽ đọc thêm `HOUSEHOLD_INVITE_ATTEMPT_LIMIT` sau khi backend gộp.

#### 57.8 (THẤP) — phần còn lại

Đạt #1, #2, #3, #4.
- **#6 [vá]:** `memberCount` ở HS:705 đọc cột không tồn tại ⇒ luôn 1.

```js
// HR, findPendingInvitationsForEmail: thay `household: true`
household: { include: { _count: { select: { household_member: { where: { left_at: null } } } } } },
// HS:705
memberCount: inv.household?._count?.household_member ?? 1,
```

- **#5, #7, #8 (tay — chỉ cần một câu ở mục 10):** #5 trả lời *"`GET /invites` giữ 5 trạng thái `Pending|Declined|Revoked|Used|Expired`"*; #7 *"giữ trần 5 thư / giờ"*; #8 xác nhận *"`ON DELETE CASCADE` / `SET NULL` ở `database/40` là chủ ý vì không có đường xoá cứng"*, hoặc viết migration đổi. Có câu trả lời, client tự ghi vào `docs/Family/01` mục 2.2, 2.4. Muốn khác thì nói rõ ở mục 10.

**Kiểm lại:** `chay_kiem.js` ca 57.8 #6; ba câu ở mục 10.

### Đơn 58 — lỗi do PR #170 đưa vào (58.1, 58.2 đạt; 58.5 ở mục 2)

#### 58.3 (VỪA) — phần còn lại · [vá theo 57.6]

Thứ tự phát đúng (HS:506-520), chỉ không chạy tới vì 57.6. Sửa 57.6 là đủ.
**Kiểm lại:** `chay_kiem.js`: A, B, C mỗi người đúng một `HOUSEHOLD_DISSOLVED`.

#### 58.4 (VỪA) — phần còn lại · [vá]

**Chỗ sai:** SS:503 đọc nhà từ `op.payload.idhousehold`. Người bất kỳ xoá hàng riêng của mình kèm `idhousehold: H` ⇒ `synced` ⇒ mọi thành viên H nhận `sync.completed` (đã chạy xác nhận); ngược lại, hàng của nhà đẩy không có khoá ấy thì không ai được báo.

**Cách sửa:**

```js
// SS, ngay sau indexedOps
const nhaCuaThaoTac = new Map();

// trong nhánh if (targetHhId), sau khi enforceHouseholdPermission qua
nhaCuaThaoTac.set(idx, Number(targetHhId));

// SS:501-507, thay khối đọc payload
if (results[i]?.status === 'synced' && nhaCuaThaoTac.has(i)) {
  affectedHouseholds.add(nhaCuaThaoTac.get(i));
}
```

**Kiểm lại:** `chay_kiem.js` bốn ca 58.4.

#### 58.6 (THẤP) — phần còn lại

Đạt: `chuConPremium`, thứ tự 5 bậc (người ngoài đổi `idhousehold` hàng của nhà ⇒ `NOT_MEMBER`, đã chạy), vế AIOps.
- **`database/41:45-49`, `database/44:104-109` [vá]:** `account_type_permission` đổi thành `ON CONFLICT ("account_type", "feature_id") DO NOTHING;`. Giữ `DO UPDATE` của bảng `feature`. **Kiểm lại:** đổi tay `is_enabled` rồi áp lại 41, 44 ⇒ giá trị admin giữ nguyên.
- **`database/33:22` [vá]:** `"Email" LIKE 'test\_%@anonymized.local'` — bộ lọc cũ trùng cả tài khoản ẩn danh hoá thật. Script test đang dùng đúng tiền tố `test_`.
- **`Test/test_can_lam_fixes.js`, `Test/test_sync_new_schema.js` (tay):** thêm ngay đầu tệp, trước mọi `require` tới CSDL:

```js
require('dotenv').config({ path: require('path').resolve(__dirname, '../src/Backend/.env') });
if (/supabase\.com/i.test(process.env.DATABASE_URL || '')) {
  console.error('Script này ghi dữ liệu: từ chối chạy trên Supabase dùng chung.');
  process.exit(1);
}
```

  `test_can_lam_fixes.js:437, :440, :449`: thay `deleteMany` bằng xoá mềm; bỏ phần tạo khuôn `is_default: true` ở `:322-330`. `test_sync_new_schema.js`: dời khối dọn `:228-234`, `:246-249` vào `finally`. **Kiểm lại:** chạy với URL Supabase ⇒ thoát trước mọi ghi; ép lỗi ở bước đẩy ⇒ hàng vẫn được xoá mềm.
- **Ca test payload app:** `tests/unit/household.system_impact.test.js` vẫn `create`, không `idaccount`. Thay bằng bước 7 *Cách làm* (`chay_kiem.js` đã có đủ ca Chủ / Member / `Transfer` / trần ví). Tệp cũ giữ hoặc bỏ tuỳ backend, nhưng đừng viện dẫn nó làm bằng chứng.

### Đơn 59 — lỗi do PR #172 đưa vào / phát hiện khi soát PR #172

#### 59.1 (CAO, hồi quy PR #172) — Hàng mới mang `idhousehold` không bị kiểm `idaccount` · [vá]

**Chỗ sai:** bản sửa 57.4 dời chốt *"Ownership mismatch"* vào nhánh hàng riêng. SS:336 nhận nguyên `payload.idaccount` cho hàng mới có `idhousehold`.
**Đã chạy xác nhận:** Member của một nhà đẩy `bill` mới với `idaccount: E` ⇒ `synced`, tài khoản E có thêm một hoá đơn, kéo về qua `/sync/pull` (`bill` không có cột `Idhousehold`). Member tạo khoản mới mang tên Chủ ⇒ `synced`. Trước PR bị chặn. Chỉ xảy ra với yêu cầu tự dựng: hàng mới của app luôn mang `idaccount` của phiên.

**Cách sửa:**

```js
// SS, đầu tệp
const HOUSEHOLD_ENTITIES = new Set(['wallet', 'transaction', 'budget', 'goal', 'category']);

// SS:317-319: bill không có cột nên luôn đi nhánh hàng riêng
const targetHhId = !HOUSEHOLD_ENTITIES.has(entity)
  ? null
  : existingRecord
    ? (existingRecord.idhousehold ?? existingRecord.Idhousehold ?? null)
    : (hasHhKey ? (payloadHh !== null && payloadHh !== undefined ? Number(payloadHh) : null) : null);

// SS:335-337: hàng MỚI thì người ghi luôn là chủ token
} else {
  if (payload.idaccount !== undefined && payload.idaccount !== null && Number(payload.idaccount) !== Number(idaccount)) {
    results[idx] = { localId, status: 'error', code: 'NOT_OWNER', message: 'Hàng mới phải mang idaccount của người đẩy' };
    errors++;
    continue;
  }
  payload.idaccount = Number(idaccount);
}
```

Ca 4 `household_and_aiops_v2.test.js` phải giả `getTransactionById` trả hàng đã có (hiện nó rơi vào nhánh hàng mới nên đang khẳng định đúng lỗi này) và thêm vế hàng mới ⇒ `NOT_OWNER` — bản vá đã làm.
**Kiểm lại:** `chay_kiem.js` bốn ca 59.1.

#### 59.2 (THẤP, hồi quy PR #172) — `delete` hàng chưa từng lên server bị tính là hàng mới · [vá]

**Đã chạy xác nhận:** Chủ nhà xoá ví chưa từng lên server khi nhà đủ trần ⇒ `HOUSEHOLD_WALLET_LIMIT`; client xếp mã này là vĩnh viễn.

```js
// SS:150
const isNewWallet = operation !== 'delete' && (operation === 'create' || !existingRecord);
// SS:169
const isNewTx = operation !== 'delete' && (operation === 'create' || !existingRecord);
// SS:181: khi xoá chỉ xét hàng cũ, không tin type trong payload
const isPayloadTransfer = operation !== 'delete' && String(payload.type || '').toLowerCase() === 'transfer';
```

**Kiểm lại:** `chay_kiem.js` hai ca 59.2. Chủ cũ xoá `Transfer` đã có vẫn phải ra `HOUSEHOLD_ROLE_FORBIDDEN` (ca 58.1).

#### 59.3 (VỪA, có sẵn trước PR) — Danh mục mới `is_default: true` từ client · [vá]

**Đã chạy xác nhận:** tài khoản thường đẩy danh mục mới `is_default: true` ⇒ hàng `Is_default = true`, trả cho **mọi** tài khoản ở `/sync/pull` (SR:303), mọi máy sao thành danh mục riêng. `FORBIDDEN_SYSTEM_DEFAULT` (SR:270) chỉ áp hàng đã có. App không gửi vậy.

```js
// SR:251, trong nhánh prisma.category.create
is_default: false,   // khuôn mặc định chỉ tạo qua Admin-web
```

**Kiểm lại:** `chay_kiem.js` ca 59.3.

---

## 2. AIOps và trạng thái tài khoản (đơn 43)

Viết tắt: **AQ** = `modules/aiops/aiops.quarantine.js`, **AQR** = `aiops.quarantine.repository.js`. Lịch sử: [`LICH-SU/SOAT_SAU_GOP_CD2EE572.md`](./LICH-SU/SOAT_SAU_GOP_CD2EE572.md). Vế AIOps của 58.6 đạt.

### 58.5 (CAO) — còn thiếu sau PR #172 · [vá]

Dấu `[AIOPS_AUTO_QUARANTINE]` đã ghi, tài khoản AIOps khoá đã tự mở (đã chạy, ca 1). **Đã chạy xác nhận** các lỗi còn lại trên CSDL thật + `sweepExpiredQuarantines`:

| Ca | Kịch bản | Hiện tại | Phải là |
|---|---|---|---|
| 2 | Admin khoá lý do R → gõ sai đủ ngưỡng → sau hạn | `Active`, mất lý do ⇒ **người bị khoá tự mở được** | `Inactive`, lý do R |
| 3 | Khoá vĩnh viễn → AIOps khoá lại từ IP khác → sau hạn | `Active` | `Inactive` |
| 4 | AIOps khoá → backend tắt qua mốc hạn → bật lại | `Inactive` mãi | `Active` |
| 5 | Username chứa `Admin` bị AIOps khoá → sau hạn | `Inactive` mãi | `Active` |
| 6 | Admin khoá lý do chứa chữ `AIOps` → sau hạn | `Active` | `Inactive` |
| 7 | `message` socket, 401, 403 | chứa `[AIOPS_AUTO_QUARANTINE]` | không chứa |

Ca 2 nguy hiểm vì `login` trả 401 khi sai mật khẩu **trước** khi xét trạng thái (`auth.service.js:341-343` trước `:363`), nên tài khoản đang khoá vẫn bị đếm. Ca test viện dẫn đi qua `isAccountQuarantined` — hàm không chỗ nào gọi ngoài test (AQ:904).

**Cách sửa:**

```js
// modules/aiops/aiops.reason.js — tệp mới
const AIOPS_AUTO_REASON_PREFIX = '[AIOPS_AUTO_QUARANTINE]';
function lyDoChoNguoiDung(reason) {
  if (!reason) return reason;
  const s = String(reason);
  return s.startsWith(AIOPS_AUTO_REASON_PREFIX) ? s.slice(AIOPS_AUTO_REASON_PREFIX.length).replace(/^[:\s]+/, '') : s;
}
module.exports = { AIOPS_AUTO_REASON_PREFIX, lyDoChoNguoiDung };

// AQ: require hằng + hàm từ tệp trên, bỏ const cũ. AQ:405: báo đây là khoá tự động
this._syncAccountStatusToDatabase(idaccount || cleanUser, 'Inactive', autoReason, { idaccount, username: cleanUser, autoQuarantine: true })

// AQ:683-694: một dấu cố định, bỏ contains và NOT
andConditions.push({ reason_inactive: { startsWith: AIOPS_AUTO_REASON_PREFIX } });

// AQ:696-699: khoá tự động chỉ đụng hàng đang Active
} else if (options.autoQuarantine) {
  andConditions.push({ status: 'Active' });
} else {
  andConditions.push({ status: { not: 'PendingDelete' } });
}

// AQ:720
emitForceLogout(targetId, 'ACCOUNT_INACTIVE', lyDoChoNguoiDung(reason) || 'Tài khoản của bạn đã bị cách ly tạm khóa để bảo vệ an toàn.');

// AQ: hàm mới, gọi ở hydrateFromDatabase (sau loadActiveQuarantines) và cuối sweepExpiredQuarantines
async _reconcileAutoLocks() {
  if (!this.repository || typeof this.repository.getAccountByUsername !== 'function') return false;
  try {
    const { prisma } = require('../../config/db');
    if (!prisma?.account?.findMany) return false;
    const locked = await prisma.account.findMany({
      where: { status: 'Inactive', reason_inactive: { startsWith: AIOPS_AUTO_REASON_PREFIX } },
      select: { idaccount: true, username: true },
    });
    const now = Date.now();
    let changed = false;
    for (const acc of locked) {
      const clean = String(acc.username).toLowerCase();
      // Hàng vừa khoá có thể chưa ghi xong aiops_account_quarantine: RAM còn hiệu lực thì bỏ qua
      const conTrongRam = [...this._pairs.values()].some((r) => r.username && r.username.toLowerCase() === clean
        && (r.accountStatus === 'permanent' || (r.accountStatus === 'temporary' && r.accountExpiresAt > now)));
      if (conTrongRam) continue;
      const row = await this.repository.getAccountByUsername(acc.username);
      const conHieuLuc = row && (row.status === 'PERMANENT'
        || (row.status === 'TEMPORARY' && row.expires_at && new Date(row.expires_at).getTime() > now));
      if (conHieuLuc) continue;
      await this._syncAccountStatusToDatabase(acc.idaccount, 'Active', null, { onlyAIOpsLocked: true, idaccount: acc.idaccount, username: acc.username });
      changed = true;
    }
    return changed;
  } catch (err) {
    logger.warn('[AIOps Quarantine] Lỗi đối soát khoá tự động', { error: err.message });
    return false;
  }
}
```

```sql
-- AQR:226-233: khoá vĩnh viễn không bị hạ xuống tạm thời
"status" = CASE WHEN "aiops_account_quarantine"."status" = 'PERMANENT' THEN 'PERMANENT' ELSE EXCLUDED."status" END,
"reason" = CASE WHEN "aiops_account_quarantine"."status" = 'PERMANENT' THEN "aiops_account_quarantine"."reason" ELSE EXCLUDED."reason" END,
"expires_at" = CASE WHEN "aiops_account_quarantine"."status" = 'PERMANENT' THEN NULL ELSE EXCLUDED."expires_at" END,
```

```js
// middleware/auth.js accountRejection và auth.service.js:364-370: dùng lyDoChoNguoiDung(...) cho cả message lẫn reason_inactive trả về
const lyDo = lyDoChoNguoiDung(info?.reason_inactive);
```

**Lưu ý chưa có trong bản vá, chưa chạy:** `aiops_account_quarantine` có một hàng mỗi username theo chuỗi gõ thô (`accId`, AQR:151), còn `getAccountByUsername` so `LOWER` + `LIMIT 1` không `ORDER BY` (AQR:789). Cùng tên khác hoa thường có thể ra hai hàng và đọc nhầm hàng cũ, khiến `_reconcileAutoLocks` mở khoá sớm. Nên thêm vào câu truy vấn ấy `ORDER BY ("status" <> 'UNLOCKED') DESC, "updated_at" DESC`.

Ba tệp test đang khẳng định bộ lọc cũ (`aiops.sync_account_protection.test.js:42-46`, `aiops_group2_completion.test.js` ca 1, 3, `household_and_aiops_v2.test.js` ca 5) đổi sang `startsWith` / `status: 'Active'` — bản vá đã làm.
**Kiểm lại:** `chay_kiem.js` bảy ca 58.5 và ca `PendingDelete` của 58.6.

*Ghi nhận, không phải việc của đơn này:* (a) ai biết username vẫn giữ khoá được mãi — mỗi 15 phút một loạt 15 lần sai, mỗi lần `force_logout` mọi máy (`feature.collector.js:220`). Cân nhắc gõ sai chỉ khoá IP. (b) `findFirst` theo `username` (AQ:658-661) có thể nhầm khi trùng username; Supabase đo 2026-10-31: 0 username trùng, 0 username chứa `Admin`, 0 khoá AIOps cũ không dấu.

---

## 3. PayOS (đơn 44)

Không còn việc (client soát 2026-10-30; PR #172 chỉ đổi hai dòng ép `Number`, không ảnh hưởng client). Ca test PayOS của PR: xem T6 (mục 8.6).

---

## 4. Mã hoá dữ liệu — giải mã hỏng (đơn 52)

Lịch sử: [`LICH-SU/GIAI_MA_HONG_TRA_BAN_MA.md`](./LICH-SU/GIAI_MA_HONG_TRA_BAN_MA.md). Đạt: bỏ đường đi vòng `isEncrypted ? x : encrypt(x)`; `restoreSafeNote` trả `''` cho hàng đã xoá giải hỏng. ⚠️ Hàng **còn sống** giải hỏng vẫn làm `/sync/pull` 500 cả lượt (`sync.controller.js:67-73`), nên 52.4 còn quan trọng.

**Client đo Supabase 2026-10-31** (chỉ đọc, hàm `decrypt` của backend, khoá `.env`): `transaction.Note` 25 hàng `enc:`, **0 hỏng**; `user.Phone` 3 hàng, **0 hỏng**; `user.Address`, `bill` / `goal` / `budget.Note`, `bank_account.Account_number`: 0 hàng. *"28 trường"* ở ô trả lời là 28 **ô dữ liệu**, không phải 28 cột.

### 52.1 (VỪA) — phần còn thiếu · [vá]

`mask*` nhận `context` nhưng chỗ gọi không truyền.

```js
// modules/admin/admin.service.js:173-174 và :195-196
phone: maskPhone(u.phone, { table: 'user', id: u.iduser, field: 'phone' }),
address: maskAddress(u.address, { table: 'user', id: u.iduser, field: 'address' }),
// modules/bank/bank.service.js:68
account_number: maskAccountNumber(acc.account_number, { table: 'bank_account', id: acc.id_bank_account, field: 'account_number' }),
```

Hai chỗ không có hàng để nêu, ghi rõ là ngoại lệ ở mục 10: `workers/bank.worker.js:85` (số thô từ webhook), `modules/ai/features/classify/pipeline/llm.classifier.js:54` (chữ thô).
**Ca test thêm tay:** gọi `adminService.getUsers` với một hàng `user.Phone` giải hỏng, kiểm dòng log có `table: 'user'` + `recordId`. Đừng gọi thẳng `maskPhone` như ca 7 hiện nay (ca ấy tự truyền context nên che đúng chỗ thiếu).

### 52.3 (VỪA) — chưa làm

Chưa có câu chốt khoá cho `PersonFinance`. Dữ liệu ở đó mã hoá bằng khoá dev mặc định (`crypto.util.js:43`), script di trú chưa chạy trên đó; bật backend trỏ `PersonFinance` với khoá `.env` ⇒ `/sync/pull` 500.

**Cách làm (đề xuất lối a, không đụng dữ liệu):** dán vào `docs/progress/Backend.md` và thành chú thích `.env.example`:

> CSDL dev cục bộ `PersonFinance` chạy với `DATA_ENCRYPTION_KEY` = khoá dev mặc định của `utils/crypto.util.js` (đặt qua biến môi trường của tiến trình, không sửa `.env`). Khoá trong `.env` là của Supabase. Không trộn hai khoá trên một CSDL.

Rồi chạy và dán dòng tổng kết vào mục 10:

```bash
DATABASE_URL=<PersonFinance> DIRECT_URL=<PersonFinance> DATA_ENCRYPTION_KEY=<khoá dev> npm run db:verify-encryption
```

Muốn lối b (mã hoá lại sang khoá `.env`) thì `migrate_reencrypt_legacy_dev_data.js` phải phủ thêm `bill` · `budget` · `goal` · `bank_account`, có giao tác theo bảng, `--dry-run`, sao lưu trước.

### 52.4 (VỪA) — chưa làm

`npm run db:verify-encryption` ở máy dev dùng khoá của máy dev, không chứng minh gì về Render. **Rủi ro đã tăng:** 19 + 3 hàng nay mang khoá `.env`; Render khác khoá thì mọi lượt kéo toàn bộ của tài khoản có hàng còn sống trả 500.

**Cách làm:** so vân tay, không in khoá. Thêm tạm vào `index.js` sau khi nạp `.env`, deploy, đọc log Render, rồi gỡ:

```js
logger.info('DATA_KEY_FP', { fp: require('crypto').createHash('sha256').update(process.env.DATA_ENCRYPTION_KEY || '').digest('hex').slice(0, 8) });
```

Trên máy dev (từ `src/Backend`):

```bash
node -e "require('dotenv').config();console.log(require('crypto').createHash('sha256').update(process.env.DATA_ENCRYPTION_KEY||'').digest('hex').slice(0,8))"
```

**Kiểm lại:** hai vân tay giống nhau; `GET https://managementfinance.onrender.com/api/sync/pull` không `since` của một tài khoản có hàng đã di trú trả 200; ghi cả hai vào mục 10.

### 52.5 (VỪA) — phần còn thiếu

Supabase với khoá `.env` đạt (số đo trên). Còn: `/sync/pull` toàn bộ trả 200 (theo 52.4), `PersonFinance` = 0 (theo 52.3).
**Cách sửa `scripts/migrate_reencrypt_legacy_dev_data.js`:** đếm hàng không giải được bằng cả hai khoá (`:83`; phía `user` `:98-112` đang im hẳn), cuối script in số ấy và `process.exit(soKhongXuLy > 0 ? 1 : 0)`, không in *"HOÀN TẤT"* khi còn hàng hỏng. Ghi vào mục 10: script chạy trên CSDL nào, khoá nào, lúc nào.

---

## 5. Phân quyền theo gói — hợp đồng `/payment/subscription-info` (đơn 55)

Lịch sử: [`LICH-SU/PHAN_QUYEN_THEO_GOI_HOP_DONG_VA_TAI_LIEU.md`](./LICH-SU/PHAN_QUYEN_THEO_GOI_HOP_DONG_VA_TAI_LIEU.md).

### 55.A3 (VỪA) — còn lại sau PR #172 · [vá] mã; tài liệu tay

Bốn nơi đã cùng ra Basic nhưng là bốn công thức chép tay; job hạ cấp bỏ hàng hạn NULL ⇒ giữ `Type = 'Premium'` mãi, trong khi mọi lượt đẩy vào nhà nhận `HOUSEHOLD_READ_ONLY`. Supabase đo 2026-10-31: 0 tài khoản như vậy — vá phòng xa.

```js
// utils/premium.util.js — tệp mới, định nghĩa duy nhất
function isPremiumEffective(account, now = new Date()) {
  if (!account || account.type !== 'Premium' || !account.premium_expires_at) return false;
  return new Date(account.premium_expires_at) > now;
}
module.exports = { isPremiumEffective };

// Gọi ở: SS chuConPremium; middleware/feature-permission.middleware.js:33;
// HS updateHouseholdStatusByOwner; payment.service.js:830 (const isExpired = !isPremiumEffective(account, now);
//   GIỮ const isPremium ở :827, biến ấy còn dùng ở dưới).

// payment.repository.js:510-515
type: 'Premium',
OR: [{ premium_expires_at: { lte: now } }, { premium_expires_at: null }],
```

**Tay:** dán vào `docs/Payment/CLIENT_INTEGRATION_GUIDE.md:173-186` và `docs/Functional-Mobile/12_GOI_CUOC_PREMIUM_VA_PAYOS.md:23`:

> `premium_expires_at` NULL với `Type = 'Premium'` là dữ liệu hỏng, coi là Basic: `accountType: 'Premium'`, `isPremium: false`, `isExpired: true`; job hạ cấp đưa về `Basic` ở lượt quét kế.

**Kiểm lại:** chỉ còn `utils/premium.util.js` chứa công thức hạn; ca test (CSDL riêng) tài khoản `Premium` + NULL ⇒ bốn nơi cùng kết quả và sau job `Type = 'Basic'`. App đổi theo sau khi có câu hợp đồng.

---

## 6. Script test ghi vào dữ liệu thật (đơn 48)

Lịch sử: [`LICH-SU/DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md`](./LICH-SU/DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md). Hai rủi ro script test còn lại → 58.6.

### 48.1 (THẤP) — ô trả lời chưa khớp

Ô trả lời ghi `scripts/cleanup` (không tồn tại, chưa từng có trong git), *"Lead FullStack"* (không phải tên), *"28/10/2026"*. Client đo Supabase 2026-10-31: tài khoản 18 có 0 ví sống tên chứa *test*, 13 ví đã xoá mềm, lần xoá mới nhất **2026-10-26 03:58:21Z**, không hàng nào ngày 28/10. Tài khoản 18 là tài khoản dev thật `quangdat`, không phải tài khoản test.
**Cách làm:** ghi ở mục 10: tên người / công cụ đã chạy (câu `UPDATE` tay? Admin-web? script nào?), trên Supabase, lúc 2026-10-26 03:58:21Z nếu đúng. Không nhớ thì ghi *"không truy được"* — câu ấy cũng đóng việc.

---

## 7. Migration và máy dev (đơn 49)

Không còn việc (49.F(1) đạt theo đọc mã 2026-10-31; bộ lọc `anonymized.local` của cùng tệp ở 58.6).

---

## 8. Tài liệu backend cần sửa — gom theo tệp

Các tệp dưới là tài liệu **của backend** (client không sửa). Số dòng là của tài liệu ở HEAD `5ff06db4`; đường dẫn *Mã thật* dưới `src/Client-app/lib/` trừ khi ghi khác.
**Banner không thay được dòng sai:** PR #172 không đổi dòng cũ nào của ba tệp T1–T3 (`git diff --stat`: +14 / +6 / +10, 0 dòng xoá), T1 mục 7 vẫn ghi *"ĐÃ CÓ"* dưới khối ghi chú nói ngược lại. Hàng được banner phủ đúng đã bỏ khỏi bảng dưới. Tính năng chưa có thì ghi *"kế hoạch"*, đừng đánh `[x]` / *"100%"*.
**Cách làm:** mở từng dòng trong bảng, sửa ngay tại dòng theo cột bên phải (hoặc ghi rõ *"Server lưu / chưa có hiệu lực ở app"*).
**Kiểm lại** (cả 8.1 – 8.3): đọc lại từng dòng; tìm bổ trợ phải ra 0 dòng: `thongBaoHeThong`, `demNguocXoa`, `BottomSheet`, `SnackBar` (T1); `ai-assistant`, `Modal BottomSheet`, `hiển thị dialog` (T3). Đổi từ khoá mà giữ nội dung vẫn không qua.

### 8.1 (T1) — `docs/Admin-web/Event-Notification-to-ClientApp.md`

| Dòng | Đang nói | Xin sửa theo mã |
|---|---|---|
| 24-33 | Banner: `ocr.duplicate` kích hoạt sync; 503 / 429 / 403 qua interceptor với retry backoff | **Banner sai — sửa trước.** `ocr.duplicate` không sync (`core/realtime/realtime_event.dart:121-127`). Interceptor chỉ phân loại `MAINTENANCE_MODE`, `AIOPS_QUARANTINED`, báo `FEATURE_DISABLED` (`core/api/interceptors/may_chu_interceptor.dart:56-87`) |
| 611 | `system.broadcast` = `thongBaoHeThong` | Luồng riêng `tinHeThong`, đọc qua `docTinHeThong` (`core/realtime/tin_he_thong.dart:32`), không thuộc enum |
| 614, 640 | `demNguocXoa` | App không nghe `account.countdown`, không có enum ấy; số ngày từ `countdown` của `/auth/profile` |
| 218-223 | Banner theo `level`, SnackBar 4 s | Trung tâm thông báo + khay hệ điều hành (`nhan_tin_he_thong.dart:53-72`); không banner, không SnackBar |
| 99, 291, 293 | `sync.completed` *từ thiết bị khác* | Phát cho mọi máy của tài khoản, cả máy vừa đẩy |
| 329-331, 617 | `ocr.duplicate` Dialog vàng | Toast hằng số *"Hoá đơn này đã được ghi nhận trước đó"*; không sync |
| 318, 321-327 | `metadata`; mẫu `ocr.duplicate` | `src/Backend/…/notification.service.js:98-104, 129-135` gửi `title, message, type, data, createdAt` |
| **67** | Socket không truyền số tài khoản đầy đủ | **Chọn một:** che `transfer_details.source_account` / `destination_account` trước `eventBus.publish('ocr.completed')` (`ocr.service.js:133-149`; đọc `maskAccountNumber` trước vì nó gọi `decrypt` đầu vào), hoặc sửa câu cho đúng. Nguồn: `classify.service.js:325, 328`, `notification.service.js:102`. Client không đọc payload này nên che số không phải đổi app |
| 65 | Mọi trường được ánh xạ | App đọc hộp đen trừ `account.force_logout`, `system.broadcast` |
| 102, 335-351 | `user.notification` lưu SQLite + badge | Client không nghe; server cũng không phát: `sendDirectNotification` / `notifyUser` 0 chỗ gọi ngoài test. Ghi *"chưa dùng"* hoặc xoá |
| 103, 358 | `payment.success` do webhook | Webhook chỉ `eventBus.publish` không ai subscribe (`payment.service.js:342`) + `admin_room`; tới tài khoản chỉ ở JIT (`:737`). Hoặc thêm `emitToAccount`, hoặc sửa chữ |
| 105, 385, 393 | Worker phát `order_expired`, đóng popup | Worker chỉ `admin_room { count }` (`:970`); tới tài khoản chỉ ở JIT (`:660`) |
| 378-379, 618 | Đóng popup QR | `payment.*` là tín hiệu, màn đang mở hỏi lại server; không popup |
| 410, 621 | Dialog, *"hỗ trợ xem biên lai"* | Không có trong app |
| 485, 626 | Top Toast cam + exponential backoff | Không toast; chỉ `/sync/push` hẹn lại, sàn 30 s (`core/sync/gui_lo_dong_bo.dart:214`, `core/network/trang_thai_may_chu.dart:19, 95-103`) |
| 500, 627 | 429 dừng retry, báo người dùng | App không có nhánh riêng |
| 120, 522, 628, 644 | Dialog phong toả + đếm ngược | Dòng nhắc Trang chủ + toast + câu Đăng nhập + hẹn thử |
| 121, 538, 629, 645 | BottomSheet / điều hướng `/premium?quyen=` | Chỉ làm mới gói (`may_chu_interceptor.dart:77-87`) |
| 88-109, 607-631 | 18 sự kiện, không có `household.*` | Thêm `household.changed`, `household.invited` vào bảng 3.1 và ma trận |
| 42, 113, 455 | 9 tín hiệu | Bảng 3.2 có 8 hàng, mục 5 có 5.1-5.8 |

### 8.2 (T2) — `docs/Admin-web/IP-Device-ClientApp.md`

| Dòng | Đang nói | Xin sửa theo mã |
|---|---|---|
| 17 | Banner: *"cấu hình linh hoạt theo hạ tầng rate-limiter"* | **Banner sai.** Là `skipThrottle: true` của lịch sử thiết bị ở `verifyRegisterOtp`, `register`, `login`, `refresh` (`auth.service.js:211, 289, 414, 542`) |
| 305 | Luôn bypass khi Login | Nêu đủ bốn đường trên |
| 287-291 | Test 2.x `[x]` *"CSDL PostgreSQL có…"* | Ghi rõ ca dùng Prisma giả (`device.tracking.2tier.test.js:38-80`), hoặc viết ca chạm CSDL thật có dọn dữ liệu |
| 292 | Test 2.5 xoá cứng → CASCADE, `[x]` | Ca này **không tồn tại**: 2.5 thật là thứ tự `getDeviceHistory` (`:247`). Sửa cho đúng tên ca; bỏ kịch bản xoá cứng (trái quy tắc xoá mềm) |

### 8.3 (T3) — `docs/Functional-Mobile/4_TRU_COT.md`

Gốc chung: app **không** đọc `scopes` / `scope_config` lẫn `policies` / `downgrade_policy`. Cách sửa gọn: dưới mỗi tính năng thêm một dòng *"App thi hành: …"*; dòng `scope_config` chưa dùng ghi *"Server lưu, chưa có hiệu lực ở app"*.

| Dòng | Đang nói | App thi hành |
|---|---|---|
| 74-76, 428 | `READ_ONLY` xem lại dự báo | Thẻ khoá thay cả khối; dự báo tính tại chỗ, không lưu (`features/analytics/presentation/pages/analytics_page.dart:179-185`) |
| 70 | Dialog | Chuyển `/premium?tran=…` (`chuyen_huong_theo_goi.dart:13`) |
| 599 | `/ai-assistant` | `/ai-chat`, khoá trong trang. `/export-report` đúng, thêm `/analytics/export` |
| 603 | Modal BottomSheet | Thẻ khoá → `/premium?quyen=…` |
| 225-227, 565 | OCR 15 lượt | ML Kit, không đếm lượt |
| 203-204, 563 | 1 / 5 ảnh, 90 ngày | Không đính ảnh vào giao dịch; Sổ xem mọi kỳ |
| 236-237, 566 | 20 / 100 | Không trần |
| 274-275, 569 | 5 / 25 từ khoá | Không trần |
| 580 | FHS | App không có màn |
| 529-530, 589 | Tải hoá đơn | Không có; chỉ *Lưu mã QR* |
| 545-547, 590 | Sao lưu ảnh, về 10 s | 2 s mọi gói, không sao lưu ảnh |
| 110-112, 556 | `cache_token_days` | Không có; mở lạnh dùng phiên đã lưu rồi `verifySession()` |
| 491, 586 | MB / MOMO / ZALOPAY, *"4 banks"* | Seed `database/32:196, 260` vẫn VCB / MB / TCB / ACB. **Chọn một:** viết migration sửa seed, hoặc ghi đúng seed + *"Server lưu, không dùng"*. App: MB Bank · MoMo · ZaloPay, không theo gói |
| 518-519 | `countdown_minutes: 15` | **Chọn một:** migration đổi seed về 10 (`database/32:208, 262, 309`), hoặc ghi *"Server lưu, không dùng"* |
| 11 | *"lộ trình tương lai"* | Bỏ, trừ khi có quyết định PO |

### 8.4 (T4) — Tên migration cũ

Không còn việc (client soát 2026-10-30).

### 8.5 (T5) — Quy ước tài liệu client

Không còn việc (client soát 2026-10-30). `docs/superpowers/sync/SYNC_DOCUMENTATION.md` là tài liệu **của client** — muốn sửa thì ghi ở mục 14 *Trao đổi* của tệp ấy hoặc đặt đơn, không viết đè.

### 8.6 (T6, THẤP) — Câu sai PR #172 vừa viết thêm

| Tệp, dòng | Cách sửa |
|---|---|
| `docs/progress/Backend.md:694-695` | *"3 quyền `household.create`, `household.dissolve`, `household.member_limit`"*, gói *`Free`, `Plus`* không tồn tại. Thay bằng 4 quyền thật (`household`, `household_join`, `household_members`, `household_wallets`) và gói Basic / Premium |
| `Project.md:4828, 4819` | Đường đúng là `/api/payment/order-status/:orderCode`; 6.1 tới tài khoản chỉ `account.upgraded`, webhook không phát `payment.success` tới tài khoản |
| `tests/unit/payos_group3_comprehensive_audit.test.js` ca 2 | Mô tả P2002 nhưng webhook chỉ gọi một lần nên nhánh `payment.repository.js:373-378` không chạy. Gọi webhook hai lần cùng `reference` với `recordTransaction` thật trên CSDL thử, hoặc tách ca đơn vị; đếm một hàng. Bỏ nhãn `[Tier 2]` ở ca mock. **Thêm:** `activatePremiumSubscription:429-433` — bắt lỗi trong transaction không cứu được giao tác đã huỷ; dùng `createMany({ skipDuplicates: true })` hoặc bỏ `catch` |

---

## 10. Trả lời (backend ghi vào đây)

Mỗi dòng một câu nói đúng việc của mã ấy — commit, tệp, ca test (đường thật, payload như app gửi). Báo cáo PR #172: `git show 5ff06db4:docs/superpowers/backend/CAN-LAM/VIEC_BACKEND_CON_LAI.md` mục 10.

**Dòng `TỔNG:` của `chay_kiem.js` sau khi sửa:** …

| Mã | Đã làm (commit, tệp) | Ca test / câu kiểm | Ghi chú |
|---|---|---|---|
| 57.6 | | | |
| 57.2 | | | |
| 59.1 | | | |
| 58.5 | | | |
| 58.3 | | | |
| 58.4 | | | |
| 59.3 | | | |
| 57.7 | | | *(kèm bảng mã chốt)* |
| 57.1 | | | |
| 57.3 | | | |
| 55.A3 | | | |
| 52.1 | | | |
| 52.3 | | | |
| 52.4 | | | |
| 52.5 | | | |
| T1 | | | |
| T2 | | | |
| T3 | | | |
| 57.8 | | | *(#5, #7, #8 trả lời ở đây)* |
| 58.6 | | | |
| 59.2 | | | |
| 48.1 | | | |
| T6 | | | |
