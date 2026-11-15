/**
 * Xác thực thao tác nhạy cảm CHỈ bằng mã PIN quản trị, không nhận mật khẩu.
 * Lý do: kẻ gian lấy được mật khẩu (đăng nhập được) vẫn không thay đổi được hệ thống nếu không có PIN.
 * Mọi thao tác nhạy cảm (khoá người dùng, bảo trì, danh mục, hoàn tiền, xem IP, chính sách, sự cố dữ liệu)
 * đều đi qua adminService.verifySecurityAction.
 */
const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const bcrypt = require('bcryptjs');
const adminService = require('../../modules/admin/admin.service');
const adminRepository = require('../../modules/admin/admin.repository');

describe('verifySecurityAction chỉ nhận mã PIN', () => {
  let saved;
  let pinHash;
  let passHash;

  beforeEach(async () => {
    saved = adminRepository.getAccountById;
    pinHash = pinHash || await bcrypt.hash('246810', 4);
    passHash = passHash || await bcrypt.hash('Admin@2026', 4);
    adminRepository.getAccountById = async (id) => ({ idaccount: id, pin_hash: pinHash, password: passHash });
  });
  afterEach(() => { adminRepository.getAccountById = saved; });

  const rejectsWith = (status, pattern) => (err) => {
    assert.strictEqual(err.statusCode, status);
    assert.match(err.message, pattern);
    assert.doesNotMatch(err.message, /mật khẩu/i, 'thông báo không còn nhắc tới mật khẩu');
    return true;
  };

  it('Chỉ gửi mật khẩu đúng, không có PIN ⇒ 400, yêu cầu nhập PIN', async () => {
    await assert.rejects(
      () => adminService.verifySecurityAction({ password: 'Admin@2026', action: 'TEST' }, { idaccount: 9201 }),
      rejectsWith(400, /PIN/)
    );
  });

  it('PIN sai kèm mật khẩu đúng ⇒ vẫn bị từ chối', async () => {
    await assert.rejects(
      () => adminService.verifySecurityAction({ pin: '000000', password: 'Admin@2026', action: 'TEST' }, { idaccount: 9202 }),
      rejectsWith(400, /PIN/)
    );
  });

  it('Không gửi gì ⇒ 400, thông báo chỉ nói tới PIN', async () => {
    await assert.rejects(() => adminService.verifySecurityAction({}, { idaccount: 9203 }), rejectsWith(400, /PIN/));
  });

  it('PIN đúng ⇒ xác thực thành công', async () => {
    const r = await adminService.verifySecurityAction({ pin: '246810', action: 'TEST', targetId: 'x' }, { idaccount: 9204 });
    assert.strictEqual(r.verified, true);
  });
});
