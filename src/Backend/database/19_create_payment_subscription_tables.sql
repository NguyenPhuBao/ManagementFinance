-- Migration: 19_create_payment_subscription_tables.sql
-- Mô tả: Thêm cột premium_expires_at vào bảng account và tạo 2 bảng payment_order, payment_transaction
-- Tuân thủ: Data_Security.md (PCI-DSS & NĐ 13/2023/NĐ-CP), Rule 10 (DB Guard)

-- 1. Thêm cột premium_expires_at vào bảng account nếu chưa có
ALTER TABLE "account" 
ADD COLUMN IF NOT EXISTS "premium_expires_at" TIMESTAMP(6) NULL;

-- 2. Tạo bảng payment_order (Đơn hàng thanh toán gói dịch vụ)
CREATE TABLE IF NOT EXISTS "payment_order" (
    "id" VARCHAR(36) NOT NULL,
    "idaccount" INTEGER NOT NULL,
    "order_code" BIGINT NOT NULL,
    "package_type" VARCHAR(30) NOT NULL DEFAULT 'PREMIUM_1_MONTH',
    "amount" DECIMAL(15, 2) NOT NULL DEFAULT 49000.00,
    "currency" VARCHAR(3) NOT NULL DEFAULT 'VND',
    "status" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    "checkout_url" TEXT NULL,
    "payment_link_id" VARCHAR(100) NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "paid_at" TIMESTAMP(6) NULL,
    "expired_at" TIMESTAMP(6) NULL,
    CONSTRAINT "pk_payment_order" PRIMARY KEY ("id"),
    CONSTRAINT "uq_payment_order_code" UNIQUE ("order_code"),
    CONSTRAINT "fk_payment_order_account" FOREIGN KEY ("idaccount") 
        REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- 3. Tạo bảng payment_transaction (Nhật ký giao dịch đối soát Webhook PayOS)
CREATE TABLE IF NOT EXISTS "payment_transaction" (
    "id" VARCHAR(36) NOT NULL,
    "order_id" VARCHAR(36) NOT NULL,
    "idaccount" INTEGER NOT NULL,
    "payos_transaction_id" VARCHAR(100) NULL,
    "amount" DECIMAL(15, 2) NOT NULL,
    "bank_code" VARCHAR(50) NULL,
    "transaction_time" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "signature_verified" BOOLEAN NOT NULL DEFAULT TRUE,
    "raw_webhook_hash" VARCHAR(256) NULL,
    "created_at" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pk_payment_transaction" PRIMARY KEY ("id"),
    CONSTRAINT "fk_payment_transaction_order" FOREIGN KEY ("order_id") 
        REFERENCES "payment_order"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "fk_payment_transaction_account" FOREIGN KEY ("idaccount") 
        REFERENCES "account"("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- 4. Tạo các chỉ mục tối ưu hiệu năng truy vấn
CREATE INDEX IF NOT EXISTS "idx_payment_order_account" ON "payment_order"("idaccount");
CREATE INDEX IF NOT EXISTS "idx_payment_order_status" ON "payment_order"("status");
CREATE INDEX IF NOT EXISTS "idx_payment_order_code" ON "payment_order"("order_code");
CREATE INDEX IF NOT EXISTS "idx_payment_transaction_order" ON "payment_transaction"("order_id");
CREATE INDEX IF NOT EXISTS "idx_payment_transaction_account" ON "payment_transaction"("idaccount");
CREATE INDEX IF NOT EXISTS "idx_account_premium_expires" ON "account"("premium_expires_at") WHERE "premium_expires_at" IS NOT NULL;
