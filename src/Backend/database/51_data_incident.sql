-- Migration 51: Sổ sự cố dữ liệu cá nhân (2026-11-14)
-- Luật Bảo vệ dữ liệu cá nhân 2025 (91/2025/QH15) Điều 23, Nghị định 356/2025: thông báo cơ quan chuyên trách trong 72 giờ kể từ khi phát hiện.
-- Quy trình: docs/Rule_Project/Quy_trinh_su_co_du_lieu.md. Hạn báo = detected_at + 72 giờ (tính ở Backend).
-- Sổ sự cố là hồ sơ pháp lý: trigger chặn DELETE; sự cố đã đóng không sửa được (kiểm ở Backend).
-- Lũy đẳng: chạy lại không lỗi, không đổi dữ liệu.

CREATE TABLE IF NOT EXISTS "data_incident" (
  "id"                    SERIAL       PRIMARY KEY,
  "code"                  VARCHAR(20)  NOT NULL UNIQUE,
  "title"                 VARCHAR(200) NOT NULL,
  "description"           TEXT         NOT NULL,
  "source"                VARCHAR(20)  NOT NULL DEFAULT 'OTHER',
  "detected_at"           TIMESTAMP(6) NOT NULL,
  "occurred_at"           TIMESTAMP(6) NULL,
  "data_types"            TEXT         NULL,
  "sensitive"             BOOLEAN      NOT NULL DEFAULT FALSE,
  "affected_users"        INT          NULL,
  "affected_records"      INT          NULL,
  "consequences"          TEXT         NULL,
  "measures"              TEXT         NULL,
  "contact"               TEXT         NULL,
  "status"                VARCHAR(20)  NOT NULL DEFAULT 'OPEN',
  "contained_at"          TIMESTAMP(6) NULL,
  "authority_reported_at" TIMESTAMP(6) NULL,
  "authority_report_ref"  TEXT         NULL,
  "late_reason"           TEXT         NULL,
  "report_not_required"   BOOLEAN      NOT NULL DEFAULT FALSE,
  "no_report_reason"      TEXT         NULL,
  "users_notified_at"     TIMESTAMP(6) NULL,
  "root_cause"            TEXT         NULL,
  "closed_at"             TIMESTAMP(6) NULL,
  "created_by"            INT          NULL REFERENCES "account"("Idaccount") ON DELETE SET NULL,
  "updated_by"            INT          NULL REFERENCES "account"("Idaccount") ON DELETE SET NULL,
  "created_at"            TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  "updated_at"            TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  CONSTRAINT "ck_data_incident_status" CHECK ("status" IN ('OPEN', 'CONTAINED', 'REPORTED', 'CLOSED')),
  CONSTRAINT "ck_data_incident_source" CHECK ("source" IN ('AIOPS', 'AUDIT_LOG', 'USER_REPORT', 'PROCESSOR', 'OTHER'))
);

CREATE INDEX IF NOT EXISTS "idx_data_incident_status_detected" ON "data_incident" ("status", "detected_at" DESC);

CREATE OR REPLACE FUNCTION protect_data_incident_delete()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Sổ sự cố dữ liệu là hồ sơ pháp lý: không được xóa (data_incident %)', OLD."code";
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_data_incident ON "data_incident";
CREATE TRIGGER trg_protect_data_incident
BEFORE DELETE ON "data_incident"
FOR EACH ROW EXECUTE FUNCTION protect_data_incident_delete();

COMMENT ON TABLE "data_incident" IS 'Sổ sự cố dữ liệu cá nhân; hạn báo cơ quan chuyên trách = detected_at + 72 giờ; không được xóa';
