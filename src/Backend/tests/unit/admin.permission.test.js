const test = require('node:test');
const assert = require('node:assert/strict');
const adminService = require('../../modules/admin/admin.service');
const adminController = require('../../modules/admin/admin.controller');
const permissionRepository = require('../../modules/payment/permission.repository');

test('Admin Dynamic Permission Management Suite', async (t) => {
  await t.test('1. adminService.getPermissionsMatrix() trả về ma trận cấu hình đầy đủ', async () => {
    const origGetFeatures = permissionRepository.getAllFeatures;
    const origGetPerms = permissionRepository.getAllAccountPermissions;

    permissionRepository.getAllFeatures = async () => [
      { id: 'wallets', name: 'Tạo ví', type: 'LIMIT', category_group: 'Tài nguyên' },
      { id: 'ai_assistant', name: 'Trợ lý AI', type: 'TOGGLE', category_group: 'AI' },
    ];

    permissionRepository.getAllAccountPermissions = async () => [
      { account_type: 'Basic', feature_id: 'wallets', is_enabled: true, limit_value: 3 },
      { account_type: 'Basic', feature_id: 'ai_assistant', is_enabled: false, limit_value: null },
      { account_type: 'Premium', feature_id: 'wallets', is_enabled: true, limit_value: null },
      { account_type: 'Premium', feature_id: 'ai_assistant', is_enabled: true, limit_value: null },
    ];

    try {
      const matrix = await adminService.getPermissionsMatrix();
      assert.strictEqual(matrix.features.length, 2);
      assert.strictEqual(matrix.permissions.Basic.wallets.limit_value, 3);
      assert.strictEqual(matrix.permissions.Basic.ai_assistant.is_enabled, false);
      assert.strictEqual(matrix.permissions.Premium.wallets.limit_value, null);
      assert.strictEqual(matrix.permissions.Premium.ai_assistant.is_enabled, true);
    } finally {
      permissionRepository.getAllFeatures = origGetFeatures;
      permissionRepository.getAllAccountPermissions = origGetPerms;
    }
  });

  await t.test('2. adminService.updatePermissionsMatrix() cập nhật hợp lệ và trả về số lượng', async () => {
    const origUpdate = permissionRepository.updatePermission;
    const updatedCalls = [];
    permissionRepository.updatePermission = async (accountType, featureId, data) => {
      updatedCalls.push({ accountType, featureId, ...data });
      return { id: 1, account_type: accountType, feature_id: featureId, ...data };
    };

    try {
      const updates = [
        { account_type: 'Basic', feature_id: 'wallets', limit_value: 5, is_enabled: true },
        { account_type: 'Basic', feature_id: 'ai_assistant', limit_value: null, is_enabled: true },
      ];
      const result = await adminService.updatePermissionsMatrix(updates);
      assert.strictEqual(result.updatedCount, 2);
      assert.strictEqual(updatedCalls.length, 2);
      assert.strictEqual(updatedCalls[0].limit_value, 5);
      assert.strictEqual(updatedCalls[1].is_enabled, true);
    } finally {
      permissionRepository.updatePermission = origUpdate;
    }
  });

  await t.test('3. adminService.updatePermissionsMatrix() ném lỗi khi dữ liệu không hợp lệ', async () => {
    // 3.1 Mảng rỗng
    await assert.rejects(
      async () => adminService.updatePermissionsMatrix([]),
      /Danh sách cập nhật không được rỗng/
    );

    // 3.2 Sai account_type
    await assert.rejects(
      async () => adminService.updatePermissionsMatrix([{ account_type: 'Gold', feature_id: 'wallets' }]),
      /Loại tài khoản không hợp lệ/
    );

    // 3.3 Thiếu feature_id
    await assert.rejects(
      async () => adminService.updatePermissionsMatrix([{ account_type: 'Basic', feature_id: '' }]),
      /Thiếu mã tính năng/
    );
  });

  await t.test('4. adminController phản hồi chuẩn JSON qua ResponseHandler', async () => {
    const origGetMatrix = adminService.getPermissionsMatrix;
    adminService.getPermissionsMatrix = async () => ({ features: [], permissions: { Basic: {}, Premium: {} } });

    let capturedJson = null;
    let capturedStatus = 200;
    const mockRes = {
      status(code) {
        capturedStatus = code;
        return this;
      },
      json(data) {
        capturedJson = data;
        return this;
      },
    };

    try {
      await adminController.getPermissions({}, mockRes);
      assert.strictEqual(capturedStatus, 200);
      assert.strictEqual(capturedJson.success, true);
      assert.ok(capturedJson.data.permissions);
    } finally {
      adminService.getPermissionsMatrix = origGetMatrix;
    }
  });
});
