/**
 * Unit Test Suite: Admin Security Refinement
 * Kiểm thử 2 Tầng cho Backend:
 * - firstLoginSetup
 * - changeAdminPin
 * - changeAdminPassword
 * - createAdminAccount
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');
const bcrypt = require('bcryptjs');
const adminService = require('../../modules/admin/admin.service');
const adminRepository = require('../../modules/admin/admin.repository');

describe('Admin Security Refinement Suite (Backend)', () => {
  describe('firstLoginSetup', () => {
    it('should reject when newPassword is "123456"', async () => {
      await assert.rejects(
        async () => {
          await adminService.firstLoginSetup(
            { newPassword: '123456', confirmPassword: '123456', pin: '654321', confirmPin: '654321' },
            { idaccount: 1 }
          );
        },
        (err) => {
          assert.strictEqual(err.statusCode, 400);
          assert.ok(err.message.includes('123456'));
          return true;
        }
      );
    });

    it('should reject when pin is "123456"', async () => {
      await assert.rejects(
        async () => {
          await adminService.firstLoginSetup(
            { newPassword: 'NewPassword@2026', confirmPassword: 'NewPassword@2026', pin: '123456', confirmPin: '123456' },
            { idaccount: 1 }
          );
        },
        (err) => {
          assert.strictEqual(err.statusCode, 400);
          assert.ok(err.message.includes('123456'));
          return true;
        }
      );
    });

    it('should succeed with valid newPassword and pin, returning updated user with is_first_login = false', async () => {
      const origGet = adminRepository.getAccountById;
      const origUpdate = adminRepository.updateFirstLoginSetup;

      adminRepository.getAccountById = async (id) => ({
        idaccount: id,
        username: 'admin',
        email: 'admin@finance.local',
        password: 'old_hash',
        pin_hash: 'old_pin',
      });

      adminRepository.updateFirstLoginSetup = async (id, passHash, pinHash) => ({
        idaccount: id,
        username: 'admin',
        email: 'admin@finance.local',
        idrole: 1,
        is_first_login: false,
        role: { idrole: 1, rolename: 'Admin' },
        User: { fullname: 'Administrator', email: 'admin@finance.local' },
      });

      try {
        const result = await adminService.firstLoginSetup(
          { newPassword: 'SecurePassword@2026', confirmPassword: 'SecurePassword@2026', pin: '987654', confirmPin: '987654' },
          { idaccount: 1 }
        );

        assert.strictEqual(result.success, true);
        assert.strictEqual(result.user.is_first_login, false);
      } finally {
        adminRepository.getAccountById = origGet;
        adminRepository.updateFirstLoginSetup = origUpdate;
      }
    });
  });

  describe('changeAdminPassword', () => {
    it('should reject when oldPin is invalid', async () => {
      const origGet = adminRepository.getAccountById;
      const passHash = await bcrypt.hash('CorrectOldPassword', 10);
      const pinHash = await bcrypt.hash('112233', 10);

      adminRepository.getAccountById = async (id) => ({
        idaccount: id,
        password: passHash,
        pin_hash: pinHash,
      });

      try {
        await assert.rejects(
          async () => {
            await adminService.changeAdminPassword(
              { oldPassword: 'CorrectOldPassword', oldPin: '999999', newPassword: 'NewSuperPassword@2026', confirmPassword: 'NewSuperPassword@2026' },
              { idaccount: 1 }
            );
          },
          (err) => {
            assert.strictEqual(err.statusCode, 400);
            assert.ok(err.message.includes('Mã PIN'));
            return true;
          }
        );
      } finally {
        adminRepository.getAccountById = origGet;
      }
    });

    it('should reject when oldPassword is wrong', async () => {
      const origGet = adminRepository.getAccountById;
      const passHash = await bcrypt.hash('CorrectOldPassword', 10);
      const pinHash = await bcrypt.hash('112233', 10);

      adminRepository.getAccountById = async (id) => ({
        idaccount: id,
        password: passHash,
        pin_hash: pinHash,
      });

      try {
        await assert.rejects(
          async () => {
            await adminService.changeAdminPassword(
              { oldPassword: 'WrongPassword', oldPin: '112233', newPassword: 'NewSuperPassword@2026', confirmPassword: 'NewSuperPassword@2026' },
              { idaccount: 1 }
            );
          },
          (err) => {
            assert.strictEqual(err.statusCode, 400);
            assert.ok(err.message.includes('Mật khẩu'));
            return true;
          }
        );
      } finally {
        adminRepository.getAccountById = origGet;
      }
    });

    it('should successfully change password when pin is provided as current security pin (matching account.pin_hash)', async () => {
      const origGet = adminRepository.getAccountById;
      const origUpdatePass = adminRepository.updateAccountPassword;
      const passHash = await bcrypt.hash('CorrectOldPassword', 10);
      const pinHash = await bcrypt.hash('654321', 10);
      let updatedWithHash = null;

      adminRepository.getAccountById = async (id) => ({
        idaccount: id,
        password: passHash,
        pin_hash: pinHash,
      });

      adminRepository.updateAccountPassword = async (id, newHash) => {
        updatedWithHash = newHash;
        return { idaccount: id };
      };

      try {
        const result = await adminService.changeAdminPassword(
          { oldPassword: 'CorrectOldPassword', pin: '654321', newPassword: 'BrandNewPassword@2026', confirmPassword: 'BrandNewPassword@2026' },
          { idaccount: 1 }
        );

        assert.strictEqual(result.success, true);
        assert.ok(updatedWithHash !== null);
        const matchesNew = await bcrypt.compare('BrandNewPassword@2026', updatedWithHash);
        assert.strictEqual(matchesNew, true);
      } finally {
        adminRepository.getAccountById = origGet;
        adminRepository.updateAccountPassword = origUpdatePass;
      }
    });

    it('should reject when pin is invalid current pin', async () => {
      const origGet = adminRepository.getAccountById;
      const passHash = await bcrypt.hash('CorrectOldPassword', 10);
      const pinHash = await bcrypt.hash('654321', 10);

      adminRepository.getAccountById = async (id) => ({
        idaccount: id,
        password: passHash,
        pin_hash: pinHash,
      });

      try {
        await assert.rejects(
          async () => {
            await adminService.changeAdminPassword(
              { oldPassword: 'CorrectOldPassword', pin: '000000', newPassword: 'BrandNewPassword@2026', confirmPassword: 'BrandNewPassword@2026' },
              { idaccount: 1 }
            );
          },
          (err) => {
            assert.strictEqual(err.statusCode, 400);
            assert.ok(err.message.includes('Mã PIN bảo mật hiện tại không chính xác'));
            return true;
          }
        );
      } finally {
        adminRepository.getAccountById = origGet;
      }
    });
  });

  describe('createAdminAccount', () => {
    it('should reject when fullName is missing or too short', async () => {
      await assert.rejects(
        async () => {
          await adminService.createAdminAccount(
            { username: 'newadmin', email: 'newadmin@finance.local', pin: '000000', fullName: 'A' },
            { idaccount: 1 }
          );
        },
        (err) => {
          assert.strictEqual(err.statusCode, 400);
          assert.ok(err.message.includes('Họ và tên'));
          return true;
        }
      );
    });

    it('should reject when phone is missing or invalid', async () => {
      await assert.rejects(
        async () => {
          await adminService.createAdminAccount(
            { username: 'newadmin', email: 'newadmin@finance.local', pin: '000000', fullName: 'Nguyễn Quản Trị', phone: '123' },
            { idaccount: 1 }
          );
        },
        (err) => {
          assert.strictEqual(err.statusCode, 400);
          assert.ok(err.message.includes('Số điện thoại'));
          return true;
        }
      );
    });

    it('should reject when creator PIN is invalid', async () => {
      const origGet = adminRepository.getAccountById;
      const pinHash = await bcrypt.hash('888999', 10);

      adminRepository.getAccountById = async (id) => ({
        idaccount: id,
        pin_hash: pinHash,
      });

      try {
        await assert.rejects(
          async () => {
            await adminService.createAdminAccount(
              {
                username: 'newadmin',
                email: 'newadmin@finance.local',
                pin: '000000',
                fullName: 'Nguyễn Quản Trị',
                phone: '0912345678',
              },
              { idaccount: 1 }
            );
          },
          (err) => {
            assert.strictEqual(err.statusCode, 400);
            assert.ok(err.message.includes('Mã PIN'));
            return true;
          }
        );
      } finally {
        adminRepository.getAccountById = origGet;
      }
    });

    it('should create admin account successfully when creator PIN is valid and username/email are fresh', async () => {
      const origGet = adminRepository.getAccountById;
      const origFind = adminRepository.findAccountByUsernameOrEmail;
      const origCreate = adminRepository.createAdminAccount;

      const pinHash = await bcrypt.hash('888999', 10);

      adminRepository.getAccountById = async (id) => ({
        idaccount: id,
        pin_hash: pinHash,
      });

      adminRepository.findAccountByUsernameOrEmail = async () => null;

      adminRepository.createAdminAccount = async ({ username, email, createdByAdminId, fullName, phone, address, countryCode }) => ({
        idaccount: 100,
        username,
        email,
        fullname: fullName || `Quản trị viên ${username}`,
        phone,
        address,
        country_code: countryCode || '+84',
        idrole: 1,
        status: 'Active',
        is_first_login: true,
        created_by_admin_id: createdByAdminId,
      });

      try {
        const result = await adminService.createAdminAccount(
          {
            username: 'superadmin2',
            email: 'superadmin2@finance.local',
            pin: '888999',
            fullName: 'Lê Văn Admin',
            phone: '0987654321',
            address: '123 Phố Tài Chính, Q.1',
            countryCode: '+84',
          },
          { idaccount: 1 }
        );

        assert.strictEqual(result.success, true);
        assert.strictEqual(result.data.username, 'superadmin2');
        assert.strictEqual(result.data.fullname, 'Lê Văn Admin');
        assert.strictEqual(result.data.phone, '0987654321');
        assert.strictEqual(result.data.is_first_login, true);
        assert.strictEqual(result.data.created_by_admin_id, 1);
      } finally {
        adminRepository.getAccountById = origGet;
        adminRepository.findAccountByUsernameOrEmail = origFind;
        adminRepository.createAdminAccount = origCreate;
      }
    });
  });

  describe('calcUptimePercent (PO Formula)', () => {
    it('should return 100% when there is no maintenance downtime', async () => {
      const { defaultMaintenanceRepository } = require('../../modules/admin/maintenance.repository');
      const origGet = defaultMaintenanceRepository.getTotalMaintenanceDowntimeSeconds;
      defaultMaintenanceRepository.getTotalMaintenanceDowntimeSeconds = async () => 0;

      try {
        // Giả lập hệ thống chạy 2 tiếng (7200s), không bảo trì
        const result = await adminService.calcUptimePercent(7200);
        assert.strictEqual(result.uptimePercent, 100);
        assert.strictEqual(result.uptimeSeconds, 7200);
        assert.strictEqual(result.totalSeconds, 7200);
        assert.strictEqual(result.downtimeSeconds, 0);
      } finally {
        defaultMaintenanceRepository.getTotalMaintenanceDowntimeSeconds = origGet;
      }
    });

    it('should return exactly 80% when running 4h out of 5h total with 1h downtime (PO Example)', async () => {
      const { defaultMaintenanceRepository } = require('../../modules/admin/maintenance.repository');
      const origGet = defaultMaintenanceRepository.getTotalMaintenanceDowntimeSeconds;
      // 1 giờ bảo trì = 3600 giây
      defaultMaintenanceRepository.getTotalMaintenanceDowntimeSeconds = async () => 3600;

      try {
        // Tổng thời gian = 5 tiếng (18000s)
        const result = await adminService.calcUptimePercent(18000);
        assert.strictEqual(result.uptimePercent, 80);
        assert.strictEqual(result.uptimeSeconds, 14400); // 4 tiếng chạy thực tế
        assert.strictEqual(result.totalSeconds, 18000);  // 5 tiếng tổng thời gian
        assert.strictEqual(result.downtimeSeconds, 3600);
      } finally {
        defaultMaintenanceRepository.getTotalMaintenanceDowntimeSeconds = origGet;
      }
    });
  });
});
