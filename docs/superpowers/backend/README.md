# Backend — Mục lục và thứ tự đọc

> Thư mục này gom mọi tài liệu backend của FlowMoney. Có **16 tài liệu**, phần
> lớn đã làm xong — bảng "Còn phải làm" bên dưới là thứ cần đọc trước.
>
> Cập nhật 2026-09-04. Trạng thái từng mục đối chiếu với `schema.prisma` và mã
> nguồn thật, không chép lại từ bản cũ. Bảng trạng thái đầy đủ hơn nằm ở mục 14
> `docs/PROJECT_CONTEXT.md`.

---

## 1. Đọc trước để có bối cảnh

Ba tài liệu này **không phải việc cần làm** — chúng là nền để hiểu phần còn lại.

| # | Tài liệu | Nội dung |
|---|---|---|
| 1 | [New_Database.md](./New_Database.md) | Lược đồ chuẩn của PostgreSQL. `CLAUDE.md` chỉ định đây là **nguồn sự thật** cho schema |
| 2 | [2026-08-10-backend-sync-spec.md](./2026-08-10-backend-sync-spec.md) | Hợp đồng `/sync/push` và `/sync/pull`: định dạng request/response, thứ tự entity, quy tắc LWW |
| 3 | [PROGRESS-BACKEND.md](./PROGRESS-BACKEND.md) | Checklist B1→B7 và tiến độ từng bước |

---

## 2. Còn phải làm — theo thứ tự đề nghị

| # | Tài liệu | Trạng thái |
|---|---|---|
| 1 | [CATEGORY_KEYWORD_SYNC.md](./CATEGORY_KEYWORD_SYNC.md) | ⛔ **Lỗ hổng phân quyền còn nguyên** ở `POST /api/ai/classify/feedback`. Đợt sửa trước chỉ đổi ký tự tách từ khoá. Từ khoá phân loại còn tồn tại ở hai kho độc lập, không có đường nối |
| 2 | [2026-09-04-backend-idempotent-delete.md](./2026-09-04-backend-idempotent-delete.md) | ⛔ **Ba việc độc lập** trong `/sync/push`. **(A)** xoá bản ghi không tồn tại đang bị trả về là lỗi → client đẩy lại vĩnh viễn. **(B)** `message` là nguyên văn stack trace Prisma, để lộ đường dẫn máy chủ và nội dung hàng dữ liệu. **(C)** `upsertBudget` ép `time_recurrence = null` thành `'Month'` → **chặn hẳn** ngân sách "Ngày cụ thể", và làm ngân sách tự hết hạn sớm sau khi pull. Cả ba chỉ sửa logic, **không cần migration** |
| 3 | [CATEGORY_NAME_UNIQUENESS.md](./CATEGORY_NAME_UNIQUENESS.md) | ⚠️ Một phần — Admin-web đã thi hành quy tắc, nhưng còn 4 khoảng hở (không gom khoảng trắng, không chuẩn hoá NFC, thiếu vế chéo "người dùng ↔ mặc định"), và `/sync/push` cùng CSDL vẫn chưa thi hành |
| 4 | [CATEGORY_STABLE_IDS.md](./CATEGORY_STABLE_IDS.md) | ⛔ `seed.js` vẫn `crypto.randomUUID()`, nên tên danh mục bị dùng làm khoá nối giữa hai phía — đây là nguyên nhân gốc của các lỗi 11.3–11.6 trong `PROJECT_CONTEXT.md` |
| 5 | [CATEGORY_GROUP_MEMBERSHIP_SYNC.md](./CATEGORY_GROUP_MEMBERSHIP_SYNC.md) | ⛔ Thứ **duy nhất** còn chặn G10: backend chưa có bảng/entity cho việc gán danh mục **mặc định** vào nhóm |
| 6 | [CATEGORY_CLASSIFY_ALIGNMENT.md](./CATEGORY_CLASSIFY_ALIGNMENT.md) | ⚠️ Gần xong — còn đúng một bước thu hẹp `validClassify` trong `sync.validation.js` |

### Vì sao xếp thứ tự này

Mục 1 đứng đầu vì là vấn đề **bảo mật**; những mục sau là lỗi chức năng. Nếu
cần một kết quả nhanh trước thì đảo mục 2 lên: nó không phụ thuộc gì, không cần
migration, và đang chặn một tính năng người dùng đã dùng được ở client.

Mục 3 → 4 → 5 nên đi liền nhau: cả ba đều xoay quanh danh mục, và mục 4 là
nguyên nhân gốc mà hai mục kia phải chịu hậu quả.

---

## 3. Đã xong hoặc chỉ để tham khảo

| Tài liệu | Trạng thái |
|---|---|
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
