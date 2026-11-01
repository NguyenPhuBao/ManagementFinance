# Gia đình — 04. Hợp đồng phần 1 như mã backend đang chạy (đối chiếu cho lát 1 client)

> **Ngày:** 2026-10-28 (phiên 21) · **Phía client viết** · **Người đọc:** client làm lát 1 gia đình; backend tham khảo.
> **Nguồn:** mã backend ở `177dd0e1` (PR #168, gộp `main` @ `7b56d822`) — `api/households.routes.js`, `modules/household/*`,
> `modules/sync/*`, `database/40_create_household_foundation.sql` — đối chiếu `01_NEN_MONG.md` và đơn 50 C. Mọi `tệp:dòng` ở
> `docs/superpowers/backend/CAN-LAM/VIEC_BACKEND_CON_LAI.md` mục 1 (đơn 56 — `/sync/push`, đơn 57 — API của nhà).
>
> Tệp này **không thay** `01_NEN_MONG.md`: `01` là hợp đồng **muốn có** (thắng khi lệch); tệp này là **ảnh chụp** mã đang chạy để
> client biết chỗ nào dựng được ngay, chỗ nào chờ backend. Gộp `main` lần sau thì đo lại, đừng tin bảng này.
>
> 🔎 **Đo lại 2026-10-30 (phiên 24) — backend `e3248955` (PR #170 = `5be3b4c0`, client gộp `ba5cd3c5`), mã đọc ở HEAD `ba5cd3c5`.** Ảnh chụp ban đầu ở `177dd0e1`
> (2026-10-28); phần nào đổi sau PR #170 ghi **🔎 2026-10-30**. Kết quả soát (đạt 56.1, 56.3–56.7; một phần 56.2, 56.8, 56.9 — phần còn ở 58.x / 57.4;
> **đơn 57 chưa làm một việc nào**; lỗi mới do PR → đơn 58); việc còn mở ở `VIEC_BACKEND_CON_LAI.md` mục 0. **Đo lại sau mỗi lần gộp `main`** — ngày đo gần nhất: 2026-10-30 / backend `e3248955`.

> 🔎 **Đo lại 2026-10-31 (phiên 25) — backend `5ff06db4` (PR #172), chạy thật trên bản sao + CSDL tạm, không phải máy thật.** Bảng dưới vẫn là ảnh chụp `e3248955`; chỗ đã khác ở **mục 2a**. Trạng thái việc: `CAN-LAM/VIEC_BACKEND_CON_LAI.md`. **Đo lại sau mỗi lần gộp `main`.**

> 🔎 **Đo lại 2026-10-31 (phiên 27) — backend `8e3b4e48` (PR #174), kịch bản 50 / 50.** Hợp đồng hiện hành ở **mục 2b**, thắng mục 2 và 2a.

## 1. Kết luận cho lát 1

- **Dựng được ngay trên mã hiện tại:** 16 đường dẫn + method (bảng mục 2), migration 40 (ba bảng + cột `Idhousehold` ở 5 bảng, không có
  ở `bill`), khoá đồng bộ `idhousehold` hai chiều (mục 3), bảy mã đẩy vĩnh viễn (đã xếp ở `gui_lo_dong_bo.dart`), `household.invited` tới
  phòng tài khoản ⇒ đủ để dựng `HouseholdApi`, Drift v32 + DAO `IS NULL`, `purgeDataForOtherAccounts(…, nhaGiu)`, `NhaRepository`.
- **Lát 1 mã xong 2026-10-28; từ 2026-11-01 (`9396cd25`) client chỉ đọc MỘT hình dạng lồng** (`nha_cua_toi.dart`: nhánh phẳng và `POST /` thô đã gỡ sau PR #174; chốt `laThanTrangThaiNha` siết ở `821f75a7`: thân `{household: {}}` không còn là "không nhà"). Hình dạng hiện hành ở mục 2b.
- **Model trạng thái nhà dựng theo `01` mục 4** (một hình dạng lồng `household` + `myRole` + `members` + `formerMembers`) — người dùng chốt
  2026-10-28 xin backend theo `docs/Family` (đơn **57.1**), **không** theo hình dạng phẳng của `/me` hiện nay.
- **Chủ nhà sửa khoản của thành viên:** client **giữ** gửi `idaccount` người ghi của hàng (như hiện nay); backend bỏ chốt *"Ownership
  mismatch"* cho hàng của nhà (đơn **57.4**). Gửi `idaccount` người sửa là ghi đè mất người ghi.
- **Chặn nghiệm thu máy thật** *(ảnh chụp `177dd0e1`, 2026-10-28 — xem gạch 🔎 dưới)*: mọi chốt hàng của nhà khi đẩy (56.1–56.6, 57.4), cả đường mời email (57.2 + 57.3), `household.changed`
  không ai nhận (56.8), giải tán không có tombstone (57.6). Lát 1 dọn dữ liệu nhà theo spec 2026-10-23 mục 4.6 **không chờ** cờ xoá từ
  server.
- 🔎 **2026-10-30 — sau PR #170 danh sách chặn rút còn:** **57.1–57.8 (tám việc, chưa làm)**, chốt 57.4 (*"Ownership mismatch"* chặn Chủ nhà sửa khoản của thành viên; ca 10, 12, 13 hỏng với
  payload app thật), 56.2 phần `Transfer` (**58.1**: chốt chỉ ở `operation === 'create'`, app luôn gửi `update`), `HOUSEHOLD_DISSOLVED` không tới ai (**58.3**), `household.changed` phát theo
  `payload.idhousehold` chưa kiểm (**58.4**). Đã hết chặn: 56.1 (`findMember` có thật), 56.3 (đổi `Idhousehold` → `SCOPE_MISMATCH`), 56.4 (Basic bị chặn tạo nhà), 56.5, 56.6, 56.7.
  **Lát 1 không phải đổi mã** (chưa có đường ghi vào nhà; Supabase 0 nhà). Trước khi lát 2 mở đường ghi: 57.4 đóng (rồi mới sửa G113 nợ 4); G113 nợ 9 (số dư ví nhà không được `pending` — 56.2 đã chạy nên vòng `HOUSEHOLD_ROLE_FORBIDDEN` là thật); giãn cách `nhaDoi` (✅ `1227d8a2`). Nên chờ thêm 58.1 / 58.2 (chốt `Transfer` / trần ví chung chết với payload app) và 58.4 (giảm khuếch đại phía server).

## 2. Mười sáu endpoint (như mã — `/api/households`, mọi route qua `authenticate`)

Thành công `{success: true, statusCode, message?, data}`; lỗi `{success: false, statusCode, code, message}` — `code` ở cấp gốc, mặc định
`HOUSEHOLD_ERROR` 500. Cột *Mã lỗi* là tên **hiện có trong mã** (lệch `01` mục 2.5 — đơn 57.7; dựng câu báo lỗi theo bảng mã chốt khi
backend trả lời).

| # | Method · đường | Ai gọi được | Body | `data` khi thành công | Mã lỗi (`code` · HTTP) |
|---|---|---|---|---|---|
| 1 | `POST /` | tài khoản chưa ở nhà **và** có quyền `household` — 🔎 2026-10-30 route gác `requireFeature('household')` (`households.routes.js:11`): Basic → 403 `FEATURE_DISABLED` (cấp gốc thân, `core/response-handler.js:50-59`; client đã map `tinhNangKhongMo`, `cau_loi_nha.dart:74`); nếu CSDL **chưa áp migration 41** (`PersonFinance`: chưa áp 41–43 — chưa có phép đích danh, chưa đo): Basic vẫn 403 nhờ `DEFAULT_PERMISSIONS`, Premium còn hạn **vẫn tạo được**, Premium không `premium_expires_at` bị coi Basic ⇒ 403 | `{name}` 1–100 ký tự (trần nhà vẫn đọc được từ body — 57.5) | 201 — hàng thô + `myRole` (→ 57.1; **không đổi** 2026-10-30) | `INVALID_HOUSEHOLD_NAME` 400 · `HOUSEHOLD_ALREADY_IN_ONE` 409 · `FEATURE_DISABLED` 403 |
| 2 | `GET /me` | mọi tài khoản | — | `{household: null}` hoặc hình dạng phẳng (→ 57.1) — 🔎 2026-10-30 **không đổi**: `household.service.js:151-163`, không nhà `{household: null}` (`household.controller.js:51`; `data` không bao giờ `null`); nhà đã giải tán cũng `{household: null}` (`:125`) | — |
| 3 | `POST /invites` | Owner, nhà `Active`, còn chỗ | `{role?: Member\|Viewer}` | 201 `{code, role, expiresAt}` — 8 ký tự, 48 giờ | `INVALID_INVITE_ROLE` 400 · `FORBIDDEN_NOT_OWNER` 403 · `HOUSEHOLD_NOT_ACTIVE` 400 · `HOUSEHOLD_FULL` 409 |
| 4 | `GET /invites` | Owner | — | `[{code, role, email\|null, createAt, expiresAt, status}]` — `status` ∈ `Pending · Declined · Revoked · Used · Expired` | `FORBIDDEN_NOT_OWNER` 403 |
| 5 | `DELETE /invites/:code` | Owner của nhà có mã | — | `{revoked: true}` | `HOUSEHOLD_INVITE_NOT_FOUND` 404 · `FORBIDDEN_NOT_OWNER` 403 |
| 6 | `GET /invites/:code` | mọi tài khoản (lời mời email: hiện **luôn 403** — 57.2) | — | `{householdName, ownerName, memberCount, maxMembers, role, expiresAt}` | `HOUSEHOLD_INVITE_INVALID` 404 · `_USED` 409 · `_EXPIRED` 400 · `_WRONG_ACCOUNT` 403 |
| 7 | `POST /join` | chưa ở nhà | `{code}` (cắt trắng, chữ hoa) | như #2 có nhà | `INVALID_INVITE_CODE` 400 · `HOUSEHOLD_ALREADY_IN_ONE` 409 · `_INVALID` 404 · `_USED` 409 · `_EXPIRED` 400 · `HOUSEHOLD_FULL` 409 |
| 8 | `PATCH /members/:idaccount` | Owner; đích ở cùng nhà, khác mình | `{role: Member\|Viewer}` | `{targetIdaccount, newRole}` | `INVALID_MEMBER_ROLE` 400 · `CANNOT_CHANGE_OWNER_ROLE` 400 · `FORBIDDEN_NOT_OWNER` 403 · `MEMBER_NOT_IN_HOUSEHOLD` 404 |
| 9 | `POST /transfer-owner` | Owner; đích ở cùng nhà | `{idaccount}` | như #2 (của chủ cũ, nay Member) | `INVALID_TARGET_USER` 400 · `CANNOT_TRANSFER_TO_SELF` 400 · `FORBIDDEN_NOT_OWNER` 403 · `TARGET_NOT_IN_HOUSEHOLD` 404 |
| 10 | `DELETE /members/:idaccount` | Owner; đích khác mình | — | `{removed: true}` | `CANNOT_REMOVE_SELF` 400 · `FORBIDDEN_NOT_OWNER` 403 · `MEMBER_NOT_IN_HOUSEHOLD` 404 |
| 11 | `POST /leave` | Member / Viewer | — | `{household: null}` | `NOT_IN_HOUSEHOLD` 404 · `OWNER_CANNOT_LEAVE` 400 |
| 12 | `POST /dissolve` (đơn 50 viết `DELETE /`) | Owner | — | `{dissolved: true}` | `FORBIDDEN_NOT_OWNER` 403 |
| 13 | `POST /invites/email` | Owner, nhà `Active` | `{email, role?}` | 202 `{sent: true, email, role, expiresAt}` — 7 ngày; luôn cùng hình dạng (thư hiện **không** gửi — 57.3) | `INVALID_EMAIL` 400 · `INVALID_INVITE_ROLE` 400 · `FORBIDDEN_NOT_OWNER` 403 · `HOUSEHOLD_NOT_ACTIVE` 400 · `HOUSEHOLD_INVITE_RATE_LIMIT` 429 (20 / 24 giờ **hoặc** 5 / giờ) · `HOUSEHOLD_FULL` 409 |
| 14 | `GET /invitations` | mọi tài khoản | — | `[{code, householdName, inviterName, role, expiresAt}]` — hiện chỉ lời mời đã gắn `Invitee_idaccount` (57.2) | — |
| 15 | `POST /invitations/:code/accept` | như #7 | — | như #2 | như #7 |
| 16 | `POST /invitations/:code/decline` | người được mời | — | `{declined: true}` | `HOUSEHOLD_INVITE_INVALID` 404 · `_WRONG_ACCOUNT` 403 |

## 2a. Khác biệt so với bảng mục 2 (đo 2026-10-31 ở `5ff06db4`, gộp với 2b — cập nhật 2026-11-01)

Không có route mới, không đổi đường dẫn. Dòng không nêu là không đổi (#3, #4, #5, #8, #10, #11). Bốn dòng từng 🛑 hỏng ở `5ff06db4` (#12, #14, #15, #16) **đã chạy từ `8e3b4e48`** (mục 2b); cột dưới giữ phần khác biệt còn đúng. Thân #11 thật là `{household: null}` (mục 2b). Hình dạng lồng, mã lỗi chốt, `household.changed` không phát từ đường đồng bộ: đều ở mục 2b — đó là một hợp đồng với bảng này.

| # | Khác ở HEAD |
|---|---|
| 1 | Body chỉ đọc `name` (trần cố định 6 / 10 / 5). `data` 201 là hình dạng **lồng**, hết hàng thô |
| 2 | `data` **lồng** theo `01` mục 4; không nhà: `{household: null, myRole: null, members: [], formerMembers: []}`. `contributionDueDay` nằm trong `household` |
| 6 | Thêm limiter 30 lượt / 15 phút / IP (429). Lời mời email hết *luôn 403*, đúng người xem được. `_EXPIRED` 410. Thêm `_DECLINED` 409. Nhà `ReadOnly` xem được (lỗi, 57.7). Nhà đã giải tán: `_INVALID` 404 |
| 7 | Thêm `requireFeature('household_join')` (403 `FEATURE_DISABLED`; mặc định `true` nên CSDL chưa áp 44 vẫn qua) và limiter. `data` lồng. `_EXPIRED` 410, thêm `_DECLINED` 409. `_WRONG_ACCOUNT` chạy thật. Nhà `ReadOnly` vào được (lỗi, 57.7) |
| 9 | `data` lồng, của chủ cũ |
| 12 | Chạy từ `8e3b4e48`: `{dissolved: true}` (từng 500 ở `5ff06db4`, 57.6) |
| 13 | Email > 100: 400 `INVALID_EMAIL`. Người đang ở nhà: 202 trước cả rate limit và `HOUSEHOLD_FULL`. Thư gửi thật |
| 14 | Chạy từ `8e3b4e48` (từng 500, 57.2): khớp cả email, thêm `maxMembers`, `memberCount` (đếm đúng từ 57.8 #6; màn không hiện) |
| 15 | Thêm `requireFeature('household_join')`. Chạy từ `8e3b4e48` (từng 500, 57.2): như #7, không có limiter |
| 16 | `_INVALID` 404, `_DECLINED` 409, `_USED` 409, `_EXPIRED` 410; lời mời hợp lệ: `{declined: true}` (từng 500, 57.2) |

Đồng bộ (mục 3) ở `5ff06db4`: 57.4, 58.1, 58.2 **đạt, đã chạy thật với payload app** (Member đẩy khoản của Chủ ⇒ `_ROLE_FORBIDDEN`; Member đẩy danh mục nhà ⇒ `synced`; Chủ đẩy khoản của Member ⇒ `synced`, `Idaccount` giữ người ghi; `Transfer` chỉ Chủ, xét vai hiện tại; trần ví chung chạy với `operation: 'update'`). `household.changed` sau `/sync/push` **đã bỏ**, chỉ còn `sync.completed` tới thành viên khác; nhà của sự kiện còn đọc từ payload (58.4). Không mã đẩy mới; `_permanentCodes` không phải đổi. Hàng mới mang `idaccount` khác phiên hiện **vẫn ghi được** (59.1; app không gửi vậy).

## 2b. Hợp đồng ở `8e3b4e48` (PR #174, đo 2026-10-31) — **thắng bảng mục 2 và mục 2a khi lệch**

Đo bằng `CAN-LAM/KIEM-THU/chay_kiem.js` trên bản sao + CSDL tạm: **50 / 50**. Chưa đo trên máy thật. Không có route mới, không đổi đường dẫn.

- **Hết bốn dòng 🛑 của mục 2a:** #12 `POST /dissolve` chạy, trả `{dissolved: true}`, phát `HOUSEHOLD_DISSOLVED` cho từng thành viên. #14, #15, #16 chạy.
- **Hình dạng trạng thái nhà một kiểu lồng** ở #1, #2, #7, #9, #15 (⚠️ #11 `POST /leave` trả thân thật **`{household: null}`** — không có `myRole` / hai mảng; client coi đó là "không nhà", `laThanTrangThaiNha` nhận): `{household: {id, name, status, maxMembers, ownerId, createAt, maxSharedWallets, contributionDueDay} | null, myRole, members: [{idaccount, displayName, role, joinedAt}], formerMembers: [{idaccount, displayName, role, leftAt}]}`. Không nhà: `household: null, myRole: null`, hai mảng rỗng. Thân khác: #8 `{targetIdaccount, newRole}` · #10 `{removed}` · #12 `{dissolved}` · #16 `{declined}`.
- **#14** khớp cả theo email; thêm `memberCount` (đếm đúng) và `maxMembers`.
- ⚠️ **`formerMembers` có thể chứa người đang ở nhà, hoặc một người nhiều lần** (đo 2026-11-02, `PersonFinance`: tài khoản 30 có **3** hàng `household_member` ở nhà 3). Gốc: `addMember` luôn `create` hàng mới (`household.repository.js:17`), mỗi lần rời đặt `Left_at` trên hàng cũ; chỉ có `uq_household_member_active_account` (một hàng sống mỗi tài khoản, `database/40`), không khoá duy nhất theo (nhà, tài khoản); `findFormerMembersByHousehold` trả mọi hàng `Left_at IS NOT NULL`. Client khử trùng khi đọc `/me` (`nhaCuaToiTuJson`: bỏ id đang ở, khử theo id; commit `658edf45`). Đơn backend **64**.
- **Đồng bộ:** `household.changed` **không còn phát sau `/sync/push`** (đã bỏ từ `5ff06db4`, mục 2a; đo lại 2026-11-01 ở client): đường đồng bộ chỉ còn `sync.completed` tới thành viên khác. `household.changed` chỉ phát từ thao tác nhà (vào / rời / mời ra / đổi vai / chuyển chủ / đổi trạng thái / giải tán). Hàng mới mang `idhousehold` phải có `idaccount` = chủ token, không thì `NOT_OWNER` (59.1). `bill` luôn đi nhánh hàng riêng. Client không gửi lệch, không phải đổi mã.

**Bảng mã lỗi chốt (57.7, đối chiếu từng mã với `household.service.js`, `middleware/rate-limiter.js`: khớp):**

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
| `HOUSEHOLD_CLOSED` | 410 | #3, #13 | Nhà đã giải tán. ⚠️ Thực tế khó tới: giải tán đặt `left_at`, Chủ cũ nhận `FORBIDDEN_NOT_OWNER` trước |
| `HOUSEHOLD_ALREADY_IN_ONE` | 409 | #1, #7, #15 | Đang ở nhà khác |
| `HOUSEHOLD_FULL` | 409 | #3, #7, #13, #15 | Đủ người |
| `FEATURE_DISABLED` | 403 | #1, #7, #15 | Gói không có `household` / `household_join` |
| `FORBIDDEN_NOT_OWNER` | 403 | #3, #4, #5, #8, #9, #10, #12, #13 | Không phải Chủ nhà |
| `NOT_IN_HOUSEHOLD` · `OWNER_CANNOT_LEAVE` | 404 · 400 | #11 | Không ở nhà nào · Chủ nhà rời |
| `HOUSEHOLD_INVITE_NOT_FOUND` | 404 | #5 | Huỷ mã không có |
| `MEMBER_NOT_IN_HOUSEHOLD` / `TARGET_NOT_IN_HOUSEHOLD` | 404 | #8, #10 / #9 | Đích không ở nhà |
| `INVALID_HOUSEHOLD_NAME`, `INVALID_INVITE_CODE`, `INVALID_INVITE_ROLE`, `INVALID_MEMBER_ROLE`, `INVALID_TARGET_USER`, `INVALID_EMAIL` | 400 | #1, #7, #3 + #13, #8, #9, #13 | Dữ liệu sai |
| `CANNOT_CHANGE_OWNER_ROLE`, `CANNOT_TRANSFER_TO_SELF`, `CANNOT_REMOVE_SELF` | 400 | #8, #9, #10 | Thao tác lên chính mình / Chủ |

Ngoài bảng chỉ còn `HOUSEHOLD_ERROR` 500 (dự phòng trong mọi `catch` của controller); client đọc là lỗi máy chủ. `HOUSEHOLD_NOT_ACTIVE` đã hết.

**Quyền:** chỉ `household` (#1) và `household_join` (#7, #15) được thi hành. Trần thật lấy từ cột từng nhà (`max_members`, `max_shared_wallets`), client đọc ở `/me`; `limits.household_*` và `scopes` client bỏ qua. Sửa `limit_value` ở Admin-web không đổi trần nhà đang có. Migration 41 và 44 đổi sang `DO NOTHING` sau khi đã áp: CSDL mới và CSDL cũ có thể khác nhau ở `scope_config`, hiện không tác động vì client không đọc.

## 3. Đồng bộ (`/sync/push`, `/sync/pull`)

- **Đẩy:** backend nhận khoá **`idhousehold`** (số hoặc `null`) ở wallet · transaction · budget · goal · category (không ở bill); cũng đọc
  `idHousehold` / `householdId` / `Idhousehold` nhưng app chỉ gửi **một** tên — `idhousehold`. Payload năm thực thể gửi
  `idhousehold` từ lát 1 (normalizer không lọc khoá — không sửa; tập khoá ở `sync_payload_contract_test.dart`).
- **Kéo:** mỗi bảng trả hàng `(Idaccount = tôi ∧ Idhousehold trống) ∨ Idhousehold = nhà tôi`, kèm khoá `idhousehold`. Hàng của nhà mang
  `idaccount` **người ghi** — mọi truy vấn `idaccount.equals` và `purgeDataForOtherAccounts` phải theo spec 2026-10-23 mục 4.6 (1) / 7.2
  (`nhaGiu`, test quét 37).
- **Mã đẩy backend phát:** 🔎 2026-10-30 — **sáu trong bảy mã gia đình nay CHẠY thật** (56.1 / 56.2): `NOT_OWNER` + `HOUSEHOLD_NOT_MEMBER`, `_CLOSED`, `_READ_ONLY`,
  `_SCOPE_MISMATCH`, `_ROLE_FORBIDDEN`, cộng `FORBIDDEN_SYSTEM_DEFAULT` cho hàng khuôn. Tám mã gia đình / quyền backend phát (bảy mã + `FORBIDDEN_SYSTEM_DEFAULT`) khớp từng ký tự với `_permanentCodes`
  (`gui_lo_dong_bo.dart:302-342`) — client không cần đổi. Riêng `HOUSEHOLD_WALLET_LIMIT` đã có mã nhưng **chết với app** (chỉ chạy khi `operation === 'create'`, app luôn gửi `update` — 58.2).
  Lệch nhỏ: người ngoài nhà đổi `idhousehold` của hàng đã có nhận `HOUSEHOLD_SCOPE_MISMATCH` thay vì `_NOT_MEMBER` (chốt 56.3 đứng trước kiểm thành viên — 58.6). Chốt *"Ownership mismatch"* (57.4)
  vẫn trả `error` **không `code`**, client xếp vĩnh viễn (`gui_lo_dong_bo.dart:409-411`).
- **Socket:** `household.changed` — backend phát ở **hai nơi, hai hình dạng**: (a) đổi thành viên / trạng thái nhà `{idhousehold, eventType, payload, timestamp}`;
  (b) sau MỖI `/sync/push` chạm hàng của nhà `{idhousehold, eventType: 'SYNC_COMPLETED', timestamp}` — không có `payload` (`src/Backend/modules/sync/sync.service.js:475-506`, chỉ đọc).
  Client không đọc payload (đo 2026-10-28) — app chỉ đọc tên sự kiện (cam kết hộp đen) rồi gọi
  lại `/me`. 🔎 **2026-10-30 — sự kiện nay tới đúng phòng:** `emitHouseholdChanged` (`household.service.js:662-…`) phát tới phòng **`account_<id>` của từng thành viên** + người nhận thêm
  (`MEMBER_REMOVED` `:430-432`, `MEMBER_LEFT` `:450`); sau `/sync/push` (`sync.service.js:475-506`) phát `household.changed` **và** `sync.completed` (payload `{source: 'household_sync', idhousehold, timestamp}`) tới mọi thành viên **khác**
  ⇒ dữ liệu nhà về gần thời gian thực (client đọc `dongBoXong` → `syncNow()`). Còn thiếu: `HOUSEHOLD_DISSOLVED` không tới ai (`Left_at` đặt trước khi phát — 58.3); nhà lấy từ `payload.idhousehold` chưa kiểm, kể cả op bị từ chối (58.4);
  `household.changed` sau đẩy là thừa (58.4) — ⚠️ **đã bỏ từ `5ff06db4`** (đoạn này là ảnh chụp 2026-10-30, trước PR #172). **Client giãn cách `nhaDoi`:** 30 s giữa hai lượt `lamMoi()` (`kGianCachNhaDoi`, `nha_repository_impl.dart`, commit `1227d8a2`), có một lượt chạy bù cuối cửa sổ; `loiMoiNha` và thao tác của chính máy không qua bộ giãn.
  `household.invited` tới phòng tài khoản — chạy.
- **Mã cặp góp / rút `idfund_pair` (đợt 1A, 2026-11-01, `235be596..3cd7aa5f`)** — phần 2 của hợp đồng đồng bộ, đã chạy trên CSDL thử:
  - Cột `transaction."Idfund_pair"` VARCHAR(36) NULL + chỉ mục từng phần (`database/45_add_transaction_fund_pair.sql`, luỹ đẳng); payload đẩy khoá **`idfund_pair`**, `/sync/pull` trả khoá (chuỗi hoặc `null`). **Migration 45 đã áp `PersonFinance` (sao lưu trước `D:\FlowMoney-saoluu\PersonFinance-truoc-45-2026-11-01.dump`), CHƯA áp Supabase** — việc backend, đơn 63.1.
  - **Server không bao giờ gỡ mã đã gắn** (`mapped.idfund_pair || existing.idfund_pair`, `sync.repository.js`) — spec `02A` mục 11 / spec 2026-11-01 mục 4 từng viết `!== undefined` (cho gỡ); đổi vì máy có cột cục bộ `null` gửi `null` sẽ xoá mã.
  - Mã cặp trên `Transfer` ⇒ `HOUSEHOLD_SCOPE_MISMATCH`. Hàng của nhà có mã cặp: chỉ **người ghi** sửa; Chủ nhà chỉ **xoá** — "xoá" là `operation === 'delete'` (`laXoa`), không đọc `is_deleted` trong payload (đo được chuỗi hai lượt đẩy gỡ mã rồi đổi tiền; client thật luôn xoá bằng op `delete`). Khoản chuyển giữa ví chung chỉ Chủ sửa / xoá.
  - `isNewTx = operation !== 'delete' && !existingRecord` (sửa lỗi có từ trước: trước đó nhánh "mới" bắt cả op `delete`; chốt mới dựa vào nhánh ấy).
  - Kịch bản `CAN-LAM/KIEM-THU/chay_kiem_gia_dinh_2.js` 21 / 21 và hồi quy `chay_kiem.js` 50 / 50 (CSDL `flowmoney_kiem_thu`, đo trong đợt). Ngoài phạm vi, ghi lại: chuỗi khác rỗng khác mã cũ vẫn ghi đè ở `sync.repository.js:519` (chỉ người ghi của hàng; client không có đường này); `sync.service.js:147` `isNewWallet` còn `operation === 'create' || !existingRecord` (client luôn gửi `update`, chưa gặp).
  - Server **chưa** chốt phạm vi danh mục cho khoản của nhà — đơn 63.2.

## 4. Đơn backend viết cho client (`docs/superpowers/client-app/CAN-LAM/GIA_DINH_NEN_MONG.md`) — chỗ không làm theo

Khớp `docs/Family`: 16 đường dẫn, Drift v32 + 5 cột, DAO `IS NULL`, kéo lại toàn bộ sau tạo / tham gia / chấp nhận, dọn dữ liệu nhà khi
rời / giải tán, `household.changed` → `/me`, `household.invited` → danh sách lời mời. Không làm theo:

1. **Cây tệp** (`presentation/screens/`, `domain/entities/`, `domain/repositories/`) — lệch luật vị trí tệp (`KIEN_TRUC_CLIENT_APP.md`
   mục 8, test quét 25). Theo cây ở spec 2026-10-23 mục 7.1.
2. **"toast"** — phản hồi đi qua `baoNhanh` (test quét 19).
3. **`_permanentCodes`** — đã xong (bảy mã, 2026-10-26).
4. Đơn không nhắc đẩy / kéo `idhousehold` và `nhaGiu` — vẫn phải làm (mục 3).
5. Mục 3 #2 tả `/me` theo C.1 — đúng ý `docs/Family` nhưng **sai với mã hiện tại** (đơn 57.1).
6. Mục 3 #6 xem trước lời mời email — hiện trả 403 với mọi người (đơn 57.2).

## 5. Đã kiểm / chưa kiểm

**Đã kiểm (phiên chính, 2026-10-28, trước lát 1):**

- Hai ràng buộc không-partial `uq_wallet_account_name` / `uq_wallet_default_one` → **không còn** trên cả `PersonFinance` lẫn Supabase.
  Chỉ mục unique của `wallet` / `category` nay: `uq_wallet_account_name_active` (`Idaccount, Name` WHERE `Delete_at IS NULL AND
  Idhousehold IS NULL`), `uq_wallet_default_active` (… `Idhousehold IS NULL`), `uq_wallet_household_name_active` (`Idhousehold, Name`
  WHERE … `Idhousehold IS NOT NULL`), `uq_wallet_bank_active`, `uq_category_owner_name` (… `Idhousehold IS NULL`),
  `uq_category_household_name`, `uq_category_default_name`.
- Migration 40 → **đã áp cả hai** (`PersonFinance` + Supabase, 2026-10-28).
- `account.Email` → **0 hàng có chữ hoa** (21 / 21 `PersonFinance`, 12 / 12 Supabase) — phép so email của 57.2 không bị chữ hoa cản;
  Supabase 0 nhà.

**Đã kiểm 2026-10-30 (phiên 24, HEAD `ba5cd3c5`, chỉ đọc):**

- Supabase: `account_type_permission` có 4 hàng (`Basic/household=false`, `Premium/household=true`, `Basic/household_members=false`, `Premium/household_members=true,6`) + `feature` 2 hàng ⇒ **migration 41 đã áp**; 0 nhà. `PersonFinance` **chưa áp 41–43** (chưa có phép đích danh; chưa đo — cần mật khẩu postgres cục bộ; không bắt buộc cho đường tạo nhà — mục 2 hàng #1).
- 17 ca *Kiểm lại mục 1* chấm theo payload app gửi thật: 13 đạt (1–9, 14–17; ca 16, 17 theo mã, chưa chạy được); **4 không đạt** — ca 10, 12, 13 (payload mang `idaccount` người ghi ⇒ *"Ownership mismatch"* không `code`, 57.4) và ca 11 (`Transfer` qua `update` — 58.1).
- Bộ test backend (`household.system_impact.test.js`) payload không có `idaccount` và dùng `operation: 'create'` — không phản ánh app; đừng coi *"test backend xanh"* là bằng chứng.
- Mã lỗi API của nhà (`household.service.js` + `household.controller.js`): tập mã trước / sau PR giống hệt (57.7 chưa làm); `loaiLoiTuMa` (`cau_loi_nha.dart:57-76`) đọc cả hai bộ tên, không cần đổi. `'PREMIUM_REQUIRED'` ở `cau_loi_nha.dart:73` nay là mã chết (vô hại).
- Chưa kiểm: toàn bộ đường ghi vào nhà trên máy thật (không có nhà nào; CSDL 0 nhà).

**Đã kiểm 2026-11-01 phiên 29 (Realme + máy ảo, backend `13fddd09` trên `PersonFinance`):** đủ đường thành viên, thẻ lời mời, thông báo, giải tán, thư qua Brevo. Giải tán nay phát `household.changed` (máy kia tự về sau 3 s); giãn cách `nhaDoi` đo được Realme trễ tới hết cửa sổ 30 s rồi tự đúng. `/invites/email` nhận địa chỉ có dấu (đơn 61.1, client chặn trước từ G116). Bảng: khối 🏠 `PROJECT_CONTEXT.md` mục 14.

**Đã kiểm 2026-11-01 (máy ảo 411 dp, backend `8e3b4e48` trên CSDL tạm; không phải máy thật):** 18 dòng nghiệm thu đạt (16 trọn, 2 một phần). `POST /` trả hình dạng lồng đủ `members` (Tạo nhà ra *1/6*); `/me` không nhà đủ bốn khoá; `POST /leave` trả `{household: null}`; `household.changed` về qua socket (giãn cách `nhaDoi` đo 4,7 s ở cửa sổ đầu, 36 s ở lượt thứ hai); thư lời mời thật chưa đo (backend dev giả lập, ghi `[MOCK EMAIL]`). Mẫu JSON của `ba5cd3c5` (hình phẳng, `POST /` thô) **đã gỡ**: hình dạng hiện hành ở mục 2b, ca hợp đồng ở `test/features/household/data/models/nha_cua_toi_test.dart`.
