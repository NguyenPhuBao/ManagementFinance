-- Migration 50: Yêu cầu bản sao dữ liệu cá nhân (2026-11-13)
-- Quyền xem và nhận bản sao dữ liệu của chủ thể dữ liệu (Luật Bảo vệ dữ liệu cá nhân 2025, thời hạn đáp ứng 10 ngày).
-- Mỗi dòng là một yêu cầu: trạng thái, khóa tệp trong Supabase Storage (bucket riêng tư data-exports), thời điểm sẵn sàng / hết hạn.
-- Bảng là bằng chứng đã đáp ứng yêu cầu; tệp tự xóa sau 24 giờ (job hằng ngày), dòng yêu cầu được giữ lại.
-- Lũy đẳng: chạy lại không lỗi, không đổi dữ liệu.

CREATE TABLE IF NOT EXISTS "data_export_request" (
  "id"            VARCHAR(36)  PRIMARY KEY,
  "idaccount"     INT          NOT NULL REFERENCES "account"("Idaccount") ON DELETE CASCADE,
  "status"        VARCHAR(20)  NOT NULL DEFAULT 'PROCESSING',
  "json_ref"      TEXT         NULL,
  "csv_ref"       TEXT         NULL,
  "requested_at"  TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  "ready_at"      TIMESTAMP(6) NULL,
  "expires_at"    TIMESTAMP(6) NULL,
  "email_sent_at" TIMESTAMP(6) NULL,
  "error"         TEXT         NULL,
  CONSTRAINT "ck_data_export_status" CHECK ("status" IN ('PROCESSING', 'READY', 'EXPIRED', 'FAILED'))
);

CREATE INDEX IF NOT EXISTS "idx_data_export_account_time" ON "data_export_request" ("idaccount", "requested_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_data_export_expiry" ON "data_export_request" ("expires_at") WHERE "status" = 'READY';

COMMENT ON TABLE "data_export_request" IS 'Yêu cầu bản sao dữ liệu cá nhân; tệp ở Supabase Storage bucket data-exports, hết hạn sau 24 giờ';
