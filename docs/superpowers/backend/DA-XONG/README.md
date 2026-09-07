# DA-XONG — tài liệu backend không còn việc

**Gom lại ngày 2026-09-07.**

> Thư mục này **không phải thùng rác**. Mỗi tệp ở đây là lý lẽ đứng sau một
> quyết định đã đi vào lược đồ hoặc vào mã đang chạy. Khi ai đó hỏi *"vì sao cột
> này tồn tại"* hay *"vì sao index này lại bỏ `Classify`"*, câu trả lời nằm ở
> đây chứ không ở chỗ nào khác.
>
> Điều duy nhất đã hết là **việc phải làm**. Việc còn lại nằm ở
> [`../CAN-LAM/README.md`](../CAN-LAM/README.md) — bốn mục, không hơn.

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
| [2026-09-05-backend-goal-priority.md](./2026-09-05-backend-goal-priority.md) | Cột `goal.Priority` đã có. Client **chưa làm** tính năng ưu tiên mục tiêu — nhưng backend không còn gì phải làm, và lối "xin cột trước khi viết mã" đã chứng minh rẻ hơn hai lần "làm trước xin sau" |

## 2. Đã xong từ trước, hoặc chỉ để tham khảo lịch sử

Tám tài liệu này vốn nằm ở thư mục cha; gom về đây để thư mục cha chỉ còn ba
tệp bối cảnh và hai mục lục.

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

---

## 3. Hai chỗ dễ đọc nhầm

- **"Đã xong" nói về phía backend, không phải phía client.** `goal.Priority` có
  cột nhưng client chưa dựng màn ưu tiên; `transaction.Idgoal` có cột nhưng
  client vẫn còn nhánh so **tên** chưa gỡ. Muốn biết client còn nợ gì thì đọc
  `docs/CLIENT_APP_KNOWN_GAPS.md`, không phải thư mục này.

- **Tài liệu là ảnh chụp tại thời điểm viết.** Trạng thái ở đây đo ngày
  2026-09-07 trên `localhost:5432/PersonFinance`. Trước khi dựa vào bất kỳ dòng
  nào, mở `schema.prisma` hoặc truy vấn thẳng CSDL để đối chiếu — đúng nguyên
  tắc mà `CLAUDE.md` đặt ra cho cả kho này.
