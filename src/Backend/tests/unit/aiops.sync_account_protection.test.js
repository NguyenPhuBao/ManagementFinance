const test = require('node:test');
const assert = require('node:assert/strict');
const { defaultAIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
const { prisma } = require('../../config/db');

test('AIOps Account Status Sync & Database Protection (2-Tier Testing Matrix)', async (t) => {
  const originalUpdateMany = prisma.account?.updateMany;
  let lastCapturedQuery = null;

  t.beforeEach(() => {
    lastCapturedQuery = null;
    prisma.account.updateMany = async (args) => {
      lastCapturedQuery = args;
      return { count: 1 };
    };
  });

  t.after(() => {
    if (originalUpdateMany) {
      prisma.account.updateMany = originalUpdateMany;
    }
  });

  await t.test('Tier 1 & Tier 2: Tự động hết hạn (sweep) chỉ mở khóa tài khoản đang Inactive và do AIOps/Sentinel khóa', async () => {
    // Kích hoạt đồng bộ mở khóa tự động
    await defaultAIOpsQuarantine._syncAccountStatusToDatabase('test_user_aiops', 'Active', null, { onlyAIOpsLocked: true });

    assert.ok(lastCapturedQuery, 'Hệ thống phải thực thi updateMany xuống CSDL');
    assert.strictEqual(lastCapturedQuery.data.status, 'Active');
    assert.strictEqual(lastCapturedQuery.data.reason_inactive, null);

    const andConditions = lastCapturedQuery.where.AND;
    assert.ok(Array.isArray(andConditions), 'Mệnh đề where phải dùng AND để bảo vệ đa điều kiện');

    // Tầng 2: Kiểm tra bắt buộc có điều kiện status: 'Inactive' (không mở khóa PendingDelete)
    const hasInactiveCondition = andConditions.some((c) => c.status === 'Inactive');
    assert.ok(hasInactiveCondition, 'Bắt buộc chỉ mở khóa tài khoản đang có trạng thái Inactive');

    // Tầng 2: Kiểm tra lọc theo lý do AIOps/Sentinel
    const reasonCondition = andConditions.find((c) => c.reason_inactive?.startsWith);
    assert.ok(reasonCondition, 'Bắt buộc lọc theo đúng một dấu cố định của khoá tự động');
    assert.strictEqual(reasonCondition.reason_inactive.startsWith, '[AIOPS_AUTO_QUARANTINE]');
  });

  await t.test('Tier 2: Khi AIOps cách ly hoặc tạm khóa tài khoản, TUYỆT ĐỐI không ghi đè tài khoản PendingDelete', async () => {
    await defaultAIOpsQuarantine._syncAccountStatusToDatabase('user_in_deletion', 'Inactive', 'Cách ly an ninh AIOps');

    assert.ok(lastCapturedQuery, 'Hệ thống phải thực thi updateMany xuống CSDL');
    assert.strictEqual(lastCapturedQuery.data.status, 'Inactive');

    const andConditions = lastCapturedQuery.where.AND;
    // Tầng 2: Phải có điều kiện status: { not: 'PendingDelete' }
    const protectPendingDelete = andConditions.some((c) => c.status && c.status.not === 'PendingDelete');
    assert.ok(protectPendingDelete, 'Tuyệt đối không được ghi đè hoặc hạ trạng thái tài khoản đang là PendingDelete');
  });

  await t.test('Tier 1 & Tier 2: Mở khóa thủ công từ Admin AIOps mở khóa Inactive nhưng vẫn bảo vệ PendingDelete', async () => {
    await defaultAIOpsQuarantine._syncAccountStatusToDatabase('12345', 'Active', null);

    assert.ok(lastCapturedQuery, 'Hệ thống phải thực thi updateMany xuống CSDL');
    assert.strictEqual(lastCapturedQuery.data.status, 'Active');

    const andConditions = lastCapturedQuery.where.AND;
    const hasInactiveCondition = andConditions.some((c) => c.status === 'Inactive');
    assert.ok(hasInactiveCondition, 'Mở khóa thủ công vẫn phải bảo vệ không tác động tài khoản ngoài Inactive');
    
    // Identifier condition cho số idaccount
    const idCondition = andConditions.find((c) => Array.isArray(c.OR));
    assert.ok(idCondition, 'Phải tìm kiếm theo idaccount hoặc username');
  });
});
