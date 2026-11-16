const test = require('node:test');
const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
const { AIOpsQuarantine, defaultAIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');

test('AIOps Active Quarantine & Mitigation Suite', async (t) => {
  await t.test('1. Quarantine registers IP, sets expiration, and records reason', () => {
    const q = new AIOpsQuarantine({ defaultDurationMs: 60000 });
    const ip = '203.162.10.45';

    q.quarantine(ip, 'Tấn công DoS quá ngưỡng request', 60000);

    const check = q.isQuarantined(ip);
    assert.strictEqual(check.quarantined, true);
    assert.strictEqual(check.reason, 'Tấn công DoS quá ngưỡng request');
    assert.ok(check.expiresAt > Date.now());
    assert.strictEqual(check.hits, 1);
  });

  await t.test('2. Expired quarantine entries auto-evict and allow traffic', () => {
    const q = new AIOpsQuarantine();
    const ip = '1.2.3.4';

    // Quarantine with past expiration
    q.quarantine(ip, 'Thử nghiệm hết hạn', -1000);

    const check = q.isQuarantined(ip);
    assert.strictEqual(check.quarantined, false, 'Expired IP must be considered unblocked');
  });

  await t.test('3. unblock removes IP from quarantine list', () => {
    const q = new AIOpsQuarantine();
    const ip = '113.161.88.99';

    q.quarantine(ip, 'SQL Injection probe');
    assert.strictEqual(q.isQuarantined(ip).quarantined, true);

    const list = q.getQuarantinedList();
    assert.strictEqual(list.length, 1);
    const hash = list[0].hash;

    const unblocked = q.unblock(hash);
    assert.strictEqual(unblocked, true);
    assert.strictEqual(q.isQuarantined(ip).quarantined, false);
  });

  await t.test('4. getQuarantinedList returns masked IP for privacy compliance', () => {
    const q = new AIOpsQuarantine();
    const ip = '192.168.1.100';

    q.quarantine(ip, 'Dò mật khẩu Brute-Force');
    const list = q.getQuarantinedList();

    assert.strictEqual(list.length, 1);
    assert.strictEqual(list[0].maskedIp, '192.168.xxx.xxx', 'IP must be masked to respect Data Security');
    assert.strictEqual(list[0].reason, 'Dò mật khẩu Brute-Force');
    assert.ok(list[0].hash, 'Hash key must exist for admin unblocking action');
  });

  await t.test('5. Middleware rejects quarantined client with HTTP 403 AIOPS_QUARANTINED', () => {
    const q = new AIOpsQuarantine();
    const mw = q.createMiddleware();
    const ip = '10.20.30.40';

    q.quarantine(ip, 'Phát hiện mã độc');

    const req = {
      ip,
      headers: {},
      method: 'POST',
      url: '/api/transactions',
      isAdmin: false,
    };

    let statusCode = null;
    let jsonBody = null;
    let nextCalled = false;

    const res = {
      status: (code) => {
        statusCode = code;
        return {
          json: (body) => {
            jsonBody = body;
          },
        };
      },
    };

    mw(req, res, () => { nextCalled = true; });

    assert.strictEqual(nextCalled, false, 'next() must NOT be called for blocked IP');
    assert.strictEqual(statusCode, 403);
    assert.strictEqual(jsonBody.success, false);
    assert.strictEqual(jsonBody.code, 'AIOPS_QUARANTINED');
    assert.strictEqual(jsonBody.error, 'AIOPS_QUARANTINED');
    assert.ok(jsonBody.message.includes('phong tỏa'));
  });

  // Đổi nghiệp vụ 2026-11-16 (mục 2.5 kế hoạch sửa trang AIOps): IP bị khoá thì chặn cả admin.
  await t.test('6. Admin đã xác thực (req.isAdmin = true) đi từ IP đang khoá vẫn bị chặn 403', () => {
    const q = new AIOpsQuarantine();
    const mw = q.createMiddleware();
    const ip = '118.69.12.34';
    q.quarantine(ip, 'Test quarantine');
    const req = { ip, headers: {}, method: 'GET', url: '/api/admin/system/health', isAdmin: true };

    let statusCode = null;
    let jsonBody = null;
    const res = { status: (code) => { statusCode = code; return { json: (body) => { jsonBody = body; } }; } };
    let nextCalled = false;
    mw(req, res, () => { nextCalled = true; });

    assert.strictEqual(nextCalled, false, 'Admin không được đi qua IP đang khoá');
    assert.strictEqual(statusCode, 403);
    assert.strictEqual(jsonBody.code, 'AIOPS_QUARANTINED');
  });

  await t.test('7. Emits Socket.io admin.security_blocked event upon quarantining an IP', () => {
    let emittedEvent = null;
    let emittedData = null;

    const mockIo = {
      to: (room) => {
        assert.strictEqual(room, 'admin_room');
        return {
          emit: (event, data) => {
            emittedEvent = event;
            emittedData = data;
          },
        };
      },
    };

    const q = new AIOpsQuarantine({ io: mockIo });
    q.quarantine('118.69.12.34', 'DDoS Attack Burst', 60000);

    assert.strictEqual(emittedEvent, 'admin.security_blocked');
    assert.strictEqual(emittedData.maskedIp, '118.69.xxx.xxx');
    assert.strictEqual(emittedData.reason, 'DDoS Attack Burst');
  });

  await t.test('8. unquarantine(rawIp) unblocks IP directly without needing hash', () => {
    const q = new AIOpsQuarantine();
    const ip = '14.161.22.33';

    q.quarantine(ip, 'Testing direct unquarantine');
    assert.strictEqual(q.isQuarantined(ip).quarantined, true);

    const result = q.unquarantine(ip);
    assert.strictEqual(result, true);
    assert.strictEqual(q.isQuarantined(ip).quarantined, false);
  });

  await t.test('9. POST /api/auth/login with admin username from quarantined IP MUST BE BLOCKED (HTTP 403)', () => {
    const q = new AIOpsQuarantine();
    const mw = q.createMiddleware();
    const ip = '14.161.22.33';

    q.quarantine(ip, 'Quarantined Brute-Force IP');

    const req = {
      ip,
      headers: {},
      method: 'POST',
      originalUrl: '/api/auth/login',
      path: '/api/auth/login',
      body: { username: 'admin', password: 'SecretPassword123' },
      isAdmin: false,
    };

    let statusCode = null;
    let jsonBody = null;
    const res = {
      status: (code) => {
        statusCode = code;
        return {
          json: (body) => { jsonBody = body; },
        };
      },
    };

    let nextCalled = false;
    mw(req, res, () => { nextCalled = true; });

    assert.strictEqual(nextCalled, false, 'Quarantined IP cannot bypass quarantine by guessing admin username');
    assert.strictEqual(statusCode, 403);
    assert.strictEqual(jsonBody.code, 'AIOPS_QUARANTINED');
  });

  await t.test('10. Requests with req.isAdminWebClient = true from quarantined IP MUST BE BLOCKED (HTTP 403)', () => {
    const q = new AIOpsQuarantine();
    const mw = q.createMiddleware();
    const ip = '14.161.22.33';

    q.quarantine(ip, 'Quarantined IP');

    const req = {
      ip,
      headers: { 'x-client-platform': 'admin-web' },
      method: 'POST',
      originalUrl: '/api/auth/login',
      isAdminWebClient: true,
      isAdmin: false,
    };

    let statusCode = null;
    let jsonBody = null;
    const res = {
      status: (code) => {
        statusCode = code;
        return {
          json: (body) => { jsonBody = body; },
        };
      },
    };

    let nextCalled = false;
    mw(req, res, () => { nextCalled = true; });

    assert.strictEqual(nextCalled, false, 'Client self-declared header must NOT bypass quarantine');
    assert.strictEqual(statusCode, 403);
    assert.strictEqual(jsonBody.code, 'AIOPS_QUARANTINED');
  });

  await t.test('11. Đăng nhập với token admin hợp lệ (req.isAdmin = true) từ IP đang khoá vẫn bị chặn', () => {
    const q = new AIOpsQuarantine();
    const mw = q.createMiddleware();
    const ip = '14.161.22.33';
    q.quarantine(ip, 'Quarantined IP');
    const req = { ip, headers: {}, method: 'POST', originalUrl: '/api/auth/login', isAdmin: true };

    let statusCode = null;
    let jsonBody = null;
    const res = { status: (code) => { statusCode = code; return { json: (body) => { jsonBody = body; } }; } };
    let nextCalled = false;
    mw(req, res, () => { nextCalled = true; });

    assert.strictEqual(nextCalled, false);
    assert.strictEqual(statusCode, 403);
  });

  await t.test('12. Trusted IPs configured via process.env.ADMIN_TRUSTED_IPS are protected from quarantine', () => {
    const originalEnv = process.env.ADMIN_TRUSTED_IPS;
    try {
      process.env.ADMIN_TRUSTED_IPS = '192.168.1.55,10.0.0.1';
      const q = new AIOpsQuarantine();

      assert.strictEqual(q.isProtectedIp('192.168.1.55'), true, 'Configured static IP must be protected');
      assert.strictEqual(q.isProtectedIp('10.0.0.1'), true, 'Configured static IP must be protected');

      const result = q.quarantine('192.168.1.55', 'Test blocking static trusted IP');
      assert.strictEqual(result, null, 'Must reject quarantining static trusted IP');
      assert.strictEqual(q.isQuarantined('192.168.1.55').quarantined, false);
    } finally {
      process.env.ADMIN_TRUSTED_IPS = originalEnv;
    }
  });

  await t.test('13. Không còn cơ chế phiên admin tự miễn khoá IP', () => {
    const q = new AIOpsQuarantine();
    assert.strictEqual(typeof q.registerAdminSession, 'undefined');
    assert.strictEqual(typeof q.unregisterAdminSession, 'undefined');
    assert.strictEqual(typeof q.getActiveAdminIps, 'undefined');
  });

  await t.test('14. IP từng có admin dùng vẫn khoá được (khoá tự động lẫn khoá tay)', () => {
    const q = new AIOpsQuarantine();
    const officeIp = '14.241.11.22';
    assert.strictEqual(q.isProtectedIp(officeIp), false);
    assert.ok(q.quarantine(officeIp, 'Brute force probe from coffee wifi'));
    assert.strictEqual(q.isQuarantined(officeIp).quarantined, true);
  });

  await t.test('15. Admin đăng nhập thành công không gỡ khoá IP đang có', async () => {
    const authService = require('../../modules/auth/auth.service');
    const src = require('fs').readFileSync(require.resolve('../../modules/auth/auth.service'), 'utf8')
      + require('fs').readFileSync(require.resolve('../../modules/auth/auth.controller'), 'utf8');
    assert.ok(authService);
    assert.strictEqual(/registerAdminSession|unregisterAdminSession/.test(src), false, 'đăng nhập / đăng xuất không còn đụng tới khoá IP');
  });

  await t.test('16. [43.A3] getQuarantinedList chỉ mở khóa tài khoản AIOps cách ly, không can thiệp tài khoản Admin khóa tay', async () => {
    const q = new AIOpsQuarantine();
    let syncCalledWithOptions = null;
    q._syncAccountStatusToDatabase = async (idOrUser, status, reason, options) => {
      syncCalledWithOptions = options;
    };

    // Tạo bản ghi hết hạn cách ly
    q._pairs.set('user:hacker', {
      ipStatus: 'unlocked',
      ipExpiresAt: null,
      accountStatus: 'temporary',
      accountExpiresAt: Date.now() - 5000, // Đã hết hạn
      idaccount: 99,
      username: 'hacker',
    });

    q.getQuarantinedList();

    assert.ok(syncCalledWithOptions, 'Phải gọi _syncAccountStatusToDatabase');
    assert.strictEqual(syncCalledWithOptions.onlyAIOpsLocked, true, 'Bắt buộc truyền onlyAIOpsLocked: true để bảo vệ khóa tay của Admin');
  });
});
