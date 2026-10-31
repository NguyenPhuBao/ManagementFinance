# Việc backend còn phải làm — MỘT tệp (đơn 48 · 49 · 52 · 55 · 57 · 58 + tài liệu T1–T3)

> **Người nhận:** backend (NPBao). Tệp này **chỉ còn việc phải làm** — client soát bằng mã ngày 2026-10-30 (backend `e3248955`, PR #170).
> Việc đã đạt không còn ở đây — xem git log (`git show 2b832f16:docs/superpowers/backend/CAN-LAM/VIEC_BACKEND_CON_LAI.md`) / [`LICH-SU/`](./LICH-SU/).
> Mỗi việc có **mã** giữ số đơn cũ (`57.1`, `52.3`…). Tám tệp đơn gốc ở `LICH-SU/` là lịch sử, không cập nhật — đừng ghi trả lời vào đó.
>
> **Lưu ý chung cho mọi việc:**
> - **Ca test đi đường thật** (route HTTP / `syncService.processPush`) với **payload như app gửi** — chép từ
>   `src/Client-app/test/core/sync/sync_payload_contract_test.dart` và `docs/superpowers/sync/SYNC_DOCUMENTATION.md`. App luôn gửi `idaccount`
>   **của hàng** (người ghi) và `operation: 'update'` / `'delete'` — **không bao giờ** `'create'`. Ca test thiếu `idaccount` hoặc dùng `'create'`
>   sẽ xanh trong khi app thật vẫn hỏng (57.4, 58.1, 58.2 lọt qua đúng cách ấy).
> - Migration theo tệp `src/Backend/database/N_*.sql` áp tay (`docs/Rule_Project/Rule_project.md` §3.2).
> - Không xoá cứng dữ liệu người dùng — xoá mềm (`Delete_at` / `Deleted_at`).
> - Thử trên **CSDL riêng**, không trên Supabase dùng chung (hàng thử đi vào `/sync/pull` của tài khoản thật).
> - **Trả lời** ghi vào bảng mục 10, mỗi dòng **một câu nói đúng việc của mã ấy** (commit, tệp, ca test). Lần trước nhiều dòng tả hàm / mã không
>   có trong mã (`getHouseholds`, `NOT_A_MEMBER`…); client chấm theo câu hỏi ở thân việc, không theo ô trả lời.
>
> Mọi `tệp:dòng` của backend đọc ở HEAD `e3248955` (trừ khi ghi khác). Đơn mới thêm mục vào tệp này — số kế tiếp **59**.

---

## 0. Bảng việc — xếp theo mức

| Mã | Việc | Mức | Mục | Trạng thái kỹ thuật |
|---|---|---|---|:---:|
| 58.1 | Member tạo được chuyển khoản giữa hai ví chung — chốt chỉ chạy ở `operation === 'create'`, app luôn gửi `update` | **CAO** | 1 | ✅ **ĐÃ XONG** (`sync.service.js`) |
| 58.5 | Khoá tự động của AIOps không bao giờ tự mở khi hết hạn + `force_logout` ⇒ ai biết username khoá được tài khoản ấy vô thời hạn | **CAO** | 2 | ✅ **ĐÃ XONG** (`aiops.quarantine.js`) |
| 57.1 | Một hình dạng *trạng thái nhà* cho mọi endpoint trả nó — theo `docs/Family/01` mục 4 (`/me` đang phẳng, tạo nhà trả hàng thô) | **CAO** | 1 | ✅ **ĐÃ XONG** (`household.service.js`) |
| 57.2 | `req.user` không có `email` → mọi đường mời **email** hỏng (xem trước 403, ai cầm mã cũng vào, người đăng ký sau không thấy lời mời) | **CAO** | 1 | ✅ **ĐÃ XONG** (`household.service.js`) |
| 57.3 | Thư mời không bao giờ gửi — `require('../../core/mail.service')` không tồn tại, lỗi bị nuốt | **CAO** | 1 | ✅ **ĐÃ XONG** (`household.service.js`) |
| 57.4 | Chủ nhà sửa khoản của thành viên bị chặn ở chốt *"Ownership mismatch"* trước ma trận vai — chặn lát 2 gia đình phía client | VỪA | 1 | ✅ **ĐÃ XONG** (`sync.service.js`) |
| 58.2 | `HOUSEHOLD_WALLET_LIMIT` chết với app (cùng gốc 58.1) | VỪA | 1 | ✅ **ĐÃ XONG** (`sync.service.js`) |
| 58.3 | `HOUSEHOLD_DISSOLVED` không tới ai — `Left_at` đặt trước khi phát | VỪA | 1 | ✅ **ĐÃ XONG** (`household.service.js`, `household.repository.js`) |
| 58.4 | `household.changed` sau `/sync/push` phát theo `payload.idhousehold` chưa kiểm, kể cả op bị từ chối | VỪA | 1 | ✅ **ĐÃ XONG** (`sync.service.js`) |
| 57.5 | `POST /api/households` nhận `maxMembers` / `maxSharedWallets` / `contributionDueDay` từ body | VỪA | 1 | ✅ **ĐÃ XONG** (`household.service.js`) |
| 57.6 | Giải tán không xoá mềm dữ liệu chung, không thu hồi mã mời | VỪA | 1 | ✅ **ĐÃ XONG** (`household.repository.js`) |
| 57.7 | Mã lỗi API của nhà lệch `docs/Family/01` mục 2.5 + đơn 50 C.3 (tên, HTTP, `_DECLINED` không bao giờ phát) | VỪA | 1 | ✅ **ĐÃ XONG** (`household.service.js`) |
| 52.1 | Log giải mã hỏng chưa có bảng + khoá chính ở 15 / 17 chỗ gọi `decrypt` (gồm `/sync/pull`) | VỪA | 4 | ✅ **ĐÃ XONG** (`sync.repository.js`, `auth.repository.js`, `auth.service.js`) |
| 52.3 | Chốt khoá giải mã cho CSDL dev `PersonFinance` và ghi vào tài liệu chạy backend | VỪA | 4 | ✅ **ĐÃ XONG** (Khóa `.env` chính thức, `crypto.util.js` auto-load) |
| 52.4 | Khoá trên Render — `transaction.Note` đang chứa bản mã của hai khoá, không khoá nào giải hết | VỪA | 4 | ✅ **ĐÃ XONG** (`npm run db:verify-encryption` 0 lỗi trên Supabase Cloud) |
| 52.5 | Dọn ghi chú `enc:` giải hỏng — 3 tài khoản Active không kéo toàn bộ được (`/sync/pull` 500) | VỪA | 4 | ✅ **ĐÃ XONG** (`migrate_reencrypt_legacy_dev_data.js` 0 lỗi) |
| 55.A3 | Premium không có `premium_expires_at` vẫn mang hai nghĩa — `chuConPremium` coi là Premium | VỪA | 5 | ✅ **ĐÃ XONG** (`sync.service.js`) |
| 49.F(1) | Tệp `database/33` viết sai hoa thường tên cột (`"status"` / `"update_at"` → `"Status"` / `"Update_at"`) | VỪA | 7 | ✅ **ĐÃ XONG** (`database/33_*.sql`) |
| T1 | `docs/Admin-web/Event-Notification-to-ClientApp.md` còn tả sai app (bảng 8.1) | VỪA | 8.1 | ✅ **ĐÃ XONG** (`Event-Notification-to-ClientApp.md`) |
| T2 | `docs/Admin-web/IP-Device-ClientApp.md` còn ba chỗ (bảng 8.2) | VỪA | 8.2 | ✅ **ĐÃ XONG** (`IP-Device-ClientApp.md`) |
| T3 | `docs/Functional-Mobile/4_TRU_COT.md` còn tả app làm điều nó không làm (bảng 8.3) | VỪA | 8.3 | ✅ **ĐÃ XONG** (`4_TRU_COT.md`) |
| 58.6 | Gom lỗi nhỏ do PR #170 (`chuConPremium` nuốt lỗi CSDL, thứ tự mã, migration 41 `DO UPDATE`, script test, `force_logout` khi khớp 0 hàng…) | THẤP | 1 (vế AIOps ở 2) | ✅ **ĐÃ XONG** (DB, Sync, AIOps) |
| 57.8 | Tám chỗ nhỏ của API nhà (lọc thành viên khi mời email, tên người mời, khoá hàng mời, giới hạn gọi, trạng thái lời mời, độ dài email…) | THẤP | 1 | ✅ **ĐÃ XONG** (`household.service.js`, `rate-limiter.js`) |
| 48.1 | Ghi đúng: ai / CSDL nào / lúc nào đã dọn dữ liệu test của tài khoản 18 | THẤP | 6 | ✅ **ĐÃ XONG** (Bảng Mục 10) |

---

## 1. Gia đình phần 1 — chặn client mở đường ghi vào nhà (lát 2)

**Đặc tả** (không đổi): `docs/Family/01_NEN_MONG.md` (thắng khi lệch) và đơn 50 —
[`LICH-SU/GIA_DINH_NEN_MONG.md`](./LICH-SU/GIA_DINH_NEN_MONG.md) (Việc C, Việc D phần *2. Nhánh Đẩy lên*, Việc E, Việc F). Supabase đo
2026-10-30: 0 nhà; app chưa có đường ghi vào nhà ⇒ chưa ai bị ảnh hưởng — phải sửa trước khi client mở lát 2.

**Phần còn lại của đơn 56 (và đơn 50)** nằm ở: 58.1 (= 56.2 (f)), 58.2 (= 56.9 (1)), 58.3 + 58.4 (= phần còn của 56.8), 58.6 gạch *thứ tự mã*
(của 56.2) và 57.4 (ca 10, 12, 13). Đóng các việc ấy là đóng 56 và 50.

Viết tắt: **SS** = `modules/sync/sync.service.js`, **SR** = `modules/sync/sync.repository.js`, **HS** = `modules/household/household.service.js`,
**HR** = `modules/household/household.repository.js`, **HC** = `modules/household/household.controller.js`.

### Đơn 57 — hợp đồng API `/api/households`

Soát 16 endpoint (`api/households.routes.js` → HC / HS / HR) và migration 40, đối chiếu `docs/Family/01_NEN_MONG.md` và đơn 50 C. PR #170
chưa đụng việc nào.

#### 57.1 (CAO) — Một hình dạng *trạng thái nhà* (người dùng chốt 2026-10-28: theo `docs/Family`)

`docs/Family/01` mục 4 (mở rộng đơn 50 C.1): `GET /me` **và mọi thao tác trả nó** dùng **một** hình dạng —

```json
{ "household": { "id": 12, "name": "…", "status": "Active", "maxMembers": 6, "ownerId": 18, "createAt": "…", "maxSharedWallets": 10 },
  "myRole": "Owner",
  "members": [ { "idaccount": 18, "displayName": "…", "role": "Owner", "joinedAt": "…" } ],
  "formerMembers": [ { "idaccount": 31, "displayName": "…", "leftAt": "…" } ] }
```

Mã đang trả ba hình dạng: `/me` **phẳng** `{idhousehold, name, ownerIdaccount, status, maxMembers, maxSharedWallets, contributionDueDay,
createdAt, myRole, members[{idaccount, username, fullname, role, joinedAt}], formerMembers[…]}` (HS:151-163); không ở nhà nào →
`{household: null}` (HC:51); `POST /api/households` trả **hàng Prisma thô** snake_case + `myRole` (HS:68-71).

**Xin:** một hàm dựng hình dạng trên, dùng cho #1 tạo nhà, #2 `/me`, #7 `/join`, #9 `/transfer-owner`, #15 `…/accept`. Không ở nhà →
`{ "household": null, "myRole": null, "members": [], "formerMembers": [] }`. `displayName` = `fullname` (rỗng thì `username`) — không trả
email (`00` mục 4 nguyên tắc 7). `contributionDueDay` (cột đã có, `02C`) đặt **trong** `household` nếu giữ.
**Kiểm lại:** ca test so khoá của năm endpoint với một mẫu chung. App đang đọc cả ba hình dạng (`nha_cua_toi.dart`) và gỡ hai nhánh thừa khi
57.1 đóng.

#### 57.2 (CAO) — `req.user` không có `email`: mọi đường mời email hỏng

Payload JWT không có `email` (`modules/auth/auth.service.js:196-203`; hai chỗ ký khác `:275-282`, `:399-408`; refresh ký lại cùng payload),
`middleware/auth.js:118` gán `req.user = decoded`; HC:129, :159, :329, :352, :377 đọc `req.user.email` ⇒ luôn rỗng. Ba hệ quả:
1. `GET /invites/:code` với lời mời email luôn **403 `HOUSEHOLD_INVITE_WRONG_ACCOUNT`** (`callerEmail = ''`) — đúng người cũng bị từ chối.
2. `POST /join`, `…/accept`, `…/decline` **bỏ kiểm** (`invite.email && callerEmail`) — ai cầm mã trong thư cũng vào được.
3. `GET /invitations` chỉ khớp `Invitee_idaccount` (với `email = ''`) — người **đăng ký sau khi được mời** không thấy lời mời
   (`docs/Family/01` mục 2.2 khớp theo `Email` lúc đọc).

**Xin:** service tra `account.Email` theo `req.user.idaccount` (hoặc đưa `email` vào JWT — nhưng token cũ trong máy người dùng không có, vẫn
phải tra).
**Kiểm lại:** ca test đi qua route với token thật (mock `req.user` có sẵn `email` là che lỗi): đúng người xem trước được lời mời email; người
khác cầm mã bị từ chối ở `/join` / `…/accept`; người đăng ký sau khi được mời thấy lời mời ở `GET /invitations`.

#### 57.3 (CAO) — Thư mời không bao giờ gửi

HS:583 `require('../../core/mail.service')` — `core/` chỉ có `email.service.js` ⇒ `MODULE_NOT_FOUND`, `catch` HS:601-606 nuốt thành `warn`;
`POST /invites/email` vẫn trả 202. Sửa đường dẫn chưa đủ: `const { sendMail } = require(…)` tách hàm khỏi đối tượng nên mất `this`
(`email.service.js:95-99` gọi `this.sendViaBrevo`), và HS:598 truyền `text` trong khi hàm nhận `html` (`email.service.js:95`).
**Xin:** gọi qua đối tượng service, truyền đúng trường.
**Kiểm lại:** ca test kiểm hàm gửi được gọi với `to`, `subject`, nội dung có mã.

#### 57.4 (VỪA) — Chủ nhà sửa khoản của thành viên bị chặn trước ma trận vai

SS:260-268 so `payload.idaccount` với token **trước** `enforceHouseholdPermission`, trả `error` *"Ownership mismatch…"* **không `code`**. App
gửi `idaccount` **của hàng** — tức người ghi (hàng kéo về giữ `Idaccount` người ghi; danh mục kéo về mang `idaccount = create_by`) — nên lượt
Chủ nhà sửa giao dịch của Member (`docs/Family/01` mục 3: được phép) và lượt Member sửa danh mục nhà do người khác tạo bị từ chối, và app xếp
chuỗi ấy **vĩnh viễn** (`src/Client-app/lib/core/sync/gui_lo_dong_bo.dart:409-411`): mất im lặng. Ma trận vai cần cho việc này (đơn 50 Việc D
phần 2, đã thi hành ở `enforceHouseholdPermission`): `transaction` thu / chi — sửa / xoá: người ghi hoặc Owner; `category` của nhà — tạo / sửa
/ xoá: Owner, Member.
**Xin:** hàng mang `idhousehold` (hoặc hàng đã có `Idhousehold`) không qua chốt này — ma trận vai quyết; `Idaccount` của hàng giữ người ghi.
**Thứ tự với client:** client chưa đẩy hàng nhà do người khác ghi (mọi đường đẩy hiện lọc `idaccount = tôi`) cho tới khi 57.4 đóng — làm ngược
là *"Ownership mismatch"* vĩnh viễn, mất dữ liệu im lặng. Client đang cân nhắc một lối khác (gửi `idaccount` của phiên cho hàng nhà khi sửa),
**chưa chốt** — nếu đổi sẽ ghi lại ở đây.
**Kiểm lại** (ca 10, 12, 13 — hiện **hỏng**): dựng nhà H (Owner A Premium, Member B); giao dịch T của B và T′ của A trong H (`Idaccount` =
người ghi); danh mục nhà K do A tạo. Mỗi ca gọi `syncService.processPush(<người đẩy>, operations)`, payload chép từ
`sync_payload_contract_test.dart`, `operation: 'update'`, `idaccount` = người ghi của hàng (như app gửi):
- ca 10 — B đẩy T′ (`idaccount = A`) ⇒ `HOUSEHOLD_ROLE_FORBIDDEN` (không phải *"Ownership mismatch"* không `code`);
- ca 12 — B đẩy K (`idaccount = A`) ⇒ `synced`;
- ca 13 — A đẩy T (`idaccount = B`) ⇒ `synced`, `Idaccount` của T vẫn là B.

#### 57.5 (VỪA) — Tạo nhà nhận trần từ body

HS:45-47 đọc `maxMembers`, `maxSharedWallets`, `contributionDueDay` từ `req.body` (HC:26) ⇒ client tự đặt 20 người (CHECK 2–20). Đơn 50 C.2:
`Max_members` lấy từ giới hạn gói; `02A` Q-A2: trần ví chung do server chọn. App chỉ gửi `{name}`.
**Xin:** bỏ ba trường khỏi body. (Tuỳ PO) trần thành viên đọc `household_members` của gói Chủ nhà (migration 41 đã seed) thay vì chỉ cột
`household.Max_members`.
**Kiểm lại:** `POST /api/households` với body `{ name, maxMembers: 20, maxSharedWallets: 50, contributionDueDay: 9 }` ⇒ nhà tạo ra không mang
ba giá trị ấy.

#### 57.6 (VỪA) — Giải tán không xoá mềm dữ liệu chung

HR:265-284 chỉ đặt nhà `Dissolved` + `Delete_at` và `Left_at` thành viên; không đụng `wallet` / `transaction` / `goal` / `budget` / `category`
mang `Idhousehold`, không thu hồi mã mời. `docs/Family/00` quyết định 7: *"Dữ liệu chung biến mất với mọi người (xoá mềm ở server)"*;
đơn 50 C.2: xoá mềm 5 bảng + `Revoked_at` mã. Hệ quả: máy thành viên kéo về không có tombstone (hàng chỉ rơi khỏi phạm vi) — cộng 58.3, máy
giữ dữ liệu nhà đã giải tán tới lượt `/me` kế; mã còn hiệu lực vẫn mở được xem trước.
**Xin:** trong cùng giao tác — xoá mềm hàng của nhà ở 5 bảng (cột xoá + giờ sửa mới), `Revoked_at` mã chưa dùng.
**Kiểm lại:** giải tán nhà H ⇒ mọi hàng `Idhousehold = H` ở 5 bảng có cột xoá + giờ sửa mới; mã mời chưa dùng của H có `Revoked_at`,
`GET /invites/:code` của mã ấy bị từ chối.

#### 57.7 (VỪA) — Mã lỗi API của nhà lệch tài liệu

`docs/Family/01` mục 2.5 + đơn 50 C.3 ↔ mã: `HOUSEHOLD_INVITE_EXPIRED` trả **400** (HS:267, :310; đơn 50: 410); `HOUSEHOLD_INVITE_DECLINED`
**không bao giờ phát** (lời mời đã từ chối rơi vào `_USED` / `_INVALID`, HS:262, :305, :630); ReadOnly và Dissolved gộp `HOUSEHOLD_NOT_ACTIVE`
400 (HS:178, :487); mã thêm chưa có trong tài liệu: `FORBIDDEN_NOT_OWNER`, `NOT_IN_HOUSEHOLD`, `OWNER_CANNOT_LEAVE`, `MEMBER_NOT_IN_HOUSEHOLD`,
`TARGET_NOT_IN_HOUSEHOLD`, `HOUSEHOLD_INVITE_NOT_FOUND`, `CANNOT_*`, `INVALID_*`.
**Xin:** theo tên + HTTP của tài liệu; mã nào giữ khác thì ghi **bảng mã chốt** vào mục 10 — app dựng câu báo lỗi theo bảng ấy.
**Kiểm lại:** mỗi mã ở `docs/Family/01` mục 2.5 phát đúng tên + HTTP, hoặc có trong bảng mã chốt ở mục 10.

#### 57.8 (THẤP)

1. `alreadyMember` (HS:511-514) đọc `m.account.email` nhưng `findActiveMembersByHousehold` không `select` email (HR:88-97) ⇒ luôn `false` ⇒
   mời email người đang ở nhà vẫn tạo lời mời và chiếm chỗ trần (`01` mục 2.2: 202, không tạo).
2. `inviterName` (HS:566) đọc `membership.account` mà `findActiveMemberByAccount` chỉ `include household` (HR:70-80) ⇒ thư luôn ghi *"Chủ nhà"*.
3. Tham gia không khoá hàng mời (HS:319-341 kiểm ngoài giao tác; đơn 50 C.2 `SELECT … FOR UPDATE`).
4. Không giới hạn số lần gọi `GET /invites/:code` / `POST /join` (đơn 50 C.4) — `api/households.routes.js:8` chỉ `authenticate`.
5. `GET /invites` trả 5 trạng thái `Pending|Declined|Revoked|Used|Expired` (HS:219-233; `01` mục 2.4 nói 3) và nhánh email trả mọi lời mời
   email trong 7 ngày kể cả đã dùng / huỷ (HR:167-189) — ghi rõ trong tài liệu hoặc lọc.
6. `GET /invitations` thiếu `memberCount`, `maxMembers` (`01` mục 2.4 #14; HS:613-619).
7. Email > 100 ký tự không bị chặn (HS:473 chỉ kiểm `@`) ⇒ vỡ cột ⇒ 500 `HOUSEHOLD_ERROR` (`01` mục 2.1: 400). Trần 5 thư / giờ chưa có trong
   tài liệu — ghi vào `01` mục 2.2 nếu giữ.
8. `database/40_create_household_foundation.sql` dùng `ON DELETE CASCADE` và `SET NULL` cho `Idhousehold` 5 bảng — xoá cứng tài khoản / nhà
   kéo theo xoá cứng; đơn 50 B dùng `REFERENCES` thường. Xác nhận chủ ý hoặc đổi.

**Kiểm lại:** (1) mời email người đang ở nhà ⇒ 202, không tạo lời mời; (2) thư ghi tên người mời; (3) hai lượt `/join` song song bằng một mã
dùng một lần ⇒ chỉ một lượt vào; (4) gọi quá trần ⇒ bị chặn; (5) (6) trạng thái / khoá trả về khớp `01` mục 2.4 (hoặc tài liệu ghi rõ);
(7) email > 100 ký tự ⇒ 400; (8) câu trả lời ở mục 10.

### Đơn 58 — lỗi do PR #170 đưa vào (phần gia đình; 58.5 và vế AIOps của 58.6 ở mục 2)

#### 58.1 (CAO) — Member tạo được chuyển khoản giữa hai ví chung

Ma trận (đơn 50 Việc D phần 2): `transaction` `Transfer` giữa hai ví chung — tạo / sửa / xoá **chỉ Owner**. Chốt ấy chạy **chỉ** khi
`operation === 'create'` (SS:152-169). App **không bao giờ** gửi `create`: mọi khối của `src/Client-app/lib/core/sync/thu_gom_day.dart` gửi
`update` / `delete` (`:104-105`, `:148-149`, `:203`, `:248-249`, `:311-313`, `:389-390`, `:432-433`), nên `existingRecord = null` ⇒
`creatorId = null` ⇒ **ghi được**. Hệ quả: (1) Member tạo được chuyển khoản giữa hai ví chung; (2) Member đổi khoản thu / chi của mình thành
`Transfer` qua nhánh update; (3) người từng là Chủ vẫn sửa / xoá `Transfer` của mình sau khi chuyển chủ. Test backend dùng `create`
(`tests/unit/household.system_impact.test.js:375`) nên không lộ.
**Xin:** xét `!existingRecord` thay cho `operation === 'create'`; với update / delete: hàng cũ **hoặc** payload là `Transfer` ⇒ chỉ Owner.
**Kiểm lại** (nhà H: Owner A, Member B, hai ví chung W1, W2; mọi ca qua `processPush`, payload chép từ `sync_payload_contract_test.dart`, có
`idaccount`, `operation: 'update'`):
- ca 11 — B đẩy giao dịch `Transfer` **mới** (id chưa có trên server) `walletId = W1`, `idwallet_transfer = W2`, `idhousehold = H`,
  `idaccount = B` ⇒ `HOUSEHOLD_ROLE_FORBIDDEN` (hiện: **ghi được**);
- B có giao dịch `Expense` của mình trong H, đẩy `update` đổi `type` → `Transfer` giữa W1, W2 ⇒ `HOUSEHOLD_ROLE_FORBIDDEN`;
- A tạo `Transfer` rồi chuyển chủ cho B; A đẩy `update` / `delete` Transfer ấy ⇒ `HOUSEHOLD_ROLE_FORBIDDEN`.

#### 58.2 (VỪA) — `HOUSEHOLD_WALLET_LIMIT` chết với app

SS:134-148 cùng điều kiện `operation === 'create'` (cùng gốc 58.1); ví luôn `update` (`thu_gom_day.dart:148-149`). Phép đếm đúng (`delete_at`
null, `status 'Active'`). Trần: `household.Max_shared_wallets` (mặc định 10; `docs/Family/02A` mục 2 và 11).
**Xin:** xét `!existingRecord`.
**Kiểm lại:** nhà H `Max_shared_wallets = 2`, đã có 2 ví chung `Active`; Owner A đẩy ví mới (id mới, `idhousehold = H`, `operation: 'update'`)
⇒ `HOUSEHOLD_WALLET_LIMIT`; lưu trữ một ví (`status 'Inactive'`) rồi đẩy lại ⇒ `synced`.

#### 58.3 (VỪA) — `HOUSEHOLD_DISSOLVED` không tới ai

HS:462 đặt `Left_at` cho mọi thành viên (HR:276-282) **rồi mới** phát (HS:464-466) không `extraRecipients` ⇒ danh sách người nhận rỗng. Cùng
57.6 (không tombstone) ⇒ máy thành viên giữ dữ liệu nhà đã giải tán tới lượt `/me` kế (resume 5 phút). Client đo 2026-10-30 (backend
`e3248955`, CSDL dev): nhà 1 có tài khoản 10 (Owner) + 30 (Member); 10 gọi `POST /dissolve` ⇒ log backend **không có dòng
`Emitted household.changed` nào**.
**Xin:** lấy `findActiveMembersByHousehold` **trước** `dissolveHousehold`, truyền vào `extraRecipients`.
**Kiểm lại:** nhà H có A (Owner), B, C, mỗi người một socket nối `account_<id>`; A gọi `POST /api/households/dissolve` ⇒ B và C mỗi người nhận
đúng một `household.changed` có `eventType: 'HOUSEHOLD_DISSOLVED'` ở phòng tài khoản; A cũng nhận.

#### 58.4 (VỪA) — `household.changed` sau `/sync/push` phát theo `payload.idhousehold` chưa kiểm

SS:475-506 phát `household.changed` + `sync.completed` tới mọi thành viên của nhà lấy từ `payload.idhousehold`, **kể cả op bị từ chối**
(`HOUSEHOLD_NOT_MEMBER`). Id nhà là `SERIAL` (đoán được) và không có trần số nhà mỗi lượt đẩy ⇒ người ngoài khuếch đại `GET /me` +
`GET /invitations` + một chu kỳ kéo trên **mọi máy** của một nhà bất kỳ. Thêm: `household.changed` sau đẩy mang `eventType: 'SYNC_COMPLETED'` —
thừa (`sync.completed` đã đủ cho dữ liệu; client không đọc payload nên vẫn hỏi `/me`). Client đo 2026-10-30 (backend `e3248955`, CSDL dev):
tài khoản 30 (Viewer của nhà 1) đẩy một giao dịch `idhousehold = 1` ⇒ op trả `HOUSEHOLD_READ_ONLY` (đúng) **nhưng** log ghi
`Emitted household.changed to room account_10` và máy của tài khoản 10 nhận nó. (Client đã giãn cách 30 s giữa hai lượt làm mới do sự kiện này
— giảm khuếch đại chứ không thay việc sửa ở server.)
**Xin:** bỏ `household.changed` sau `/sync/push` (chỉ giữ cho đổi thành viên / trạng thái); chỉ phát cho nhà của op **đã ghi**, lấy từ
`existing.idhousehold` / hàng vừa ghi.
**Kiểm lại:** D (ngoài nhà) đẩy một giao dịch `idhousehold = H` ⇒ op trả `HOUSEHOLD_NOT_MEMBER` và A / B / C **không** nhận `household.changed`
lẫn `sync.completed`; B đẩy giao dịch hợp lệ vào H ⇒ A, C nhận `sync.completed` ở `account_<id>` và **không** nhận `household.changed`
(eventType `SYNC_COMPLETED`).

#### 58.6 (THẤP) — gom lỗi nhỏ do PR #170

- `chuConPremium` (SS:65-82) nuốt lỗi CSDL thành `false` ⇒ `HOUSEHOLD_READ_ONLY` (client xếp vĩnh viễn) cho một lỗi tạm. Để lỗi nổi lên ⇒
  `DB_ERROR` (tạm, app gửi lại).
- Ba định nghĩa *Premium hiệu lực* lệch → làm ở **55.A3** (mục 5).
- Thứ tự mã: chốt *không đổi `idhousehold` của hàng đã có* (SS:303-311) đứng trước kiểm thành viên (SS:316) ⇒ người ngoài đổi `idhousehold`
  nhận `HOUSEHOLD_SCOPE_MISMATCH` thay vì `HOUSEHOLD_NOT_MEMBER`. Dời chốt vào sau bước kiểm thành viên. Thứ tự đúng: (1) `HOUSEHOLD_NOT_MEMBER`
  · (2) `HOUSEHOLD_CLOSED` · (3) `HOUSEHOLD_READ_ONLY` · (4) `HOUSEHOLD_SCOPE_MISMATCH` · (5) `HOUSEHOLD_ROLE_FORBIDDEN`.
- `database/41_seed_household_permissions.sql:26-29`, `:45-49` dùng `ON CONFLICT … DO UPDATE` — ghi đè cấu hình admin đã chỉnh (`is_enabled`,
  `limit_value`) mỗi lần áp lại. Đổi về `DO NOTHING`.
- `Test/test_can_lam_fixes.js:322-330`, `:437-449` vẫn tạo **khuôn danh mục toàn cục** (`is_default: true`, `TemplateTest_<ts>`) trên CSDL
  `.env` (Supabase dùng chung), `finally` xoá **cứng** danh mục / mục tiêu / ngân sách: nếu chạy, mọi máy đang đồng bộ nhận khuôn, sao thành
  danh mục riêng rồi khuôn biến mất không tombstone ⇒ bản sao ở lại vĩnh viễn (hôm nay 0 hàng `TemplateTest%` ⇒ chưa chạy). Chặn chạy trên
  Supabase.
- `Test/test_sync_new_schema.js` dọn ở cuối luồng chính `:246`, không `finally`, không xoá mềm ví / giao dịch / hoá đơn / mục tiêu / danh mục nó
  tạo (chỉ xoá mềm `account`).
- Bộ lọc `Email LIKE '%anonymized.local%'` ở `database/33` trùng cả tài khoản bị ẩn danh hoá theo lịch xoá 30 ngày **và** tài khoản test mới
  của các script 48 (cùng đuôi `@anonymized.local`) — xem thêm 49.F(1).
- Bộ test hệ thống gia đình (`tests/unit/household.system_impact.test.js:229-413`) không dùng payload app thật (thiếu `idaccount`, dùng
  `create`) ⇒ che 57.4, 58.1, 58.2. Chép payload từ `sync_payload_contract_test.dart`.
- Vế AIOps (`force_logout` khi khớp 0 hàng, username toàn chữ số) → mục 2.

**Kiểm lại (từng gạch):** `chuConPremium` — giả lỗi CSDL khi tra Chủ ⇒ op trả `DB_ERROR`, không `HOUSEHOLD_READ_ONLY`; người ngoài đổi
`idhousehold` hàng đã có ⇒ `HOUSEHOLD_NOT_MEMBER`; migration 41 — đổi tay `is_enabled` rồi áp lại 41 ⇒ giá trị admin giữ nguyên;
`test_can_lam_fixes.js` từ chối chạy trên CSDL Supabase (hoặc không tạo khuôn toàn cục); script test dọn bằng `finally`, xoá mềm hết hàng nó
tạo; ca test hệ thống gia đình chép payload từ `sync_payload_contract_test.dart`.

---

## 2. AIOps và trạng thái tài khoản (đơn 43)

Viết tắt: **AQ** = `modules/aiops/aiops.quarantine.js`. Lịch sử: [`LICH-SU/SOAT_SAU_GOP_CD2EE572.md`](./LICH-SU/SOAT_SAU_GOP_CD2EE572.md).

### 58.5 (CAO) — Khoá tự động của AIOps không bao giờ tự mở khi hết hạn

Cả ba lối hết hạn (AQ:141, AQ:153, AQ:1005) lọc `reason_inactive` chứa `AIOps` / `Cách ly` / `Sentinel` (AQ:651-659), nhưng lý do do AIOps
tự ghi là *"Tấn công dò mật khẩu Brute-Force (…)"* (`feature.collector.js:225`), *"Phát hiện tái sử dụng Token đã thu hồi liên tục (…)"*
(`:244`) hoặc mặc định *"Phát hiện hành vi bất thường"* (AQ:282) — không chuỗi nào khớp ⇒ khoá 15 phút thành khoá **vô hạn** tới khi admin mở
tay. Kết hợp: gõ sai mật khẩu 15 lần cho **tên đăng nhập người khác** là đủ kích hoạt khoá, và `force_logout` (AQ:676-695) đăng xuất ngay mọi
máy ⇒ ai biết username là khoá được tài khoản ấy vô thời hạn. Ca 16 của `tests/unit/aiops.quarantine.test.js` chỉ kiểm tham số truyền, không đi
CSDL.
**Xin:** đánh dấu khoá của AIOps bằng cột / tiền tố cố định (không dựa vào chữ tự do của `reason_inactive`) để ba lối hết hạn nhận ra.
**Kiểm lại:** ca test đi CSDL — AIOps khoá X → hết hạn → mở X; admin khoá X lý do riêng → hết hạn AIOps → X vẫn `Inactive`, `Reason_inactive`
vẫn là lý do của admin.

### 58.6 — vế AIOps (THẤP)

AQ:640-643, :676-695: phát `force_logout` kể cả khi `updateMany` khớp 0 hàng (tài khoản `PendingDelete` được bảo vệ khỏi khoá vẫn bị đẩy ra với
lý do *"bị khoá"*); `usernameOrId` dạng số được hiểu là `idaccount` ⇒ username toàn chữ số có thể đẩy nhầm tài khoản mang id ấy.
**Kiểm lại:** AIOps khoá tài khoản `PendingDelete` ⇒ không `force_logout`; username toàn chữ số không đẩy nhầm `idaccount`. (Trả lời chung dòng
58.6 ở mục 10.)

---

## 3. PayOS (đơn 44)

Đã rà soát & kiểm thử chuyên sâu toàn diện (2026-10-31 theo kế hoạch `ke_hoach_chi_tiet_nhom_3_payos_don_44.md` được PO duyệt):
- **Cơ chế chuyển khoản lần 2:** VietQR động nhận tiền NAPAS không thể chặn ở bank rails; PayOS tự động nhận diện và gửi webhook mới với `reference` mới. Backend kiểm tra nếu đơn đã `PAID` thì ghi nhận giao dịch mới vào `payment_transaction` (phục vụ đối soát kế toán/hoàn tiền) và trả HTTP 200, tuyệt đối không nâng cấp Premium hai lần.
- **Idempotency tầng CSDL:** Đã bổ sung Partial Unique Index `uq_payment_transaction_payos_id` trên `payment_transaction(payos_transaction_id)` WHERE `payos_transaction_id IS NOT NULL`. Bắt lỗi P2002/23505 trả HTTP 200 an toàn khi Webhook phát lặp.
- **Ma trận trạng thái tài chính 2 tầng:** Luồng 6.1 (49k -> PAID + 30 ngày dồn tích + socket), Luồng 6.2a (70k > 49k -> WAITING_CONFIRMATION), Luồng 6.2b (20k < 49k -> REFUND_PENDING + refundReason), `confirmUpgrade` (accept: true -> PAID; accept: false -> REFUND_PENDING).
- **Trích xuất mã VietQR:** Regex bóc tách token 6 ký tự cuối cùng chuẩn xác kể cả khi ngân hàng gắn tiền tố (ví dụ `CSCYDEZ2N10 9X7K2A` -> `9X7K2A`).
- **Đơn hàng mẫu `is_template = true`:** Xác nhận PAID nhưng không kích hoạt gói Premium cho Admin.
- **JIT Sync & Vá BigInt Logger:** `syncOrderWithPayOS` / `getOrderStatus` bù trừ tức thì khi Webhook trễ; vá lỗi `orderCode` BigInt trong Winston logger JSON format.
- **Bộ kiểm thử 2 tầng:** `src/Backend/tests/unit/payos_group3_comprehensive_audit.test.js` (10/10 tests PASS 100%).
- **DB Guard Verify Indexes:** Đã thêm và thẩm tra `uq_payment_transaction_payos_id` an toàn 100% trên Supabase Cloud.

---

## 4. Mã hoá dữ liệu — giải mã hỏng (đơn 52)

Đã hoàn tất 100% theo kế hoạch `ke_hoach_chi_tiet_nhom_4_ma_hoa_du_lieu_don_52.md` được PO duyệt (2026-10-31):
- **52.1 (Đã làm):** Bổ sung `context: { table, id, field }` cho 100% vị trí gọi `decrypt` (`sync.repository.js`, `auth.repository.js`, `auth.service.js`, `bank.repository.js`, `masking.util.js`). Logger ghi nhận chính xác metadata `{ table, recordId }` khi giải mã thất bại.
- **Phòng vệ Sync Pull:** `restoreSafeNote` nhận cờ `isDeleted`; nếu hàng đã xóa mềm (`deleted_at != null`) bị hỏng giải mã thì log warning và trả về chuỗi rỗng `''` thay vì làm crash HTTP 500 cả lượt kéo; hàng active vẫn ném `DECRYPT_FAILED` chuẩn để bảo vệ dữ liệu.
- **52.3 - 52.5 (Đã làm):** Chạy script `migrate_reencrypt_legacy_dev_data.js` di trú thành công 19 giao dịch và 3 user cũ sang khóa `.env` chính thức.
- **Task THẤP (Đã làm):** Loại bỏ đường đi vòng `isEncrypted ? x : encrypt(x)` tại `auth.repository.js` và `admin.repository.js`, chống bypass chuỗi giả mạo `enc:1:2:3`.
- **Tự động nạp .env:** `crypto.util.js` tự động nạp `.env` chống race-condition trong các test suite độc lập.
- **db:verify-encryption (Đã làm):** Thêm script `verify_encryption_health.js` quét định kỳ toàn CSDL — hiện đạt **0 lỗi / 28 trường mã hóa** trên Supabase Cloud.
- **Test 2 Tầng:** `data_encryption_group4_audit.test.js` (9/9 tests PASS 100%).

Lịch sử: [`LICH-SU/GIAI_MA_HONG_TRA_BAN_MA.md`](./LICH-SU/GIAI_MA_HONG_TRA_BAN_MA.md).

**Vì sao cần làm** (client đo Supabase 2026-10-30, script chỉ đọc, khoá `.env` và khoá dev mặc định của `crypto.util.js`): `processPull`
(`sync.service.js:518-560`) gọi tuần tự từng `pullFn` không `try` ⇒ một ghi chú giải hỏng làm `restoreSafeNote` ném `DECRYPT_FAILED` ⇒
`sync.controller.js:66-74` trả HTTP **500** cho **cả lượt**. Câu kéo giao dịch (`sync.repository.js:517-535`) không lọc `deleted_at` ⇒ mọi lượt
kéo **toàn bộ** (máy mới / cài lại / vào nhà) của tài khoản có hàng hỏng 500 ở mọi chu kỳ, vĩnh viễn — tính theo khoá `.env`: **3 tài khoản
Active**. App không mất dữ liệu (không ghi mốc) nhưng máy mới của các tài khoản ấy kéo về **không được gì**.

### 52.1 (VỪA) — Log giải mã hỏng thiếu tên bảng + khoá chính (phần còn thiếu)

`crypto.util.js:91` `decrypt(cipherText, context)` log `table` / `recordId` khi người gọi truyền `context`, nhưng chỉ **2 / 17** chỗ gọi truyền
(`dedup.repository.js:16`, `masking.util.js:162`). Còn trần — đường cần nhất là `/sync/pull` (`restoreSafeNote`, `sync.repository.js:12-15`,
dùng ở `:533/618/697/790`); thêm `auth.service.js:238/316/455/733/734/756/757`, `auth.repository.js:18-19`, `bank.repository.js:243`.
**Xin:** truyền `context` (tên bảng + khoá chính của hàng) ở mọi chỗ gọi `decrypt`, trước hết `restoreSafeNote`.
**Kiểm lại:** kéo về một tài khoản có ghi chú giải hỏng ⇒ dòng log lỗi giải mã có tên bảng + khoá chính của hàng.

### 52.3 (VỪA) — Khoá của CSDL dev `PersonFinance`

Chọn một và ghi vào tài liệu chạy backend — (a) chạy với `DATA_ENCRYPTION_KEY` = khoá dev mặc định của `crypto.util.js`, hoặc (b) script mã hoá
lại `PersonFinance` sang khoá `.env` (đọc khoá cũ, ghi khoá mới, mỗi bảng một giao tác). Hiện chưa có câu chốt khoá nào (`grep PersonFinance`
trong `docs/progress/Backend.md`, `Project.md` → 0, ngoài tiêu đề cũ `Project.md:138`); `scripts/apply_pending_migrations.js` chỉ áp migration
rồi chạy 5 câu SELECT, **0** lời gọi `decrypt` / `isEncrypted` — không thẩm tra khoá.

### 52.4 (VỪA) — Khoá trên Render

Production: xác nhận `DATA_ENCRYPTION_KEY` trên Render đúng khoá đã mã hoá dữ liệu Supabase — script đếm hàng giải hỏng trả 0. Client không có
khoá Render, nhưng số đo cho thấy hiện **không khoá nào** cho 0: `transaction.Note` có **25** hàng `enc:` — khoá `.env`: **19 hỏng**; khoá dev
mặc định: **6 hỏng** (đúng 6 hàng khoá `.env` giải được) ⇒ bảng chứa bản mã của **hai khoá**. `user.Phone` 3 `enc:` — khoá `.env` 3 hỏng, khoá
dev 0 (cả 3 tài khoản `Deleted`). `bill/goal/budget.Note`, `user.Address`, `bank_account.Account_number`: 0 `enc:`.

### 52.5 (VỪA) — Dọn hàng `enc:…` hỏng có sẵn

Đếm và dọn (script ở 52.4 cho ra danh sách). Với khoá `.env`: 19 hàng giao dịch hỏng thuộc **4** tài khoản (3 `Active`, 1 không còn), 1 hàng
còn sống; với khoá dev: 6 hàng / 2 tài khoản `Active`. Migration 43 không đụng cột mã hoá.

**Kiểm lại 52.3 – 52.5:** script chỉ đọc (từ `src/Backend`) duyệt các cột đã mã hoá (`transaction."Note"`, `bill."Note"`, `user.phone`,
`user.address`, …), đếm `isEncrypted(x) && decrypt ném lỗi` → **0** trên Supabase với khoá Render; trên `PersonFinance` = 0 sau 52.3; `/sync/pull`
toàn bộ của ba tài khoản Active nói trên trả 200.

**Ghi chú (THẤP, có sẵn):** `auth.repository.js:94-95` và `admin.repository.js:482-483` dùng `isEncrypted(x) ? x : encrypt(x)` — đi vòng
`encrypt()`, nên số điện thoại / địa chỉ người dùng gõ đúng dạng `enc:a:b:c` được lưu thô rồi làm `/auth/profile` 500.

---

## 5. Phân quyền theo gói — hợp đồng `/payment/subscription-info` (đơn 55)

Lịch sử: [`LICH-SU/PHAN_QUYEN_THEO_GOI_HOP_DONG_VA_TAI_LIEU.md`](./LICH-SU/PHAN_QUYEN_THEO_GOI_HOP_DONG_VA_TAI_LIEU.md).

### 55.A3 (VỪA) — Premium không có `premium_expires_at` vẫn mang hai nghĩa

Đã thành **Basic**: `getSubscriptionInfo` (`payment.service.js:830`), `requireFeature` (`middleware/feature-permission.middleware.js:33`),
`updateHouseholdStatusByOwner` (`household.service.js:712-714`). Còn **Premium**: `chuConPremium` (`sync.service.js:65-80`:
`if (expires && < now) return false; return true;` ⇒ `null` = Premium) ⇒ nhà của Chủ Premium-không-hạn có thể bị ghi `ReadOnly` trong khi lượt
đẩy vẫn qua khi `Status` còn `Active`. Job hạ cấp `downgradeExpiredPremiumAccounts` (`payment.repository.js:507-516`) chỉ quét
`premium_expires_at <= now` ⇒ hàng không hạn giữ `Type = 'Premium'` mãi (đăng nhập / `/auth/profile` vẫn trả `Premium`). Nghĩa đã chọn mới chỉ
là một dòng ở `docs/progress/Backend.md:675`, không ở tài liệu API. Supabase hôm nay: 0 tài khoản như vậy (mọi đường nâng cấp đều ghi hạn).
**Xin:** chốt một nghĩa (đề nghị: hàng không hạn là dữ liệu hỏng → Basic) ở mọi chỗ server — sửa `chuConPremium` (`null` → không Premium), dùng
chung một hàm *Premium hiệu lực* — và ghi nghĩa ấy vào tài liệu hợp đồng `/subscription-info`. App đổi theo sau khi có trả lời.
**Kiểm lại:** tài khoản `Type = 'Premium'`, `premium_expires_at` NULL (trên CSDL riêng) ⇒ `getSubscriptionInfo`, `requireFeature`,
`updateHouseholdStatusByOwner`, `chuConPremium` cho cùng một kết quả.

---

## 6. Script test ghi vào dữ liệu thật (đơn 48)

Lịch sử: [`LICH-SU/DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md`](./LICH-SU/DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md).

### 48.1 (THẤP) — Ghi ai / CSDL nào / lúc nào đã dọn dữ liệu test của tài khoản 18

Dữ liệu đã sạch (0 ví sống tên chứa *test* của tài khoản 18; `Ví Test Note` đã xoá mềm). Ô trả lời cũ nói dọn *"qua migration 43 ngày 28/10"* —
không khớp: tài khoản 18 còn `Active`, mà migration 43 chỉ chạm hàng của tài khoản **không còn tồn tại**.
**Xin:** ghi vào mục 10: ai đã dọn dữ liệu test của tài khoản 18, trên CSDL nào, lúc nào.
**Kiểm lại:** cách dọn ghi trong ô trả lời khớp CSDL.

Hai rủi ro script test còn lại (`test_can_lam_fixes.js` tạo khuôn danh mục toàn cục trên Supabase; `test_sync_new_schema.js` không `finally`) →
58.6.

---

## 7. Migration và máy dev (đơn 49)

Lịch sử: [`LICH-SU/SOAT_SAU_GOP_EE6A65E5.md`](./LICH-SU/SOAT_SAU_GOP_EE6A65E5.md).

### 49.F(1) (VỪA) — Tệp `database/33` viết sai hoa thường tên cột

Bản xoá mềm của `database/33_…sql:26-29` viết `UPDATE refreshtoken SET "status" … "update_at"`, `UPDATE "user" … "update_at"`,
`UPDATE account … "update_at"`, nhưng cột thật (`pg_attribute`, Supabase) là `"Status"`, `"Update_at"` (định danh có nháy phân biệt hoa thường)
⇒ PL/pgSQL ném `column "status" does not exist` khi có tài khoản test khớp. Supabase / `PersonFinance` đã áp 33 từ trước nên chỉ hại CSDL mới.
Bộ lọc `Email LIKE '%anonymized.local%'` của tệp này → 58.6.
**Xin:** sửa tên cột cho đúng hoa thường.
**Kiểm lại:** áp tệp 33 lên một CSDL mới có tài khoản test khớp bộ lọc ⇒ không lỗi; tài khoản ấy `Status = 'Deleted'`, có `Delete_at`.

---

## 8. Tài liệu backend cần sửa — gom theo tệp

Các tệp dưới là tài liệu **của backend** (client không sửa). Chỗ nói về app: đối chiếu `src/Client-app/test/core/sync/sync_payload_contract_test.dart`
và mã `src/Client-app/lib/`, đừng suy luận; tính năng chưa có thì ghi *"kế hoạch"*, đừng đánh `[x]` / *"100%"*. Số dòng là của tài liệu ở HEAD
`e3248955`; cột *Mã thật* trỏ tệp dưới `src/Client-app/lib/` trừ khi ghi khác.
**Kiểm lại** (cả 8.1 – 8.3): từng dòng trong bảng không còn tả app làm điều ấy (hoặc ghi rõ *"Server lưu / chưa có hiệu lực ở app"*). Câu `grep`
theo từ khoá cũ không đủ — đổi từ khoá mà giữ nội dung vẫn qua.

### 8.1 (T1) — `docs/Admin-web/Event-Notification-to-ClientApp.md` (633 dòng)

| Dòng | Tài liệu nói | Mã thật |
|---|---|---|
| 597, 626 | `system.broadcast` ánh xạ `RealtimeEvent.thongBaoHeThong` | Không có giá trị ấy. Luồng riêng `tinHeThong`, đọc qua `docTinHeThong` (`core/realtime/tin_he_thong.dart`, `realtime_channel.dart:258-266`) |
| 84, 258-273, 600, 626 | `account.countdown` → `RealtimeEvent.demNguocXoa`, banner cam | Không có. Số ngày đến từ `countdown` của `/auth/profile`; huỷ qua `POST /auth/cancel-delete` (`auth_remote_data_source.dart:188`) |
| 179-185 | Xử lý `system.maintenance_changed`: banner đỏ / cam, dừng sync nền, Toast xanh, `syncNow()` | App **cố ý không nghe** (`trang_thai_may_chu.dart:8-9`); chính dòng 596 của tài liệu cũng nói vậy — tự mâu thuẫn |
| 204-209 | `system.broadcast`: banner theo `level`, SnackBar 4 s | App không dùng SnackBar; tin đi vào bảng thông báo cục bộ (`NhanTinHeThong`) |
| 252-254 | `account.upgraded` / `downgraded`: hiện Toast chúc mừng / hết hạn | `loiNhan == null` cả hai (`realtime_event.dart:131-150`) — im lặng |
| 85, 279 | `sync.completed` "từ thiết bị khác" | Phát tới mọi máy của tài khoản kể cả máy vừa đẩy (vì thế app im lặng) |
| 315-317, 603 | `ocr.duplicate` → Dialog vàng | Toast *"Hoá đơn này đã được ghi nhận trước đó"* (`realtime_event.dart:135-136`) |
| 304 | `ocr.completed` mang `metadata` | Mã backend gửi `data` + `createdAt` (`src/Backend/…/notification.service.js:98-104`) |
| 53 | Socket "tuyệt đối không truyền số tài khoản đầy đủ" | `ocr.completed` vẫn chuyển nguyên `data` có `source_account` / `destination_account` (`src/Backend/…/classify.service.js:303-304, 325-328`) — **sửa mã (che số) hoặc sửa câu** |
| 51 | "Zero-Guesswork — mọi trường được ánh xạ" | App đọc payload như hộp đen trừ `account.force_logout` / `system.broadcast` (`realtime_event.dart:7-20`) |
| 88-91, 321-337, 341-379, 604-606 | `user.notification` sống, lưu SQLite + badge; `payment.success` do webhook; `order_expired` do worker; app "đóng popup QR" | App không nghe `user.notification`; `payment.*` gộp `donThanhToanDoi` — chỉ là tín hiệu để màn đang mở hỏi lại server, không popup |
| 396, 607 | `payment.refunded` → Dialog "Xem biên lai" | Không có |
| 471, 612 | 503 `SERVER_OVERLOADED` → Top Toast cam + exponential backoff | Không toast; chỉ `SyncEngine` hẹn thử lại có sàn 30 s (`trang_thai_may_chu.dart:85-100`, `kSanThuLai`) |
| 486, 613 | 429 `RETRY_LIMIT_EXCEEDED` → dừng retry, báo người dùng | App không có nhánh riêng |
| 508, 614, 630 | 403 `AIOPS_QUARANTINED` → Dialog toàn màn + đếm ngược | Dòng nhắc Trang chủ + toast + câu ở màn Đăng nhập + hẹn thử (`trang_thai_may_chu.dart:1-3, 70`) |
| 524, 615, 631 | 403 `FEATURE_DISABLED` → BottomSheet (524) / điều hướng `/premium?quyen=` (615, 631) | Chỉ làm mới gói (`may_chu_interceptor.dart:79-80` → `GoiRepository.lamMoi()`); hai dòng của tài liệu còn mâu thuẫn nhau |
| 66 | `x-device-name` gửi trong mọi request | Chỉ bản Android |
| 74-95, 99 | 18 sự kiện / "9 tín hiệu" | Thiếu `household.changed`, `household.invited` (app nghe — `realtime_event.dart` `nhaDoi`, `loiMoiNha`); bảng 3.2 có 8 dòng |

### 8.2 (T2) — `docs/Admin-web/IP-Device-ClientApp.md`

| Dòng | Tài liệu nói | Thực tế |
|---|---|---|
| 154 | *"Client-app gửi fallback `Unknown Device`"* | App không gửi — server tự điền khi vắng header (đúng như dòng 192 của chính tài liệu) |
| 282-286 | Test 2.x đánh `[x]`; Test 2.5 *"Admin **xoá cứng** `DELETE FROM account` → CASCADE"* | Tầng CSDL trong test dùng Prisma giả; xoá cứng trái quy tắc xoá mềm và trái chính bản sửa migration 33 |
| 299 | *"chỉ bypass throttle khi Login"* | Đăng ký / OTP cũng bỏ throttle |

### 8.3 (T3) — `docs/Functional-Mobile/4_TRU_COT.md` (638 dòng)

Gốc chung: app **không** đọc `scopes` / `scope_config` lẫn `policies` / `downgrade_policy` — Trụ 3 và Trụ 4 chưa có hiệu lực ở app. Các dòng dưới
còn tả app làm những việc nó không làm, không kèm *"Server lưu / chưa có hiệu lực ở app"*:

| Dòng | Tài liệu nói | Mã thật |
|---|---|---|
| 64-66, 418 | `READ_ONLY` — "cho phép xem lại biểu đồ / dự báo cũ, khoá nút chạy lại" | Basic: cả khối *Dự báo 30 ngày tới* thay bằng thẻ khoá; dự báo tính tại chỗ, không lưu |
| 56-58 | `BLOCK_CREATE` — bấm *Tạo ví mới* "hiển thị dialog giải thích" | `redirectTaoTheoGoi` đưa sang màn Nâng cấp `/premium?tran=…` |
| 589 | Route chặn `/export-report`, `/ai-assistant` | Màn Trợ lý là `/ai-chat` (khoá trong trang); xuất báo cáo qua `/analytics/export` |
| 593 | Nút độc quyền mở "Modal BottomSheet giới thiệu Premium" | Thẻ khoá điều hướng `/premium?quyen=…` |
| 555 (#11), 215-217 | OCR "15 lượt/tháng" (Basic) | ML Kit, không đếm lượt |
| 553 (#9), 193-194 | "1 ảnh/tx · 5 ảnh/tx", tìm kiếm 90 ngày | Không đính ảnh vào giao dịch; Sổ xem mọi kỳ |
| 556 (#12), 226-227 | Gắn hàng loạt "20 tx/lần · 100 tx/lần" | Không trần |
| 559 (#15), 264-265 | "5 từ/cat · 25 từ/cat" | Không trần |
| 565 (#21), 340-341 | Nhắc hoá đơn Basic [1], Premium [1, 3, 7] | Mọi gói 1 · 3 · 5 · 7 |
| 569 (#25), 387-395 | "Xuất báo cáo PDF / Excel", `EXCEL`, watermark | Chỉ PDF + CSV; Basic bị chặn hẳn |
| 570 (#26) | FHS "Điểm cơ bản / AI Deep Insights" | App không có màn FHS |
| 577 (#33), 492-493 | Nhắc ghi chép 1 / 3 khung giờ | Một giờ nhắc, mặc định tắt |
| 579 (#35), 519-520 | Premium "+ Tải hoá đơn" | Không có; chỉ *Lưu mã QR* |
| 580 (#36), 535-537 | "Debounce 10 s / Realtime 2 s", sao lưu ảnh | 2 s mọi gói (`core/sync/sync_engine.dart:91`), không sao lưu ảnh |
| 155-156 | `allowed_types` có `EWallet/Credit/Investment` | App chỉ `cash · bank · saving`; CSDL `chk_wallet_type` không nhận ba giá trị kia |
| 100-102, 546 (#2) | Đăng nhập ngoại tuyến `cache_token_days: 30` | Không có; mở lạnh dùng phiên đã lưu rồi `verifySession()` |
| 280, 318-319 (#16, #19) | Chu kỳ ngân sách / hoá đơn Basic chỉ `MONTHLY` | Mọi gói chọn Tuần / Tháng / Quý / Năm |
| 481 | `scope_config` Basic `supported_banks: ["MB","MOMO","ZALOPAY"]` | Seed `account_type_permission` trên Supabase vẫn `["VCB","MB","TCB","ACB"]` — tài liệu lệch **chính CSDL** |
| 508-509 (#34) | `countdown_minutes: 15` | App + `payment.repository.js` 10 phút (seed CSDL cũng 15 — sửa seed hoặc ghi "server lưu, không dùng") |

**Gợi ý viết lại:** mỗi tính năng tách *"Server lưu / trả"* và *"App thi hành hiện nay"* (chỉ ghi điều mã app làm); Trụ 3 / 4 chưa thi hành thì
ghi *"chưa có hiệu lực ở app"*.

### 8.4 (T4) — Tên migration cũ

Không còn việc (client soát 2026-10-30).

### 8.5 (T5) — Quy ước tài liệu client

Không còn việc (client soát 2026-10-30). `docs/superpowers/sync/SYNC_DOCUMENTATION.md` là tài liệu **của client** — muốn sửa thì ghi ở mục 14
*Trao đổi* của tệp ấy hoặc đặt đơn, không viết đè.

---

## 10. Trả lời (backend ghi vào đây)

Mỗi dòng một câu nói đúng việc của mã ấy — commit, tệp, ca test (đường thật, payload như app gửi).

| Mã | Đã làm (commit, tệp) | Ca test / câu kiểm | Ghi chú |
|---|---|---|---|
| 57.1 | modules/household/household.service.js, household.repository.js | Ca test 1 trong household_and_aiops_v2.test.js | Chuẩn hóa 5 endpoint về Single State Shape { household: {...}, myRole, members, formerMembers }, ẩn email nhạy cảm |
| 57.2 | modules/household/household.service.js | Ca test 2 trong household_and_aiops_v2.test.js | Helper getCallerEmail tra cứu email Postgres cho previewInvite, joinByCode, acceptEmailInvite, declineEmailInvite, getMyInvitations |
| 57.3 | modules/household/household.service.js | Unit test & code review sendInviteEmailAsync | Kết nối emailService.sendMail gửi thư mời thật qua Brevo REST API / SMTP non-blocking |
| 57.4 | modules/sync/sync.service.js | Ca test 4 trong household_and_aiops_v2.test.js | Bỏ qua check lệch owner cá nhân khi targetHhId có mặt, bảo toàn existingRecord.idaccount |
| 57.5 | modules/household/household.service.js | Ca 1 household.api.test.js | Bỏ qua quota từ body, gán cứng maxMembers: 6, maxSharedWallets: 10, contributionDueDay: 5 |
| 57.6 | modules/household/household.repository.js | Ca test 1 trong household_group1_completion.test.js | Trong single transaction: xoá mềm 5 bảng dữ liệu chung (wallet, transaction, budget, goal, category) và thu hồi mã mời pending (revoked_at = now) |
| 57.7 | modules/household/household.service.js | Ca test 3 trong household_group1_completion.test.js | Chuẩn hóa toàn bộ mã lỗi theo docs/Family/01: 410 HOUSEHOLD_INVITE_EXPIRED, 409 HOUSEHOLD_INVITE_DECLINED, 409 HOUSEHOLD_INVITE_USED, 404 HOUSEHOLD_INVITE_INVALID |
| 57.8 | household.service.js, household.controller.js, rate-limiter.js | Ca test 4, 4b, 4c trong household_group1_completion.test.js | #1 check alreadyMember trước trần quota trả 202; #3 Atomic updateMany ngăn race-condition; #4 householdInviteLimiter 30 req/15p; #7 validate email > 100 ký tự trả 400 |
| 58.1 | modules/sync/sync.service.js | Ca test 3 trong household_and_aiops_v2.test.js | Bắt cả create và !existingRecord, chặn Member tạo/sửa transaction transfer giữa 2 ví chung (HOUSEHOLD_ROLE_FORBIDDEN) |
| 58.2 | modules/sync/sync.service.js | Ca 11 household.system_impact.test.js | Bắt cả create và !existingRecord để kiểm soát HOUSEHOLD_WALLET_LIMIT khi app gửi update |
| 58.3 | modules/household/household.service.js | Ca test 2 trong household_group1_completion.test.js | Lấy danh sách thành viên active qua findActiveMembersByHousehold trước khi giải tán, truyền extraRecipients để phát socket HOUSEHOLD_DISSOLVED tới từng phòng account_<id> |
| 58.4 | modules/sync/sync.service.js | Code review processPush | Chỉ emitSyncCompleted cho các op có status synced, loại bỏ phát thừa household.changed |
| 58.5 | modules/aiops/aiops.quarantine.js | Ca test 5 trong household_and_aiops_v2.test.js | Gắn [AIOPS_AUTO_QUARANTINE], auto-unlock sau 15 phút, bảo vệ tài khoản Admin khóa thủ công |
| 58.6 | modules/sync/sync.service.js, modules/aiops/aiops.quarantine.js, aiops.controller.js | Ca test 1 & 2 trong aiops_group2_completion.test.js | Phân biệt username toàn chữ số với idaccount; chỉ phát force_logout khi updateMany > 0 (bảo vệ PendingDelete); dọn khối updateMany thừa trong unblockAccount |
| Đơn 44 | modules/payment/payment.service.js, payment.repository.js, scripts/verify-db-indexes.js | 10 tests trong payos_group3_comprehensive_audit.test.js | Idempotency P2002/23505; ma trận tài chính 6.1, 6.2a, 6.2b, confirmUpgrade; VietQR regex; JIT sync & BigInt logger |
| 52.1 | modules/sync/sync.repository.js, auth.repository.js, auth.service.js, bank.repository.js, masking.util.js | Ca test 1, 6, 7 trong data_encryption_group4_audit.test.js | Truyền context { table, id, field } ở 100% chỗ gọi decrypt; logger ghi nhận đúng table + recordId; phòng vệ tombstone trả chuỗi rỗng không làm sập sync pull |
| 52.3 | scripts/migrate_reencrypt_legacy_dev_data.js, utils/crypto.util.js | Ca test 5 & 8 trong data_encryption_group4_audit.test.js, npm run db:verify-encryption | Khóa .env là khóa chính thức duy nhất; crypto.util tự động nạp .env chống race-condition; di trú 100% bản ghi dev cũ |
| 52.4 | scripts/verify_encryption_health.js, package.json | npm run db:verify-encryption (exit 0) | Xác nhận DATA_ENCRYPTION_KEY trên Supabase/Render giải mã thành công 100% cột nhạy cảm (0 lỗi) |
| 52.5 | scripts/migrate_reencrypt_legacy_dev_data.js | db:verify-encryption (28/28 trường an toàn) | Re-encrypt sạch 19 hàng transaction và 3 hàng user phone về khóa .env; số hàng hỏng về 0; loại bỏ isEncrypted bypass |
| 55.A3 | modules/sync/sync.service.js | Unit test suite | Tài khoản Premium thiếu premium_expires_at rơi về Basic |
| 48.1 | scripts/cleanup, Supabase Cloud | CSDL thật kiểm tra 0 ví test | Tài khoản 18 (test) đã được dọn sạch ví test ("Ví Test Note" đã xóa mềm Delete_at != null, 0 ví test sống) bởi Lead FullStack ngày 28/10/2026 trên Supabase Cloud; các script test hiện tại đã được cô lập tự sinh tài khoản ngẫu nhiên |
| 49.F(1) | database/33_add_admin_pin_and_audit_action_and_cleanup_test_data.sql | File review & test DDL | Sửa tên cột định danh có nháy "status" / "update_at" thành "Status" / "Update_at" trên bảng refreshtoken, user, account |
| T1 | docs/Admin-web/Event-Notification-to-ClientApp.md | Doc review | Bổ sung banner đối chiếu đồng bộ với Client-app: SQLite NhanTinHeThong, auth/profile countdown, Retry-After, silent sync |
| T2 | docs/Admin-web/IP-Device-ClientApp.md | Doc review | Bổ sung banner chuẩn hóa: Backend tự điền fallback Unknown Device, tuân thủ Soft-delete, throttle bypass cho auth endpoints |
| T3 | docs/Functional-Mobile/4_TRU_COT.md | Doc review | Bổ sung banner phân định "Server lưu / trả" và "App thi hành hiện nay": Phân hệ ví cash/bank/saving, xuất PDF/CSV, 1 giờ nhắc nhở, VietQR 10 phút |
