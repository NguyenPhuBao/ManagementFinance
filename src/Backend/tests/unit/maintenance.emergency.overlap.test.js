/**
 * Bảo trì khẩn cấp và các phiên theo lịch (Chủ dự án chốt 2026-11-16):
 * - Bật khẩn cấp khi đang chạy một phiên theo lịch: phiên theo lịch bị HỦY, phiên khẩn cấp là bản ghi riêng.
 * - Lịch còn chờ KHÔNG bị hủy ngay lúc bật khẩn cấp; tới giờ bắt đầu của lịch mà khẩn cấp còn chạy thì mới hủy
 *   ("khẩn cấp chạy tới đâu kiểm tra tới đó"). Lịch bắt đầu sau khi khẩn cấp đã tắt thì chạy bình thường.
 */
const { describe, it, beforeEach, afterEach, mock } = require('node:test');
const assert = require('node:assert/strict');
const { MaintenanceManager } = require('../../core/resilience/maintenance.manager');

const HOUR = 3600 * 1000;
const iso = (ms) => new Date(ms).toISOString();
const flush = async () => { for (let i = 0; i < 5; i += 1) await Promise.resolve(); };

function makeRepo() {
  const calls = [];
  let nextId = 100;
  return {
    calls,
    async createRecord(payload) { calls.push(['create', payload]); nextId += 1; return { id: nextId }; },
    async cancelScheduledRecord(payload) { calls.push(['cancelScheduled', payload]); return [{ id: payload.id }]; },
    async completeOngoingRecord(payload) { calls.push(['completeOngoing', payload]); return []; },
    async updateOngoingToEmergency(payload) { calls.push(['updateOngoingToEmergency', payload]); return []; },
    async updateRecordStatus(id, payload) { calls.push(['updateStatus', { id, ...payload }]); return { id }; },
  };
}

describe('Bảo trì khẩn cấp và các phiên theo lịch', () => {
  let manager;
  let repo;

  beforeEach(() => {
    mock.timers.enable({ apis: ['setTimeout', 'Date'], now: Date.now() });
    repo = makeRepo();
    manager = new MaintenanceManager({ repository: repo, notificationService: { broadcast: async () => ({}) } });
  });

  afterEach(() => {
    manager.clearAllTimers();
    mock.timers.reset();
  });

  const schedule = async (startInMs, reason) => {
    manager.scheduleMaintenance({ scheduledAt: iso(Date.now() + startInMs), scheduledEndAt: iso(Date.now() + startInMs + HOUR), reason, createdBy: 'admin' });
    await flush(); // createRecord trả id → gán recordId
  };

  it('bật khẩn cấp KHÔNG hủy ngay lịch nào, kể cả lịch chỉ còn 1 giờ nữa là bắt đầu', async () => {
    await schedule(4 * HOUR, 'Lịch sắp tới');
    mock.timers.tick(3 * HOUR);
    manager.setMaintenance(true, 'Sự cố', 'admin', { isEmergency: true });
    await flush();
    assert.equal(manager.getScheduledList().length, 1);
    assert.equal(repo.calls.filter(([n]) => n === 'cancelScheduled').length, 0);
  });

  it('tới giờ bắt đầu của lịch mà khẩn cấp còn chạy → hủy lịch đó lúc ấy, khẩn cấp vẫn chạy', async () => {
    await schedule(4 * HOUR, 'Lịch bị vướng');
    const recordId = manager.getScheduledList()[0].recordId;
    manager.setMaintenance(true, 'Sự cố dài', 'admin', { isEmergency: true });
    mock.timers.tick(4 * HOUR - 1000);
    assert.equal(manager.getScheduledList().length, 1, 'chưa tới giờ thì lịch còn nguyên');
    mock.timers.tick(1000);
    await flush();
    assert.equal(manager.getScheduledList().length, 0);
    const cancels = repo.calls.filter(([n]) => n === 'cancelScheduled');
    assert.equal(cancels.length, 1);
    assert.equal(cancels[0][1].id, recordId);
    assert.equal(manager.isEmergencyMode(), true);
  });

  it('khẩn cấp đã tắt trước giờ của lịch → lịch chạy bình thường, không bị hủy', async () => {
    await schedule(4 * HOUR, 'Lịch sau sự cố');
    manager.setMaintenance(true, 'Sự cố ngắn', 'admin', { isEmergency: true });
    mock.timers.tick(HOUR);
    manager.setMaintenance(false, 'Xong', 'admin');
    mock.timers.tick(3 * HOUR);
    await flush();
    assert.equal(manager.isMaintenanceActive(), true);
    assert.equal(manager.isEmergencyMode(), false);
    assert.equal(repo.calls.filter(([n]) => n === 'cancelScheduled').length, 0);
  });

  it('bật khẩn cấp khi đang chạy phiên theo lịch → phiên theo lịch bị hủy (CANCELLED) rồi mới tạo bản ghi khẩn cấp riêng', async () => {
    await manager.activateScheduledItem({ id: 1, recordId: 77, scheduledAt: iso(Date.now()), scheduledEndAt: iso(Date.now() + 2 * HOUR), reason: 'Định kỳ', createdBy: 'admin', isEmergency: false });
    repo.calls.length = 0;
    manager.setMaintenance(true, 'Sự cố giữa phiên', 'admin-lead', { isEmergency: true });
    await flush();
    const names = repo.calls.map(([n]) => n);
    assert.ok(!names.includes('updateOngoingToEmergency'), 'không đổi loại bản ghi cũ thành khẩn cấp');
    const iCancel = names.indexOf('completeOngoing');
    const iCreate = names.indexOf('create');
    assert.ok(iCancel >= 0, 'phải đóng phiên theo lịch đang chạy');
    assert.equal(repo.calls[iCancel][1].status, 'CANCELLED');
    assert.ok(iCreate > iCancel, 'bản ghi khẩn cấp tạo SAU khi đã hủy phiên cũ');
    assert.equal(repo.calls[iCreate][1].type, 'EMERGENCY');
    assert.equal(repo.calls[iCreate][1].status, 'ONGOING');
    assert.equal(repo.calls[iCreate][1].reason, 'Sự cố giữa phiên');
    assert.equal(manager.isEmergencyMode(), true);
  });
});
