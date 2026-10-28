-- ============================================================================
-- MIGRATION 40: HOUSEHOLD FOUNDATION (GIA ĐÌNH NỀN MÓNG)
-- Hệ thống: FlowMoney / ManagementFinance
-- Nguồn sự thật: docs/Family/01_NEN_MONG.md & docs/superpowers/backend/CAN-LAM/LICH-SU/GIA_DINH_NEN_MONG.md
-- ============================================================================

-- 1. Bảng household (Nhà)
CREATE TABLE IF NOT EXISTS "household" (
  "Idhousehold"          SERIAL PRIMARY KEY,
  "Name"                 VARCHAR(100) NOT NULL,
  "Owner_idaccount"      INT NOT NULL REFERENCES "account"("Idaccount") ON DELETE CASCADE,
  "Status"               VARCHAR(10) NOT NULL DEFAULT 'Active',
  "Max_members"          SMALLINT NOT NULL DEFAULT 6,
  "Max_shared_wallets"   SMALLINT NOT NULL DEFAULT 10,
  "Contribution_due_day" SMALLINT NOT NULL DEFAULT 5,
  "Create_at"            TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Update_at"            TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Delete_at"            TIMESTAMP(6) NULL,
  CONSTRAINT "chk_household_status"      CHECK ("Status" IN ('Active', 'ReadOnly', 'Dissolved')),
  CONSTRAINT "chk_household_max_members" CHECK ("Max_members" BETWEEN 2 AND 20),
  CONSTRAINT "chk_household_due_day"     CHECK ("Contribution_due_day" BETWEEN 1 AND 31)
);

-- 2. Bảng household_member (Thành viên nhà)
CREATE TABLE IF NOT EXISTS "household_member" (
  "Id"          SERIAL PRIMARY KEY,
  "Idhousehold" INT NOT NULL REFERENCES "household"("Idhousehold") ON DELETE CASCADE,
  "Idaccount"   INT NOT NULL REFERENCES "account"("Idaccount") ON DELETE CASCADE,
  "Role"        VARCHAR(7) NOT NULL,
  "Joined_at"   TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Left_at"     TIMESTAMP(6) NULL,
  CONSTRAINT "chk_household_member_role" CHECK ("Role" IN ('Owner', 'Member', 'Viewer'))
);

-- Ràng buộc: Mỗi tài khoản tại 1 thời điểm chỉ ở tối đa 1 nhà đang active
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_member_active_account"
  ON "household_member" ("Idaccount") WHERE "Left_at" IS NULL;

-- Ràng buộc: Mỗi nhà chỉ có đúng 1 Chủ nhà (Owner) đang active
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_one_owner"
  ON "household_member" ("Idhousehold") WHERE "Role" = 'Owner' AND "Left_at" IS NULL;

CREATE INDEX IF NOT EXISTS "idx_household_member_active"
  ON "household_member" ("Idhousehold") WHERE "Left_at" IS NULL;

-- 3. Bảng household_invite (Mã mời công khai 8 ký tự & Lời mời đích danh Email)
CREATE TABLE IF NOT EXISTS "household_invite" (
  "Code"                VARCHAR(8) PRIMARY KEY,
  "Idhousehold"         INT NOT NULL REFERENCES "household"("Idhousehold") ON DELETE CASCADE,
  "Role"                VARCHAR(7) NOT NULL,
  "Created_by"          INT NOT NULL REFERENCES "account"("Idaccount") ON DELETE CASCADE,
  "Email"               VARCHAR(100) NULL,
  "Invitee_idaccount"   INT NULL REFERENCES "account"("Idaccount") ON DELETE SET NULL,
  "Create_at"           TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "Expires_at"          TIMESTAMP(6) NOT NULL,
  "Used_by"             INT NULL REFERENCES "account"("Idaccount") ON DELETE SET NULL,
  "Used_at"             TIMESTAMP(6) NULL,
  "Revoked_at"          TIMESTAMP(6) NULL,
  "Declined_at"         TIMESTAMP(6) NULL,
  CONSTRAINT "chk_household_invite_role" CHECK ("Role" IN ('Member', 'Viewer'))
);

-- Ràng buộc: Mỗi email chỉ có 1 lời mời active cho mỗi nhà
CREATE UNIQUE INDEX IF NOT EXISTS "uq_household_invite_email_active"
  ON "household_invite" ("Idhousehold", "Email")
  WHERE "Email" IS NOT NULL AND "Used_at" IS NULL AND "Revoked_at" IS NULL AND "Declined_at" IS NULL;

CREATE INDEX IF NOT EXISTS "idx_household_invite_email"
  ON "household_invite" ("Email") WHERE "Email" IS NOT NULL;

-- 4. Bổ sung cột Idhousehold cho 5 bảng đồng bộ cốt lõi
ALTER TABLE "wallet"      ADD COLUMN IF NOT EXISTS "Idhousehold" INT NULL REFERENCES "household"("Idhousehold") ON DELETE SET NULL;
ALTER TABLE "transaction" ADD COLUMN IF NOT EXISTS "Idhousehold" INT NULL REFERENCES "household"("Idhousehold") ON DELETE SET NULL;
ALTER TABLE "goal"        ADD COLUMN IF NOT EXISTS "Idhousehold" INT NULL REFERENCES "household"("Idhousehold") ON DELETE SET NULL;
ALTER TABLE "budget"      ADD COLUMN IF NOT EXISTS "Idhousehold" INT NULL REFERENCES "household"("Idhousehold") ON DELETE SET NULL;
ALTER TABLE "category"    ADD COLUMN IF NOT EXISTS "Idhousehold" INT NULL REFERENCES "household"("Idhousehold") ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS "idx_wallet_household"      ON "wallet"      ("Idhousehold", "Server_update_at") WHERE "Idhousehold" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_transaction_household" ON "transaction" ("Idhousehold", "Server_update_at") WHERE "Idhousehold" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_goal_household"        ON "goal"        ("Idhousehold", "Server_update_at") WHERE "Idhousehold" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_budget_household"      ON "budget"      ("Idhousehold", "Server_update_at") WHERE "Idhousehold" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_category_household"    ON "category"    ("Idhousehold", "Server_update_at") WHERE "Idhousehold" IS NOT NULL;

-- 5. Chuẩn hóa Partial Unique Indexes cách ly cá nhân vs nhà (Tuân thủ DB Guard & Soft Delete)
DROP INDEX IF EXISTS "uq_wallet_account_name_active";
CREATE UNIQUE INDEX "uq_wallet_account_name_active"
  ON "wallet" ("Idaccount", "Name") WHERE "Delete_at" IS NULL AND "Idhousehold" IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "uq_wallet_household_name_active"
  ON "wallet" ("Idhousehold", "Name") WHERE "Delete_at" IS NULL AND "Idhousehold" IS NOT NULL;

DROP INDEX IF EXISTS "uq_wallet_default_active";
CREATE UNIQUE INDEX "uq_wallet_default_active"
  ON "wallet" ("Idaccount") WHERE "Is_default" = TRUE AND "Delete_at" IS NULL AND "Idhousehold" IS NULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_wallet_household_not_default') THEN
    ALTER TABLE "wallet" ADD CONSTRAINT "chk_wallet_household_not_default"
      CHECK ("Idhousehold" IS NULL OR "Is_default" = FALSE);
  END IF;
END $$;

DROP INDEX IF EXISTS "uq_category_owner_name";
CREATE UNIQUE INDEX "uq_category_owner_name"
  ON "category" ("Create_by", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Is_default" = FALSE AND "Delete_at" IS NULL AND "Idhousehold" IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "uq_category_household_name"
  ON "category" ("Idhousehold", lower(regexp_replace(btrim(normalize("NameCategory", NFC)), '\s+', ' ', 'g')))
  WHERE "Delete_at" IS NULL AND "Idhousehold" IS NOT NULL;
