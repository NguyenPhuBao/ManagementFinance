const test = require('node:test');
const assert = require('node:assert/strict');

test('Admin Permission 4 Pillars API Suite', async (t) => {
  const adminController = require('../../modules/admin/admin.controller');
  const adminService = require('../../modules/admin/admin.service');
  const paymentService = require('../../modules/payment/payment.service');
  const permissionRepository = require('../../modules/payment/permission.repository');

  const mockRes = () => {
    const res = {};
    res.statusCode = 200;
    res.status = function (code) {
      this.statusCode = code;
      return this;
    };
    res.json = function (payload) {
      this.body = payload;
      return this;
    };
    return res;
  };

  await t.test('1. GET /admin/permissions trả về ma trận 4 trụ cột thành công', async () => {
    const origGetMatrix = adminService.getPermissionsMatrix;
    adminService.getPermissionsMatrix = async () => ({
      features: [
        { id: 'wallets', scope_schema: { allowed_types: ['Cash'] }, default_downgrade_policy: 'BLOCK_CREATE' },
      ],
      permissions: {
        Basic: {
          wallets: { is_enabled: true, limit_value: 3, scope_config: {}, downgrade_policy: 'BLOCK_CREATE' },
        },
        Premium: {
          wallets: { is_enabled: true, limit_value: null, scope_config: {}, downgrade_policy: 'BLOCK_CREATE' },
        },
      },
    });

    try {
      const res = mockRes();
      await adminController.getPermissions({}, res);
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.ok(res.body.data.features);
      assert.ok(res.body.data.permissions.Basic.wallets.scope_config);
      assert.strictEqual(res.body.data.permissions.Basic.wallets.downgrade_policy, 'BLOCK_CREATE');
    } finally {
      adminService.getPermissionsMatrix = origGetMatrix;
    }
  });

  await t.test('2. PUT /admin/permissions cập nhật thành công cả 4 trụ cột', async () => {
    const origUpdate = adminService.updatePermissionsMatrix;
    let capturedUpdates = null;
    adminService.updatePermissionsMatrix = async (updates) => {
      capturedUpdates = updates;
      return { updatedCount: updates.length, updates };
    };

    try {
      const res = mockRes();
      const req = {
        body: {
          updates: [
            {
              account_type: 'Basic',
              feature_id: 'export_reports',
              is_enabled: true,
              limit_value: null,
              scope_config: { formats: ['PDF'] },
              downgrade_policy: 'LOCK_FEATURE',
            },
          ],
        },
        user: { idaccount: 1, role: 'Admin' },
      };

      await adminController.updatePermissions(req, res);
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(capturedUpdates.length, 1);
      assert.deepStrictEqual(capturedUpdates[0].scope_config, { formats: ['PDF'] });
      assert.strictEqual(capturedUpdates[0].downgrade_policy, 'LOCK_FEATURE');
    } finally {
      adminService.updatePermissionsMatrix = origUpdate;
    }
  });

  await t.test('3. POST /admin/permissions/reset khôi phục cấu hình mặc định', async () => {
    const origReset = adminService.resetPermissionsToDefault;
    let resetCalled = false;
    adminService.resetPermissionsToDefault = async () => {
      resetCalled = true;
      return { success: true, message: 'Đã khôi phục' };
    };

    try {
      const res = mockRes();
      await adminController.resetPermissions({ user: { idaccount: 1 } }, res);
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.ok(resetCalled);
    } finally {
      adminService.resetPermissionsToDefault = origReset;
    }
  });

  await t.test('4. getSubscriptionInfo() trả về tương thích ngược kèm scopes và policies', async () => {
    const origFindUnique = require('../../config/db').prisma.account.findUnique;
    const origGetPerms = permissionRepository.getPermissionsByAccountType;

    require('../../config/db').prisma.account.findUnique = async () => ({
      idaccount: 10,
      type: 'Basic',
      premium_expires_at: null,
    });

    permissionRepository.getPermissionsByAccountType = async () => ({
      limits: { wallets: 3 },
      features: { ai_assistant: false },
      scopes: { wallets: { allowed_types: ['Cash'] } },
      policies: { wallets: 'BLOCK_CREATE' },
    });

    try {
      const info = await paymentService.getSubscriptionInfo(10);
      // Tương thích ngược Client-app:
      assert.strictEqual(info.accountType, 'Basic');
      assert.deepStrictEqual(info.limits, { wallets: 3 });
      assert.deepStrictEqual(info.features, { ai_assistant: false });
      // Bổ sung 4 trụ cột:
      assert.deepStrictEqual(info.scopes, { wallets: { allowed_types: ['Cash'] } });
      assert.deepStrictEqual(info.policies, { wallets: 'BLOCK_CREATE' });
    } finally {
      require('../../config/db').prisma.account.findUnique = origFindUnique;
      permissionRepository.getPermissionsByAccountType = origGetPerms;
    }
  });
});
