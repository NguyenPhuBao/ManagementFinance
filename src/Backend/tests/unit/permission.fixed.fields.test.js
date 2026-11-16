/**
 * Ma trận phân quyền: trường app không áp dụng thì Backend không ghi (Chủ dự án chốt 2026-11-16).
 * - Trụ cột 4 (`downgrade_policy`): app viết cứng cách hạ cấp → bỏ qua khi lưu.
 * - Hạn mức gia đình (`household_members`, `household_wallets`): Backend gia đình viết cứng 6 / 10 → bỏ qua `limit_value`
 *   và `is_enabled` (ô Truy cập không có tác dụng, khoá luôn: chốt 2026-11-16).
 * - Các hạn mức khác vẫn lưu như cũ.
 */
const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const adminService = require('../../modules/admin/admin.service');
const permissionRepository = require('../../modules/payment/permission.repository');

describe('Lưu ma trận phân quyền: bỏ qua trường cố định', () => {
  const orig = permissionRepository.updatePermission;
  let calls;

  beforeEach(() => {
    calls = [];
    permissionRepository.updatePermission = async (accountType, featureId, data) => {
      calls.push({ accountType, featureId, ...data });
      return { account_type: accountType, feature_id: featureId };
    };
  });
  afterEach(() => { permissionRepository.updatePermission = orig; });

  it('không ghi downgrade_policy (Khi hạ cấp) dù lệnh lưu có gửi', async () => {
    await adminService.updatePermissionsMatrix([
      { account_type: 'Premium', feature_id: 'export_reports', is_enabled: true, limit_value: null, downgrade_policy: 'READ_ONLY' },
    ]);
    assert.equal(calls.length, 1);
    assert.equal(calls[0].downgrade_policy, undefined);
    assert.equal(calls[0].is_enabled, true);
  });

  it('không ghi limit_value lẫn is_enabled của household_members và household_wallets (cả hai cố định)', async () => {
    await adminService.updatePermissionsMatrix([
      { account_type: 'Premium', feature_id: 'household_members', is_enabled: false, limit_value: 99 },
      { account_type: 'Premium', feature_id: 'household_wallets', is_enabled: true, limit_value: null },
    ]);
    assert.equal(calls[0].limit_value, undefined);
    assert.equal(calls[0].is_enabled, undefined);
    assert.equal(calls[1].limit_value, undefined);
    assert.equal(calls[1].is_enabled, undefined);
  });

  it('hạn mức khác (ví) vẫn lưu như cũ', async () => {
    await adminService.updatePermissionsMatrix([{ account_type: 'Basic', feature_id: 'wallets', is_enabled: true, limit_value: 5 }]);
    assert.equal(calls[0].limit_value, 5);
  });
});
