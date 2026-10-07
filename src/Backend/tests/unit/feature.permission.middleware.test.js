const test = require('node:test');
const assert = require('node:assert/strict');
const { requireFeature } = require('../../middleware/feature-permission.middleware');
const permissionRepository = require('../../modules/payment/permission.repository');
const { prisma } = require('../../config/db');

test('Feature Permission Middleware Suite', async (t) => {
  const origFindUnique = prisma.account.findUnique;
  const origGetPerms = permissionRepository.getPermissionsByAccountType;

  t.afterEach(() => {
    prisma.account.findUnique = origFindUnique;
    permissionRepository.getPermissionsByAccountType = origGetPerms;
  });

  await t.test('1. Chặn 401 nếu request chưa có req.user.idaccount', async () => {
    const middleware = requireFeature('ai_assistant');
    const req = { user: null };
    let statusSent = null;
    let jsonSent = null;
    const res = {
      status(s) { statusSent = s; return this; },
      json(j) { jsonSent = j; return this; },
    };
    let nextCalled = false;

    await middleware(req, res, () => { nextCalled = true; });

    assert.equal(nextCalled, false);
    assert.equal(statusSent, 401);
    assert.equal(jsonSent.success, false);
  });

  await t.test('2. Cho phép Admin (idrole = 1) bypass mọi ràng buộc', async () => {
    const middleware = requireFeature('ai_assistant');
    const req = { user: { idaccount: 99, idrole: 1, rolename: 'admin' } };
    let nextCalled = false;
    const res = {};

    await middleware(req, res, () => { nextCalled = true; });

    assert.equal(nextCalled, true);
  });

  await t.test('3. Chặn 403 Forbidden nếu tài khoản Basic bị tắt tính năng (ai_assistant = false)', async () => {
    prisma.account.findUnique = async () => ({
      type: 'Basic',
      premium_expires_at: null,
    });
    permissionRepository.getPermissionsByAccountType = async () => ({
      limits: { wallets: 3 },
      features: { ai_assistant: false },
    });

    const middleware = requireFeature('ai_assistant');
    const req = { user: { idaccount: 50, idrole: 2, type: 'Basic' } };
    let statusSent = null;
    let jsonSent = null;
    const res = {
      status(s) { statusSent = s; return this; },
      json(j) { jsonSent = j; return this; },
    };
    let nextCalled = false;

    await middleware(req, res, () => { nextCalled = true; });

    assert.equal(nextCalled, false);
    assert.equal(statusSent, 403);
    assert.equal(jsonSent.code, 'FEATURE_DISABLED');
    assert.equal(jsonSent.featureId, 'ai_assistant');
  });

  await t.test('4. Cho qua nếu tài khoản Premium có tính năng bật (ai_assistant = true)', async () => {
    prisma.account.findUnique = async () => ({
      type: 'Premium',
      premium_expires_at: new Date(Date.now() + 86400000), // ngày mai
    });
    permissionRepository.getPermissionsByAccountType = async () => ({
      limits: { wallets: null },
      features: { ai_assistant: true },
    });

    const middleware = requireFeature('ai_assistant');
    const req = { user: { idaccount: 50, idrole: 2, type: 'Premium' } };
    let nextCalled = false;
    const res = {};

    await middleware(req, res, () => { nextCalled = true; });

    assert.equal(nextCalled, true);
  });

  await t.test('5. Tự động hạ về Basic và chặn 403 nếu tài khoản Premium đã quá hạn', async () => {
    prisma.account.findUnique = async () => ({
      type: 'Premium',
      premium_expires_at: new Date(Date.now() - 86400000), // đã hết hạn hôm qua
    });
    permissionRepository.getPermissionsByAccountType = async (type) => {
      assert.equal(type, 'Basic'); // Phải tra cứu theo Basic
      return {
        limits: { wallets: 3 },
        features: { ai_assistant: false },
      };
    };

    const middleware = requireFeature('ai_assistant');
    const req = { user: { idaccount: 50, idrole: 2, type: 'Premium' } };
    let statusSent = null;
    let jsonSent = null;
    const res = {
      status(s) { statusSent = s; return this; },
      json(j) { jsonSent = j; return this; },
    };
    let nextCalled = false;

    await middleware(req, res, () => { nextCalled = true; });

    assert.equal(nextCalled, false);
    assert.equal(statusSent, 403);
    assert.equal(jsonSent.code, 'FEATURE_DISABLED');
    assert.equal(jsonSent.accountType, 'Basic');
  });
});
