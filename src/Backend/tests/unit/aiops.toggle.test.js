/**
 * AIOps tạm dừng bằng công tắc AIOPS_ENABLED (2026-11-17).
 * Đặc tả: docs/Admin-web/09-aiops-sentinel-and-quarantine.md, mục "Trạng thái: tạm dừng".
 * - Mặc định tắt: không thu thập chỉ số, không chặn IP cách ly, /admin/aiops/* trả 404 AIOPS_DISABLED,
 *   không chạy vòng đo 10 giây.
 * - Khi tắt vẫn nạp danh sách phong toả để bộ quét hết hạn mở các tài khoản đang bị khoá tạm.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const EventEmitter = require('node:events');

const toggle = require('../../modules/aiops/aiops.toggle');
const { AIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');

const withEnv = async (value, fn) => {
  const old = process.env.AIOPS_ENABLED;
  if (value === undefined) delete process.env.AIOPS_ENABLED;
  else process.env.AIOPS_ENABLED = value;
  try {
    return await fn();
  } finally {
    if (old === undefined) delete process.env.AIOPS_ENABLED;
    else process.env.AIOPS_ENABLED = old;
  }
};

const fakeRes = () => {
  const res = new EventEmitter();
  res.statusCode = 200;
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  return res;
};

test('AIOps tạm dừng — công tắc AIOPS_ENABLED', async (t) => {
  await t.test('isAiopsEnabled: chỉ bật khi AIOPS_ENABLED = true', () => {
    assert.strictEqual(toggle.isAiopsEnabled({}), false, 'Không đặt biến ⇒ tắt');
    assert.strictEqual(toggle.isAiopsEnabled({ AIOPS_ENABLED: 'false' }), false);
    assert.strictEqual(toggle.isAiopsEnabled({ AIOPS_ENABLED: '' }), false);
    assert.strictEqual(toggle.isAiopsEnabled({ AIOPS_ENABLED: 'true' }), true);
    assert.strictEqual(toggle.isAiopsEnabled({ AIOPS_ENABLED: 'TRUE' }), true);
  });

  await t.test('aiopsGated: tắt thì bỏ qua middleware, bật thì chạy', async () => {
    let calls = 0;
    const gated = toggle.aiopsGated(() => { calls += 1; });
    await withEnv(undefined, () => {
      let nexted = false;
      gated({}, fakeRes(), () => { nexted = true; });
      assert.strictEqual(calls, 0);
      assert.strictEqual(nexted, true);
    });
    await withEnv('true', () => {
      gated({}, fakeRes(), () => {});
      assert.strictEqual(calls, 1);
    });
  });

  await t.test('IP đang bị cách ly: tắt thì đi qua, bật thì 403 AIOPS_QUARANTINED', async () => {
    const q = new AIOpsQuarantine({ repository: null, autoExpire: false });
    q.quarantine('203.0.113.9', 'thử', 60000);
    const gated = toggle.aiopsGated(q.createMiddleware());
    const req = { ip: '203.0.113.9', headers: {}, method: 'GET', path: '/api/x', originalUrl: '/api/x' };

    await withEnv(undefined, () => {
      const res = fakeRes();
      let nexted = false;
      gated(req, res, () => { nexted = true; });
      assert.strictEqual(nexted, true, 'AIOps tắt ⇒ không chặn IP');
      assert.strictEqual(res.statusCode, 200);
    });
    await withEnv('true', () => {
      const res = fakeRes();
      gated(req, res, () => {});
      assert.strictEqual(res.statusCode, 403);
      assert.strictEqual(res.body.code, 'AIOPS_QUARANTINED');
    });
  });

  await t.test('aiopsRouteGate: tắt thì 404 AIOPS_DISABLED, bật thì đi tiếp', async () => {
    await withEnv(undefined, () => {
      const res = fakeRes();
      let nexted = false;
      toggle.aiopsRouteGate({}, res, () => { nexted = true; });
      assert.strictEqual(nexted, false);
      assert.strictEqual(res.statusCode, 404);
      assert.strictEqual(res.body.success, false);
      assert.strictEqual(res.body.code, 'AIOPS_DISABLED');
    });
    await withEnv('true', () => {
      let nexted = false;
      toggle.aiopsRouteGate({}, fakeRes(), () => { nexted = true; });
      assert.strictEqual(nexted, true);
    });
  });

  await t.test('admin.routes: cổng AIOps đứng trước mọi route /aiops', () => {
    const router = require('../../api/admin.routes');
    const idxGate = router.stack.findIndex((l) => l.handle === toggle.aiopsRouteGate);
    const idxFirstAiops = router.stack.findIndex((l) => l.route && String(l.route.path).startsWith('/aiops'));
    assert.ok(idxGate >= 0, 'Phải gắn aiopsRouteGate');
    assert.ok(idxGate < idxFirstAiops, 'Cổng phải đứng trước route /aiops đầu tiên');
    assert.ok(router.stack[idxGate].regexp.test('/aiops/status'), 'Cổng chỉ áp cho /aiops');
    assert.ok(!router.stack[idxGate].regexp.test('/users'), 'Cổng không chặn route khác');
  });

  await t.test('startAiops: tắt thì không chạy vòng đo nhưng vẫn nạp phong toả (bộ quét hết hạn mở khoá tạm)', async () => {
    const log = [];
    const deps = {
      service: { start: () => log.push('service.start') },
      quarantine: { hydrateFromDatabase: async () => log.push('hydrate') },
      repository: { initTables: async () => log.push('initTables') },
    };
    await withEnv(undefined, () => toggle.startAiops(deps));
    assert.deepStrictEqual(log, ['initTables', 'hydrate']);

    log.length = 0;
    await withEnv('true', () => toggle.startAiops(deps));
    assert.deepStrictEqual(log, ['service.start', 'initTables', 'hydrate']);
  });
});
