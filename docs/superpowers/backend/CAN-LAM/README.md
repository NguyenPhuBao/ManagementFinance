# Backend — CHỈ ĐỌC THƯ MỤC NÀY

**Cập nhật:** 2026-09-05

> Thư mục cha có 20 tài liệu, phần lớn đã xong hoặc chỉ để tham khảo lịch sử.
> **Mười tài liệu trong thư mục này là toàn bộ phần còn việc.** Không cần mở gì
> ở thư mục cha ngoài ba tệp bối cảnh liệt kê ở mục 4.

---

## 1. Câu hỏi quan trọng nhất: việc nào chặn tính năng đã có?

Client-app **đã phát hành** một số tính năng mà backend chưa theo kịp. Những
việc ấy khác hẳn về mức khẩn so với những việc phục vụ một tính năng client
**chưa hề bắt đầu**.

Bảng dưới chia đúng theo ranh giới đó.

### 🔴 Nhóm 1 — client ĐÃ CÓ, backend đang chặn hoặc gây hại

Làm nhóm này trước. Mỗi mục ở đây tương ứng với một thứ người dùng **có thể
chạm vào hôm nay**.

| # | Tài liệu | Client đã có gì | Backend thiếu gì | Chi phí |
|---|---|---|---|---|
| 1 | [2026-09-04-ocr-classify-review.md](./2026-09-04-ocr-classify-review.md) — **chỉ mục Socket.io** | Không liên quan tính năng nào — đây là rò rỉ ở tầng hạ tầng | Socket.io **không xác thực**, `join_account` tin con số client tự khai, và bốn dòng `io.emit` phát cho **mọi** socket. `emitAuditActivity` đang rò tên người dùng ra socket ẩn danh **ngay lúc này** | một buổi (phải sửa cùng `Admin-web/src/hooks/useSocket.js`) |
| 2 | [2026-09-04-backend-idempotent-delete.md](./2026-09-04-backend-idempotent-delete.md) | Toàn bộ đồng bộ offline-first, và ngân sách **"Ngày cụ thể"** | **(A)** `/sync/push` báo lỗi khi xoá bản ghi server không có → client đẩy lại **vĩnh viễn**. **(B)** `message` là nguyên văn stack trace Prisma → client phải dò chuỗi, hiện đã có **ba** phép khớp dựng tạm. **(C)** `upsertBudget` ép `time_recurrence = null` thành `'Month'` → **chặn hẳn** ngân sách "Ngày cụ thể" | vài dòng + nửa buổi |
| 3 | [CATEGORY_KEYWORD_SYNC.md](./CATEGORY_KEYWORD_SYNC.md) | Danh mục và từ khoá phân loại; chiều **xuống** client đã nối xong | Lỗ hổng **phân quyền** ở `POST /api/ai/classify/feedback` — `appendCategoryKeyword()` không đọc `create_by`, nên ghi được từ khoá vào danh mục của người khác. Chiều **lên** chưa có mô hình dữ liệu | một buổi |
| 4 | [CATEGORY_STABLE_IDS.md](./CATEGORY_STABLE_IDS.md) | Danh mục mặc định trên mọi máy | `seed.js:150` vẫn `crypto.randomUUID()`, nên **tên danh mục** bị dùng làm khoá nối giữa hai phía. Đây là nguyên nhân gốc của các lỗi 11.3–11.6 trong `PROJECT_CONTEXT.md` | migration |
| 5 | [CATEGORY_NAME_UNIQUENESS.md](./CATEGORY_NAME_UNIQUENESS.md) | Quy tắc trùng tên đã thi hành ở client **và** Admin-web | `/sync/push` chưa kiểm gì cả, và hai unique index của CSDL thi hành một quy tắc **khác** — lệch theo cả hai chiều. Thiếu `WHERE "Delete_at" IS NULL` là mỗi lần mở app client tạo lại danh mục đã xoá và bản ghi ấy **không bao giờ lên được server** | migration |
| 6 | [CATEGORY_GROUP_MEMBERSHIP_SYNC.md](./CATEGORY_GROUP_MEMBERSHIP_SYNC.md) | Gom nhóm danh mục | Không có bảng/entity cho việc gán danh mục **mặc định** vào nhóm → quan hệ đó chỉ tồn tại trên một máy. Thứ **duy nhất** còn chặn G10 | entity mới |
| 7 | [CATEGORY_CLASSIFY_ALIGNMENT.md](./CATEGORY_CLASSIFY_ALIGNMENT.md) | Bộ giá trị `classify` của danh mục | `validClassify` (`sync.validation.js:103`) rộng hơn thực tế | **một dòng** |

### 🟡 Nhóm 2 — client ĐÃ CÓ nhưng không có gì hỏng; đây là *mở khoá*

Không ai mất dữ liệu và không có gì sai số nếu chưa làm. Nhưng tính năng ấy
**không theo người dùng sang máy thứ hai**.

| # | Tài liệu | Client đã có gì | Backend thiếu gì | Chi phí |
|---|---|---|---|---|
| 8 | [2026-09-05-backend-transaction-goal-id.md](./2026-09-05-backend-transaction-goal-id.md) | Lịch sử tích luỹ nối với mục tiêu bằng **ID** (schema v14) | Cột nullable `transaction.Idgoal`. Thiếu nó, hàng kéo về từ server rơi xuống nhánh so **tên** — nhánh vẫn còn đúng khuyết điểm mà cột này sinh ra để chữa | một cột |
| 9 | [2026-09-05-backend-goal-auto-deposit.md](./2026-09-05-backend-goal-auto-deposit.md) | **Trích tiền tự động định kỳ** cho mục tiêu (schema v15) | Ba cột `auto_deposit_*`. Thiếu chúng, bật trích ở điện thoại rồi đăng nhập máy khác thì máy kia không trích gì cả | ba cột |

> ⚠️ Mục 9 có một cái bẫy: **ba cột phải lên cùng một lúc.** Đưa hai cột đầu mà
> bỏ `auto_deposit_last_run` là mỗi máy giữ một mốc riêng và **cả hai cùng
> chuyển tiền** — hỏng nặng hơn hiện trạng. Đọc mục 2 của tài liệu ấy trước.

### ⚪ Nhóm 3 — client CHƯA làm; để sau cũng được

| Tài liệu | Vì sao chưa gấp |
|---|---|
| [2026-09-05-backend-goal-priority.md](./2026-09-05-backend-goal-priority.md) | Client **chưa làm** ưu tiên mục tiêu, và cố ý chưa làm cho tới khi có cột. Đây là tài liệu *mở đường*: xin **một** cột nullable `goal.Priority` **trước** khi viết mã, thay vì làm cột cục bộ rồi xin sau như hai lần trước. Danh sách hiện sắp theo hạn gần nhất trước, đã gần đúng thứ tự ưu tiên khi chỉ có vài mục tiêu |
| [2026-09-04-ocr-classify-review.md](./2026-09-04-ocr-classify-review.md) — **phần OCR/Classify** (mục 2–8 của tài liệu) | Client-app **chưa có tính năng quét hoá đơn**: không có màn hình, không có repository, không có endpoint nào được gọi. `classifyBatch` sai kiểu tham số, `GEMINI_API_KEY` thiếu, dedup Quy tắc 3 chặn nhầm, cửa hậu `_mock*` — tất cả đều thật, nhưng **không ai chạm tới được từ app**. ⚠️ Riêng `uq_transaction_external` thiếu `Idaccount` thì **phải xong TRƯỚC** khi client nối luồng OCR, vì ràng buộc ấy là **toàn cục** |

---

## 2. Thứ tự thi công đề nghị

1. **Socket.io** (nhóm 1 mục 1) — thứ duy nhất đang chảy máu dữ liệu thật.
2. **`/sync/push`** (nhóm 1 mục 2), phần (A) và (C) — rẻ, và (A) cắt vòng lặp
   đẩy lại bất kể nguyên nhân gốc là gì, kể cả nguyên nhân chưa ai tìm ra.
3. **`validClassify`** (nhóm 1 mục 7) — một dòng.
4. **Lỗ hổng phân quyền từ khoá** (nhóm 1 mục 3).
5. **Một đợt migration duy nhất**: mục 4 → 5 → 6 của nhóm 1, **liền một mạch**,
   cộng thêm hai mục của nhóm 2, cột `goal.Priority` của nhóm 3, và `Idaccount`
   cho `uq_transaction_external`.

> ⚠️ **Bước 5 không tách lẻ được.** `CATEGORY_STABLE_IDS` là nguyên nhân gốc:
> ID ổn định cho seed là điều kiện để hai tài liệu kia không phải dùng *tên danh
> mục* làm khoá nối. Làm `CATEGORY_NAME_UNIQUENESS` trước là phải làm lại.
>
> Gộp hai mục của nhóm 2 **và** cột `goal.Priority` vào đúng đợt migration này
> là rẻ nhất — cả ba chỉ thêm cột nullable, không đụng dữ liệu cũ. `Priority`
> chưa có gì chờ nó, nhưng thêm sau lại tốn một migration nữa.

---

## 3. Ranh giới trách nhiệm

Client-app **không sửa `src/Backend`**. Mọi việc cần backend đều được viết
thành tài liệu ở đây thay vì sửa thẳng. Nếu một mục nào đó đọc thấy vô lý hoặc
tốn hơn dự kiến, hãy ghi lại lý do vào chính tài liệu ấy — client sẽ đọc và tìm
đường vòng ở phía mình.

---

## 4. Ba tệp bối cảnh, nằm ở thư mục cha

Không phải việc cần làm, nhưng cần để hiểu phần trên:

- [`../New_Database.md`](../New_Database.md) — lược đồ chuẩn của PostgreSQL.
  `CLAUDE.md` chỉ định đây là **nguồn sự thật** cho schema.
- [`../2026-08-10-backend-sync-spec.md`](../2026-08-10-backend-sync-spec.md) —
  hợp đồng `/sync/push` và `/sync/pull`.
- [`../PROGRESS-BACKEND.md`](../PROGRESS-BACKEND.md) — checklist B1→B7.

⚠️ **Backend lệch tên cột giữa các bảng**, ít nhất ba kiểu: `category` dùng
`Delete_at`, `transaction` dùng `Deleted_at`, và cột ngày của giao dịch là
`DateTransaction` (không gạch dưới). Đừng suy tên từ bảng này sang bảng kia —
mở `schema.prisma` ra đọc. Sai tên cột ở PostgreSQL thì báo lỗi ngay, nhưng sai
trong payload đồng bộ thì **im lặng**.
