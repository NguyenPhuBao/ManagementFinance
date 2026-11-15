/**
 * Khôi phục bảo trì từ CSDL khi khởi động (kế hoạch 2026-11-15, mục 2.1; Q1, Q7).
 * CSDL là nguồn sự thật: deploy / khởi động lại giữa phiên bảo trì không làm mất bảo trì,
 * lịch hẹn được nạp lại; chưa đọc được CSDL thì khoá người dùng (fail-closed).
 *
 * Tầng 1: trạng thái RAM của MaintenanceManager và phản hồi của middleware.
 * Tầng 2: tác động lên CSDL (bản ghi đóng / huỷ / không tạo mới), thông báo đẩy, sự kiện socket.
 */

const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const { MaintenanceManager } = require('../../core/resilience/maintenance.manager');
const { createMaintenanceMiddleware } = require('../../middleware/maintenance.middleware');

const MIN = 60 * 1000;
const iso = (ms) => new Date(ms).toISOString();

function makeRepo({ ongoing = [], scheduled = [], failTimes = 0 } = {}) {
  const calls = { load: 0, create: [], close: [], cancel: [], updateStatus: [], complete: [] };
  const repo = {
    calls,
    async loadRestoreState() {
      calls.load += 1;
      if (calls.load <= failTimes) throw new Error('Simulated DB outage');
      return { ongoing: ongoing.map((r) => ({ ...r })), scheduled: scheduled.map((r) => ({ ...r })) };
    },
    async closeRecord(id, payload) { calls.close.push({ id, ...payload }); return { id }; },
    async cancelScheduledRecord(payload) { calls.cancel.push(payload); return { id: payload.id }; },
    async updateRecordStatus(id, payload) { calls.updateStatus.push({ id, ...payload }); return { id }; },
    async createRecord(payload) { calls.create.push(payload); return { id: 999 }; },
    async completeOngoingRecord(payload) { calls.complete.push(payload); return []; },
  };
  return repo;
}

function makeManager(repo) {
  const broadcasts = [];
  const emits = [];
  const manager = new MaintenanceManager({
    repository: repo,
    notificationService: { broadcast: async (p) => { broadcasts.push(p); } },
    emitMaintenanceChanged: (status) => emits.push(status),
  });
  return { manager, broadcasts, emits };
}

function runMiddleware(mw, { url = '/api/transactions', method = 'GET', isAdmin = false } = {}) {
  let statusCode = 200;
  let body = null;
  let passed = false;
  const res = {
    setHeader() {},
    status(c) { statusCode = c; return this; },
    json(b) { body = b; return this; },
  };
  mw({ originalUrl: url, method, isAdmin }, res, () => { passed = true; });
  return { statusCode, body, passed };
}

describe('Khôi phục bảo trì từ CSDL khi khởi động', () => {
  let manager;
  afterEach(() => { if (manager) manager.clearAllTimers(); });

  it('B1. Có phiên ONGOING không hạn kết thúc → khoá lại, giữ lúc bắt đầu, không tạo bản ghi, không thông báo đẩy, có phát socket', async () => {
    const startedAt = iso(Date.now() - 30 * MIN);
    const repo = makeRepo({
      ongoing: [{ id: 5, type: 'EMERGENCY', reason: 'Sửa sự cố CSDL', activated_by: 'admin', started_at: startedAt, scheduled_end_at: null, status: 'ONGOING' }],
    });
    const ctx = makeManager(repo);
    manager = ctx.manager;

    await manager.restoreFromDatabase();

    assert.strictEqual(manager.isMaintenanceActive(), true);
    const st = manager.getStatus();
    assert.strictEqual(st.active, true);
    assert.strictEqual(st.isEmergency, true);
    assert.strictEqual(st.reason, 'Sửa sự cố CSDL');
    assert.strictEqual(st.activatedBy, 'admin');
    assert.strictEqual(new Date(st.activatedAt).getTime(), new Date(startedAt).getTime());
    assert.strictEqual(repo.calls.create.length, 0, 'không tạo bản ghi bảo trì mới');
    assert.strictEqual(repo.calls.close.length, 0);
    assert.strictEqual(ctx.broadcasts.length, 0, 'không gửi thông báo đẩy trùng');
    assert.ok(ctx.emits.length >= 1, 'phải phát maintenance_changed để client cập nhật');
    assert.strictEqual(ctx.emits[ctx.emits.length - 1].active, true);
  });

  it('B1b. Loại UPGRADE / SCHEDULED được khôi phục đúng cờ', async () => {
    const repo = makeRepo({
      ongoing: [{ id: 6, type: 'UPGRADE', reason: 'Nâng cấp', activated_by: 'admin', started_at: iso(Date.now() - MIN), scheduled_end_at: null, status: 'ONGOING' }],
    });
    manager = makeManager(repo).manager;
    await manager.restoreFromDatabase();
    const st = manager.getStatus();
    assert.strictEqual(st.isUpgrade, true);
    assert.strictEqual(st.isEmergency, false);
    assert.strictEqual(st.type, 'UPGRADE');
  });

  it('B2. Phiên ONGOING đã quá giờ kết thúc hẹn → đóng COMPLETED tại scheduled_end_at, không khoá', async () => {
    const endAt = iso(Date.now() - 10 * MIN);
    const repo = makeRepo({
      ongoing: [{ id: 7, type: 'SCHEDULED', reason: 'Bảo trì định kỳ', activated_by: 'admin', started_at: iso(Date.now() - 70 * MIN), scheduled_end_at: endAt, status: 'ONGOING' }],
    });
    manager = makeManager(repo).manager;

    await manager.restoreFromDatabase();

    assert.strictEqual(manager.isMaintenanceActive(), false);
    assert.strictEqual(repo.calls.close.length, 1);
    assert.strictEqual(repo.calls.close[0].id, 7);
    assert.strictEqual(repo.calls.close[0].status, 'COMPLETED');
    assert.strictEqual(new Date(repo.calls.close[0].ended_at).getTime(), new Date(endAt).getTime());
  });

  it('B3. Phiên ONGOING còn hạn → khoá, tới giờ hẹn thì tự mở và đóng bản ghi', async () => {
    const repo = makeRepo({
      ongoing: [{ id: 8, type: 'SCHEDULED', reason: 'Bảo trì', activated_by: 'admin', started_at: iso(Date.now() - MIN), scheduled_end_at: iso(Date.now() + 80), status: 'ONGOING' }],
    });
    const ctx = makeManager(repo);
    manager = ctx.manager;

    await manager.restoreFromDatabase();
    assert.strictEqual(manager.isMaintenanceActive(), true);

    await new Promise((r) => setTimeout(r, 200));
    assert.strictEqual(manager.isMaintenanceActive(), false, 'hết giờ hẹn phải tự mở');
    assert.strictEqual(repo.calls.complete.length, 1, 'phải đóng bản ghi ONGOING trong CSDL');
  });

  it('B4. Hai bản ghi ONGOING → giữ bản mới nhất, đóng bản cũ', async () => {
    const newer = iso(Date.now() - 5 * MIN);
    const repo = makeRepo({
      ongoing: [
        { id: 11, type: 'EMERGENCY', reason: 'Mới', activated_by: 'admin', started_at: newer, scheduled_end_at: null, status: 'ONGOING' },
        { id: 10, type: 'EMERGENCY', reason: 'Cũ', activated_by: 'admin', started_at: iso(Date.now() - 60 * MIN), scheduled_end_at: null, status: 'ONGOING' },
      ],
    });
    manager = makeManager(repo).manager;

    await manager.restoreFromDatabase();

    assert.strictEqual(manager.getStatus().reason, 'Mới');
    assert.strictEqual(repo.calls.close.length, 1);
    assert.strictEqual(repo.calls.close[0].id, 10);
    assert.strictEqual(repo.calls.close[0].status, 'COMPLETED');
    assert.strictEqual(new Date(repo.calls.close[0].ended_at).getTime(), new Date(newer).getTime());
  });

  it('B5a. Lịch SCHEDULED tương lai → nạp lại vào danh sách lịch, giữ recordId', async () => {
    const at = iso(Date.now() + 5 * 3600 * 1000);
    const end = iso(Date.now() + 6 * 3600 * 1000);
    const repo = makeRepo({
      scheduled: [{ id: 21, type: 'SCHEDULED', reason: 'Lịch đêm', activated_by: 'admin', started_at: at, scheduled_end_at: end, status: 'SCHEDULED' }],
    });
    manager = makeManager(repo).manager;

    await manager.restoreFromDatabase();

    const list = manager.getScheduledList();
    assert.strictEqual(list.length, 1);
    assert.strictEqual(list[0].recordId, 21);
    assert.strictEqual(new Date(list[0].scheduledAt).getTime(), new Date(at).getTime());
    assert.strictEqual(list[0].reason, 'Lịch đêm');
    assert.ok(manager.scheduledList[0]._timer, 'phải có hẹn giờ kích hoạt');
    assert.strictEqual(manager.isMaintenanceActive(), false);
  });

  it('B5b. Lịch SCHEDULED đang trong khung giờ → kích hoạt ngay, cập nhật bản ghi sang ONGOING', async () => {
    const repo = makeRepo({
      scheduled: [{ id: 22, type: 'SCHEDULED', reason: 'Đang tới giờ', activated_by: 'admin', started_at: iso(Date.now() - MIN), scheduled_end_at: iso(Date.now() + 60 * MIN), status: 'SCHEDULED' }],
    });
    manager = makeManager(repo).manager;

    await manager.restoreFromDatabase();

    assert.strictEqual(manager.isMaintenanceActive(), true);
    assert.strictEqual(manager.getStatus().isEmergency, false);
    assert.ok(repo.calls.updateStatus.some((c) => c.id === 22 && c.status === 'ONGOING'));
    assert.strictEqual(repo.calls.create.length, 0);
  });

  it('B5c. Lịch SCHEDULED đã lỡ cả khung giờ → huỷ kèm lý do', async () => {
    const repo = makeRepo({
      scheduled: [{ id: 23, type: 'SCHEDULED', reason: 'Lịch cũ', activated_by: 'admin', started_at: iso(Date.now() - 120 * MIN), scheduled_end_at: iso(Date.now() - 60 * MIN), status: 'SCHEDULED' }],
    });
    manager = makeManager(repo).manager;

    await manager.restoreFromDatabase();

    assert.strictEqual(manager.isMaintenanceActive(), false);
    assert.strictEqual(manager.getScheduledList().length, 0);
    assert.strictEqual(repo.calls.cancel.length, 1);
    assert.strictEqual(repo.calls.cancel[0].id, 23);
    assert.match(repo.calls.cancel[0].reason, /Lỡ lịch/);
  });

  it('B5d. Lịch đang trong khung giờ nhưng đã khôi phục một phiên ONGOING → lịch bị huỷ (luật cũ)', async () => {
    const repo = makeRepo({
      ongoing: [{ id: 30, type: 'EMERGENCY', reason: 'Khẩn', activated_by: 'admin', started_at: iso(Date.now() - 10 * MIN), scheduled_end_at: null, status: 'ONGOING' }],
      scheduled: [{ id: 31, type: 'SCHEDULED', reason: 'Lịch', activated_by: 'admin', started_at: iso(Date.now() - MIN), scheduled_end_at: iso(Date.now() + 60 * MIN), status: 'SCHEDULED' }],
    });
    manager = makeManager(repo).manager;

    await manager.restoreFromDatabase();

    assert.strictEqual(manager.getStatus().reason, 'Khẩn');
    assert.ok(repo.calls.cancel.some((c) => c.id === 31));
  });

  it('B6. Không có phiên nào → không khoá (hồi quy)', async () => {
    const repo = makeRepo();
    const ctx = makeManager(repo);
    manager = ctx.manager;
    await manager.restoreFromDatabase();
    assert.strictEqual(manager.isMaintenanceActive(), false);
    assert.strictEqual(repo.calls.close.length + repo.calls.cancel.length + repo.calls.create.length, 0);
  });
});

describe('Khoá khi chưa đọc được CSDL (fail-closed, Q7)', () => {
  let manager;
  afterEach(() => { if (manager) manager.clearAllTimers(); });

  it('B7a. Đang chờ khôi phục → middleware chặn người dùng 503 MAINTENANCE_MODE, vẫn cho health check và admin qua', () => {
    const ctx = makeManager(makeRepo());
    manager = ctx.manager;
    manager.beginRestore();
    const mw = createMaintenanceMiddleware({ manager });

    const user = runMiddleware(mw);
    assert.strictEqual(user.passed, false);
    assert.strictEqual(user.statusCode, 503);
    assert.strictEqual(user.body.code, 'MAINTENANCE_MODE');
    assert.match(user.body.message, /khởi động/i);

    assert.strictEqual(runMiddleware(mw, { url: '/health' }).passed, true);
    assert.strictEqual(runMiddleware(mw, { isAdmin: true }).passed, true);
    assert.strictEqual(ctx.emits.length, 0, 'trạng thái chờ chỉ ở RAM, không phát cho client');
    assert.strictEqual(ctx.broadcasts.length, 0);
  });

  it('B7b. CSDL lỗi → vẫn khoá và thử lại; đọc được thì mở và phát socket một lần', async () => {
    const repo = makeRepo({ failTimes: 2 });
    const ctx = makeManager(repo);
    manager = ctx.manager;
    const mw = createMaintenanceMiddleware({ manager });

    const done = manager.startRestoreLoop({ retryMs: 20 });
    await new Promise((r) => setTimeout(r, 5));
    assert.strictEqual(runMiddleware(mw).statusCode, 503, 'lần đọc đầu lỗi: vẫn khoá');

    await done;
    assert.ok(repo.calls.load >= 3, 'phải thử lại tới khi đọc được');
    assert.strictEqual(manager.isMaintenanceActive(), false);
    assert.strictEqual(runMiddleware(mw).passed, true);
    assert.strictEqual(ctx.emits.length, 1);
    assert.strictEqual(ctx.emits[0].active, false);
  });

  it('B7c. Đọc được CSDL và có phiên ONGOING → vẫn khoá sau khi hết chờ, thông điệp là lý do bảo trì', async () => {
    const repo = makeRepo({
      ongoing: [{ id: 40, type: 'EMERGENCY', reason: 'Đang sửa', activated_by: 'admin', started_at: iso(Date.now() - MIN), scheduled_end_at: null, status: 'ONGOING' }],
    });
    manager = makeManager(repo).manager;
    const mw = createMaintenanceMiddleware({ manager });
    await manager.startRestoreLoop({ retryMs: 20 });
    const r = runMiddleware(mw);
    assert.strictEqual(r.statusCode, 503);
    assert.strictEqual(r.body.message, 'Đang sửa');
  });
});
