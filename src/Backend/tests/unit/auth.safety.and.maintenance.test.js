const test = require('node:test');
const assert = require('node:assert/strict');
const authController = require('../../modules/auth/auth.controller');
const authService = require('../../modules/auth/auth.service');
const { isAccountValid } = require('../../middleware/auth');
const aiopsQuarantine = require('../../modules/aiops/aiops.quarantine');
const { prisma } = require('../../config/db');

test('Auth & Resilience Safety Suite (2-Tier Testing — Mục 43 CAN-LAM)', async (t) => {
  await t.test('1. [Tier 1] auth.controller.login khi 503 trả về mã MAINTENANCE_MODE và header Retry-After: 60', async () => {
    const origLogin = authService.login;
    try {
      authService.login = async () => {
        throw Object.assign(
          new Error('Hệ thống đang bảo trì'),
          {
            statusCode: 503,
            code: 'MAINTENANCE_MODE',
            isEmergency: true,
            activatedAt: '2026-10-16T08:00:00.000Z',
          }
        );
      };

      const headers = {};
      let responseStatus = null;
      let responseBody = null;

      const req = {
        body: { username: 'user_test', password: 'password123' },
      };
      const res = {
        setHeader: (k, v) => {
          headers[k] = v;
        },
        status: (code) => {
          responseStatus = code;
          return {
            json: (data) => {
              responseBody = data;
              return data;
            },
          };
        },
      };

      await authController.login(req, res);

      assert.strictEqual(responseStatus, 503, 'HTTP Status phải là 503');
      assert.strictEqual(headers['Retry-After'], '60', 'Header Retry-After phải là 60');
      assert.strictEqual(responseBody.code, 'MAINTENANCE_MODE', 'Body JSON phải chứa code MAINTENANCE_MODE');
      assert.strictEqual(responseBody.isEmergency, true, 'isEmergency phải phản ánh đúng từ manager');
    } finally {
      authService.login = origLogin;
    }
  });

  await t.test('2. [Tier 2] accountRejection an toàn mặc định ACCOUNT_INACTIVE khi trạng thái không phải deleted (ngăn Client xóa SQLite)', async () => {
    const { accountRejection } = require('../../middleware/auth');
    
    // 1. Trạng thái Locked do AIOps cách ly -> Không được trả ACCOUNT_DELETED, phải là ACCOUNT_INACTIVE
    const resLocked = accountRejection({ valid: false, status: 'Locked', reason_inactive: 'Vi phạm an ninh AIOps' }, 10);
    assert.strictEqual(resLocked.data.code, 'ACCOUNT_INACTIVE', 'Locked phải trả code ACCOUNT_INACTIVE để client không xoá SQLite');
    assert.strictEqual(resLocked.data.reason_inactive, 'Vi phạm an ninh AIOps');

    // 2. Trạng thái Inactive bình thường -> ACCOUNT_INACTIVE
    const resInactive = accountRejection({ valid: false, status: 'Inactive', reason_inactive: 'Tạm khóa' }, 10);
    assert.strictEqual(resInactive.data.code, 'ACCOUNT_INACTIVE');

    // 3. Trạng thái lạ bất kỳ khác Deleted -> ACCOUNT_INACTIVE (Safe Default)
    const resUnknown = accountRejection({ valid: false, status: 'Suspended' }, 10);
    assert.strictEqual(resUnknown.data.code, 'ACCOUNT_INACTIVE');

    // 4. Đúng nghĩa Deleted -> Mới được trả ACCOUNT_DELETED
    const resDeleted = accountRejection({ valid: false, status: 'Deleted' }, 10);
    assert.strictEqual(resDeleted.data.code, 'ACCOUNT_DELETED');

    // 5. Tài khoản không tồn tại (status null) -> ACCOUNT_DELETED
    const resMissing = accountRejection({ valid: false, status: null }, 10);
    assert.strictEqual(resMissing.data.code, 'ACCOUNT_DELETED');
  });

  await t.test('3. [Tier 2] AIOps Quarantine đồng bộ trạng thái Inactive vào CSDL (không vi phạm ck_account_status)', async () => {
    const { defaultAIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
    let updatedPayload = null;
    const origUpdateMany = prisma.account.updateMany;
    try {
      prisma.account.updateMany = async (args) => {
        updatedPayload = args;
        return { count: 1 };
      };

      await defaultAIOpsQuarantine._syncAccountStatusToDatabase('test_user', 'Inactive', 'Cách ly tự động');

      assert.ok(updatedPayload);
      assert.strictEqual(updatedPayload.data.status, 'Inactive', 'AIOps phải ghi Inactive vào bảng account thay vì Locked');
      assert.strictEqual(updatedPayload.data.reason_inactive, 'Cách ly tự động');
    } finally {
      prisma.account.updateMany = origUpdateMany;
    }
  });
});
