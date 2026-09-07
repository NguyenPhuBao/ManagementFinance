-- ==============================================================================
-- MIGRATION: CONSOLIDATED SCHEMA CHANGES FROM CAN-LAM SPECIFICATIONS
-- Date: 2026-09-07
-- Modules impacted: category, category_group_membership, transaction, goal
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CATEGORY: Partial Unique Index (WHERE "Delete_at" IS NULL) & Cross Trigger
-- Ref: CATEGORY_NAME_UNIQUENESS.md
-- ------------------------------------------------------------------------------
DROP INDEX IF EXISTS "uq_category_owner_name_classify";
DROP INDEX IF EXISTS "uq_category_default_name_classify";
ALTER TABLE "category" DROP CONSTRAINT IF EXISTS "uq_category_owner_name_classify";
ALTER TABLE "category" DROP CONSTRAINT IF EXISTS "uq_category_default_name_classify";

-- Danh mục người dùng: duy nhất theo (chủ sở hữu, tên chuẩn hoá NFC), bỏ qua hàng đã xoá mềm
CREATE UNIQUE INDEX IF NOT EXISTS "uq_category_owner_name"
  ON "category" ("Create_by", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = FALSE AND "Delete_at" IS NULL;

-- Dọn dẹp các danh mục mặc định cũ (sinh ngẫu nhiên trước khi đóng băng 13 stable UUIDs)
DELETE FROM "category" 
WHERE "Is_default" = TRUE 
  AND "Idcategory" NOT IN (
    'f92ee650-47d7-42c3-a9cd-75fe2e5daa84',
    'bfc1ef8d-d9af-4f8d-80bb-a7fac310891f',
    'af5d9ad9-04b2-4df3-9634-b44fa0c9fef0',
    '8e06aaf6-4608-4cb3-8770-2c2c1eae25b6',
    '08639bd7-ef8f-4c58-ae8a-7f58198ad79b',
    'b84b02f4-72ad-42e0-9298-860efb5889b0',
    '3d2a54d2-eb45-41b4-ad18-0f4308791dea',
    'd5fead3c-4b9a-4649-bd63-1019bc2c7fef',
    '5c9b4699-59ab-4ade-9f8d-312db326b5c8',
    'ed724230-14e7-4bef-8620-03c52730d32c',
    'e6d26476-a546-48a9-bf45-716ba0264547',
    '58839f91-9eec-4af7-b542-65d2a70e3e36',
    'df489f3d-6ddf-44c6-be3c-2402259ec9cf'
  );

-- Danh mục mặc định: duy nhất theo tên chuẩn hoá NFC, bỏ qua hàng đã xoá mềm
CREATE UNIQUE INDEX IF NOT EXISTS "uq_category_default_name"
  ON "category" (lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = TRUE AND "Delete_at" IS NULL;

-- Trigger kiểm tra chéo: Tên danh mục người dùng không được trùng với danh mục mặc định và ngược lại
CREATE OR REPLACE FUNCTION check_category_name_cross_default()
RETURNS TRIGGER AS $$
DECLARE
  norm_name TEXT;
  conflict_count INT;
BEGIN
  IF NEW."Delete_at" IS NOT NULL THEN
    RETURN NEW;
  END IF;

  norm_name := lower(regexp_replace(btrim(normalize(NEW."NameCategory", NFC)), '\s+', ' ', 'g'));

  IF NEW."Is_default" = FALSE THEN
    SELECT COUNT(*) INTO conflict_count
    FROM "category"
    WHERE "Is_default" = TRUE
      AND "Delete_at" IS NULL
      AND lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')) = norm_name
      AND "Idcategory" != NEW."Idcategory";

    IF conflict_count > 0 THEN
      RAISE EXCEPTION 'Tên danh mục không được trùng với danh mục mặc định hệ thống'
        USING ERRCODE = '23505';
    END IF;
  ELSE
    SELECT COUNT(*) INTO conflict_count
    FROM "category"
    WHERE "Is_default" = FALSE
      AND "Delete_at" IS NULL
      AND lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')) = norm_name
      AND "Idcategory" != NEW."Idcategory";

    IF conflict_count > 0 THEN
      RAISE EXCEPTION 'Tên danh mục mặc định không được trùng với danh mục của người dùng'
        USING ERRCODE = '23505';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_category_name_cross_default ON "category";
CREATE TRIGGER trg_category_name_cross_default
  BEFORE INSERT OR UPDATE OF "NameCategory", "Is_default", "Delete_at"
  ON "category"
  FOR EACH ROW
  EXECUTE FUNCTION check_category_name_cross_default();

-- ------------------------------------------------------------------------------
-- 2. CATEGORY_GROUP_MEMBERSHIP: Bảng gán danh mục mặc định vào nhóm của user
-- Ref: CATEGORY_GROUP_MEMBERSHIP_SYNC.md
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "category_group_membership" (
  "Idmembership" VARCHAR(36) PRIMARY KEY,
  "Idaccount"    INT         NOT NULL,
  "Idcategory"   VARCHAR(36) NOT NULL,
  "Idgroup"      VARCHAR(36) NOT NULL,
  "Update_at"    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "Delete_at"    TIMESTAMP   NULL,
  CONSTRAINT "fk_membership_account"  FOREIGN KEY ("Idaccount")  REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "fk_membership_category" FOREIGN KEY ("Idcategory") REFERENCES "category"("Idcategory") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "fk_membership_group"    FOREIGN KEY ("Idgroup")    REFERENCES "category"("Idcategory") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "uq_membership_owner_category" UNIQUE ("Idaccount", "Idcategory")
);

CREATE INDEX IF NOT EXISTS "idx_membership_account" ON "category_group_membership"("Idaccount");
CREATE INDEX IF NOT EXISTS "idx_membership_update_at" ON "category_group_membership"("Update_at");

-- ------------------------------------------------------------------------------
-- 3. TRANSACTION: Cột Idgoal & Ràng buộc Unique per-account (Idaccount, Provider, Bank_tran_id)
-- Ref: 2026-09-05-backend-transaction-goal-id.md & 2026-09-04-ocr-classify-review.md
-- ------------------------------------------------------------------------------
ALTER TABLE "transaction" ADD COLUMN IF NOT EXISTS "Idgoal" VARCHAR(36) NULL;

ALTER TABLE "transaction" DROP CONSTRAINT IF EXISTS "fk_transaction_goal";
ALTER TABLE "transaction" ADD CONSTRAINT "fk_transaction_goal"
  FOREIGN KEY ("Idgoal") REFERENCES "goal"("Idgoal")
  ON DELETE SET NULL ON UPDATE NO ACTION;

CREATE INDEX IF NOT EXISTS "idx_transaction_goal" ON "transaction"("Idgoal") WHERE "Idgoal" IS NOT NULL;

-- Nâng cấp ràng buộc duy nhất thành cấp độ per-account:
ALTER TABLE "transaction" DROP CONSTRAINT IF EXISTS "uq_transaction_external";
DROP INDEX IF EXISTS "uq_transaction_external";
ALTER TABLE "transaction" ADD CONSTRAINT "uq_transaction_external" UNIQUE ("Idaccount", "Provider", "Bank_tran_id");

-- ------------------------------------------------------------------------------
-- 4. GOAL: Ba cột trích tiền tự động (auto_deposit_*) & Cột Priority
-- Ref: 2026-09-05-backend-goal-auto-deposit.md & 2026-09-05-backend-goal-priority.md
-- ------------------------------------------------------------------------------
ALTER TABLE "goal" ADD COLUMN IF NOT EXISTS "auto_deposit_amount" DECIMAL(18, 2) NULL;
ALTER TABLE "goal" ADD COLUMN IF NOT EXISTS "auto_deposit_wallet_id" VARCHAR(36) NULL;
ALTER TABLE "goal" ADD COLUMN IF NOT EXISTS "auto_deposit_last_run" TIMESTAMP NULL;
ALTER TABLE "goal" ADD COLUMN IF NOT EXISTS "Priority" INT NULL;
