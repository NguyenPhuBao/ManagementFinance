-- ============================================================================
-- Migration 22: Tạo bảng danh mục tính năng (feature) và phân quyền theo loại tài khoản (account_type_permission)
-- Mục đích: Hỗ trợ phân quyền tính năng động từ CSDL cho Basic và Premium (Bước 3 / Mục 39)
-- ============================================================================

-- 1. Tạo bảng feature (Danh mục chức năng ứng dụng)
CREATE TABLE IF NOT EXISTS "feature" (
    "id" VARCHAR(50) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "type" VARCHAR(20) NOT NULL DEFAULT 'TOGGLE',
    "category_group" VARCHAR(50) NOT NULL DEFAULT 'Chức năng',
    "default_limit" INTEGER,
    "default_enabled" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
    CONSTRAINT "feature_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ck_feature_type" CHECK ("type" IN ('LIMIT', 'TOGGLE'))
);

-- 2. Tạo bảng account_type_permission (Cấu hình phân quyền theo loại tài khoản)
CREATE TABLE IF NOT EXISTS "account_type_permission" (
    "id" SERIAL NOT NULL,
    "account_type" VARCHAR(20) NOT NULL,
    "feature_id" VARCHAR(50) NOT NULL,
    "is_enabled" BOOLEAN NOT NULL DEFAULT true,
    "limit_value" INTEGER,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
    "updated_at" TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
    CONSTRAINT "account_type_permission_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "fk_perm_feature" FOREIGN KEY ("feature_id") REFERENCES "feature"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "uq_account_type_feature" UNIQUE ("account_type", "feature_id"),
    CONSTRAINT "ck_perm_account_type" CHECK ("account_type" IN ('Basic', 'Premium'))
);

-- 3. Tạo chỉ mục hỗ trợ truy vấn nhanh theo loại tài khoản
CREATE INDEX IF NOT EXISTS "idx_perm_account_type" ON "account_type_permission" ("account_type");

-- 4. Seed Data: 5 tính năng cốt lõi khớp khảo sát Mục 39 của Client-app & PO
INSERT INTO "feature" ("id", "name", "description", "type", "category_group", "default_limit", "default_enabled")
VALUES
    ('wallets', 'Tạo ví', 'Giới hạn số lượng ví hoạt động đồng thời', 'LIMIT', 'Tài nguyên', 3, true),
    ('budgets', 'Tạo ngân sách', 'Giới hạn số lượng ngân sách hoạt động đồng thời', 'LIMIT', 'Tài nguyên', 3, true),
    ('goals', 'Tạo mục tiêu', 'Giới hạn số lượng mục tiêu tiết kiệm hoạt động đồng thời', 'LIMIT', 'Tài nguyên', 3, true),
    ('ai_assistant', 'Trợ lý AI & Lệnh tạo', 'Trợ lý tài chính AI hỏi đáp và tự sinh lệnh tạo', 'TOGGLE', 'Trí tuệ nhân tạo', NULL, false),
    ('ai_quick_input', 'Nhập nhanh bằng câu', 'Tự động bóc tách câu tự nhiên thành giao dịch bằng AI', 'TOGGLE', 'Trí tuệ nhân tạo', NULL, false)
ON CONFLICT ("id") DO UPDATE SET
    "name" = EXCLUDED."name",
    "description" = EXCLUDED."description",
    "type" = EXCLUDED."type",
    "category_group" = EXCLUDED."category_group",
    "default_limit" = EXCLUDED."default_limit",
    "default_enabled" = EXCLUDED."default_enabled",
    "updated_at" = (now() AT TIME ZONE 'UTC');

-- 5. Seed Permissions: Cấu hình chuẩn Basic (Trần 3/3/3, AI khóa) và Premium (Không trần, AI mở)
INSERT INTO "account_type_permission" ("account_type", "feature_id", "is_enabled", "limit_value")
VALUES
    -- Gói Basic
    ('Basic', 'wallets', true, 3),
    ('Basic', 'budgets', true, 3),
    ('Basic', 'goals', true, 3),
    ('Basic', 'ai_assistant', false, NULL),
    ('Basic', 'ai_quick_input', false, NULL),
    -- Gói Premium
    ('Premium', 'wallets', true, NULL),
    ('Premium', 'budgets', true, NULL),
    ('Premium', 'goals', true, NULL),
    ('Premium', 'ai_assistant', true, NULL),
    ('Premium', 'ai_quick_input', true, NULL)
ON CONFLICT ("account_type", "feature_id") DO UPDATE SET
    "is_enabled" = EXCLUDED."is_enabled",
    "limit_value" = EXCLUDED."limit_value",
    "updated_at" = (now() AT TIME ZONE 'UTC');
