-- ==============================================================================
-- 9_Add_Countdown_To_Account.sql
-- Bổ sung cột Countdown vào bảng account để quản lý thời gian chờ xóa (30 ngày)
-- ==============================================================================

ALTER TABLE "account" 
ADD COLUMN IF NOT EXISTS "Countdown" INT DEFAULT NULL;

COMMENT ON COLUMN "account"."Countdown" IS 'Số ngày đếm ngược chờ xóa tài khoản (mặc định 30 khi chuyển sang PendingDelete, null khi Active/Deleted)';
