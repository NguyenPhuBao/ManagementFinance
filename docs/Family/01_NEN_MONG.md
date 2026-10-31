# Gia đình — 01. Nền móng (phần 1): mời bằng email + luật quyền khi đẩy

> **Ngày:** 2026-10-26 · **Trạng thái:** thiết kế người dùng đã duyệt, lát 1 client đã có mã (2026-10-28, phần ngầm — chưa màn; chờ backend đơn 56 / 57) · **Người đọc:** backend, PO, client.
> **Nền:** phần 1 đã có spec `docs/superpowers/specs/2026-10-23-gia-dinh-nen-mong-design.md` và đơn **50**
> `docs/superpowers/backend/CAN-LAM/LICH-SU/GIA_DINH_NEN_MONG.md` — **giữ nguyên** (nhà, thành viên, ba vai, mã mời 8 ký tự / 48 giờ, Premium,
> phạm vi kéo về, `Idhousehold` cho 5 bảng, danh mục của nhà, ba đường dọn dữ liệu). Tệp này chỉ ghi **phần thêm và phần đổi**;
> chỗ lệch với đơn 50 tóm ở mục 6 `00_TONG_QUAN.md`.

---

## 1. Phần 1 gồm gì (nhắc lại một đoạn)

Chủ nhà (Premium) tạo nhà → server sao 13 danh mục mặc định thành danh mục của nhà → Chủ nhà mời người khác (mã mời; nay thêm
email) → người được mời tham gia → máy họ kéo lại toàn bộ dữ liệu một lần (`SyncEngine.keoLaiToanBo`, spec 2026-10-23 mục 11 #1) →
Chủ nhà đổi vai / chuyển chủ / mời ra / giải tán; thành viên rời nhà. Chủ hết Premium ⇒ nhà `ReadOnly`. Khu **Nhà mình** (`/nha`, mục
drawer) là nơi duy nhất hiện dữ liệu của nhà. Chi tiết: đơn 50 mục 3, spec 2026-10-23 mục 3–7, 11.

## 2. Mời bằng email

### 2.1 Người dùng thấy gì

**Chủ nhà — màn *Mời thành viên* (`/nha/moi`)**, hai khối:

1. **Mời qua email** — ô email (tối đa 100 ký tự, như cột `account.Email`), chọn vai *Thành viên* / *Chỉ xem*, nút **Gửi lời mời**.
   Gửi xong: dòng nhắc *"Đã gửi lời mời tới an@…"* — **cùng một câu dù email có tài khoản hay không** (chống dò email).
2. **Mã mời** — như spec 2026-10-23 mục 5.2: chọn vai → *Tạo mã* → mã + hạn + *Chia sẻ* / *Chép mã*.

Dưới cùng: **danh sách lời mời** — mã còn hiệu lực, và lời mời email kèm trạng thái *Đang chờ / Đã từ chối / Hết hạn*; mỗi dòng còn
hiệu lực có nút *Huỷ*. Nhà đủ người ⇒ cả hai nút khoá kèm câu lý do (lời mời còn hiệu lực cũng chiếm chỗ — đơn 50 C.2).

**Người được mời:**

- **Khu Nhà mình** có thẻ **"Lời mời đang chờ"**: tên nhà, người mời, vai, hạn; nút *Chấp nhận* / *Từ chối*. Đang ở nhà khác ⇒
  *Chấp nhận* khoá, câu *"Rời nhà hiện tại trước"*.
- **Trung tâm thông báo**: loại mới *"Lời mời vào nhà"* (nhóm *Gia đình*), chạm ⇒ `/nha`.
- **Thư** tới hộp thư (mẫu ở 2.6) mang **mã mời** — người chưa có tài khoản đăng ký **bằng đúng email ấy** rồi vào *Nhà mình → Tham
  gia bằng mã*, hoặc mở app là thấy thẻ lời mời (server khớp theo email lúc đọc — 2.2).

### 2.2 Luật phía server

- **Một câu trả lời cho mọi email hợp lệ** (`202`): server không cho biết email có tài khoản hay không, đã là thành viên hay chưa.
  Email đã là thành viên đang ở của **chính nhà này** ⇒ vẫn `202`, không tạo lời mời, không gửi thư.
- **Chuẩn hoá email:** cắt khoảng trắng + chữ thường; so với `lower(account."Email")`.
- **Luôn gửi một thư** qua đường gửi thư đang dùng cho OTP (Brevo / Resend). Gửi hỏng ⇒ lời mời vẫn tạo (người được mời có tài khoản
  vẫn thấy trong app); log lỗi, không trả lỗi cho Chủ nhà.
- **Có tài khoản ⇒** điền `Invitee_idaccount` và phát **`household.invited`** tới tài khoản ấy (`emitToAccount`, payload tuỳ backend —
  client chỉ đọc tên sự kiện rồi gọi #14).
- **Chưa có tài khoản ⇒** `Invitee_idaccount` trống; khi người ấy đăng ký bằng email đó, #14 vẫn trả lời mời (khớp theo `Email`).
- **Hạn 7 ngày** cho lời mời email (mã thường vẫn 48 giờ). **Mỗi email một lời mời còn hiệu lực mỗi nhà** — gửi lại ⇒ huỷ lời mời cũ
  (`Revoked_at`), tạo mã mới, gửi thư mới (*làm mới*).
- **Mã trong thư gắn với email:** dùng mã ấy (#7 tham gia, #6 xem trước, #15 chấp nhận) mà email của tài khoản khác email lời mời ⇒
  `403 HOUSEHOLD_INVITE_WRONG_ACCOUNT` — thư bị chuyển tiếp không mở được nhà cho người lạ; #6 cũng không lộ tên nhà cho họ.
- **Trần chống spam:** 20 lời mời email mỗi nhà mỗi 24 giờ (đếm `Create_at`) ⇒ `429 HOUSEHOLD_INVITE_RATE_LIMIT`.
- **Đếm trần thành viên:** thành viên đang ở + mã còn hiệu lực + **lời mời email còn hiệu lực** ≤ `Max_members` (mở rộng đơn 50 C.2).
- **Từ chối** ⇒ `Declined_at`; lời mời không dùng được nữa (`409 HOUSEHOLD_INVITE_DECLINED`); phát `household.changed` tới Chủ nhà để
  danh sách lời mời của họ cập nhật.

> **Backend trả lời 2026-10-31 (đơn 57.8, đối chiếu với mã: khớp):** #7 giữ trần **5 thư / giờ**, tối đa **20 thư / 24 giờ / nhà**, đếm theo nhà. #8 `ON DELETE CASCADE` / `SET NULL` ở `database/40_create_household_foundation.sql` là chủ ý, vì hệ thống xoá mềm và không có đường xoá cứng từ phía người dùng / client.

### 2.3 Dữ liệu (SQL nháp — cùng tệp migration của phần 1 hoặc tệp kế, câu hỏi Q1 `00`)

```sql
ALTER TABLE "household_invite"
  ADD COLUMN IF NOT EXISTS "Email"             VARCHAR(100) NULL,   -- NULL = mã mời thường
  ADD COLUMN IF NOT EXISTS "Invitee_idaccount" INT NULL REFERENCES "account"("Idaccount"),
  ADD COLUMN IF NOT EXISTS "Declined_at"       TIMESTAMP(6) NULL;

-- Một lời mời email còn hiệu lực mỗi (nhà, email). Hết hạn là theo thời gian nên không vào điều kiện chỉ mục —
-- "làm mới" huỷ lời mời cũ trước khi chèn.
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_invite_email_active"
  ON "household_invite" ("Idhousehold", "Email")
  WHERE "Email" IS NOT NULL AND "Used_at" IS NULL AND "Revoked_at" IS NULL AND "Declined_at" IS NULL;

-- #14 tìm lời mời gửi tới tôi theo email.
CREATE INDEX IF NOT EXISTS "idx_household_invite_email"
  ON "household_invite" ("Email") WHERE "Email" IS NOT NULL;
```

`Email` lưu **đã chuẩn hoá** (chữ thường) nên chỉ mục thường là đủ.

### 2.4 API — bốn endpoint mới + hai endpoint đổi

| # | Endpoint | Ai được | Thân | Trả về (`data`) |
|---|---|---|---|---|
| **13** | `POST /api/households/invites/email` | `Owner`, nhà `Active`, chưa đủ người | `{ email, role: 'Member' \| 'Viewer' }` | `202` `{ sent: true, email, role, expiresAt }` (luôn cùng hình dạng) |
| **14** | `GET /api/households/invitations` | mọi tài khoản | — | `[{ code, householdName, inviterName, role, memberCount, maxMembers, expiresAt }]` — lời mời gửi tới tôi (`Email` = email của tôi **hoặc** `Invitee_idaccount` = tôi), còn hiệu lực, nhà `Active` |
| **15** | `POST /api/households/invitations/:code/accept` | người được mời, chưa ở nhà nào | — | trạng thái nhà (đơn 50 C.1) — như #7 |
| **16** | `POST /api/households/invitations/:code/decline` | người được mời | — | `{ declined: true }` |
| 4 (đổi) | `GET /api/households/invites` | `Owner` | — | thêm lời mời email: `[{ code, role, createAt, expiresAt, email \| null, status: 'Pending' \| 'Declined' \| 'Expired' }]` — mã thường: chỉ còn hiệu lực (như cũ); lời mời email: cả đã từ chối / hết hạn trong 7 ngày gần nhất |
| 7, 6 (đổi) | `POST /join`, `GET /invites/:code` | — | — | kiểm email khi lời mời có `Email` (2.2) |

`#5 DELETE /api/households/invites/:code` dùng cho cả hai loại. Tên hiển thị người mời: `user.Fullname`, thiếu thì `account.Username`
(đơn 50 C). **Không** trả email của ai ngoài chính email Chủ nhà đã gõ ở #4.

> **Backend trả lời 2026-10-31 (đơn 57.8 #5):** `GET /invites` giữ **5 trạng thái** `Pending · Declined · Revoked · Used · Expired`. Màn Mời chỉ hiện *Đang chờ / Đã từ chối / Hết hạn* (mục 2.1).

### 2.5 Mã lỗi API mới (4xx, `code` ở cấp gốc)

| Mã | HTTP | Khi |
|---|---|---|
| `HOUSEHOLD_INVITE_WRONG_ACCOUNT` | 403 | lời mời email, tài khoản gọi có email khác |
| `HOUSEHOLD_INVITE_DECLINED` | 409 | lời mời đã bị từ chối |
| `HOUSEHOLD_INVITE_RATE_LIMIT` | 429 | quá 20 lời mời email / nhà / 24 giờ |
| (400 `'Validation failed'` có sẵn) | 400 | email sai dạng / dài quá 100 |

Các mã của đơn 50 C.3 (`HOUSEHOLD_INVITE_INVALID` / `_EXPIRED` / `_USED`, `HOUSEHOLD_ALREADY_IN_ONE`, `HOUSEHOLD_FULL`…) áp nguyên cho
#15.

### 2.6 Mẫu thư

> **Tiêu đề:** Lời mời vào nhà "{tên nhà}" trên FlowMoney
>
> {Tên người mời} mời bạn vào nhà **"{tên nhà}"** trên FlowMoney với vai **{Thành viên | Chỉ xem}**.
>
> Mã mời: **{ABCD2345}** — dùng được tới {dd/MM/yyyy HH:mm} (giờ Việt Nam).
>
> Cách tham gia: mở FlowMoney → **Nhà mình** → **Tham gia bằng mã**, nhập mã trên. Chưa có tài khoản? Đăng ký bằng chính địa chỉ email
> này rồi làm như trên.
>
> Nếu bạn không biết người mời, hãy bỏ qua thư này.

Không có đường link mở thẳng app (app chưa cấu hình App Links — ngoài phạm vi). Không kèm thông tin thành viên khác.

### 2.7 Thời gian thực và thông báo

- **`household.invited`** — sự kiện mới, tới tài khoản được mời. Client: một giá trị `RealtimeEvent` mới, im lặng (`loiNhan null`),
  `canDongBoLai false`, chỉ gọi lại #14. Nguồn sự thật luôn là #14 — mất kết nối lúc được mời không mất lời mời.
- **Thông báo `loiMoiNha`** (client, nhóm mới **Gia đình**): luật cục bộ đọc danh sách #14 đã nhớ; khoá chống trùng
  **`loiMoiNha:<code>`**; deeplink `/nha`; câu *"{người mời} mời bạn vào nhà {tên nhà}"*.

### 2.8 Phía client

- `NhaRepository` (spec 2026-10-23 mục 5.8 + kế hoạch lát 1) nhớ thêm **danh sách lời mời gửi tới tôi**; làm mới cùng lúc với trạng
  thái nhà (đăng nhập, `resumed` giãn 5 phút, `household.invited`, `household.changed`) và sau mỗi thao tác 13–16.
- `HouseholdApi` (`features/household/data/datasources/`) thêm 4 lời gọi; `cau_loi_nha.dart` thêm câu cho 3 mã mới.
- Màn *Mời thành viên* hai khối; thẻ *Lời mời đang chờ* ở *Nhà mình*. Ô email dùng `GioiHanDoRong` (100) như ô tên.
- `NotificationKind` thêm `loiMoiNha` + nhóm `NotificationGroup.giaDinh` (hai `switch` không `default` ở `notification_prefs.dart` +
  `tatCaUngVien()` ở `notification_deeplink_test.dart` — bẫy của mảng thông báo). Nhóm *Gia đình* gom mọi loại thông báo của bộ này.
- Lát 2 của kế hoạch phần 1 (màn hình) thêm hai thứ trên; lát 1 (lõi) chỉ thêm lời gọi API + mô hình dữ liệu lời mời.

## 3. Luật quyền khi đẩy hàng của nhà (thay đoạn *Tạo / Sửa / xoá* của đơn 50 D.2)

Đơn 50 cho mọi `Owner` / `Member` tạo / sửa / xoá **mọi** hàng của nhà. Nay theo nguyên tắc *Chủ nhà cấu hình · Thành viên giao dịch*
và quyết định *người ghi + Chủ nhà sửa / xoá* (`00` mục 2, #9 và #15):

| Hàng của nhà | Tạo | Sửa | Xoá |
|---|---|---|---|
| `wallet` (ví chung) | Owner | Owner | Owner |
| `goal` (mục tiêu chung — `03`) | Owner | Owner | Owner |
| `budget` (ngân sách chung — `02D`) | Owner | Owner | Owner |
| `category` (danh mục của nhà) | Owner, Member | Owner, Member | Owner, Member |
| `transaction` thu / chi thường | Owner, Member | người ghi; Owner | người ghi; Owner |
| `transaction` `Transfer` (giữa hai ví chung) | Owner | Owner | Owner |
| `transaction` có `Idfund_pair` (nửa của nhà của khoản góp / rút — `02A`) | Owner, Member | **chỉ người ghi** | người ghi; Owner |

- **"Người ghi"** = `existing."Idaccount"` (server giữ người tạo — đơn 50 D.2).
- Thứ tự kiểm (để mã ổn định): không là thành viên đang ở ⇒ `HOUSEHOLD_NOT_MEMBER`; nhà `Dissolved` ⇒ `HOUSEHOLD_CLOSED`; vai `Viewer`
  hoặc nhà `ReadOnly` ⇒ `HOUSEHOLD_READ_ONLY`; tham chiếu sai phạm vi ⇒ `HOUSEHOLD_SCOPE_MISMATCH`; **còn lại không khớp bảng ⇒
  `HOUSEHOLD_ROLE_FORBIDDEN`** (mã đẩy mới, vĩnh viễn).
- Vì sao khoản có mã cặp chỉ người ghi được **sửa**: nửa riêng của cặp chỉ nằm trên máy người ghi; Chủ nhà sửa số tiền nửa của nhà là
  hai nửa lệch nhau mãi. Chủ nhà muốn sửa ghi nhầm thì **xoá** — máy người ghi tự gỡ nửa riêng (`02A` mục 6).
- **Bỏ ngoại lệ `idgoal`** của đơn 50 D.2: giao dịch **riêng** chỉ được trỏ `idgoal` tới mục tiêu **riêng của chính người ấy**; trỏ tới
  mục tiêu của nhà ⇒ `HOUSEHOLD_SCOPE_MISMATCH`. Mục tiêu chung nay là công tắc trên ví chung, góp qua cặp hai khoản (`03`).
- Phía client: thêm `HOUSEHOLD_ROLE_FORBIDDEN` (và `HOUSEHOLD_WALLET_LIMIT` của `02A`) vào `_permanentCodes`
  (`lib/core/sync/gui_lo_dong_bo.dart`) **trước** khi backend bật — cùng cách năm mã của đơn 50 đã làm ngày 2026-10-26 (✅ **đã thêm
  2026-10-27**; backend đặt tên khác thì báo client để sửa theo) — và form chặn
  trước theo đúng bảng trên (nút sửa / xoá chỉ hiện khi được phép) nên mã này chỉ nổ khi vai vừa đổi ở máy khác.

## 4. Trạng thái nhà — phần mở rộng của đơn 50 C.1

Thêm vào hình dạng `GET /api/households/me` (và mọi thao tác trả nó). Hai khoá của phần 1 / 2a ở đây; khoá của 2b / 2c ở tệp của
chúng:

```json
{
  "household": { "id": 12, "name": "Nhà Đạt – Linh", "status": "Active", "maxMembers": 6, "ownerId": 18,
                 "createAt": "…", "maxSharedWallets": 10 },
  "myRole": "Owner",
  "members": [ … như đơn 50 … ],
  "formerMembers": [ { "idaccount": 31, "displayName": "Lê Bình", "leftAt": "2026-11-02T03:00:00.000Z" } ]
}
```

- **`formerMembers`** — thành viên đã rời / bị mời ra của nhà này (`household_member."Left_at"` khác trống), để dòng hoạt động và bảng góp
  hiện tên người đã rời kèm *"(đã rời)"* (khoản của họ ở lại nhà — đơn 50 C.2). Không trả email.
- **`maxSharedWallets`** — trần số ví chung (`02A` mục 2).

## 5. Kiểm thử và nghiệm thu (phần thêm)

- **Domain / repository (client):** câu lỗi 3 mã mới; `NhaRepository` nhớ + làm mới danh sách lời mời; thẻ lời mời khoá *Chấp nhận* khi
  đã ở nhà; thông báo `loiMoiNha` một lần mỗi mã (ca chống trùng).
- **Widget:** màn Mời hai khối ở 360 dp, có ca bàn phím mở; ô email cắt ở 100 ký tự.
- **Backend (đề xuất ca):** email có / không tài khoản ⇒ cùng `202`; gửi lại ⇒ lời mời cũ `Revoked_at`; chuyển tiếp mã sang tài khoản email
  khác ⇒ `403 WRONG_ACCOUNT`; từ chối ⇒ chấp nhận sau đó `409 DECLINED`; đăng ký sau khi được mời ⇒ #14 trả lời mời; 21 lời mời / ngày ⇒
  `429`; ma trận mục 3 — mỗi ô một ca (Member sửa ví chung ⇒ `HOUSEHOLD_ROLE_FORBIDDEN`; Member sửa khoản của người khác ⇒ như trên; Owner
  sửa nửa của nhà có `Idfund_pair` của người khác ⇒ như trên; Owner xoá nó ⇒ được).
- **Nghiệm thu hai máy thật, hai tài khoản:** mời bằng email tài khoản đã có ⇒ thẻ + thông báo hiện ở máy kia trong vài giây (app đang mở);
  chấp nhận ⇒ dữ liệu nhà về; mời email chưa có tài khoản ⇒ thư tới, đăng ký đúng email ⇒ thấy lời mời.

## 6. Câu hỏi để thảo luận

- **N1** — Trần 20 thư / nhà / 24 giờ có hợp với hạn mức gửi của nhà cung cấp thư không (câu Q2 `00`)?
- **N2** — `formerMembers` trả mọi người từng ở nhà, hay chỉ người có ít nhất một khoản của nhà? Client chỉ cần tên; danh sách đầy đủ đơn
  giản hơn và nhà tối đa 6 người nên không dài.
- **N3** — Gửi thư hỏng: backend có muốn trả `202` kèm cờ `emailFailed` để Chủ nhà biết gửi lại? Client chưa cần (lời mời trong app vẫn tới
  người có tài khoản).

## 7. Trả lời / thảo luận

*(Chờ backend / PO.)*
