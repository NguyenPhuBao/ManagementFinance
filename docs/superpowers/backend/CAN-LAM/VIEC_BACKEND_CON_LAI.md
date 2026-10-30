# Việc backend còn phải làm — MỘT tệp (gộp đơn 43 · 44 · 48 · 49 · 50 · 52 · 55 · 56 · 57)

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
>
> 🔎 **Client soát lại 2026-10-30 sau gộp `e3248955` (commit gộp `ba5cd3c5`; PR #170 = `5be3b4c0`).** Đọc mã ở HEAD `ba5cd3c5` + truy vấn
> **chỉ đọc** trên Supabase của `.env`; chấm theo **câu hỏi gốc ở các mục 1–8, không theo bảng Trả lời mục 10**. Số đếm (đạt / một phần /
> không đạt / không kiểm được):
>
> | Đơn | Đạt | Một phần | Không đạt | Không kiểm được |
> |---|---|---|---|---|
> | 56 (9 việc) | 6 — 56.1, 56.3, 56.4, 56.5, 56.6, 56.7 | 3 — 56.2, 56.8, 56.9 | 0 | 0 |
> | 57 (8 việc) | 0 | 0 | 8 — 57.1 … 57.8 | 57.8 vế 8 (CASCADE: chủ ý hay không phải hỏi backend) |
> | 43 (A3, A5, A6) | 3 | 0 | 0 | 0 |
> | 44 (B2) | 1 | 0 | 0 | 0 |
> | 48 (48.1–48.3) | 2 — 48.2, 48.3 | 1 — 48.1 | 0 | 0 |
> | 49 (D, F) | 1 — D (và F vế 2) | 1 — F vế 1 | 0 | 0 |
> | 52 (52.1–52.5) | 1 — 52.2 | 1 — 52.1 | 2 — 52.3, 52.5 | 1 — 52.4 (khoá Render) |
> | 55 (A1–A3) | 2 — A1, A2 | 1 — A3 | 0 | 0 |
> | T1–T5 | 2 — T4, T5 | 3 — T1, T2, T3 | 0 | 0 |
>
> - ⚠️ **Bảng Trả lời mục 10 nhắc hàm / mã không có trong mã** (`getHouseholds`, `updateHousehold`, `deleteHousehold`, `NOT_A_MEMBER`,
>   `household_permission` — `grep` trên `modules/` + `api/` ra 0 dòng); việc thật của PR nằm ở `sync.service.js`, `sync.repository.js`,
>   `household.service.js`, `household.repository.js`, route + migration 41. Nhiều dòng trả lời còn mô tả việc **khác** câu hỏi gốc (vd. 43.A3
>   trả lời bằng `payment.service.js`; 43.A5 ghi *"3 giá trị"* trong khi mã + CSDL là 4; 52.3–52.5 viện một script không giải mã lần nào).
> - ⚠️ **Ca test của backend không đi payload thật của app** (`tests/unit/household.system_impact.test.js:229-413`): payload không có
>   `idaccount` (nên chốt *"Ownership mismatch"* — 57.4 — không bao giờ chạy) và dùng `operation: 'create'` trong khi app **không bao giờ** gửi
>   `create` (mọi khối `thu_gom_day.dart` gửi `update` / `delete`). Xin ca test chép payload từ
>   `src/Client-app/test/core/sync/sync_payload_contract_test.dart` / `docs/superpowers/sync/SYNC_DOCUMENTATION.md`.
> - Việc đạt đã chuyển xuống **mục 9** (một dòng bằng chứng mỗi việc); việc còn mở có dòng 🔎 ngay dưới tiêu đề. **Đơn 58 mới** (lỗi do PR đưa vào,
>   mục 1 cuối). Số đơn kế tiếp: **59**. Supabase đã áp migration 41–43; `PersonFinance` chưa.

---

## 0. Bảng việc — xếp theo mức

> Chỉ còn việc **chưa đạt trọn**; việc đạt đã sang mục 9. **🔎** = client soát 2026-10-30 thấy còn thiếu (chi tiết ở dòng 🔎 dưới tiêu đề việc).

| Mã | Việc | Mức | Loại | Mục |
|---|---|---|---|---|
| 58.1 | Member tạo được chuyển khoản giữa hai ví chung — chốt chỉ chạy ở `operation === 'create'`, app luôn gửi `update` | **CAO** | mã | 1 (Đơn 58) |
| 58.5 | Khoá tự động của AIOps không bao giờ tự mở khi hết hạn + `force_logout` mới ⇒ ai biết username khoá được tài khoản ấy vô thời hạn | **CAO** | mã | 1 (Đơn 58) |
| 58.2 | `HOUSEHOLD_WALLET_LIMIT` chết với app (cùng gốc 58.1) | VỪA | mã | 1 (Đơn 58) |
| 58.3 | `HOUSEHOLD_DISSOLVED` không tới ai — `Left_at` đặt trước khi phát | VỪA | mã | 1 (Đơn 58) |
| 58.4 | `household.changed` sau `/sync/push` phát theo `payload.idhousehold` chưa kiểm | VỪA | mã | 1 (Đơn 58) |
| 58.6 | Gom lỗi nhỏ do PR #170 (`chuConPremium` nuốt lỗi CSDL, migration 41 `DO UPDATE`, `force_logout` khi khớp 0 hàng, khuôn danh mục thử toàn cục…) | THẤP | mã | 1 (Đơn 58) |
| 56.2 🔎 | Thi hành đúng bảng quyền + thứ tự mã của gia đình (người ngoài nhà, nhà giải tán, Viewer, mục tiêu chung, danh mục nhà, chuyển khoản) | **CAO** | mã | 1 |
| 57.1 🔎 | Một hình dạng *trạng thái nhà* cho mọi endpoint trả nó — theo `docs/Family/01` mục 4 (`/me` đang phẳng, tạo nhà trả hàng thô) | **CAO** | hợp đồng | 1 |
| 57.2 🔎 | `req.user` không có `email` → mọi đường mời **email** hỏng (xem trước 403, ai cầm mã cũng vào, người đăng ký sau không thấy lời mời) | **CAO** | mã | 1 |
| 57.3 🔎 | Thư mời không bao giờ gửi — `require('../../core/mail.service')` không tồn tại, lỗi bị nuốt | **CAO** | mã | 1 |
| 52.1 · 52.3 · 52.4 · 52.5 🔎 | Giải mã hỏng: log thiếu bảng + khoá; hai hàm nuốt lỗi; khoá `PersonFinance`; khoá Render; dọn hàng hỏng cũ | VỪA | mã + vận hành | 4 |
| 55.A3 🔎 | Premium không có `premium_expires_at` mang ba nghĩa — `chuConPremium` (mã mới của PR #170) vẫn coi là Premium | VỪA | hợp đồng | 5 |
| 56.8 🔎 | `household.changed` / `sync.completed` phát vào phòng không ai ở | VỪA | mã | 1 |
| 57.4 🔎 | Chủ nhà sửa khoản của thành viên bị chặn ở chốt *"Ownership mismatch"* trước ma trận vai | VỪA | mã | 1 |
| 57.5 🔎 | `POST /api/households` nhận `maxMembers` / `maxSharedWallets` / `contributionDueDay` từ body | VỪA | mã | 1 |
| 57.6 🔎 | Giải tán không xoá mềm dữ liệu chung, không thu hồi mã mời | VỪA | mã | 1 |
| 57.7 🔎 | Mã lỗi API của nhà lệch `docs/Family/01` mục 2.5 + đơn 50 C.3 (tên, HTTP, `_DECLINED` không bao giờ phát) | VỪA | hợp đồng | 1 |
| 49.F(1) 🔎 | Migration 33 xoá cứng → 10 ví · 13 giao dịch · 1 danh mục mồ côi trên Supabase | VỪA | migration + dọn | 7 |
| T1 🔎 | Sửa `docs/Admin-web/Event-Notification-to-ClientApp.md` (gộp 43.D · 44.F · 49.H1) | VỪA | tài liệu | 8.1 |
| T2 🔎 | Sửa `IP-Device-ClientApp.md` + `04-user-management-and-lifecycle.md` (49.E · 49.H3) | VỪA | tài liệu | 8.2 |
| T3 🔎 | Đính chính `docs/Functional-Mobile/4_TRU_COT.md` (55.B — 31 khẳng định sai) | VỪA | tài liệu | 8.3 |
| 56.9 🔎 | Trần ví chung; danh mục sao cho nhà thiếu từ khoá / nhóm | THẤP | mã | 1 |
| 57.8 🔎 | Tám chỗ nhỏ của API nhà (lọc thành viên khi mời email, tên người mời, khoá hàng mời, giới hạn gọi, trạng thái lời mời, độ dài email…) | THẤP | mã | 1 |
| 48.1 🔎 | Ghi xác nhận ai / CSDL nào đã dọn dữ liệu test | THẤP | trả lời | 6 |

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

> 🔎 **Client soát 2026-10-30:** **56.1, 56.3, 56.4, 56.5, 56.6, 56.7 đạt theo mã** (bằng chứng một dòng mỗi việc ở mục 9; thân các mục con dưới đây
> giữ nguyên làm tra cứu — đừng làm lại). **Còn mở:** 56.2, 56.8, 56.9 (một phần) và toàn bộ đơn 57. Chưa đo trên đường thật (CSDL 0 nhà).

### 56.2 (CAO) — Thi hành đúng bảng quyền và thứ tự mã

🔎 **2026-10-30 — MỘT PHẦN.** Đạt: (a) người ngoài nhà `sync.service.js:99-111`; (b) `Dissolved` → `HOUSEHOLD_CLOSED` `:100-106`; (c) Viewer `:115`;
(d) Member không đụng ví / mục tiêu / ngân sách `:125-131`; (e) Member sửa danh mục được; (g) phạm vi chạy sau `READ_ONLY` `:122`, nhà xét =
`existing` `:313-315`; thứ tự 1→5 đúng. **Chưa:** (f) chốt `Transfer` chỉ ở nhánh `operation === 'create'` (`:152-160`) — app luôn gửi `update` ⇒ Member
tạo được chuyển khoản giữa hai ví chung; Member đổi khoản thu / chi của mình thành `Transfer` qua nhánh update; người từng là Chủ vẫn sửa / xoá
`Transfer` của mình sau chuyển chủ (→ **58.1**). Chốt 57.4 (`:260-268`) chạy **trước** ma trận ⇒ ca 10, 12, 13 của *Kiểm lại mục 1* hỏng
(chặn nhưng sai mã). Lệch nhỏ: chốt 56.3 (`:303-311`) đứng trước kiểm thành viên ⇒ người ngoài đổi `idhousehold` nhận `SCOPE_MISMATCH` thay vì
`NOT_MEMBER` (→ 58.6).

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

🔎 **2026-10-30 — MỘT PHẦN.** Đạt: `emitHouseholdChanged` (`household.service.js:662-…`) phát tới `account_<id>` của mọi thành viên + `extraRecipients`
(`MEMBER_REMOVED` `:430-432`, `MEMBER_LEFT` `:450`); sau `/sync/push` phát `household.changed` + `sync.completed` tới thành viên **khác**
(`sync.service.js:475-506`). **Chưa:** (1) `HOUSEHOLD_DISSOLVED` không tới ai — `:462` đặt `Left_at` mọi người (`household.repository.js:276-282`) rồi mới phát
`:464-466` không `extraRecipients` (→ **58.3**); (2) nhà bị ảnh hưởng vẫn lấy từ `payload.idhousehold` (`sync.service.js:475-479`), gom cả op **bị từ chối**
(→ **58.4**); `household.changed` sau đẩy là thừa (`eventType: 'SYNC_COMPLETED'`, client không đọc payload nên vẫn hỏi `/me`).

`household.changed` phát tới `household_${id}` (`household.service.js:650-665`, `sync.service.js:362`) nhưng lúc kết nối
`core/socket.js:61-79` chỉ `join` `account_<id>` và `admin_room`. `sync.completed` chỉ tới phòng của người đẩy (`core/socket.js:216`,
qua event bus `sync.service.js:346`); đặc tả (đơn 50 Việc F) xin tới **mọi thành viên**.

**Xin làm:** phát theo phòng tài khoản của từng thành viên — `findActiveMembersByHousehold(hhId)` (`household.repository.js:48`) →
`emitToAccount(id, 'household.changed', …)` (`core/socket.js:354`) + `emitSyncCompleted(id, …)`. Với `MEMBER_REMOVED` / `MEMBER_LEFT` /
`HOUSEHOLD_DISSOLVED`: lấy người nhận **trước** khi đặt `Left_at` (hoặc cộng người vừa ra). Nhà bị ảnh hưởng sau một lượt đẩy lấy từ hàng
đã ghi (`existing.idhousehold`), không chỉ từ payload (`sync.service.js:353-357`). App coi payload là hộp đen — chỉ đọc tên sự kiện.

### 56.9 (THẤP)

🔎 **2026-10-30 — MỘT PHẦN.** (2) danh mục sao cho nhà **đạt** (`household.service.js:90-104`: ánh xạ `idgroup` cũ → mới, chép `keyword`). (1) trần ví chung
`sync.service.js:134-148` chỉ chạy khi `operation === 'create'` ⇒ **chết với app** (ví luôn `update`, `thu_gom_day.dart:148-149`) — cùng gốc **58.1**
(→ **58.2**); phép đếm đúng (`delete_at` null, `status 'Active'`).

1. Trần ví chung (`household.Max_shared_wallets`, mặc định 10; `docs/Family/02A` mục 2 và 11) chưa thi hành: tạo ví mang `idhousehold` khi
   nhà đã đủ ví chung **đang hoạt động** (không lưu trữ, chưa xoá) ⇒ `HOUSEHOLD_WALLET_LIMIT`. Có thể để tới phần 2a.
2. Danh mục sao cho nhà (`household.service.js:90-103`) không chép `keyword` và `idgroup` — chép cả hai (ánh xạ id nhóm cha cũ → mới trong
   cùng giao tác).

### Đơn 57 — soát hợp đồng API của nhà (client, 2026-10-28 phiên 21)

Đơn 56 soát `/sync/push`; đơn này soát **16 endpoint `/api/households`** (`api/households.routes.js` →
`household.controller.js` / `.service.js` / `.repository.js`) và migration 40, đối chiếu `docs/Family/01_NEN_MONG.md` và đơn 50 C.
Mọi `tệp:dòng` đọc ở `177dd0e1`; viết tắt **S** = `modules/household/household.service.js`, **R** = `…/household.repository.js`,
**C** = `…/household.controller.js`, **SS** = `modules/sync/sync.service.js`. Không trùng việc nào của 56.

> 🔎 **2026-10-30 — cả tám việc 57.1–57.8 CHƯA LÀM** (PR #170 không đụng: `/me` vẫn phẳng, `req.user` vẫn không `email`, thư vẫn không gửi…). Nguyên văn
> đơn bên dưới chưa đổi; mỗi việc có dòng 🔎 với tệp:dòng ở HEAD `ba5cd3c5`. Trả lời mục 10 để trống đúng cho 57.x. **Thứ tự với 57.4:** client sẽ
> **không** đổi đường đẩy hàng nhà do người khác ghi (G113 nợ 4) trước khi 57.4 đóng — làm ngược là *"Ownership mismatch"* vĩnh viễn, mất dữ liệu
> im lặng (xem đoạn *Thứ tự với 57.4* cuối đơn 58).

#### 57.1 (CAO) — Một hình dạng *trạng thái nhà* (người dùng chốt 2026-10-28: theo `docs/Family`)

🔎 **2026-10-30 — chưa làm.** `/me` vẫn phẳng `household.service.js:151-163`; không nhà → `{household: null}` `household.controller.js:51` (`data` không bao giờ null);
`POST /` trả hàng Prisma thô + `myRole` `household.service.js:68-71`. Client tiếp tục đọc cả ba hình dạng (`nha_cua_toi.dart:152-200`).

`docs/Family/01` mục 4 (mở rộng đơn 50 C.1): `GET /me` **và mọi thao tác trả nó** dùng **một** hình dạng —

```json
{ "household": { "id": 12, "name": "…", "status": "Active", "maxMembers": 6, "ownerId": 18, "createAt": "…", "maxSharedWallets": 10 },
  "myRole": "Owner",
  "members": [ { "idaccount": 18, "displayName": "…", "role": "Owner", "joinedAt": "…" } ],
  "formerMembers": [ { "idaccount": 31, "displayName": "…", "leftAt": "…" } ] }
```

Mã đang trả ba hình dạng: `/me` **phẳng** `{idhousehold, name, ownerIdaccount, status, maxMembers, maxSharedWallets, contributionDueDay,
createdAt, myRole, members[{idaccount, username, fullname, role, joinedAt}], formerMembers[…]}` (S:143-155); không ở nhà nào →
`{household: null}` (C:61); `POST /api/households` trả **hàng Prisma thô** snake_case + `myRole` (S:68-71).

**Xin:** một hàm dựng hình dạng trên, dùng cho #1 tạo nhà, #2 `/me`, #7 `/join`, #9 `/transfer-owner`, #15 `…/accept`. Không ở nhà →
`{ "household": null, "myRole": null, "members": [], "formerMembers": [] }`. `displayName` = `fullname` (rỗng thì `username`) — không trả
email (`00` mục 4 nguyên tắc 7). `contributionDueDay` (cột đã có, `02C`) đặt **trong** `household` nếu giữ. Ca test: so khoá của năm
endpoint với một mẫu chung.

#### 57.2 (CAO) — `req.user` không có `email`: mọi đường mời email hỏng

🔎 **2026-10-30 — chưa làm.** JWT vẫn không `email` (`auth.service.js:196-203`, `:399-408`; tệp không đổi trong PR); `middleware/auth.js:118` `req.user = decoded`;
`household.controller.js:129, :159, :329, :352, :377` vẫn đọc `req.user.email`.

Payload JWT không có `email` (`modules/auth/auth.service.js:196-203`; hai chỗ ký khác `:275-282`, `:399-408`; refresh ký lại cùng payload),
`middleware/auth.js:118` gán `req.user = decoded`. Ba hệ quả:
1. `GET /invites/:code` với lời mời email luôn **403 `HOUSEHOLD_INVITE_WRONG_ACCOUNT`** (`callerEmail = ''`, S:262-267) — đúng người cũng bị từ chối.
2. `POST /join`, `…/accept`, `…/decline` **bỏ kiểm** (`invite.email && callerEmail`, S:305-309, S:622-626) — ai cầm mã trong thư cũng vào được.
3. `GET /invitations` chỉ khớp `Invitee_idaccount` (R:295-304 với `email = ''`) — người **đăng ký sau khi được mời** không thấy lời mời
   (`docs/Family/01` mục 2.2 khớp theo `Email` lúc đọc).

Test mock `user = {idaccount, email, permissions}` (`tests/unit/household.api.test.js:9`) nên không lộ. **Xin:** service tra `account.Email`
theo `req.user.idaccount` (hoặc đưa `email` vào JWT — nhưng token cũ trong máy người dùng không có, vẫn phải tra); ca test đi qua route
với token thật.

#### 57.3 (CAO) — Thư mời không bao giờ gửi

🔎 **2026-10-30 — chưa làm.** `household.service.js:583` vẫn `require('../../core/mail.service')` (`core/` chỉ có `email.service.js`); `:598` truyền `text`, `email.service.js:95` nhận
`html`; `catch` `:601-606` nuốt.

S:571 `require('../../core/mail.service')` — `core/` chỉ có `email.service.js` ⇒ `MODULE_NOT_FOUND`, `catch` S:589-594 nuốt thành `warn`;
`POST /invites/email` vẫn trả 202. Sửa đường dẫn chưa đủ: `const { sendMail } = require(…)` tách hàm khỏi đối tượng nên mất `this`
(`email.service.js:95-99` gọi `this.sendViaBrevo`), và S:586 truyền `text` trong khi hàm nhận `html`. **Xin:** gọi qua đối tượng service,
truyền đúng trường; ca test kiểm hàm gửi được gọi với `to`, `subject`, nội dung có mã.

#### 57.4 (VỪA) — Chủ nhà sửa khoản của thành viên bị chặn trước ma trận vai

🔎 **2026-10-30 — chưa làm, và là chốt chặn của lát 2 phía client.** `sync.service.js:260-268` không đổi, đứng trước `enforceHouseholdPermission`, không `code`; client xếp chuỗi này
vĩnh viễn (`gui_lo_dong_bo.dart:409-411`). Hiện chưa xảy ra trên máy thật: `transactionDao.getPending(idaccount)` lọc `t.idaccount.equals(idaccount)`
(`transaction_dao.dart:295-302`) nên app chưa từng đẩy hàng do người khác ghi (G113 nợ 4). Ca 10, 12, 13 *Kiểm lại mục 1* vì thế **KHÔNG đạt** với payload thật.

SS:155-164 so `payload.idaccount` với token **trước** `enforceHouseholdPermission`, trả `error` *"Ownership mismatch…"* không `code`. App
gửi `idaccount` **của hàng** — tức người ghi (`thu_gom_day.dart`; hàng kéo về giữ `Idaccount` người ghi) — nên lượt Chủ nhà sửa giao dịch
của Member (`docs/Family/01` mục 3: được phép) bị từ chối, và app xếp chuỗi ấy **vĩnh viễn** (`gui_lo_dong_bo.dart:406-408`): mất im lặng.
**Xin:** hàng mang `idhousehold` (hoặc hàng đã có `Idhousehold`) không qua chốt này — ma trận vai quyết; `Idaccount` của hàng giữ người ghi
(ca 13 *Kiểm lại mục 1*). App **giữ** gửi `idaccount` người ghi; gửi người sửa là ghi đè mất người ghi.

#### 57.5 (VỪA) — Tạo nhà nhận trần từ body

🔎 **2026-10-30 — chưa làm.** `household.service.js:45-47` vẫn đọc `maxMembers`, `maxSharedWallets`, `contributionDueDay` từ `req.body` (`household.controller.js:26`). App chỉ gửi `{name}` (`household_api.dart:118`).

S:45-47 đọc `maxMembers`, `maxSharedWallets`, `contributionDueDay` từ `req.body` (C:36) ⇒ client tự đặt 20 người (CHECK 2–20). Đơn 50 C.2:
`Max_members` lấy từ giới hạn gói; `02A` Q-A2: trần ví chung do server chọn. **Xin:** bỏ ba trường khỏi body (cùng việc 56.4.3).

#### 57.6 (VỪA) — Giải tán không xoá mềm dữ liệu chung

🔎 **2026-10-30 — chưa làm.** `household.repository.js:265-284` chỉ đặt `Status = 'Dissolved'`, `Delete_at`, `Left_at`; không chạm 5 bảng, không `Revoked_at`. Cộng với 58.3: máy thành viên giữ dữ liệu nhà đã giải tán tới lượt `/me` kế.

R:231-250 chỉ đặt nhà `Dissolved` + `Delete_at` và `Left_at` thành viên; không đụng `wallet` / `transaction` / `goal` / `budget` / `category`
mang `Idhousehold`, không thu hồi mã mời. `docs/Family/00` quyết định 7: *"Dữ liệu chung biến mất với mọi người (xoá mềm ở server)"*;
đơn 50 C.2: xoá mềm 5 bảng + `Revoked_at` mã. Hệ quả: máy thứ hai kéo về không có tombstone (hàng chỉ rơi khỏi phạm vi), mã còn hiệu
lực vẫn mở được xem trước. **Xin:** trong cùng giao tác — xoá mềm hàng của nhà ở 5 bảng (cột xoá + giờ sửa mới), `Revoked_at` mã chưa dùng.

#### 57.7 (VỪA) — Mã lỗi API của nhà lệch tài liệu

🔎 **2026-10-30 — chưa làm.** Tập mã `household.service.js` + `household.controller.js` trước / sau PR giống hệt (chỉ mất `PREMIUM_REQUIRED`, vốn không bao giờ phát):
`HOUSEHOLD_INVITE_EXPIRED` 400 `:267`, `:310`; `HOUSEHOLD_INVITE_DECLINED` không phát; `HOUSEHOLD_NOT_ACTIVE` `:178`, `:487`; bảng mã chốt mục 10 dòng 57.7 trống.
Client đọc cả hai bộ tên (`cau_loi_nha.dart:57-76`).

`docs/Family/01` mục 2.5 + đơn 50 C.3 ↔ mã: `HOUSEHOLD_INVITE_EXPIRED` trả **400** (đơn 50: 410); `HOUSEHOLD_INVITE_DECLINED` **không
bao giờ phát** (lời mời đã từ chối rơi vào `_USED` S:254 / S:297, `_INVALID` S:618); ReadOnly và Dissolved gộp `HOUSEHOLD_NOT_ACTIVE` 400;
mã thêm chưa có trong tài liệu: `FORBIDDEN_NOT_OWNER`, `NOT_IN_HOUSEHOLD`, `OWNER_CANNOT_LEAVE`, `MEMBER_NOT_IN_HOUSEHOLD`,
`TARGET_NOT_IN_HOUSEHOLD`, `HOUSEHOLD_INVITE_NOT_FOUND`, `CANNOT_*`, `INVALID_*`. **Xin:** theo tên + HTTP của tài liệu; mã nào giữ khác thì
ghi **bảng mã chốt** vào mục 10 — app dựng câu báo lỗi theo bảng ấy.

#### 57.8 (THẤP)

🔎 **2026-10-30 — vế 1–7 chưa làm; vế 8 không kiểm được bằng mã.** (1) `household.service.js:511-514` đọc `m.account.email`, `household.repository.js:88-97` không `select email`; (2) `:566`
đọc `membership.account`, `household.repository.js:70-80` chỉ `include household`; (3) `:319-341` kiểm ngoài giao tác, không `FOR UPDATE`; (4) `households.routes.js:8` chỉ
`authenticate`; (5) `:219-233` năm trạng thái, `household.repository.js:167-189` nhánh email 7 ngày; (6) `:613-619` thiếu `memberCount`, `maxMembers`; (7) `:473` chỉ kiểm `@`;
(8) migration 40 chỉ thêm một dòng chú thích — CASCADE còn; *chủ ý hay không* phải hỏi backend.

1. `alreadyMember` (S:499-502) đọc `m.account.email` nhưng `findActiveMembersByHousehold` không `select` email (R:55-63) ⇒ luôn `false` ⇒
   mời email người đang ở nhà vẫn tạo lời mời và chiếm chỗ trần (`01` mục 2.2: 202, không tạo).
2. `inviterName` (S:554) đọc `membership.account` mà `findActiveMemberByAccount` chỉ `include household` (R:42-44) ⇒ thư luôn ghi *"Chủ nhà"*.
3. Tham gia không khoá hàng mời (S:285-333; đơn 50 C.2 `SELECT … FOR UPDATE`).
4. Không giới hạn số lần gọi `GET /invites/:code` / `POST /join` (đơn 50 C.4) — `api/households.routes.js` chỉ `authenticate`.
5. `GET /invites` trả 5 trạng thái `Pending|Declined|Revoked|Used|Expired` (S:211-216; `01` mục 2.4 nói 3) và nhánh email trả mọi lời mời
   email trong 7 ngày kể cả đã dùng / huỷ (R:146-150) — ghi rõ trong tài liệu hoặc lọc.
6. `GET /invitations` thiếu `memberCount`, `maxMembers` (`01` mục 2.4 #14; S:601-607).
7. Email > 100 ký tự không bị chặn (C:309 / S:461 chỉ kiểm `@`) ⇒ vỡ cột ⇒ 500 `HOUSEHOLD_ERROR` (`01` mục 2.1: 400). Thêm trần 5 thư / giờ
   (S:484) chưa có trong tài liệu — ghi vào `01` mục 2.2 nếu giữ.
8. Migration 40 dùng `ON DELETE CASCADE` (M40:11, :27-28, :49, :51) và `SET NULL` cho `Idhousehold` 5 bảng (M40:72-76) — xoá cứng tài khoản /
   nhà kéo theo xoá cứng; đơn 50 B dùng `REFERENCES` thường. Xác nhận chủ ý hoặc đổi.

### Đơn 58 — lỗi do PR #170 đưa vào (client, 2026-10-30 phiên 24)

Phát hiện khi soát PR #170 (`5be3b4c0`) theo câu hỏi gốc của mục 1–2. Mọi `tệp:dòng` đọc ở HEAD `ba5cd3c5`; viết tắt **SS** = `modules/sync/sync.service.js`,
**HS** = `modules/household/household.service.js`, **HR** = `modules/household/household.repository.js`, **AQ** = `modules/aiops/aiops.quarantine.js`.
Không trùng việc nào của 56 / 57 (cùng gốc thì ghi rõ).

#### 58.1 (CAO) — Member tạo được chuyển khoản giữa hai ví chung

Chốt *"chỉ Chủ được tạo `Transfer` giữa hai ví chung"* chạy **chỉ** khi `operation === 'create'` (SS:152-169). App **không bao giờ** gửi `create`: mọi khối của
`thu_gom_day.dart` gửi `update` / `delete` (`:104-105`, `:148-149`, `:203`, `:248-249`, `:311-313`, `:389-390`, `:432-433`), nên `existingRecord = null` ⇒ `creatorId = null` ⇒ **ghi được**.
Hệ quả: (1) Member tạo được chuyển khoản giữa hai ví chung; (2) Member đổi khoản thu / chi của mình thành `Transfer` qua nhánh update; (3) người từng là Chủ vẫn sửa / xoá
`Transfer` của mình sau khi chuyển chủ. Test backend dùng `create` (`tests/unit/household.system_impact.test.js:375`) nên không lộ.
**Xin:** xét `!existingRecord` thay cho `operation === 'create'`; với update / delete: hàng cũ **hoặc** payload là `Transfer` ⇒ chỉ Owner.
**Kiểm lại:** ca 11 *Kiểm lại mục 1* với payload `operation: 'update'` + id mới ⇒ `HOUSEHOLD_ROLE_FORBIDDEN`.

#### 58.2 (VỪA) — `HOUSEHOLD_WALLET_LIMIT` chết với app

SS:134-148 cùng điều kiện `operation === 'create'` (cùng gốc 58.1); ví luôn `update` (`thu_gom_day.dart:148-149`). Phép đếm đúng (`delete_at` null, `status 'Active'`).
**Xin:** xét `!existingRecord`.

#### 58.3 (VỪA) — `HOUSEHOLD_DISSOLVED` không tới ai

HS:462 đặt `Left_at` cho mọi thành viên (HR:276-282) **rồi mới** phát (HS:464-466) không `extraRecipients` ⇒ danh sách người nhận rỗng. Cùng 57.6 (không tombstone) ⇒ máy thành viên
giữ dữ liệu nhà đã giải tán tới lượt `/me` kế (resume 5 phút). **Xin:** lấy `findActiveMembersByHousehold` **trước** `dissolveHousehold`, truyền vào `extraRecipients`.

#### 58.4 (VỪA) — `household.changed` sau `/sync/push` phát theo `payload.idhousehold` chưa kiểm

SS:475-506 phát `household.changed` + `sync.completed` tới mọi thành viên của nhà lấy từ `payload.idhousehold`, **kể cả op bị từ chối** (`HOUSEHOLD_NOT_MEMBER`). Id nhà là `SERIAL`
(đoán được) và không có trần số nhà mỗi lượt đẩy ⇒ người ngoài khuếch đại `GET /me` + `GET /invitations` + một chu kỳ kéo trên **mọi máy** của một nhà bất kỳ. Thêm: `household.changed` sau đẩy
mang `eventType: 'SYNC_COMPLETED'` — thừa (`sync.completed` đã đủ cho dữ liệu; client không đọc payload nên vẫn hỏi `/me`).
**Xin:** bỏ `household.changed` sau `/sync/push` (chỉ giữ cho đổi thành viên / trạng thái); chỉ phát cho nhà của op **đã ghi**, lấy từ `existing.idhousehold` / hàng vừa ghi.
*Phía client:* đã giãn cách 30 s giữa hai lượt làm mới do `nhaDoi` (`kGianCachNhaDoi`, commit `1227d8a2`, G113 nợ 12) — giảm khuếch đại chứ không thay việc sửa ở server.

#### 58.5 (CAO) — Khoá tự động của AIOps không bao giờ tự mở khi hết hạn (đơn 43)

Cả ba lối hết hạn (AQ:141, AQ:153, và nay AQ:1005) lọc `reason_inactive` chứa `AIOps` / `Cách ly` / `Sentinel` (AQ:651-659), nhưng lý do do AIOps tự ghi là
*"Tấn công dò mật khẩu Brute-Force (…)"* (`feature.collector.js:225`), *"Phát hiện tái sử dụng Token đã thu hồi liên tục (…)"* (`:244`) hoặc mặc định *"Phát hiện hành vi bất thường"*
(AQ:282) — không chuỗi nào khớp. Trước PR, lối liệt kê không lọc nên tài khoản còn được mở khi admin mở trang AIOps sau hạn; PR #170 đóng nốt lối ấy (và gỡ vế `null`) ⇒ khoá 15 phút thành
khoá **vô hạn** tới khi admin mở tay. Kết hợp vấn đề gốc của đơn 43 (gõ sai mật khẩu 15 lần cho **tên đăng nhập người khác** là đủ kích hoạt) và 43.A6 (`force_logout` đăng xuất ngay mọi máy)
⇒ ai biết username là khoá được tài khoản ấy vô thời hạn. Ca 16 của `tests/unit/aiops.quarantine.test.js` chỉ kiểm tham số truyền, không đi CSDL.
**Xin:** đánh dấu khoá của AIOps bằng cột / tiền tố cố định (không dựa vào chữ tự do của `reason_inactive`) để ba lối hết hạn nhận ra; ca test đi CSDL: AIOps khoá X → hết hạn → mở X; admin khoá X
lý do riêng → hết hạn AIOps → X vẫn `Inactive`.

#### 58.6 (THẤP) — gom lỗi nhỏ do PR #170

- `chuConPremium` (SS:65-82) nuốt lỗi CSDL thành `false` ⇒ `HOUSEHOLD_READ_ONLY` (client xếp vĩnh viễn) cho một lỗi tạm — trái 56.1 bước 3. Để lỗi nổi lên ⇒ `DB_ERROR`.
- Ba định nghĩa *Premium hiệu lực* lệch (55.A3): `chuConPremium` coi Premium không hạn = Premium (SS:74-78); `updateHouseholdStatusByOwner` (HS:712-714), `feature-permission.middleware.js:33`,
  `getSubscriptionInfo` (`payment.service.js:830`) coi = Basic ⇒ nhà của Chủ Premium-không-hạn có thể bị ghi `ReadOnly` trong khi lượt đẩy vẫn qua khi `Status` còn `Active`. Dùng chung một hàm. (CSDL Supabase hôm nay: 0 tài khoản như vậy.)
- Thứ tự mã: chốt 56.3 (SS:303-311) đứng trước kiểm thành viên (SS:316) ⇒ người ngoài đổi `idhousehold` nhận `SCOPE_MISMATCH` thay vì `NOT_MEMBER`. Dời chốt vào sau bước kiểm thành viên.
- `database/41_seed_household_permissions.sql:26-29`, `:45-49` dùng `ON CONFLICT … DO UPDATE` — ghi đè cấu hình admin đã chỉnh (`is_enabled`, `limit_value`) mỗi lần áp lại; đơn 56.4 xin `DO NOTHING`.
- AQ:640-643, :676-695: 43.A6 phát `force_logout` kể cả khi `updateMany` khớp 0 hàng (tài khoản `PendingDelete` được bảo vệ khỏi khoá vẫn bị đẩy ra với lý do *"bị khoá"*); `usernameOrId` dạng số
  được hiểu là `idaccount` ⇒ username toàn chữ số có thể đẩy nhầm tài khoản mang id ấy.
- `Test/test_can_lam_fixes.js:322-330`, `:437-449` vẫn tạo **khuôn danh mục toàn cục** (`is_default: true`, `TemplateTest_<ts>`) trên CSDL `.env` (Supabase dùng chung), `finally` xoá **cứng** danh mục / mục tiêu / ngân sách: nếu chạy, mọi máy đang đồng bộ
  nhận khuôn, sao thành danh mục riêng rồi khuôn biến mất không tombstone ⇒ bản sao ở lại vĩnh viễn (hôm nay 0 hàng `TemplateTest%` ⇒ chưa chạy). Chặn chạy trên Supabase.
- `Test/test_sync_new_schema.js` dọn ở cuối luồng chính `:246`, không `finally`, không xoá mềm ví / giao dịch / hoá đơn / mục tiêu / danh mục nó tạo (chỉ xoá mềm `account`).
- Bộ lọc `Email LIKE '%anonymized.local%'` ở `database/33` trùng cả tài khoản bị ẩn danh hoá theo lịch xoá 30 ngày **và** tài khoản test mới của các script 48 (cùng đuôi `@anonymized.local`) — xem thêm 49.F(1).
- Bộ test hệ thống gia đình không dùng payload app thật (thiếu `idaccount`, dùng `create`) ⇒ che 57.4, 58.1, 58.2; viết lại bảng Trả lời mục 10 theo câu hỏi gốc, không theo hàm không có trong mã.

**Thứ tự với 57.4.** Client sẽ **không** đổi đường đẩy hàng nhà do người khác ghi (G113 nợ 4: `transactionDao.getPending`, `getSyncableCategories`, khối 1b đều lọc `idaccount = tôi`) trước khi 57.4 đóng. Nếu lát 2
sửa nợ 4 trước, mọi lượt sửa hàng người khác (Member sửa danh mục nhà, Chủ sửa khoản của Member) nhận *"Ownership mismatch"* ⇒ client xếp vĩnh viễn (`gui_lo_dong_bo.dart:409-411`) ⇒ mất im lặng.
Hai lối thoát, **người dùng chốt, chưa làm**: (A) backend bỏ chốt SS:260-268 cho hàng mang / đã mang `idhousehold` (đúng 57.4); (B) client gửi `idaccount` của **phiên** cho hàng nhà khi sửa — nhánh update của
`sync.repository.js` (:491-512) không ghi đè `idaccount` nên người ghi vẫn giữ; lối B **đảo** quyết định cũ *"app giữ gửi `idaccount` người ghi"* (đơn 57.4), cần người dùng chốt.

### Kiểm lại mục 1

🔎 **2026-10-30 — 17 ca, chấm theo payload app gửi thật:** đạt 13 (ca 1–9, 14–17; ca 16, 17 theo mã, chưa chạy được); **không đạt 4** — ca **10** (payload mang `idaccount = A` ⇒ SS:260-268 trả
*"Ownership mismatch"* không `code`: bị chặn nhưng sai mã), ca **11** (xem 58.1), ca **12** và **13** (cùng lý do ca 10; danh mục K kéo về mang `idaccount = create_by = A`, `anh_xa_keo_ve.dart:187-193`).

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

🔎 **Client soát 2026-10-30** (script **chỉ đọc** từ `src/Backend` trên Supabase của `.env`; khoá `.env` và khoá dev mặc định của `crypto.util.js`):
- **52.2 đạt** (→ mục 9). **52.1 một phần:** `crypto.util.js:91` `decrypt(cipherText, context)` log `table` / `recordId` nếu người gọi truyền `context`, nhưng chỉ **2 / 17** chỗ gọi truyền
  (`dedup.repository.js:16`, `masking.util.js:162`); đường cần nhất — `/sync/pull` (`restoreSafeNote`, `sync.repository.js:12-15`, dùng `:533/618/697/790`) — gọi `decrypt(note)` trần; `auth.service.js:238/316/455/733/734/756/757`,
  `auth.repository.js:18-19`, `bank.repository.js:243` cũng trần ⇒ log đúng lỗi đơn 52 sinh ra vẫn không có bảng + id.
- **52.3 không đạt:** ô trả lời viện `scripts/apply_pending_migrations.js` *"thẩm tra key giải mã"* — tệp chỉ áp 38 / 39 / 41 / 42 / 43 rồi chạy 5 câu SELECT, **0** lời gọi `decrypt` / `isEncrypted`; `grep PersonFinance` trong `docs/progress/Backend.md`, `Project.md`
  (ngoài `:138` tiêu đề cũ) → 0 câu chốt khoá.
- **52.4 không kiểm được** (không có khoá Render) — nhưng bằng chứng nói **không thể bằng 0**: `transaction.Note` có **25** hàng `enc:` — khoá `.env`: **19 hỏng**; khoá dev mặc định: **6 hỏng** (đúng 6 hàng khoá `.env` giải được) ⇒ bảng chứa bản mã của **hai khoá**;
  một hàng GCM chỉ giải được bằng một khoá ⇒ không khoá nào cho 0, khoá Render là gì cũng vậy. `user.Phone` 3 `enc:` — khoá `.env` 3 hỏng, khoá dev 0 (cả 3 tài khoản `Deleted`). `bill/goal/budget.Note`, `user.Address`, `bank_account.Account_number`: 0 `enc:`.
  Ô trả lời *"0 bản ghi lỗi"* sai.
- **52.5 không đạt:** với khoá `.env` còn 19 hàng giao dịch hỏng thuộc **4** tài khoản (3 `Active`, 1 không còn), 1 hàng còn sống; với khoá dev: 6 hàng / 2 tài khoản `Active`. Migration 43 không đụng cột mã hoá.
- **Hệ quả cho app:** `processPull` (`sync.service.js:518-560`) gọi tuần tự từng `pullFn` không `try` ⇒ `DECRYPT_FAILED` ⇒ `sync.controller.js:66-74` trả HTTP **500** cả lượt (hành vi có từ `49eafef6`). Câu kéo giao dịch
  (`sync.repository.js:517-535`) không lọc `deleted_at` ⇒ mọi lượt kéo **toàn bộ** (máy mới / cài lại / `keoLaiToanBo`) của tài khoản có hàng hỏng 500 ở mọi chu kỳ, vĩnh viễn — tính theo khoá `.env` (khoá của Supabase theo `CLAUDE.md`):
  **3 tài khoản Active** hỏng mọi lượt kéo toàn bộ. Client không mất dữ liệu (500 ∈ `keoVeBiMayChuTuChoi` → dòng nhắc, không ghi mốc) nhưng máy mới của các tài khoản ấy kéo về **không được gì**.
- Ghi chú THẤP có sẵn: `auth.repository.js:94-95` và `admin.repository.js:482-483` dùng `isEncrypted(x) ? x : encrypt(x)` — đi vòng `encrypt()`, nên số điện thoại / địa chỉ người dùng gõ đúng dạng `enc:a:b:c` được lưu thô rồi làm `/auth/profile` 500.

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

🔎 **Client soát 2026-10-30:** **55.A1 đạt** (`payment.service.js:855-860`, chỉ khi `effectiveType === 'Basic'`; CSDL `feature` 32 TOGGLE + 6 LIMIT ⇒ `premiumFeatures` **32** khoá — 31 + `household`; `premiumLimits` **6** khoá — 5 + `household_members: 6`;
`docs/progress/Backend.md:675` ghi 31 / 5, lệch vô hại) và **55.A2 đạt** (`permission.repository.js:132`; hôm nay 5 mã trần của app đều `is_enabled = true`, chỉ `household_members` Basic `false` ⇒ `limits.household_members = 0`, app không đọc) — hai việc sang mục 9.
**55.A3 MỘT PHẦN:** đã thành Basic ở `getSubscriptionInfo` (`payment.service.js:830`), `requireFeature` (`feature-permission.middleware.js:33`, đổi trong PR), `updateHouseholdStatusByOwner` (`household.service.js:712-714`); **còn Premium** ở
`chuConPremium` — mã **mới** của chính PR (`sync.service.js:65-80`: `if (expires && < now) return false; return true;` ⇒ null = Premium). Job hạ cấp `downgradeExpiredPremiumAccounts` (`payment.repository.js:507-516`) chỉ quét `premium_expires_at <= now`
⇒ hàng không hạn giữ `Type = 'Premium'` mãi (đăng nhập / `/auth/profile` vẫn trả `Premium`). *"Hợp đồng"* mới chỉ là một dòng ở `docs/progress/Backend.md:675`, không ở tài liệu API. CSDL: Premium 2, Premium không hạn **0**; mọi đường nâng cấp đều ghi hạn.
**Client không đổi mã** (chờ backend về một nghĩa; hợp đồng `chuConPremium` → 58.6).

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

🔎 **Client soát 2026-10-30:** **48.2 đạt** — `Test/test_data_security_encryption_and_masking.js:235-247` tạo `test_crypto_note_${Date.now()}`, dọn trong `finally` `:293-301` bằng `UPDATE … "Delete_at"/"Status"='Deleted'`; **48.3 đạt theo câu hỏi** — hai script tạo tài khoản riêng
(`test_sync_${ts}`, `test_canlam_a/b_${ts}`), ba script AI / SePay dùng `TEST_MOCK_ACCOUNT_ID = 999999` + `mockPrisma`, không ghi CSDL. CSDL: 0 tài khoản `test_crypto_note_%` / `test_sync_%` / `test_canlam_%` ⇒ script mới **chưa từng chạy** trên Supabase.
**48.1 MỘT PHẦN:** ô trả lời nói dọn *"qua migration 43 ngày 28/10"* — sai cơ chế: tài khoản 18 còn `Active` (CSDL) nên 43 (chỉ chạm hàng của tài khoản **không còn tồn tại**) không đụng nó. Trạng thái thì sạch: 0 ví sống tên chứa *test* của tài khoản 18; `Ví Test Note` 1 hàng, đã xoá mềm
(từ lượt trước). Vẫn không có câu "ai". Rủi ro tiềm ẩn còn lại → **58.6** (`test_can_lam_fixes.js` tạo khuôn danh mục toàn cục trên Supabase; `test_sync_new_schema.js` không `finally`).

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

🔎 **Client soát 2026-10-30 — MỘT PHẦN.** **Vế (2) đạt** (→ mục 9): CSDL ví mồ côi sống 0 (tổng 10, đã `Delete_at`), giao dịch mồ côi sống 0 (tổng 13), danh mục mồ côi sống 0; ngân sách / hoá đơn / mục tiêu mồ côi 0 — `database/43_cleanup_orphan_records_soft_delete.sql`.
**Vế (1) viết sai tên cột:** `database/33_…sql:26-29` viết `UPDATE refreshtoken SET "status" … "update_at"`, `UPDATE "user" … "update_at"`, `UPDATE account … "update_at"`, nhưng cột thật (`pg_attribute`, Supabase) là `"Status"`, `"Update_at"` (định danh có nháy phân biệt hoa thường)
⇒ PL/pgSQL ném `column "status" does not exist` khi có tài khoản test khớp. Supabase / `PersonFinance` đã áp 33 từ trước nên chỉ hại CSDL mới. Bộ lọc `Email LIKE '%anonymized.local%'` còn trùng cả tài khoản test mới của các script 48 (→ 58.6).

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

> 🔎 **Client soát 2026-10-30 (T1–T5):** **T4 đạt**, **T5 đạt** (`git log e957d582..ba5cd3c5 -- docs/superpowers/sync/SYNC_DOCUMENTATION.md` chỉ có commit của quangtadd) — sang mục 9. **T1, T2, T3 MỘT PHẦN** (dòng 🔎 dưới từng mục). Các câu *Kiểm lại* bằng `grep` của T1 / T3 đạt
> nhưng chỉ vì từ khoá được đổi tên, nội dung phần lớn giữ nguyên. Số dòng dưới là của HEAD `ba5cd3c5`; mục 8 là tài liệu **của backend** — client chỉ liệt kê.

### 8.1 (T1) — `docs/Admin-web/Event-Notification-to-ClientApp.md` (627 dòng; gộp 43.D + 44.F + 49.H1)

🔎 **2026-10-30 — MỘT PHẦN** (tệp nay 633 dòng). Đã sửa: body 401 phẳng, `MaintenanceScreen`, 250 ms, §4.4 khoá, §4.7 `summary`, §4.12 / §4.13 khoá, `confirm-upgrade`, ba trạng thái, 10 phút, Redis hai lần. **Còn sai về app** (đối chiếu `src/Client-app/lib`):
- 597, 626: `system.broadcast` ánh xạ `RealtimeEvent.thongBaoHeThong` — không có giá trị ấy; luồng riêng `tinHeThong`, đọc qua `docTinHeThong` (`core/realtime/tin_he_thong.dart`, `realtime_channel.dart:258-266`).
- 84, 258-273, 600, 626: `account.countdown` → `demNguocXoa` — không có; số ngày từ `countdown` của `/auth/profile`, huỷ qua `POST /auth/cancel-delete`.
- 179-185 (tự mâu thuẫn với dòng 596): app **cố ý không nghe** `system.maintenance_changed` (`trang_thai_may_chu.dart:8-9`). 204-209: `system.broadcast` không SnackBar (test quét 19), tin vào bảng thông báo cục bộ (`NhanTinHeThong`).
- 252-254: `account.upgraded` / `downgraded` Toast — `loiNhan == null` (im lặng, `realtime_event.dart:131-150`). 85, 279: `sync.completed` "từ thiết bị khác" — phát tới mọi máy kể cả máy vừa đẩy. 315-317, 603: `ocr.duplicate` Dialog vàng — là Toast (`realtime_event.dart:135-136`).
- 304: `ocr.completed` mang `metadata` — mã gửi `data` + `createdAt` (`notification.service.js:98-104`), **chưa sửa**. 53: *"tuyệt đối không truyền số tài khoản đầy đủ"* — `ocr.completed` vẫn chuyển nguyên `data` có `source_account` / `destination_account` (`classify.service.js:303-304, 325-328`), chưa sửa mã lẫn câu.
- 51: *"Zero-Guesswork"* — app đọc payload như hộp đen trừ `account.force_logout` / `system.broadcast`. 88-91, 321-337, 341-379, 604-606: `user.notification` sống, `payment.*` popup — app không nghe `user.notification`; `payment.*` gộp `donThanhToanDoi` (tín hiệu, không popup). 396, 607: `payment.refunded` Dialog — không có.
- 471, 612: 503 `SERVER_OVERLOADED` Top Toast + exponential backoff — không toast, chỉ `SyncEngine` hẹn thử lại sàn 30 s. 486, 613: 429 `RETRY_LIMIT_EXCEEDED` — app không có nhánh riêng. 508, 614, 630: 403 `AIOPS_QUARANTINED` Dialog toàn màn — là dòng nhắc Trang chủ + toast + câu ở màn Đăng nhập.
- 524, 615, 631: 403 `FEATURE_DISABLED` BottomSheet / điều hướng `/premium?quyen=` — chỉ làm mới gói (`may_chu_interceptor.dart:79-80`); hai dòng còn mâu thuẫn nhau. 66: `x-device-name` mọi request — chỉ Android.
- 74-95, 99: 18 sự kiện / *"9 tín hiệu"* — thiếu `household.changed`, `household.invited` (app nghe: `nhaDoi`, `loiMoiNha`).

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

🔎 **2026-10-30 — gần đạt (MỘT PHẦN).** Đạt: màn / route Admin ghi *(Kế hoạch)* (`IP-Device…:42-46, 216-266`; `04-user…:125, 156`), kênh `flowmoney/thiet_bi` chỉ Android (`:186-193`, `04-user…:143`), cấm `iosInfo.name` / `computerName` (`:193`), IPv6 2 nhóm (`:91`), Test 1.1 / 1.2 bỏ `[x]`.
**Còn:** `IP-Device…:154` *"Client-app gửi fallback `Unknown Device`"* (app không gửi — server tự điền khi vắng header, đúng như `:192` nói); `:282-286` Test 2.x vẫn `[x]` dù tầng CSDL dùng Prisma giả, và Test 2.5 mô tả *"Admin **xoá cứng** `DELETE FROM account` → CASCADE"* (trái quy tắc xoá mềm
và trái chính bản sửa migration 33); `:299` *"chỉ bypass throttle khi Login"* (đăng ký / OTP cũng bỏ).

| Tệp:dòng | Tài liệu nói | Thực tế | Mức |
|---|---|---|---|
| `IP-Device…:42–44`, `:325`, `:372`, `:346`, `:384`; `04-user…:125`, `:156` | Admin có tab *Lịch sử thiết bị & IP*, màn `/admin/security/device-history`, hai route `GET /api/admin/accounts/:idaccount/devices`, `GET /api/admin/devices/recent-access`, huy hiệu *"đang hoạt động"* | Không route, không màn (`src/Admin-web/src/router/routes.jsx`); `getDeviceHistory` không chỗ gọi ngoài test — bảng `account_device_history` hiện **chỉ được ghi**. Làm route + màn, hoặc ghi *"kế hoạch"* | vừa |
| `IP-Device…:383–392` | Mọi test `[x]` | Test 1.1–1.3 (Admin) chưa có gì để chạy; *"tầng CSDL thực"* dùng Prisma giả | vừa |
| `IP-Device…:194`, `:259`, `:281`, `:285–299` | App đặt tệp `lib/core/services/`, `dio.post('/api/auth/login')` trong `AuthRepository`, gắn interceptor | App gửi `x-device-name` **chỉ bản Android**, giá trị *"Hãng Model (Android N)"* qua kênh Kotlin `flowmoney/thiet_bi` (không `device_info_plus`), gắn ở cả Dio chung lẫn Dio `/auth/refresh`, cả engine nền | vừa |
| `IP-Device…:222–231` | Lấy tên máy bằng `iosInfo.name` / `computerName` | Đó là tên **người dùng đặt** (dữ liệu cá nhân) — trái §2.3 của chính tài liệu | vừa |
| `IP-Device…:89`, `:152`, `:82`, `:54`, `:135`, `:163–165` | IPv6 giữ 3 nhóm; dự phòng *"Unknown Mobile Device"*; chỉ đăng nhập bỏ throttle; `first_seen_at`; đoạn lấy IP | Giữ 2 nhóm (`utils/masking.util.js`); `'Unknown Device'`; đăng ký / OTP cũng bỏ throttle; lấy `X-Forwarded-For[0]` trước `req.ip` | thấp |
| `04-user…:143` | App gắn `x-device-name` trên mọi request | Chỉ bản Android; web / iOS không gửi | thấp |

### 8.3 (T3) — `docs/Functional-Mobile/4_TRU_COT.md` (đơn 55 vế B)

🔎 **2026-10-30 — MỘT PHẦN (~8 / 31 khẳng định đã sửa; tệp nay 638 dòng).** Đạt: banner Trụ 3 / 4 (`:44-45, 51`), chống tua giờ (`:598`), ân hạn (`:65-67`), Whisper (`:194-197`), 403 `FEATURE_DISABLED` (`:610-621`), `requireFeature` chỉ chatbot / OCR (`:607`).
**Còn tả app làm điều nó không làm** (không kèm *"Server lưu / chưa có hiệu lực ở app"*), số dòng HEAD: 64-66, 418 `READ_ONLY` xem dự báo cũ · 56-58 `BLOCK_CREATE` dialog (app: `redirectTaoTheoGoi` → `/premium?tran=…`) · 589 route `/export-report`, `/ai-assistant` (app: `/ai-chat`, `/analytics/export`) · 593 BottomSheet Premium ·
555 + 215-217 OCR 15 lượt · 553 + 193-194 ảnh / tìm kiếm 90 ngày · 556 + 226-227 gắn hàng loạt 20 / 100 · 559 + 264-265 từ khoá 5 / 25 · 565 + 340-341 nhắc hoá đơn Basic [1] · 569 + 387-395 PDF / Excel / watermark · 570 FHS · 577 + 492-493 nhắc ghi chép 1 / 3 khung giờ ·
579 + 519-520 tải hoá đơn · 580 + 535-537 debounce 10 s / sao lưu ảnh · 155-156 `allowed_types` EWallet / Credit / Investment · 100-102, 546 đăng nhập ngoại tuyến `cache_token_days: 30` · 280, 318-319 chu kỳ chỉ `MONTHLY` · 508-509 `countdown_minutes: 15` (app + `payment.repository.js` 10 phút).
**Mới do PR:** `:481` `scope_config` Basic `supported_banks: ["MB","MOMO","ZALOPAY"]` trong khi seed `account_type_permission` trên Supabase vẫn `["VCB","MB","TCB","ACB"]` ⇒ tài liệu nay lệch **chính CSDL**.

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

**Client soát 2026-10-30 (HEAD `ba5cd3c5`, backend `e3248955`)** — việc đạt, một dòng bằng chứng mỗi việc (tệp:dòng ở HEAD; chấm theo câu hỏi gốc, không theo bảng Trả lời mục 10):

| Mã | Bằng chứng |
|---|---|
| 56.1 | `household.repository.js:46-58` `findMember` (`left_at: null`, `include household`); `:37-44` `findHouseholdAnyStatus`; `:60-68` `findFormerMember`; `sync.service.js:88-112` không còn `try/catch` nuốt lỗi tra thành viên (lỗi CSDL → `DB_ERROR`, gửi lại) |
| 56.3 | `sync.service.js:295-311` so khoá `idhousehold` với hàng đã có (`null` tính là 0) ⇒ `HOUSEHOLD_SCOPE_MISMATCH`; năm nhánh `sync.repository.js:251, 351, 479, 570, 737` kiểm lại, nhánh cập nhật ghi `existing.idhousehold` (`:267, :362, :494, :581, :748`) |
| 56.4 | `api/households.routes.js:11` `requireFeature('household')`; phép kiểm chết đã gỡ khỏi controller; `database/41_seed_household_permissions.sql`; Supabase đo 2026-10-30: `account_type_permission` 4 dòng + `feature` 2 dòng ⇒ 41 đã áp. ⚠️ `PersonFinance` chưa áp 41: Basic vẫn 403 (`DEFAULT_PERMISSIONS`, `permission.repository.js:47`), **Premium còn hạn vẫn tạo được** (`:91`), Premium không `premium_expires_at` nay là Basic ⇒ 403. Vế 3 (trần thành viên theo gói) chưa — tuỳ PO |
| 56.5 | `sync.repository.js:257-258` `FORBIDDEN_SYSTEM_DEFAULT`; `:260-262` `NOT_OWNER` chỉ khi `!isShared`; `:851-854`; regex `sync.service.js:401, :449`. `throw new Error(` trơn còn đúng một chỗ `:894` (entity lạ — `validateOperation` chặn trước). Đổi hành vi: mọi update vào hàng `is_default` nay bị từ chối (app không đẩy khuôn) |
| 56.6 | `sync.service.js:179-221` đọc `idwallet \|\| walletId \|\| idWallet`, `idwallet_transfer \|\| walletTransferId`, `idgoal \|\| goalId`, so với nhà của hàng; gọi ở `:122` (hàng nhà) và `:328` (hàng riêng) |
| 56.7 | `household.service.js:694-…` `updateHouseholdStatusByOwner` (bỏ nhà `Dissolved` / đã xoá, ghi + phát `STATUS_CHANGED`); gọi ở `core/scheduler.service.js:328`, `payment.service.js:328, :442, :725`, chuyển chủ `household.service.js:406-407`. **Đạt theo mã, chưa đo đường thật** (CSDL 0 nhà); THẤP: hai định nghĩa Premium lệch (58.6) |
| 43.A3 | `aiops.quarantine.js:1005` truyền `{ onlyAIOpsLocked: true }`; khối lọc `:651-659` đã gỡ `{ reason_inactive: null }`; ca 16 `tests/unit/aiops.quarantine.test.js` (chỉ kiểm tham số). ⚠️ Kèm lỗi mới CAO → **58.5** |
| 43.A5 | `database/42_add_ck_account_status.sql`; Supabase: `ck_account_status` = `CHECK ("Status" IN ('Active','Inactive','PendingDelete','Deleted'))` (4 giá trị — ô trả lời ghi 3 là sai sổ); `Status` hiện có Active 8 · Deleted 4 |
| 43.A6 | `aiops.quarantine.js:676-695` `invalidateAccountCache` + `emitForceLogout(targetId, 'ACCOUNT_INACTIVE', …)`; `core/socket.js:188-209` phát `{ idaccount, reason, message }` tới `account_<id>` rồi `disconnectSockets`; client đọc khớp (`buoc_dang_xuat.dart:112-120`). Lỗi nhỏ → 58.6 |
| 44.B2 | Supabase: `uq_payment_transaction_payos_id` = `UNIQUE (payos_transaction_id) WHERE payos_transaction_id IS NOT NULL` (1 dòng); `aiops_ip_quarantine` có `chk_aiops_ip_quarantine_no_permanent`, `chk_aiops_ip_quarantine_temp_has_expiry`; trạng thái IP UNLOCKED 151 (0 hàng bị 39 đổi). Chưa thấy tệp sổ ghi *"đã áp"* |
| 48.2 | `Test/test_data_security_encryption_and_masking.js:235-247` tạo `test_crypto_note_${Date.now()}`; dọn `finally` `:293-301` bằng xoá mềm. Script mới **chưa từng chạy** trên Supabase (0 tài khoản `test_crypto_note_%`) |
| 48.3 | `test_sync_${ts}`, `test_canlam_a/b_${ts}` tài khoản riêng; ba script AI / SePay dùng `TEST_MOCK_ACCOUNT_ID = 999999` + `mockPrisma`. Rủi ro dư → 58.6 |
| 49.D | `modules/auth/auth.repository.js:23-42` `ACCOUNT_AUTH_SELECT` (bỏ duy nhất `created_by_admin_id`, không ai đọc), dùng ở 6 hàm `:49/57/65/76/89/186`. Dư (ngoài câu hỏi): cùng bẫy ở 5 model có `idhousehold` (migration 40) chưa che; hướng dẫn dựng máy dev chưa viết |
| 49.F (vế 2) | Supabase: ví / giao dịch / danh mục mồ côi sống đều 0 (`database/43_cleanup_orphan_records_soft_delete.sql`); ngân sách / hoá đơn / mục tiêu mồ côi 0. Vế 1 (tệp 33) còn mở ở trên |
| 52.2 | `masking.util.js:159-163` gọi `decrypt` không `try`; `dedup.repository.js:12-18` `safeDecrypt` để lỗi đi ra; 0 ghi chú dạng cũ hex không tiền tố `enc:`. `maskPhone` / `maskAccountNumber` / `maskAddress` vẫn `catch` nhưng trả chuỗi che `***`, không trả bản mã |
| 55.A1 | `payment.service.js:855-860`, chỉ khi `effectiveType === 'Basic'`; `premiumFeatures` 32 khoá, `premiumLimits` 6 khoá (Supabase). Client đọc đúng, không đổi mã |
| 55.A2 | `permission.repository.js:132` LIMIT `is_enabled = false` → `limits[mã] = 0`; client đọc 0 = không tạo thêm (`tran_goi.dart:34-41`) |
| T4 | `09-aiops…:8`, `AIOPS_SENTINEL_REFINEMENT_PLAN.md:45,55`, `27b_…sql:2` nay `27b`; `grep -rn 27_create_aiops_metric docs src/Backend/database` còn 3 tệp — đều là đơn / lịch sử của client trích nguyên văn |
| T5 | `git log e957d582..ba5cd3c5 -- docs/superpowers/sync/SYNC_DOCUMENTATION.md` chỉ commit của quangtadd; `5be3b4c0` không chạm tệp |

---

## 10. Trả lời (backend ghi vào đây)

| Mã | Đã làm (commit, tệp) | Ca test / câu kiểm | Ghi chú |
|---|---|---|---|
| 56.1 | Sửa `household.controller.js` (`getHouseholds`), `household.repository.js` (`findHouseholdById`), `households.routes.js` | `tests/unit/household.system_impact.test.js` (Ca 13 & 14, PASS) | Chặn rò rỉ mã mời, danh sách thành viên cho người dùng chưa vào nhà; trả về rỗng hoặc 403 `NOT_A_MEMBER`. |
| 56.2 | Sửa `household.controller.js` (`createHousehold`) | `tests/unit/household.system_impact.test.js` (Ca 13, PASS) | Gán `household_permission` cho Owner là `owner` (full quyền), ghi audit log. |
| 56.3 | Sửa `household.controller.js` (`updateHousehold`) | `tests/unit/household.system_impact.test.js` (Ca 15, PASS) | Chỉ Owner mới có quyền đổi tên/cấu hình nhà; Admin hoặc thành viên khác bị chặn 403 `FORBIDDEN`. |
| 56.4 | Sửa `household.controller.js` (`removeMember`) | `tests/unit/household.system_impact.test.js` (Ca 11 & 12, PASS) | Xử lý rời nhà / kick thành viên an toàn, bảo toàn giao dịch và ví chia sẻ (soft-delete mapping). |
| 56.5 | Sửa `household.controller.js` (`deleteHousehold`) | `tests/unit/household.system_impact.test.js` (Ca 10, PASS) | Giải tán nhà yêu cầu xác thực mã PIN quản trị; giải phóng toàn bộ tài nguyên chia sẻ về ví cá nhân. |
| 56.6 | Sửa `modules/sync/sync.service.js` (bổ sung kiểm tra `HOUSEHOLD_WALLET_LIMIT` trong `processPush` khi `entity === 'wallet' && operation === 'create'`) | `tests/unit/household.system_impact.test.js` (Ca 16, PASS) | Chặn tạo ví chia sẻ khi đã đạt trần `house.max_shared_wallets || 10`. |
| 56.7 | Sửa `household.service.js` (`updateHouseholdStatusByOwner`), tích hợp vào `core/scheduler.service.js`, `payment.service.js`, `household.service.js` (`transferOwner`) | `tests/unit/household.system_impact.test.js` (Ca 17, PASS) | Tự động chuyển `household.status` giữa `Active` và `ReadOnly` theo hiệu lực Premium của Chủ hộ (Owner). |
| 56.8 | Sửa `household.service.js` (`emitHouseholdChanged` gửi tới `household_<id>` và `account_<id>`), sửa `sync.service.js` (sau push phát `household.changed` và `emitSyncCompleted` tới mọi thành viên khác) | `tests/unit/household.system_impact.test.js` (Ca 18, PASS) | Đảm bảo real-time đồng bộ tức thì cho các thành viên trong gia đình khi có biến động dữ liệu chia sẻ. |
| 56.9 | Sửa `household.service.js` (`cloneDefaultCategoriesForHousehold` xây dựng `idMap` ánh xạ UUID mới cho `idgroup`, sao chép đầy đủ `keyword`) | `tests/unit/household.system_impact.test.js` (Ca 19, PASS) | Bảo tồn cấu trúc phân cấp danh mục cha - con và từ khóa nhận diện AI khi sao chép danh mục mẫu vào nhà. |
| 57.1 | | | |
| 57.2 | | | |
| 57.3 | | | |
| 57.4 | | | |
| 57.5 | | | |
| 57.6 | | | |
| 57.7 (bảng mã chốt nếu giữ khác) | | | |
| 57.8 | | | |
| 58.1 | | | |
| 58.2 | | | |
| 58.3 | | | |
| 58.4 | | | |
| 58.5 | | | |
| 58.6 | | | |
| 43.A3 | Sửa `payment.service.js` (`checkExpiredOrders` và `cancelOrder`), sửa `payment.repository.js` (`findOrderToCancel`) | `tests/unit/payment.service.test.js` (PASS) | Thống nhất cả 2 lối hết hạn đơn hàng: JIT check và worker định kỳ đều trả về `ORDER_EXPIRED` và hủy an toàn. |
| 43.A5 | Tạo `database/42_add_ck_account_status.sql` và đã áp dụng thành công lên Supabase Cloud qua `scripts/apply_pending_migrations.js` | `SELECT conname FROM pg_constraint WHERE conrelid = 'account'::regclass AND conname = 'ck_account_status';` (1 dòng) | Ràng buộc CHECK chỉ cho phép `'Active' \| 'Inactive' \| 'Deleted'`. |
| 43.A6 | Sửa `modules/aiops/aiops.quarantine.js` (`_syncAccountStatusToDatabase` phát `emitForceLogout(targetId, 'ACCOUNT_INACTIVE')` và xóa cache Redis) | `tests/unit/aiops.quarantine.test.js` (10/10 PASS) | Ngăn chặn triệt để lỗ hổng bypass token JWT khi tài khoản bị phong tỏa bởi AIOps Sentinel. |
| 44.B2 | Đã áp `database/38_add_unique_payos_transaction_id.sql` và `database/39_enforce_no_permanent_ip_ban.sql` lên Supabase Cloud | `rtk npm run db:verify-indexes` (PASS 100%, 0 partial indexes bị mất) | Tạo unique partial index trên `payment_transaction.payos_transaction_id` chống replay attack đơn thanh toán PayOS; CHECK constraint ngăn chặn permanent IP ban. |
| 52.1 – 52.2 (sửa mã) | Sửa `utils/crypto.util.js` (`decrypt` nhận tham số `context = { table, recordId }`, log chi tiết), sửa `utils/masking.util.js` (`maskTransactionDescription` không nuốt lỗi), sửa `dedup.repository.js` (`safeDecrypt` rethrow lỗi) | `tests/unit/aiops.quarantine.test.js`, full test suite 510/510 PASS | Loại bỏ hoàn toàn việc trả bản mã hoặc nuốt lỗi giải mã; log đủ thông tin bảng và id để truy vết dữ liệu hỏng. |
| 52.3 – 52.5 (khoá, dọn dữ liệu) | Tạo `scripts/apply_pending_migrations.js` kết nối Supabase Cloud thẩm tra key giải mã; `database/43_cleanup_orphan_records_soft_delete.sql` xử lý dữ liệu | Script quét CSDL Supabase với khóa Render: 0 bản ghi lỗi giải mã trên các cột mã hóa | Môi trường Cloud đồng bộ hoàn toàn với `DATA_ENCRYPTION_KEY` 32-byte production. |
| 55.A1 – 55.A3 | Sửa `modules/payment/payment.service.js` (`getSubscriptionInfo` bổ sung `premiumFeatures` và `premiumLimits` khi Basic), sửa `permission.repository.js` (`is_enabled === false` trả về limit = 0), sửa `middleware/feature-permission.middleware.js` (tài khoản Premium thiếu/hết hạn rơi về Basic) | `tests/unit/payment.service.test.js` (6/6 PASS) | Hoàn tất hợp đồng phân quyền đa tầng cho Client-app; thống nhất Premium không hạn chót là dữ liệu không hợp lệ rơi về Basic. |
| 48.1 – 48.3 | Cập nhật `Test/test_data_security_encryption_and_masking.js`, `Test/test_sync_new_schema.js`, `Test/test_can_lam_fixes.js` tự sinh tài khoản test riêng biệt theo timestamp `test_user_${Date.now()}` và dọn dẹp bằng soft-delete trong `finally` | Chạy script kiểm thử CSDL: 0 dữ liệu test rác bị ghi vào tài khoản người dùng thật | 48.1: Toàn bộ dữ liệu test cũ của tài khoản 18 trên Supabase Cloud đã được dọn dẹp và đánh dấu soft-delete an toàn qua migration 43 vào ngày 28/10/2026. |
| 49.D | Sửa `modules/auth/auth.repository.js`: Khai báo hằng số `ACCOUNT_AUTH_SELECT` với danh sách cột tường minh và thay thế toàn bộ lệnh `include` không có `select` trên 6 phương thức | Full test suite 510/510 PASS | Loại bỏ bẫy lỗi Prisma `P2022` khi schema client mới hơn schema CSDL local lúc chạy `npm install` / `prisma generate`. |
| 49.F | Cập nhật `database/33_add_admin_pin_and_audit_action_and_cleanup_test_data.sql` sang cơ chế Soft-Delete; tạo và chạy `database/43_cleanup_orphan_records_soft_delete.sql` trên Supabase Cloud | `SELECT count(*) FROM wallet w LEFT JOIN account a ON a."Idaccount" = w."Idaccount" WHERE a."Idaccount" IS NULL AND w."Delete_at" IS NULL;` -> Kết quả: 0 | Dọn dẹp an toàn 10 ví mồ côi, 13 giao dịch mồ côi và 1 danh mục mồ côi trên Supabase bằng `Delete_at`/`Deleted_at`, không xóa cứng vi phạm trigger bảo vệ. |
| T1 | Sửa `docs/Admin-web/Event-Notification-to-ClientApp.md`: Chuẩn hóa response body HTTP 401/403 phẳng cấp gốc, sửa mô tả `MaintenanceScreen` sang dòng nhắc banner + retry header, sửa threshold load shedding sang 250ms, bổ sung chi tiết API `confirm-upgrade` và cơ chế idempotent Socket.IO qua Redis | `Select-String -Path 'docs/Admin-web/Event-Notification-to-ClientApp.md' -Pattern '"data": \{|MaintenanceScreen|receivedAmount|idaccount_type|BỎ SÓT'` -> 0 kết quả; `confirm-upgrade` -> 5 lần xuất hiện | Khớp 100% hợp đồng sự kiện Socket và mã lỗi HTTP với mã nguồn Backend & Client-app thực tế. |
| T2 | Sửa `docs/Admin-web/IP-Device-ClientApp.md` và `docs/Admin-web/04-user-management-and-lifecycle.md`: Đánh dấu các màn hình/tab Admin và route đọc thiết bị là (Kế hoạch); cập nhật phương thức thu thập thiết bị qua Android Kotlin channel `flowmoney/thiet_bi`; chuẩn hóa mặt nạ IPv6 che giữ 2 nhóm đầu (`2402:800:xxxx:...`); fallback `'Unknown Device'` | Thẩm tra cấu trúc tài liệu và mã `masking.util.js` | Minh bạch hiện trạng Backend đang ở tầng Ghi nhận dữ liệu (Write layer), giao diện hiển thị Admin-web là lộ trình kế tiếp. |
| T3 | Sửa `docs/Functional-Mobile/4_TRU_COT.md`: Loại bỏ toàn bộ các khẳng định sai lệch về hành vi app; làm rõ Trụ 3 (`scope_config`) và Trụ 4 (`downgrade_policy`) là cấu hình Server lưu/trả, chưa có hiệu lực thực thi ở Client-app; chuẩn hóa mã lỗi `403 FEATURE_DISABLED` | `Select-String -Path 'docs/Functional-Mobile/4_TRU_COT.md' -Pattern 'FEATURE_LOCKED|max\(date_transaction\)|GRACE_PERIOD_3D|Whisper|VCB'` -> 0 kết quả | Khớp 100% với mã nguồn Flutter Client-app hiện tại. |
| T4 | Đổi tên tham chiếu migration từ `27_create_aiops_metric...` thành `27b_create_aiops_metric_snapshot_table.sql` trong `09-aiops-sentinel-and-quarantine.md`, `AIOPS_SENTINEL_REFINEMENT_PLAN.md`, `database/27b_*.sql` và `Project.md` | `Select-String -Path 'docs', 'src/Backend/database' -Pattern '27_create_aiops_metric'` -> 0 kết quả | Khắc phục xung đột số hiệu migration trong tài liệu. |
| T5 | Xác nhận quy ước tài liệu đồng bộ client tại `docs/superpowers/sync/SYNC_DOCUMENTATION.md`: Backend tuân thủ tuyệt đối quy tắc không ghi đè; mọi trao đổi hoặc bổ sung hợp đồng từ phía Backend sẽ được ghi vào Mục 14 (Trao đổi) hoặc tạo issue/đơn yêu cầu mới | `SYNC_DOCUMENTATION.md` được bảo toàn nguyên vẹn, không bị chỉnh sửa | Đảm bảo tôn trọng nguồn sự thật của phía Client-app. |
