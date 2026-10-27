# Mục 50 — Chức năng GIA ĐÌNH (nhà nhiều người): Toàn bộ Thiết kế & Nhiệm vụ Backend Phần 1 (Nền móng)

> 👑 **TÀI LIỆU YÊU CẦU KỸ THUẬT NGUỒN SỰ THẬT (SOURCE OF TRUTH) — ĐÃ ĐƯỢC PO DUYỆT 2026-10-27**
> **Người nhận:** Backend Team (Lead FullStack & Backend Engineers)  
> **Người giao:** Product Owner (PO) & Lead Business Analyst  
> **Mức độ ưu tiên:** **CAO (High / P1)** — Tính năng chiến lược mở rộng hệ sinh thái FlowMoney  
> **Tài liệu nghiệp vụ gốc:** [`docs/Family/00_TONG_QUAN.md`](../../../Family/00_TONG_QUAN.md) & [`docs/Family/01_NEN_MONG.md`](../../../Family/01_NEN_MONG.md)  
> **Trạng thái:** 🟢 SẴN SÀNG TRIỂN KHAI THEO QUY TRÌNH TDD & DB GUARD  

---

## 0. Tóm tắt Tổng quan (Executive Summary)

**1. Mục tiêu Người dùng:**
Một người dùng có gói **Premium** tạo một **"Nhà"** trên FlowMoney (quy mô tối đa 6 người). Chủ nhà gửi **Mã mời 8 ký tự** hoặc gửi **Lời mời đích danh qua Email** cho người thân (vợ/chồng/con/bố mẹ). Người được mời có thể dùng gói Basic miễn phí tham gia nhà. Trong nhà có ví chung, chi tiêu chung, hạn mức chi, định mức góp, ngân sách chung và mục tiêu chung. Dữ liệu riêng tư của cá nhân vẫn được cách ly tuyệt đối, không bị trộn lẫn với dữ liệu của nhà.

**2. Mô hình Kiến trúc: "Nhà là Chủ sở hữu thứ ba":**
- 5 bảng đồng bộ cốt lõi (`wallet`, `transaction`, `goal`, `budget`, `category`) được bổ sung cột `Idhousehold INT NULL REFERENCES "household"("Idhousehold")`.
- `Idhousehold IS NULL`: Dữ liệu riêng tư cá nhân.
- `Idhousehold IS NOT NULL`: Dữ liệu thuộc sở hữu chung của Nhà; cột `Idaccount` khi đó đóng vai trò là **Người ghi (Creator / Author)**.

**3. Danh mục 7 Nhóm Nhiệm vụ Backend Phần 1:**

| # | Nhóm nhiệm vụ | Chi tiết thực thi | Mức độ |
|---|---|---|:---:|
| **A** | **Tiền đề an ninh `/sync/push`** | Bổ sung kiểm tra quyền sở hữu (`NOT_OWNER`) khi Sửa/Xóa dữ liệu cá nhân của 6 thực thể. | **Tối khẩn** |
| **B** | **Migration CSDL** | Script `database/40_create_household_foundation.sql`: 3 bảng `household`, `household_member`, `household_invite` (kèm cột Email, Invitee_idaccount, Declined_at); cột `Idhousehold` cho 5 bảng; Partial Unique Indexes; cập nhật `schema.prisma`. | **Cao** |
| **C** | **Module `households` API** | Xây dựng 16 REST endpoints chuẩn mực: 12 endpoint quản lý nhà/mã mời + **4 endpoint mời qua Email** (chống dò email, rate limit 20 mail/24h, mẫu thư Brevo/Resend). | **Cao** |
| **D** | **Chuẩn hóa Sync Engine** | `/sync/pull` kéo `(của tôi AND riêng) OR (của nhà tôi đang ở)`. `/sync/push` áp dụng **Ma trận quyền Vai trò $\times$ Thực thể** kèm mã lỗi đẩy mới: `HOUSEHOLD_ROLE_FORBIDDEN`, `NOT_OWNER`, `HOUSEHOLD_NOT_MEMBER`, `HOUSEHOLD_CLOSED`, `HOUSEHOLD_READ_ONLY`, `HOUSEHOLD_SCOPE_MISMATCH`. Bỏ ngoại lệ `idgoal`. | **Cao** |
| **E** | **Phân quyền & Gói dịch vụ** | Áp dụng phân quyền trụ cột: quyền `household`, trần `household_members` (mặc định 6). Chủ nhà hết Premium $\rightarrow$ Nhà tự động chuyển `ReadOnly` (chỉ xem, không ai được ghi mới). | **Vừa** |
| **F** | **Sự kiện Thời gian thực** | Phát Socket.io: `household.changed` khi trạng thái nhà thay đổi; `household.invited` tới tài khoản được mời qua email; `sync.completed` tới **mọi thành viên** khi có giao dịch của nhà được đẩy lên. | **Vừa** |
| **G** | **Nhân bản Danh mục Nhà** | Khi tạo nhà thành công, server tự động sao chép 13 danh mục mặc định của hệ thống thành danh mục của nhà (`Idhousehold = H`, `Create_by = Owner`, `Is_default = false`). | **Vừa** |

---

## 1. Nghiệp vụ Chi tiết & Quyết định Đã Chốt (Theo `docs/Family/`)

1. **Quy mô & Giới hạn:**
   - Mỗi nhà tối đa **6 thành viên** (có thể ghi đè bằng `household.Max_members`).
   - Một tài khoản tại một thời điểm chỉ được ở **tối đa 1 nhà** (`uq_household_member_active_account`).
2. **Ba vai trò cố định áp cho cả nhà:**
   - `Owner` (Chủ nhà): Cần gói Premium; toàn quyền quản trị, cấu hình hạn mức/ngân sách/mục tiêu, mời và giải tán nhà.
   - `Member` (Thành viên): Dùng miễn phí; ghi chép chi/thu/góp/rút vào ví chung; sửa/xóa khoản do mình ghi; xem hạn mức/định mức của mình.
   - `Viewer` (Chỉ xem): Xem toàn bộ số liệu, ví chung, báo cáo; không được ghi chép bất kỳ dữ liệu nào.
3. **Trạng thái Nhà (`household.Status`):**
   - `Active`: Hoạt động bình thường.
   - `ReadOnly`: Khi Chủ nhà hết hạn Premium hoặc bị hạ cấp gói. Thành viên và Chủ nhà vẫn xem được dữ liệu, nhưng **mọi thao tác ghi mới vào nhà đều bị từ chối** (`HOUSEHOLD_READ_ONLY`). Thao tác quản lý (rời nhà, mời ra) vẫn cho phép.
   - `Dissolved`: Khi Chủ nhà giải tán nhà. Dữ liệu chung bị ẩn hoàn toàn (Soft-delete).
4. **Giải tán nhà:**
   - Dữ liệu chung bị xóa mềm ở server (`household.Delete_at = now()`, cập nhật `Status = 'Dissolved'`).
   - Thành viên tự động được giải phóng khỏi nhà (`Left_at = now()`).
   - Nửa riêng của các khoản góp/rút trên máy cá nhân được bảo toàn nguyên vẹn.

---

## 2. Chi tiết Kỹ thuật Backend Cần Thực Hiện

### Việc A: Tiền đề an ninh — Kiểm tra quyền sở hữu khi Sửa / Xóa qua `/sync/push`

* **Vấn đề an ninh hiện hữu:** Nhánh Sửa (`upsert*`) và Xóa (`softDelete`) của `sync.repository.js` hiện chỉ tìm bản ghi theo UUID khóa chính rồi so sánh `update_at` mà không kiểm tra `existing.idaccount`. Khi tính năng gia đình mở ra, UUID ví chung và giao dịch được chia sẻ giữa các thành viên, nếu không siết chặt sẽ dẫn tới lỗ hổng sửa/xóa chéo dữ liệu của nhau.
* **Quy tắc kiểm tra bắt buộc khi Sửa / Xóa:**
  ```javascript
  // 1. Nếu là bản ghi cá nhân (Idhousehold IS NULL)
  if (!existing.Idhousehold) {
    const ownerId = existing.Idaccount || existing.Create_by;
    if (ownerId !== req.user.idaccount) {
      throw new DomainError('NOT_OWNER', 'Bản ghi không thuộc quyền sở hữu của bạn');
    }
  }
  // 2. Nếu là bản ghi của nhà (Idhousehold IS NOT NULL) -> Áp dụng ma trận quyền tại Mục D
  ```
* **Mã lỗi trả về:** Ném lỗi với mã `code: 'NOT_OWNER'` (HTTP 200 trong mảng `results[i].code` của `/sync/push`) để Client xếp vào danh sách lỗi vĩnh viễn, không gửi lại.

---

### Việc B: Migration CSDL `database/40_create_household_foundation.sql`

Viết file migration SQL theo chuẩn Supabase PostgreSQL, không dùng `prisma db push` / `migrate dev`:

```sql
-- ============================================================================
-- MIGRATION 40: HOUSEHOLD FOUNDATION (GIA ĐÌNH NỀN MÓNG)
-- ============================================================================

-- 1. Bảng household (Nhà)
CREATE TABLE IF NOT EXISTS "household" (
  "Idhousehold"     SERIAL PRIMARY KEY,
  "Name"            VARCHAR(100) NOT NULL,
  "Owner_idaccount" INT NOT NULL REFERENCES "account"("Idaccount"),
  "Status"          VARCHAR(10) NOT NULL DEFAULT 'Active',
  "Max_members"     SMALLINT NOT NULL DEFAULT 6,
  "Max_shared_wallets" SMALLINT NOT NULL DEFAULT 10,
  "Contribution_due_day" SMALLINT NOT NULL DEFAULT 5,
  "Create_at"       TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Update_at"       TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Delete_at"       TIMESTAMP(6) NULL,
  CONSTRAINT "chk_household_status"      CHECK ("Status" IN ('Active', 'ReadOnly', 'Dissolved')),
  CONSTRAINT "chk_household_max_members" CHECK ("Max_members" BETWEEN 2 AND 20),
  CONSTRAINT "chk_household_due_day"     CHECK ("Contribution_due_day" BETWEEN 1 AND 31)
);

-- 2. Bảng household_member (Thành viên nhà)
CREATE TABLE IF NOT EXISTS "household_member" (
  "Id"          SERIAL PRIMARY KEY,
  "Idhousehold" INT NOT NULL REFERENCES "household"("Idhousehold"),
  "Idaccount"   INT NOT NULL REFERENCES "account"("Idaccount"),
  "Role"        VARCHAR(7) NOT NULL,
  "Joined_at"   TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Left_at"     TIMESTAMP(6) NULL,
  CONSTRAINT "chk_household_member_role" CHECK ("Role" IN ('Owner', 'Member', 'Viewer'))
);

-- Ràng buộc: Mỗi tài khoản tại 1 thời điểm chỉ ở tối đa 1 nhà đang active
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_member_active_account"
  ON "household_member" ("Idaccount") WHERE "Left_at" IS NULL;

-- Ràng buộc: Mỗi nhà chỉ có đúng 1 Chủ nhà (Owner) đang active
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_one_owner"
  ON "household_member" ("Idhousehold") WHERE "Role" = 'Owner' AND "Left_at" IS NULL;

CREATE INDEX IF NOT EXISTS "idx_household_member_active"
  ON "household_member" ("Idhousehold") WHERE "Left_at" IS NULL;

-- 3. Bảng household_invite (Mã mời & Lời mời Email)
CREATE TABLE IF NOT EXISTS "household_invite" (
  "Code"                VARCHAR(8) PRIMARY KEY,
  "Idhousehold"         INT NOT NULL REFERENCES "household"("Idhousehold"),
  "Role"                VARCHAR(7) NOT NULL,
  "Created_by"          INT NOT NULL REFERENCES "account"("Idaccount"),
  "Email"               VARCHAR(100) NULL,                                   -- NULL = Mã mời công khai
  "Invitee_idaccount"   INT NULL REFERENCES "account"("Idaccount"),         -- Tự khớp nếu email đã có tài khoản
  "Create_at"           TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Expires_at"          TIMESTAMP(6) NOT NULL,
  "Used_by"             INT NULL REFERENCES "account"("Idaccount"),
  "Used_at"             TIMESTAMP(6) NULL,
  "Revoked_at"          TIMESTAMP(6) NULL,
  "Declined_at"         TIMESTAMP(6) NULL,
  CONSTRAINT "chk_household_invite_role" CHECK ("Role" IN ('Member', 'Viewer'))
);

-- Ràng buộc: Mỗi email chỉ có 1 lời mời active cho mỗi nhà
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_invite_email_active"
  ON "household_invite" ("Idhousehold", "Email")
  WHERE "Email" IS NOT NULL AND "Used_at" IS NULL AND "Revoked_at" IS NULL AND "Declined_at" IS NULL;

CREATE INDEX IF NOT EXISTS "idx_household_invite_email"
  ON "household_invite" ("Email") WHERE "Email" IS NOT NULL;

-- 4. Bổ sung cột Idhousehold cho 5 bảng đồng bộ
ALTER TABLE "wallet"      ADD COLUMN IF NOT EXISTS "Idhousehold" INT NULL REFERENCES "household"("Idhousehold");
ALTER TABLE "transaction" ADD COLUMN IF NOT EXISTS "Idhousehold" INT NULL REFERENCES "household"("Idhousehold");
ALTER TABLE "goal"        ADD COLUMN IF NOT EXISTS "Idhousehold" INT NULL REFERENCES "household"("Idhousehold");
ALTER TABLE "budget"      ADD COLUMN IF NOT EXISTS "Idhousehold" INT NULL REFERENCES "household"("Idhousehold");
ALTER TABLE "category"    ADD COLUMN IF NOT EXISTS "Idhousehold" INT NULL REFERENCES "household"("Idhousehold");

CREATE INDEX IF NOT EXISTS "idx_wallet_household"      ON "wallet"      ("Idhousehold", "Server_update_at") WHERE "Idhousehold" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_transaction_household" ON "transaction" ("Idhousehold", "Server_update_at") WHERE "Idhousehold" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_goal_household"        ON "goal"        ("Idhousehold", "Server_update_at") WHERE "Idhousehold" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_budget_household"      ON "budget"      ("Idhousehold", "Server_update_at") WHERE "Idhousehold" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_category_household"    ON "category"    ("Idhousehold", "Server_update_at") WHERE "Idhousehold" IS NOT NULL;

-- 5. Chuẩn hóa Partial Unique Index cách ly cá nhân vs nhà
DROP INDEX IF EXISTS "uq_wallet_account_name_active";
CREATE UNIQUE INDEX "uq_wallet_account_name_active"
  ON "wallet" ("Idaccount", "Name") WHERE "Delete_at" IS NULL AND "Idhousehold" IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "uq_wallet_household_name_active"
  ON "wallet" ("Idhousehold", "Name") WHERE "Delete_at" IS NULL AND "Idhousehold" IS NOT NULL;

DROP INDEX IF EXISTS "uq_wallet_default_active";
CREATE UNIQUE INDEX "uq_wallet_default_active"
  ON "wallet" ("Idaccount") WHERE "Is_default" = TRUE AND "Delete_at" IS NULL AND "Idhousehold" IS NULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_wallet_household_not_default') THEN
    ALTER TABLE "wallet" ADD CONSTRAINT "chk_wallet_household_not_default"
      CHECK ("Idhousehold" IS NULL OR "Is_default" = FALSE);
  END IF;
END $$;

DROP INDEX IF EXISTS "uq_category_owner_name";
CREATE UNIQUE INDEX "uq_category_owner_name"
  ON "category" ("Create_by", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = FALSE AND "Delete_at" IS NULL AND "Idhousehold" IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "uq_category_household_name"
  ON "category" ("Idhousehold", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Delete_at" IS NULL AND "Idhousehold" IS NOT NULL;
```

---

### Việc C: Xây dựng Module `households` (16 Endpoints RESTful)

Khởi tạo cấu trúc thư mục tại `src/Backend/modules/household/`:
- `household.controller.js`
- `household.service.js`
- `household.repository.js`
- `household.validation.js`
- Đăng ký route tại `src/Backend/api/households.routes.js` và nạp vào `src/Backend/api/index.js` qua middleware `authenticate`.

#### Danh sách 16 Endpoints hoàn chỉnh:

| # | Phương thức & URI | Quyền gọi | Payload Body / Params | Phản hồi chuẩn (`data`) & Mã HTTP |
|:---:|---|---|---|---|
| **1** | `POST /api/households` | Có quyền `household` (Premium), chưa ở nhà nào | `{ "name": "Gia đình Tuấn An" }` | `201` Trạng thái nhà đầy đủ |
| **2** | `GET /api/households/me` | Mọi user đã đăng nhập | — | `200` `{ "household": null }` hoặc thông tin nhà + `myRole` + `members` + `formerMembers` |
| **3** | `POST /api/households/invites` | `Owner`, nhà `Active`, chưa đủ người | `{ "role": "Member" \| "Viewer" }` | `201` `{ "code": "ABCD2345", "role": "Member", "expiresAt": "..." }` (Hạn 48h) |
| **4** | `GET /api/households/invites` | `Owner` | — | `200` Danh sách mã mời còn hạn + lời mời email (kèm trạng thái Pending/Declined/Expired) |
| **5** | `DELETE /api/households/invites/:code` | `Owner` | — | `200` `{ "revoked": true }` |
| **6** | `GET /api/households/invites/:code` | Mọi user đã đăng nhập | — | `200` Xem trước: `{ householdName, ownerName, memberCount, maxMembers, role, expiresAt }` |
| **7** | `POST /api/households/join` | User chưa ở nhà nào | `{ "code": "ABCD2345" }` | `200` Trạng thái nhà sau khi gia nhập thành công |
| **8** | `PATCH /api/households/members/:idaccount` | `Owner`, đích là Member/Viewer | `{ "role": "Member" \| "Viewer" }` | `200` Trạng thái nhà sau cập nhật |
| **9** | `POST /api/households/transfer-owner` | `Owner`, đích là thành viên trong nhà | `{ "idaccount": 25 }` | `200` Trạng thái nhà (chuyển vai Owner) |
| **10**| `DELETE /api/households/members/:idaccount` | `Owner`, đích khác chính mình | — | `200` Trạng thái nhà sau khi mời ra |
| **11**| `POST /api/households/leave` | `Member` / `Viewer` | — | `200` `{ "household": null }` |
| **12**| `POST /api/households/dissolve` | `Owner` | — | `200` `{ "dissolved": true }` |
| **13**| `POST /api/households/invites/email` | `Owner`, nhà `Active`, chưa đủ người | `{ "email": "user@gmail.com", "role": "Member" }` | `202` `{ "sent": true, "email": "...", "role": "...", "expiresAt": "..." }` *(Luôn trả 202 để chống dò email; rate limit 20 mail/nhà/24h)* |
| **14**| `GET /api/households/invitations` | Mọi user đã đăng nhập | — | `200` Danh sách lời mời gửi tới email của user hiện tại |
| **15**| `POST /api/households/invitations/:code/accept` | User được mời qua email | — | `200` Trạng thái nhà sau khi chấp nhận |
| **16**| `POST /api/households/invitations/:code/decline` | User được mời qua email | — | `200` `{ "declined": true }` |

* **Quy cách Thư mời Email (Brevo / Resend):** Tiêu đề: *`Lời mời vào nhà "{tên nhà}" trên FlowMoney`*. Nội dung chứa mã mời, người mời, vai trò và hạn 7 ngày. Gửi lỗi thì ghi log, không trả lỗi 500 cho Chủ nhà.
* **Quyền riêng tư:** `user.Fullname` (hoặc fallback `account.Username`). Tuyệt đối không trả email/số điện thoại của thành viên khác trong các response chung.

---

### Việc D: Chuẩn hóa Đồng bộ Sync Engine (`/sync/pull` & `/sync/push`)

#### 1. Nhánh Kéo về (`GET /api/sync/pull`):
Cập nhật truy vấn kéo dữ liệu của 5 bảng (`wallet`, `transaction`, `budget`, `goal`, `category`):
```sql
WHERE ("Idaccount" = :myId AND "Idhousehold" IS NULL) 
   OR ("Idhousehold" = :myActiveHouseholdId)
```

#### 2. Nhánh Đẩy lên (`POST /api/sync/push`):
Áp dụng nghiêm ngặt **Ma trận quyền Vai trò $\times$ Thực thể**:

| Thực thể của Nhà | Tạo (Create) | Sửa (Update) | Xóa (Soft Delete) |
|---|---|---|---|
| `wallet` (Ví chung) | `Owner` | `Owner` | `Owner` |
| `goal` (Mục tiêu chung) | `Owner` | `Owner` | `Owner` |
| `budget` (Ngân sách chung) | `Owner` | `Owner` | `Owner` |
| `category` (Danh mục của nhà) | `Owner`, `Member` | `Owner`, `Member` | `Owner`, `Member` |
| `transaction` (Chi/Thu chung) | `Owner`, `Member` | Người ghi (`Idaccount`) HOẶC `Owner` | Người ghi (`Idaccount`) HOẶC `Owner` |
| `transaction` (`Transfer` giữa 2 ví chung) | `Owner` | `Owner` | `Owner` |
| `transaction` (Có mã cặp `Idfund_pair`) | `Owner`, `Member` | **CHỈ người ghi** | Người ghi HOẶC `Owner` |

* **Thứ tự kiểm tra mã lỗi đẩy (Ném lỗi vĩnh viễn trong `results[i].code`):**
  1. Người gửi không phải thành viên active của nhà $\rightarrow$ `HOUSEHOLD_NOT_MEMBER`.
  2. Nhà đã giải tán $\rightarrow$ `HOUSEHOLD_CLOSED`.
  3. Người gửi có vai `Viewer` hoặc Nhà ở trạng thái `ReadOnly` $\rightarrow$ `HOUSEHOLD_READ_ONLY`.
  4. Tham chiếu sai phạm vi (ví dụ: giao dịch riêng trỏ vào ví chung, hoặc trỏ `idgoal` của nhà) $\rightarrow$ `HOUSEHOLD_SCOPE_MISMATCH`.
  5. Vi phạm ma trận phân quyền ở bảng trên $\rightarrow$ **`HOUSEHOLD_ROLE_FORBIDDEN`** *(Mã lỗi mới)*.

---

### Việc E: Phân quyền Trụ cột & Quản lý Hết hạn Premium

- Cập nhật ma trận phân quyền `account_type_permission`: Đảm bảo quyền `household` chỉ cấp cho tài khoản gói **Premium**.
- Kiểm tra giới hạn thành viên: Khi mời/gia nhập, tổng số thành viên active + số lời mời còn hiệu lực $\le$ `Max_members` (mặc định 6). Vượt quá $\rightarrow$ `409 HOUSEHOLD_FULL`.
- Khi Chủ nhà hết hạn Premium (Job cron hạ cấp hoặc webhook hạ cấp): Cập nhật trạng thái nhà `Status = 'ReadOnly'`, phát socket `household.changed`. Khi Chủ nhà gia hạn Premium thành công $\rightarrow$ Chuyển lại `Status = 'Active'`.

---

### Việc F: Tích hợp Sự kiện Thời gian thực (Socket.io)

- **`household.changed`**: Phát tới room của nhà (`household_<id>`) khi có thay đổi: thành viên tham gia, đổi vai, rời nhà, mời ra, giải tán, hoặc trạng thái nhà đổi sang `ReadOnly`/`Active`.
- **`household.invited`**: Phát tới socket của tài khoản đích khi có lời mời gửi đích danh qua email.
- **`sync.completed`**: Khi có bất kỳ bản ghi nào mang `Idhousehold` được đẩy lên thành công qua `/sync/push`, backend **phát sự kiện `sync.completed` tới toàn bộ các thành viên đang hoạt động trong nhà** để các thiết bị khác tự động kích hoạt Delta Pull kéo dữ liệu mới về.

---

### Việc G: Tự động Nhân bản Danh mục Mặc định cho Nhà

Trong giao tác tạo nhà tại `household.service.js`:
- Sau khi tạo bản ghi `household` và `household_member` (vai Owner), tự động truy vấn 13 danh mục mặc định của hệ thống (`Is_default = true`, `Idhousehold IS NULL`).
- Sao chép (clone) 13 danh mục này thành danh mục của nhà với:
  + `Idhousehold` = Id nhà mới tạo.
  + `Create_by` = Id tài khoản Owner.
  + `Is_default` = `false` (để nhà có thể tự do chỉnh sửa/đổi tên danh mục sau này).
  + Tạo UUID mới cho từng danh mục sao chép.

---

## 3. Checklist Kiểm thử & Nghiệm thu 2 Tầng (Lead BA & QA Bắt buộc)

Áp dụng quy tắc kiểm thử 2 tầng **(Rule 11)**:

### 🧱 Tầng 1: Kiểm thử API & Hợp đồng Dữ liệu (Integration & Unit Tests)
- [ ] 16/16 Endpoints RESTful phản hồi đúng mã HTTP (200, 201, 202, 400, 403, 404, 409, 429).
- [ ] Validation bắt lỗi: Tên nhà rỗng/quá 100 ký tự; Email sai định dạng; Vai trò không hợp lệ.
- [ ] Mời qua Email trả `202 Accepted` với cùng một định dạng dù email có tài khoản hay chưa.
- [ ] Rate limit mời email: Lời mời thứ 21 trong 24 giờ trả về `429 HOUSEHOLD_INVITE_RATE_LIMIT`.

### ⚡ Tầng 2: Kiểm thử Toàn vẹn Hệ thống & DB Impact (System & Security Impact)
- [ ] **DB Guard & Triggers:** Chạy `rtk npm run db:verify-indexes` xác nhận 100% Partial Unique Indexes và Trigger CSDL nguyên vẹn.
- [ ] **Lỗ hổng NOT_OWNER:** Thử sửa/xóa bản ghi riêng của người khác qua `/sync/push` $\rightarrow$ Chặn đứng và trả mã `NOT_OWNER`.
- [ ] **Ma trận Vai trò:** Thành viên thử tạo ví chung hoặc sửa ngân sách nhà qua `/sync/push` $\rightarrow$ Chặn đứng và trả mã `HOUSEHOLD_ROLE_FORBIDDEN`.
- [ ] **Tự động sao chép danh mục:** Tạo nhà mới $\rightarrow$ Kiểm tra CSDL có đúng 13 danh mục mang `Idhousehold` của nhà mới.
- [ ] **Realtime Event:** Kiểm tra socket `household.changed`, `household.invited` và `sync.completed` phát đúng room và đúng tài khoản.
- [ ] **Tự động chuyển ReadOnly:** Giả lập Chủ nhà hết hạn Premium $\rightarrow$ Trạng thái nhà chuyển `ReadOnly`, giao dịch ghi bị chặn đứng với mã `HOUSEHOLD_READ_ONLY`.
