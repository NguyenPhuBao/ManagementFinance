-- Migration 53: Sổ giao dịch thanh toán bất biến + lưu chứng cứ đối chiếu PayOS / ngân hàng.
-- Kế hoạch: docs/superpowers/plans/2026-11-15-don-mau-thanh-toan-chong-lam-dung.md (mục 2.1, 2.4, 2.5)
--
--  1. Dọn đơn mẫu và giao dịch giả hiện có (CHỈ khi trigger bảo vệ chưa tồn tại — chạy lại an toàn).
--  2. payment_order: thêm hidden_at / hidden_by (ẩn đơn mẫu thay cho xoá).
--  3. payment_transaction: thêm cột chứng cứ (chiều tiền, nguồn, tài khoản nhận, người chuyển mã hoá,
--     payload gốc mã hoá, người ghi hoàn tiền, minh chứng); mã giao dịch ngân hàng NOT NULL + duy nhất.
--  4. payment_webhook_log: nhật ký mọi webhook PayOS có chữ ký hợp lệ (append-only).
--  5. Trigger: payment_transaction và payment_webhook_log cấm UPDATE / DELETE;
--     payment_order cấm DELETE, cấm sửa trường gốc, trường tiền ghi một lần, đơn REFUNDED khoá hẳn.
-- Luỹ đẳng: chạy lại nhiều lần không lỗi.

-- 1. Dọn đơn mẫu / giao dịch giả trước khi khoá sổ
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_protect_payment_transaction') THEN
    DELETE FROM "payment_transaction"
     WHERE "order_id" IN (SELECT "id" FROM "payment_order" WHERE "is_template" = TRUE)
        OR "payos_transaction_id" LIKE 'SAMPLE-TXN-%'
        OR "payos_transaction_id" LIKE 'SIM-REF-%';
    DELETE FROM "payment_order" WHERE "is_template" = TRUE;
  END IF;
END $$;

-- 2. Ẩn đơn mẫu
ALTER TABLE "payment_order" ADD COLUMN IF NOT EXISTS "hidden_at" TIMESTAMP(6) NULL;
ALTER TABLE "payment_order" ADD COLUMN IF NOT EXISTS "hidden_by" INTEGER NULL;

-- 3. Cột chứng cứ của sổ giao dịch
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "direction" VARCHAR(3) NOT NULL DEFAULT 'IN';
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "source" VARCHAR(12) NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "receiving_account_number" VARCHAR(50) NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "payment_link_id" VARCHAR(64) NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "transfer_description" VARCHAR(255) NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "currency" VARCHAR(10) NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "counter_account_bank_id" VARCHAR(20) NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "counter_account_bank_name" VARCHAR(255) NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "counter_account_name" VARCHAR(512) NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "counter_account_number" VARCHAR(512) NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "raw_payload" TEXT NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "created_by" INTEGER NULL;
ALTER TABLE "payment_transaction" ADD COLUMN IF NOT EXISTS "proof" TEXT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_payment_transaction_direction') THEN
    ALTER TABLE "payment_transaction" ADD CONSTRAINT "ck_payment_transaction_direction" CHECK ("direction" IN ('IN', 'OUT'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_payment_transaction_source') THEN
    ALTER TABLE "payment_transaction" ADD CONSTRAINT "ck_payment_transaction_source"
      CHECK ("source" IS NULL OR "source" IN ('WEBHOOK', 'PAYOS_API', 'ADMIN_REFUND'));
  END IF;
END $$;

-- Mã giao dịch ngân hàng: bắt buộc (không bao giờ thay bằng mã đơn). Tính duy nhất do chỉ mục sẵn có
-- "uq_payment_transaction_payos_id" (WHERE NOT NULL) bảo đảm — cột đã NOT NULL nên áp cho mọi dòng.
ALTER TABLE "payment_transaction" ALTER COLUMN "payos_transaction_id" SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "uq_payment_transaction_payos_id" ON "payment_transaction" ("payos_transaction_id") WHERE "payos_transaction_id" IS NOT NULL;
DROP INDEX IF EXISTS "uq_payment_transaction_bank_ref";

COMMENT ON COLUMN "payment_transaction"."payos_transaction_id" IS 'Mã giao dịch ngân hàng (PayOS reference / mã chuyển khoản hoàn tiền). Bắt buộc, duy nhất, không thay bằng mã đơn.';
COMMENT ON COLUMN "payment_transaction"."counter_account_number" IS 'Số tài khoản người chuyển (tiền vào) - mã hoá AES-256-GCM';
COMMENT ON COLUMN "payment_transaction"."raw_payload" IS 'Webhook gốc có chữ ký PayOS hoặc phản hồi API PayOS - mã hoá AES-256-GCM';

-- 4. Nhật ký webhook thô
CREATE TABLE IF NOT EXISTS "payment_webhook_log" (
  "id"              BIGSERIAL PRIMARY KEY,
  "received_at"     TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "order_code"      BIGINT NULL,
  "reference"       VARCHAR(100) NULL,
  "amount"          DECIMAL(15, 2) NULL,
  "signature_valid" BOOLEAN NOT NULL,
  "handled_as"      VARCHAR(40) NULL,
  "payload"         TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS "idx_payment_webhook_log_order_code" ON "payment_webhook_log" ("order_code");
CREATE INDEX IF NOT EXISTS "idx_payment_webhook_log_received_at" ON "payment_webhook_log" ("received_at");
COMMENT ON TABLE "payment_webhook_log" IS 'Nhật ký mọi webhook PayOS có chữ ký hợp lệ (payload mã hoá). Append-only.';

-- 5. Trigger bất biến
CREATE OR REPLACE FUNCTION "fn_payment_ledger_immutable"() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'Bảng % là sổ chứng từ thanh toán: cấm % (quy định lưu trữ chứng từ)', TG_TABLE_NAME, TG_OP
    USING ERRCODE = 'P0001';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS "trg_protect_payment_transaction" ON "payment_transaction";
CREATE TRIGGER "trg_protect_payment_transaction"
  BEFORE UPDATE OR DELETE ON "payment_transaction"
  FOR EACH ROW EXECUTE FUNCTION "fn_payment_ledger_immutable"();

DROP TRIGGER IF EXISTS "trg_protect_payment_webhook_log" ON "payment_webhook_log";
CREATE TRIGGER "trg_protect_payment_webhook_log"
  BEFORE UPDATE OR DELETE ON "payment_webhook_log"
  FOR EACH ROW EXECUTE FUNCTION "fn_payment_ledger_immutable"();

CREATE OR REPLACE FUNCTION "fn_protect_payment_order"() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Đơn thanh toán % là chứng từ: cấm xoá', OLD."order_code" USING ERRCODE = 'P0001';
  END IF;
  IF OLD."status" = 'REFUNDED' THEN
    RAISE EXCEPTION 'Đơn % đã hoàn tiền: khoá, không được sửa', OLD."order_code" USING ERRCODE = 'P0001';
  END IF;
  IF NEW."id" IS DISTINCT FROM OLD."id"
     OR NEW."idaccount" IS DISTINCT FROM OLD."idaccount"
     OR NEW."order_code" IS DISTINCT FROM OLD."order_code"
     OR NEW."package_type" IS DISTINCT FROM OLD."package_type"
     OR NEW."amount" IS DISTINCT FROM OLD."amount"
     OR NEW."currency" IS DISTINCT FROM OLD."currency"
     OR NEW."is_template" IS DISTINCT FROM OLD."is_template"
     OR NEW."created_at" IS DISTINCT FROM OLD."created_at"
     OR (OLD."recognition_code" IS NOT NULL AND NEW."recognition_code" IS DISTINCT FROM OLD."recognition_code") THEN
    RAISE EXCEPTION 'Đơn %: cấm sửa trường gốc của chứng từ', OLD."order_code" USING ERRCODE = 'P0001';
  END IF;
  IF (OLD."paid_at" IS NOT NULL AND NEW."paid_at" IS DISTINCT FROM OLD."paid_at")
     OR (OLD."amount_received" <> 0 AND NEW."amount_received" IS DISTINCT FROM OLD."amount_received")
     OR (OLD."refunded_at" IS NOT NULL AND NEW."refunded_at" IS DISTINCT FROM OLD."refunded_at")
     OR (OLD."refunded_amount" IS NOT NULL AND NEW."refunded_amount" IS DISTINCT FROM OLD."refunded_amount")
     OR (OLD."refund_proof" IS NOT NULL AND NEW."refund_proof" IS DISTINCT FROM OLD."refund_proof")
     OR (OLD."hidden_at" IS NOT NULL AND NEW."hidden_at" IS DISTINCT FROM OLD."hidden_at") THEN
    RAISE EXCEPTION 'Đơn %: trường tiền / thời điểm chỉ ghi một lần', OLD."order_code" USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS "trg_protect_payment_order" ON "payment_order";
CREATE TRIGGER "trg_protect_payment_order"
  BEFORE UPDATE OR DELETE ON "payment_order"
  FOR EACH ROW EXECUTE FUNCTION "fn_protect_payment_order"();
