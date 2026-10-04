/**
 * Unit Test — Admin Priority & Emergency Maintenance Mode (TDD)
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const { createAdminPriorityMiddleware } = require('../../middleware/admin-priority.middleware');
const { MaintenanceManager } = require('../../core/resilience/maintenance.manager');
const { createMaintenanceMiddleware } = require('../../middleware/maintenance.middleware');

describe('Admin Resilience — Làn ưu tiên & Công tắc bảo trì khẩn cấp', () => {
  let maintenanceManager;

  beforeEach(() => {
    maintenanceManager = new MaintenanceManager();
  });

  it('1. Admin Priority Middleware tự động nhận diện và gắn cờ req.isAdmin = true cho route /api/admin', (t, done) => {
    const middleware = createAdminPriorityMiddleware();
    const req = { originalUrl: '/api/admin/totaluser', headers: {} };
    const res = {};

    middleware(req, res, () => {
      assert.strictEqual(req.isAdmin, true, 'Request vào /api/admin phải được gắn req.isAdmin = true');
      done();
    });
  });

  it('2. Admin Priority Middleware nhận diện qua header X-Emergency-Admin-Key', (t, done) => {
    const middleware = createAdminPriorityMiddleware({ emergencyKey: 'secret-admin-pass' });
    const req = {
      originalUrl: '/api/categories',
      headers: { 'x-emergency-admin-key': 'secret-admin-pass' },
    };
    const res = {};

    middleware(req, res, () => {
      assert.strictEqual(req.isAdmin, true);
      done();
    });
  });

  it('3. Maintenance Middleware chặn Client-app với HTTP 503 khi chế độ bảo trì đang BẬT', (t, done) => {
    maintenanceManager.setMaintenance(true, 'Hệ thống đang bảo trì để nâng cấp định kỳ', 'admin-01');

    const middleware = createMaintenanceMiddleware({ manager: maintenanceManager });
    const reqClient = { originalUrl: '/api/transactions', headers: {}, isAdmin: false };

    let statusCode = null;
    let responseBody = null;
    const res = {
      status: (code) => {
        statusCode = code;
        return {
          json: (body) => {
            responseBody = body;
            assert.strictEqual(statusCode, 503);
            assert.strictEqual(responseBody.code, 'MAINTENANCE_MODE');
            assert.ok(responseBody.message.includes('bảo trì'));
            done();
          },
        };
      },
    };

    middleware(reqClient, res, () => {
      assert.fail('Không được cho client đi qua khi bảo trì đang bật');
    });
  });

  it('4. Maintenance Middleware cho phép Admin-web truy cập bình thường kể cả khi bảo trì BẬT', (t, done) => {
    maintenanceManager.setMaintenance(true, 'Khắc phục sự cố khẩn cấp', 'admin-01');

    const middleware = createMaintenanceMiddleware({ manager: maintenanceManager });
    const reqAdmin = { originalUrl: '/api/admin/getuser', headers: {}, isAdmin: true };
    const res = {};

    middleware(reqAdmin, res, () => {
      // Admin đi qua thông suốt!
      done();
    });
  });

  it('5. Bảo trì thông thường (im lặng): Không phát broadcast tới người dùng', () => {
    let broadcastCalled = false;
    const mockNotif = {
      broadcast: async () => { broadcastCalled = true; },
    };
    const mgr = new MaintenanceManager({ notificationService: mockNotif });

    mgr.setMaintenance(true, 'Bảo trì kỹ thuật định kỳ', 'admin', { isEmergency: false });
    const status = mgr.getStatus();

    assert.strictEqual(status.active, true);
    assert.strictEqual(status.isEmergency, false);
    assert.strictEqual(broadcastCalled, false, 'Bảo trì thường KHÔNG được phát broadcast');
  });

  it('6. Bảo trì khẩn cấp: Tự động phát broadcast CRITICAL tới toàn bộ người dùng', () => {
    let broadcastPayload = null;
    const mockNotif = {
      broadcast: async (payload) => {
        broadcastPayload = payload;
      },
    };
    const mgr = new MaintenanceManager({ notificationService: mockNotif });

    mgr.setMaintenance(true, 'Sự cố máy chủ nghiêm trọng', 'admin', { isEmergency: true });
    const status = mgr.getStatus();

    assert.strictEqual(status.active, true);
    assert.strictEqual(status.isEmergency, true);
    assert.ok(broadcastPayload, 'Phải phát broadcast khi khẩn cấp');
    assert.strictEqual(broadcastPayload.level, 'CRITICAL');
    assert.strictEqual(broadcastPayload.metadata.isEmergency, true);
  });

  it('7. Lên lịch bảo trì: Lưu thông tin lịch và cho phép hủy lịch chủ động', () => {
    const mgr = new MaintenanceManager();
    const futureDate = new Date(Date.now() + 100000).toISOString();

    mgr.scheduleMaintenance({
      scheduledAt: futureDate,
      reason: 'Nâng cấp CSDL tối nay',
      isEmergency: false,
      createdBy: 'admin-lead',
    });

    let status = mgr.getStatus();
    assert.ok(status.scheduled, 'Phải có thông tin scheduled');
    assert.strictEqual(status.scheduled.scheduledAt, futureDate);
    assert.strictEqual(status.scheduled.createdBy, 'admin-lead');

    // Hủy lịch
    const cancelRes = mgr.cancelScheduledMaintenance();
    assert.strictEqual(cancelRes.cancelled, true);
    assert.strictEqual(mgr.getStatus().scheduled, null);
  });

  it('8. QUY TẮC CỐT LÕI CỦA PO: Kích hoạt Bảo trì khẩn cấp tự động HỦY/XÓA lịch bảo trì đã hẹn trước', () => {
    const mgr = new MaintenanceManager();
    const futureDate = new Date(Date.now() + 100000).toISOString();

    // 1. Đặt lịch trước
    mgr.scheduleMaintenance({
      scheduledAt: futureDate,
      reason: 'Bảo trì ngày mai',
      isEmergency: false,
      createdBy: 'admin-01',
    });
    assert.ok(mgr.getStatus().scheduled, 'Lịch bảo trì phải tồn tại trước khi sự cố xảy ra');

    // 2. Sự cố khẩn cấp xảy ra -> Bật bảo trì khẩn cấp ngay
    mgr.setMaintenance(true, 'Sập đường truyền cáp quang', 'admin-02', { isEmergency: true });

    // 3. Kiểm tra: Lịch hẹn đã bị xóa sạch (scheduled = null)
    const status = mgr.getStatus();
    assert.strictEqual(status.active, true);
    assert.strictEqual(status.isEmergency, true);
    assert.strictEqual(status.scheduled, null, 'Lịch hẹn trước phải bị xóa sạch khi kích hoạt bảo trì khẩn cấp');
  });

  it('9. Lên lịch bảo trì với thời điểm kết thúc hợp lệ (scheduledEndAt)', () => {
    const mgr = new MaintenanceManager();
    const futureStart = new Date(Date.now() + 100000).toISOString();
    const futureEnd = new Date(Date.now() + 200000).toISOString();

    mgr.scheduleMaintenance({
      scheduledAt: futureStart,
      scheduledEndAt: futureEnd,
      reason: 'Nâng cấp máy chủ từ 2h đến 3h',
      isEmergency: false,
      createdBy: 'admin-lead',
    });

    const status = mgr.getStatus();
    assert.ok(status.scheduled);
    assert.strictEqual(status.scheduled.scheduledAt, futureStart);
    assert.strictEqual(status.scheduled.scheduledEndAt, futureEnd);
  });

  it('10. Chặn lên lịch khi thời điểm kết thúc trước hoặc bằng thời điểm bắt đầu', () => {
    const mgr = new MaintenanceManager();
    const futureStart = new Date(Date.now() + 200000).toISOString();
    const invalidEnd = new Date(Date.now() + 100000).toISOString(); // Trước start

    assert.throws(
      () => {
        mgr.scheduleMaintenance({
          scheduledAt: futureStart,
          scheduledEndAt: invalidEnd,
          reason: 'Lỗi thứ tự thời gian',
        });
      },
      { message: /Thời điểm kết thúc bảo trì phải sau thời điểm bắt đầu/ }
    );
  });

  it('11. Chặn cài đặt lịch bảo trì mới khi hệ thống đang trong phiên bảo trì trực tiếp', () => {
    const mgr = new MaintenanceManager();
    mgr.setMaintenance(true, 'Đang bảo trì trực tiếp', 'admin-01');

    const futureStart = new Date(Date.now() + 100000).toISOString();

    assert.throws(
      () => {
        mgr.scheduleMaintenance({
          scheduledAt: futureStart,
          reason: 'Cố tình lên lịch trùng',
        });
      },
      { message: /Hệ thống hiện đang trong phiên bảo trì trực tiếp/ }
    );
  });
});
