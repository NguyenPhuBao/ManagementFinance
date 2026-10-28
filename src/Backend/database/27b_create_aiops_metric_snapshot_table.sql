-- ==============================================================================
-- Migration 27b: Tạo bảng aiops_metric_snapshot lưu trữ định kỳ các mẫu đo lường AIOps
-- Tuân thủ: Phương án A đã được PO phê duyệt, lưu trữ mẫu định kỳ (mỗi 5 phút)
-- phục vụ hiển thị biểu đồ xu hướng 4 Vector cho các khung 24h, 7 ngày, 1 tháng
-- ==============================================================================

CREATE TABLE IF NOT EXISTS "aiops_metric_snapshot" (
  "id" VARCHAR(64) PRIMARY KEY,
  "threat_score" INT NOT NULL DEFAULT 0,
  "auth_score" INT NOT NULL DEFAULT 0,
  "traffic_score" INT NOT NULL DEFAULT 0,
  "exploit_score" INT NOT NULL DEFAULT 0,
  "resource_score" INT NOT NULL DEFAULT 0,
  "requests_per_min" INT NOT NULL DEFAULT 0,
  "cpu_percent" INT NOT NULL DEFAULT 0,
  "ram_percent" INT NOT NULL DEFAULT 0,
  "event_loop_lag_ms" INT NOT NULL DEFAULT 0,
  "is_anomaly" BOOLEAN NOT NULL DEFAULT FALSE,
  "recorded_at" TIMESTAMP(6) NOT NULL DEFAULT NOW()
);

-- Chỉ mục tối ưu hóa tốc độ truy vấn phạm vi thời gian (Range Query)
CREATE INDEX IF NOT EXISTS "idx_aiops_metric_snapshot_recorded_at" ON "aiops_metric_snapshot"("recorded_at" DESC);
