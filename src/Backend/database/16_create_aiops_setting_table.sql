-- ==============================================================================
-- Migration 16: Tạo bảng aiops_setting lưu trữ cấu hình hệ thống AIOps Sentinel
-- Mục đích: Lưu cứng giá trị "Số người dùng đồng thời" (Target Concurrency)
-- Đảm bảo không bị thay đổi khi load lại trang hay server khởi động lại.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS "aiops_setting" (
  "key" VARCHAR(64) PRIMARY KEY,
  "value" TEXT NOT NULL,
  "updated_at" TIMESTAMP(6) NOT NULL DEFAULT NOW()
);

-- Khởi tạo giá trị mặc định chuẩn: target_concurrency = 1000 (1,000 Người dùng Chuẩn)
INSERT INTO "aiops_setting" ("key", "value", "updated_at")
VALUES ('target_concurrency', '1000', NOW())
ON CONFLICT ("key") DO UPDATE SET "value" = '1000', "updated_at" = NOW();
