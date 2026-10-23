const test = require('node:test');
const assert = require('node:assert/strict');
const { prisma } = require('../../config/db');

test('Permission 4 Pillars Unit Suite', async (t) => {
  const permissionRepository = require('../../modules/payment/permission.repository');
  const adminService = require('../../modules/admin/admin.service');

  await t.test('1. getPermissionsByAccountType() trả về đầy đủ 4 trụ cột: limits, features, scopes, policies', async () => {
    const origFindMany = prisma.account_type_permission.findMany;
    prisma.account_type_permission.findMany = async ({ where }) => {
      return [
        {
          feature_id: 'wallets',
          limit_value: 3,
          is_enabled: true,
          scope_config: { allowed_types: ['Cash', 'Bank'] },
          downgrade_policy: 'BLOCK_CREATE',
          feature: { type: 'LIMIT' },
        },
        {
          feature_id: 'export_reports',
          limit_value: null,
          is_enabled: false,
          scope_config: { formats: [] },
          downgrade_policy: 'LOCK_FEATURE',
          feature: { type: 'TOGGLE' },
        },
      ];
    };

    try {
      const res = await permissionRepository.getPermissionsByAccountType('Basic');
      // Trụ 1: Access
      assert.strictEqual(res.features.export_reports, false);
      // Trụ 2: Quota
      assert.strictEqual(res.limits.wallets, 3);
      // Trụ 3: Scope
      assert.deepStrictEqual(res.scopes.wallets, { allowed_types: ['Cash', 'Bank'] });
      assert.deepStrictEqual(res.scopes.export_reports, { formats: [] });
      // Trụ 4: Policy
      assert.strictEqual(res.policies.wallets, 'BLOCK_CREATE');
      assert.strictEqual(res.policies.export_reports, 'LOCK_FEATURE');
    } finally {
      prisma.account_type_permission.findMany = origFindMany;
    }
  });

  await t.test('2. updatePermission() cập nhật đầy đủ cả 4 trụ cột (scope_config, downgrade_policy)', async () => {
    const origUpsert = prisma.account_type_permission.upsert;
    let capturedArgs = null;
    prisma.account_type_permission.upsert = async (args) => {
      capturedArgs = args;
      return { id: 1, ...args.update };
    };

    try {
      await permissionRepository.updatePermission('Basic', 'export_reports', {
        is_enabled: true,
        limit_value: null,
        scope_config: { formats: ['PDF'] },
        downgrade_policy: 'LOCK_FEATURE',
      });

      assert.ok(capturedArgs);
      assert.strictEqual(capturedArgs.update.is_enabled, true);
      assert.strictEqual(capturedArgs.update.limit_value, null);
      assert.deepStrictEqual(capturedArgs.update.scope_config, { formats: ['PDF'] });
      assert.strictEqual(capturedArgs.update.downgrade_policy, 'LOCK_FEATURE');
    } finally {
      prisma.account_type_permission.upsert = origUpsert;
    }
  });

  await t.test('3. adminService.getPermissionsMatrix() chứa đầy đủ thông tin 4 trụ cột', async () => {
    const origGetAllFeatures = permissionRepository.getAllFeatures;
    const origGetAllPerms = permissionRepository.getAllAccountPermissions;

    permissionRepository.getAllFeatures = async () => [
      {
        id: 'wallets',
        name: 'Quản lý ví tiền',
        type: 'LIMIT',
        category_group: 'Quản lý Ví & Tài sản',
        scope_schema: { allowed_types: ['Cash', 'Bank'] },
        default_downgrade_policy: 'BLOCK_CREATE',
      },
    ];

    permissionRepository.getAllAccountPermissions = async () => [
      {
        account_type: 'Basic',
        feature_id: 'wallets',
        is_enabled: true,
        limit_value: 3,
        scope_config: { allowed_types: ['Cash'] },
        downgrade_policy: 'BLOCK_CREATE',
      },
      {
        account_type: 'Premium',
        feature_id: 'wallets',
        is_enabled: true,
        limit_value: null,
        scope_config: { allowed_types: ['Cash', 'Bank', 'Credit'] },
        downgrade_policy: 'BLOCK_CREATE',
      },
    ];

    try {
      const matrix = await adminService.getPermissionsMatrix();
      assert.ok(matrix.features);
      assert.ok(matrix.permissions);
      assert.strictEqual(matrix.features[0].default_downgrade_policy, 'BLOCK_CREATE');
      assert.deepStrictEqual(matrix.features[0].scope_schema, { allowed_types: ['Cash', 'Bank'] });

      const basicWallet = matrix.permissions.Basic.wallets;
      assert.strictEqual(basicWallet.is_enabled, true);
      assert.strictEqual(basicWallet.limit_value, 3);
      assert.deepStrictEqual(basicWallet.scope_config, { allowed_types: ['Cash'] });
      assert.strictEqual(basicWallet.downgrade_policy, 'BLOCK_CREATE');

      const premWallet = matrix.permissions.Premium.wallets;
      assert.strictEqual(premWallet.limit_value, null);
      assert.deepStrictEqual(premWallet.scope_config, { allowed_types: ['Cash', 'Bank', 'Credit'] });
    } finally {
      permissionRepository.getAllFeatures = origGetAllFeatures;
      permissionRepository.getAllAccountPermissions = origGetAllPerms;
    }
  });

  await t.test('4. adminService.updatePermissionsMatrix() truyền tải đầy đủ 4 trụ cột cho repository', async () => {
    const origUpdate = permissionRepository.updatePermission;
    const captured = [];
    permissionRepository.updatePermission = async (type, featId, payload) => {
      captured.push({ type, featId, payload });
      return { id: 1, account_type: type, feature_id: featId, ...payload };
    };

    try {
      await adminService.updatePermissionsMatrix([
        {
          account_type: 'Basic',
          feature_id: 'export_reports',
          is_enabled: true,
          limit_value: null,
          scope_config: { formats: ['PDF'] },
          downgrade_policy: 'LOCK_FEATURE',
        },
      ]);

      assert.strictEqual(captured.length, 1);
      assert.strictEqual(captured[0].type, 'Basic');
      assert.strictEqual(captured[0].featId, 'export_reports');
      assert.strictEqual(captured[0].payload.is_enabled, true);
      assert.deepStrictEqual(captured[0].payload.scope_config, { formats: ['PDF'] });
      assert.strictEqual(captured[0].payload.downgrade_policy, 'LOCK_FEATURE');
    } finally {
      permissionRepository.updatePermission = origUpdate;
    }
  });
});
