-- ==============================================================================
-- 12_Can_Lam_Align_Schema_Fixes.sql
-- Mục đích:
-- 1. Xóa bỏ index "uq_wallet_saving_active" (Cho phép user có nhiều ví tiết kiệm)
-- 2. Bổ sung cột "Color" vào bảng "category"
-- 3. Bổ sung cột "Idbill" và khóa ngoại vào bảng "transaction"
-- 4. Bổ sung các cột "Previous_bill_id", "Period_end", "Auto_pay", "Anchor_day" vào bảng "bill"
-- 5. Cập nhật CHECK constraint "chk_bill_pay_status" nhận thêm trạng thái 'Skipped'
-- 6. Chuẩn hóa dữ liệu Goal Priority: NULL thay vì <= 0
-- ==============================================================================

-- 1. Xóa bỏ partial unique index ví tiết kiệm (User được tạo nhiều ví tiết kiệm)
DROP INDEX IF EXISTS "uq_wallet_saving_active";

-- 2. Bổ sung cột Color cho category
ALTER TABLE "category" ADD COLUMN IF NOT EXISTS "Color" VARCHAR(9) NULL;

-- 3. Bổ sung cột Idbill vào transaction (Liên kết giao dịch thanh toán với hóa đơn)
ALTER TABLE "transaction" ADD COLUMN IF NOT EXISTS "Idbill" VARCHAR(36) NULL;

ALTER TABLE "transaction" DROP CONSTRAINT IF EXISTS "fk_transaction_bill";
ALTER TABLE "transaction" ADD CONSTRAINT "fk_transaction_bill"
  FOREIGN KEY ("Idbill") REFERENCES "bill"("Idbill")
  ON DELETE SET NULL ON UPDATE NO ACTION;

CREATE INDEX IF NOT EXISTS "idx_transaction_bill" ON "transaction"("Idbill") WHERE "Idbill" IS NOT NULL;

-- 4. Bổ sung các trường chuỗi kỳ, ngày neo, và thanh toán tự động cho bill
ALTER TABLE "bill" ADD COLUMN IF NOT EXISTS "Previous_bill_id" VARCHAR(36) NULL;

ALTER TABLE "bill" DROP CONSTRAINT IF EXISTS "fk_bill_previous_bill";
ALTER TABLE "bill" ADD CONSTRAINT "fk_bill_previous_bill"
  FOREIGN KEY ("Previous_bill_id") REFERENCES "bill"("Idbill")
  ON DELETE SET NULL ON UPDATE NO ACTION;

CREATE INDEX IF NOT EXISTS "idx_bill_previous_bill" ON "bill"("Previous_bill_id") WHERE "Previous_bill_id" IS NOT NULL;

ALTER TABLE "bill" ADD COLUMN IF NOT EXISTS "Period_end" DATE NULL;
ALTER TABLE "bill" ADD COLUMN IF NOT EXISTS "Auto_pay" BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE "bill" ADD COLUMN IF NOT EXISTS "Anchor_day" SMALLINT NULL;

ALTER TABLE "bill" DROP CONSTRAINT IF EXISTS "chk_bill_anchor_day";
ALTER TABLE "bill" ADD CONSTRAINT "chk_bill_anchor_day"
  CHECK ("Anchor_day" IS NULL OR ("Anchor_day" BETWEEN 1 AND 31));

-- 5. Cập nhật ràng buộc trạng thái hóa đơn hỗ trợ 'Skipped'
ALTER TABLE "bill" DROP CONSTRAINT IF EXISTS "chk_bill_pay_status";
ALTER TABLE "bill" ADD CONSTRAINT "chk_bill_pay_status"
  CHECK ("Pay_status" IN ('Pending', 'Payed', 'Overdue', 'Skipped'));

-- 6. Dọn dẹp dữ liệu Goal Priority: chuyển các giá trị <= 0 về NULL
UPDATE "goal" SET "Priority" = NULL WHERE "Priority" IS NOT NULL AND "Priority" <= 0;
