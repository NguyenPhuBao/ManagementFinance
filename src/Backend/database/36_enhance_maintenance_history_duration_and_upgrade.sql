-- Migration 36: Bổ sung actual_duration_seconds và hỗ trợ loại UPGRADE trong maintenance_history
-- Tuân thủ Rule 10 DB Guard: Chạy DDL an toàn IF NOT EXISTS

ALTER TABLE "maintenance_history" 
ADD COLUMN IF NOT EXISTS "actual_duration_seconds" INTEGER NULL;

COMMENT ON COLUMN "maintenance_history"."actual_duration_seconds" IS 'Thời lượng thực tế của phiên bảo trì hoặc nâng cấp tính bằng giây';
