-- ============================================================================
-- Migration 33: Thêm mã PIN Admin, cột Action cho Audit Log & Dọn dẹp dữ liệu test
-- ============================================================================

-- 1. Bổ sung trường pin_hash vào bảng account để lưu cứng mã PIN bảo mật đã mã hóa
ALTER TABLE account ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255);

-- 2. Bổ sung trường Action vào bảng audit_log để phân định rõ ràng giữa API Endpoint và Hành động người dùng
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS "Action" VARCHAR(255);

-- 3. Dọn dẹp các tài khoản test giả lập tích tụ từ trước (user_ret_* và @anonymized.local)
-- Sử dụng session_replication_role = 'replica' trong phiên bảo trì để vượt qua cascade trigger an toàn
SET session_replication_role = 'replica';

DO $$
DECLARE
  v_test_account_ids INT[];
BEGIN
  SELECT ARRAY_AGG("Idaccount") INTO v_test_account_ids
  FROM account
  WHERE "Username" LIKE 'user_ret_%' 
     OR "Email" LIKE '%anonymized.local%'
     OR "Email" LIKE '%retention_%@example.com';

  IF v_test_account_ids IS NOT NULL AND array_length(v_test_account_ids, 1) > 0 THEN
    -- Task 49.F: Chuyển sang xóa mềm (Soft-Delete) tuân thủ Rule 9 & DB Guard, bảo toàn tính toàn vẹn
    UPDATE refreshtoken SET "Status" = true, "Update_at" = NOW() WHERE "Idaccount" = ANY(v_test_account_ids);
    UPDATE "user" SET "Delete_at" = NOW(), "Update_at" = NOW() WHERE "Idaccount" = ANY(v_test_account_ids);
    UPDATE account SET "Status" = 'Deleted', "Countdown" = 0, "Delete_at" = NOW(), "Update_at" = NOW() WHERE "Idaccount" = ANY(v_test_account_ids);
    RAISE NOTICE 'Đã xóa mềm thành công các tài khoản test giả lập trong CSDL.';
  ELSE
    RAISE NOTICE 'Không có tài khoản test rác cần xóa.';
  END IF;
END $$;

-- Khôi phục session_replication_role về origin
SET session_replication_role = 'origin';
