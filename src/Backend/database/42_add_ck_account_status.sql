-- Migration 42: Bổ sung Check Constraint cho trường Status trên bảng account
-- Đảm bảo chỉ 4 trạng thái hợp lệ: Active, Inactive, PendingDelete, Deleted (Task 43.A5)

DO $$
BEGIN
    -- 1. Xóa constraint cũ nếu đã tồn tại để tránh xung đột
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ck_account_status'
    ) THEN
        ALTER TABLE "account" DROP CONSTRAINT "ck_account_status";
    END IF;

    -- 2. Thêm Check constraint mới
    ALTER TABLE "account"
    ADD CONSTRAINT "ck_account_status"
    CHECK ("Status" IN ('Active', 'Inactive', 'PendingDelete', 'Deleted'));

    RAISE NOTICE 'Đã áp dụng check constraint ck_account_status thành công.';
END $$;

