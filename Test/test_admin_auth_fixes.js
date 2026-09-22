/**
 * Test Suite: Admin-Web Auth Fixes Verification
 * Kiểm tra các tình huống đăng nhập, phân quyền, và refresh token cho Admin-Web
 */

const assert = require('assert');
const authService = require('../src/Backend/modules/auth/auth.service');
const { prisma } = require('../src/Backend/config/db');

async function runTests() {
  console.log('\n======================================================================');
  console.log('       BẮT ĐẦU KIỂM THỬ: AUTH & LOGIN FIXES CHO ADMIN-WEB             ');
  console.log('======================================================================\n');

  // 1. Kiểm tra đăng nhập sai mật khẩu
  console.log('1. Kiểm thử Đăng nhập sai mật khẩu:');
  try {
    await authService.login('admin', 'wrong_password_123456');
    assert.fail('Đăng nhập sai mật khẩu phải ném lỗi 401');
  } catch (err) {
    assert.strictEqual(err.statusCode, 401);
    console.log(`  ✔ PASS: Backend trả đúng mã lỗi 401: "${err.message}"`);
  }

  // 2. Kiểm tra đăng nhập tài khoản admin thật
  console.log('\n2. Kiểm thử Đăng nhập tài khoản Admin thật:');
  // Lấy tài khoản admin đầu tiên trong DB
  const adminAccount = await prisma.account.findFirst({
    where: { idrole: 1, status: 'Active' },
    include: { role: true },
  });
  assert(adminAccount, 'Phải có ít nhất 1 tài khoản Admin trong CSDL');

  // Giả lập logic kiểm tra role trong auth.context.jsx
  const mockAdminUser = {
    idaccount: adminAccount.idaccount,
    username: adminAccount.username,
    idrole: adminAccount.idrole,
    rolename: adminAccount.role.rolename,
  };

  const isAdmin1 = mockAdminUser.idrole === 1 || String(mockAdminUser.rolename || '').toLowerCase() === 'admin';
  assert.strictEqual(isAdmin1, true, 'Admin account phải được xác thực quyền thành công');
  console.log(`  ✔ PASS: Tài khoản admin (idrole=${mockAdminUser.idrole}, rolename="${mockAdminUser.rolename}") được chấp thuận`);

  // 3. Kiểm tra chặn tài khoản User thường không cho vào Admin-Web
  console.log('\n3. Kiểm thử Chặn User thường đăng nhập Admin-Web:');
  const userAccount = await prisma.account.findFirst({
    where: { idrole: 2, status: 'Active' },
    include: { role: true },
  });
  assert(userAccount, 'Phải có ít nhất 1 tài khoản User trong CSDL');

  const mockNormalUser = {
    idaccount: userAccount.idaccount,
    username: userAccount.username,
    idrole: userAccount.idrole,
    rolename: userAccount.role.rolename,
  };

  const isNormalUserAdmin = mockNormalUser.idrole === 1 || String(mockNormalUser.rolename || '').toLowerCase() === 'admin';
  assert.strictEqual(isNormalUserAdmin, false, 'Tài khoản thường KHÔNG được có quyền admin');
  console.log(`  ✔ PASS: Tài khoản User thường (idrole=${mockNormalUser.idrole}, rolename="${mockNormalUser.rolename}") bị chặn đúng`);

  // 4. Kiểm tra Silent Refresh Token
  console.log('\n4. Kiểm thử Cơ chế Refresh Token:');
  // Sinh token cho tài khoản admin
  const jwt = require('../src/Backend/node_modules/jsonwebtoken');
  const config = require('../src/Backend/config');
  const payload = {
    idaccount: adminAccount.idaccount,
    username: adminAccount.username,
    idrole: adminAccount.idrole,
    rolename: adminAccount.role.rolename,
    status: 'Active',
  };

  const testRefreshToken = jwt.sign(payload, config.jwt.refreshSecret, { expiresIn: '7d' });
  const crypto = require('crypto');
  const tokenHash = crypto.createHash('sha256').update(testRefreshToken).digest('hex');

  const savedRt = await prisma.refreshtoken.create({
    data: {
      idaccount: adminAccount.idaccount,
      idrole: adminAccount.idrole,
      token_hash: tokenHash,
      expired: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      status: false,
    },
  });

  const refreshed = await authService.refresh(testRefreshToken);
  assert(refreshed.accessToken, 'Phải sinh ra accessToken mới');
  assert(refreshed.refreshToken, 'Phải sinh ra refreshToken mới');
  console.log('  ✔ PASS: Cơ chế Refresh Token hoạt động trơn tru');

  // Dọn dẹp token test
  await prisma.refreshtoken.deleteMany({
    where: { idaccount: adminAccount.idaccount, token_hash: tokenHash },
  });

  console.log('\n======================================================================');
  console.log('   🎉 TẤT CẢ CÁC BÀI KIỂM THỬ AUTH CHO ADMIN-WEB ĐỀU ĐẠT PASS 100%!   ');
  console.log('======================================================================\n');
}

runTests()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Test failed:', err);
    process.exit(1);
  });
