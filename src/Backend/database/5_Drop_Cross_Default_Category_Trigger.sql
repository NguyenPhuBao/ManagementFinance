-- ==============================================================================
-- 5_Drop_Cross_Default_Category_Trigger.sql
-- Mục đích:
-- 1. Gỡ bỏ Trigger và Hàm cấm trùng chéo giữa danh mục người dùng và danh mục hệ thống
--    (Chuyển đổi sang Mô hình Template & Cloned: Người dùng được phép có danh mục
--     cá nhân trùng tên với danh mục mẫu hệ thống).
-- 2. Tái xác nhận 2 Partial Unique Indexes chuẩn xác:
--    - uq_category_owner_name: (Create_by, lower(NameCategory)) cho danh mục người dùng
--    - uq_category_default_name: (lower(NameCategory)) cho danh mục hệ thống
-- ==============================================================================

-- 1. Gỡ bỏ Trigger kiểm tra chéo
DROP TRIGGER IF EXISTS trg_category_name_cross_default ON "category";
DROP FUNCTION IF EXISTS check_category_name_cross_default();
DROP FUNCTION IF EXISTS func_category_name_cross_default();

-- 2. Đảm bảo Index duy nhất danh mục người dùng (1 tài khoản không trùng tên danh mục đang hoạt động, không phân biệt hoa thường)
DROP INDEX IF EXISTS "uq_category_owner_name";
CREATE UNIQUE INDEX "uq_category_owner_name"
  ON "category" ("Create_by", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = FALSE AND "Delete_at" IS NULL;

-- 3. Đảm bảo Index duy nhất danh mục hệ thống (Danh mục hệ thống không trùng tên nhau, không phân biệt hoa thường)
DROP INDEX IF EXISTS "uq_category_default_name";
CREATE UNIQUE INDEX "uq_category_default_name"
  ON "category" (lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = TRUE AND "Delete_at" IS NULL;
