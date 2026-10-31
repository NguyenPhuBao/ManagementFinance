-- ============================================================================
-- Migration 44: Mở Rộng Phân Quyền 4 Trụ Cột Cho Phân Hệ Gia Đình (Household)
-- Nguồn sự thật: docs/Family/00_TONG_QUAN.md & ke_hoach_chi_tiet_6_viec_cao_va_phan_quyen_gia_dinh.md
-- Ngày thực hiện: 2026-10-30
-- Quy tắc: DB Guard (Rule 10) - Bọc trong TRANSACTION (BEGIN...COMMIT), Idempotent
-- ============================================================================

BEGIN;

-- 1. Nạp và chuẩn hóa danh mục 4 tính năng Gia đình vào bảng feature
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
    (
        'household',
        'Gia đình — tạo & quản trị nhà',
        'Chủ nhà cần Premium để tạo và quản trị nhà; người được mời dùng miễn phí',
        'TOGGLE',
        'Gia đình',
        NULL,
        false,
        'LOCK_FEATURE',
        NOW(),
        NOW()
    ),
    (
        'household_join',
        'Gia đình — tham gia nhà',
        'Cho phép tài khoản tham gia vào nhà khi nhận được lời mời (cả Basic và Premium)',
        'TOGGLE',
        'Gia đình',
        NULL,
        true,
        'FALLBACK_DEFAULT',
        NOW(),
        NOW()
    ),
    (
        'household_members',
        'Gia đình — số thành viên tối đa',
        'Trần thành viên mỗi nhà (gồm cả Chủ nhà)',
        'LIMIT',
        'Gia đình',
        6,
        true,
        'BLOCK_CREATE',
        NOW(),
        NOW()
    ),
    (
        'household_wallets',
        'Gia đình — số ví chung tối đa',
        'Trần số lượng ví dùng chung trong mỗi gia đình',
        'LIMIT',
        'Gia đình',
        10,
        true,
        'BLOCK_CREATE',
        NOW(),
        NOW()
    )
ON CONFLICT ("id") DO UPDATE SET
    "name" = EXCLUDED."name",
    "description" = EXCLUDED."description",
    "type" = EXCLUDED."type",
    "category_group" = EXCLUDED."category_group",
    "default_limit" = EXCLUDED."default_limit",
    "default_enabled" = EXCLUDED."default_enabled",
    "default_downgrade_policy" = EXCLUDED."default_downgrade_policy",
    "updated_at" = NOW();

-- 2. Cấu hình phân quyền theo loại tài khoản (account_type_permission)
INSERT INTO "account_type_permission" (
    "account_type",
    "feature_id",
    "is_enabled",
    "limit_value",
    "scope_config",
    "downgrade_policy",
    "updated_at"
)
VALUES
    -- Gói Basic
    ('Basic', 'household',         false, NULL, '{}'::jsonb,                                                                                                     'LOCK_FEATURE',    NOW()),
    ('Basic', 'household_join',    true,  NULL, '{}'::jsonb,                                                                                                     'FALLBACK_DEFAULT', NOW()),
    ('Basic', 'household_members', false, 0,    '{}'::jsonb,                                                                                                     'BLOCK_CREATE',    NOW()),
    ('Basic', 'household_wallets', false, 0,    '{}'::jsonb,                                                                                                     'BLOCK_CREATE',    NOW()),

    -- Gói Premium
    ('Premium', 'household',         true,  NULL, '{"allow_transfer_owner": true, "allow_dissolve": true}'::jsonb,                                               'LOCK_FEATURE',    NOW()),
    ('Premium', 'household_join',    true,  NULL, '{}'::jsonb,                                                                                                     'FALLBACK_DEFAULT', NOW()),
    ('Premium', 'household_members', true,  6,    '{"invite_methods": ["code", "email"], "code_expire_hours": 48, "email_invite_expire_days": 7}'::jsonb,      'BLOCK_CREATE',    NOW()),
    ('Premium', 'household_wallets', true,  10,   '{"max_shared_wallets": 10}'::jsonb,                                                                          'BLOCK_CREATE',    NOW())
ON CONFLICT ("account_type", "feature_id") DO UPDATE SET
    "is_enabled" = EXCLUDED."is_enabled",
    "limit_value" = EXCLUDED."limit_value",
    "scope_config" = EXCLUDED."scope_config",
    "downgrade_policy" = EXCLUDED."downgrade_policy",
    "updated_at" = NOW();

COMMIT;

