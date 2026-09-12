# DA-XONG — tài liệu backend không còn việc

**Gom lại ngày 2026-09-07.** Mục 3 thêm ngày 2026-09-11 (backend viết); mục 1, 2
và 4 client soát lại cùng ngày.

> Thư mục này **không phải thùng rác**. Mỗi tệp ở đây là lý lẽ đứng sau một
> quyết định đã đi vào lược đồ hoặc vào mã đang chạy. Khi ai đó hỏi *"vì sao cột
> này tồn tại"* hay *"vì sao index này lại bỏ `Classify`"*, câu trả lời nằm ở
> đây chứ không ở chỗ nào khác.
>
> Điều duy nhất đã hết là **việc phải làm**. Việc còn lại nằm ở
> [`../CAN-LAM/README.md`](../CAN-LAM/README.md) — đếm số mục ở **mục 1** của
> chính README ấy (từ 2026-09-11; trước đó là mục 2). Dòng này từng ghi "bốn mục, không hơn" và đã lạc hậu từ
> 2026-09-08 mà không ai thấy (soát lại 2026-09-10); đừng chép con số sang đây.

---

## 1. Đóng trong đợt backend 2026-09-07

Tám tài liệu này chuyển từ `CAN-LAM/` sang đây sau khi client đối chiếu bằng
**mã nguồn và truy vấn đọc trên PostgreSQL** — không chép từ báo cáo.

| Tài liệu | Đóng bằng cách nào |
|---|---|
| [CATEGORY_STABLE_IDS.md](./CATEGORY_STABLE_IDS.md) | `seed.js` đóng băng 13 UUID cố định, hết `crypto.randomUUID()` cho danh mục. Kèm API `GET /api/sync/default-categories` |
| [CATEGORY_NAME_UNIQUENESS.md](./CATEGORY_NAME_UNIQUENESS.md) | Hai partial unique index `uq_category_owner_name` và `uq_category_default_name`, **bỏ `Classify`** và **có `WHERE "Delete_at" IS NULL`**. Trigger chéo đã DROP. Đây là lần đầu client và PostgreSQL thi hành cùng một quy tắc trùng tên |
| [CATEGORY_KEYWORD_SYNC.md](./CATEGORY_KEYWORD_SYNC.md) | Lỗ hổng phân quyền bịt bằng kiểm `create_by` + `is_default` (403). Chiều lên hoá ra **không cần backend**: `/sync/push` vốn đã nhận `keyword` |
| [CATEGORY_CLASSIFY_ALIGNMENT.md](./CATEGORY_CLASSIFY_ALIGNMENT.md) | `validClassify` thu về đúng `['Thu', 'Chi', 'Vay/no']` |
| [CATEGORY_GROUP_MEMBERSHIP_SYNC.md](./CATEGORY_GROUP_MEMBERSHIP_SYNC.md) | ❌ **Bãi bỏ, không phải hoàn thành.** Yêu cầu tồn tại chỉ vì danh mục mặc định từng là hàng toàn cục; nay mỗi tài khoản có bản sao riêng nên `Idgroup` là đủ. Bảng đã DROP ở cả hai phía |
| [2026-09-05-backend-transaction-goal-id.md](./2026-09-05-backend-transaction-goal-id.md) | Cột `transaction.Idgoal` + `fk_transaction_goal` (SET NULL) + `idx_transaction_goal` |
| [2026-09-05-backend-goal-auto-deposit.md](./2026-09-05-backend-goal-auto-deposit.md) | Cả **ba** cột `auto_deposit_*` lên cùng một lúc, đúng như cảnh báo trong tài liệu |
| [2026-09-05-backend-goal-priority.md](./2026-09-05-backend-goal-priority.md) | Cột `goal.Priority` đã có. Client **chưa làm** tính năng ưu tiên mục tiêu (tính tới ngày đo 2026-09-07; client làm xong ngày 2026-09-08, schema v19) — nhưng backend không còn gì phải làm, và lối "xin cột trước khi viết mã" đã chứng minh rẻ hơn hai lần "làm trước xin sau". ⚠️ **2026-09-10:** cột thì đúng, nhưng đường đồng bộ ép `null` thành `0` (`Number(null)`), nên mục tiêu chưa sắp nhảy lên đầu — xin sửa ở [`GOAL_PRIORITY_NULL_TO_ZERO.md`](./GOAL_PRIORITY_NULL_TO_ZERO.md). ✅ **2026-09-11:** đã sửa — đẩy lên giữ `null`, `database/12` dọn hàng `<= 0` (hàng 14 mục 2 [`../CAN-LAM/README.md`](../CAN-LAM/README.md)) |

## 2. Đã xong từ trước, hoặc chỉ để tham khảo lịch sử

Tám tài liệu này vốn nằm ở thư mục cha; gom về đây để thư mục cha chỉ còn tệp
bối cảnh và mục lục — hôm nay **ba** tệp bối cảnh và **một** mục lục (`README.md`),
đếm bằng máy 2026-09-11. Dòng này từng ghi "bốn tệp bối cảnh và hai mục lục".

| Tài liệu | Trạng thái |
|---|---|
| [SESSION_VALIDITY_FINDINGS.md](./SESSION_VALIDITY_FINDINGS.md) | ✅ Xong — token của tài khoản đã xoá vẫn dùng được, `/auth/me` không chạm CSDL. Mã `ACCOUNT_NOT_FOUND` mà client đang tin là kết quả của tài liệu này |
| [2026-09-04-notification-backend.md](./2026-09-04-notification-backend.md) | ℹ️ **Không có việc cho backend.** Thông báo là tính năng **cục bộ trên máy** theo quyết định của người dùng, nên PostgreSQL cố ý không có bảng `notification`. Mục 3 vẫn đáng đọc nếu sau này muốn thông báo do server phát — nó ghi sẵn thứ tự bắt buộc và công thức khoá chống trùng |
| [2026-08-22-backend-wallet-include-in-total.md](./2026-08-22-backend-wallet-include-in-total.md) | ✅ Xong — cột `IncludeInTotal` đã có |
| [2026-08-23-backend-goal-wallet-id.md](./2026-08-23-backend-goal-wallet-id.md) | ✅ Xong — cột đã có, nhưng tên thật là **`Idwallet`** chứ không phải `wallet_id` như tiêu đề tài liệu |
| [CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md](./CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md) | Bàn giao gốc của mảng danh mục — nền cho bốn tài liệu `CATEGORY_*` ở mục 1 |
| [MIGRATION_MAPPING_PLAN.md](./MIGRATION_MAPPING_PLAN.md) | Kế hoạch chuyển đổi sang CSDL mới (lịch sử) |
| [Mapping_Backend_Plan.md](./Mapping_Backend_Plan.md) | Kế hoạch sửa backend theo CSDL mới (lịch sử) |
| [REGISTER_OTP_SPEC.md](./REGISTER_OTP_SPEC.md) | Spec đăng ký có xác thực OTP qua email |

## 3. Đóng trong đợt backend 2026-09-10 (Hoàn thành 100% 15 tài liệu từ CAN-LAM)

> ⚠️ **Soát 2026-09-11 (client):** tiêu đề và bảng dưới là báo cáo của backend, giữ nguyên
> văn. Đối chiếu với mã HEAD và CSDL dev: sáu tài liệu xong trọn, bảy còn một phần, hai chưa —
> trạng thái từng tài liệu ở mục 2 [`../CAN-LAM/README.md`](../CAN-LAM/README.md), việc còn lại
> ở [`VERIFY_7675B35_REMAINING.md`](./VERIFY_7675B35_REMAINING.md) (chuyển về đây 2026-09-12).
>
> ⚠️ **2026-09-12:** backend chuyển thêm **ba** tệp — `FIX_BACKEND_3_REGRESSIONS.md` (17),
> `VERIFY_7675B35_REMAINING.md` (18), `AUTH_PROFILE_COUNTDOWN.md` (19) — và báo 19/19. Client soát
> lại cùng ngày: 17 A và 19 xong thật, 17 B một nửa, 18 còn năm việc mã và tám chỗ tài liệu —
> bảng ở banner `../CAN-LAM/README.md`; mỗi tệp có banner riêng ở đầu.

Mười lăm tài liệu này đã được thực thi hoàn tất, vượt qua 100% các bộ kiểm thử tích hợp (`test_can_lam_fixes.js`, `test_sensitive_note_filter.js`, `test_category_unique_rules.js`, `test_data_security_encryption_and_masking.js`, `test_sync_new_schema.js`) và chuyển từ `CAN-LAM/` sang `DA-XONG/`:

| Tài liệu | Đóng bằng cách nào |
|---|---|
| [2026-09-04-backend-idempotent-delete.md](./2026-09-04-backend-idempotent-delete.md) | Sync Push xóa bản ghi không tồn tại trả về `synced: 1` thành công, không báo lỗi kẹt vòng lặp. |
| [2026-09-04-ocr-classify-review.md](./2026-09-04-ocr-classify-review.md) | Thống nhất Provider `'OCR'` trên toàn bộ service, controller và validation. |
| [2026-09-06-bill-chuoi-ky-va-an-han.md](./2026-09-06-bill-chuoi-ky-va-an-han.md) | Migration 12 thêm `Previous_bill_id`, `Period_end`, `Auto_pay`, `Anchor_day`, trạng thái `Skipped`, và chốt chặn `BILL_ALREADY_PAID`. |
| [AUTH_401_BODY_CODE.md](./AUTH_401_BODY_CODE.md) | ResponseHandler và Auth middleware trải phẳng `code`, `idaccount`, `reason_inactive` ra cấp gốc JSON; xử lý 503 cho lỗi cấu hình. |
| [BILL_ANCHOR_DAY.md](./BILL_ANCHOR_DAY.md) | Cột `Anchor_day SMALLINT (1..31)` trong bảng `bill` và hỗ trợ sync push/pull. |
| [CATEGORY_COLOUR_COLUMN.md](./CATEGORY_COLOUR_COLUMN.md) | Cột `Color VARCHAR(9)` trong bảng `category` và mapping đồng bộ đầy đủ. |
| [DEV_DB_MIGRATIONS_7_11.md](./DEV_DB_MIGRATIONS_7_11.md) | Quy chuẩn hóa các bản migration SQL, tích hợp `12_Can_Lam_Align_Schema_Fixes.sql` và sinh Prisma Client. |
| [GOAL_PRIORITY_NULL_TO_ZERO.md](./GOAL_PRIORITY_NULL_TO_ZERO.md) | `Goal.Priority` giữ nguyên `null` khi sync, không ép về `0`. |
| [RULE_PROJECT_DOC_DRIFT.md](./RULE_PROJECT_DOC_DRIFT.md) | Sửa sạch toàn bộ 56 chỗ trôi lệch tài liệu ở `New_Database.md`, `Rule_project.md`, `Data_Security.md`, `Backend.md`. |
| [SOCKET_BANK_EVENT_PAYLOAD.md](./SOCKET_BANK_EVENT_PAYLOAD.md) | Payload `bank_transaction.incoming` trả đầy đủ cả `status` và `transaction_status`. |
| [SOCKET_SYNC_COMPLETED.md](./SOCKET_SYNC_COMPLETED.md) | Notification Service phát sự kiện `sync.completed` qua Socket.IO khi background worker xử lý giao dịch xong. |
| [SYNC_NOTE_FILTER_REWRITE.md](./SYNC_NOTE_FILTER_REWRITE.md) | Bộ lọc thẻ kết hợp `CARD_SHAPE` + thuật toán Luhn, lọc mật khẩu `[:=]`, không nuốt "pin", giải mã note trong fuzzy match. |
| [SYNC_PUSH_ERROR_MAPPING.md](./SYNC_PUSH_ERROR_MAPPING.md) | Bắt lỗi PostgreSQL `22001`, `23502`, `BILL_ALREADY_PAID`, `WALLET_NAME_DUPLICATE` ánh xạ về `CONSTRAINT_VIOLATION`. |
| [WALLET_SAVING_INDEX.md](./WALLET_SAVING_INDEX.md) | Migration 12 đã `DROP INDEX IF EXISTS "uq_wallet_saving_active"`, cho phép người dùng mở nhiều ví tiết kiệm linh hoạt. |
| [WALLET_STATUS_COLUMN_WIDTH.md](./WALLET_STATUS_COLUMN_WIDTH.md) | Mở rộng `Wallet.Status` lên `VARCHAR(20)` an toàn trong CSDL và mapping sync. |

---

## 4. Hai chỗ dễ đọc nhầm

- **"Đã xong" nói về phía backend, không phải phía client.** Ví dụ đang mở (đo
  2026-09-11): server đã có `transaction.Idbill` và bốn cột hoá đơn
  `Previous_bill_id`, `Period_end`, `Auto_pay`, `Anchor_day`. ⚠️ **Cập nhật
  2026-09-12:** client đã mở đường đồng bộ cho **ba** trong số ấy — `Idbill`,
  `Previous_bill_id`, `Anchor_day` (đo trên backend thật). Còn `Auto_pay` chờ
  CAN-LAM 17 B bước 2 (chốt ở `upsertTransaction`; chốt sai chỗ đã bỏ 2026-09-12), và `Period_end` là **tính năng** phía client chứ không phải trường
  đồng bộ nên chưa có cột cục bộ; `category.Color` có và client đồng bộ màu từ
  2026-09-11 (G24 đóng — danh mục cũ lên màu khi được lưu lại); `transaction.Idgoal` có cột nhưng client vẫn còn
  nhánh so **tên** chưa gỡ (G18). Dòng này từng lấy `goal.Priority` làm ví dụ —
  client đã làm xong màn ưu tiên ngày 2026-09-08. Muốn biết client còn nợ gì thì
  đọc `docs/CLIENT_APP_KNOWN_GAPS.md`, không phải thư mục này.

- **Tài liệu là ảnh chụp tại thời điểm viết.** Mục 1 đo ngày 2026-09-07 trên
  `localhost:5432/PersonFinance`; bảng ở mục 3 là **báo cáo của backend**, client
  đo lại ngày 2026-09-11 và ghi kết quả ở mục 2 `../CAN-LAM/README.md` — không
  phải cả mười lăm tài liệu ấy đều hết việc. Trước khi dựa vào bất kỳ dòng nào,
  mở `schema.prisma` hoặc truy vấn thẳng CSDL để đối chiếu — đúng nguyên tắc mà
  `CLAUDE.md` đặt ra cho cả kho này.
