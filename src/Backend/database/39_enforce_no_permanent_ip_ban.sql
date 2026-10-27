-- ==============================================================================
-- Migration 39: Chặn hoàn toàn việc phong tỏa vĩnh viễn địa chỉ IP (No Permanent IP Ban)
-- Tuân thủ: Quyết định chính sách an ninh của PO (Tránh chặn nhầm mạng dùng chung CGNAT / 4G / IP Động)
-- Quy tắc: DB Guard (Rule 10) - DDL Idempotent, bảo vệ tính toàn vẹn dữ liệu
-- ==============================================================================

-- 1. Dọn dẹp dữ liệu lịch sử: Chuyển các IP đang có status 'PERMANENT' sang 'TEMPORARY' với thời hạn 4 giờ
UPDATE "aiops_ip_quarantine"
SET 
  "status" = 'TEMPORARY',
  "expires_at" = COALESCE("expires_at", NOW() + INTERVAL '4 hours'),
  "updated_at" = NOW(),
  "reason" = "reason" || ' (Chuyển từ khóa vĩnh viễn sang tạm khóa 4 giờ theo chính sách an ninh mới)'
WHERE "status" = 'PERMANENT' OR "status" NOT IN ('TEMPORARY', 'UNLOCKED');

-- 2. Thêm Check Constraint cấm vĩnh viễn trạng thái 'PERMANENT' đối với địa chỉ IP
ALTER TABLE "aiops_ip_quarantine"
DROP CONSTRAINT IF EXISTS "chk_aiops_ip_quarantine_no_permanent";

ALTER TABLE "aiops_ip_quarantine"
ADD CONSTRAINT "chk_aiops_ip_quarantine_no_permanent"
CHECK ("status" IN ('TEMPORARY', 'UNLOCKED'));

-- 3. Thêm Check Constraint bắt buộc phải có thời gian hết hạn (expires_at) khi ở trạng thái 'TEMPORARY'
ALTER TABLE "aiops_ip_quarantine"
DROP CONSTRAINT IF EXISTS "chk_aiops_ip_quarantine_temp_has_expiry";

ALTER TABLE "aiops_ip_quarantine"
ADD CONSTRAINT "chk_aiops_ip_quarantine_temp_has_expiry"
CHECK ("status" <> 'TEMPORARY' OR "expires_at" IS NOT NULL);
