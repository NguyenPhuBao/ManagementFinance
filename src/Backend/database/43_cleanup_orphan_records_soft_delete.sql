-- ============================================================================
-- Migration 43: Xử lý các bản ghi mồ côi còn sót trên Supabase bằng XÓA MỀM (Soft-Delete)
-- Nguồn sự thật: docs/superpowers/backend/CAN-LAM/VIEC_BACKEND_CON_LAI.md (Task 49.F)
-- Không xóa cứng, bảo toàn tính toàn vẹn CSDL và tuân thủ Rule 9 & Rule 10.
-- ============================================================================

DO $$
DECLARE
  v_orphan_wallets INT;
  v_orphan_transactions INT;
  v_orphan_categories INT;
BEGIN
  -- 1. Xóa mềm các ví mồ côi (không còn account sở hữu)
  UPDATE wallet
  SET "Delete_at" = NOW(), "Status" = 'Inactive', "Update_at" = NOW()
  WHERE "Delete_at" IS NULL
    AND "Idaccount" NOT IN (SELECT "Idaccount" FROM account);
  GET DIAGNOSTICS v_orphan_wallets = ROW_COUNT;

  -- 2. Xóa mềm các giao dịch mồ côi (bảng transaction dùng Deleted_at)
  UPDATE transaction
  SET "Deleted_at" = NOW(), "Update_at" = NOW()
  WHERE "Deleted_at" IS NULL
    AND "Idaccount" NOT IN (SELECT "Idaccount" FROM account);
  GET DIAGNOSTICS v_orphan_transactions = ROW_COUNT;

  -- 3. Xóa mềm các danh mục mồ côi (không phải mặc định)
  UPDATE category
  SET "Delete_at" = NOW(), "Update_at" = NOW()
  WHERE "Delete_at" IS NULL
    AND "Is_default" = false
    AND "Create_by" NOT IN (SELECT "Idaccount" FROM account);
  GET DIAGNOSTICS v_orphan_categories = ROW_COUNT;

  RAISE NOTICE 'Đã xóa mềm mồ côi: % ví, % giao dịch, % danh mục.', v_orphan_wallets, v_orphan_transactions, v_orphan_categories;
END $$;

