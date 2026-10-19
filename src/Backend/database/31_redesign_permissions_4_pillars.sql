-- ============================================================================
-- Migration 31: Nâng cấp cấu trúc CSDL quản lý phân quyền theo 4 Trụ Cột
-- Ngày thực hiện: 2026-10-17
-- Mục tiêu:
--   1. Trụ 1 (Access): is_enabled (đã có sẵn trong account_type_permission)
--   2. Trụ 2 (Quota): limit_value (đã có sẵn trong account_type_permission)
--   3. Trụ 3 (Scope):
--      - feature.scope_schema: Khuôn mẫu định nghĩa các quyền năng con của tính năng
--      - account_type_permission.scope_config: Cấu hình giá trị quyền năng con theo gói
--   4. Trụ 4 (Downgrade Policy):
--      - feature.default_downgrade_policy: Chính sách hạ cấp mặc định của tính năng
--      - account_type_permission.downgrade_policy: Chính sách hạ cấp áp dụng cho gói
-- Cơ chế an toàn: ALTER TABLE ADD COLUMN IF NOT EXISTS (Idempotent, không mất dữ liệu)
-- ============================================================================

-- 1. Nâng cấp bảng feature
ALTER TABLE "feature"
  ADD COLUMN IF NOT EXISTS "scope_schema" JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS "default_downgrade_policy" VARCHAR(50) NOT NULL DEFAULT 'BLOCK_CREATE';

-- 2. Nâng cấp bảng account_type_permission
ALTER TABLE "account_type_permission"
  ADD COLUMN IF NOT EXISTS "scope_config" JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS "downgrade_policy" VARCHAR(50) NOT NULL DEFAULT 'BLOCK_CREATE';

-- 3. Cập nhật default_downgrade_policy chuẩn cho bảng feature
-- - Tính năng có trần (LIMIT): Khi hết hạn hạ cấp thì BLOCK_CREATE (bảo toàn dữ liệu cũ, chỉ chặn tạo mới)
UPDATE "feature"
SET "default_downgrade_policy" = 'BLOCK_CREATE'
WHERE "type" = 'LIMIT';

-- - Tính năng bật/tắt (TOGGLE): Khi hết hạn hạ cấp thì LOCK_FEATURE (khóa quyền truy cập tính năng)
UPDATE "feature"
SET "default_downgrade_policy" = 'LOCK_FEATURE'
WHERE "type" = 'TOGGLE';

-- 4. Đồng bộ downgrade_policy trong account_type_permission theo tính năng
UPDATE "account_type_permission" p
SET "downgrade_policy" = f."default_downgrade_policy"
FROM "feature" f
WHERE p."feature_id" = f."id";
