-- ============================================================================
-- Migration 34: Thêm cờ is_first_login và trường created_by_admin_id cho tài khoản Admin
-- ============================================================================

-- 1. Bổ sung cờ is_first_login vào bảng account
ALTER TABLE account ADD COLUMN IF NOT EXISTS is_first_login BOOLEAN NOT NULL DEFAULT TRUE;

-- 2. Bổ sung trường created_by_admin_id để quản lý ai là người cấp tài khoản admin
ALTER TABLE account ADD COLUMN IF NOT EXISTS created_by_admin_id INT;

-- 3. Ràng buộc khóa ngoại an toàn
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_account_created_by_admin'
  ) THEN
    ALTER TABLE account 
    ADD CONSTRAINT fk_account_created_by_admin 
    FOREIGN KEY (created_by_admin_id) REFERENCES account("Idaccount") ON DELETE SET NULL;
  END IF;
END $$;

-- 4. Khởi tạo is_first_login = FALSE cho tài khoản Admin hiện có (theo lựa chọn của PO)
UPDATE account 
SET is_first_login = FALSE 
WHERE "Idrole" = (SELECT "Idrole" FROM role WHERE "Rolename" = 'Admin' LIMIT 1)
   OR "Username" = 'admin'
   OR "Email" = 'phubaonguyen1802@gmail.com';
