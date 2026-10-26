# Mục 50 — Chức năng GIA ĐÌNH (nhà nhiều người): toàn bộ thiết kế + việc backend của phần 1 (nền móng)

> 🏠 **2026-10-26 (sau) — thiết kế được mở rộng; ĐỌC `docs/Family/00_TONG_QUAN.md` MỤC 6 TRƯỚC KHI LÀM ĐƠN NÀY.** Người dùng thêm: mời bằng
> email, nhiều ví chung, góp / rút quỹ (cặp hai khoản, cột `Idfund_pair`), hạn mức chi từng thành viên, định mức góp + tự góp, ngân sách + báo cáo
> của nhà, mục tiêu chung = công tắc trên ví chung; **bỏ** *ai nợ ai* và *cho nhà xem*. Tám chỗ đổi so với đơn này (bảng mục 6 tệp tổng quan) —
> đáng chú ý: **ma trận vai × thực thể** khi đẩy + mã `HOUSEHOLD_ROLE_FORBIDDEN` thay đoạn *Tạo / Sửa / xoá* của D.2; **bỏ ngoại lệ `idgoal`** ở
> D.2; mục 4 (định hướng ba phần con) **không còn đúng**. Bộ `docs/Family/00…03` là tài liệu để backend / PO **xem và thảo luận** — đơn CAN-LAM cho
> các phần sau đặt khi thảo luận xong. Phần còn lại của đơn này (A, B, C, D trừ đoạn trên, E, F, G) giữ nguyên.
>
> 🔎 **Client soát lại 2026-10-26** (`main` @ `5bb258ff`; truy vấn chỉ đọc trên CSDL Supabase của `.env`): **chưa vế nào
> được làm** — `src/Backend` (`.js` / `.sql` / `.prisma`) có 0 chữ *household*; `database/` dừng ở `36_*`; CSDL: 0 bảng
> `household*`, 0 cột `Idhousehold`. **Vế A vẫn mở:** nhánh sửa của `/sync/push` chỉ so `update_at` (`upsertWallet`,
> `sync.repository.js:269-313`), `softDelete` (`:710-752`) xoá theo khoá chính — không kiểm chủ sở hữu. `36f1ea43` (PR #159)
> thêm `docs/Family/GIA_DINH_NEN_MONG.md` — **bản chép y nguyên** đơn này (cùng blob `d6e786e1`), không kế hoạch, không trả lời
> mục 6. Nhờ backend trả lời / ghi kế hoạch **vào đơn này**: bản ở `docs/Family/` do backend tạo nên client không cập nhật theo
> đơn — đọc bản ở `CAN-LAM/`.
>
> **Client đặt 2026-10-23.** Người nhận: backend (NPBao). Mức: **cao** — tính năng mới người dùng chọn; client làm phần mình
> song song bằng API giả, **nghiệm thu chờ đơn này**.
>
> **Đọc theo thứ tự:** mục 0 (một trang) → mục 1–2 (tính năng là gì) → mục 3 (việc phải làm, chi tiết) → mục 5 (câu kiểm lại).
> Mục 4 là định hướng ba phần con sau — **chưa phải việc**, để lược đồ thiết kế một lần không phải đập lại.
>
> Thiết kế đầy đủ phía client (đã duyệt từng phần với người dùng):
> `docs/superpowers/specs/2026-10-23-gia-dinh-nen-mong-design.md`. Tên endpoint / tên mã trong đơn là **đề xuất** — backend được
> đổi, nhưng ghi lại tên chốt khi trả lời (mục 6) để client theo.

---

## 0. Tóm tắt một trang

**Người dùng thấy gì:** một mục mới *"Nhà mình"* trong drawer. Một người có Premium **tạo nhà**, gửi **mã mời 8 ký tự** cho vợ /
chồng / con / bố mẹ (tối đa 6 người). Người được mời nhập mã là vào nhà (Basic cũng vào được). Trong nhà có **quỹ chung** cả nhà
cùng ghi, **chi chung** tự trả rồi tính *ai nợ ai*, **mục tiêu chung**, và mỗi người tự chọn ví riêng nào *cho nhà xem*. Dữ liệu
riêng vẫn riêng; màn cá nhân (Trang chủ, Sổ giao dịch, Phân tích, Ngân sách) **không đổi**.

**Mô hình:** *"nhà là chủ sở hữu thứ ba"* — năm bảng đồng bộ (`wallet`, `transaction`, `goal`, `budget`, `category`) thêm cột
`Idhousehold` (nullable). Trống = dữ liệu riêng như hôm nay. Có giá trị = bản ghi **của nhà**; `Idaccount` / `Create_by` khi ấy
chỉ nghĩa **người tạo**.

**Việc backend của phần 1 (đơn này):**

| # | Việc | Mức |
|---|---|---|
| **A** | **Tiền đề — kiểm chủ sở hữu khi sửa / xoá qua `/sync/push`** (lỗ hổng có sẵn: biết UUID là ghi đè / xoá được bản ghi người khác) | **cao** |
| B | Migration `database/37_*.sql`: ba bảng `household`, `household_member`, `household_invite`; cột `Idhousehold` cho 5 bảng; chỉ mục trùng tên theo nhà | cao |
| C | Module `households` — 12 endpoint (tạo, trạng thái, tạo / liệt kê / huỷ mã mời, xem trước, tham gia, đổi vai, chuyển chủ, mời ra, rời, giải tán) | cao |
| D | Đồng bộ: kéo về *"của tôi + của nhà tôi"*; đẩy lên kiểm quyền nhà, **4 mã lỗi mới**; `mapEntityFields` nhận `idhousehold` | cao |
| E | Premium: khoá quyền `household`, giới hạn `household_members`; chủ hết Premium ⇒ nhà `ReadOnly`, gia hạn ⇒ `Active` | vừa |
| F | Thời gian thực: sự kiện mới `household.changed`; `sync.completed` tới **mọi** thành viên khi có hàng của nhà được đẩy | vừa |
| G | Lập nhà ⇒ sao 13 danh mục mặc định thành danh mục của nhà | vừa |

**Client làm (song song, không chờ):** mảng `features/household/`, 5 màn, Drift v32 thêm cột, 25+ truy vấn cá nhân thêm
`idhousehold IS NULL`, đồng bộ đọc / gửi `idhousehold`, thêm 4 mã vào danh sách lỗi vĩnh viễn. Không đổi gì ở `src/Backend`.

---

## 1. Tính năng là gì — quyết định của người dùng (2026-10-23)

| Câu hỏi | Chốt |
|---|---|
| Dùng để làm gì | **Cả bốn**: quỹ chung cùng ghi · xem chung bức tranh tài chính · chia tiền, ai nợ ai · mục tiêu tiết kiệm chung |
| Quỹ chung là gì | **Cả hai kiểu**: quỹ thật (thẻ / tiền mặt chung) cả nhà cùng ghi vào, **và** khoản mỗi người tự trả rồi tính chung |
| Quy mô | Gia đình nhiều người, **tối đa 6** (server ghi đè được bằng giới hạn gói) |
| Vai trò | **Ba vai cố định cho cả nhà**: `Owner` (chủ nhà) · `Member` (thành viên) · `Viewer` (chỉ xem) |
| Riêng tư | Mặc định chỉ thấy dữ liệu **chung**; mỗi người tự bật *"cho nhà xem"* từng ví riêng (chỉ xem, không sửa) |
| Gói | **Chủ nhà cần Premium**; người được mời dùng miễn phí; chủ hết Premium ⇒ nhà **chỉ xem**, không mất dữ liệu |
| Danh mục cho khoản của nhà | **Bộ danh mục riêng của nhà** (sao từ bộ mặc định khi lập nhà; thành viên thêm được) |
| Giải tán nhà | Dữ liệu chung **biến mất với mọi người** — **xoá mềm** ở server |
| Một tài khoản | Ở **tối đa một nhà** |
| Phần server | **Backend làm theo đơn** (client không sửa `src/Backend`) |

**Vai trò làm được gì:**

| Hành động | Owner | Member | Viewer |
|---|:---:|:---:|:---:|
| Xem dữ liệu chung của nhà | ✅ | ✅ | ✅ |
| Ghi / sửa / xoá dữ liệu của nhà (ví, giao dịch, mục tiêu, ngân sách, danh mục của nhà) | ✅ | ✅ | ❌ |
| Tạo / huỷ mã mời, đổi vai, mời ra, chuyển chủ, giải tán | ✅ | ❌ | ❌ |
| Rời nhà | ❌ (phải chuyển chủ hoặc giải tán trước) | ✅ | ✅ |

Nhà `ReadOnly` (chủ hết Premium) hoặc `Dissolved`: **không ai** ghi được dữ liệu của nhà; vẫn xem được (`ReadOnly`) hoặc không
còn gì (`Dissolved`). Thao tác quản lý (đổi vai, rời, mời ra) vẫn chạy khi `ReadOnly`; tạo mã mời / tham gia thì không.

---

## 2. Bốn phần con và phạm vi đơn này

| # | Phần | Đơn backend |
|---|---|---|
| **1** | **Nền móng** — nhà, thành viên, mã mời, vai, Premium, đồng bộ theo phạm vi nhà, danh mục của nhà | **đơn này (mục 50)** |
| 2 | Quỹ chung (ví của nhà cả nhà cùng ghi) + ví riêng *"cho nhà xem"* + màn tổng hợp *Nhà mình* | đơn riêng, sau |
| 3 | Chi chung tự trả + ai nợ ai + trả nợ | đơn riêng, sau |
| 4 | Mục tiêu chung (mỗi người góp từ ví riêng) | đơn riêng, sau |

**Ngoài phạm vi cả bốn phần:** hoá đơn chung (bảng `bill` **không** thêm cột), quét QR, tạo / tham gia nhà khi offline, một tài
khoản ở nhiều nhà, màn quản trị gia đình ở Admin-web (có thể làm sau, không chặn client).

Đơn này đặt **cột và mã lỗi dùng chung** cho cả bốn phần (cột `Idhousehold`, bốn mã đẩy, `NOT_OWNER`) để các đơn sau phần lớn chỉ
thêm. **Ngoại lệ đã biết:** luật tham chiếu (D.2) có thể phải nới ở phần 2 — xem dòng *nạp / rút quỹ* ở D.2.

---

## 3. Việc backend — phần 1, chi tiết

### A (cao) — Tiền đề: kiểm chủ sở hữu khi sửa / xoá qua `/sync/push`

**Hiện trạng (đọc mã 2026-10-23):**
- `modules/sync/sync.service.js:103-113` chỉ so `payload.idaccount` với `req.user.idaccount`; payload để trống `idaccount` thì
  gán từ token (`:116`).
- Lỗi *"Ownership mismatch"* ở đó trả `{status:'error', message}` **không có `code`** — client chỉ dừng gửi lại khi mã nằm trong danh
  sách lỗi vĩnh viễn, nên hàng ấy bị **gửi lại mọi chu kỳ**. Xin trả **`NOT_OWNER`** ở đây luôn.
- Nhánh **sửa** của `upsertWallet` (`sync.repository.js` ~`:291`), `upsertTransaction` (~`:400`), `upsertBudget` (~`:472`),
  `upsertBill` (~`:540`), `upsertGoal` (~`:613`) tìm bản ghi theo khoá chính rồi chỉ so `update_at` — **không** so
  `existing.idaccount`.
- `upsertCategory` có kiểm chủ (`:209-214`, ném `'Cannot modify category belonging to another user'`) nhưng chuỗi ấy không khớp
  nhánh bắt lỗi nào nên ra `DB_ERROR` (client coi là lỗi tạm, gửi lại mãi) — đổi sang `NOT_OWNER`.
- `softDelete` (`:709-752`) xoá theo khoá chính, **không** kiểm chủ ở thực thể nào (nhánh danh mục chỉ chặn `is_default`).

⇒ Ai gửi `{entity:'wallet', operation:'update', payload:{idwallet:'<UUID của người khác>', update_at:<rất mới>, …}}` là ghi đè
được ví người khác; `operation:'delete'` là xoá mềm được. UUID v4 khó đoán, nhưng gia đình **làm lộ UUID giữa thành viên** (ví
*cho nhà xem* — phần 2), nên phải đóng trước.

**Xin:** trong nhánh sửa và xoá của cả 6 thực thể, sau khi tìm `existing`:
- `existing.Idhousehold` **trống** ⇒ chỉ cho khi `existing.idaccount` (danh mục: `existing.create_by`) = người đẩy; sai ⇒ mã
  **`NOT_OWNER`** (mới, vĩnh viễn).
- `existing.Idhousehold` **có** ⇒ luật quyền nhà (mục D).
- Nhánh **tạo** với khoá chính đã tồn tại của người khác cũng đi luật này (không được "tạo đè").

### B (cao) — Migration `database/37_create_household.sql`

Quy ước repo: `docs/Rule_Project/Rule_project.md` §3.2 — tệp `database/N_*.sql`, cột mới nullable / có DEFAULT, cập nhật
`schema.prisma` rồi chỉ `prisma generate`, áp bằng `scripts/apply_migration_37.js` (khuôn `apply_migration_36.js`: `BEGIN` →
`query(sql)` → `COMMIT`, nên tệp SQL **không** tự mở giao tác). Số **37**: lớn nhất hiện là 36 (đơn 49 vế C xin đổi tệp 27 trùng
số — nếu tệp ấy lấy 37 thì đơn này dùng 38; ghi rõ khi trả lời). Ghi vào sổ áp ở `Rule_project.md` (tài liệu của backend).

SQL nháp (đúng quy ước tên cột có nháy kép của repo; backend chỉnh được):

```sql
-- ===== 1. Ba bảng mới =====
CREATE TABLE IF NOT EXISTS "household" (
  "Idhousehold"     SERIAL PRIMARY KEY,
  "Name"            VARCHAR(100) NOT NULL,
  "Owner_idaccount" INT NOT NULL REFERENCES "account"("Idaccount"),
  "Status"          VARCHAR(10) NOT NULL DEFAULT 'Active',
  "Max_members"     SMALLINT NOT NULL DEFAULT 6,
  "Create_at"       TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Update_at"       TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Delete_at"       TIMESTAMP(6) NULL,
  CONSTRAINT "chk_household_status"      CHECK ("Status" IN ('Active', 'ReadOnly', 'Dissolved')),
  CONSTRAINT "chk_household_max_members" CHECK ("Max_members" BETWEEN 2 AND 20)
);

CREATE TABLE IF NOT EXISTS "household_member" (
  "Id"          SERIAL PRIMARY KEY,
  "Idhousehold" INT NOT NULL REFERENCES "household"("Idhousehold"),
  "Idaccount"   INT NOT NULL REFERENCES "account"("Idaccount"),
  "Role"        VARCHAR(7) NOT NULL,
  "Joined_at"   TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Left_at"     TIMESTAMP(6) NULL,
  CONSTRAINT "chk_household_member_role" CHECK ("Role" IN ('Owner', 'Member', 'Viewer'))
);
-- Một tài khoản ở tối đa một nhà; mỗi nhà đúng một chủ đang ở.
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_member_active_account"
  ON "household_member" ("Idaccount") WHERE "Left_at" IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_one_owner"
  ON "household_member" ("Idhousehold") WHERE "Role" = 'Owner' AND "Left_at" IS NULL;
CREATE INDEX IF NOT EXISTS "idx_household_member_active"
  ON "household_member" ("Idhousehold") WHERE "Left_at" IS NULL;

CREATE TABLE IF NOT EXISTS "household_invite" (
  "Code"        VARCHAR(8) PRIMARY KEY,
  "Idhousehold" INT NOT NULL REFERENCES "household"("Idhousehold"),
  "Role"        VARCHAR(7) NOT NULL,
  "Created_by"  INT NOT NULL REFERENCES "account"("Idaccount"),
  "Create_at"   TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Expires_at"  TIMESTAMP(6) NOT NULL,
  "Used_by"     INT NULL REFERENCES "account"("Idaccount"),
  "Used_at"     TIMESTAMP(6) NULL,
  "Revoked_at"  TIMESTAMP(6) NULL,
  CONSTRAINT "chk_household_invite_role" CHECK ("Role" IN ('Member', 'Viewer'))
);

-- ===== 2. Cột Idhousehold cho 5 bảng đồng bộ (bill KHÔNG) =====
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

-- ===== 3. Ràng buộc cá nhân bỏ qua hàng của nhà; thêm ràng buộc theo nhà =====
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
END $$;  -- PostgreSQL không có ADD CONSTRAINT IF NOT EXISTS; khối này cho tệp chạy lại được

DROP INDEX IF EXISTS "uq_category_owner_name";
CREATE UNIQUE INDEX "uq_category_owner_name"
  ON "category" ("Create_by", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = FALSE AND "Delete_at" IS NULL AND "Idhousehold" IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "uq_category_household_name"
  ON "category" ("Idhousehold", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Delete_at" IS NULL AND "Idhousehold" IS NOT NULL;
```

⚠️ **Kiểm trước khi áp:** `New_Database.sql:160` khai ràng buộc **không partial** `"uq_wallet_account_name" UNIQUE ("Idaccount",
"Name")` và `:175` `uq_wallet_default_one`; không thấy tệp nào DROP chúng. Nếu còn trên CSDL (đo bằng
`scripts/verify_db_live.js` hoặc câu 5.1), ví của nhà trùng tên ví riêng của người tạo sẽ vỡ — phải DROP trong cùng tệp.

**`schema.prisma`:** ba model mới; trường `idhousehold Int? @map("Idhousehold")` + quan hệ cho 5 model (khuôn `idaccount Int`).

### C (cao) — Module `households`

Khuôn repo: `api/households.routes.js` đăng ký ở `api/index.js` (cạnh `router.use('/sync', …)`, `:64-70`); thư mục
`modules/household/{household.controller,household.service,household.repository,household.validation}.js`; mọi route qua
`authenticate` (`middleware/auth.js`); lỗi nghiệp vụ ném lỗi có `code` để `middleware/error-handler.js:25-38` trả
`{success:false, statusCode, code, message}` — **`code` ở cấp gốc**, như mọi lỗi client đang đọc.

**Tên hiển thị thành viên:** `user.Fullname` (`schema.prisma:67`), thiếu thì `account.Username`. **Không** trả email / số điện
thoại của thành viên khác.

| # | Endpoint | Ai được | Thân / tham số | Trả về (`data`) |
|---|---|---|---|---|
| 1 | `POST /api/households` | có quyền `household` (mục E), chưa ở nhà nào | `{ name }` (1–100 ký tự, cắt khoảng trắng) | trạng thái nhà (#2) |
| 2 | `GET /api/households/me` | mọi tài khoản | — | `{ household: null }` hoặc mục 3.C.1 |
| 3 | `POST /api/households/invites` | `Owner`, nhà `Active`, chưa đủ người | `{ role: 'Member' \| 'Viewer' }` | `{ code, role, expiresAt }` |
| 4 | `GET /api/households/invites` | `Owner` | — | `[{ code, role, expiresAt, createAt }]` (chỉ mã còn hiệu lực) |
| 5 | `DELETE /api/households/invites/:code` | `Owner` | — | `{ revoked: true }` |
| 6 | `GET /api/households/invites/:code` | mọi tài khoản | — | `{ householdName, ownerName, memberCount, maxMembers, role, expiresAt }` |
| 7 | `POST /api/households/join` | chưa ở nhà nào | `{ code }` | trạng thái nhà (#2) |
| 8 | `PATCH /api/households/members/:idaccount` | `Owner`; đích là `Member` / `Viewer` | `{ role: 'Member' \| 'Viewer' }` | trạng thái nhà |
| 9 | `POST /api/households/transfer-owner` | `Owner`; đích là thành viên đang ở | `{ idaccount }` | trạng thái nhà |
| 10 | `DELETE /api/households/members/:idaccount` | `Owner`; đích khác chính mình | — | trạng thái nhà |
| 11 | `POST /api/households/leave` | `Member` / `Viewer` | — | `{ household: null }` |
| 12 | `DELETE /api/households` | `Owner` | — | `{ household: null }` |

**C.1 — Hình dạng trạng thái nhà** (`GET /me` và mọi thao tác trả nó):

```json
{
  "household": {
    "id": 12,
    "name": "Nhà Đạt – Linh",
    "status": "Active",
    "maxMembers": 6,
    "ownerId": 18,
    "createAt": "2026-10-23T08:00:00.000Z"
  },
  "myRole": "Owner",
  "members": [
    { "idaccount": 18, "displayName": "Trần Quang Đạt", "role": "Owner",  "joinedAt": "2026-10-23T08:00:00.000Z" },
    { "idaccount": 25, "displayName": "Nguyễn Linh",    "role": "Member", "joinedAt": "2026-10-23T09:12:00.000Z" }
  ]
}
```

**C.2 — Luật từng thao tác:**
- **Mã mời:** 8 ký tự từ bảng `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (bỏ `0 O 1 I`), sinh bằng `crypto.randomInt`; hết hạn **48 giờ**;
  **dùng một lần**; huỷ được. Tham gia **khoá hàng mời** (`SELECT … FOR UPDATE` trong giao tác) để hai người không cùng dùng một mã.
- **Đếm trần:** số thành viên đang ở (`Left_at IS NULL`) **cộng mã còn hiệu lực** không được vượt `Max_members` lúc tạo mã; lúc
  tham gia đếm lại thành viên đang ở. `Max_members` lấy từ giới hạn gói của chủ nhà (mục E) lúc tạo nhà; gói đổi thì cập nhật.
- **Tham gia:** trong một giao tác: mã hợp lệ → nhà `Active` → người dùng chưa ở nhà nào → chưa đủ người → thêm `household_member`
  với vai của mã → đánh dấu mã đã dùng. Phát `household.changed` (mục F).
- **Đổi vai:** chỉ `Member` ↔ `Viewer`; không đổi được vai `Owner` (dùng chuyển chủ).
- **Chuyển chủ:** một giao tác: chủ cũ → `Member`, đích → `Owner`, `household.Owner_idaccount` = đích; rồi xét lại `Status`
  theo Premium của chủ mới (mục E).
- **Mời ra / rời:** đặt `Left_at`; dữ liệu người ấy đã ghi **ở lại nhà** (không đổi `Idhousehold`, không đổi người tạo). Mã mời do
  người rời tạo vẫn thuộc nhà (chỉ chủ tạo mã nên không phát sinh).
- **Giải tán:** một giao tác: `household.Status = 'Dissolved'`, `Delete_at = now()`; mọi `household_member` đang ở → `Left_at`; mọi
  mã còn hiệu lực → `Revoked_at`; **xoá mềm mọi hàng** của nhà ở 5 bảng (`Delete_at` / `transaction."Deleted_at"` = now(),
  `Update_at` + `Server_update_at` = now() để lượt kéo về của các máy nhận được cờ xoá). **Không xoá cứng** (quy ước repo).

**C.3 — Mã lỗi API** (4xx, `code` ở cấp gốc):

| Mã | HTTP | Khi |
|---|---|---|
| `HOUSEHOLD_INVITE_INVALID` | 404 | mã không tồn tại / đã huỷ |
| `HOUSEHOLD_INVITE_EXPIRED` | 410 | quá 48 giờ |
| `HOUSEHOLD_INVITE_USED` | 409 | mã đã dùng |
| `HOUSEHOLD_ALREADY_IN_ONE` | 409 | tạo / tham gia khi đang ở một nhà |
| `HOUSEHOLD_FULL` | 409 | đủ người (tạo mã hoặc tham gia) |
| `HOUSEHOLD_NOT_FOUND` | 404 | thao tác cần nhà mà người dùng không ở nhà nào |
| `HOUSEHOLD_NOT_OWNER` | 403 | thao tác của chủ do người khác gọi |
| `HOUSEHOLD_OWNER_MUST_TRANSFER` | 409 | chủ gọi *rời* |
| `HOUSEHOLD_READ_ONLY` | 409 | tạo mã / tham gia khi nhà `ReadOnly` |
| `HOUSEHOLD_CLOSED` | 410 | nhà `Dissolved` |
| `FEATURE_DISABLED` (có sẵn) | 403 | tạo nhà mà gói không có `household` |
| (400 `'Validation failed'` của `middleware/validator.js:33`, có sẵn) | 400 | tên rỗng, vai lạ, mã sai dạng |

**C.4 — Chống dò mã:** giới hạn tần suất cho `GET /invites/:code` và `POST /join` (ví dụ 10 lần / phút / tài khoản) bằng
`middleware/rate-limiter.js` (`express-rate-limit`, đang dùng ở `api/auth.routes.js`).

### D (cao) — Đồng bộ

**D.1 — Kéo về (`sync.repository.js` các hàm `pull…`, `:239-653`).** Thay điều kiện chủ sở hữu, giữ nguyên điều kiện
`server_update_at > since` và thứ tự:

```js
// H = nhà người dùng đang ở (household_member.Left_at IS NULL), hoặc null
const phamVi = H
  ? { OR: [{ idaccount, idhousehold: null }, { idhousehold: H }] }
  : { idaccount, idhousehold: null };
// wallet / transaction / goal / budget: where: { ...phamVi, server_update_at: … }
// category: OR: [{ is_default: true }, { create_by: idaccount, idhousehold: null }, ...(H ? [{ idhousehold: H }] : [])]
```

- Hàng tôi từng ghi vào một nhà **đã rời** không còn về (hàng ấy có `Idhousehold` khác H).
- `pullCategories` liệt kê cột bằng `select` (`:248-262`) — **phải thêm `idhousehold`**; năm hàm kia trả mọi cột.
- Trả khoá `idhousehold` (số hoặc `null`) trong mỗi bản ghi. Hàng tombstone (đã xoá mềm) vẫn đi ra như hôm nay — client cần để
  xoá cục bộ (giải tán nhà).
- `bill` **không** đổi.

**D.2 — Đẩy lên.** `mapEntityFields` (`:18-184`) thêm cho 5 thực thể: nhận khoá `idhousehold` (client gửi đúng tên này, số
nguyên hoặc `null`). ⚠️ Phải thêm `idhousehold` vào **mọi khối `data` của nhánh tạo và sửa** (khoảng 10 khối, `:192-230,
272-308, 377-425, 450-492, 586-638`) — không thêm là trường **bị bỏ qua im lặng** (lớp lỗi quy tắc 4 của repo).
- **Tạo**, `idhousehold` khác trống: người đẩy phải là thành viên đang ở của nhà ấy, vai `Owner` / `Member`, nhà `Active`;
  `idaccount` / `create_by` = người đẩy (từ token).
- **Sửa / xoá** một hàng có `Idhousehold`: cùng điều kiện; **không** đổi `idaccount` / `create_by` (giữ người tạo); **không**
  cho đổi `Idhousehold` của một hàng đã có (chuyển hàng giữa riêng ↔ nhà là `HOUSEHOLD_SCOPE_MISMATCH`).
- **Luật tham chiếu** (kiểm khi tạo / sửa):
  - hàng **của nhà H**: `idwallet`, `idwallet_transfer`, `idcategory`, `idgoal` (ngân sách: `idcategory`) phải trỏ tới hàng của **chính H**;
  - hàng **riêng**: ví / danh mục phải là của **chính người đẩy** (riêng) — **ngoại lệ duy nhất:** giao dịch riêng được trỏ
    `idgoal` tới mục tiêu của nhà **người ấy đang ở** (khoản góp từ ví riêng vào mục tiêu chung — phần 4; mở luật ngay để không
    phải đổi mã về sau).
  - ⚠️ **Chưa cho phép ở phần 1:** chuyển tiền giữa ví riêng và ví của nhà (**nạp / rút quỹ** — `Transfer` có một đầu riêng, một
    đầu của nhà) ⇒ `HOUSEHOLD_SCOPE_MISMATCH`. Phần 2 sẽ định luật cho khoản ấy và cách **mọi** thành viên thấy nó (hôm nay giao
    dịch riêng chỉ về máy chủ của nó, nên số dư quỹ chung sẽ lệch giữa các máy) — có thể phải nới luật này; đơn phần 2 nêu cụ thể.

**D.3 — Bốn mã lỗi mới**, trả theo khuôn kết quả từng thao tác hiện có (`results[i] = {localId, status:'error', code, message}`,
HTTP 200 cho cả lô — `sync.service.js:94-99, 159-237`). Client xếp cả bốn (và `NOT_OWNER` của mục A) là **lỗi vĩnh viễn**
(✅ client **đã thêm** cả năm mã 2026-10-26 — `src/Client-app/lib/core/sync/gui_lo_dong_bo.dart`; backend bật mục A hay D lúc nào
cũng được, hàng bị từ chối không bị đẩy lại mãi):

| Mã | Khi |
|---|---|
| `HOUSEHOLD_NOT_MEMBER` | người đẩy không còn là thành viên đang ở của nhà của hàng |
| `HOUSEHOLD_READ_ONLY` | vai `Viewer`, hoặc nhà `ReadOnly` |
| `HOUSEHOLD_CLOSED` | nhà `Dissolved` |
| `HOUSEHOLD_SCOPE_MISMATCH` | vi phạm luật tham chiếu D.2, hoặc đổi `Idhousehold` của hàng đã có |
| `NOT_OWNER` (mục A) | sửa / xoá hàng riêng của người khác |

Ném trong repository bằng lỗi có `code` riêng và bắt ở `sync.service.js` (cạnh `BILL_ALREADY_PAID`, `:181-184`) — đừng để rơi vào
`DB_ERROR` (`:178`): client coi `DB_ERROR` là lỗi tạm và **gửi lại mãi**.

**D.4 — Thứ tự đẩy.** `ENTITY_PRIORITY` hiện có (`category 10 → wallet 20 → goal 30 → bill 31 → budget 32 → transaction 40`, xoá
theo `100 − w`) đã đúng cho hàng của nhà. Không đổi.

**D.5 — Xung đột.** Giữ ghi-sau-thắng theo `update_at` như hôm nay (client chấp nhận rủi ro lệch đồng hồ giữa hai máy — spec
mục 4.4). Không cần làm gì.

### E (vừa) — Premium

- **Khoá quyền mới** `household` (kiểu `TOGGLE`, tên *"Gia đình"*): Basic `false`, Premium `true`. Thêm một hàng `feature`
  (`INSERT … ON CONFLICT("id") DO UPDATE`, khuôn `database/30_*.sql`) + hai hàng `account_type_permission` (khuôn `32_*.sql`) — đặt
  trong tệp migration của mục B hoặc tệp seed kế tiếp. **Thêm cả vào `DEFAULT_PERMISSIONS`** (`permission.repository.js:6-91`),
  nếu không khoá biến mất khi CSDL lỗi và client coi là *đóng* (client đặt mặc định *thiếu khoá thì đóng* cho tính năng này).
- **Giới hạn mới** `household_members` (kiểu `LIMIT`): Basic `6`, Premium `6` (để admin chỉnh). Server **tự thi hành** khi tạo mã /
  tham gia (mục C.2) — hôm nay `limits` không được kiểm ở server nào.
- `POST /api/households` qua `requireFeature('household')` (`middleware/feature-permission.middleware.js`), trả 403
  `FEATURE_DISABLED` sẵn có.
- **Chủ hết Premium ⇒ `ReadOnly`:** trong vòng hạ cấp `core/scheduler.service.js:261-327` (cạnh `emitToAccount(...,
  'account.downgraded')` ở `:319`), với mỗi tài khoản vừa hạ cấp mà là `Owner` của nhà `Active` ⇒ `Status = 'ReadOnly'`, phát
  `household.changed`. **Gia hạn / nâng cấp** (webhook `:313`, `confirmUpgrade` `:411`, và nhánh JIT — xem đơn 49 vế G) ⇒ nhà của
  chủ ấy `ReadOnly` → `Active`, phát `household.changed`. **Chuyển chủ** cũng xét lại theo Premium chủ mới.
  Phòng hờ cron lỡ: `GET /households/me` xét lại trạng thái theo gói hiện tại của chủ trước khi trả.

### F (vừa) — Thời gian thực

- **Sự kiện mới `household.changed`** tới **mọi thành viên đang ở** (và người vừa bị mời ra / vừa rời): khi tham gia, rời, mời ra,
  đổi vai, chuyển chủ, `Active` ↔ `ReadOnly`, giải tán. Đề xuất phát bằng `emitToAccount` (`core/socket.js:354-366`) cho từng
  thành viên — khỏi phải quản phòng `household_<id>` khi vào / ra. Payload tuỳ backend (client chỉ đọc **tên** sự kiện rồi gọi
  `GET /households/me`), gợi ý `{ idhousehold, reason }`.
- **`sync.completed` tới mọi thành viên:** hôm nay chỉ tới phòng người đẩy (`sync.service.js:245` → `notification.service.js:
  139-149` → `emitSyncCompleted`). Khi lô đẩy có ít nhất một hàng của nhà, phát thêm tới mọi thành viên đang ở khác của nhà ấy —
  máy họ tự kéo về. Payload giữ nguyên.

### G (vừa) — Danh mục của nhà khi lập nhà

Trong giao tác tạo nhà (C #1): với mỗi danh mục mặc định đang sống (`is_default = true, delete_at IS NULL` — 13 hàng, nguồn
`prisma/seed.js:8-25`, tài liệu `DA-XONG/CATEGORY_STABLE_IDS.md`), tạo một hàng `category` mới: `idcategory` = UUID **mới**,
`Is_default = false`, `Create_by` = chủ nhà, `Idhousehold` = nhà, giữ `NameCategory`, `Classify`, `Icon`, `Color`, `Keyword`,
nhóm (`Is_group` / `Idgroup` ánh xạ sang UUID mới của nhóm tương ứng). `Server_update_at` = now() để lượt kéo về của chủ nhà nhận.

---

## 4. Định hướng ba phần con sau (chưa phải việc — để thiết kế lược đồ một lần)

- **Phần 2 — quỹ chung + *cho nhà xem*.** Quỹ chung = `wallet` có `Idhousehold` (không cần bảng mới); giao dịch của nhà ghi vào nó
  đi đúng mục D. *Cho nhà xem* dự kiến một cờ trên ví riêng (ví dụ `Share_with_household BOOLEAN DEFAULT FALSE`): kéo về trả thêm
  ví riêng có cờ của các thành viên khác **và giao dịch của chúng** dưới dạng **chỉ xem** (đẩy lên sửa / xoá chúng ⇒ `NOT_OWNER`).
  Đây là lý do mục A phải xong trước.
- **Phần 3 — chi chung + ai nợ ai.** Khoản *chi chung* là giao dịch **riêng** của người trả kèm thông tin chia (ai chịu bao nhiêu);
  dự kiến một bảng chia (ví dụ `transaction_split(Idtran, Idaccount, Share_amount)`) hoặc cột trên `transaction`, và giao dịch *trả
  nợ* đánh dấu cân nợ. Thành viên trong nhà kéo về được các khoản chi chung của nhau (chỉ xem). Thiết kế chốt ở spec phần 3.
- **Phần 4 — mục tiêu chung.** Mục tiêu = `goal` có `Idhousehold`; khoản góp là giao dịch **riêng** trỏ `idgoal` tới mục tiêu của
  nhà (đã mở ở luật tham chiếu D.2). `Current_amount` của mục tiêu chung tính từ mọi khoản góp của cả nhà — chốt ở spec phần 4.

---

## 5. Kiểm lại

**5.1 CSDL (sau khi áp):**

```sql
-- ba bảng + cột
SELECT table_name FROM information_schema.tables WHERE table_name IN ('household','household_member','household_invite');   -- 3 hàng
SELECT table_name FROM information_schema.columns WHERE column_name = 'Idhousehold'
  AND table_name IN ('wallet','transaction','goal','budget','category');                                                        -- 5 hàng
-- chỉ mục / ràng buộc
SELECT indexname FROM pg_indexes WHERE indexname IN ('uq_household_member_active_account','uq_household_one_owner',
  'uq_wallet_household_name_active','uq_category_household_name','uq_wallet_account_name_active','uq_wallet_default_active',
  'uq_category_owner_name');                                                                                                    -- 7 hàng
SELECT indexdef FROM pg_indexes WHERE indexname IN ('uq_wallet_account_name_active','uq_wallet_default_active','uq_category_owner_name');
  -- cả ba có  "Idhousehold" IS NULL
SELECT conname FROM pg_constraint WHERE conname IN ('uq_wallet_account_name','uq_wallet_default_one');                          -- 0 hàng
SELECT conname FROM pg_constraint WHERE conname = 'chk_wallet_household_not_default';                                         -- 1 hàng
-- quyền
SELECT * FROM "feature" WHERE "id" IN ('household','household_members');                                                     -- 2 hàng
```

**5.2 Hành vi (gợi ý ca test 2 tầng của backend):**
1. **Mục A:** tài khoản X đẩy `update` / `delete` ví riêng của Y (biết UUID) ⇒ `NOT_OWNER`, ví Y không đổi.
2. Basic gọi `POST /households` ⇒ 403 `FEATURE_DISABLED`; Premium ⇒ nhà `Active`, 13 danh mục của nhà, kéo về của chủ có chúng.
3. Tạo mã `Member` → Y xem trước → tham gia ⇒ `members` có Y; dùng lại mã ⇒ `HOUSEHOLD_INVITE_USED`; mã quá 48 giờ ⇒
   `HOUSEHOLD_INVITE_EXPIRED`; Y tham gia nhà thứ hai ⇒ `HOUSEHOLD_ALREADY_IN_ONE`; nhà 6 người ⇒ `HOUSEHOLD_FULL`.
4. Y (`Member`) đẩy tạo ví `idhousehold = H` ⇒ `synced`; X kéo về thấy ví ấy; Z (ngoài nhà) không thấy.
5. Y bị đổi sang `Viewer` rồi đẩy sửa ví của nhà ⇒ `HOUSEHOLD_READ_ONLY`.
6. Giao dịch của nhà trỏ ví riêng ⇒ `HOUSEHOLD_SCOPE_MISMATCH`; giao dịch riêng trỏ `idgoal` mục tiêu của nhà mình ⇒ `synced`;
   trỏ mục tiêu của nhà khác ⇒ `HOUSEHOLD_SCOPE_MISMATCH`.
7. Y rời ⇒ kéo về của Y không còn hàng của H; hàng Y đã ghi vẫn ở H (X vẫn thấy, người tạo vẫn là Y).
8. Chủ hết Premium (chạy vòng hạ cấp) ⇒ nhà `ReadOnly`, `household.changed` tới mọi thành viên; gia hạn ⇒ `Active`.
9. Giải tán ⇒ mọi hàng của H có `Delete_at`, kéo về của X và Y trả tombstone; `GET /me` ⇒ `household: null`.
10. Lô đẩy có hàng của nhà ⇒ `sync.completed` tới cả X lẫn Y.
11. Ví của nhà trùng tên ví riêng của người tạo ⇒ tạo được; hai ví của nhà trùng tên ⇒ `WALLET_NAME_DUPLICATE`.

---

## 6. Trả lời đơn

Cập nhật dòng **50** ở bảng mục 0 `CAN-LAM/README.md` (*"✅ Đã xong"* + ngày) và ghi **tên chốt** nếu khác đề xuất: số tệp
migration, đường dẫn endpoint, tên mã lỗi, khoá quyền, tên sự kiện. Client soát bằng **mã + CSDL** như các đơn trước. Đừng sửa
tài liệu của client (`docs/superpowers/specs/…`, `docs/superpowers/sync/SYNC_DOCUMENTATION.md`) — thấy chỗ sai thì ghi vào đơn này.
