/**
 * Dọn route quản trị không còn nơi gọi (2026-11-14):
 * - DELETE /aiops/quarantine/:hash: gỡ chặn không qua PIN, Admin-web dùng unblock-ip / unblock-account.
 * - GET /payments/payos-qr: không màn hình nào gọi.
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');

const router = require('../../api/admin.routes');
const routeKeys = router.stack
  .filter((l) => l.route)
  .flatMap((l) => Object.keys(l.route.methods).map((m) => `${m.toUpperCase()} ${l.route.path}`));

describe('Route quản trị đã dọn', () => {
  it('không còn DELETE /aiops/quarantine/:hash; vẫn còn gỡ chặn có kiểm soát', () => {
    assert.ok(!routeKeys.includes('DELETE /aiops/quarantine/:hash'));
    assert.ok(routeKeys.includes('POST /aiops/quarantine/unblock-ip'));
    assert.ok(routeKeys.includes('POST /aiops/quarantine/unblock-account'));
  });

  it('không còn GET /payments/payos-qr; đơn thanh toán admin vẫn còn', () => {
    assert.ok(!routeKeys.includes('GET /payments/payos-qr'));
    assert.ok(routeKeys.includes('GET /payments/orders'));
  });

  it('controller không còn hàm của route đã bỏ', () => {
    assert.strictEqual(require('../../modules/aiops/aiops.controller').unblockQuarantine, undefined);
    assert.strictEqual(require('../../modules/payment/payment.controller').getPayosQr, undefined);
  });
});
