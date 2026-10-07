-- ============================================================================
-- Migration 21: Đồng nhất Server_update_at về cùng đồng hồ UTC
-- Khắc phục: Lệch 7 giờ giữa trigger/default và Prisma ORM (Mục 40 CAN-LAM)
-- ============================================================================

-- 1. Cập nhật Trigger function set_server_update_at() sang (now() AT TIME ZONE 'UTC')
CREATE OR REPLACE FUNCTION set_server_update_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW."Server_update_at" = (now() AT TIME ZONE 'UTC');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Cập nhật giá trị DEFAULT của cột Server_update_at trên 6 bảng đồng bộ
ALTER TABLE IF EXISTS "category"
  ALTER COLUMN "Server_update_at" SET DEFAULT (now() AT TIME ZONE 'UTC');

ALTER TABLE IF EXISTS "wallet"
  ALTER COLUMN "Server_update_at" SET DEFAULT (now() AT TIME ZONE 'UTC');

ALTER TABLE IF EXISTS "budget"
  ALTER COLUMN "Server_update_at" SET DEFAULT (now() AT TIME ZONE 'UTC');

ALTER TABLE IF EXISTS "bill"
  ALTER COLUMN "Server_update_at" SET DEFAULT (now() AT TIME ZONE 'UTC');

ALTER TABLE IF EXISTS "goal"
  ALTER COLUMN "Server_update_at" SET DEFAULT (now() AT TIME ZONE 'UTC');

ALTER TABLE IF EXISTS "transaction"
  ALTER COLUMN "Server_update_at" SET DEFAULT (now() AT TIME ZONE 'UTC');

-- 3. Chuẩn hóa dữ liệu nếu có bản ghi bị ghi lệch trước trong tương lai (> UTC now)
UPDATE "category"
  SET "Server_update_at" = (now() AT TIME ZONE 'UTC')
  WHERE "Server_update_at" > (now() AT TIME ZONE 'UTC');

UPDATE "wallet"
  SET "Server_update_at" = (now() AT TIME ZONE 'UTC')
  WHERE "Server_update_at" > (now() AT TIME ZONE 'UTC');

UPDATE "budget"
  SET "Server_update_at" = (now() AT TIME ZONE 'UTC')
  WHERE "Server_update_at" > (now() AT TIME ZONE 'UTC');

UPDATE "bill"
  SET "Server_update_at" = (now() AT TIME ZONE 'UTC')
  WHERE "Server_update_at" > (now() AT TIME ZONE 'UTC');

UPDATE "goal"
  SET "Server_update_at" = (now() AT TIME ZONE 'UTC')
  WHERE "Server_update_at" > (now() AT TIME ZONE 'UTC');

UPDATE "transaction"
  SET "Server_update_at" = (now() AT TIME ZONE 'UTC')
  WHERE "Server_update_at" > (now() AT TIME ZONE 'UTC');
