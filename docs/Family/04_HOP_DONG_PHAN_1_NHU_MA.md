# Gia đình — 04. Hợp đồng phần 1 như mã backend đang chạy (đối chiếu cho lát 1 client)

> **Ngày:** 2026-10-28 (phiên 21) · **Phía client viết** · **Người đọc:** client làm lát 1 gia đình; backend tham khảo.
> **Nguồn:** mã backend ở `177dd0e1` (PR #168, gộp `main` @ `7b56d822`) — `api/households.routes.js`, `modules/household/*`,
> `modules/sync/*`, `database/40_create_household_foundation.sql` — đối chiếu `01_NEN_MONG.md` và đơn 50 C. Mọi `tệp:dòng` ở
> `docs/superpowers/backend/CAN-LAM/VIEC_BACKEND_CON_LAI.md` mục 1 (đơn 56 — `/sync/push`, đơn 57 — API của nhà).
>
> Tệp này **không thay** `01_NEN_MONG.md`: `01` là hợp đồng **muốn có** (thắng khi lệch); tệp này là **ảnh chụp** mã đang chạy để
> client biết chỗ nào dựng được ngay, chỗ nào chờ backend. Gộp `main` lần sau thì đo lại, đừng tin bảng này.

## 1. Kết luận cho lát 1

- **Dựng được ngay trên mã hiện tại:** 16 đường dẫn + method (bảng mục 2), migration 40 (ba bảng + cột `Idhousehold` ở 5 bảng, không có
  ở `bill`), khoá đồng bộ `idhousehold` hai chiều (mục 3), bảy mã đẩy vĩnh viễn (đã xếp ở `gui_lo_dong_bo.dart`), `household.invited` tới
  phòng tài khoản ⇒ đủ để dựng `HouseholdApi`, Drift v32 + DAO `IS NULL`, `purgeDataForOtherAccounts(…, nhaGiu)`, `NhaRepository`.
- **Model trạng thái nhà dựng theo `01` mục 4** (một hình dạng lồng `household` + `myRole` + `members` + `formerMembers`) — người dùng chốt
  2026-10-28 xin backend theo `docs/Family` (đơn **57.1**), **không** theo hình dạng phẳng của `/me` hiện nay.
- **Chủ nhà sửa khoản của thành viên:** client **giữ** gửi `idaccount` người ghi của hàng (như hiện nay); backend bỏ chốt *"Ownership
  mismatch"* cho hàng của nhà (đơn **57.4**). Gửi `idaccount` người sửa là ghi đè mất người ghi.
- **Chặn nghiệm thu máy thật:** mọi chốt hàng của nhà khi đẩy (56.1–56.6, 57.4), cả đường mời email (57.2 + 57.3), `household.changed`
  không ai nhận (56.8), giải tán không có tombstone (57.6). Lát 1 dọn dữ liệu nhà theo spec 2026-10-23 mục 4.6 **không chờ** cờ xoá từ
  server.

## 2. Mười sáu endpoint (như mã — `/api/households`, mọi route qua `authenticate`)

Thành công `{success: true, statusCode, message?, data}`; lỗi `{success: false, statusCode, code, message}` — `code` ở cấp gốc, mặc định
`HOUSEHOLD_ERROR` 500. Cột *Mã lỗi* là tên **hiện có trong mã** (lệch `01` mục 2.5 — đơn 57.7; dựng câu báo lỗi theo bảng mã chốt khi
backend trả lời).

| # | Method · đường | Ai gọi được | Body | `data` khi thành công | Mã lỗi (`code` · HTTP) |
|---|---|---|---|---|---|
| 1 | `POST /` | mọi tài khoản chưa ở nhà (Premium **chưa** kiểm — 56.4) | `{name}` 1–100 ký tự | 201 — hàng thô + `myRole` (→ 57.1) | `INVALID_HOUSEHOLD_NAME` 400 · `HOUSEHOLD_ALREADY_IN_ONE` 409 |
| 2 | `GET /me` | mọi tài khoản | — | `{household: null}` hoặc hình dạng phẳng (→ 57.1) | — |
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

## 3. Đồng bộ (`/sync/push`, `/sync/pull`)

- **Đẩy:** backend nhận khoá **`idhousehold`** (số hoặc `null`) ở wallet · transaction · budget · goal · category (không ở bill); cũng đọc
  `idHousehold` / `householdId` / `Idhousehold` nhưng app chỉ gửi **một** tên — `idhousehold`. Payload app **chưa** có khoá này
  (`sync_payload_contract_test.dart`) → lát 1 thêm vào `thu_gom_day.dart` + normalizer + khoá tên trong hợp đồng.
- **Kéo:** mỗi bảng trả hàng `(Idaccount = tôi ∧ Idhousehold trống) ∨ Idhousehold = nhà tôi`, kèm khoá `idhousehold`. Hàng của nhà mang
  `idaccount` **người ghi** — mọi truy vấn `idaccount.equals` và `purgeDataForOtherAccounts` phải theo spec 2026-10-23 mục 4.6 (1) / 7.2
  (`nhaGiu`, test quét 37).
- **Mã đẩy backend phát:** `NOT_OWNER`, `HOUSEHOLD_ROLE_FORBIDDEN`, `HOUSEHOLD_READ_ONLY`, `HOUSEHOLD_SCOPE_MISMATCH`; ba mã
  `HOUSEHOLD_NOT_MEMBER` · `_CLOSED` · `_WALLET_LIMIT` app đã xếp nhưng backend chưa phát (56.2, 56.9).
- **Socket:** `household.changed` `{idhousehold, eventType, payload, timestamp}` — app chỉ đọc tên sự kiện (cam kết hộp đen) rồi gọi
  lại `/me`; hiện phát vào phòng `household_<id>` không ai `join` (56.8). `household.invited` tới phòng tài khoản — chạy.

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

## 5. Chưa kiểm

- Hai ràng buộc không-partial `uq_wallet_account_name` / `uq_wallet_default_one` còn trên CSDL không (migration 40 không `DROP`).
- Migration 40 đã áp `PersonFinance` chưa (CLAUDE.md: chưa).
- `account.Email` lưu chữ thường hay nguyên dạng (ảnh hưởng phép so email của 57.2).
