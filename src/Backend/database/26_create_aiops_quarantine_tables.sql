-- ==============================================================================
-- Migration 26: Tạo 3 bảng lưu trữ bền vững Ma trận Phong tỏa AIOps (Phương án 1: Quan hệ N-N)
-- Tuân thủ: Luật An ninh mạng 2018 (Điều 26), Nghị định 53/2022/NĐ-CP (Lưu tối thiểu 12 tháng)
-- Tuân thủ: Rule 10 DB Guard (DDL an toàn IF NOT EXISTS) & Rule 9 Data Security (Zero PII, Hash IP)
-- ==============================================================================

-- 1. BẢNG QUẢN LÝ PHONG TỎA ĐỊA CHỈ IP
CREATE TABLE IF NOT EXISTS "aiops_ip_quarantine" (
  "id" VARCHAR(64) PRIMARY KEY,
  "ip_hash" VARCHAR(64) NOT NULL UNIQUE,
  "masked_ip" VARCHAR(45) NOT NULL,
  "raw_ip" VARCHAR(45) NULL,
  "status" VARCHAR(20) NOT NULL DEFAULT 'TEMPORARY',
  "reason" TEXT NOT NULL,
  "violation_vector" VARCHAR(20) NULL,
  "threat_score_at_ban" INT NULL,
  "hits" INT NOT NULL DEFAULT 1,
  "banned_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "expires_at" TIMESTAMP WITH TIME ZONE NULL,
  "unblocked_at" TIMESTAMP WITH TIME ZONE NULL,
  "banned_by" VARCHAR(100) NOT NULL DEFAULT 'AIOps Sentinel',
  "unblocked_by" VARCHAR(100) NULL,
  "unblock_reason" TEXT NULL,
  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Chỉ mục tối ưu hóa tốc độ tra cứu IP
CREATE INDEX IF NOT EXISTS "idx_aiops_ip_quarantine_status" ON "aiops_ip_quarantine"("status");
CREATE INDEX IF NOT EXISTS "idx_aiops_ip_quarantine_ip_hash" ON "aiops_ip_quarantine"("ip_hash");
CREATE INDEX IF NOT EXISTS "idx_aiops_ip_quarantine_expires_at" ON "aiops_ip_quarantine"("expires_at");
CREATE INDEX IF NOT EXISTS "idx_aiops_ip_quarantine_banned_at" ON "aiops_ip_quarantine"("banned_at" DESC);

-- 2. BẢNG QUẢN LÝ PHONG TỎA TÀI KHOẢN
CREATE TABLE IF NOT EXISTS "aiops_account_quarantine" (
  "id" VARCHAR(64) PRIMARY KEY,
  "idaccount" INT NULL,
  "username" VARCHAR(255) NOT NULL,
  "status" VARCHAR(20) NOT NULL DEFAULT 'TEMPORARY',
  "reason" TEXT NOT NULL,
  "violation_vector" VARCHAR(20) NULL,
  "threat_score_at_ban" INT NULL,
  "hits" INT NOT NULL DEFAULT 1,
  "banned_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "expires_at" TIMESTAMP WITH TIME ZONE NULL,
  "unblocked_at" TIMESTAMP WITH TIME ZONE NULL,
  "banned_by" VARCHAR(100) NOT NULL DEFAULT 'AIOps Sentinel',
  "unblocked_by" VARCHAR(100) NULL,
  "unblock_reason" TEXT NULL,
  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Chỉ mục tối ưu hóa tra cứu Tài khoản
CREATE INDEX IF NOT EXISTS "idx_aiops_account_quarantine_status" ON "aiops_account_quarantine"("status");
CREATE INDEX IF NOT EXISTS "idx_aiops_account_quarantine_username" ON "aiops_account_quarantine"("username");
CREATE INDEX IF NOT EXISTS "idx_aiops_account_quarantine_idaccount" ON "aiops_account_quarantine"("idaccount");
CREATE INDEX IF NOT EXISTS "idx_aiops_account_quarantine_banned_at" ON "aiops_account_quarantine"("banned_at" DESC);

-- 3. BẢNG LIÊN KẾT SỰ KIỆN VI PHẠM N-N & NHẬT KÝ ĐIỀU TRA AN NINH
CREATE TABLE IF NOT EXISTS "aiops_quarantine_incident_link" (
  "id" SERIAL PRIMARY KEY,
  "ip_quarantine_id" VARCHAR(64) NOT NULL REFERENCES "aiops_ip_quarantine"("id") ON DELETE CASCADE,
  "account_quarantine_id" VARCHAR(64) NOT NULL REFERENCES "aiops_account_quarantine"("id") ON DELETE CASCADE,
  "ip_hash" VARCHAR(64) NOT NULL,
  "username" VARCHAR(255) NOT NULL,
  "reason" TEXT NOT NULL,
  "incident_code" VARCHAR(50) NULL,
  "detected_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Chỉ mục tối ưu truy vấn điều tra chéo N-N
CREATE INDEX IF NOT EXISTS "idx_quarantine_link_ip" ON "aiops_quarantine_incident_link"("ip_quarantine_id");
CREATE INDEX IF NOT EXISTS "idx_quarantine_link_account" ON "aiops_quarantine_incident_link"("account_quarantine_id");
CREATE INDEX IF NOT EXISTS "idx_quarantine_link_ip_hash" ON "aiops_quarantine_incident_link"("ip_hash");
CREATE INDEX IF NOT EXISTS "idx_quarantine_link_username" ON "aiops_quarantine_incident_link"("username");
CREATE INDEX IF NOT EXISTS "idx_quarantine_link_detected_at" ON "aiops_quarantine_incident_link"("detected_at" DESC);
