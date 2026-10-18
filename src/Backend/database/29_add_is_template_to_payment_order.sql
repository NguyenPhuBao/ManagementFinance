-- ============================================================================
-- Migration 29: Bổ sung trường is_template vào bảng payment_order
-- Phục vụ phân biệt đơn hàng mẫu (thử nghiệm) và đơn hàng thật của người dùng
-- ============================================================================

-- 1. Thêm cột is_template (Mặc định FALSE cho tất cả đơn của người dùng)
ALTER TABLE "payment_order"
ADD COLUMN IF NOT EXISTS "is_template" BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Tạo Index phục vụ bộ lọc tìm kiếm và loại bỏ đơn mẫu tốc độ cao
CREATE INDEX IF NOT EXISTS "idx_payment_order_is_template" 
ON "payment_order"("is_template");

-- 3. Cập nhật các đơn hàng mẫu đã phát sinh trước đây thành TRUE
UPDATE "payment_order"
SET "is_template" = TRUE
WHERE "payment_link_id" LIKE 'sample-link-%';

COMMENT ON COLUMN "payment_order"."is_template" IS 'Cờ đánh dấu đơn hàng mẫu (TRUE) do Admin thử nghiệm, hoặc đơn thật (FALSE) của người dùng';
