-- ==============================================================================
-- MIGRATION 13: DROP DEFAULT ON budget.Threshold_Warning_Percent
-- Ref: VERIFY_7675B35_REMAINING.md §2.2
-- Purpose: Ngăn chặn giá trị mặc định 0 ép buộc khi ghi CSDL ngoài đường /sync/push
-- ==============================================================================

ALTER TABLE "budget" ALTER COLUMN "Threshold_Warning_Percent" DROP DEFAULT;

-- ==============================================================================
-- RÀNG BUỘC VÍ DUY NHẤT TRONG MỖI TÀI KHOẢN (Ref: Rule_project.md §2.5)
-- 1. Tên ví duy nhất trong một tài khoản (bỏ qua ví đã xoá mềm)
-- 2. Tối đa một ví mặc định trong một tài khoản (bỏ qua ví đã xoá mềm)
-- ==============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS "uq_wallet_account_name_active"
  ON "wallet" ("Idaccount", "Name")
  WHERE "Delete_at" IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "uq_wallet_default_active"
  ON "wallet" ("Idaccount")
  WHERE "Is_default" = TRUE AND "Delete_at" IS NULL;
