-- Migration 20: Thêm các cột đối soát số tiền thực nhận, mã nhận diện 6 ký tự và thông tin hoàn tiền minh bạch
-- Module: Payment (WealthCommand FinanceManagement)
-- Mục tiêu: Hỗ trợ quy trình thanh toán 6 bước PayOS, xử lý chuyển thừa/thiếu tiền và minh chứng hoàn tiền pháp lý.

-- 1. Bổ sung các cột mới vào bảng payment_order nếu chưa tồn tại
ALTER TABLE "payment_order"
ADD COLUMN IF NOT EXISTS "recognition_code" VARCHAR(10),
ADD COLUMN IF NOT EXISTS "amount_received" DECIMAL(15,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS "fee" DECIMAL(15,2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS "transfer_content" VARCHAR(100),
ADD COLUMN IF NOT EXISTS "refunded_at" TIMESTAMP(6),
ADD COLUMN IF NOT EXISTS "refunded_amount" DECIMAL(15,2),
ADD COLUMN IF NOT EXISTS "refund_reason" TEXT,
ADD COLUMN IF NOT EXISTS "refund_proof" TEXT;

-- 2. Đảm bảo ràng buộc chỉ mục hiệu năng cao cho việc tra cứu đối soát
CREATE INDEX IF NOT EXISTS "idx_payment_order_recognition_code" ON "payment_order"("recognition_code");
CREATE INDEX IF NOT EXISTS "idx_payment_order_status" ON "payment_order"("status");
