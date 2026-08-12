-- ============================================
-- WealthCommand Backend
-- Script: Convert Category PK sang UUID
-- Database: PersonFinance (PostgreSQL 18)
-- Ngay: 2026-08-12
-- Mo ta: Chuyen Primary Key cua bang Category
--         tu idcategory (INT) sang uuid (VARCHAR(36))
--         + Them FK constraints cho Transaction & Budget
-- ============================================

BEGIN;

-- ============================================
-- 1. KIEM TRA UUID DA CO CHUA
-- ============================================

-- Dam bao uuid da duoc them tu script )3
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'category' AND column_name = 'uuid'
  ) THEN
    ALTER TABLE Category ADD COLUMN uuid VARCHAR(36) UNIQUE;
    UPDATE Category SET uuid = gen_random_uuid()::VARCHAR(36) WHERE uuid IS NULL;
    ALTER TABLE Category ALTER COLUMN uuid SET NOT NULL;
  END IF;
END $$;

-- ============================================
-- 2. DOI PRIMARY KEY: idcategory → uuid
-- ============================================

-- Drop PK constraint (ten constraint mac dinh cua PostgreSQL)
ALTER TABLE Category DROP CONSTRAINT IF EXISTS category_pkey;

-- Dat uuid lam Primary Key moi
ALTER TABLE Category ADD PRIMARY KEY (uuid);

-- idcategory giu lam unique index (backward compat cho admin-web)
ALTER TABLE Category ADD CONSTRAINT category_idcategory_unique UNIQUE (idcategory);

-- ============================================
-- 3. THEM FK: transaction.category_id → category.uuid
-- ============================================

-- Dat NULL cho cac transaction co category_id khong ton tai trong category.uuid
UPDATE "transaction"
SET category_id = NULL
WHERE category_id IS NOT NULL
  AND category_id NOT IN (SELECT uuid FROM Category);

ALTER TABLE "transaction"
ADD CONSTRAINT fk_transaction_category
  FOREIGN KEY (category_id) REFERENCES Category(uuid)
  ON DELETE SET NULL;

-- ============================================
-- 4. THEM FK: budget.category_id → category.uuid
-- ============================================

UPDATE budget
SET category_id = NULL
WHERE category_id IS NOT NULL
  AND category_id NOT IN (SELECT uuid FROM Category);

ALTER TABLE budget
ADD CONSTRAINT fk_budget_category
  FOREIGN KEY (category_id) REFERENCES Category(uuid)
  ON DELETE SET NULL;

COMMIT;

-- ============================================
-- VERIFY
-- ============================================
-- SELECT conname, contype FROM pg_constraint WHERE conrelid = 'Category'::regclass;
-- Kiem tra: PRIMARY KEY (uuid), UNIQUE (idcategory)
