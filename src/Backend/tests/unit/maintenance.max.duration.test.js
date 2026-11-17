/**
 * Thời hạn tối đa một phiên bảo trì là 7 ngày (Chủ dự án chốt 2026-11-16).
 * - Lên lịch có giờ kết thúc: kết thúc cách bắt đầu quá 7 ngày → từ chối.
 * - Mọi phiên không có giờ kết thúc (khẩn cấp, theo lịch không nhập giờ kết thúc): tự kết thúc sau 7 ngày.
 * - Khởi động lại giữa phiên: hạn 7 ngày tính từ lúc phiên bắt đầu; đã quá thì đóng phiên.
 * Lý do gốc: hẹn giờ setTimeout tối đa ~24,8 ngày, phiên dài hơn làm hẹn giờ tắt chạy ngay.
 */
const { describe, it, beforeEach, afterEach, mock } = require('node:test');
const assert = require('node:assert/strict');
const { MaintenanceManager } = require('../../core/resilience/maintenance.manager');

const MIN = 60 * 1000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;
const iso = (ms) => new Date(ms).toISOString();

function makeRepo({ ongoing = [] } = {}) {
  const calls = { create: [], close: [], complete: [] };
  return {
    calls,
    async loadRestoreState() { return { ongoing: ongoing.map((r) => ({ ...r })), scheduled: [] }; },
    async closeRecord(id, payload) { calls.close.push({ id, ...payload }); return { id }; },
    async cancelScheduledRecord() { return {}; },
    async updateRecordStatus() { return {}; },
    async createRecord(payload) { calls.create.push(payload); return { id: 999 }; },
    async completeOngoingRecord(payload) { calls.complete.push(payload); return []; },
    async cancelConflictingRecords() { return []; },
  };
}

describe('Thời hạn tối đa 7 ngày của một phiên bảo trì', () => {
  let manager;
  let repo;

  beforeEach(() => {
    repo = makeRepo();
    manager = new MaintenanceManager({ repository: repo, notificationService: { broadcast: async () => ({}) } });
  });

  afterEach(() => {
    manager.clearAllTimers();
    mock.timers.reset();
  });

  it('lên lịch có giờ kết thúc cách bắt đầu quá 7 ngày → từ chối, không tạo lịch', () => {
    const start = Date.now() + 4 * HOUR;
    assert.throws(
      () => manager.scheduleMaintenance({ scheduledAt: iso(start), scheduledEndAt: iso(start + 7 * DAY + MIN), reason: 'Quá dài' }),
      /tối đa 7 ngày/
    );
    assert.equal(manager.getScheduledList().length, 0);
  });

  it('lên lịch có giờ kết thúc đúng 7 ngày sau bắt đầu → nhận', () => {
    const start = Date.now() + 4 * HOUR;
    manager.scheduleMaintenance({ scheduledAt: iso(start), scheduledEndAt: iso(start + 7 * DAY), reason: 'Vừa đủ' });
    assert.equal(manager.getScheduledList().length, 1);
  });

  it('bảo trì khẩn cấp không có giờ kết thúc → còn bật ở 7 ngày trừ 1 phút, tự tắt khi đủ 7 ngày', () => {
    mock.timers.enable({ apis: ['setTimeout', 'Date'], now: Date.now() });
    manager.setMaintenance(true, 'Sự cố', 'admin', { isEmergency: true });
    assert.equal(manager.isMaintenanceActive(), true);
    mock.timers.tick(7 * DAY - MIN);
    assert.equal(manager.isMaintenanceActive(), true);
    mock.timers.tick(MIN);
    assert.equal(manager.isMaintenanceActive(), false);
    assert.equal(repo.calls.complete.length, 1);
  });

  it('phiên theo lịch không nhập giờ kết thúc → tự tắt sau 7 ngày kể từ lúc bắt đầu', async () => {
    mock.timers.enable({ apis: ['setTimeout', 'Date'], now: Date.now() });
    await manager.activateScheduledItem({ id: 1, scheduledAt: iso(Date.now()), scheduledEndAt: null, reason: 'Định kỳ', createdBy: 'admin', isEmergency: false });
    assert.equal(manager.isMaintenanceActive(), true);
    mock.timers.tick(7 * DAY - MIN);
    assert.equal(manager.isMaintenanceActive(), true);
    mock.timers.tick(MIN);
    assert.equal(manager.isMaintenanceActive(), false);
  });

  it('phiên theo lịch có giờ kết thúc (2 giờ) → vẫn tắt đúng giờ kết thúc đã hẹn', async () => {
    mock.timers.enable({ apis: ['setTimeout', 'Date'], now: Date.now() });
    const now = Date.now();
    await manager.activateScheduledItem({ id: 2, scheduledAt: iso(now), scheduledEndAt: iso(now + 2 * HOUR), reason: 'Có hẹn', createdBy: 'admin', isEmergency: false });
    mock.timers.tick(2 * HOUR);
    assert.equal(manager.isMaintenanceActive(), false);
  });

  it('khẩn cấp đè lên phiên theo lịch có giờ kết thúc → không bị tắt theo giờ của lịch, tự tắt sau 7 ngày kể từ lúc bật khẩn cấp', async () => {
    mock.timers.enable({ apis: ['setTimeout', 'Date'], now: Date.now() });
    const now = Date.now();
    await manager.activateScheduledItem({ id: 3, scheduledAt: iso(now), scheduledEndAt: iso(now + 2 * HOUR), reason: 'Có hẹn', createdBy: 'admin', isEmergency: false });
    mock.timers.tick(HOUR);
    manager.setMaintenance(true, 'Sự cố giữa phiên', 'admin', { isEmergency: true });
    mock.timers.tick(2 * HOUR);
    assert.equal(manager.isMaintenanceActive(), true, 'khẩn cấp không được tắt theo giờ kết thúc của lịch');
    mock.timers.tick(7 * DAY - 2 * HOUR);
    assert.equal(manager.isMaintenanceActive(), false);
  });

  it('khởi động lại: phiên không hạn kết thúc bắt đầu 1 ngày trước → khôi phục, tự tắt sau 6 ngày nữa', async () => {
    mock.timers.enable({ apis: ['setTimeout', 'Date'], now: Date.now() });
    repo = makeRepo({ ongoing: [{ id: 5, type: 'EMERGENCY', reason: 'Sự cố', activated_by: 'admin', started_at: iso(Date.now() - DAY), scheduled_end_at: null }] });
    manager = new MaintenanceManager({ repository: repo, notificationService: { broadcast: async () => ({}) } });
    await manager.restoreFromDatabase();
    assert.equal(manager.isMaintenanceActive(), true);
    mock.timers.tick(6 * DAY - MIN);
    assert.equal(manager.isMaintenanceActive(), true);
    mock.timers.tick(MIN);
    assert.equal(manager.isMaintenanceActive(), false);
  });

  it('khởi động lại: phiên không hạn kết thúc đã bắt đầu 8 ngày trước → đóng phiên tại mốc 7 ngày, không bật lại', async () => {
    const startedAt = Date.now() - 8 * DAY;
    repo = makeRepo({ ongoing: [{ id: 6, type: 'EMERGENCY', reason: 'Quên tắt', activated_by: 'admin', started_at: iso(startedAt), scheduled_end_at: null }] });
    manager = new MaintenanceManager({ repository: repo, notificationService: { broadcast: async () => ({}) } });
    await manager.restoreFromDatabase();
    assert.equal(manager.isMaintenanceActive(), false);
    assert.equal(repo.calls.close.length, 1);
    assert.equal(repo.calls.close[0].id, 6);
    assert.equal(new Date(repo.calls.close[0].ended_at).getTime(), startedAt + 7 * DAY);
  });
});
