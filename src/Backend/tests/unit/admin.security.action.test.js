/**
 * Test: Verify Security Action (PIN / Password Re-authentication)
 * Đảm bảo các hành động chí mạng (Refund, Delete User, Maintenance) phải được bảo vệ bởi xác thực PIN/Password
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');
const bcrypt = require('bcryptjs');
const adminService = require('../../modules/admin/admin.service');
const adminRepository = require('../../modules/admin/admin.repository');

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

  it('should verify successfully when correct hashed PIN in DB is provided', async () => {
    const origGet = adminRepository.getAccountById;
    const pinHash = await bcrypt.hash('888999', 10);
    const dummyPassHash = await bcrypt.hash('dummy_pass', 10);
    adminRepository.getAccountById = async (id) => ({
      idaccount: id,
      pin_hash: pinHash,
      password: dummyPassHash,
    });

    try {
      const result = await adminService.verifySecurityAction(
        { pin: '888999', action: 'REFUND', targetId: 'ORDER_999' },
        { idaccount: 1 }
      );

      assert.strictEqual(result.verified, true);
      assert.strictEqual(result.action, 'REFUND');
      assert.ok(result.verifiedAt);
    } finally {
      adminRepository.getAccountById = origGet;
    }
  });

  it('should verify successfully with fallback system PIN when account has no pin_hash in DB', async () => {
    const origGet = adminRepository.getAccountById;
    const dummyPassHash = await bcrypt.hash('dummy_pass', 10);
    adminRepository.getAccountById = async (id) => ({
      idaccount: id,
      pin_hash: null,
      password: dummyPassHash,
    });
    process.env.ADMIN_SECURITY_PIN = '654321';

    try {
      const result = await adminService.verifySecurityAction(
        { pin: '654321', action: 'REFUND', targetId: 'ORDER_999' },
        { idaccount: 1 }
      );

      assert.strictEqual(result.verified, true);
    } finally {
      adminRepository.getAccountById = origGet;
    }
  });

  it('should reject with 401 when invalid PIN is provided', async () => {
    const origGet = adminRepository.getAccountById;
    const pinHash = await bcrypt.hash('888999', 10);
    const dummyPassHash = await bcrypt.hash('dummy_pass', 10);
    adminRepository.getAccountById = async (id) => ({
      idaccount: id,
      pin_hash: pinHash,
      password: dummyPassHash,
    });

    try {
      await assert.rejects(
        async () => {
          await adminService.verifySecurityAction(
            { pin: '000000', action: 'REFUND', targetId: 'ORDER_999' },
            { idaccount: 1 }
          );
        },
        (err) => {
          assert.strictEqual(err.statusCode, 400);
          assert.ok(err.message.includes('không chính xác'));
          return true;
        }
      );
    } finally {
      adminRepository.getAccountById = origGet;
    }
  });
});
