-- Migration 7: Update Account & User Unique Indexes for Soft-Delete & Registration Rules
-- Author: Antigravity
-- Date: 2026-09-07
-- Description:
-- 1. Chuyển account_Email_key và user_Email_key thành Partial Unique Index lọc WHERE "Delete_at" IS NULL
--    -> Cho phép tạo lại tài khoản mới với email và số điện thoại trùng sau khi tài khoản cũ đã bị xóa mềm.
-- 2. Chuyển account_Username_key từ UNIQUE đơn lẻ thành INDEX thông thường
--    -> Cho phép trùng Username nếu Password khác nhau (ràng buộc cặp Username + Password được kiểm soát tại tầng ứng dụng với bcrypt).

-- 1. Xử lý Email trên bảng account
DROP INDEX IF EXISTS public."account_Email_key";
CREATE UNIQUE INDEX "account_Email_key" ON public.account USING btree ("Email") WHERE ("Delete_at" IS NULL);

-- 2. Xử lý Email trên bảng user
DROP INDEX IF EXISTS public."user_Email_key";
CREATE UNIQUE INDEX "user_Email_key" ON public."user" USING btree ("Email") WHERE ("Delete_at" IS NULL);

-- 3. Xử lý Username trên bảng account
DROP INDEX IF EXISTS public."account_Username_key";
DROP INDEX IF EXISTS public."idx_account_username";
CREATE INDEX "idx_account_username" ON public.account USING btree ("Username");

-- 4. Mở rộng độ dài cột Status của bảng wallet từ VARCHAR(7) lên VARCHAR(20) để chứa 'Inactive'
ALTER TABLE public.wallet ALTER COLUMN "Status" TYPE VARCHAR(20);
