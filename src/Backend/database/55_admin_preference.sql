-- Migration 55: Bảng admin_preference lưu cài đặt cá nhân của từng tài khoản quản trị (Admin-web, 2026-11-16).
-- Trước đây cài đặt nằm chung một khoá localStorage của trình duyệt: nhiều admin trên cùng trình duyệt dùng chung,
-- sang máy khác thì mất. Nay mỗi tài khoản một dòng, đăng nhập ở đâu cũng dùng đúng cài đặt của mình.
-- Phạm vi: 7 cài đặt của hộp Cài đặt (giao diện, thông báo, kết nối, tự khoá); kiểm khoá và giá trị ở Backend.
-- Chỉ thêm bảng mới, không đổi bảng account; không đi qua /sync/*, Client-app không bị ảnh hưởng.
-- Luỹ đẳng: chạy lại nhiều lần không lỗi.

CREATE TABLE IF NOT EXISTS "admin_preference" (
  "idaccount"  INTEGER     PRIMARY KEY,
  "settings"   JSONB       NOT NULL DEFAULT '{}'::jsonb,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "fk_admin_preference_account" FOREIGN KEY ("idaccount") REFERENCES "account" ("Idaccount") ON DELETE CASCADE,
  CONSTRAINT "ck_admin_preference_settings_object" CHECK (jsonb_typeof("settings") = 'object')
);

COMMENT ON TABLE "admin_preference" IS 'Cài đặt cá nhân của từng tài khoản quản trị trên Admin-web (giao diện, thông báo, kết nối, tự khoá)';
COMMENT ON COLUMN "admin_preference"."settings" IS 'Chỉ các khoá Backend cho phép: theme, tableDensity, soundEnabled, toastDuration, showUnreadBadge, metricsInterval, autoLockMinutes';
