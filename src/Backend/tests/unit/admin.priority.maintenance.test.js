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
});
