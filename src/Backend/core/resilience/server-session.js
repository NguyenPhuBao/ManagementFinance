/**
 * Ghi phiên chạy của tiến trình Backend vào bảng server_session (migration 52).
 * Dùng để tính độ khả dụng theo kỳ, bền vững qua các lần khởi động lại.
 *
 *  - start(): đóng phiên treo của lần chạy trước (không đóng kịp = sập) thành UNKNOWN, chèn phiên mới, bật nhịp sống.
 *  - heartbeat(): cập nhật last_seen_at (mặc định mỗi 60 giây). Sập giữa hai nhịp mất tối đa một chu kỳ số liệu.
 *  - stop(): gọi khi nhận SIGTERM / SIGINT, đóng phiên GRACEFUL (tắt có chủ đích: deploy, Render cho ngủ).
 * Lỗi CSDL không làm sập tiến trình; start() lỗi thì thử lại sau `retryMs`.
 */

const os = require('os');
const logger = require('../logger');

const STALE_MS = 3 * 60 * 1000; // phiên không có nhịp quá 3 phút coi là đã chết (không đóng phiên máy khác còn sống)

class ServerSessionTracker {
  constructor({
    pool,
    instanceId = process.env.RENDER_INSTANCE_ID || os.hostname(),
    version = process.env.RENDER_GIT_COMMIT || null,
    now = () => new Date(),
    heartbeatMs = 60 * 1000,
    retryMs = 30 * 1000,
  } = {}) {
    this.pool = pool;
    this.instanceId = String(instanceId).slice(0, 100);
    this.version = version ? String(version).slice(0, 12) : null;
    this.now = now;
    this.heartbeatMs = heartbeatMs;
    this.retryMs = retryMs;
    this.sessionId = null;
    this.startedAt = null;
    this._heartbeatTimer = null;
    this._retryTimer = null;
  }

  async start() {
    try {
      const staleBefore = new Date(this.now().getTime() - STALE_MS).toISOString();
      // Phiên mở của máy khác chỉ đóng khi mất nhịp quá STALE_MS (có thể còn sống);
      // phiên mở của CHÍNH máy này đóng ngay: tiến trình mới chạy nghĩa là tiến trình cũ đã chết.
      await this.pool.query(
        `UPDATE "server_session" SET "ended_at" = "last_seen_at", "end_reason" = 'UNKNOWN'
         WHERE "ended_at" IS NULL AND ("last_seen_at" < $1 OR "instance_id" = $2)`,
        [staleBefore, this.instanceId]
      );
      const res = await this.pool.query(
        `INSERT INTO "server_session" ("instance_id", "version") VALUES ($1, $2) RETURNING "id", "started_at"`,
        [this.instanceId, this.version]
      );
      this.sessionId = res.rows[0].id;
      this.startedAt = res.rows[0].started_at;
      this._heartbeatTimer = setInterval(() => { this.heartbeat(); }, this.heartbeatMs);
      if (typeof this._heartbeatTimer.unref === 'function') this._heartbeatTimer.unref();
      logger.info('[ServerSession] Đã ghi phiên chạy', { id: String(this.sessionId), version: this.version });
    } catch (err) {
      logger.warn('[ServerSession] Chưa ghi được phiên chạy, sẽ thử lại', { error: err.message });
      this._retryTimer = setTimeout(() => { this._retryTimer = null; this.start(); }, this.retryMs);
      if (typeof this._retryTimer.unref === 'function') this._retryTimer.unref();
    }
  }

  async heartbeat() {
    if (!this.sessionId) return;
    try {
      await this.pool.query(`UPDATE "server_session" SET "last_seen_at" = NOW() WHERE "id" = $1`, [this.sessionId]);
    } catch (err) {
      logger.warn('[ServerSession] Lỗi ghi nhịp sống', { error: err.message });
    }
  }

  async stop() {
    this.stopHeartbeat();
    if (!this.sessionId) return;
    try {
      await this.pool.query(
        `UPDATE "server_session" SET "ended_at" = NOW(), "last_seen_at" = NOW(), "end_reason" = 'GRACEFUL' WHERE "id" = $1`,
        [this.sessionId]
      );
    } catch (err) {
      logger.warn('[ServerSession] Lỗi đóng phiên khi tắt', { error: err.message });
    }
  }

  stopHeartbeat() {
    if (this._heartbeatTimer) clearInterval(this._heartbeatTimer);
    if (this._retryTimer) clearTimeout(this._retryTimer);
    this._heartbeatTimer = null;
    this._retryTimer = null;
  }

  getInfo() {
    return { instanceId: this.instanceId, version: this.version, sessionId: this.sessionId };
  }
}

let defaultTracker = null;
function getDefaultServerSession() {
  if (!defaultTracker) {
    const { pool } = require('../../config/db');
    defaultTracker = new ServerSessionTracker({ pool });
  }
  return defaultTracker;
}

module.exports = { ServerSessionTracker, getDefaultServerSession, STALE_MS };
