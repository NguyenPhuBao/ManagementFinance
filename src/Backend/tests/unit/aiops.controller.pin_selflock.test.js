/**
 * Mục 2.3 – 2.4 kế hoạch sửa trang AIOps:
 * - Mọi thao tác ghi trên trang AIOps đòi PIN (máy chủ kiểm qua adminService.verifySecurityAction); thiếu / sai PIN
 *   thì từ chối và không thay đổi gì.
 * - Admin không tự khoá tài khoản của chính mình (403 CANNOT_LOCK_SELF); khoá admin khác thì được.
 * - "Khóa thêm 4 giờ" IP có route riêng extend-ip; route cũ permanent-ip trỏ cùng hàm.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const controller = require('../../modules/aiops/aiops.controller');
const adminService = require('../../modules/admin/admin.service');
const { defaultAIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
const { defaultAIOpsService } = require('../../modules/aiops/aiops.service');

const GOOD_PIN = '246810';
const ME = { idaccount: 7, username: 'admin.a', idrole: 1 };

const fakeRes = () => {
  const res = { code: null, body: null, headers: {} };
  res.status = (c) => { res.code = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  res.set = (k, v) => { res.headers[k] = v; return res; };
  return res;
};
const call = async (method, body = {}, user = ME) => {
  const req = { body, params: {}, query: {}, user, headers: {} };
  const res = fakeRes();
  await controller[method](req, res);
  return res;
};

// Thao tác ghi: [tên hàm controller, body hợp lệ, [đối tượng, tên hàm thật bị gọi]]
const WRITES = [
  ['toggleVector', { vector: 'auth', enabled: false }, [defaultAIOpsService, 'toggleVector']],
  ['calibrate', { targetConcurrency: 1000, customThresholds: {} }, [defaultAIOpsService, 'calibrate']],
  ['setScale', { concurrency: 2000 }, [defaultAIOpsService, 'setConcurrencyScale']],
  ['quarantineActor', { ip: '198.51.100.7', durationMinutes: 60 }, [defaultAIOpsQuarantine, 'quarantineActor']],
  ['unblockIp', { ipHash: 'h-1' }, [defaultAIOpsQuarantine, 'unblockIp']],
  ['extendIp', { ipHash: 'h-1' }, [defaultAIOpsQuarantine, 'extendIp']],
  ['permanentBanIp', { ipHash: 'h-1' }, [defaultAIOpsQuarantine, 'extendIp']],
  ['temporaryBlockIp', { ipHash: 'h-1' }, [defaultAIOpsQuarantine, 'temporaryBlockIp']],
  ['unblockAccount', { username: 'binh' }, [defaultAIOpsQuarantine, 'unblockAccount']],
  ['permanentBanAccount', { username: 'binh' }, [defaultAIOpsQuarantine, 'permanentBanAccount']],
  ['temporaryBlockAccount', { username: 'binh' }, [defaultAIOpsQuarantine, 'temporaryBlockAccount']],
];

test('AIOps controller — PIN cho mọi thao tác ghi và chặn tự khoá (mục 2.3, 2.4)', async (t) => {
  const saved = [];
  const stub = (obj, name, fn) => { saved.push([obj, name, obj[name]]); obj[name] = fn; };
  const calls = [];
  stub(adminService, 'verifySecurityAction', async ({ pin, action }) => {
    if (pin !== GOOD_PIN) throw Object.assign(new Error('Mã PIN không đúng'), { statusCode: 403 });
    calls.push(['PIN', action]);
    return { verified: true };
  });
  for (const [, , [obj, name]] of WRITES) {
    if (saved.some(([o, n]) => o === obj && n === name)) continue;
    stub(obj, name, async (...args) => { calls.push([name, args]); return name === 'quarantineActor' ? { maskedIp: '198.51.xxx.xxx' } : { message: 'ok', targetConcurrency: 2000 }; });
  }
  stub(defaultAIOpsQuarantine, '_resolveAccount', async (v) => {
    const s = String(v).toLowerCase();
    if (s === 'admin.a' || s === '7') return { idaccount: 7, username: 'admin.a', idrole: 1 };
    if (s === 'admin.b' || s === '8') return { idaccount: 8, username: 'admin.b', idrole: 1 };
    return { idaccount: 11, username: 'binh', idrole: 2 };
  });
  t.after(() => saved.reverse().forEach(([obj, name, fn]) => { obj[name] = fn; }));
  t.beforeEach(() => { calls.length = 0; });

  for (const [method, body, [, target]] of WRITES) {
    await t.test(`${method}: thiếu PIN → từ chối, không gọi ${target}`, async () => {
      const res = await call(method, body);
      assert.ok(res.code >= 400 && res.code < 500, `mã ${res.code}`);
      assert.equal(calls.some(([n]) => n === target), false);
    });
    await t.test(`${method}: sai PIN → từ chối, không gọi ${target}`, async () => {
      const res = await call(method, { ...body, pin: '000000' });
      assert.equal(res.code, 403);
      assert.equal(calls.some(([n]) => n === target), false);
    });
    await t.test(`${method}: đúng PIN → thực hiện`, async () => {
      const res = await call(method, { ...body, pin: GOOD_PIN });
      assert.ok(res.code < 300, `mã ${res.code}: ${res.body?.message}`);
      assert.ok(calls.some(([n]) => n === 'PIN'));
      assert.ok(calls.some(([n]) => n === target), `phải gọi ${target}`);
    });
  }

  for (const method of ['temporaryBlockAccount', 'permanentBanAccount']) {
    await t.test(`${method}: tự khoá chính mình (theo tên, khác hoa thường) → 403 CANNOT_LOCK_SELF`, async () => {
      const res = await call(method, { username: 'ADMIN.A', pin: GOOD_PIN });
      assert.equal(res.code, 403);
      assert.equal(res.body.code, 'CANNOT_LOCK_SELF');
      assert.equal(calls.some(([n]) => n === method), false);
    });
    await t.test(`${method}: tự khoá chính mình (theo mã tài khoản) → 403 CANNOT_LOCK_SELF`, async () => {
      const res = await call(method, { idaccount: 7, pin: GOOD_PIN });
      assert.equal(res.body.code, 'CANNOT_LOCK_SELF');
    });
    await t.test(`${method}: khoá admin khác → được`, async () => {
      const res = await call(method, { username: 'admin.b', pin: GOOD_PIN });
      assert.ok(res.code < 300);
      assert.ok(calls.some(([n]) => n === method));
    });
  }

  await t.test('khoá tay tài khoản qua quarantineActor (username = chính mình) cũng bị chặn', async () => {
    const res = await call('quarantineActor', { username: 'admin.a', ip: '198.51.100.7', pin: GOOD_PIN });
    assert.equal(res.body.code, 'CANNOT_LOCK_SELF');
  });

  await t.test('thao tác chỉ đọc không đòi PIN: danh sách khoá đọc từ kho lưu (listQuarantines)', async () => {
    stub(defaultAIOpsQuarantine, 'listQuarantines', async () => [{ id: 'x', username: 'binh', accountStatus: 'unlocked' }]);
    const res = await call('getQuarantineList', {});
    assert.equal(res.code, 200);
    assert.deepEqual(res.body.data, [{ id: 'x', username: 'binh', accountStatus: 'unlocked' }]);
  });

  await t.test('route extend-ip được khai báo, route cũ permanent-ip còn giữ', () => {
    const router = require('../../api/admin.routes');
    const paths = router.stack.filter((l) => l.route).map((l) => `${Object.keys(l.route.methods)[0]} ${l.route.path}`);
    assert.ok(paths.includes('post /aiops/quarantine/extend-ip'));
    assert.ok(paths.includes('post /aiops/quarantine/permanent-ip'));
  });
});
