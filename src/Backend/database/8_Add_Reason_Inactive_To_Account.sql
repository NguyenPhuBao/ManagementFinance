-- ============================================================================
-- Migration 8: Bổ sung cột Reason_Inactive vào bảng account
-- Ngày tạo: 2026-09-09
-- Mục đích: Lưu trữ lý do vô hiệu hóa tài khoản người dùng từ Admin-web
-- ============================================================================

ALTER TABLE "account" ADD COLUMN IF NOT EXISTS "Reason_Inactive" TEXT DEFAULT NULL;
