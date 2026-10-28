# Mục 56 — Gia đình phần 1: các chốt chặn ghi vào nhà chưa chạy (soát sau gộp `main` @ `7b56d822`)

> 🗂️ **2026-10-28 — đơn 56 đã gộp vào [`../VIEC_BACKEND_CON_LAI.md`](../VIEC_BACKEND_CON_LAI.md), mục 1 (`56.1` – `56.9`).**
> Tệp này nay chỉ là **lịch sử** (lý do, số đo, các lượt soát cũ): không cập nhật nữa, đừng ghi trả lời vào đây — việc còn lại và
> bảng trả lời ở tệp gộp. Số dòng mã / tài liệu trong tệp này là ảnh chụp lúc viết.

> **Client đặt 2026-10-28** (phiên 20). Người nhận: backend (NPBao). Mức: **CAO** — chặn client bắt đầu tính năng gia đình.
> **Hiện chưa ai bị ảnh hưởng:** Supabase có 0 nhà, 0 hàng mang `Idhousehold`, và app chưa gửi `idhousehold`. Nhưng khi client mở
> tính năng thì mọi lỗi dưới đây chạy thật — nên xin sửa **trước** khi client làm lát 1.
>
> Client soát bằng đọc mã (backend ở `177dd0e1`, PR #168; client gộp `a630c4c8`) + truy vấn **chỉ đọc** trên CSDL Supabase của `.env`.
> Chưa gọi thử API. Mỗi việc có tệp:dòng, cách sửa đề xuất và cách kiểm lại.
>
> **Quan hệ với đơn 50** ([`GIA_DINH_NEN_MONG.md`](./GIA_DINH_NEN_MONG.md)): đơn này **không đổi đặc tả**. Đặc tả đúng đã nằm sẵn trong đơn
> 50 do chính backend viết — bảng quyền + thứ tự mã lỗi ở **Việc D, phần *2. Nhánh Đẩy lên***, gói + `ReadOnly` ở **Việc E**, socket
> ở **Việc F** (mục 2 của đơn 50); nguồn gốc `docs/Family/01_NEN_MONG.md` mục 3. Đơn này chỉ chỉ ra **chỗ mã lệch đặc tả ấy**. Xong đơn này thì
> đóng luôn đơn 50.
>
> **Đã đạt, không cần làm lại:** `NOT_OWNER` cho hàng riêng tư ở cả 6 thực thể; nhánh tạo ép `idaccount` theo token
> (`sync.service.js:156-167`); phạm vi `/sync/pull`; migration 40 trên Supabase; trần thành viên khi mời / vào nhà
> (`household.service.js:179`, `:312`, `:494`); sao khuôn danh mục khi tạo nhà.

---

## Tóm tắt — 9 việc

| # | Việc | Mức | Tệp chính |
|---|---|---|---|
| 1 | `findMember` không tồn tại → vai và `ReadOnly` không bao giờ được xét khi đẩy | **CAO** | `sync.service.js:195-217`, `household.repository.js` |
| 2 | Thi hành đúng bảng quyền + thứ tự mã của đơn 50 D.2 (người ngoài nhà, nhà giải tán, Viewer, mục tiêu chung, danh mục nhà, chuyển khoản) | **CAO** | `sync.service.js:69-95`, `:180-217` |
| 3 | Không cho đổi `Idhousehold` của hàng đã có qua `/sync/push` | **CAO** | `sync.repository.js` 5 hàm `upsert*` |
| 4 | Basic tạo được nhà — phép kiểm Premium không bao giờ chạy; ma trận gói không có khoá `household` | **CAO** | `household.controller.js:27`, `households.routes.js:10`, `database/41` mới |
| 5 | Từ chối quyền bằng `Error` trơn → `DB_ERROR` → client gửi lại **mãi** | **CAO** | `sync.repository.js:253-258`, `sync.service.js:267`, `:327` |
| 6 | Kiểm phạm vi đọc sai khoá → không bao giờ chạy với giao dịch của client | VỪA | `sync.service.js:100-115`, `:184` |
| 7 | Chủ nhà hết / gia hạn Premium không đổi trạng thái nhà | VỪA | `scheduler.service.js:295`, `payment.repository.js:392`, `household.service.js:375` |
| 8 | `household.changed` / `sync.completed` phát vào phòng không ai ở | VỪA | `household.service.js:650-665`, `sync.service.js:348-370`, `core/socket.js:61-79` |
| 9 | Trần ví chung không thi hành; danh mục sao cho nhà thiếu từ khoá | THẤP | `household.service.js:75-107` |

Ca test cho mọi việc: xem mục **Kiểm lại** cuối đơn — **phải đi qua `syncService.processPush`**, không gọi thẳng hàm con.

---

## Việc 1 (CAO) — `householdRepository.findMember` không tồn tại

**Hiện trạng.** `sync.service.js:200`:

```js
const membership = await householdRepository.findMember(targetHhId, idaccount);   // ← hàm không có
const house = membership?.household || await householdRepository.findHouseholdById(targetHhId);
userRole = membership?.role || null;
householdStatus = house?.status || 'Active';
} catch {
  // Fallback
}
```

`household.repository.js` chỉ có `findHouseholdById` (`:27`) và `findActiveMemberByAccount` (`:36`); `grep -rn "findMember\b"` trên toàn
`src/Backend` (trừ `node_modules`) ra **1 dòng** — chính lời gọi trên. `TypeError` bị `catch {}` nuốt ⇒ `userRole = null`,
`householdStatus = 'Active'` ⇒ `enforceHouseholdPermission` không bao giờ ném. Hệ quả: **không bao giờ** có `HOUSEHOLD_ROLE_FORBIDDEN`
hay `HOUSEHOLD_READ_ONLY` từ `/sync/push`.

Vì sao test không bắt: các ca 3–6 của `household.system_impact.test.js` (`:105-173`) gọi thẳng
`syncService.enforceHouseholdPermission({ userRole: 'Member', … })` — truyền sẵn vai, nên không đi qua dòng tra thành viên.

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

2. Tra nhà **không lọc `delete_at`** (việc 2 cần biết nhà đã `Dissolved`): `findHouseholdById` (`:27-34`) lọc `delete_at: null`, mà giải tán
   ghi cả `delete_at` lẫn `Status = 'Dissolved'` (`household.repository.js:231-249`) — nên nhà đã giải tán tra ra `null` và rơi về `'Active'`.
   Thêm một hàm tra theo khoá chính không lọc, dùng riêng cho phép kiểm này.
3. **Bỏ `catch {}` nuốt lỗi.** Tra thành viên lỗi (CSDL chập chờn) thì để lỗi đi ra như lỗi thường của thao tác — client gửi lại ở chu kỳ
   sau — chứ **không** cho qua. Hiện tại lỗi = cho ghi.

---

## Việc 2 (CAO) — Thi hành đúng bảng quyền và thứ tự mã của đơn 50 D.2

**Đặc tả (đơn 50, Việc D phần *2. Nhánh Đẩy lên*, nguyên văn ý):**

| Hàng của nhà | Tạo | Sửa | Xoá |
|---|---|---|---|
| `wallet` | Owner | Owner | Owner |
| `goal` | Owner | Owner | Owner |
| `budget` | Owner | Owner | Owner |
| `category` | Owner, Member | Owner, Member | Owner, Member |
| `transaction` thu / chi | Owner, Member | người ghi hoặc Owner | người ghi hoặc Owner |
| `transaction` `Transfer` (giữa hai ví chung) | Owner | Owner | Owner |
| `transaction` có `Idfund_pair` | *(phần 2a — chưa có cột, chưa làm)* | | |

Thứ tự kiểm: (1) không là thành viên đang ở ⇒ `HOUSEHOLD_NOT_MEMBER` · (2) nhà `Dissolved` ⇒ `HOUSEHOLD_CLOSED` · (3) vai `Viewer` **hoặc**
nhà `ReadOnly` ⇒ `HOUSEHOLD_READ_ONLY` · (4) tham chiếu sai phạm vi ⇒ `HOUSEHOLD_SCOPE_MISMATCH` · (5) không khớp bảng ⇒
`HOUSEHOLD_ROLE_FORBIDDEN`.

**Mã hiện tại lệch ở 7 chỗ** (`enforceHouseholdPermission`, `sync.service.js:69-95`, và chỗ gọi `:180-217`):

| # | Đặc tả | Mã đang chạy |
|---|---|---|
| a | Người không phải thành viên ⇒ `HOUSEHOLD_NOT_MEMBER` | Không có nhánh; `userRole = null` đi qua mọi phép kiểm |
| b | Nhà `Dissolved` ⇒ `HOUSEHOLD_CLOSED` | Không có nhánh (kiểm `'Inactive'` — giá trị `chk_household_status` không cho phép) |
| c | `Viewer` ⇒ `HOUSEHOLD_READ_ONLY` | Không có nhánh — Viewer ghi được mọi thứ |
| d | `goal` của nhà chỉ Owner | Member tạo / sửa / xoá được (mảng `:77` thiếu `goal`) |
| e | `category` của nhà: Owner **và Member** | Member bị chặn (mảng `:77` có `category`) |
| f | `Transfer` giữa hai ví chung chỉ Owner | Không phân biệt — Member chuyển được |
| g | Kiểm phạm vi là bước **4** | Chạy **trước** mọi bước (`:184`) — người ngoài nhà nhận `SCOPE_MISMATCH` thay vì `NOT_MEMBER` |

Ngoài ra, nhà dùng để xét phải là **nhà của hàng đang có** (`existing.idhousehold`) cho sửa / xoá — hiện `targetHhId` lấy
`payload.idhousehold` trước (`:186-192`), nên payload ghi một nhà khác là được xét theo nhà khác (xem thêm việc 3).

**Xin làm.** Gom thành **một** hàm chạy sau khi đã có `existing` (bản trên server, nếu có) và trước `upsert*` / `softDelete`:

```js
// Phác — tên hàm tuỳ backend. hhId = existing ? existing.idhousehold : payload.idhousehold (sau chuẩn hoá khoá)
async function kiemGhiVaoNha({ entity, operation, idaccount, hhId, existing, payload }) {
  if (!hhId) return;                                            // hàng riêng tư — NOT_OWNER lo
  const house  = await timNhaMoiTrangThai(hhId);                // không lọc delete_at (việc 1.2)
  const member = await householdRepository.findMember(hhId, idaccount);
  if (!member) {
    if (house?.status === 'Dissolved' && await daTungOTrongNha(hhId, idaccount)) throw ma('HOUSEHOLD_CLOSED');
    throw ma('HOUSEHOLD_NOT_MEMBER');
  }
  if (member.role === 'Viewer' || house.status === 'ReadOnly' || !(await chuConPremium(house))) throw ma('HOUSEHOLD_READ_ONLY');
  await kiemPhamVi(payload, hhId);                              // việc 6 → HOUSEHOLD_SCOPE_MISMATCH
  if (!duocPhepTheoBang(entity, operation, member.role, idaccount, existing, payload)) throw ma('HOUSEHOLD_ROLE_FORBIDDEN');
}
```

- **Về `HOUSEHOLD_CLOSED`:** giải tán đặt `Left_at` cho mọi thành viên (`household.repository.js:242-248`), nên theo đúng thứ tự trên thì ai
  cũng rơi vào bước (1) và `HOUSEHOLD_CLOSED` không bao giờ xảy ra. Đề xuất như phác: người **từng** có hàng `household_member` của nhà ấy
  mà nhà đã `Dissolved` ⇒ `HOUSEHOLD_CLOSED`; người chưa từng ở ⇒ `HOUSEHOLD_NOT_MEMBER`. Client xếp cả hai là lỗi vĩnh viễn, chỉ khác câu
  báo (*"Nhà đã giải tán"* / *"Bạn không còn là thành viên"*), nên chọn cách nào cũng không vỡ client.
- **`chuConPremium`** là tuỳ chọn nhưng nên có: giữa lúc Premium của Chủ nhà hết hạn và lúc tác vụ hạ cấp chạy (0h00 giờ VN), cột `Status` vẫn
  `'Active'`. Tính hạn hiệu lực giống `requireFeature` (`middleware/feature-permission.middleware.js:24-36`) thì không có khe ấy.
- **"Người ghi"** = `existing.idaccount` (giao dịch). Nhánh cập nhật hiện **không** ghi đè `idaccount` — đúng, giữ nguyên.
- `Idfund_pair` chưa có cột (phần 2a) — bỏ qua dòng ấy của bảng cho tới khi làm 2a.

---

## Việc 3 (CAO) — Không cho đổi `Idhousehold` của hàng đã có

**Hiện trạng.** Cả 5 nhánh cập nhật ghi `idhousehold: mapped.idhousehold !== undefined ? mapped.idhousehold : existing.idhousehold`
(`upsertCategory` `:263`, `upsertWallet` `:354`, `upsertTransaction` `:482`, `upsertBudget` `:565`, `upsertGoal` `:728`).
Kết hợp với việc 2 (nhà xét theo payload) và việc bỏ `NOT_OWNER` khi hàng là của nhà (`isShared`, `sync.repository.js:249` …), một
thao tác đẩy có thể: kéo một hàng của nhà A sang nhà B; biến hàng của nhà thành hàng riêng của người ghi (đặt `idhousehold: null`).

**Vì sao chặn.** Lý do chính là **an ninh**: mọi phép kiểm quyền của nhà xét theo nhà của hàng; cho đổi `Idhousehold` qua một lượt đẩy là cho
người ghi tự chọn nhà sẽ xét mình — kéo hàng của nhà sang nhà khác, hoặc tư hữu hoá hàng của nhà (sau đó `NOT_OWNER` lại bảo vệ nó như hàng
riêng của họ). Đặc tả cũng không có luồng nào cần đổi: ví chung là hàng `wallet` **tạo mới** mang `Idhousehold`, chỉ Chủ nhà tạo
(`docs/Family/02A_VI_CHUNG_GOP_QUY.md` mục 2 *"Là hàng `wallet` có `Idhousehold` … Chỉ Chủ nhà tạo"*); góp / rút là **cặp hai giao dịch** riêng
biệt, không đổi phạm vi hàng nào (`02A` mục 5); người rời nhà thì khoản đã ghi *"ở lại nhà (không đổi `Idhousehold`, không đổi người tạo)"*
(`docs/Family/GIA_DINH_NEN_MONG.md:268`). Nếu sau này cần đổi phạm vi, làm bằng endpoint riêng có kiểm quyền cả hai phía, không qua `/sync/push`.

**Xin làm.** Hàng đã có: payload mang `idhousehold` **khác** giá trị đang lưu (kể cả `null` khi đang có nhà, hoặc một số khi đang `null`) ⇒
`HOUSEHOLD_SCOPE_MISMATCH`, không ghi gì. Payload không mang khoá `idhousehold` ⇒ giữ giá trị đang lưu (như hiện nay).

---

## Việc 4 (CAO) — Basic tạo được nhà

**Hiện trạng.**
- `household.controller.js:27` chỉ chặn khi `req.user.permissions` là một mảng không chứa `'household'`. `req.user` là payload JWT
  (`middleware/auth.js:118`), mà payload lúc ký **không có** `permissions` — đăng nhập `auth.service.js:399-408`, đăng ký `:197`, `:275`:
  `{ idaccount, username, idrole, rolename, type, status, countdown, is_first_login }`. ⇒ phép kiểm luôn bị bỏ qua.
- Route `POST /api/households` (`api/households.routes.js:10`) không có middleware quyền.
- Đo Supabase 2026-10-28 (chỉ `SELECT`): bảng `feature` có **36** mã, **không có** `household` lẫn `household_members`; `account_type_permission`
  0 dòng cho hai mã ấy. ⚠️ `requireFeature` chỉ chặn khi đọc được **đúng** `false` (`feature-permission.middleware.js:45`) và cho qua khi
  lỗi (`:59-63`) — nên **chỉ gắn middleware mà không seed thì vẫn mở cho Basic**.

**Xin làm.**
1. Migration `database/41_seed_household_permissions.sql` (quy ước áp tay `database/N` như 40; khuôn `database/32_seed_permissions_4_pillars_data.sql`
   — `feature.id` là khoá chính chữ, `account_type_permission` duy nhất theo `(account_type, feature_id)`, CHECK `type IN ('LIMIT','TOGGLE')`):

   ```sql
   BEGIN;
   INSERT INTO "feature" ("id", "name", "description", "type", "category_group",
                          "default_limit", "default_enabled", "default_downgrade_policy", "created_at", "updated_at")
   VALUES
     ('household',         'Gia đình — tạo nhà',          'Chủ nhà cần Premium; người được mời dùng miễn phí', 'TOGGLE', 'Gia đình', NULL, false, 'LOCK_FEATURE', NOW(), NOW()),
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

   Chạy được nguyên văn: các cột bỏ qua đều có mặc định — `scope_schema` / `scope_config` `'{}'::jsonb`, `created_at` / `updated_at`
   `(now() AT TIME ZONE 'UTC')` (đo `information_schema.columns` trên Supabase 2026-10-28). Tên / nhóm / chính sách hạ cấp / trần do PO chốt;
   tối thiểu phải có dòng `('Basic', 'household', false)`.
2. `api/households.routes.js:10` → `router.post('/', requireFeature('household'), householdController.createHousehold);` và gỡ phép kiểm chết ở
   `household.controller.js:26-34`.
3. (Tuỳ PO) Trần thành viên đọc `household_members` của gói Chủ nhà thay vì chỉ cột `household.Max_members` — đơn 50 Việc E, gạch đầu dòng thứ hai.

**Ảnh hưởng client:** không phải sửa gì — `/subscription-info` trả thêm hai khoá, client lưu bảng `features` thành `Map` và chỉ đọc mã của
mình (`premium/data/models/trang_thai_goi.dart:127`), khoá lạ bỏ qua. Khi làm gia đình, client sẽ thêm mã `household` vào danh sách của mình.

---

## Việc 5 (CAO) — Từ chối quyền bằng `Error` trơn → `DB_ERROR` → client gửi lại mãi

**Hiện trạng.** `upsertCategory` (`sync.repository.js:253-258`):

```js
if (existing.is_default && existing.create_by !== mapped.create_by) {
  throw new Error('Cannot modify system default category');
}
if (!existing.is_default && mapped.create_by && existing.create_by !== mapped.create_by) {
  throw new Error('Cannot modify category belonging to another user');
}
```

Hai lỗi không mang `code` ⇒ rơi về mặc định `code = 'DB_ERROR'` (`sync.service.js:267`); nhánh `FORBIDDEN_SYSTEM_DEFAULT` (`:327`) chỉ khớp
chữ *"cannot **delete** system default category"*. Client coi `DB_ERROR` là lỗi **tạm thời** (danh sách lỗi vĩnh viễn là danh sách trắng —
`src/Client-app/lib/core/sync/gui_lo_dong_bo.dart:302-339`) ⇒ bản ghi bị gửi lại ở **mọi** chu kỳ đồng bộ, không bao giờ dừng.

Với gia đình, dòng `:256` chặn **mọi** lần sửa danh mục của nhà bởi người không tạo ra nó: danh mục sao khi tạo nhà mang `create_by` = Chủ
nhà (`household.service.js:92`) ⇒ Member sửa ⇒ `DB_ERROR` ⇒ vòng lặp — trong khi đặc tả cho Member sửa (việc 2 e).

**Xin làm.**
1. Vế `:256` chỉ áp cho hàng **riêng tư** (`!isShared`) — hàng của nhà để việc 2 quyết. (Với hàng riêng tư, `NOT_OWNER` ở `:250` đã chặn
   trước nên vế này gần như thừa.)
2. Mọi lỗi từ chối quyền ở đường đẩy phải mang `code` vĩnh viễn: `:253-254` → `FORBIDDEN_SYSTEM_DEFAULT` (sửa regex `:327` thành
   `/cannot (delete|modify) system default category/i`, hoặc gắn `code` vào lỗi). Rà cả `sync.repository.js` cho `throw new Error(` khác
   không có `code` trên đường đẩy.

---

## Việc 6 (VỪA) — Kiểm phạm vi đọc sai khoá

**Hiện trạng.** `validateEntityScope` (`sync.service.js:100-115`) chạy ở `:184` — **trước** `mapEntityFields` — và chỉ đọc `payload.idwallet`.
Payload giao dịch của client mang khoá **`walletId`** (hợp đồng tên trường của client: `src/Client-app/test/core/sync/sync_payload_contract_test.dart:391`;
cùng tệp: `idwallet_transfer` `:393`, `idgoal` `:397-398`; ngân sách và mục tiêu mang `idwallet` `:577`, `:650`). ⇒ Phép kiểm **bỏ qua đúng ca nó
sinh ra để chặn** (giao dịch riêng trỏ vào ví chung). Ca test 7 dựng payload bằng `idwallet` (`household.system_impact.test.js:193-196`) nên không lộ.

**Xin làm** (bước 4 của việc 2):
- Đọc khoá **sau** chuẩn hoá (`mapEntityFields` đã đổi `walletId` → `idwallet`), hoặc đọc `payload.idwallet ?? payload.walletId`.
- Phạm vi của hàng = `existing.idhousehold` (đã có) hoặc `payload.idhousehold` (tạo mới). So với:
  - ví nguồn (`idwallet`) — mọi thực thể có khoá này;
  - ví đích (`idwallet_transfer`) — giao dịch chuyển khoản;
  - mục tiêu (`idgoal`) — giao dịch **riêng** chỉ trỏ mục tiêu riêng của chính người ấy; trỏ mục tiêu của nhà ⇒ `HOUSEHOLD_SCOPE_MISMATCH`
    (đơn 50 Việc D phần 2, bước kiểm 4; `docs/Family/01_NEN_MONG.md` mục 3 *"Bỏ ngoại lệ `idgoal`"*).
- Ví / mục tiêu tham chiếu không tồn tại thì để khoá ngoại xử lý như hiện nay (không phải việc của phép kiểm này).

---

## Việc 7 (VỪA) — Trạng thái nhà theo gói của Chủ nhà

**Hiện trạng.** Toàn backend chỉ **đọc** `'ReadOnly'` (`sync.service.js:70`); không chỗ nào **ghi** `household.Status = 'ReadOnly'` hay ghi
lại `'Active'`. Đặc tả: đơn 50 Việc E, gạch đầu dòng cuối.

**Xin làm.** Một hàm dùng chung, vd `capNhatTrangThaiNhaTheoChu(idaccount)`: tìm nhà mà tài khoản đang là `Owner` (`household_member`
`Role = 'Owner'`, `Left_at IS NULL`); tính Premium hiệu lực (cùng luật `feature-permission.middleware.js:24-36`); nhà không `Dissolved` mà trạng
thái lệch thì ghi `'ReadOnly'` / `'Active'` + phát `household.changed` (`eventType: 'STATUS_CHANGED'`, người nhận theo việc 8). Gọi ở:

| Lúc | Chỗ |
|---|---|
| Hạ cấp hết hạn (0h00 VN) | `core/scheduler.service.js:295-325` — với từng tài khoản trong `downgradedAccounts` |
| Nâng cấp / gia hạn | sau `paymentRepository.activatePremiumSubscription` (`payment.repository.js:392`) — ba nơi gọi: `payment.service.js:317`, `:415`, `:700` |
| Chuyển Chủ nhà | `household.service.js:375-398` — tính lại theo Chủ nhà **mới** (chuyển cho Member gói Basic ⇒ nhà `ReadOnly`; PO có thể chọn chặn hẳn) |
| Admin đổi gói tay (nếu có đường ấy) | cùng hàm |

Không được đụng nhà `Dissolved`. Thao tác quản lý (rời nhà, mời ra, giải tán) vẫn chạy khi `ReadOnly` (đơn 50 mục 1, điểm 3 *Trạng thái Nhà*).

---

## Việc 8 (VỪA) — Sự kiện tới phòng không ai ở

**Hiện trạng.** `household.changed` phát tới `household_${id}` (`household.service.js:650-665`, `sync.service.js:362`), nhưng lúc kết nối
`core/socket.js:61-79` chỉ `join` `account_<id>` và (admin) `admin_room` — không ai ở phòng `household_<id>`. `sync.completed` chỉ tới phòng
của **người đẩy** (`core/socket.js:215-226`, qua event bus `sync.service.js:346`). Đặc tả đơn 50 Việc F: `sync.completed` tới
**mọi thành viên** khi có hàng của nhà được đẩy.

Hệ quả cho client: máy các thành viên khác không biết có dữ liệu mới của nhà cho tới lượt kéo định kỳ kế tiếp; không biết mình bị đổi vai /
mời ra / nhà giải tán cho tới khi tự mở lại màn Nhà.

**Xin làm** (đề xuất — không phải quản lý vào / ra phòng nhà, vốn dễ sót khi mời ra mà socket còn mở):
- Phát theo **phòng tài khoản** của từng người: lấy `findActiveMembersByHousehold(hhId)` (`household.repository.js:48`) rồi
  `emitToAccount(id, 'household.changed', …)` (`core/socket.js:354`) và `emitSyncCompleted(id, …)` (`:216`).
- Với `MEMBER_REMOVED` · `MEMBER_LEFT` · `HOUSEHOLD_DISSOLVED`: lấy danh sách người nhận **trước** khi đặt `Left_at` (hoặc cộng thêm người vừa
  ra) — nếu không, đúng người bị mời ra không bao giờ nhận được tin.
- Nhà bị ảnh hưởng sau một lượt đẩy lấy từ **hàng đã ghi** (`existing.idhousehold` hoặc giá trị vừa tạo), không chỉ từ `payload.idhousehold`
  như `sync.service.js:353-357` — thao tác sửa / xoá không bắt buộc mang `idhousehold`.
- Client đã nghe `sync.completed` trên phòng tài khoản (đánh thức đồng bộ, im lặng); `household.changed` client sẽ nghe từ lát 1. Payload
  client coi là hộp đen — chỉ đọc tên sự kiện.

---

## Việc 9 (THẤP)

1. **Trần ví chung** (`household.Max_shared_wallets`, mặc định 10; `docs/Family/02A_VI_CHUNG_GOP_QUY.md` mục 2 và mục 11) không chỗ nào thi hành. Tạo ví
   mang `idhousehold` khi nhà đã đủ số ví chung **đang hoạt động** (không lưu trữ, chưa xoá) ⇒ `HOUSEHOLD_WALLET_LIMIT` (client đã xếp mã này vĩnh viễn). Có thể để tới phần 2a.
2. **Danh mục sao cho nhà** (`household.service.js:90-103`) không chép `keyword` — nhà không có từ khoá nhận diện; không chép `idgroup` — mất
   cấu trúc nhóm. Chép cả hai (nhóm cha cần ánh xạ id cũ → id mới trong cùng giao tác).

---

## Kiểm lại (Rule 11 — hai tầng)

**Tầng hành vi — mọi ca đi qua `syncService.processPush(idaccount, operations)`**, payload dùng **đúng khoá client gửi** (chép từ
`src/Client-app/test/core/sync/sync_payload_contract_test.dart` — giao dịch: `id`, `walletId`, `categoryId`, `idwallet_transfer`, `amount`, `type`,
`note`, `dateTransaction`, `is_deleted`, `update_at`, `idaccount`, `idgoal`, …). Dựng: nhà H (Owner A Premium, Member B, Viewer C), tài khoản D
ngoài nhà, ví chung W, mục tiêu chung G, danh mục nhà K (do A tạo), giao dịch T của B.

| # | Ca | Mong đợi `results[0].code` |
|---|---|---|
| 1 | D sửa ví W | `HOUSEHOLD_NOT_MEMBER` |
| 2 | D tạo giao dịch mang `idhousehold = H` | `HOUSEHOLD_NOT_MEMBER` |
| 3 | C (Viewer) tạo giao dịch vào W | `HOUSEHOLD_READ_ONLY` |
| 4 | Nhà H `ReadOnly`, A tạo giao dịch | `HOUSEHOLD_READ_ONLY` |
| 5 | H đã giải tán, B (từng ở) sửa T | `HOUSEHOLD_CLOSED` |
| 6 | B tạo giao dịch **riêng** (`idhousehold` vắng) với `walletId = W` | `HOUSEHOLD_SCOPE_MISMATCH` |
| 7 | B tạo giao dịch riêng với `idgoal = G` | `HOUSEHOLD_SCOPE_MISMATCH` |
| 8 | B sửa T, payload `idhousehold: null` | `HOUSEHOLD_SCOPE_MISMATCH`, T giữ `Idhousehold = H` |
| 9 | B tạo ví chung / mục tiêu chung / ngân sách chung | `HOUSEHOLD_ROLE_FORBIDDEN` (3 ca) |
| 10 | B sửa giao dịch của A | `HOUSEHOLD_ROLE_FORBIDDEN` |
| 11 | B tạo giao dịch `Transfer` giữa hai ví chung | `HOUSEHOLD_ROLE_FORBIDDEN` |
| 12 | B sửa danh mục K (A tạo) | `synced` (không phải `DB_ERROR`) |
| 13 | A sửa T của B | `synced`, `Idaccount` của T vẫn là B |
| 14 | Tài khoản sửa danh mục mặc định hệ thống | `FORBIDDEN_SYSTEM_DEFAULT` |
| 15 | Tài khoản Basic `POST /api/households` | HTTP 403 `FEATURE_DISABLED` |
| 16 | Hạ cấp A (chạy hàm hạ cấp với giờ giả) rồi gia hạn | `household.Status` `ReadOnly` → `Active`, B nhận `household.changed` trên phòng `account_<B>` |
| 17 | B đẩy giao dịch vào W | A và C nhận `sync.completed` trên phòng tài khoản của mình |

**Tầng CSDL** (sau khi áp `database/41`; chỉ `SELECT`):

```sql
SELECT account_type, feature_id, is_enabled, limit_value
FROM account_type_permission WHERE feature_id IN ('household', 'household_members') ORDER BY 2, 1;   -- 4 dòng

SELECT "Idhousehold", "Owner_idaccount", "Status", "Delete_at" FROM household ORDER BY 1;
SELECT "Idhousehold", "Idaccount", "Role", "Left_at" FROM household_member ORDER BY 1, 2;
```

⚠️ Chạy các ca trên **CSDL riêng**, không phải Supabase dùng chung — tạo nhà / ví chung thử trên Supabase là hàng thật đi vào `/sync/pull` của
tài khoản thật. Dọn dữ liệu thử bằng **xoá mềm** (`Delete_at`), không xoá cứng: hàng đã đồng bộ về máy mà bị xoá cứng ở server là máy đẩy
lên nhận `Record not found` ở mọi chu kỳ.

---

## Trả lời đơn (backend ghi vào đây)

| Việc | Đã làm (commit, tệp) | Ca test |
|---|---|---|
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | | |
| 5 | | |
| 6 | | |
| 7 | | |
| 8 | | |
| 9 | | |
