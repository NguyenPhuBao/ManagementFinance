const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { MaintenanceManager } = require('../../core/resilience/maintenance.manager');

describe('Maintenance Manager Schedule Rules (4h & 5h constraints & isEmergency=false)', () => {
  let manager;
  let mockRepository;
  let mockNotifService;

  beforeEach(() => {
    mockRepository = {
      createRecord: async () => ({ id: 999 }),
      updateRecordStatus: async () => ({ id: 999 }),
      cancelScheduledRecord: async () => ({ id: 999 }),
      completeOngoingRecord: async () => ({ id: 999 }),
      getActiveScheduledRecords: async () => ([]),
    };

    mockNotifService = {
      broadcastCalls: [],
      broadcast: async (payload) => {
        mockNotifService.broadcastCalls.push(payload);
        return { success: true };
      },
    };

    manager = new MaintenanceManager({
      redis: null,
      notificationService: mockNotifService,
    });
  });

  afterEach(() => {
    if (manager && typeof manager.clearAllTimers === 'function') {
      manager.clearAllTimers();
    }
  });

  it('FAIL khi đặt thời gian bảo trì trước dưới 4 tiếng so với hiện tại', () => {
    const now = Date.now();
    const scheduledAt = new Date(now + 2 * 3600 * 1000).toISOString(); // Chỉ 2 tiếng nữa
    const scheduledEndAt = new Date(now + 3 * 3600 * 1000).toISOString();

    assert.throws(() => {
      manager.scheduleMaintenance({
        scheduledAt,
        scheduledEndAt,
        reason: 'Bảo trì test dưới 4 tiếng',
        createdBy: 'admin',
      });
    }, /ít nhất 4 tiếng/i);
  });

  it('PASS khi đặt thời gian bảo trì trước ít nhất 4 tiếng so với hiện tại', () => {
    const now = Date.now();
    const scheduledAt = new Date(now + 5 * 3600 * 1000).toISOString(); // 5 tiếng nữa
    const scheduledEndAt = new Date(now + 6 * 3600 * 1000).toISOString();

    const status = manager.scheduleMaintenance({
      scheduledAt,
      scheduledEndAt,
      reason: 'Bảo trì test hợp lệ 5h',
      createdBy: 'admin',
    });

    assert.ok(status);
    assert.ok(manager.getScheduledList().length >= 1);
  });

  it('FAIL khi đặt lịch thứ 2 cách lịch thứ nhất dưới 5 tiếng', () => {
    const now = Date.now();
    // Lịch 1: Từ now + 5h đến now + 7h
    const sched1Start = new Date(now + 5 * 3600 * 1000).toISOString();
    const sched1End = new Date(now + 7 * 3600 * 1000).toISOString();

    manager.scheduleMaintenance({
      scheduledAt: sched1Start,
      scheduledEndAt: sched1End,
      reason: 'Lịch 1',
      createdBy: 'admin',
    });

    // Lịch 2: Từ now + 9h (cách lịch 1 kết thúc chỉ 2 tiếng, < 5h)
    const sched2Start = new Date(now + 9 * 3600 * 1000).toISOString();
    const sched2End = new Date(now + 10 * 3600 * 1000).toISOString();

    assert.throws(() => {
      manager.scheduleMaintenance({
        scheduledAt: sched2Start,
        scheduledEndAt: sched2End,
        reason: 'Lịch 2 quá sát lịch 1',
        createdBy: 'admin',
      });
    }, /cách nhau ít nhất 5 tiếng/i);
  });

  it('PASS khi đặt lịch thứ 2 cách lịch thứ nhất ít nhất 5 tiếng', () => {
    const now = Date.now();
    // Lịch 1: Từ now + 5h đến now + 7h
    const sched1Start = new Date(now + 5 * 3600 * 1000).toISOString();
    const sched1End = new Date(now + 7 * 3600 * 1000).toISOString();

    manager.scheduleMaintenance({
      scheduledAt: sched1Start,
      scheduledEndAt: sched1End,
      reason: 'Lịch 1',
      createdBy: 'admin',
    });

    // Lịch 2: Từ now + 13h (cách lịch 1 kết thúc đúng 6 tiếng, >= 5h)
    const sched2Start = new Date(now + 13 * 3600 * 1000).toISOString();
    const sched2End = new Date(now + 15 * 3600 * 1000).toISOString();

    const status = manager.scheduleMaintenance({
      scheduledAt: sched2Start,
      scheduledEndAt: sched2End,
      reason: 'Lịch 2 cách 6 tiếng',
      createdBy: 'admin',
    });

    assert.ok(status);
    assert.strictEqual(manager.getScheduledList().length, 2);
  });

  it('Kích hoạt lịch hẹn bảo trì thì isEmergency = false và tiêu đề là HỆ THỐNG ĐANG BẢO TRÌ', async () => {
    const schedItem = {
      id: 1234,
      scheduledAt: new Date().toISOString(),
      reason: 'Nâng cấp định kỳ',
      createdBy: 'admin',
      isEmergency: false,
    };

    manager.activateScheduledItem(schedItem);

    assert.strictEqual(manager.active, true);
    assert.strictEqual(manager.isEmergency, false);
    assert.strictEqual(manager.getStatus().isEmergency, false);

    // Kiểm tra broadcast không được chứa từ KHẨN CẤP
    assert.ok(mockNotifService.broadcastCalls.length > 0);
    const lastCall = mockNotifService.broadcastCalls[mockNotifService.broadcastCalls.length - 1];
    assert.match(lastCall.title, /HỆ THỐNG ĐANG BẢO TRÌ/i);
    assert.ok(!/CRITICAL/i.test(lastCall.level || ''));
  });
});
