-- Migration 49: Chính sách bảo mật theo phiên bản và bằng chứng người dùng đồng ý (T3, 2026-11-13)
-- Căn cứ: Luật Bảo vệ dữ liệu cá nhân 2025, Nghị định 356/2025/NĐ-CP Điều 6 (bên kiểm soát lưu bằng chứng đồng ý).
-- Mô hình: mỗi phiên bản chính sách là một dòng (không sửa nội dung đã đăng); người dùng đồng ý một lần cho mỗi phiên bản,
-- không có rút đồng ý từng mục đích. Lũy đẳng.

CREATE TABLE IF NOT EXISTS "privacy_policy" (
  "version"      INTEGER PRIMARY KEY,
  "title"        VARCHAR(200) NOT NULL,
  "content"      TEXT NOT NULL,
  "published_at" TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  "published_by" INTEGER NULL REFERENCES "account" ("Idaccount") ON DELETE SET NULL,
  CONSTRAINT "ck_privacy_policy_version_positive" CHECK ("version" > 0)
);

CREATE TABLE IF NOT EXISTS "policy_acceptance" (
  "id"             BIGSERIAL PRIMARY KEY,
  "idaccount"      INTEGER NOT NULL REFERENCES "account" ("Idaccount") ON DELETE CASCADE,
  "policy_version" INTEGER NOT NULL REFERENCES "privacy_policy" ("version") ON DELETE RESTRICT,
  "accepted_at"    TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  "ip_hash"        VARCHAR(64) NULL,
  "device_name"    VARCHAR(150) NULL,
  "user_agent"     TEXT NULL,
  CONSTRAINT "uq_policy_acceptance_account_version" UNIQUE ("idaccount", "policy_version")
);

CREATE INDEX IF NOT EXISTS "idx_policy_acceptance_version" ON "policy_acceptance" ("policy_version");

CREATE OR REPLACE FUNCTION protect_policy_immutability()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'BẢO MẬT: % chỉ được thêm, không được sửa (bằng chứng chính sách / đồng ý).', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_privacy_policy ON "privacy_policy";
CREATE TRIGGER trg_protect_privacy_policy
BEFORE UPDATE ON "privacy_policy"
FOR EACH ROW EXECUTE FUNCTION protect_policy_immutability();

DROP TRIGGER IF EXISTS trg_protect_policy_acceptance ON "policy_acceptance";
CREATE TRIGGER trg_protect_policy_acceptance
BEFORE UPDATE ON "policy_acceptance"
FOR EACH ROW EXECUTE FUNCTION protect_policy_immutability();

COMMENT ON TABLE "privacy_policy" IS 'Chính sách bảo mật theo phiên bản; phiên bản lớn nhất là hiện hành; không sửa nội dung đã đăng';
COMMENT ON TABLE "policy_acceptance" IS 'Bằng chứng người dùng đồng ý từng phiên bản chính sách (Nghị định 356/2025 Điều 6); chỉ thêm';
COMMENT ON COLUMN "policy_acceptance"."ip_hash" IS 'HMAC-SHA256(BLIND_INDEX_SECRET, IP) lúc đồng ý; không lưu IP';
