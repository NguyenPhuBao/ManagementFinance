-- Một mục tiêu sống mỗi ví chung (docs/Family/03 mục 5).
-- Trước khi áp, câu sau phải ra 0 hàng; ra hàng thì dừng, báo người dùng, không tự xoá:
--   SELECT "Idwallet", COUNT(*) FROM "goal"
--   WHERE "Idhousehold" IS NOT NULL AND "Delete_at" IS NULL AND "Idwallet" IS NOT NULL
--   GROUP BY "Idwallet" HAVING COUNT(*) > 1;
CREATE UNIQUE INDEX IF NOT EXISTS "uq_goal_household_wallet_active"
  ON "goal" ("Idwallet") WHERE "Idhousehold" IS NOT NULL AND "Delete_at" IS NULL;
