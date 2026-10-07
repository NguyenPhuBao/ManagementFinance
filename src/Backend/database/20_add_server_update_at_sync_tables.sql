-- ============================================================================
-- Migration 20: Thêm cột Server_update_at cho 6 bảng đồng bộ
-- Mục đích: Tách mốc thời gian nhận của server phục vụ /sync/pull delta
-- khỏi mốc update_at của máy dùng cho Last-Write-Wins (LWW) (Mục 37 CAN-LAM)
-- ============================================================================

-- 1. Thêm cột Server_update_at (nếu chưa có)
ALTER TABLE IF EXISTS "category"
  ADD COLUMN IF NOT EXISTS "Server_update_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE IF EXISTS "wallet"
  ADD COLUMN IF NOT EXISTS "Server_update_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE IF EXISTS "budget"
  ADD COLUMN IF NOT EXISTS "Server_update_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE IF EXISTS "bill"
  ADD COLUMN IF NOT EXISTS "Server_update_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE IF EXISTS "goal"
  ADD COLUMN IF NOT EXISTS "Server_update_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE IF EXISTS "transaction"
  ADD COLUMN IF NOT EXISTS "Server_update_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- 2. Đồng bộ giá trị ban đầu cho các bản ghi cũ từ Update_at
UPDATE "category" SET "Server_update_at" = "Update_at" WHERE "Server_update_at" = CURRENT_TIMESTAMP AND "Update_at" IS NOT NULL;
UPDATE "wallet" SET "Server_update_at" = "Update_at" WHERE "Server_update_at" = CURRENT_TIMESTAMP AND "Update_at" IS NOT NULL;
UPDATE "budget" SET "Server_update_at" = "Update_at" WHERE "Server_update_at" = CURRENT_TIMESTAMP AND "Update_at" IS NOT NULL;
UPDATE "bill" SET "Server_update_at" = "Update_at" WHERE "Server_update_at" = CURRENT_TIMESTAMP AND "Update_at" IS NOT NULL;
UPDATE "goal" SET "Server_update_at" = "Update_at" WHERE "Server_update_at" = CURRENT_TIMESTAMP AND "Update_at" IS NOT NULL;
UPDATE "transaction" SET "Server_update_at" = "Update_at" WHERE "Server_update_at" = CURRENT_TIMESTAMP AND "Update_at" IS NOT NULL;

-- 3. Tạo chỉ mục hỗ trợ truy vấn kéo delta theo account và Server_update_at
CREATE INDEX IF NOT EXISTS "idx_category_server_updated" ON "category" ("Create_by", "Server_update_at");
CREATE INDEX IF NOT EXISTS "idx_wallet_server_updated" ON "wallet" ("Idaccount", "Server_update_at");
CREATE INDEX IF NOT EXISTS "idx_budget_server_updated" ON "budget" ("Idaccount", "Server_update_at");
CREATE INDEX IF NOT EXISTS "idx_bill_server_updated" ON "bill" ("Idaccount", "Server_update_at");
CREATE INDEX IF NOT EXISTS "idx_goal_server_updated" ON "goal" ("Idaccount", "Server_update_at");
CREATE INDEX IF NOT EXISTS "idx_transaction_server_updated" ON "transaction" ("Idaccount", "Server_update_at");

-- 4. Tạo Trigger Function tự động gán Server_update_at = CURRENT_TIMESTAMP khi bản ghi được UPDATE
CREATE OR REPLACE FUNCTION set_server_update_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW."Server_update_at" = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Gắn Trigger vào 6 bảng đồng bộ
DROP TRIGGER IF EXISTS trg_set_server_update_at_category ON "category";
CREATE TRIGGER trg_set_server_update_at_category
BEFORE UPDATE ON "category"
FOR EACH ROW EXECUTE FUNCTION set_server_update_at();

DROP TRIGGER IF EXISTS trg_set_server_update_at_wallet ON "wallet";
CREATE TRIGGER trg_set_server_update_at_wallet
BEFORE UPDATE ON "wallet"
FOR EACH ROW EXECUTE FUNCTION set_server_update_at();

DROP TRIGGER IF EXISTS trg_set_server_update_at_budget ON "budget";
CREATE TRIGGER trg_set_server_update_at_budget
BEFORE UPDATE ON "budget"
FOR EACH ROW EXECUTE FUNCTION set_server_update_at();

DROP TRIGGER IF EXISTS trg_set_server_update_at_bill ON "bill";
CREATE TRIGGER trg_set_server_update_at_bill
BEFORE UPDATE ON "bill"
FOR EACH ROW EXECUTE FUNCTION set_server_update_at();

DROP TRIGGER IF EXISTS trg_set_server_update_at_goal ON "goal";
CREATE TRIGGER trg_set_server_update_at_goal
BEFORE UPDATE ON "goal"
FOR EACH ROW EXECUTE FUNCTION set_server_update_at();

DROP TRIGGER IF EXISTS trg_set_server_update_at_transaction ON "transaction";
CREATE TRIGGER trg_set_server_update_at_transaction
BEFORE UPDATE ON "transaction"
FOR EACH ROW EXECUTE FUNCTION set_server_update_at();
