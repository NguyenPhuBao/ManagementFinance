# Backend — Mục lục, thứ tự đọc và thứ tự thi công

> Thư mục này gom mọi tài liệu backend của FlowMoney. Có **19 tài liệu**, phần
> lớn đã làm xong — bảng "Còn phải làm" bên dưới là thứ cần đọc trước.
>
> Cập nhật 2026-09-04 (lần hai, sau khi gộp `origin/main` `dfda862` mang mô-đun
> OCR F013 và bộ phân loại hai cấp F012). Trạng thái từng mục đối chiếu với
> `schema.prisma` và mã nguồn thật tại `fcf7659`, không chép lại từ bản cũ. Bảng
> trạng thái đầy đủ hơn nằm ở mục 14 `docs/PROJECT_CONTEXT.md`.

---

## 0. Bắt đầu từ đâu — chín bước, theo đúng thứ tự này

Đây là **thứ tự thi công**, không phải thứ tự đọc cho vui. Mỗi bước ghi rõ chi
phí ước lượng và thứ nó mở khoá.

> **Cập nhật 2026-09-04 (lần hai), sau một vòng thẩm định phản biện.** Thứ tự
> dưới đây đã đổi so với bản buổi sáng. Nguyên tắc phân loại mới: tách **"đang
> hỏng hôm nay"** khỏi **"nợ phải trả trước khi làm bước tiếp theo"**. Trộn hai
> loại đó là cách nhanh nhất để người đọc mất niềm tin vào cả danh sách.

### Nhóm A — đang gây hại hôm nay

| Bước | Làm gì | Ở đâu | Chi phí |
|---|---|---|---|
| **1** | **Xác thực Socket.io và xoá bốn dòng `io.emit` toàn cục.** Máy chủ không kiểm token ở đâu cả; `join_account` cho vào phòng theo con số client tự khai; và mỗi hàm phát đều bồi thêm một bản phát cho **mọi** socket. `emitAuditActivity` đang rò tên người dùng + hành động ra mọi socket ẩn danh **ngay lúc này**, vì audit middleware chạy trên mọi request | `core/socket.js:11-31`, `:60`, `:84`, `:104`, `:124` | một buổi — **phải sửa cùng lúc** `Admin-web/src/hooks/useSocket.js` vì consumer hiện kết nối không kèm token |
| **2** | `/sync/push` trả **thành công** khi xoá bản ghi server không có | `sync.service.js:112-119` | vài dòng |
| **3** | Trả **mã lỗi ổn định** thay cho nguyên văn `err.message` | `sync.service.js:147-160` | nửa buổi |

### Nhóm B — chặn tính năng người dùng đã thấy hoặc sắp thấy

| Bước | Làm gì | Ở đâu | Chi phí |
|---|---|---|---|
| **4** | Giữ nguyên `time_recurrence = null`, thôi ép về `'Month'` — mở khoá ngân sách **"Ngày cụ thể"** | `sync.repository.js:325` | một dòng |
| **5** | Sửa tham số `classifyBatch` (đang truyền Array vào tham số Object) — làm **chạy được** phân loại từng mặt hàng, hiện chưa bao giờ chạy | `classify.service.js:372` | một dòng |
| **6** | Thêm `GEMINI_API_KEY` vào `.env.example`, và sửa error handler để không nuốt `statusCode`/`errorCode` | `.env.example`, `middleware/error-handler.js` | một giờ |
| **7** | Ba việc logic còn lại của mô-đun AI: đối chiếu `create_by` trước khi ghi từ khoá · sửa dedup Quy tắc 3 (bỏ quên `counterpart`, `note`, `provider`) · chặn `_mock*` khỏi `req.body` | `classify.repository.js:64`, `dedup.repository.js:158-182`, `ocr.controller.js:21` | một buổi |

### Nhóm C — nợ phải trả trước bước tiếp theo, cần migration

| Bước | Làm gì | Ở đâu | Chi phí |
|---|---|---|---|
| **8** | Thu hẹp `validClassify` | `sync.validation.js:103` | một dòng |
| **9** | Ba việc về danh mục, làm **liền một mạch**: ID ổn định cho seed → unique index theo tên chuẩn hoá (**có mệnh đề `WHERE "Delete_at" IS NULL`**) → bảng membership. Cùng lúc đưa `Idaccount` vào `uq_transaction_external` | `seed.js:150`, `schema.prisma:129` và `:299`, entity mới | nhiều buổi + migration |

**Nguyên tắc xếp thứ tự:** nhóm A là rò rỉ và hỏng vĩnh viễn — bịt trước khi đi
tìm nguyên nhân gốc. Nhóm B rẻ, làm được xen kẽ, và mỗi bước gỡ một tính năng
khỏi trạng thái chết. Nhóm C đắt nhất, cần migration, nhưng đừng bỏ: bước 9 là
thứ duy nhất còn chặn **G10**.

> ⚠️ **Bước 9 phải làm liền một mạch.** Ba tài liệu phụ thuộc lẫn nhau
> (`CATEGORY_STABLE_IDS` → `CATEGORY_NAME_UNIQUENESS` →
> `CATEGORY_GROUP_MEMBERSHIP_SYNC`). Làm lẻ một cái sẽ phải làm lại: ID ổn định
> là điều kiện để hai cái kia không phải dùng **tên danh mục** làm khoá nối.
>
> Vế `WHERE "Delete_at" IS NULL` không phải chi tiết trang trí — thiếu nó thì
> mỗi lần người dùng xoá một danh mục cá nhân mặc định, client sẽ tạo lại nó ở
> **mỗi lần mở app** và bản ghi mới không bao giờ lên được server. Chuỗi đầy đủ
> ở mục 10 của `2026-09-04-ocr-classify-review.md`.
>
> Client đã cầm máu ngày 2026-09-04 (xếp vi phạm UNIQUE thành `permanent` nên
> hàng đợi không còn bị kéo chậm), nhưng đó là **lớp cầm máu, không phải bản vá
> gốc**. Thêm mệnh đề WHERE thì mọi bản ghi đang bị chặn **tự quay lại hàng đợi**
> và đồng bộ thành công — người dùng không phải làm gì.
>
> Vế `uq_transaction_external` thì **chưa nổ được** hôm nay (client không gửi
> `provider`/`bank_tran_id`), nhưng phải xong **trước khi** client nối luồng OCR.

---

## 1. Đọc trước để có bối cảnh

Ba tài liệu này **không phải việc cần làm** — chúng là nền để hiểu phần còn lại.

| # | Tài liệu | Nội dung |
|---|---|---|
| 1 | [New_Database.md](./New_Database.md) | Lược đồ chuẩn của PostgreSQL. `CLAUDE.md` chỉ định đây là **nguồn sự thật** cho schema |
| 2 | [2026-08-10-backend-sync-spec.md](./2026-08-10-backend-sync-spec.md) | Hợp đồng `/sync/push` và `/sync/pull`: định dạng request/response, thứ tự entity, quy tắc LWW |
| 3 | [PROGRESS-BACKEND.md](./PROGRESS-BACKEND.md) | Checklist B1→B7 và tiến độ từng bước |

---

## 2. Còn phải làm — trạng thái từng tài liệu

Tám tài liệu, xếp theo mức ưu tiên. Bảng này trả lời **"tài liệu nào còn việc và
việc đó là gì"**; muốn biết **làm theo trình tự nào** thì xem mục 0 ở trên —
một tài liệu có thể trải ra nhiều bước ở đó, và ngược lại.

| # | Tài liệu | Trạng thái |
|---|---|---|
| 1 | [CATEGORY_KEYWORD_SYNC.md](./CATEGORY_KEYWORD_SYNC.md) | ⛔ **Lỗ hổng phân quyền còn nguyên** ở `POST /api/ai/classify/feedback` — `appendCategoryKeyword()` không đọc `create_by`. **Nghiêm trọng hơn từ 2026-09-04:** `keyword.matcher` nay là Tầng 1 trên đường quét hoá đơn, nên từ khoá ghi bậy vào danh mục mặc định làm sai kết quả phân loại của **mọi** người dùng. ✅ Chiều **xuống** đã nối xong (client tự làm 2026-09-04, backend vốn đã gửi `keyword` trong `/sync/pull`); chiều **lên** vẫn cần backend quyết mô hình dữ liệu |
| 2 | [2026-09-04-backend-idempotent-delete.md](./2026-09-04-backend-idempotent-delete.md) | ⛔ **Ba việc độc lập** trong `/sync/push`. **(A)** xoá bản ghi không tồn tại đang bị trả về là lỗi → client đẩy lại vĩnh viễn. **(B)** `message` là nguyên văn stack trace Prisma, để lộ đường dẫn máy chủ và nội dung hàng dữ liệu — và client nay đã có tới **ba** phép khớp chuỗi dựng tạm vì thiếu mã lỗi ổn định. **(C)** `upsertBudget` ép `time_recurrence = null` thành `'Month'` → **chặn hẳn** ngân sách "Ngày cụ thể", và làm ngân sách tự hết hạn sớm sau khi pull. Cả ba chỉ sửa logic, **không cần migration** |
| 3 | [2026-09-04-ocr-classify-review.md](./2026-09-04-ocr-classify-review.md) | ⛔ **Tám việc** từ đợt đẩy OCR/Classify, đã qua một vòng thẩm định phản biện và đo trực tiếp trên CSDL. Nặng nhất: **Socket.io không xác thực + bốn dòng `io.emit` toàn cục**, đang rò tên người dùng ra mọi socket ẩn danh **hôm nay**. Rồi: `classifyBatch` sai kiểu tham số → phân loại từng mặt hàng chưa bao giờ chạy · thiếu `GEMINI_API_KEY` · dedup Quy tắc 3 chặn nhầm · cửa hậu `_mock*`. ⚠️ Bản đầu của tài liệu này xếp `uq_transaction_external` ưu tiên cao nhất — **đã rút lại**, việc đó chưa nổ được, xem khung đầu tài liệu |
| 4 | [CATEGORY_NAME_UNIQUENESS.md](./CATEGORY_NAME_UNIQUENESS.md) | ⚠️ Một phần — Admin-web đã thi hành quy tắc, nhưng còn 4 khoảng hở (không gom khoảng trắng, không chuẩn hoá NFC, thiếu vế chéo "người dùng ↔ mặc định"), và `/sync/push` chưa kiểm gì cả. CSDL **có** hai unique index nhưng chúng thi hành một quy tắc **khác** — lệch theo cả hai chiều, chi tiết ở mục 2 của tài liệu. ⚠️ Vế "chặt hơn" (hàng đã xoá mềm vẫn giữ chỗ tên) có **đường kích hoạt tự lặp ở mỗi lần mở app** — client đã cầm máu 2026-09-04 nhưng bản ghi vẫn không lên được server; chỉ mệnh đề `WHERE "Delete_at" IS NULL` mới dứt điểm |
| 5 | [CATEGORY_STABLE_IDS.md](./CATEGORY_STABLE_IDS.md) | ⛔ `seed.js:150` vẫn `crypto.randomUUID()`, nên tên danh mục bị dùng làm khoá nối giữa hai phía — đây là nguyên nhân gốc của các lỗi 11.3–11.6 trong `PROJECT_CONTEXT.md` |
| 6 | [CATEGORY_GROUP_MEMBERSHIP_SYNC.md](./CATEGORY_GROUP_MEMBERSHIP_SYNC.md) | ⛔ Thứ **duy nhất** còn chặn G10: backend chưa có bảng/entity cho việc gán danh mục **mặc định** vào nhóm |
| 7 | [CATEGORY_CLASSIFY_ALIGNMENT.md](./CATEGORY_CLASSIFY_ALIGNMENT.md) | ⚠️ Gần xong — còn đúng một bước thu hẹp `validClassify` (`sync.validation.js:103`) |
| 8 | [2026-09-05-backend-transaction-goal-id.md](./2026-09-05-backend-transaction-goal-id.md) | 🔓 **Mở khoá, không phải sửa lỗi** — xin một cột nullable `transaction.Idgoal` để giao dịch tích luỹ nối với mục tiêu bằng ID thay vì bằng tên. **Không có gì đang hỏng**: trên máy tạo ra dữ liệu client đã nối đúng, máy khác thì rơi xuống nhánh so tên (hiện thừa khi hai mục tiêu trùng tên hoặc tên này là tiền tố tên kia). Nhưng nó **chặn hẳn** hướng bỏ bộ đếm `current_amount` để suy tiến độ từ chính giao dịch. Rẻ nhất là gộp vào đợt migration của **bước 9** |
| 9 | [2026-09-05-backend-goal-auto-deposit.md](./2026-09-05-backend-goal-auto-deposit.md) | 🔓 **Mở khoá, không phải sửa lỗi** — xin ba cột nullable cho cấu hình **trích tiền tự động** của mục tiêu (`auto_deposit_amount`, `auto_deposit_wallet_id`, `auto_deposit_last_run`). Client đã làm xong tính năng (schema v15) nhưng ba cột ở lại máy, nên bật trích ở điện thoại rồi đăng nhập máy khác thì máy kia **không trích gì cả**. ⚠️ **Ba cột phải lên CÙNG LÚC**: đưa hai cột đầu mà bỏ `auto_deposit_last_run` là mỗi máy giữ một mốc riêng và **cả hai cùng chuyển tiền** — hỏng nặng hơn hiện trạng. Rẻ nhất là gộp vào đợt migration của **bước 9** cùng `transaction.Idgoal` |

### Vì sao mức ưu tiên xếp như vậy

> Bảng này xếp theo **mức ưu tiên của từng tài liệu**; mục 0 xếp theo **thứ tự
> thi công**. Hai cách xếp không trùng nhau, nên mỗi đoạn dưới đây ghi kèm số
> bước tương ứng ở mục 0.

**Mục 3 có việc gấp nhất trong cả thư mục** — Socket.io không xác thực, đang rò
tên người dùng ra mọi socket ẩn danh. Đó là **bước 1** ở mục 0, đứng trước tất
cả vì nó là thứ duy nhất đang chảy máu dữ liệu thật.

**Mục 1 đứng đầu bảng** vì là lỗ hổng **phân quyền**, và mức nghiêm trọng vừa
tăng khi bộ phân loại được đưa lên đường chạy thật. Nó là **bước 7** ở mục 0 —
xếp sau nhóm "đang gây hại" vì khai thác được nó cần biết `idcategory` của
người khác, còn Socket.io thì không cần gì cả.

**Mục 2 và 3 nên đọc cùng nhau.** Nhiều lỗi ghi mà mục 3 mô tả chỉ trở thành
*hỏng vĩnh viễn* nhờ (A) và (B) của mục 2 — đó là lý do (A) là **bước 2**: nó
cắt vòng lặp bất kể nguyên nhân gốc là gì, kể cả nguyên nhân chưa ai tìm ra.
(B) càng đáng làm sau 2026-09-04: client vừa phải thêm phép **khớp chuỗi thứ
ba** vào `_classifyFailure`, và phải đoán ba biến thể câu chữ cho cùng một lỗi
vì không biết Prisma phiên bản nào đang chạy.

**Mục 5 → 4 → 6 phụ thuộc lẫn nhau và phải làm liền một mạch** — đó là **bước
9** ở mục 0. Thứ tự này quan trọng: **mục 5 là nguyên nhân gốc**, ID ổn định cho
seed là điều kiện để hai mục kia không phải dùng *tên danh mục* làm khoá nối.
Làm mục 4 trước mục 5 là phải làm lại.

**Mục 7 rẻ nhất trong cả bảng** — một dòng — nhưng hậu quả cũng nhẹ nhất, nên nó
là **bước 8**, không phải bước đầu.

---

## 3. Đã xong hoặc chỉ để tham khảo

| Tài liệu | Trạng thái |
|---|---|
| [2026-09-04-notification-backend.md](./2026-09-04-notification-backend.md) | ℹ️ **Không có việc cho backend.** Thông báo là tính năng **cục bộ trên máy** theo quyết định của người dùng — không FCM, không đồng bộ giữa thiết bị, nên PostgreSQL **cố ý không có** bảng `notification`. Tài liệu ghi lại ba khoảng trống phía backend (socket không xác thực · không có scheduler · queue `send-notification` rỗng) kèm mức khẩn thật của từng cái, và **đính chính** một nhận định sai đang lưu hành về `bill.time_notification` |
| [SESSION_VALIDITY_FINDINGS.md](./SESSION_VALIDITY_FINDINGS.md) | ✅ Xong — token của tài khoản đã xoá vẫn dùng được, `/auth/me` không chạm CSDL |
| [2026-08-22-backend-wallet-include-in-total.md](./2026-08-22-backend-wallet-include-in-total.md) | ✅ Xong — cột `IncludeInTotal` đã có trong `schema.prisma` |
| [2026-08-23-backend-goal-wallet-id.md](./2026-08-23-backend-goal-wallet-id.md) | ✅ Xong — cột đã có, nhưng tên thật là **`Idwallet`** chứ không phải `wallet_id` như tiêu đề tài liệu |
| [CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md](./CATEGORY_MANAGEMENT_BACKEND_HANDOFF.md) | Bàn giao gốc của mảng danh mục — nền cho bốn tài liệu `CATEGORY_*` ở bảng trên |
| [MIGRATION_MAPPING_PLAN.md](./MIGRATION_MAPPING_PLAN.md) | Kế hoạch chuyển đổi sang CSDL mới (lịch sử) |
| [Mapping_Backend_Plan.md](./Mapping_Backend_Plan.md) | Kế hoạch sửa backend theo CSDL mới (lịch sử) |
| [REGISTER_OTP_SPEC.md](./REGISTER_OTP_SPEC.md) | Spec đăng ký có xác thực OTP qua email |

---

## Ghi chú

- Mọi bảng offline-first dùng `VARCHAR(36)` UUID làm khoá chính — **client tự
  sinh**, không dùng `SERIAL`.
- ⚠️ **Backend lệch tên cột giữa các bảng.** Ít nhất ba kiểu: `category` dùng
  `Delete_at`, `transaction` dùng `Deleted_at`, và cột ngày của giao dịch là
  `DateTransaction` (không gạch dưới). Đừng suy tên từ bảng này sang bảng kia —
  mở `schema.prisma` ra đọc. Sai tên cột ở PostgreSQL thì báo lỗi ngay, nhưng
  sai trong payload đồng bộ thì **im lặng**.
- File gốc của một số tài liệu vẫn nằm ở `docs/superpowers/plans/`,
  `docs/superpowers/specs/`, `docs/category/`. Thư mục này là bản gom lại cho
  đội backend tiện tra.
