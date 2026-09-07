-- ==============================================================================
-- 6_Drop_Category_Group_Membership.sql
-- Mục đích:
-- 1. Xóa bỏ bảng thừa "category_group_membership" khỏi CSDL PostgreSQL / Supabase.
-- 2. Lý do: Hệ thống áp dụng Mô hình Template & Cloned Model:
--    Mỗi người dùng sở hữu bộ danh mục cá nhân riêng, nhóm danh mục được gom trực tiếp
--    thông qua quan hệ tự tham chiếu category.idgroup (với is_group = true).
--    Bảng trung gian category_group_membership không còn được sử dụng.
-- ==============================================================================

DROP TABLE IF EXISTS "category_group_membership" CASCADE;
