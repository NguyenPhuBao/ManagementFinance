-- Migration 54: Nhiều chính sách song song, phiên bản theo từng chính sách, trạng thái Đang sử dụng / Ngừng sử dụng (2026-11-15)
-- Trước: privacy_policy đánh phiên bản chung, phiên bản lớn nhất là hiện hành, cấm mọi UPDATE.
-- Sau:
--   * policy_document: mỗi dòng là một chính sách (tiêu đề không trùng).
--   * privacy_policy: thêm document_id, doc_version (phiên bản trong chính sách), status ACTIVE / INACTIVE.
--     "version" giữ làm mã nội bộ (policy_acceptance vẫn tham chiếu), bằng chứng đồng ý cũ không đổi.
--   * Mỗi chính sách chỉ có MỘT phiên bản ACTIVE (index duy nhất có điều kiện).
--   * Trigger: tiêu đề / nội dung / người đăng / thời điểm đăng / mã phiên bản vẫn không sửa được; chỉ cho đổi trạng thái.
-- Dữ liệu cũ: mỗi tiêu đề thành một chính sách, phiên bản đánh từ 1 theo thứ tự đăng; bản mới nhất của mỗi tiêu đề ACTIVE.
-- Lũy đẳng: chạy lại không đổi gì.

CREATE TABLE IF NOT EXISTS "policy_document" (
  "id"         SERIAL PRIMARY KEY,
  "title"      VARCHAR(200) NOT NULL,
  "created_at" TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  "created_by" INTEGER NULL REFERENCES "account" ("Idaccount") ON DELETE SET NULL,
  CONSTRAINT "uq_policy_document_title" UNIQUE ("title")
);

ALTER TABLE "privacy_policy" ADD COLUMN IF NOT EXISTS "document_id" INTEGER NULL;
ALTER TABLE "privacy_policy" ADD COLUMN IF NOT EXISTS "doc_version" INTEGER NULL;
ALTER TABLE "privacy_policy" ADD COLUMN IF NOT EXISTS "status" VARCHAR(10) NOT NULL DEFAULT 'INACTIVE';
ALTER TABLE "privacy_policy" ADD COLUMN IF NOT EXISTS "status_changed_at" TIMESTAMP(6) NULL;
ALTER TABLE "privacy_policy" ADD COLUMN IF NOT EXISTS "status_changed_by" INTEGER NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_privacy_policy_document') THEN
    ALTER TABLE "privacy_policy" ADD CONSTRAINT "fk_privacy_policy_document"
      FOREIGN KEY ("document_id") REFERENCES "policy_document" ("id") ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_privacy_policy_status_changed_by') THEN
    ALTER TABLE "privacy_policy" ADD CONSTRAINT "fk_privacy_policy_status_changed_by"
      FOREIGN KEY ("status_changed_by") REFERENCES "account" ("Idaccount") ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_privacy_policy_status') THEN
    ALTER TABLE "privacy_policy" ADD CONSTRAINT "ck_privacy_policy_status" CHECK ("status" IN ('ACTIVE', 'INACTIVE'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_privacy_policy_doc_version_positive') THEN
    ALTER TABLE "privacy_policy" ADD CONSTRAINT "ck_privacy_policy_doc_version_positive" CHECK ("doc_version" IS NULL OR "doc_version" > 0);
  END IF;
END $$;

-- Trigger mới cho privacy_policy (thay protect_policy_immutability, vốn cấm mọi UPDATE).
-- policy_acceptance giữ nguyên trigger cũ: bằng chứng đồng ý chỉ được thêm.
CREATE OR REPLACE FUNCTION protect_privacy_policy_content()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW."version" IS DISTINCT FROM OLD."version"
     OR NEW."title" IS DISTINCT FROM OLD."title"
     OR NEW."content" IS DISTINCT FROM OLD."content"
     OR NEW."published_at" IS DISTINCT FROM OLD."published_at"
     -- published_by chỉ được về NULL (khoá ngoại ON DELETE SET NULL)
     OR (NEW."published_by" IS DISTINCT FROM OLD."published_by" AND NEW."published_by" IS NOT NULL)
     -- document_id / doc_version: chỉ được gán một lần (lúc chuyển dữ liệu cũ)
     OR (OLD."document_id" IS NOT NULL AND NEW."document_id" IS DISTINCT FROM OLD."document_id")
     OR (OLD."doc_version" IS NOT NULL AND NEW."doc_version" IS DISTINCT FROM OLD."doc_version") THEN
    RAISE EXCEPTION 'BẢO MẬT: privacy_policy chỉ được đổi trạng thái; nội dung chính sách đã đăng không được sửa.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_privacy_policy ON "privacy_policy";
CREATE TRIGGER trg_protect_privacy_policy
BEFORE UPDATE ON "privacy_policy"
FOR EACH ROW EXECUTE FUNCTION protect_privacy_policy_content();

-- Chuyển dữ liệu cũ (chỉ các dòng chưa có document_id)
INSERT INTO "policy_document" ("title", "created_at", "created_by")
SELECT DISTINCT ON (btrim(p."title")) btrim(p."title"), p."published_at", p."published_by"
FROM "privacy_policy" p
WHERE p."document_id" IS NULL
ORDER BY btrim(p."title"), p."version"
ON CONFLICT ("title") DO NOTHING;

UPDATE "privacy_policy" p
SET "document_id" = d."id"
FROM "policy_document" d
WHERE p."document_id" IS NULL AND d."title" = btrim(p."title");

-- Bản mới nhất của mỗi chính sách (trong các dòng vừa chuyển) là ACTIVE
UPDATE "privacy_policy" p
SET "status" = 'ACTIVE'
WHERE p."doc_version" IS NULL
  AND p."version" = (SELECT max(x."version") FROM "privacy_policy" x WHERE x."document_id" = p."document_id")
  AND NOT EXISTS (SELECT 1 FROM "privacy_policy" y WHERE y."document_id" = p."document_id" AND y."status" = 'ACTIVE');

UPDATE "privacy_policy" p
SET "doc_version" = s.rn
FROM (
  SELECT "version", row_number() OVER (PARTITION BY "document_id" ORDER BY "version") AS rn
  FROM "privacy_policy"
) s
WHERE p."version" = s."version" AND p."doc_version" IS NULL;

ALTER TABLE "privacy_policy" ALTER COLUMN "document_id" SET NOT NULL;
ALTER TABLE "privacy_policy" ALTER COLUMN "doc_version" SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "uq_privacy_policy_document_version" ON "privacy_policy" ("document_id", "doc_version");
CREATE UNIQUE INDEX IF NOT EXISTS "uq_privacy_policy_one_active" ON "privacy_policy" ("document_id") WHERE "status" = 'ACTIVE';
CREATE INDEX IF NOT EXISTS "idx_privacy_policy_status" ON "privacy_policy" ("status");

COMMENT ON TABLE "policy_document" IS 'Mỗi dòng là một chính sách; các phiên bản nằm ở privacy_policy (document_id)';
COMMENT ON TABLE "privacy_policy" IS 'Phiên bản chính sách; nội dung đã đăng không sửa; chỉ đổi trạng thái ACTIVE / INACTIVE; mỗi chính sách tối đa một bản ACTIVE';
COMMENT ON COLUMN "privacy_policy"."version" IS 'Mã nội bộ của phiên bản (policy_acceptance tham chiếu); số phiên bản hiển thị là doc_version';
COMMENT ON COLUMN "privacy_policy"."doc_version" IS 'Số phiên bản trong một chính sách (v1, v2…)';
