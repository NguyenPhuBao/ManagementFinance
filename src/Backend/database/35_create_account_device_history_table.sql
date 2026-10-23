-- ============================================================================
-- Migration 35: Tạo bảng account_device_history lưu vết thiết bị & IP người dùng
-- Mục đích: Ghi nhận lịch sử Tên thiết bị và Địa chỉ IP mỗi lần người dùng đăng nhập
-- hoặc truy cập app. Nếu IP hoặc Thiết bị thay đổi thì INSERT dòng mới (không ghi đè).
-- Tuân thủ: Luật An toàn thông tin mạng 2015, Nghị định 13/2023/NĐ-CP, Rule 9 & 10.
-- Ngày tạo: 2026-10-23
-- ============================================================================

-- 1. Tạo bảng account_device_history
CREATE TABLE IF NOT EXISTS "account_device_history" (
  "id" BIGSERIAL PRIMARY KEY,
  "idaccount" INT NOT NULL,
  "device_name" VARCHAR(150) NOT NULL,
  "ip_address" VARCHAR(256) NOT NULL,
  "user_agent" TEXT,
  "first_seen_at" TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  "last_active_at" TIMESTAMP(6) NOT NULL DEFAULT (now() AT TIME ZONE 'UTC'),
  CONSTRAINT "fk_device_history_account" FOREIGN KEY ("idaccount") 
    REFERENCES "account" ("Idaccount") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- 2. Đặt comment mô tả nghiệp vụ cho bảng và các cột
COMMENT ON TABLE "account_device_history" IS 'Bảng lưu vết lịch sử thiết bị và địa chỉ IP người dùng đăng nhập/truy cập (Append-only khi có thay đổi)';
COMMENT ON COLUMN "account_device_history"."device_name" IS 'Tên thiết bị người dùng (ví dụ: Samsung Galaxy S24, iPhone 15 Pro, Web Desktop)';
COMMENT ON COLUMN "account_device_history"."ip_address" IS 'Địa chỉ IP kết nối đã được che mờ (Masked IP: a.b.xx.xx) tuân thủ Nghị định 13/2023/NĐ-CP';
COMMENT ON COLUMN "account_device_history"."first_seen_at" IS 'Thời điểm phát hiện lần đầu tiên thiết bị/IP này truy cập';
COMMENT ON COLUMN "account_device_history"."last_active_at" IS 'Thời điểm gần nhất thiết bị/IP này gửi yêu cầu';

-- 3. Tạo chỉ mục tối ưu hóa truy vấn đối soát
CREATE INDEX IF NOT EXISTS "idx_device_history_account" ON "account_device_history" ("idaccount", "last_active_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_device_history_ip" ON "account_device_history" ("ip_address");
