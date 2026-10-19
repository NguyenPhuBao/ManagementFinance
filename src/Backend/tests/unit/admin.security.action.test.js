/**
 * Test: Verify Security Action (PIN / Password Re-authentication)
 * Đảm bảo các hành động chí mạng (Refund, Delete User, Maintenance) phải được bảo vệ bởi xác thực PIN/Password
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');
const adminService = require('../../modules/admin/admin.service');

describe('adminService.verifySecurityAction', () => {
  it('should throw 400 when neither PIN nor password is provided', async () => {
    await assert.rejects(
      async () => {
        await adminService.verifySecurityAction({}, { idaccount: 1 });
      },
      (err) => {
        assert.strictEqual(err.statusCode, 400);
        assert.ok(err.message.includes('Vui lòng cung cấp mã PIN'));
        return true;
      }
    );
  });

  it('should verify successfully when correct system PIN is provided', async () => {
    process.env.ADMIN_SECURITY_PIN = '654321';
    const result = await adminService.verifySecurityAction(
      { pin: '654321', action: 'REFUND', targetId: 'ORDER_999' },
      { idaccount: 1 }
    );

    assert.strictEqual(result.verified, true);
    assert.strictEqual(result.action, 'REFUND');
    assert.ok(result.verifiedAt);
  });

  it('should reject with 401 when invalid PIN is provided', async () => {
    process.env.ADMIN_SECURITY_PIN = '654321';
    await assert.rejects(
      async () => {
        await adminService.verifySecurityAction(
          { pin: '000000', action: 'REFUND', targetId: 'ORDER_999' },
          { idaccount: 1 }
        );
      },
      (err) => {
        assert.strictEqual(err.statusCode, 401);
        assert.ok(err.message.includes('không chính xác'));
        return true;
      }
    );
  });
});
