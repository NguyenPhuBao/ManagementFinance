# Việc backend còn phải làm — MỘT tệp (gộp đơn 43 · 44 · 48 · 49 · 50 · 52 · 55 · 56)

> **Client gộp 2026-10-28** (phiên 20). Người nhận: backend (NPBao).
>
> **Cách dùng.** Chỉ cần đọc tệp này. Mỗi việc có **mã** giữ số đơn cũ (vd. `56.1`, `43.A3`) để các tài liệu khác dẫn *"đơn 43"* vẫn
> tra được. Làm xong việc nào thì ghi vào bảng **Trả lời** ở cuối tệp (commit, tệp, ca test). Tám tệp đơn gốc nằm ở
> [`LICH-SU/`](./LICH-SU/): ở đó có lý do đầy đủ, các lượt soát cũ, số đo lịch sử, nhưng chúng **không cập nhật nữa** và đừng ghi trả
> lời vào đó.
>
> **Trạng thái đo.** Client đọc mã ở HEAD `8219dcc5` (backend mới nhất `177dd0e1`, PR #168) và truy vấn **chỉ đọc** trên CSDL Supabase
> của `.env`, ngày 2026-10-28. Những vế đã đạt nằm ở mục 9 để khỏi làm lại. Client soát lại từng việc bằng mã + CSDL sau khi backend
> báo xong — xin kèm ca test đi qua **đường thật** (route / `processPush`), không chỉ gọi thẳng hàm con.
>
> **Quy ước repo cần giữ khi làm:** migration theo tệp `src/Backend/database/N_*.sql` áp tay (`docs/Rule_Project/Rule_project.md`
> §3.2); không xoá cứng dữ liệu người dùng (xoá mềm `Delete_at` / `Deleted_at`); thử nghiệm trên **CSDL riêng**, không trên Supabase
> dùng chung (hàng thử đi vào `/sync/pull` của tài khoản thật).

---

## 0. Bảng việc — xếp theo mức

| Mã | Việc | Mức | Loại | Mục |
|---|---|---|---|---|
| 56.1 | `/sync/push` gọi `findMember` không tồn tại → vai và `ReadOnly` của nhà không bao giờ được xét | **CAO** | mã | 1 |
| 56.2 | Thi hành đúng bảng quyền + thứ tự mã của gia đình (người ngoài nhà, nhà giải tán, Viewer, mục tiêu chung, danh mục nhà, chuyển khoản) | **CAO** | mã | 1 |
| 56.3 | Không cho đổi `Idhousehold` của hàng đã có qua `/sync/push` | **CAO** | mã | 1 |
| 56.4 | Basic tạo được nhà — seed khoá quyền `household` + `requireFeature` | **CAO** | mã + migration | 1 |
| 56.5 | Từ chối quyền bằng `Error` trơn → `DB_ERROR` → app gửi lại **mãi** | **CAO** | mã | 1 |
| 43.A3 | Mở trang AIOps sau hạn cách ly là mở khoá cả tài khoản **admin khoá tay** | **CAO** | mã | 2 |
| 44.B2 | Áp migration 38 (unique `payos_transaction_id`) — kèm 39 | VỪA | migration | 3 |
| 43.A5 | Ràng buộc `ck_account_status` — bảng `account` 0 CHECK | VỪA | migration | 2 |
| 52.1 – 52.5 | Giải mã hỏng: log thiếu bảng + khoá; hai hàm nuốt lỗi; khoá `PersonFinance`; khoá Render; dọn hàng hỏng cũ | VỪA | mã + vận hành | 4 |
| 55.A1 – 55.A3 | `/subscription-info`: cột Premium cho Basic; Trụ 1 của mã LIMIT; Premium không hạn | VỪA | hợp đồng | 5 |
| 56.6 | Kiểm phạm vi đọc sai khoá → không chạy với giao dịch của app | VỪA | mã | 1 |
| 56.7 | Chủ nhà hết / gia hạn Premium không đổi trạng thái nhà | VỪA | mã | 1 |
| 56.8 | `household.changed` / `sync.completed` phát vào phòng không ai ở | VỪA | mã | 1 |
| 48.2 – 48.3 | Script test ghi vào tài khoản người dùng thật | VỪA | script | 6 |
| 49.D | Bẫy thứ tự `npm install` / migration trên máy dev | VỪA | mã hoặc tài liệu | 7 |
| 49.F | Migration 33 xoá cứng → 10 ví · 13 giao dịch · 1 danh mục mồ côi trên Supabase | VỪA | migration + dọn | 7 |
| T1 | Sửa `docs/Admin-web/Event-Notification-to-ClientApp.md` (gộp 43.D · 44.F · 49.H1) | VỪA | tài liệu | 8.1 |
| T2 | Sửa `IP-Device-ClientApp.md` + `04-user-management-and-lifecycle.md` (49.E · 49.H3) | VỪA | tài liệu | 8.2 |
| T3 | Đính chính `docs/Functional-Mobile/4_TRU_COT.md` (55.B — 31 khẳng định sai) | VỪA | tài liệu | 8.3 |
| 43.A6 | (Tuỳ chọn) AIOps khoá tài khoản thì phát `account.force_logout` | THẤP | mã | 2 |
| 56.9 | Trần ví chung; danh mục sao cho nhà thiếu từ khoá / nhóm | THẤP | mã | 1 |
| 48.1 | Ghi xác nhận ai / CSDL nào đã dọn dữ liệu test | THẤP | trả lời | 6 |
| T4 | Tên migration cũ `27_create_aiops_metric…` còn trong hai tài liệu (49.C) | THẤP | tài liệu | 8.4 |
| T5 | Xác nhận quy ước: không viết đè tài liệu client (49.A) | THẤP | trả lời | 8.5 |

---

## 1. Gia đình phần 1 (đơn 50 + 56) — CAO, chặn client làm tính năng gia đình

**Bối cảnh.** Backend báo xong đơn 50 ở `177dd0e1`. Client soát: phần **hàng riêng tư** đạt (`NOT_OWNER` ở 6 thực thể, phạm vi kéo về,
migration 40 trên Supabase), nhưng mọi chốt chặn của **hàng thuộc nhà** không chạy. Supabase hiện 0 nhà, app chưa gửi `idhousehold` ⇒
chưa ai bị ảnh hưởng; phải sửa trước khi client làm lát 1. **Đặc tả không đổi** — nằm sẵn trong đơn 50 do backend viết
([`LICH-SU/GIA_DINH_NEN_MONG.md`](./LICH-SU/GIA_DINH_NEN_MONG.md) Việc D phần *2. Nhánh Đẩy lên*, Việc E, Việc F) và
`docs/Family/01_NEN_MONG.md` mục 3. Bản phân tích đầy đủ: [`LICH-SU/SOAT_SAU_GOP_7B56D822.md`](./LICH-SU/SOAT_SAU_GOP_7B56D822.md).

### 56.1 (CAO) — `householdRepository.findMember` không tồn tại

`sync.service.js:200` gọi `householdRepository.findMember(targetHhId, idaccount)`; `household.repository.js` chỉ có `findHouseholdById`
(`:27`) và `findActiveMemberByAccount` (`:36`) — `grep -rn "findMember\b" src/Backend` (trừ `node_modules`) ra đúng 1 dòng là lời gọi
ấy. `TypeError` bị `catch {}` nuốt ⇒ `userRole = null`, `householdStatus = 'Active'` ⇒ không bao giờ có `HOUSEHOLD_ROLE_FORBIDDEN` /
`HOUSEHOLD_READ_ONLY` từ đường đẩy. Ca test 3–6 của `household.system_impact.test.js` (`:105-173`) gọi thẳng
`enforceHouseholdPermission({ userRole: 'Member' })` nên không bắt được.

**Xin làm.**
1. Thêm vào `household.repository.js`:
   ```js
   async findMember(idhousehold, idaccount) {
     return prisma.household_member.findFirst({
       where: { idhousehold: Number(idhousehold), idaccount: Number(idaccount), left_at: null },
       include: { household: true },
     });
   },
   ```
2. Thêm một hàm tra nhà **không lọc `delete_at`** cho phép kiểm này — `findHouseholdById` lọc `delete_at: null`, mà giải tán ghi cả
   `delete_at` lẫn `Status = 'Dissolved'` (`household.repository.js:231-249`) ⇒ nhà đã giải tán hiện tra ra `null` → rơi về `'Active'`.
3. Bỏ `catch {}` nuốt lỗi: tra thành viên lỗi thì để thao tác lỗi như lỗi thường (app gửi lại chu kỳ sau), **không** cho ghi.

### 56.2 (CAO) — Thi hành đúng bảng quyền và thứ tự mã

Đặc tả (đơn 50 Việc D phần 2):

| Hàng của nhà | Tạo | Sửa | Xoá |
|---|---|---|---|
| `wallet` | Owner | Owner | Owner |
| `goal` | Owner | Owner | Owner |
| `budget` | Owner | Owner | Owner |
| `category` | Owner, Member | Owner, Member | Owner, Member |
| `transaction` thu / chi | Owner, Member | người ghi hoặc Owner | người ghi hoặc Owner |
| `transaction` `Transfer` giữa hai ví chung | Owner | Owner | Owner |
| `transaction` có `Idfund_pair` | *(phần 2a — chưa có cột, chưa làm)* | | |

Thứ tự mã: (1) không là thành viên đang ở ⇒ `HOUSEHOLD_NOT_MEMBER` · (2) nhà `Dissolved` ⇒ `HOUSEHOLD_CLOSED` · (3) vai `Viewer` **hoặc**
nhà `ReadOnly` ⇒ `HOUSEHOLD_READ_ONLY` · (4) tham chiếu sai phạm vi ⇒ `HOUSEHOLD_SCOPE_MISMATCH` · (5) không khớp bảng ⇒
`HOUSEHOLD_ROLE_FORBIDDEN`. App đã xếp `NOT_OWNER` và cả 6 mã `HOUSEHOLD_*` (kể cả `_ROLE_FORBIDDEN`, `_WALLET_LIMIT`) là lỗi vĩnh viễn.

Mã hiện tại (`enforceHouseholdPermission`, `sync.service.js:69-95`; chỗ gọi `:180-217`) lệch 7 chỗ: (a) người ngoài nhà không bị chặn;
(b) không có nhánh `Dissolved` (đang kiểm `'Inactive'` — giá trị CHECK không cho); (c) Viewer ghi được mọi thứ; (d) Member tạo / sửa / xoá
được **mục tiêu** chung (mảng `:77` thiếu `goal`); (e) Member **không** sửa được danh mục nhà (mảng `:77` có `category`); (f) chuyển khoản
giữa ví chung không phân biệt; (g) kiểm phạm vi chạy **trước** mọi bước (`:184`). Thêm: nhà để xét lấy `payload.idhousehold` trước
(`:186-192`) — với sửa / xoá phải là `existing.idhousehold`.

**Xin làm** — gom một hàm, chạy sau khi có `existing` và trước `upsert*` / `softDelete`:

```js
// hhId = existing ? existing.idhousehold : payload.idhousehold (sau chuẩn hoá khoá)
async function kiemGhiVaoNha({ entity, operation, idaccount, hhId, existing, payload }) {
  if (!hhId) return;                                            // hàng riêng tư — NOT_OWNER lo
  const house  = await timNhaMoiTrangThai(hhId);                // không lọc delete_at (56.1 bước 2)
  const member = await householdRepository.findMember(hhId, idaccount);
  if (!member) {
    if (house?.status === 'Dissolved' && await daTungOTrongNha(hhId, idaccount)) throw ma('HOUSEHOLD_CLOSED');
    throw ma('HOUSEHOLD_NOT_MEMBER');
  }
  if (member.role === 'Viewer' || house.status === 'ReadOnly' || !(await chuConPremium(house))) throw ma('HOUSEHOLD_READ_ONLY');
  await kiemPhamVi(payload, hhId);                              // 56.6
  if (!duocPhepTheoBang(entity, operation, member.role, idaccount, existing, payload)) throw ma('HOUSEHOLD_ROLE_FORBIDDEN');
}
```

- Giải tán đặt `Left_at` cho mọi thành viên (`household.repository.js:242-248`) nên theo thứ tự thuần thì `HOUSEHOLD_CLOSED` không bao giờ
  xảy ra — đề xuất như phác (người **từng** ở nhà đã giải tán ⇒ `CLOSED`). App coi cả hai là vĩnh viễn, chỉ khác câu báo.
- `chuConPremium` nên có: giữa lúc hạn Premium của Chủ nhà qua và lúc tác vụ hạ cấp chạy (0h00 VN) cột `Status` vẫn `'Active'`. Tính hạn
  hiệu lực giống `requireFeature` (`middleware/feature-permission.middleware.js:24-36`).
- "Người ghi" = `existing.idaccount`; nhánh cập nhật hiện không ghi đè `idaccount` — giữ nguyên.

### 56.3 (CAO) — Không cho đổi `Idhousehold` của hàng đã có

Cả 5 nhánh cập nhật ghi `idhousehold: mapped.idhousehold !== undefined ? mapped.idhousehold : existing.idhousehold`
(`sync.repository.js` `:263`, `:354`, `:482`, `:565`, `:728`). Kết hợp nhà-xét-theo-payload và việc bỏ `NOT_OWNER` khi hàng là của nhà
(`isShared`, `:249` …): một lượt đẩy kéo được hàng của nhà A sang nhà B, hoặc tư hữu hoá hàng của nhà (đặt `idhousehold: null` — sau đó
`NOT_OWNER` lại bảo vệ nó như hàng riêng). Đặc tả không có luồng nào đổi phạm vi: ví chung là hàng `wallet` **tạo mới** (`docs/Family/02A`
mục 2), góp / rút là **cặp hai giao dịch** (`02A` mục 5), khoản của người rời nhà *"ở lại nhà (không đổi `Idhousehold`)"*.

**Xin làm.** Hàng đã có mà payload mang `idhousehold` **khác** giá trị đang lưu (kể cả `null`) ⇒ `HOUSEHOLD_SCOPE_MISMATCH`, không ghi.
Payload không mang khoá ⇒ giữ giá trị đang lưu.

### 56.4 (CAO) — Basic tạo được nhà

`household.controller.js:27` chỉ chặn khi `req.user.permissions` là mảng — payload JWT không có trường ấy (`auth.service.js:399-408`
đăng nhập, `:197` / `:275` đăng ký) ⇒ phép kiểm luôn bị bỏ qua; route `POST /api/households` (`api/households.routes.js:10`) không có
middleware quyền. Đo Supabase: bảng `feature` 36 mã, **không có** `household` / `household_members`. ⚠️ `requireFeature` chỉ chặn khi đọc
được **đúng** `false` (`feature-permission.middleware.js:45`) và cho qua khi lỗi (`:59-63`) — gắn middleware mà không seed là vẫn mở.

**Xin làm.**
1. `database/41_seed_household_permissions.sql` (khuôn `database/32`; các cột bỏ qua đều có mặc định — đo `information_schema`):
   ```sql
   BEGIN;
   INSERT INTO "feature" ("id", "name", "description", "type", "category_group",
                          "default_limit", "default_enabled", "default_downgrade_policy", "created_at", "updated_at")
   VALUES
     ('household',         'Gia đình — tạo nhà',              'Chủ nhà cần Premium; người được mời dùng miễn phí', 'TOGGLE', 'Gia đình', NULL, false, 'LOCK_FEATURE', NOW(), NOW()),
     ('household_members', 'Gia đình — số thành viên tối đa', 'Trần thành viên mỗi nhà, gồm Chủ nhà',            'LIMIT',  'Gia đình', 6,    true,  'BLOCK_CREATE', NOW(), NOW())
   ON CONFLICT ("id") DO NOTHING;

   INSERT INTO "account_type_permission" ("account_type", "feature_id", "is_enabled", "limit_value", "downgrade_policy", "updated_at")
   VALUES
     ('Basic',   'household',         false, NULL, 'LOCK_FEATURE', NOW()),
     ('Premium', 'household',         true,  NULL, 'LOCK_FEATURE', NOW()),
     ('Basic',   'household_members', false, NULL, 'BLOCK_CREATE', NOW()),
     ('Premium', 'household_members', true,  6,    'BLOCK_CREATE', NOW())
   ON CONFLICT ("account_type", "feature_id") DO NOTHING;
   COMMIT;
   ```
   Tên / nhóm / trần do PO chốt; tối thiểu phải có `('Basic', 'household', false)`.
2. `api/households.routes.js:10` → `router.post('/', requireFeature('household'), householdController.createHousehold);`; gỡ phép kiểm
   chết `household.controller.js:26-34`.
3. (Tuỳ PO) trần thành viên đọc `household_members` của gói Chủ nhà thay vì chỉ cột `household.Max_members`.

App không phải sửa gì: `/subscription-info` trả thêm hai khoá, app lưu bảng `features` thành `Map` và chỉ đọc mã của mình.

### 56.5 (CAO) — Từ chối bằng `Error` trơn → `DB_ERROR` → app gửi lại mãi

`upsertCategory` (`sync.repository.js:253-258`) ném `new Error('Cannot modify system default category')` và `new Error('Cannot modify
category belonging to another user')` — không `code` ⇒ mặc định `DB_ERROR` (`sync.service.js:267`); regex `FORBIDDEN_SYSTEM_DEFAULT`
(`:327`) chỉ khớp *"cannot **delete**"*. App coi `DB_ERROR` là lỗi tạm (danh sách vĩnh viễn là danh sách trắng —
`src/Client-app/lib/core/sync/gui_lo_dong_bo.dart:302-339`) ⇒ gửi lại ở **mọi** chu kỳ. Với gia đình: danh mục sao khi tạo nhà mang
`create_by` = Chủ nhà (`household.service.js:92`) ⇒ Member sửa ⇒ vòng lặp, trong khi đặc tả cho Member sửa.

**Xin làm.** Vế `:256` chỉ áp cho hàng riêng tư (`!isShared`) — hàng của nhà để 56.2 quyết. Mọi lỗi từ chối quyền trên đường đẩy mang
`code` vĩnh viễn: `:253-254` → `FORBIDDEN_SYSTEM_DEFAULT` (regex `:327` thành `/cannot (delete|modify) system default category/i`, hoặc
gắn `code`). Rà `sync.repository.js` cho mọi `throw new Error(` không `code` khác trên đường đẩy.

### 56.6 (VỪA) — Kiểm phạm vi đọc sai khoá

`validateEntityScope` (`sync.service.js:100-115`) chạy ở `:184`, **trước** `mapEntityFields`, chỉ đọc `payload.idwallet`. Payload giao
dịch của app mang **`walletId`** (hợp đồng `src/Client-app/test/core/sync/sync_payload_contract_test.dart:391`; `idwallet_transfer` `:393`,
`idgoal` `:397-398`; ngân sách / mục tiêu mang `idwallet` `:577`, `:650`) ⇒ phép kiểm bỏ qua đúng ca nó sinh ra (giao dịch riêng trỏ ví
chung). Ca test 7 dựng payload bằng `idwallet` (`household.system_impact.test.js:193-196`) nên không lộ.

**Xin làm** (bước 4 của 56.2): đọc khoá sau chuẩn hoá (hoặc `idwallet ?? walletId`); phạm vi của hàng = `existing.idhousehold` (đã có)
hoặc `payload.idhousehold` (tạo mới); so với ví nguồn (`idwallet`), ví đích (`idwallet_transfer`), mục tiêu (`idgoal` — giao dịch **riêng**
chỉ trỏ mục tiêu riêng của chính người ấy, trỏ mục tiêu nhà ⇒ `SCOPE_MISMATCH`, theo đơn 50 Việc D phần 2 bước 4).

### 56.7 (VỪA) — Trạng thái nhà theo gói của Chủ nhà

Toàn backend chỉ **đọc** `'ReadOnly'` (`sync.service.js:70`); không chỗ nào ghi `household.Status = 'ReadOnly'` / `'Active'` (đặc tả: đơn 50
Việc E). **Xin làm:** một hàm `capNhatTrangThaiNhaTheoChu(idaccount)` — tìm nhà tài khoản đang là `Owner`, tính Premium hiệu lực (luật
`feature-permission.middleware.js:24-36`), nhà không `Dissolved` mà lệch thì ghi + phát `household.changed` (`eventType: 'STATUS_CHANGED'`,
người nhận theo 56.8). Gọi ở: hạ cấp `core/scheduler.service.js:295-325` (từng tài khoản); sau `paymentRepository.activatePremiumSubscription`
(`payment.repository.js:392` — ba nơi gọi `payment.service.js:317`, `:415`, `:700`); chuyển Chủ nhà `household.service.js:375-398` (tính theo
Chủ nhà **mới**; PO có thể chọn chặn chuyển cho tài khoản Basic). Rời nhà / mời ra / giải tán vẫn chạy khi `ReadOnly`.

### 56.8 (VỪA) — Sự kiện tới phòng không ai ở

`household.changed` phát tới `household_${id}` (`household.service.js:650-665`, `sync.service.js:362`) nhưng lúc kết nối
`core/socket.js:61-79` chỉ `join` `account_<id>` và `admin_room`. `sync.completed` chỉ tới phòng của người đẩy (`core/socket.js:216`,
qua event bus `sync.service.js:346`); đặc tả (đơn 50 Việc F) xin tới **mọi thành viên**.

**Xin làm:** phát theo phòng tài khoản của từng thành viên — `findActiveMembersByHousehold(hhId)` (`household.repository.js:48`) →
`emitToAccount(id, 'household.changed', …)` (`core/socket.js:354`) + `emitSyncCompleted(id, …)`. Với `MEMBER_REMOVED` / `MEMBER_LEFT` /
`HOUSEHOLD_DISSOLVED`: lấy người nhận **trước** khi đặt `Left_at` (hoặc cộng người vừa ra). Nhà bị ảnh hưởng sau một lượt đẩy lấy từ hàng
đã ghi (`existing.idhousehold`), không chỉ từ payload (`sync.service.js:353-357`). App coi payload là hộp đen — chỉ đọc tên sự kiện.

### 56.9 (THẤP)

1. Trần ví chung (`household.Max_shared_wallets`, mặc định 10; `docs/Family/02A` mục 2 và 11) chưa thi hành: tạo ví mang `idhousehold` khi
   nhà đã đủ ví chung **đang hoạt động** (không lưu trữ, chưa xoá) ⇒ `HOUSEHOLD_WALLET_LIMIT`. Có thể để tới phần 2a.
2. Danh mục sao cho nhà (`household.service.js:90-103`) không chép `keyword` và `idgroup` — chép cả hai (ánh xạ id nhóm cha cũ → mới trong
   cùng giao tác).

### Kiểm lại mục 1

Mọi ca qua `syncService.processPush(idaccount, operations)`, payload dùng **đúng khoá app gửi** (chép từ
`src/Client-app/test/core/sync/sync_payload_contract_test.dart`). Dựng: nhà H (Owner A Premium, Member B, Viewer C), D ngoài nhà, ví chung W,
mục tiêu chung G, danh mục nhà K (A tạo), giao dịch T của B.

| # | Ca | Mong đợi |
|---|---|---|
| 1 | D sửa W | `HOUSEHOLD_NOT_MEMBER` |
| 2 | D tạo giao dịch mang `idhousehold = H` | `HOUSEHOLD_NOT_MEMBER` |
| 3 | C (Viewer) tạo giao dịch vào W | `HOUSEHOLD_READ_ONLY` |
| 4 | H `ReadOnly`, A tạo giao dịch | `HOUSEHOLD_READ_ONLY` |
| 5 | H đã giải tán, B (từng ở) sửa T | `HOUSEHOLD_CLOSED` |
| 6 | B tạo giao dịch riêng với `walletId = W` | `HOUSEHOLD_SCOPE_MISMATCH` |
| 7 | B tạo giao dịch riêng với `idgoal = G` | `HOUSEHOLD_SCOPE_MISMATCH` |
| 8 | B sửa T, payload `idhousehold: null` | `HOUSEHOLD_SCOPE_MISMATCH`, T giữ `Idhousehold = H` |
| 9 | B tạo ví chung / mục tiêu chung / ngân sách chung | `HOUSEHOLD_ROLE_FORBIDDEN` (3 ca) |
| 10 | B sửa giao dịch của A | `HOUSEHOLD_ROLE_FORBIDDEN` |
| 11 | B tạo `Transfer` giữa hai ví chung | `HOUSEHOLD_ROLE_FORBIDDEN` |
| 12 | B sửa danh mục K | `synced` (không `DB_ERROR`) |
| 13 | A sửa T của B | `synced`, `Idaccount` của T vẫn là B |
| 14 | Sửa danh mục mặc định hệ thống | `FORBIDDEN_SYSTEM_DEFAULT` |
| 15 | Basic `POST /api/households` | HTTP 403 `FEATURE_DISABLED` |
| 16 | Hạ cấp A rồi gia hạn | `Status` `ReadOnly` → `Active`; B nhận `household.changed` ở phòng `account_<B>` |
| 17 | B đẩy giao dịch vào W | A và C nhận `sync.completed` ở phòng tài khoản của mình |

```sql
SELECT account_type, feature_id, is_enabled, limit_value FROM account_type_permission
 WHERE feature_id IN ('household', 'household_members') ORDER BY 2, 1;              -- 4 dòng
SELECT "Idhousehold", "Owner_idaccount", "Status", "Delete_at" FROM household ORDER BY 1;
SELECT "Idhousehold", "Idaccount", "Role", "Left_at" FROM household_member ORDER BY 1, 2;
```

---

## 2. AIOps và trạng thái tài khoản (đơn 43)

Lịch sử: [`LICH-SU/SOAT_SAU_GOP_CD2EE572.md`](./LICH-SU/SOAT_SAU_GOP_CD2EE572.md).

### 43.A3 (CAO) — Trang AIOps mở khoá tài khoản admin khoá tay

Hai lối hết hạn cách ly đã truyền `{ onlyAIOpsLocked: true }` (`aiops.quarantine.js:141`, `:153`). Lối thứ ba thì chưa:
`getQuarantinedList()` (`:965`) — hàm **liệt kê** — tự mở khoá hàng hết hạn ở `:984` bằng `_syncAccountStatusToDatabase(…, 'Active', null)`
**không** kèm tuỳ chọn ⇒ tài khoản admin đặt `Inactive` vì lý do khác bị mở khi có người mở trang AIOps sau hạn. Phép lọc theo chữ của
`reason_inactive` (`:653`) còn nhận cả `reason_inactive: null`.

**Xin làm:** truyền `{ onlyAIOpsLocked: true }` ở `:984`; `reason_inactive` `null` **không** được coi là AIOps khoá.
**Kiểm lại:** admin khoá X với lý do riêng trong lúc X đang bị AIOps cách ly; hết hạn; gọi `GET` danh sách cách ly → X vẫn `Inactive`,
`Reason_inactive` vẫn là lý do của admin.

### 43.A5 (VỪA) — `ck_account_status`

Bảng `account` có **0** CHECK (đo 2026-10-28) — định nghĩa gốc ở `database/New_Database.sql:40` nhưng chưa tệp `database/N` nào áp. Giá trị hiện có: `Active` 8, `Deleted` 4 ⇒ áp thẳng được.
**Xin làm:** tệp `database/N_*.sql`:
```sql
ALTER TABLE "account" ADD CONSTRAINT "ck_account_status"
  CHECK ("Status" IN ('Active', 'Inactive', 'PendingDelete', 'Deleted'));
```
**Kiểm lại:** `SELECT conname FROM pg_constraint WHERE conrelid = '"account"'::regclass AND contype = 'c';` → có `ck_account_status`.

### 43.A6 (THẤP, tuỳ chọn)

AIOps khoá tài khoản nhưng không phát `account.force_logout` (`grep force_logout modules/aiops` → 0). Luồng admin khoá đã phát với `reason:
'ACCOUNT_INACTIVE'` — làm giống thì app hiện hộp thoại ngay thay vì chờ request kế.

---

## 3. PayOS (đơn 44)

Lịch sử: [`LICH-SU/SOAT_SAU_GOP_D72CCD45.md`](./LICH-SU/SOAT_SAU_GOP_D72CCD45.md).

### 44.B2 (VỪA) — Áp migration 38 (và 39)

Mã đã bắt trùng ở mọi đường ghi `payment_transaction` (`payment.repository.js:373`, `:430`), nhưng chỉ mục unique **chưa có** trên
Supabase: `database/38_add_unique_payos_transaction_id.sql` chưa áp (đo 2026-10-28: 0 chỉ mục chứa `payos_transaction_id`). Không có nhóm
trùng nào (0) ⇒ áp không vỡ. Cùng lượt `database/39_enforce_no_permanent_ip_ban.sql` cũng chưa áp (`aiops_ip_quarantine` 0 CHECK). ⚠️ 39
khác 38: nó chạy một `UPDATE` **đổi dữ liệu** trước khi thêm CHECK — mọi phong toả `PERMANENT` (hoặc trạng thái lạ) thành `TEMPORARY`
hạn 4 giờ. Đo Supabase 2026-10-28: 142 hàng, **tất cả `UNLOCKED`** ⇒ hôm nay không hàng nào bị đổi; chạy lại
`SELECT status, count(*) FROM aiops_ip_quarantine GROUP BY 1;` ngay trước khi áp, có hàng `PERMANENT` thì để AIOps / PO quyết trước.

**Xin làm:** áp 38 và 39 lên Supabase (và mọi CSDL đang chạy backend), ghi sổ tệp đã áp.
**Kiểm lại:**
```sql
SELECT indexname FROM pg_indexes WHERE tablename = 'payment_transaction' AND indexname = 'uq_payment_transaction_payos_id';   -- 1 dòng
SELECT conname FROM pg_constraint WHERE conrelid = 'aiops_ip_quarantine'::regclass AND contype = 'c';                       -- 2 dòng
```

---

## 4. Mã hoá dữ liệu — giải mã hỏng (đơn 52)

Lịch sử: [`LICH-SU/GIAI_MA_HONG_TRA_BAN_MA.md`](./LICH-SU/GIAI_MA_HONG_TRA_BAN_MA.md). Vế CAO (không trả bản mã cho app) đã đạt.

| Mã | Việc |
|---|---|
| 52.1 | Log giải mã hỏng thiếu **tên bảng + khoá chính** của hàng — thêm để dọn được. |
| 52.2 | Hai chỗ còn nuốt lỗi giải mã: `maskTransactionDescription` (`utils/masking.util.js:155-169` — bản mã đi vào prompt Gemini qua `tools.executor.js`) và `ai/features/dedup/dedup.repository.js:11-17`. Lỗi giải mã phải đi ra như lỗi, không dùng bản mã làm chữ. |
| 52.3 | Khoá của CSDL dev `PersonFinance`: chọn một và ghi vào tài liệu chạy backend — (a) chạy với `DATA_ENCRYPTION_KEY` = khoá dev mặc định của `crypto.util.js`, hoặc (b) script mã hoá lại `PersonFinance` sang khoá `.env` (đọc khoá cũ, ghi khoá mới, mỗi bảng một giao tác). |
| 52.4 | Production: xác nhận `DATA_ENCRYPTION_KEY` trên Render đúng khoá đã mã hoá dữ liệu Supabase — script đếm hàng giải hỏng trả 0. |
| 52.5 | Hàng đã lưu sẵn chuỗi `enc:…` hỏng **trước** bản sửa `encrypt()` — đếm và dọn (script ở 52.4 cho ra danh sách). |

**Kiểm lại:** script chỉ đọc (từ `src/Backend`) duyệt các cột đã mã hoá (`transaction."Note"`, `bill."Note"`, `user.phone`,
`user.address`, …), đếm `isEncrypted(x) && decrypt ném lỗi` → **0** trên Supabase với khoá Render; trên `PersonFinance` = 0 sau 52.3.

---

## 5. Phân quyền theo gói — hợp đồng `/payment/subscription-info` (đơn 55 vế A)

Lịch sử + bối cảnh: [`LICH-SU/PHAN_QUYEN_THEO_GOI_HOP_DONG_VA_TAI_LIEU.md`](./LICH-SU/PHAN_QUYEN_THEO_GOI_HOP_DONG_VA_TAI_LIEU.md). App
**đã thi công** phần của mình (2026-10-28, B1): đọc 22 công tắc + 5 trần cho cả gói Premium; đọc `premiumFeatures` / `premiumLimits` khi
có, vắng thì như trước — chỉ chờ backend.

**55.A1 — Gửi cột Premium cho tài khoản đang Basic.** Người Basic chỉ thấy bảng Basic; admin tắt *"Xuất báo cáo"* ở **cả hai** cột thì app
vẫn mời *"Cần Premium — Nâng cấp"* và người dùng trả tiền xong vẫn bị khoá. Khi `effectiveType === 'Basic'`, thêm vào `data` của
`getSubscriptionInfo` (`payment.service.js`):

```json
"premiumFeatures": { "ai_assistant": true, "export_reports": true, "...": true },
"premiumLimits":   { "wallets": null, "budgets": null, "goals": null, "bills": null, "custom_categories": null }
```

Cùng cách dựng với `features` / `limits` (gọi `getPermissionsByAccountType('Premium')`). Đang Premium thì không cần.

**55.A2 — Trụ 1 (bật / tắt) của 5 mã LIMIT mất trên đường đi.** Admin-web cho bật / tắt ở mọi hàng, nhưng `permission.repository.js:127-128`
đưa hàng LIMIT **chỉ** vào `limits` với `limit_value` ⇒ `is_enabled = false` của `wallets` / `budgets` / `goals` / `bills` /
`custom_categories` không tới app, server cũng không thi hành. **Xin:** hàng LIMIT `is_enabled = false` → `limits[mã] = 0` (và
`premiumLimits[mã] = 0`). App đọc 0 = không tạo thêm.

**55.A3 — Premium không có `premium_expires_at` mang ba nghĩa.** `getSubscriptionInfo` coi là **Basic**; `requireFeature`
(`feature-permission.middleware.js:32-35`) coi là **Premium**; app coi là Premium còn hạn. **Xin:** chốt một nghĩa (đề nghị: mọi đường nâng
Premium đều ghi hạn; hàng không hạn là dữ liệu hỏng → Basic ở cả hai chỗ server) và ghi vào hợp đồng. App đổi theo sau khi có trả lời.

**Kiểm lại:** tài khoản Basic → `GET /api/payment/subscription-info` có `premiumFeatures` (31 khoá) + `premiumLimits` (5 khoá); tắt Trụ 1
`wallets` cột Basic → `limits.wallets === 0`; tài khoản Premium → không có hai khoá mới.

---

## 6. Script test ghi vào dữ liệu thật (đơn 48)

Lịch sử: [`LICH-SU/DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md`](./LICH-SU/DU_LIEU_TEST_TRONG_TAI_KHOAN_THAT.md). Đã đạt: không còn chọn admin,
ví UUID ngẫu nhiên, dọn trong `finally`.

- **48.2 (VỪA)** — `Test/test_data_security_encryption_and_masking.js:236-238` chọn **người dùng thật** đầu tiên có `idrole: 2` (không thấy →
  cứng `18`) rồi ghi ví + giao dịch test vào đó. `finally` không đủ: lượt hỏng giữa chừng hay hai lượt song song vẫn đụng dữ liệu thật,
  và đồng bộ của người ấy có thể kéo hàng test về máy trước khi bị xoá mềm. **Xin:** script tự tạo **tài khoản test riêng** (tên cố định
  hoặc `…_${timestamp}`), dọn bằng **xoá mềm** (`Delete_at` + `Status`, giao dịch `Deleted_at`) — đừng chép khối `finally` xoá cứng của
  `Test/test_user_soft_delete_and_auth_rules.js:270-279` (vấp trigger `protect_transaction_hard_delete`).
- **48.3 (THẤP)** — cùng khuôn: `Test/test_sync_new_schema.js:21`, `Test/test_can_lam_fixes.js:44` ghi vào tài khoản có sẵn; ba script
  `Test/test_ai_dedup_flow.js`, `test_ai_ocr_full_flow.js`, `test_bank_sepay_flow.js` ghi cứng `idaccount: 18` (client chưa kiểm chúng có
  ghi CSDL không). Chuyển sang tài khoản test riêng như 48.2.
- **48.1 (THẤP)** — ghi vào ô trả lời: ai đã dọn dữ liệu test của tài khoản 18, trên CSDL nào, lúc nào.

**Kiểm lại:** chạy script hai lần rồi:
```sql
SELECT count(*) FROM wallet w JOIN account a ON a."Idaccount" = w."Idaccount"
 WHERE w."Create_at" > '<giờ chạy>' AND a."Create_at" < '<giờ chạy>' AND w."Name" = 'Ví Test Note';            -- 0
```

---

## 7. Migration và máy dev (đơn 49)

Lịch sử: [`LICH-SU/SOAT_SAU_GOP_EE6A65E5.md`](./LICH-SU/SOAT_SAU_GOP_EE6A65E5.md).

### 49.D (VỪA) — Bẫy thứ tự `npm install` / migration

`package.json` có `"postinstall": "prisma generate"`; `modules/auth/auth.repository.js` dùng `include` không `select` (`:28`, `:39`, `:50`,
`:64`) nên Prisma đọc **mọi** cột của `account`. Máy có `schema.prisma` mới hơn CSDL (cột chưa áp) ⇒ `npm install` xong là đăng nhập /
đăng ký / đặt lại mật khẩu vỡ `P2022`. Cùng loại bẫy với migration 40 hôm nay: `schema.prisma` thêm `idhousehold` cho 5 model — máy chưa
áp `database/40` mà `prisma generate` thì mọi truy vấn 5 bảng ấy vỡ `P2022`.
**Xin:** ghi vào chỗ hướng dẫn dựng máy dev: *"sau khi kéo mã: áp các `database/N` mới **trước**, rồi mới `npm install` / `prisma
generate`"*; hoặc cho `auth.repository.js` `select` tường minh như `middleware/auth.js:22`.

### 49.F (VỪA) — Migration 33 xoá cứng; hàng mồ côi còn trên Supabase

Tệp 33 (dòng 13–38) xoá cứng `refreshtoken`, `otp_code`, `audit_log`, `user`, `account` của tài khoản thử dưới
`session_replication_role = 'replica'` (tắt trigger + khoá ngoại) ⇒ bảng con thành mồ côi. Đo Supabase 2026-10-28: **10 ví, 13 giao dịch,
1 danh mục** trỏ tới tài khoản không còn (tài khoản 2, 42–46, 53, 61, 68 — lượt đo 2026-10-26).
**Xin:** (1) đổi tệp 33 sang xoá mềm (`Status = 'Deleted'`, `Delete_at`) cho các CSDL chưa áp; (2) xử lý hàng mồ côi đang có trên Supabase
bằng **xoá mềm** (`Delete_at` / `Deleted_at`), không xoá cứng.
**Kiểm lại:**
```sql
SELECT count(*) FROM wallet w LEFT JOIN account a ON a."Idaccount" = w."Idaccount"
 WHERE a."Idaccount" IS NULL AND w."Delete_at" IS NULL;                                                         -- 0
```

---

## 8. Tài liệu backend cần sửa — gom theo tệp

Các tệp dưới là tài liệu **của backend** (client không sửa). Chỗ nói về app: đối chiếu `src/Client-app/test/core/sync/sync_payload_contract_test.dart`
và mã `src/Client-app/lib/`, đừng suy luận; tính năng chưa có thì ghi *"kế hoạch"*, đừng đánh `[x]` / *"100%"*.

### 8.1 (T1) — `docs/Admin-web/Event-Notification-to-ClientApp.md` (627 dòng; gộp 43.D + 44.F + 49.H1)

Số dòng đo trên bản hiện tại (2026-10-28; tệp không đổi từ `49eafef6`).

| Dòng | Tài liệu nói | Mã thật | Mức |
|---|---|---|---|
| 498–499, 517, 536 | Body 401 / 403 lồng `code` trong `"data": {…}`, có `statusCode` | `code` (+ `idaccount`, `reason_inactive` / `featureId`, `accountType`) ở **cấp gốc**, không `statusCode` (`core/response-handler.js` `unauthorized` / `forbidden` trải `...extra`; `feature-permission.middleware.js:47-55`) | **cao** |
| 584–604 (*"BỎ SÓT"* 584, 585, 587, 588, 599–603; *"BÁN PHẦN"* 604) | App bỏ sót `account.downgraded`, 503 bảo trì, 403 `AIOPS_QUARANTINED`, 403 `FEATURE_DISABLED` | App xử lý cả bốn từ 2026-10-20: làm mới gói khi `account.downgraded`, dòng nhắc + hẹn thử theo `Retry-After`, đăng xuất / báo khi bị từ chối (`realtime_event.dart`, `trang_thai_may_chu.dart`, `may_chu_interceptor.dart`) | vừa |
| 101, 434, 584, 599, 622 | App phải mở `MaintenanceScreen` và dừng đồng bộ nền khi bảo trì | App **cố ý** dùng dòng nhắc + hẹn thử theo `Retry-After`, không màn chặn | vừa |
| 77, 136, 584, 617 | `system.maintenance_changed` app bỏ sót | App **cố ý** không nghe (payload hộp đen) | vừa |
| 51 | Socket *"tuyệt đối không"* gửi số tài khoản ngân hàng đầy đủ | `ocr.completed` chuyển nguyên `data` có `transfer_details.source_account` / `destination_account` — **sửa mã (che số) hoặc sửa câu** | vừa (bảo mật) |
| 49 | Nguyên tắc *"Zero-Guesswork"* — app đọc mọi trường payload | App đọc payload như **hộp đen** (chỉ tên sự kiện), ngoại lệ `account.force_logout` và `system.broadcast` | thấp |
| 172 (§4.2) | Hết bảo trì `reason: null` | Mã có thêm `scheduled` / `scheduledList`, tắt không xoá `reason`; sự kiện còn phát khi tạo / huỷ lịch với `active=false` (`maintenance.manager.js`) | vừa |
| 217–218 (§4.4) | Khoá `idaccount_type` / `idfeature` | `account_type` / `feature_id` (`admin.service.js` cập nhật ma trận) | vừa |
| 236–243 (§4.5) | Một hình dạng payload `{type, message, expiresAt}` | `account.upgraded` gửi `{ type, premiumExpiresAt }` (`payment.service.js` `:346`, `:438`, `:722`); ma trận đổi gửi `{ reason: 'PERMISSIONS_MATRIX_UPDATED', updates }` tới **mọi** client (`core/socket.js`) | vừa |
| 281 (§4.7) | `summary: { created, updated, deleted }` | `total / synced / conflicts / errors` (`sync.service.js` `processPush`) | vừa |
| 287 | `sync.completed` chỉ khi máy khác đẩy; app gọi `processPull()` | Phát tới **mọi máy của tài khoản vừa đẩy**, kể cả chính máy ấy (`sync.service.js:346` → `notification.service.js:139-145` → `core/socket.js:216-224`, phòng `account_<id>`); app gọi `syncNow()` (đẩy rồi kéo), im lặng | thấp |
| 302 (§4.8) | OCR mang `metadata` | Mã gửi `data` + `createdAt` (`notification.service.js:98-104`) | thấp |
| 86, 319 (§4.9) | `user.notification` là sự kiện sống | `notifyUser` không còn chỗ gọi (ngoài test) | thấp |
| 87–89, 339–367, 592–594 | `payment.success` do webhook; `order_expired` do worker; huỷ đơn → `order_cancelled` | Webhook phát `account.upgraded` (`payment.service.js:346`, `:438`); ba sự kiện ấy tới phòng tài khoản chỉ phát từ đường đồng bộ JIT (`:610` `order_cancelled`, `:646` `order_expired`, `:717` `success`); tác vụ hết hạn đơn chỉ phát `payment.order_expired` tới `admin_room` (`:940`) | vừa |
| 91 | Đơn chờ xác nhận → *"mở hỗ trợ CSKH"* | App mở màn Chi tiết đơn, người dùng chọn qua `POST /api/payment/confirm-upgrade` | vừa |
| 386–392 (§4.12) | `payment.refunded` mang `orderCode`, `timestamp` | Mã gửi `orderId`, `refundedAmount`, `refundedAt`, `refundReason`, `refundProof` (`payment.service.js:506-509`) | vừa |
| 406 (§4.13) | `receivedAmount` | `amountReceived` + `excessAmount` (`payment.service.js:227-232`) / `shortage` + `fee` (`:270-275`) | vừa |
| *(thiếu)* | Không có `POST /api/payment/confirm-upgrade { orderCode, accept }`, ba trạng thái đơn `WAITING_CONFIRMATION` · `REFUND_PENDING` · `REFUNDED`, sự kiện `payment.overpaid_confirmation` / `payment.underpaid_warning`, hạn đơn **10 phút** (`grep confirm-upgrade` → 0) | Thêm vào | vừa |
| 102, 439 (§5.2) | Ngưỡng lag event loop 100 ms | 250 ms (`event-loop-monitor.js:9`) | thấp |
| §1 | (không nhắc) | Một sự kiện có thể tới **hai lần** qua Redis (`event-bus.js:25`) — app đã chịu được, ghi vào hợp đồng | thấp |

**Kiểm lại:** `grep -n '"data": {\|MaintenanceScreen\|receivedAmount\|idaccount_type\|BỎ SÓT' docs/Admin-web/Event-Notification-to-ClientApp.md`
→ không còn câu tả sai; `grep -c "confirm-upgrade"` ≥ 1.

### 8.2 (T2) — `docs/Admin-web/IP-Device-ClientApp.md` + `04-user-management-and-lifecycle.md` (49.E + 49.H3)

CORS `x-device-name` đã đạt. Còn:

| Tệp:dòng | Tài liệu nói | Thực tế | Mức |
|---|---|---|---|
| `IP-Device…:42–44`, `:325`, `:372`, `:346`, `:384`; `04-user…:125`, `:156` | Admin có tab *Lịch sử thiết bị & IP*, màn `/admin/security/device-history`, hai route `GET /api/admin/accounts/:idaccount/devices`, `GET /api/admin/devices/recent-access`, huy hiệu *"đang hoạt động"* | Không route, không màn (`src/Admin-web/src/router/routes.jsx`); `getDeviceHistory` không chỗ gọi ngoài test — bảng `account_device_history` hiện **chỉ được ghi**. Làm route + màn, hoặc ghi *"kế hoạch"* | vừa |
| `IP-Device…:383–392` | Mọi test `[x]` | Test 1.1–1.3 (Admin) chưa có gì để chạy; *"tầng CSDL thực"* dùng Prisma giả | vừa |
| `IP-Device…:194`, `:259`, `:281`, `:285–299` | App đặt tệp `lib/core/services/`, `dio.post('/api/auth/login')` trong `AuthRepository`, gắn interceptor | App gửi `x-device-name` **chỉ bản Android**, giá trị *"Hãng Model (Android N)"* qua kênh Kotlin `flowmoney/thiet_bi` (không `device_info_plus`), gắn ở cả Dio chung lẫn Dio `/auth/refresh`, cả engine nền | vừa |
| `IP-Device…:222–231` | Lấy tên máy bằng `iosInfo.name` / `computerName` | Đó là tên **người dùng đặt** (dữ liệu cá nhân) — trái §2.3 của chính tài liệu | vừa |
| `IP-Device…:89`, `:152`, `:82`, `:54`, `:135`, `:163–165` | IPv6 giữ 3 nhóm; dự phòng *"Unknown Mobile Device"*; chỉ đăng nhập bỏ throttle; `first_seen_at`; đoạn lấy IP | Giữ 2 nhóm (`utils/masking.util.js`); `'Unknown Device'`; đăng ký / OTP cũng bỏ throttle; lấy `X-Forwarded-For[0]` trước `req.ip` | thấp |
| `04-user…:143` | App gắn `x-device-name` trên mọi request | Chỉ bản Android; web / iOS không gửi | thấp |

### 8.3 (T3) — `docs/Functional-Mobile/4_TRU_COT.md` (đơn 55 vế B)

Đối chiếu từng khẳng định về **app** với `src/Client-app/lib` (2026-10-27): 67 khẳng định — 18 đúng, 16 đúng một phần, **31 sai** (27 về
app, 4 về backend). Gốc chung: app chỉ đọc `accountType`, `premiumExpiresAt`, `features` (22 mã) và `limits` (5 trần); **không** đọc
`scopes` / `scope_config` lẫn `policies` / `downgrade_policy` — Trụ 3 và Trụ 4 chưa có hiệu lực ở app. Số dòng của `4_TRU_COT.md` HEAD
(tệp không đổi từ 2026-10-19).

**Sai về app** (xếp theo mức hại):

| Dòng | Tài liệu nói | Mã thật (`src/Client-app/lib/…`) |
|---|---|---|
| 598 | Chống tua lùi giờ bằng `max(date_transaction)` | **Không có** — hết hạn so `DateTime.now()` với hạn lưu trên máy (`premium/data/models/trang_thai_goi.dart:39-40`) |
| 65-67 | `GRACE_PERIOD_3D` — tự trả / tự trích chạy thêm 3 ngày | Hết hạn là **dừng ngay**, giữ công tắc (`premium/data/co_quyen_nen.dart:12-16`); nhắc gia hạn chỉ là dòng Trang chủ 0–3 ngày **trước** hạn |
| 62-64 | `READ_ONLY`: vẫn xem dự báo cũ | Basic: cả khối *Dự báo 30 ngày tới* thay bằng thẻ khoá; dự báo tính tại chỗ, không lưu |
| 44, 45, 68-70, 535 | Trụ 3 `scope_config` / Trụ 4 `downgrade_policy` do app thi hành | App **không đọc** (grep = 0); đồng bộ cố định 2 s mọi gói (`core/sync/sync_engine.dart:91`) |
| 191-193 (#9) | 1 / 5 ảnh mỗi giao dịch; tìm kiếm 90 ngày | Không đính ảnh vào giao dịch; Sổ giao dịch xem mọi kỳ |
| 201-203, 195-204 (#10) | `daily_voice_quota`, 30 s; **Whisper** | Không hạn mức lượt; giọng nói = `speech_to_text` Android, dự phòng Gemma |
| 206-215 (#11) | OCR 15 lượt / tháng, `max_file_mb`, `auto_crop` | ML Kit; không đếm lượt, không cắt tự động |
| 217-226 (#12) | Gắn danh mục hàng loạt tối đa 20 / 100 | Không trần |
| 250-252 (#14) | `max_depth`, `custom_icons`, `custom_colors` theo gói | Không xét gói |
| 255-264 (#15) | 5 / 25 từ khoá mỗi danh mục | Không trần |
| 271-280 (#16), 309-318 (#19) | Chu kỳ ngân sách / hoá đơn Basic chỉ `MONTHLY` | Mọi gói chọn Tuần / Tháng / Quý / Năm |
| 293-302 (#18) | `alert_threshold` 0,8; `daily_burn_rate` chỉ Premium | Ngưỡng theo từng ngân sách; *"Nên chi X/ngày"* mọi gói |
| 326-328 (#20) | `retry_on_fail: 3` | Không thử lại 3 lần (có *"trả bù trần 3 kỳ"* — khái niệm khác) |
| 331-340 (#21) | Basic nhắc [1] ngày, Premium [1, 3, 7] | Mọi gói 1 · 3 · 5 · 7, đổi được giờ (B1 2026-10-28: Premium có thể tắt bằng ma trận) |
| 347-356 (#22) | Cột mốc con, ưu tiên chỉ Premium | Cột mốc 25 / 50 / 75 % và kéo thả ưu tiên mọi gói |
| 391-393 (#25) | PDF / **EXCEL** / CSV, watermark cho Basic | Chỉ PDF + CSV; Basic bị chặn hẳn |
| 396-405 (#26) | Màn sức khoẻ tài chính (FHS) | App **không có** |
| 92-101 (#2) | Đăng nhập ngoại tuyến, `cache_token_days: 30` | Không có; mở lạnh dùng phiên đã lưu rồi `verifySession()` |
| 119-128 (#4), 130-139 (#5) | Tổng tài sản 30 ngày / toàn thời gian; 4 / 8 phím tắt | Không giới hạn theo gói; hàng nút nhanh cố định |
| 152-154 (#6) | Basic Cash / Bank / **EWallet**, Premium **Credit / Investment** | Chỉ `cash · bank · saving` mọi gói; CSDL `chk_wallet_type` chỉ Cash / Bank / Saving / Banking |
| 445-454 (#30) | `whisper-tiny`, `finance-slm` | Gemma 4 E2B `.litertlm` |
| 456-465 (#31) | `max_storage_mb` 500 / 2000 | Không trần; mô hình ~2,4 GB |
| 472-481 (#32) | Ngân hàng Basic VCB / MB / TCB / ACB | Danh sách trắng đo trên máy thật: **MB Bank · MoMo · ZaloPay**, không theo gói |
| 483-492 (#33) | Basic 1 khung giờ nhắc ghi chép, Premium 3 | Một giờ nhắc, mặc định tắt |
| 499-508 (#34) | Đếm ngược **15** phút | **10** phút (cả app lẫn `payment.repository.js`) |
| 510-519 (#35) | Tải hoá đơn (Premium) | Không có; chỉ *"Lưu mã QR"* |
| 526-535 (#36) | Debounce 10 s / 2 s, sao lưu ảnh, `realtime_priority` | 2 s mọi gói; không sao lưu ảnh; Socket.IO mọi tài khoản |
| 588 | Route chặn `/ai-assistant` | Màn là `/ai-chat`, khoá trong trang |
| 590-591 | Nút độc quyền mở **BottomSheet** giới thiệu Premium | Thẻ khoá điều hướng sang `/premium?quyen=…` |

**Sai về backend:**

| Dòng | Tài liệu nói | Mã thật (`src/Backend/…`) |
|---|---|---|
| 42, 610-619 | 403 `{error: "FEATURE_PERMISSION_DENIED", code: "FEATURE_LOCKED", …}` | `{ code: 'FEATURE_DISABLED', featureId, accountType }` (`feature-permission.middleware.js`); app chỉ bắt `FEATURE_DISABLED` |
| 607-608 | `requireFeature` bắt buộc cho mọi endpoint CRUD | Chỉ ở `chatbot.routes.js` và `ocr.routes.js`; lỗi bất kỳ → cho qua; trần 3 / 3 / 3 / 3 / 5 **chỉ** app thi hành |
| 42, 45, 66 | `downgrade_policy` được áp khi hạ cấp | Chỉ lưu / đọc / trả; job hạ cấp `scheduler.service.js` không xét |
| (seed `database/32`) | `scope_config` ngoài miền app | `allowed_types` EWallet / Credit / Investment; `supported_banks` VCB / TCB / ACB; `models` whisper / finance-slm; `formats` EXCEL |

**Gợi ý viết lại:** mỗi tính năng tách *"Server lưu / trả"* và *"App thi hành hiện nay"* (chỉ ghi điều mã app làm); Trụ 3 / 4 chưa thi hành
thì ghi *"chưa có hiệu lực ở app"*. **Kiểm lại:**
`grep -n "FEATURE_LOCKED\|max(date_transaction)\|GRACE_PERIOD_3D\|Whisper\|VCB" docs/Functional-Mobile/4_TRU_COT.md` → không còn câu tả
app làm những việc ấy.

### 8.4 (T4) — Tên migration cũ (49.C)

Tệp nay là `database/27b_create_aiops_metric_snapshot_table.sql`, nhưng `docs/Admin-web/09-aiops-sentinel-and-quarantine.md:8` và
`docs/AIOps/AIOPS_SENTINEL_REFINEMENT_PLAN.md:55` vẫn ghi `27_create_aiops_metric_snapshot_table.sql`; dòng 2 của chính tệp `27b` vẫn ghi
*"Migration 27"*. **Kiểm lại:** `grep -rn "27_create_aiops_metric" docs src/Backend/database` → 0.

### 8.5 (T5) — Quy ước tài liệu client (49.A)

`docs/superpowers/sync/SYNC_DOCUMENTATION.md` là tài liệu **của client** và từng bị viết đè ba lần (`6cbd248e`, `36f1ea43`, `bc4e4f7f`).
Client đã gộp hai tài liệu đồng bộ vào tệp ấy (`docs/Admin-web/Sync-To-ClientApp.md` nay chỉ trỏ về) và mở **mục 14 *Trao đổi*** để backend
ghi. **Xin:** xác nhận trong ô trả lời — muốn sửa thì ghi ở mục 14 hoặc đặt đơn, không viết đè.

---

## 9. Đã xong — không làm lại

| Đơn | Vế đạt |
|---|---|
| 43 | A1 (AIOps ghi `'Inactive'`, bỏ `updateMany`), A2 (`accountRejection` mặc định `ACCOUNT_INACTIVE`), A3 hai lối hết hạn, A4, B (webhook đơn lạ trả 2xx), C (503 bảo trì có `code`) |
| 44 | A (đánh số lại), B1 (chỉ xử lý webhook `PENDING` / `EXPIRED`, ghi đối soát), C (lọc `PENDING`), D, E; mọi đường ghi bắt `P2002` |
| 48 | Không chọn admin; ví UUID; dọn trong `finally`; việc 1 bước 1 (dọn ví `test-wallet-…` trên Supabase) |
| 49 | B (không còn bảo app xoá SQLite), C phần tệp (`27b`, xoá `)2_can_lam…`), E phần CORS, G (qua đơn 53), H2 (gộp vào tài liệu đồng bộ của client), H4 phần chính |
| 50 | `NOT_OWNER` cho hàng riêng tư (6 thực thể, nhánh tạo ép `idaccount`), migration 40 trên Supabase, phạm vi kéo về, 16 endpoint, trần thành viên khi mời / vào, sao khuôn danh mục |
| 52 | `decrypt()` ném `DECRYPT_FAILED` (không trả bản mã), `encrypt()` mã hoá chuỗi `enc:…` người dùng gõ, kiểm độ dài IV / tag, 500 ở `auth` có `code` |
| 53, 54 | Đạt trọn — ở `../DA-XONG/` |

---

## 10. Trả lời (backend ghi vào đây)

| Mã | Đã làm (commit, tệp) | Ca test / câu kiểm | Ghi chú |
|---|---|---|---|
| 56.1 | | | |
| 56.2 | | | |
| 56.3 | | | |
| 56.4 | | | |
| 56.5 | | | |
| 56.6 | | | |
| 56.7 | | | |
| 56.8 | | | |
| 56.9 | | | |
| 43.A3 | | | |
| 43.A5 | | | |
| 43.A6 | | | |
| 44.B2 | | | |
| 52.1 – 52.2 (sửa mã) | | | |
| 52.3 – 52.5 (khoá, dọn dữ liệu) | | | |
| 55.A1 – 55.A3 | | | |
| 48.1 – 48.3 | | | |
| 49.D | | | |
| 49.F | | | |
| T1 | | | |
| T2 | | | |
| T3 | | | |
| T4 | | | |
| T5 | | | |
