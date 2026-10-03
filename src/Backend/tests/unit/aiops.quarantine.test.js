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
    assert.strictEqual(list[0].maskedIp, '192.168.xx.xx', 'IP must be masked to respect Data Security');
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
    assert.strictEqual(jsonBody.error, 'AIOPS_QUARANTINED');
    assert.ok(jsonBody.message.includes('phong tỏa'));
  });

  await t.test('6. Admin requests (req.isAdmin = true) are NEVER blocked even if originating from same IP', () => {
    const q = new AIOpsQuarantine();
    const mw = q.createMiddleware();
    const ip = '127.0.0.1';

    q.quarantine(ip, 'Test quarantine');

    const req = {
      ip,
      headers: {},
      method: 'GET',
      url: '/api/admin/system/health',
      isAdmin: true, // Fast-lane admin
    };

    let nextCalled = false;
    mw(req, {}, () => { nextCalled = true; });

    assert.strictEqual(nextCalled, true, 'Admin request must bypass quarantine 100%');
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
    assert.strictEqual(emittedData.maskedIp, '118.69.xx.xx');
    assert.strictEqual(emittedData.reason, 'DDoS Attack Burst');
  });
});
