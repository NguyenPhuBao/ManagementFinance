-- ============================================================================
-- Migration 41: Nạp Phân Quyền Tính Năng Gia Đình (Household Permissions)
-- Nguồn sự thật: docs/superpowers/backend/CAN-LAM/VIEC_BACKEND_CON_LAI.md (Task 56.4)
-- Ngày thực hiện: 2026-10-28
-- Quy tắc: DB Guard (Rule 10) - Bọc trong TRANSACTION (BEGIN...COMMIT), Idempotent
-- ============================================================================

BEGIN;

-- 1. Nạp tính năng vào danh mục chức năng (feature)
INSERT INTO "feature" (
    "id",
    "name",
    "description",
    "type",
    "category_group",
    "default_limit",
    "default_enabled",
    "default_downgrade_policy",
    "created_at",
    "updated_at"
)
VALUES
    ('household',         'Gia đình — tạo nhà',              'Chủ nhà cần Premium; người được mời dùng miễn phí', 'TOGGLE', 'Gia đình', NULL, false, 'LOCK_FEATURE', NOW(), NOW()),
    ('household_members', 'Gia đình — số thành viên tối đa', 'Trần thành viên mỗi nhà, gồm Chủ nhà',            'LIMIT',  'Gia đình', 6,    true,  'BLOCK_CREATE', NOW(), NOW())
ON CONFLICT ("id") DO UPDATE SET
    "name" = EXCLUDED."name",
    "description" = EXCLUDED."description",
    "updated_at" = NOW();

-- 2. Cấu hình phân quyền theo loại tài khoản (account_type_permission)
INSERT INTO "account_type_permission" (
    "account_type",
    "feature_id",
    "is_enabled",
    "limit_value",
    "downgrade_policy",
    "updated_at"
)
VALUES
    ('Basic',   'household',         false, NULL, 'LOCK_FEATURE', NOW()),
    ('Premium', 'household',         true,  NULL, 'LOCK_FEATURE', NOW()),
    ('Basic',   'household_members', false, NULL, 'BLOCK_CREATE', NOW()),
    ('Premium', 'household_members', true,  6,    'BLOCK_CREATE', NOW())
ON CONFLICT ("account_type", "feature_id") DO NOTHING;

COMMIT;

