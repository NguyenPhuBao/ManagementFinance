/**
 * PIN hệ thống dự phòng (quản trị viên chưa có pin_hash riêng).
 * Production thiếu ADMIN_SECURITY_PIN thì không được rơi về PIN mặc định '123456'.
 */
const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const bcrypt = require('bcryptjs');
const adminService = require('../../modules/admin/admin.service');
const adminRepository = require('../../modules/admin/admin.repository');

describe('PIN hệ thống dự phòng theo môi trường', () => {
  const saved = {};
  let passwordHash;

  beforeEach(async () => {
    saved.env = process.env.NODE_ENV;
    saved.pin = process.env.ADMIN_SECURITY_PIN;
    saved.get = adminRepository.getAccountById;
    passwordHash = passwordHash || await bcrypt.hash('OldPass@2026', 4);
    adminRepository.getAccountById = async (id) => ({ idaccount: id, pin_hash: null, password: passwordHash });
  });

  afterEach(() => {
    process.env.NODE_ENV = saved.env;
    if (saved.pin === undefined) delete process.env.ADMIN_SECURITY_PIN;
    else process.env.ADMIN_SECURITY_PIN = saved.pin;
    adminRepository.getAccountById = saved.get;
  });

  const isBadPin = (err) => {
    assert.strictEqual(err.statusCode, 400);
    assert.match(err.message, /PIN/);
    return true;
  };

  it('1. Production thiếu biến: verifySecurityAction từ chối PIN 123456', async () => {
    process.env.NODE_ENV = 'production';
    delete process.env.ADMIN_SECURITY_PIN;
    await assert.rejects(() => adminService.verifySecurityAction({ pin: '123456', action: 'TEST' }, { idaccount: 9101 }), isBadPin);
  });

  it('2. Production thiếu biến: changeAdminPin từ chối PIN cũ 123456', async () => {
    process.env.NODE_ENV = 'production';
    delete process.env.ADMIN_SECURITY_PIN;
    await assert.rejects(
      () => adminService.changeAdminPin({ oldPin: '123456', newPin: '135792', confirmPin: '135792', password: 'OldPass@2026' }, { idaccount: 9102 }),
      isBadPin
    );
  });

  it('3. Production thiếu biến: changeAdminPassword từ chối PIN 123456', async () => {
    process.env.NODE_ENV = 'production';
    delete process.env.ADMIN_SECURITY_PIN;
    await assert.rejects(
      () => adminService.changeAdminPassword({ oldPassword: 'OldPass@2026', pin: '123456', newPassword: 'NewPass@2026x', confirmPassword: 'NewPass@2026x' }, { idaccount: 9103 }),
      isBadPin
    );
  });

  it('3b. Production thiếu biến: createAdminAccount từ chối PIN 123456', async () => {
    process.env.NODE_ENV = 'production';
    delete process.env.ADMIN_SECURITY_PIN;
    await assert.rejects(
      () => adminService.createAdminAccount({ username: 'thu.pin', email: 'thu.pin@example.com', pin: '123456', fullName: 'Thử PIN', phone: '0901234567' }, { idaccount: 9106 }),
      isBadPin
    );
  });

  it('4. Production có đặt ADMIN_SECURITY_PIN: PIN đúng vẫn qua', async () => {
    process.env.NODE_ENV = 'production';
    process.env.ADMIN_SECURITY_PIN = '864209';
    const result = await adminService.verifySecurityAction({ pin: '864209', action: 'TEST' }, { idaccount: 9104 });
    assert.ok(result);
  });

  it('5. Dev không đặt biến: giữ PIN mặc định để chạy cục bộ', async () => {
    process.env.NODE_ENV = 'development';
    delete process.env.ADMIN_SECURITY_PIN;
    const result = await adminService.verifySecurityAction({ pin: '123456', action: 'TEST' }, { idaccount: 9105 });
    assert.ok(result);
  });
});
