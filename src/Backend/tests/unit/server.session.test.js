/**
 * Ghi phiên chạy của máy chủ (kế hoạch 2026-11-15, mục 2.2; B8, B9).
 * Tầng 1: vòng đời bộ ghi (khởi động, nhịp sống, tắt) không ném lỗi khi CSDL lỗi.
 * Tầng 2: câu lệnh ghi vào bảng server_session đúng tham số (đóng phiên treo, chèn, nhịp sống, GRACEFUL).
 * Phần SQL chạy thật trên CSDL thử: tests/integration/server.session.db.integration.test.js.
 */

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert');
const { ServerSessionTracker } = require('../../core/resilience/server-session');

function fakePool({ fail = false } = {}) {
  const queries = [];
  return {
    queries,
    async query(sql, params = []) {
      queries.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      if (fail) throw new Error('Simulated DB outage');
      if (/INSERT INTO "server_session"/.test(sql)) return { rows: [{ id: 42, started_at: new Date().toISOString() }] };
      return { rows: [], rowCount: 1 };
    },
  };
}

describe('ServerSessionTracker', () => {
  let tracker;
  afterEach(() => { if (tracker) tracker.stopHeartbeat(); });

  it('B8a. start: đóng phiên treo quá 3 phút thành UNKNOWN rồi chèn phiên mới với instance và phiên bản', async () => {
    const pool = fakePool();
    const now = new Date('2026-11-15T10:00:00.000Z');
    tracker = new ServerSessionTracker({ pool, instanceId: 'srv-a', version: 'abc123def4567890', now: () => now, heartbeatMs: 60000 });

    await tracker.start();

    const [closeQ, insertQ] = pool.queries;
    assert.match(closeQ.sql, /UPDATE "server_session" SET "ended_at" = "last_seen_at", "end_reason" = 'UNKNOWN'/);
    // Phiên treo của máy khác (quá 3 phút không nhịp) hoặc phiên cũ của CHÍNH máy này (tiến trình cũ đã chết)
    assert.match(closeQ.sql, /"ended_at" IS NULL AND \("last_seen_at" < \$1 OR "instance_id" = \$2\)/);
    assert.strictEqual(new Date(closeQ.params[0]).getTime(), now.getTime() - 3 * 60 * 1000);
    assert.strictEqual(closeQ.params[1], 'srv-a');
    assert.match(insertQ.sql, /INSERT INTO "server_session"/);
    assert.deepStrictEqual(insertQ.params, ['srv-a', 'abc123def456']);
    assert.strictEqual(tracker.sessionId, 42);
    assert.strictEqual(tracker.getInfo().version, 'abc123def456');
  });

  it('B8b. heartbeat cập nhật last_seen_at của đúng phiên', async () => {
    const pool = fakePool();
    tracker = new ServerSessionTracker({ pool, instanceId: 'srv-a', heartbeatMs: 60000 });
    await tracker.start();
    pool.queries.length = 0;

    await tracker.heartbeat();

    assert.strictEqual(pool.queries.length, 1);
    assert.match(pool.queries[0].sql, /UPDATE "server_session" SET "last_seen_at" = NOW\(\) WHERE "id" = \$1/);
    assert.deepStrictEqual(pool.queries[0].params, [42]);
  });

  it('B8c. stop (SIGTERM/SIGINT) đóng phiên GRACEFUL và dừng nhịp sống', async () => {
    const pool = fakePool();
    tracker = new ServerSessionTracker({ pool, instanceId: 'srv-a', heartbeatMs: 60000 });
    await tracker.start();
    pool.queries.length = 0;

    await tracker.stop();

    assert.match(pool.queries[0].sql, /SET "ended_at" = NOW\(\), "last_seen_at" = NOW\(\), "end_reason" = 'GRACEFUL' WHERE "id" = \$1/);
    assert.deepStrictEqual(pool.queries[0].params, [42]);
    assert.strictEqual(tracker._heartbeatTimer, null);
  });

  it('B8d. Nhịp sống chạy theo chu kỳ', async () => {
    const pool = fakePool();
    tracker = new ServerSessionTracker({ pool, instanceId: 'srv-a', heartbeatMs: 20 });
    await tracker.start();
    await new Promise((r) => setTimeout(r, 75));
    const beats = pool.queries.filter((q) => /SET "last_seen_at" = NOW\(\) WHERE/.test(q.sql)).length;
    assert.ok(beats >= 2, `phải có ít nhất 2 nhịp, có ${beats}`);
  });

  it('B8e. CSDL lỗi: start / heartbeat / stop không ném lỗi', async () => {
    tracker = new ServerSessionTracker({ pool: fakePool({ fail: true }), instanceId: 'srv-a', heartbeatMs: 60000 });
    await assert.doesNotReject(tracker.start());
    assert.strictEqual(tracker.sessionId, null);
    await assert.doesNotReject(tracker.heartbeat());
    await assert.doesNotReject(tracker.stop());
  });

  it('B8f. Không có phiên bản → version null; instance mặc định là hostname', async () => {
    const pool = fakePool();
    tracker = new ServerSessionTracker({ pool, heartbeatMs: 60000 });
    await tracker.start();
    const insertQ = pool.queries.find((q) => /INSERT/.test(q.sql));
    assert.strictEqual(insertQ.params[1], null);
    assert.strictEqual(insertQ.params[0], require('os').hostname());
  });
});
