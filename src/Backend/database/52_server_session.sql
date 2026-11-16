-- Migration 52: Bảng server_session ghi các phiên chạy của tiến trình Backend.
-- Dùng để tính độ khả dụng theo kỳ (tháng / quý / năm) bền vững qua các lần khởi động lại:
--   - mỗi lần khởi động chèn một phiên; mỗi 60 giây cập nhật last_seen_at (nhịp sống);
--   - nhận SIGTERM / SIGINT: ended_at = NOW(), end_reason = 'GRACEFUL' (deploy, Render cho ngủ);
--   - phiên không kịp đóng (sập) được đóng ở lần khởi động sau: ended_at = last_seen_at, end_reason = 'UNKNOWN'.
-- Không chứa dữ liệu người dùng. Luỹ đẳng: chạy lại nhiều lần không lỗi.
-- Kế hoạch: docs/superpowers/plans/2026-11-15-bao-tri-ben-vung-va-do-kha-dung.md (mục 2.2)

CREATE TABLE IF NOT EXISTS "server_session" (
  "id"           BIGSERIAL PRIMARY KEY,
  "instance_id"  VARCHAR(100) NOT NULL,
  "version"      VARCHAR(64)  NULL,
  "started_at"   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  "last_seen_at" TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  "ended_at"     TIMESTAMPTZ  NULL,
  "end_reason"   VARCHAR(20)  NULL,
  CONSTRAINT "ck_server_session_end_reason" CHECK ("end_reason" IS NULL OR "end_reason" IN ('GRACEFUL', 'UNKNOWN'))
);

CREATE INDEX IF NOT EXISTS "idx_server_session_started_at" ON "server_session" ("started_at");
CREATE INDEX IF NOT EXISTS "idx_server_session_open" ON "server_session" ("last_seen_at") WHERE "ended_at" IS NULL;

COMMENT ON TABLE "server_session" IS 'Phiên chạy của tiến trình Backend, phục vụ tính độ khả dụng theo kỳ';
COMMENT ON COLUMN "server_session"."end_reason" IS 'GRACEFUL: tắt có chủ đích (SIGTERM/SIGINT); UNKNOWN: không kịp đóng (sập), đóng ở lần khởi động sau';
