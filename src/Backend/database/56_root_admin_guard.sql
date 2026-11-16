-- Migration 56: Bảo vệ tài khoản quản trị gốc bằng trigger (Chủ dự án chốt 2026-11-16).
-- Tài khoản gốc được nhận diện bằng email cố định 'admin@wealthcommand.com' (trùng ROOT_ADMIN_EMAIL trong
-- src/Backend/modules/auth/root-admin.js). Không thêm cột vào bảng account; Client-app không bị ảnh hưởng.
-- Trigger chặn:
--   - xoá vật lý tài khoản gốc;
--   - đổi Email, Username, Idrole của tài khoản gốc;
--   - đưa tài khoản gốc khỏi trạng thái Active hoặc đặt Delete_at (khoá, chờ xoá, xoá mềm);
--   - tạo mới / đổi một tài khoản sang email gốc mà không phải vai quản trị (Idrole = 1), để người dùng thường
--     không chiếm trước email này.
-- Vẫn cho đổi mật khẩu, PIN, Is_first_login, Update_at.
-- Đổi email tài khoản gốc phải có migration mới (sửa cả hằng số trong root-admin.js).
-- Luỹ đẳng: chạy lại nhiều lần không lỗi.

CREATE OR REPLACE FUNCTION "fn_protect_root_admin"() RETURNS trigger AS $$
DECLARE
  root_email CONSTANT TEXT := 'admin@wealthcommand.com';
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF lower(OLD."Email") = root_email THEN
      RAISE EXCEPTION 'ROOT_ACCOUNT_PROTECTED: không được xóa tài khoản quản trị gốc' USING ERRCODE = 'P0001';
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' AND lower(OLD."Email") = root_email THEN
    IF NEW."Email" IS DISTINCT FROM OLD."Email"
       OR NEW."Username" IS DISTINCT FROM OLD."Username"
       OR NEW."Idrole" IS DISTINCT FROM OLD."Idrole"
       OR NEW."Status" IS DISTINCT FROM 'Active'
       OR NEW."Delete_at" IS NOT NULL THEN
      RAISE EXCEPTION 'ROOT_ACCOUNT_PROTECTED: không được khóa, xóa hoặc đổi định danh / vai của tài khoản quản trị gốc' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF lower(NEW."Email") = root_email AND NEW."Idrole" IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'ROOT_ACCOUNT_PROTECTED: email này dành riêng cho tài khoản quản trị gốc' USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS "trg_protect_root_admin" ON "account";
CREATE TRIGGER "trg_protect_root_admin"
  BEFORE INSERT OR UPDATE OR DELETE ON "account"
  FOR EACH ROW EXECUTE FUNCTION "fn_protect_root_admin"();

COMMENT ON FUNCTION "fn_protect_root_admin"() IS 'Bảo vệ tài khoản quản trị gốc (email admin@wealthcommand.com): không xóa, không khóa, không đổi định danh / vai';
