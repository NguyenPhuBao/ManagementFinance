-- Migration 25: Tạo bảng maintenance_history lưu trữ lịch sử các phiên bảo trì hệ thống
-- Tuân thủ Rule 10 DB Guard: Chạy DDL IF NOT EXISTS an toàn

CREATE TABLE IF NOT EXISTS "maintenance_history" (
  "id" SERIAL PRIMARY KEY,
  "type" VARCHAR(20) NOT NULL DEFAULT 'EMERGENCY',     -- 'EMERGENCY' (Khẩn cấp) | 'SCHEDULED' (Theo lịch)
  "reason" TEXT NOT NULL,                              -- Lý do / Thông điệp gửi tới người dùng
  "activated_by" VARCHAR(100) NOT NULL,                 -- Username / Email / Tên Admin kích hoạt
  "started_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  "scheduled_end_at" TIMESTAMP WITH TIME ZONE NULL,     -- Thời điểm dự kiến kết thúc (nếu theo lịch)
  "ended_at" TIMESTAMP WITH TIME ZONE NULL,            -- Thời điểm kết thúc thực tế
  "status" VARCHAR(20) NOT NULL DEFAULT 'ONGOING',      -- 'ONGOING' | 'COMPLETED' | 'CANCELLED'
  "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes tối ưu truy vấn danh sách lịch sử theo thời gian và trạng thái
CREATE INDEX IF NOT EXISTS "idx_maintenance_history_started_at" ON "maintenance_history" ("started_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_maintenance_history_status" ON "maintenance_history" ("status");
CREATE INDEX IF NOT EXISTS "idx_maintenance_history_type" ON "maintenance_history" ("type");
