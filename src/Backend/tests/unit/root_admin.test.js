/**
 * Phần 3 kế hoạch sửa trang AIOps — tài khoản quản trị gốc (Chủ dự án chốt 2026-11-16):
 * - Nhận diện bằng email cố định admin@wealthcommand.com (trùng trigger CSDL 56), không thêm cột vào account.
 * - Đăng nhập hai bước: mật khẩu (CSDL) + khoá thứ hai ROOT_ADMIN_SECOND_KEY (.env). Thiếu biến → không đăng nhập được.
 * - Phiên mang dấu vân tay khoá; đổi khoá trong .env thì phiên cũ bị từ chối (middleware và làm mới token).
 * - Không ai khoá được tài khoản gốc (AIOps khoá tay / tự khoá); request của tài khoản gốc đi qua lớp chặn IP.
 * - Mỗi lần tài khoản gốc đăng nhập thành công: gửi email cảnh báo.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const config = require('../../config');
const { prisma } = require('../../config/db');
const rootAdmin = require('../../modules/auth/root-admin');
const authRepository = require('../../modules/auth/auth.repository');
const authService = require('../../modules/auth/auth.service');
const emailService = require('../../core/email.service');
const { authenticate } = require('../../middleware/auth');
const { AIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');

const ROOT_EMAIL = 'admin@wealthcommand.com';
const PASSWORD = 'Root@2026x';
const KEY = 'khoa-thu-hai-rat-dai-0123456789';

const fakeRes = () => {
  const res = { code: null, body: null };
  res.status = (c) => { res.code = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  res.setHeader = () => res;
  res.set = () => res;
  return res;
};

test('Tài khoản quản trị gốc (Phần 3)', async (t) => {
  const saved = [];
  const stub = (obj, name, fn) => { saved.push([obj, name, obj[name]]); obj[name] = fn; };
  const savedEnv = { key: process.env.ROOT_ADMIN_SECOND_KEY, user: process.env.ROOT_ADMIN_USERNAME, alert: process.env.ADMIN_ALERT_EMAIL };
  t.after(() => {
    saved.reverse().forEach(([obj, name, fn]) => { obj[name] = fn; });
    for (const [k, v] of [['ROOT_ADMIN_SECOND_KEY', savedEnv.key], ['ROOT_ADMIN_USERNAME', savedEnv.user], ['ADMIN_ALERT_EMAIL', savedEnv.alert]]) {
      if (v === undefined) delete process.env[k]; else process.env[k] = v;
    }
  });
  t.beforeEach(() => {
    process.env.ROOT_ADMIN_SECOND_KEY = KEY;
    process.env.ROOT_ADMIN_USERNAME = 'admin';
    process.env.ADMIN_ALERT_EMAIL = 'canhbao@example.com';
  });

  const hash = await bcrypt.hash(PASSWORD, 4);
  const account = (over = {}) => ({
    idaccount: 1, idrole: 1, email: ROOT_EMAIL, username: 'admin', password: hash, status: 'Active', type: 'Basic',
    countdown: null, delete_at: null, is_first_login: false, role: { idrole: 1, rolename: 'Admin' }, User: null, ...over,
  });
  let accounts = [account()];
  stub(authRepository, 'findAccountsByUsername', async () => accounts);
  stub(prisma.refreshtoken, 'create', async () => ({}));
  const mails = [];
  stub(emailService, 'sendMail', async (m) => { mails.push(m); });

  const loginReq = (body) => ({ body, headers: {}, ip: '203.0.113.5', socket: {} });
  const loginErr = async (body) => {
    try {
      await authService.login(body.username, body.password, loginReq(body));
      return null;
    } catch (err) {
      return err;
    }
  };

  await t.test('1. Nhận diện theo email cố định, không phân biệt hoa thường', () => {
    assert.equal(rootAdmin.ROOT_ADMIN_EMAIL, ROOT_EMAIL);
    assert.equal(rootAdmin.isRootAccount({ email: 'Admin@WealthCommand.com' }), true);
    assert.equal(rootAdmin.isRootAccount({ email: 'admin.b@wealthcommand.com' }), false);
    assert.equal(rootAdmin.isRootAccount(null), false);
  });

  await t.test('2. Đúng mật khẩu nhưng thiếu khoá thứ hai → 401 ROOT_KEY_REQUIRED, không cấp token', async () => {
    const err = await loginErr({ username: 'admin', password: PASSWORD });
    assert.equal(err?.statusCode, 401);
    assert.equal(err.code, 'ROOT_KEY_REQUIRED');
  });

  await t.test('3. Sai khoá thứ hai → 401 ROOT_KEY_INVALID', async () => {
    const err = await loginErr({ username: 'admin', password: PASSWORD, rootKey: 'sai' });
    assert.equal(err?.statusCode, 401);
    assert.equal(err.code, 'ROOT_KEY_INVALID');
  });

  await t.test('4. Máy chủ chưa đặt ROOT_ADMIN_SECOND_KEY → tài khoản gốc không đăng nhập được', async () => {
    delete process.env.ROOT_ADMIN_SECOND_KEY;
    const err = await loginErr({ username: 'admin', password: PASSWORD, rootKey: KEY });
    assert.equal(err?.code, 'ROOT_KEY_NOT_CONFIGURED');
  });

  await t.test('5. Sai mật khẩu → vẫn là lỗi đăng nhập thường (không lộ đây là tài khoản gốc)', async () => {
    const err = await loginErr({ username: 'admin', password: 'sai', rootKey: KEY });
    assert.equal(err?.statusCode, 401);
    assert.equal(err.code, undefined);
  });

  await t.test('6. Đủ hai bước → cấp token mang dấu tài khoản gốc + vân tay khoá; gửi email cảnh báo', async () => {
    mails.length = 0;
    const result = await authService.login('admin', PASSWORD, loginReq({ username: 'admin', password: PASSWORD, rootKey: KEY }));
    const decoded = jwt.verify(result.accessToken, config.jwt.accessSecret);
    assert.equal(decoded.root, true);
    assert.equal(decoded.rkf, rootAdmin.keyFingerprint());
    assert.ok(decoded.rkf && !String(decoded.rkf).includes(KEY));
    await new Promise((r) => setTimeout(r, 20));
    assert.equal(mails.length, 1);
    assert.equal(mails[0].to, 'canhbao@example.com');
  });

  await t.test('7. Admin thường đăng nhập không cần khoá thứ hai, token không mang dấu gốc', async () => {
    accounts = [account({ idaccount: 8, email: 'admin.b@wealthcommand.com', username: 'admin.b' })];
    const result = await authService.login('admin.b', PASSWORD, loginReq({ username: 'admin.b', password: PASSWORD }));
    const decoded = jwt.verify(result.accessToken, config.jwt.accessSecret);
    assert.equal(decoded.root, undefined);
    accounts = [account()];
  });

  await t.test('8. Đổi khoá trong .env → token cũ của tài khoản gốc bị middleware từ chối (401 ROOT_SESSION_REVOKED)', async () => {
    const oldToken = jwt.sign({ idaccount: 1, idrole: 1, root: true, rkf: rootAdmin.keyFingerprint() }, config.jwt.accessSecret);
    process.env.ROOT_ADMIN_SECOND_KEY = 'khoa-moi-sau-khi-bi-lo-9876543210';
    const res = fakeRes();
    let nextCalled = false;
    await authenticate({ headers: { authorization: `Bearer ${oldToken}` } }, res, () => { nextCalled = true; });
    assert.equal(nextCalled, false);
    assert.equal(res.code, 401);
    assert.equal(res.body.code, 'ROOT_SESSION_REVOKED');
  });

  await t.test('9. Đổi khoá → làm mới token của tài khoản gốc bị từ chối và refresh token bị thu hồi', async () => {
    const payload = { idaccount: 1, idrole: 1, root: true, rkf: rootAdmin.keyFingerprint() };
    const refreshToken = jwt.sign(payload, config.jwt.refreshSecret, { expiresIn: '1d' });
    const updates = [];
    stub(prisma.refreshtoken, 'findUnique', async () => ({ idtoken: 99, status: false, expired: new Date(Date.now() + 864e5) }));
    stub(prisma.refreshtoken, 'update', async (args) => { updates.push(args); return {}; });
    process.env.ROOT_ADMIN_SECOND_KEY = 'khoa-moi-sau-khi-bi-lo-9876543210';
    let err = null;
    try { await authService.refresh(refreshToken, { headers: {} }); } catch (e) { err = e; }
    assert.equal(err?.statusCode, 401);
    assert.equal(err.code, 'ROOT_SESSION_REVOKED');
    assert.ok(updates.some((u) => u.data?.status === true), 'refresh token cũ phải bị thu hồi');
  });

  await t.test('10. Lớp chặn IP: request mang token hợp lệ của tài khoản gốc đi qua IP đang khoá; admin thường thì không', () => {
    const q = new AIOpsQuarantine({ repository: null, autoExpire: false });
    q.quarantine('198.51.100.77', 'Dò mật khẩu');
    const mw = q.createMiddleware();
    const rootToken = jwt.sign({ idaccount: 1, idrole: 1, root: true, rkf: rootAdmin.keyFingerprint() }, config.jwt.accessSecret);
    const adminToken = jwt.sign({ idaccount: 8, idrole: 1 }, config.jwt.accessSecret);
    let passed = false;
    mw({ ip: '198.51.100.77', headers: { authorization: `Bearer ${rootToken}` }, isAdmin: true }, fakeRes(), () => { passed = true; });
    assert.equal(passed, true);
    passed = false;
    const res = fakeRes();
    mw({ ip: '198.51.100.77', headers: { authorization: `Bearer ${adminToken}` }, isAdmin: true }, res, () => { passed = true; });
    assert.equal(passed, false);
    assert.equal(res.code, 403);
  });

  await t.test('11. Lớp chặn IP: đăng nhập bằng tên tài khoản gốc đi qua IP đang khoá (vẫn phải qua hai bước)', () => {
    const q = new AIOpsQuarantine({ repository: null, autoExpire: false });
    q.quarantine('198.51.100.78', 'Dò mật khẩu');
    const mw = q.createMiddleware();
    let passed = false;
    mw({ ip: '198.51.100.78', method: 'POST', originalUrl: '/api/auth/login', headers: {}, body: { username: 'ADMIN' } }, fakeRes(), () => { passed = true; });
    assert.equal(passed, true);
    passed = false;
    mw({ ip: '198.51.100.78', method: 'POST', originalUrl: '/api/auth/login', headers: {}, body: { username: 'binh' } }, fakeRes(), () => { passed = true; });
    assert.equal(passed, false);
  });

  await t.test('12. AIOps khoá tay tài khoản gốc → 403 ROOT_ACCOUNT_PROTECTED (kể cả chính tài khoản gốc tự khoá)', async () => {
    const controller = require('../../modules/aiops/aiops.controller');
    const adminService = require('../../modules/admin/admin.service');
    const { defaultAIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
    stub(adminService, 'verifySecurityAction', async () => ({ verified: true }));
    stub(defaultAIOpsQuarantine, '_resolveAccount', async () => ({ idaccount: 1, username: 'admin', idrole: 1, email: ROOT_EMAIL }));
    let called = false;
    stub(defaultAIOpsQuarantine, 'temporaryBlockAccount', async () => { called = true; });
    stub(defaultAIOpsQuarantine, 'permanentBanAccount', async () => { called = true; });
    for (const method of ['temporaryBlockAccount', 'permanentBanAccount']) {
      for (const user of [{ idaccount: 8, username: 'admin.b' }, { idaccount: 1, username: 'admin' }]) {
        const res = fakeRes();
        await controller[method]({ body: { username: 'admin', pin: '246810' }, user, headers: {} }, res);
        assert.equal(res.code, 403);
        assert.equal(res.body.code, 'ROOT_ACCOUNT_PROTECTED');
      }
    }
    assert.equal(called, false);
  });

  await t.test('13. Đồng bộ khoá xuống bảng account luôn loại trừ email tài khoản gốc', async () => {
    const q = new AIOpsQuarantine({ repository: null, autoExpire: false });
    let where = null;
    stub(prisma.account, 'findFirst', async () => ({ idaccount: 1 }));
    stub(prisma.account, 'updateMany', async (args) => { where = args.where; return { count: 0 }; });
    await q._syncAccountStatusToDatabase('admin', 'Inactive', '[AIOPS_AUTO_QUARANTINE]: x', { autoQuarantine: true });
    assert.ok(where.AND.some((c) => c.email && c.email.not === ROOT_EMAIL), JSON.stringify(where));
  });
});
