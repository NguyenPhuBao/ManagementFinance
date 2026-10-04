-- ==============================================================================
-- Migration 15: Tạo bảng aiops_incident lưu trữ vĩnh viễn nhật ký sự cố bất thường
-- Tuân thủ: Luật An ninh mạng 2018 (Điều 26), Nghị định 53/2022/NĐ-CP (Lưu tối thiểu 12 tháng)
-- và Data_Security.md (Zero PII thô, lưu Masked IP + Hash IP)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS "aiops_incident" (
  "id" VARCHAR(64) PRIMARY KEY,
  "code" VARCHAR(50) NOT NULL,
  "vector" VARCHAR(20) NOT NULL,
  "severity" VARCHAR(10) NOT NULL,
  "message" TEXT NOT NULL,
  "status" VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  "actor_type" VARCHAR(30) NOT NULL,
  "actor_identity" VARCHAR(100) NOT NULL,
  "actor_hash" VARCHAR(64) NOT NULL,
  "user_id" INT NULL,
  "username" VARCHAR(255) NULL,
  "user_agent" TEXT NULL,
  "target_endpoint" VARCHAR(255) NULL,
  "metric_current" NUMERIC NULL,
  "metric_baseline" NUMERIC NULL,
  "metric_unit" VARCHAR(50) NULL,
  "mitigation_taken" TEXT NULL,
  "root_cause_diagnosis" TEXT NULL,
  "hits" INT NOT NULL DEFAULT 1,
  "first_detected_at" TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  "last_seen_at" TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  "mitigated_at" TIMESTAMP(6) NULL
);

-- Chỉ mục tối ưu hóa tốc độ truy vấn & phân trang Server-side
CREATE INDEX IF NOT EXISTS "idx_aiops_incident_status" ON "aiops_incident"("status");
CREATE INDEX IF NOT EXISTS "idx_aiops_incident_vector" ON "aiops_incident"("vector");
CREATE INDEX IF NOT EXISTS "idx_aiops_incident_detected_at" ON "aiops_incident"("first_detected_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_aiops_incident_actor_hash" ON "aiops_incident"("actor_hash");
CREATE INDEX IF NOT EXISTS "idx_aiops_incident_code" ON "aiops_incident"("code");
