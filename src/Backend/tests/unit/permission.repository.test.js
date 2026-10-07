const test = require('node:test');
const assert = require('node:assert/strict');
const { prisma } = require('../../config/db');

test('Permission Repository Suite', async (t) => {
  const permissionRepository = require('../../modules/payment/permission.repository');

  await t.test('1. getPermissionsByAccountType() phân tách chính xác LIMIT và TOGGLE', async () => {
    const origFindMany = prisma.account_type_permission.findMany;
    prisma.account_type_permission.findMany = async ({ where }) => {
      if (where.account_type === 'Basic') {
        return [
          { feature_id: 'wallets', limit_value: 3, is_enabled: true, feature: { type: 'LIMIT' } },
          { feature_id: 'budgets', limit_value: 3, is_enabled: true, feature: { type: 'LIMIT' } },
          { feature_id: 'ai_assistant', limit_value: null, is_enabled: false, feature: { type: 'TOGGLE' } },
        ];
      }
      return [
        { feature_id: 'wallets', limit_value: null, is_enabled: true, feature: { type: 'LIMIT' } },
        { feature_id: 'budgets', limit_value: null, is_enabled: true, feature: { type: 'LIMIT' } },
        { feature_id: 'ai_assistant', limit_value: null, is_enabled: true, feature: { type: 'TOGGLE' } },
      ];
    };

    try {
      const basicPerms = await permissionRepository.getPermissionsByAccountType('Basic');
      assert.deepStrictEqual(basicPerms.limits, { wallets: 3, budgets: 3 });
      assert.deepStrictEqual(basicPerms.features, { ai_assistant: false });

      const premiumPerms = await permissionRepository.getPermissionsByAccountType('Premium');
      assert.deepStrictEqual(premiumPerms.limits, { wallets: null, budgets: null });
      assert.deepStrictEqual(premiumPerms.features, { ai_assistant: true });
    } finally {
      prisma.account_type_permission.findMany = origFindMany;
    }
  });

  await t.test('2. getPermissionsByAccountType() fallback về DEFAULT_PERMISSIONS khi CSDL rỗng hoặc lỗi', async () => {
    const origFindMany = prisma.account_type_permission.findMany;

    // Trường hợp rỗng
    prisma.account_type_permission.findMany = async () => [];
    try {
      const fallbackBasic = await permissionRepository.getPermissionsByAccountType('Basic');
      assert.strictEqual(fallbackBasic.limits.wallets, 3);
      assert.strictEqual(fallbackBasic.features.ai_assistant, false);

      // Trường hợp ném lỗi kết nối CSDL
      prisma.account_type_permission.findMany = async () => {
        throw new Error('Database connection failed');
      };
      const fallbackPremium = await permissionRepository.getPermissionsByAccountType('Premium');
      assert.strictEqual(fallbackPremium.limits.wallets, null);
      assert.strictEqual(fallbackPremium.features.ai_assistant, true);
    } finally {
      prisma.account_type_permission.findMany = origFindMany;
    }
  });

  await t.test('3. getAllFeatures() gọi prisma.feature.findMany theo thứ tự', async () => {
    const origFindMany = prisma.feature.findMany;
    let called = false;
    prisma.feature.findMany = async (args) => {
      called = true;
      assert.ok(args.orderBy);
      return [{ id: 'wallets', name: 'Số lượng ví' }];
    };

    try {
      const features = await permissionRepository.getAllFeatures();
      assert.ok(called);
      assert.strictEqual(features.length, 1);
      assert.strictEqual(features[0].id, 'wallets');
    } finally {
      prisma.feature.findMany = origFindMany;
    }
  });

  await t.test('4. updatePermission() gọi prisma.account_type_permission.upsert chính xác', async () => {
    const origUpsert = prisma.account_type_permission.upsert;
    let capturedArgs = null;
    prisma.account_type_permission.upsert = async (args) => {
      capturedArgs = args;
      return { id: 'mock-id', ...args.update };
    };

    try {
      await permissionRepository.updatePermission('Basic', 'wallets', { limit_value: 5, is_enabled: true });
      assert.ok(capturedArgs);
      assert.strictEqual(capturedArgs.where.account_type_feature_id.account_type, 'Basic');
      assert.strictEqual(capturedArgs.where.account_type_feature_id.feature_id, 'wallets');
      assert.strictEqual(capturedArgs.update.limit_value, 5);
      assert.strictEqual(capturedArgs.update.is_enabled, true);
    } finally {
      prisma.account_type_permission.upsert = origUpsert;
    }
  });
});
