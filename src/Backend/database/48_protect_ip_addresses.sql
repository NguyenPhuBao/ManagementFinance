-- Migration 48: Bảo vệ địa chỉ IP (phương án B, 2026-11-13)
-- Lịch sử thiết bị lưu thêm IP đầy đủ dạng mã hóa AES-256-GCM (ip_encrypted) và chỉ mục mù HMAC-SHA256 (ip_hash)
-- để so khớp và điều tra; bản che ip_address giữ nguyên để hiển thị.
-- Bảng cách ly AIOps: raw_ip chuyển sang lưu bản mã (chuỗi "enc:..." dài hơn 45 ký tự nên đổi kiểu TEXT).
-- Bản mã và chỉ mục mù bị xóa sau IP_RETENTION_DAYS (job hằng ngày runDailyIpRetentionPurgeTask).
-- Lũy đẳng: chạy lại không lỗi, không đổi dữ liệu.

ALTER TABLE "account_device_history" ADD COLUMN IF NOT EXISTS "ip_encrypted" TEXT NULL;
ALTER TABLE "account_device_history" ADD COLUMN IF NOT EXISTS "ip_hash" VARCHAR(64) NULL;

CREATE INDEX IF NOT EXISTS "idx_device_history_ip_hash"
  ON "account_device_history" ("ip_hash")
  WHERE "ip_hash" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "idx_device_history_ip_retention"
  ON "account_device_history" ("last_active_at")
  WHERE "ip_encrypted" IS NOT NULL;

ALTER TABLE "aiops_ip_quarantine" ALTER COLUMN "raw_ip" TYPE TEXT;

COMMENT ON COLUMN "account_device_history"."ip_address" IS 'IP đã che (a.b.xx.xx), chỉ để hiển thị';
COMMENT ON COLUMN "account_device_history"."ip_encrypted" IS 'IP đầy đủ mã hóa AES-256-GCM; chỉ giải khi admin xác thực PIN; xóa sau IP_RETENTION_DAYS';
COMMENT ON COLUMN "account_device_history"."ip_hash" IS 'HMAC-SHA256(BLIND_INDEX_SECRET, IP) để so khớp và tra cứu; xóa cùng ip_encrypted';
COMMENT ON COLUMN "aiops_ip_quarantine"."raw_ip" IS 'IP đầy đủ mã hóa AES-256-GCM (enc:...); xóa sau IP_RETENTION_DAYS';
