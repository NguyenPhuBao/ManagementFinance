-- ==============================================================================
-- Migration 17: Che bớt địa chỉ IP trong bảng refreshtoken (Zero Raw IP)
-- Tuân thủ: Luật Bảo vệ dữ liệu cá nhân 2025 (Luật 91/2025/QH15) & Nghị định 13/2023/NĐ-CP
-- Phương án A: Chuyển đổi toàn bộ IP thô thành Masked IP (a.b.xx.xx)
-- ==============================================================================

-- 1. Che bớt các địa chỉ IPv4 thô hiện có trong bảng refreshtoken
UPDATE "refreshtoken"
SET "IP_address" = REGEXP_REPLACE("IP_address", '^([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+$', '\1.xx.xx')
WHERE "IP_address" IS NOT NULL 
  AND "IP_address" ~ '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$';

-- 2. Đặt comment giải thích cho cột IP_address
COMMENT ON COLUMN "refreshtoken"."IP_address" IS 'Địa chỉ IP đã được che bớt (Masked IP: a.b.xx.xx) tuân thủ Nghị định 13/2023/NĐ-CP chống định danh cá nhân';
