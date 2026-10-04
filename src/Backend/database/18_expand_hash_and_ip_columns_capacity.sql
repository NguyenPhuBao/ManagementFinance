-- ============================================================================
-- Migration 18: Mở rộng dung lượng lưu trữ các cột Hash và IP trong CSDL
-- Mục đích: Đảm bảo CSDL lưu trữ an toàn các giá trị băm (Hash) lên tới 256 ký tự
-- (hoặc 512 ký tự), loại trừ triệt để nguy cơ khai báo cột chỉ có 40, 45 hoặc 64 ký tự
-- gây lỗi tràn dữ liệu (character varying length overflow).
-- Tuân thủ: Luật Bảo vệ dữ liệu cá nhân 2025, NĐ 13/2023/NĐ-CP & NĐ 53/2022/NĐ-CP.
-- Ngày tạo: 2026-10-04
-- ============================================================================

-- 1. BẢNG REFRESHTOKEN:
-- Mở rộng IP_address từ VARCHAR(45) lên VARCHAR(256) để an toàn cho cả Masked IP lẫn chuỗi Hash
ALTER TABLE "refreshtoken" ALTER COLUMN "IP_address" TYPE VARCHAR(256);
COMMENT ON COLUMN "refreshtoken"."IP_address" IS 'Địa chỉ IP đã che mờ (Masked IP) hoặc Hash (dung lượng tối đa 256 ký tự)';

-- Mở rộng Token_hash từ VARCHAR(255) lên VARCHAR(512) để tránh bẫy 255/256 ký tự
ALTER TABLE "refreshtoken" ALTER COLUMN "Token_hash" TYPE VARCHAR(512);

-- 2. BẢNG AIOPS_INCIDENT:
-- Mở rộng actor_hash từ VARCHAR(64) lên VARCHAR(256) để chứa mọi định dạng hash thuật toán
ALTER TABLE "aiops_incident" ALTER COLUMN "actor_hash" TYPE VARCHAR(256);

-- Mở rộng actor_identity từ VARCHAR(100) lên VARCHAR(256)
ALTER TABLE "aiops_incident" ALTER COLUMN "actor_identity" TYPE VARCHAR(256);

-- Mở rộng id từ VARCHAR(64) lên VARCHAR(256)
ALTER TABLE "aiops_incident" ALTER COLUMN "id" TYPE VARCHAR(256);

-- 3. BẢNG BANK_ACCOUNT:
-- Mở rộng Account_number_hash từ VARCHAR(64) lên VARCHAR(256)
ALTER TABLE "bank_account" ALTER COLUMN "Account_number_hash" TYPE VARCHAR(256);

-- 4. BẢNG OTP_CODE:
-- Mở rộng code_hash từ VARCHAR(255) lên VARCHAR(512)
ALTER TABLE "otp_code" ALTER COLUMN "code_hash" TYPE VARCHAR(512);
