/**
 * Unit Test — Admin Priority & Emergency Maintenance Mode (TDD)
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { createAdminPriorityMiddleware } = require('../../middleware/admin-priority.middleware');
const { MaintenanceManager } = require('../../core/resilience/maintenance.manager');
const { createMaintenanceMiddleware } = require('../../middleware/maintenance.middleware');
const authService = require('../../modules/auth/auth.service');
const authRepository = require('../../modules/auth/auth.repository');
const config = require('../../config');

test('Admin Resilience — Làn ưu tiên & Công tắc bảo trì khẩn cấp', async (t) => {
  await t.test('1. Admin Priority Middleware KHÔNG tự động gắn cờ req.isAdmin = true cho route /api/admin khi chưa xác thực token', () => {
    const middleware = createAdminPriorityMiddleware();
    const req = { originalUrl: '/api/admin/totaluser', headers: {} };
    const res = {};

    middleware(req, res, () => {
      assert.strictEqual(req.isAdmin, false, 'Request vào /api/admin chưa xác thực token thì req.isAdmin phải là false');
    });
  });

  await t.test('2. Admin Priority Middleware nhận diện qua header X-Emergency-Admin-Key', () => {
    const middleware = createAdminPriorityMiddleware({ emergencyKey: 'secret-admin-pass' });
    const req = {
      originalUrl: '/api/categories',
      headers: { 'x-emergency-admin-key': 'secret-admin-pass' },
    };
    const res = {};

    middleware(req, res, () => {
      assert.strictEqual(req.isAdmin, true);
    });
  });

  await t.test('3. Maintenance Middleware chặn Client-app với HTTP 503 khi chế độ bảo trì đang BẬT', () => {
    const mgr = new MaintenanceManager();
    mgr.setMaintenance(true, 'Hệ thống đang bảo trì để nâng cấp định kỳ', 'admin-01');

    const middleware = createMaintenanceMiddleware({ manager: mgr });
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
          },
        };
      },
    };

    middleware(reqClient, res, () => {
      assert.fail('Không được cho client đi qua khi bảo trì đang bật');
    });
  });

  await t.test('4. Maintenance Middleware cho phép Admin-web truy cập bình thường kể cả khi bảo trì BẬT', () => {
    const mgr = new MaintenanceManager();
    mgr.setMaintenance(true, 'Khắc phục sự cố khẩn cấp', 'admin-01');

    const middleware = createMaintenanceMiddleware({ manager: mgr });
    const reqAdmin = { originalUrl: '/api/admin/getuser', headers: {}, isAdmin: true };
    const res = {};

    let passed = false;
    middleware(reqAdmin, res, () => {
      passed = true;
    });
    assert.strictEqual(passed, true, 'Admin phải đi qua thông suốt');
  });

  await t.test('5. Bảo trì thông thường (im lặng): Không phát broadcast tới người dùng', () => {
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

  await t.test('6. Bảo trì khẩn cấp: Tự động phát broadcast CRITICAL tới toàn bộ người dùng', () => {
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

  await t.test('7. Lên lịch bảo trì: Lưu thông tin lịch và cho phép hủy lịch chủ động', () => {
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

  await t.test('8. QUY TẮC CỐT LÕI CỦA PO: Kích hoạt Bảo trì khẩn cấp tự động HỦY/XÓA lịch bảo trì đã hẹn trước', () => {
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

  await t.test('9. Lên lịch bảo trì với thời điểm kết thúc hợp lệ (scheduledEndAt)', () => {
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
    mgr.cancelScheduledMaintenance();
  });

  await t.test('10. Chặn lên lịch khi thời điểm kết thúc trước hoặc bằng thời điểm bắt đầu', () => {
    const mgr = new MaintenanceManager();
    const futureStart = new Date(Date.now() + 200000).toISOString();
    const invalidEnd = new Date(Date.now() + 100000).toISOString();

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

  await t.test('11. Chặn cài đặt lịch bảo trì mới khi hệ thống đang trong phiên bảo trì trực tiếp', () => {
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

  await t.test('12. Token giả mạo không ký (hoặc sai chữ ký) mang role: admin KHÔNG ĐƯỢC cấp req.isAdmin', () => {
    const forgedToken = jwt.sign({ idaccount: 999, role: 'admin' }, 'attacker-fake-secret');
    const middleware = createAdminPriorityMiddleware({ jwtSecret: 'legit-server-secret' });
    const req = {
      originalUrl: '/api/auth/login',
      headers: { authorization: `Bearer ${forgedToken}` },
    };
    const res = {};

    let called = false;
    middleware(req, res, () => {
      called = true;
    });
    assert.strictEqual(called, true);
    assert.strictEqual(req.isAdmin, false, 'Token sai chữ ký không được cấp req.isAdmin');
  });

  await t.test('13. Token thật ký đúng secret của server mang role: admin ĐƯỢC CẤP req.isAdmin = true', () => {
    const secret = 'valid-test-server-secret-key';
    const legitimateToken = jwt.sign({ idaccount: 1, idrole: 1, rolename: 'admin' }, secret);
    const middleware = createAdminPriorityMiddleware({ jwtSecret: secret });
    const req = {
      originalUrl: '/api/categories',
      headers: { authorization: `Bearer ${legitimateToken}` },
    };
    const res = {};

    let called = false;
    middleware(req, res, () => {
      called = true;
    });
    assert.strictEqual(called, true);
    assert.strictEqual(req.isAdmin, true, 'Token hợp lệ do server ký phải được cấp req.isAdmin');
  });

  await t.test('14. Header tự khai x-client-platform: admin-web gửi tới /auth/login KHÔNG ĐƯỢC cấp req.isAdmin', () => {
    const middleware = createAdminPriorityMiddleware();
    const req = {
      originalUrl: '/api/auth/login',
      headers: { 'x-client-platform': 'admin-web' },
    };
    const res = {};

    let called = false;
    middleware(req, res, () => {
      called = true;
    });
    assert.strictEqual(called, true);
    assert.strictEqual(req.isAdmin, false, 'Header tự khai KHÔNG được cấp req.isAdmin');
    assert.strictEqual(req.isAdminWebClient, true, 'Header tự khai chỉ được dùng làm nhãn req.isAdminWebClient');
  });

  await t.test('15. Origin / Referer admin-web gửi tới /auth/refresh KHÔNG ĐƯỢC cấp req.isAdmin', () => {
    const middleware = createAdminPriorityMiddleware();
    const req = {
      originalUrl: '/api/auth/refresh',
      headers: { origin: 'http://localhost:5173' },
    };
    const res = {};

    let called = false;
    middleware(req, res, () => {
      called = true;
    });
    assert.strictEqual(called, true);
    assert.strictEqual(req.isAdmin, false, 'Origin tự khai KHÔNG được cấp req.isAdmin');
    assert.strictEqual(req.isAdminWebClient, true);
  });

  await t.test('16. Khóa khẩn cấp x-emergency-admin-key: Đúng khóa cấp true, sai khóa cấp false', () => {
    const middleware = createAdminPriorityMiddleware({ emergencyKey: 'my-super-secret-key-12345' });
    const reqCorrect = {
      originalUrl: '/api/transactions',
      headers: { 'x-emergency-admin-key': 'my-super-secret-key-12345' },
    };
    const reqWrong = {
      originalUrl: '/api/transactions',
      headers: { 'x-emergency-admin-key': 'wrong-key-attempt' },
    };

    middleware(reqCorrect, {}, () => {});
    assert.strictEqual(reqCorrect.isAdmin, true, 'Đúng khóa khẩn cấp phải được cấp isAdmin');

    middleware(reqWrong, {}, () => {});
    assert.strictEqual(reqWrong.isAdmin, false, 'Sai khóa khẩn cấp không được cấp isAdmin');
  });

  await t.test('17. Route POST /api/auth/login được phép đi qua lớp bảo trì; query string x=/auth/login hay method GET bị chặn 503', () => {
    const mgr = new MaintenanceManager();
    mgr.setMaintenance(true, 'Hệ thống bảo trì', 'admin-01');
    const middleware = createMaintenanceMiddleware({ manager: mgr });

    // 17a. POST /api/auth/login -> Được qua
    const reqLogin = { originalUrl: '/api/auth/login', path: '/api/auth/login', method: 'POST', headers: {}, isAdmin: false };
    let passed = false;
    middleware(reqLogin, {}, () => { passed = true; });
    assert.strictEqual(passed, true, 'POST /api/auth/login được đi qua');

    // 17b. GET /api/auth/login -> Bị chặn 503
    let getBlocked = false;
    middleware({ originalUrl: '/api/auth/login', path: '/api/auth/login', method: 'GET', isAdmin: false }, {
      setHeader: () => {},
      status: (code) => {
        if (code === 503) getBlocked = true;
        return { json: () => {} };
      }
    }, () => {});
    assert.strictEqual(getBlocked, true, 'GET /api/auth/login phải bị chặn 503');

    // 17c. Query string lách bảo trì -> Bị chặn 503
    let bypassBlocked = false;
    middleware({ originalUrl: '/api/sync/push?x=/auth/login', path: '/api/sync/push', method: 'GET', isAdmin: false }, {
      setHeader: () => {},
      status: (code) => {
        if (code === 503) bypassBlocked = true;
        return { json: () => {} };
      }
    }, () => {});
    assert.strictEqual(bypassBlocked, true, 'Lách query string ?x=/auth/login phải bị chặn 503');
  });

  await t.test('18. auth.service.login: Bảo trì BẬT + tài khoản User thường đúng mật khẩu -> Từ chối với 503 MAINTENANCE_MODE', async () => {
    const { defaultMaintenanceManager } = require('../../core/resilience/maintenance.manager');
    defaultMaintenanceManager.setMaintenance(true, 'Bảo trì khẩn cấp', 'admin');
    const hashed = await bcrypt.hash('CorrectPass123!', 4);
    const userAcc = {
      idaccount: 101,
      username: 'test_user',
      password: hashed,
      status: 'Active',
      idrole: 2,
      role: { idrole: 2, rolename: 'user' },
      User: { iduser: 101, fullname: 'Test User', email: 'test@example.com' },
      delete_at: null,
      countdown: null,
    };

    const origFind = authRepository.findAccountsByUsername;
    authRepository.findAccountsByUsername = async () => [userAcc];

    try {
      await assert.rejects(
        async () => {
          await authService.login('test_user', 'CorrectPass123!');
        },
        (err) => {
          assert.strictEqual(err.statusCode, 503);
          assert.strictEqual(err.code, 'MAINTENANCE_MODE');
          return true;
        }
      );
    } finally {
      authRepository.findAccountsByUsername = origFind;
      defaultMaintenanceManager.setMaintenance(false);
    }
  });

  await t.test('19. auth.service.login: Bảo trì BẬT + tài khoản Admin đúng mật khẩu -> Cho phép đăng nhập thành công', async () => {
    const { defaultMaintenanceManager } = require('../../core/resilience/maintenance.manager');
    defaultMaintenanceManager.setMaintenance(true, 'Bảo trì khẩn cấp', 'admin');
    const hashed = await bcrypt.hash('CorrectPass123!', 4);
    const adminAcc = {
      idaccount: 1,
      username: 'test_admin',
      password: hashed,
      status: 'Active',
      idrole: 1,
      role: { idrole: 1, rolename: 'admin' },
      User: { iduser: 1, fullname: 'Test Admin', email: 'admin@example.com' },
      delete_at: null,
      countdown: null,
    };

    const origFind = authRepository.findAccountsByUsername;
    const origSave = authRepository.saveRefreshToken;
    authRepository.findAccountsByUsername = async () => [adminAcc];
    authRepository.saveRefreshToken = async () => ({ idtoken: 1 });

    try {
      const res = await authService.login('test_admin', 'CorrectPass123!');
      assert.ok(res.accessToken, 'Phải trả về accessToken cho Admin');
      assert.ok(res.refreshToken, 'Phải trả về refreshToken cho Admin');
      assert.strictEqual(res.user.idaccount, 1);
      assert.strictEqual(res.user.rolename, 'admin');
    } finally {
      authRepository.findAccountsByUsername = origFind;
      authRepository.saveRefreshToken = origSave;
      defaultMaintenanceManager.setMaintenance(false);
    }
  });

  await t.test('20. auth.service.login: Bảo trì BẬT + sai mật khẩu -> Trả về 401 (không làm lộ trạng thái bảo trì trước khi xác thực)', async () => {
    const { defaultMaintenanceManager } = require('../../core/resilience/maintenance.manager');
    defaultMaintenanceManager.setMaintenance(true, 'Bảo trì khẩn cấp', 'admin');
    const hashed = await bcrypt.hash('CorrectPass123!', 4);
    const userAcc = {
      idaccount: 101,
      username: 'test_user',
      password: hashed,
      status: 'Active',
      idrole: 2,
      role: { idrole: 2, rolename: 'user' },
      User: { iduser: 101, fullname: 'Test User', email: 'test@example.com' },
      delete_at: null,
      countdown: null,
    };

    const origFind = authRepository.findAccountsByUsername;
    authRepository.findAccountsByUsername = async () => [userAcc];

    try {
      await assert.rejects(
        async () => {
          await authService.login('test_user', 'WrongPass!');
        },
        (err) => {
          assert.strictEqual(err.statusCode, 401);
          return true;
        }
      );
    } finally {
      authRepository.findAccountsByUsername = origFind;
      defaultMaintenanceManager.setMaintenance(false);
    }
  });

  try {
    const { pool, prisma } = require('../../config/db');
    if (pool && typeof pool.end === 'function') {
      await pool.end();
    }
    if (prisma && typeof prisma.$disconnect === 'function') {
      await prisma.$disconnect();
    }
  } catch (_) {}

  setTimeout(() => process.exit(0), 50);
});
