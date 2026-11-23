/**
 * Tầng 2 trên CSDL thử thật (TEST_DATABASE_URL trỏ máy này, vd. flowmoney_adminweb).
 * Kế hoạch 2026-11-15: B19 (bảng server_session đúng cột, ràng buộc), B9 (đóng phiên treo, giữ phiên còn sống),
 * và hai hàm khôi phục bảo trì của repository (loadRestoreState, closeRecord) chạy SQL thật.
 * Chỉ tạo / xoá bản ghi có nhãn thử (instance 'it-ss-*', lý do 'IT-RESTORE *').
 */

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { pool } = require('../../config/db');
const { ServerSessionTracker } = require('../../core/resilience/server-session');
const { MaintenanceRepository } = require('../../modules/admin/maintenance.repository');

async function cleanup() {
  await pool.query(`DELETE FROM "server_session" WHERE "instance_id" LIKE 'it-ss-%'`).catch(() => {});
  await pool.query(`DELETE FROM "maintenance_history" WHERE "reason" LIKE 'IT-RESTORE %'`).catch(() => {});
}

describe('server_session + khôi phục bảo trì trên CSDL thử', () => {
  before(async () => {
    const db = (await pool.query('SELECT current_database() AS d')).rows[0].d;
    assert.doesNotMatch(db, /^postgres$/i);
    await cleanup();
  });
  after(async () => { await cleanup(); });

  it('B19. Bảng server_session đúng cột và ràng buộc', async () => {
    const cols = (await pool.query(
      `SELECT column_name FROM information_schema.columns WHERE table_name = 'server_session' ORDER BY ordinal_position`
    )).rows.map((r) => r.column_name);
    assert.deepEqual(cols, ['id', 'instance_id', 'version', 'started_at', 'last_seen_at', 'ended_at', 'end_reason']);
    await assert.rejects(
      pool.query(`INSERT INTO "server_session" ("instance_id", "end_reason") VALUES ('it-ss-bad', 'CRASH')`),
      /ck_server_session_end_reason/
    );
  });

  it('B9. Khởi động đóng phiên treo thành UNKNOWN tại last_seen_at; phiên máy khác còn sống giữ nguyên; tắt thì GRACEFUL', async () => {
    const stale = (await pool.query(
      `INSERT INTO "server_session" ("instance_id", "started_at", "last_seen_at")
       VALUES ('it-ss-old', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '1 hour') RETURNING "id", "last_seen_at"`
    )).rows[0];
    const alive = (await pool.query(
      `INSERT INTO "server_session" ("instance_id", "started_at", "last_seen_at")
       VALUES ('it-ss-alive', NOW() - INTERVAL '1 hour', NOW() - INTERVAL '30 seconds') RETURNING "id"`
    )).rows[0];

    // Tiến trình cũ trên CHÍNH máy này, nhịp cuối mới 20 giây (bị dừng cứng rồi khởi động lại ngay)
    const sameHost = (await pool.query(
      `INSERT INTO "server_session" ("instance_id", "started_at", "last_seen_at")
       VALUES ('it-ss-new', NOW() - INTERVAL '10 minutes', NOW() - INTERVAL '20 seconds') RETURNING "id", "last_seen_at"`
    )).rows[0];

    const tracker = new ServerSessionTracker({ pool, instanceId: 'it-ss-new', version: 'v-it', heartbeatMs: 60000 });
    await tracker.start();
    try {
      const rows = (await pool.query(
        `SELECT "id", "instance_id", "ended_at", "end_reason", "last_seen_at" FROM "server_session" WHERE "instance_id" LIKE 'it-ss-%'`
      )).rows;
      const old = rows.find((r) => r.id === stale.id);
      assert.equal(old.end_reason, 'UNKNOWN');
      assert.equal(new Date(old.ended_at).getTime(), new Date(stale.last_seen_at).getTime());
      const liveRow = rows.find((r) => r.id === alive.id);
      assert.equal(liveRow.ended_at, null, 'phiên còn sống của máy khác không bị đóng');
      const prev = rows.find((r) => r.id === sameHost.id);
      assert.equal(prev.end_reason, 'UNKNOWN', 'phiên cũ của chính máy này đóng ngay dù nhịp còn mới');
      assert.equal(new Date(prev.ended_at).getTime(), new Date(sameHost.last_seen_at).getTime());
      const mine = rows.find((r) => r.id === tracker.sessionId);
      assert.ok(mine && mine.ended_at === null);

      await tracker.stop();
      const closed = (await pool.query(`SELECT "ended_at", "end_reason" FROM "server_session" WHERE "id" = $1`, [tracker.sessionId])).rows[0];
      assert.equal(closed.end_reason, 'GRACEFUL');
      assert.ok(closed.ended_at);
    } finally {
      tracker.stopHeartbeat();
    }
  });

  it('loadRestoreState đọc ONGOING (mới nhất trước) và SCHEDULED; closeRecord đóng kèm thời lượng', async () => {
    const repo = new MaintenanceRepository({ pool });
    const ins = async (status, reason, startedSql, endSql = 'NULL') => (await pool.query(
      `INSERT INTO "maintenance_history" ("type", "reason", "activated_by", "started_at", "scheduled_end_at", "status")
       VALUES ('EMERGENCY', $1, 'it', ${startedSql}, ${endSql}, $2) RETURNING "id"`, [reason, status]
    )).rows[0].id;
    const older = await ins('ONGOING', 'IT-RESTORE old', `NOW() - INTERVAL '2 hours'`);
    const newer = await ins('ONGOING', 'IT-RESTORE new', `NOW() - INTERVAL '10 minutes'`);
    const sched = await ins('SCHEDULED', 'IT-RESTORE sched', `NOW() + INTERVAL '5 hours'`, `NOW() + INTERVAL '6 hours'`);

    const state = await repo.loadRestoreState();
    const ongoingIds = state.ongoing.map((r) => r.id);
    assert.ok(ongoingIds.indexOf(newer) < ongoingIds.indexOf(older), 'ONGOING mới nhất đứng trước');
    assert.ok(state.scheduled.some((r) => r.id === sched));

    const endAt = new Date(Date.now() - 60 * 60 * 1000);
    const row = await repo.closeRecord(older, { status: 'COMPLETED', ended_at: endAt });
    assert.equal(row.status, 'COMPLETED');
    assert.equal(new Date(row.ended_at).getTime(), endAt.getTime());
    assert.ok(Math.abs(row.actual_duration_seconds - 3600) <= 2, `thời lượng ~3600 giây, có ${row.actual_duration_seconds}`);
  });

  it('getAvailability đọc SQL thật: tắt có chủ đích, sập, bảo trì khẩn cấp trong tháng 01/2001', async () => {
    const { getAvailability } = require('../../modules/admin/availability.service');
    const s = async (start, end, reason) => pool.query(
      `INSERT INTO "server_session" ("instance_id", "started_at", "last_seen_at", "ended_at", "end_reason")
       VALUES ('it-ss-avail', $1, $2, $2, $3)`, [start, end, reason]
    );
    await s('2001-01-01T00:00:00+07:00', '2001-01-10T00:00:00+07:00', 'GRACEFUL');
    await s('2001-01-10T01:00:00+07:00', '2001-01-20T00:00:00+07:00', 'UNKNOWN');
    await s('2001-01-20T02:00:00+07:00', '2001-02-01T00:00:00+07:00', 'GRACEFUL');
    await pool.query(
      `INSERT INTO "maintenance_history" ("type", "reason", "activated_by", "started_at", "ended_at", "status")
       VALUES ('EMERGENCY', 'IT-RESTORE avail', 'it', '2001-01-05T00:00:00+07:00', '2001-01-05T00:30:00+07:00', 'COMPLETED')`
    );

    const r = await getAvailability({ period: 'month', year: '2001', month: '1' }, { pool, now: new Date('2001-03-01T00:00:00Z') });
    const measured = 31 * 24 * 3600;
    assert.equal(r.trackingAvailable, true);
    assert.equal(r.measuredSeconds, measured);
    assert.equal(r.plannedStopSeconds, 3600);
    assert.equal(r.unplannedSeconds, 7200);
    assert.equal(r.emergencyMaintenanceSeconds, 1800);
    assert.equal(r.percent, Number((((measured - 9000) / measured) * 100).toFixed(2)));
    assert.equal(r.buckets.length, 31);
    assert.equal(r.buckets[19].percent, Number((((24 * 3600 - 7200) / (24 * 3600)) * 100).toFixed(2)), 'ngày 20: sập 2 giờ');
    assert.ok(r.availableYears.includes(2001));
  });

  it('loadRestoreState ném lỗi khi CSDL lỗi (không rơi về bộ nhớ)', async () => {
    const repo = new MaintenanceRepository({ pool: { query: async () => { throw new Error('down'); } } });
    await assert.rejects(repo.loadRestoreState(), /down/);
  });
});
