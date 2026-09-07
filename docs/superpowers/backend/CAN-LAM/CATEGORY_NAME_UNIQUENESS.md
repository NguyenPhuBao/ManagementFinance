# Quy tắc duy nhất tên danh mục (Category Name Uniqueness Rules)

> ## 🌟 CẬP NHẬT 2026-09-07 — ĐÃ HOÀN THIỆN THEO CHỈ ĐẠO PO (MÔ HÌNH TEMPLATE & CLONED)
>
> Theo phê duyệt chính thức của Product Owner (PO), hệ thống áp dụng **Mô hình Danh mục Mẫu & Nhân bản Độc lập (Template & Cloned Model)**:
> - Danh mục hệ thống (`Is_default = true`) đóng vai trò là **Template mẫu** do Admin quản lý.
> - Khi người dùng đăng ký mới, Client-app gọi `GET /api/sync/default-categories` để lấy template, rồi tự sinh 1 bộ danh mục cá nhân (`Is_default = false`, `Create_by = idaccount`, UUID riêng) lưu vào SQLite và đồng bộ lên Backend qua `POST /api/sync/push`.
> - Do đó: **Người dùng ĐƯỢC PHÉP sở hữu danh mục cá nhân trùng tên với danh mục mẫu hệ thống**.
> - **Trigger kiểm tra chéo (`trg_category_name_cross_default`) ĐÃ BỊ LOẠI BỎ HOÀN TOÀN** khỏi CSDL theo script `database/5_Drop_Cross_Default_Category_Trigger.sql`.
> - Toàn bộ các đề xuất cũ về việc dùng trigger cấm trùng tên chéo hay gộp chung không gian tên giữa người dùng và hệ thống **đều bị bãi bỏ** vì sai lệch với kiến trúc nghiệp vụ.

**Người nhận:** Đội Backend & Client-app  
**Trạng thái:** Đã hoàn thành 100% trên Backend và CSDL.  
**Ngày cập nhật chuẩn hóa:** 2026-09-07.

---

## 1. Quy tắc nghiệp vụ chuẩn xác (Đã duyệt)

Hệ thống phân tách thành **2 không gian tên (namespaces) độc lập**:

### A. Phạm vi Danh mục Cá nhân của Người dùng
1. **Duy nhất trong từng tài khoản:** Tên danh mục là duy nhất trong phạm vi `Create_by` của tài khoản đó.
2. **Không tính `Classify`:** Một tài khoản không được có 2 danh mục cùng tên (kể cả khác loại Thu hay Chi).
3. **Không tính nhóm cha (`Idgroup`):** Hai nhóm khác nhau không tạo ra không gian tên riêng.
4. **Hàng đã xoá mềm không giữ chỗ:** Khi `Delete_at IS NOT NULL`, tên đó được phép tạo lại tự do.
5. **So tên không phân biệt hoa/thường:** Chuẩn hóa NFC, trim khoảng trắng đầu/cuối, thu gọn khoảng trắng thừa giữa các từ thành 1 dấu cách đơn, chuyển chữ thường (`LOWER`). Ví dụ: `"Ăn  UốNg"` == `"ăn uống"`.
6. **Cho phép trùng tên với hệ thống:** Người dùng hoàn toàn được phép có danh mục cá nhân mang tên `"Ăn uống"`, `"Di chuyển"`, v.v. trùng với danh mục mẫu hệ thống.
7. **Hai tài khoản khác nhau:** Được phép đặt danh mục trùng tên nhau.

### B. Phạm vi Danh mục Mẫu Hệ thống
1. **Duy nhất toàn hệ thống:** Toàn bộ danh mục hệ thống (`Is_default = true`) không được trùng tên nhau (không phân biệt hoa/thường, chuẩn hóa NFC).
2. **Admin tạo mới:** Admin có thể tạo mới danh mục hệ thống trùng tên với danh mục người dùng đã có.
3. **Bảo vệ danh mục hệ thống:** Không cho phép xóa danh mục hệ thống (Backend ném HTTP 400). Không cho phép chuyển đổi danh mục người dùng thành danh mục hệ thống.

---

## 2. Ràng buộc CSDL chuẩn hóa (PostgreSQL Partial Unique Indexes)

Đã triển khai và xác thực thành công trong CSDL:

```sql
-- 1. Danh mục của người dùng: duy nhất theo (Create_by, tên chuẩn hoá)
DROP INDEX IF EXISTS "uq_category_owner_name";
CREATE UNIQUE INDEX "uq_category_owner_name"
  ON "category" ("Create_by", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = FALSE AND "Delete_at" IS NULL;

-- 2. Danh mục mẫu hệ thống: duy nhất theo tên chuẩn hoá
DROP INDEX IF EXISTS "uq_category_default_name";
CREATE UNIQUE INDEX "uq_category_default_name"
  ON "category" (lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = TRUE AND "Delete_at" IS NULL;
```

---

## 3. Mã lỗi chuẩn hóa khi đồng bộ (`/sync/push`)

Khi xảy ra vi phạm trùng lặp tên trên cùng tài khoản (`uq_category_owner_name`), Backend trả về mã lỗi chuẩn hóa, che giấu hoàn toàn Prisma stack trace:

```json
{
  "localId": "...",
  "status": "error",
  "code": "CATEGORY_NAME_DUPLICATE",
  "message": "Tên danh mục đã tồn tại trong tài khoản này"
}
```

Client-app xếp lỗi này vào dạng `permanent` và hiển thị thông báo để người dùng đổi tên phù hợp.

---

## 4. Bảng đối chiếu kiểm chứng

| Trường hợp kiểm thử | Kết quả mong đợi | Lý do |
|---|:---:|---|
| Cùng tài khoản, tạo 2 danh mục cùng tên (khác Classify) | **TỪ CHỐI** (400 / Duplicate) | Vi phạm `uq_category_owner_name` |
| Cùng tài khoản, tạo 2 danh mục cùng tên (chỉ khác hoa thường/khoảng trắng) | **TỪ CHỐI** (400 / Duplicate) | Vi phạm `uq_category_owner_name` |
| Người dùng tạo danh mục trùng tên với danh mục mẫu hệ thống | **CHẤP NHẬN** (Thành công) | Thuộc Mô hình Template & Cloned |
| Hai tài khoản KHÁC nhau cùng tạo danh mục "Ăn uống" | **CHẤP NHẬN** (Thành công) | Khác `Create_by` |
| Xoá mềm một danh mục rồi tạo lại đúng tên đó | **CHẤP NHẬN** (Thành công) | Lọc `Delete_at IS NULL` |
| Admin tạo 2 danh mục hệ thống trùng tên nhau | **TỪ CHỐI** (400 / Duplicate) | Vi phạm `uq_category_default_name` |
| Admin cố xóa danh mục hệ thống | **TỪ CHỐI** (400 Bad Request) | Bảo vệ danh mục hệ thống |
