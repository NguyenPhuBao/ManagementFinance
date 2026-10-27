-- Migration 38: Thêm Partial Unique Index cho payos_transaction_id trên bảng payment_transaction
-- Ngăn chặn tuyệt đối tình trạng race-condition ghi đúp bản ghi đối soát khi nhận đồng thời nhiều webhook PayOS (Mục 44 vế B2)

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE tablename = 'payment_transaction' 
          AND indexname = 'uq_payment_transaction_payos_id'
    ) THEN
        CREATE UNIQUE INDEX uq_payment_transaction_payos_id 
        ON payment_transaction (payos_transaction_id) 
        WHERE payos_transaction_id IS NOT NULL;
        
        RAISE NOTICE 'Đã tạo Unique Index uq_payment_transaction_payos_id thành công.';
    ELSE
        RAISE NOTICE 'Index uq_payment_transaction_payos_id đã tồn tại.';
    END IF;
END $$;
