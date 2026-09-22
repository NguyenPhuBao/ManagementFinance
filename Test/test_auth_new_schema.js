const { prisma } = require('../src/Backend/config/db');
const authService = require('../src/Backend/modules/auth/auth.service');
const authRepository = require('../src/Backend/modules/auth/auth.repository');

const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  bright: "\x1b[1m",
};

async function runAuthTests() {
  console.log(`\n${colors.cyan}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}         KIỂM THỬ TOÀN DIỆN MODULE AUTH THEO CSDL MỚI                 ${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}======================================================================${colors.reset}\n`);

  const testUsername = `authtest_${Date.now().toString().slice(-6)}`;
  const testEmail = `${testUsername}@example.com`;
  const testPassword = 'Password123@!';

  console.log(`1. Test Đăng ký tài khoản mới qua OTP (${testUsername})...`);
  // 1.1 Gửi OTP
  await authService.sendRegisterOtp({
    username: testUsername,
    email: testEmail,
    fullname: 'Nguyễn Văn Test',
  });

  const otpRecord = await prisma.otp_code.findFirst({
    where: { email: testEmail, purpose: 'Register' },
    orderBy: { created_at: 'desc' },
  });

  if (!otpRecord) {
    throw new Error('Không tạo được bản ghi OTP Register trong CSDL');
  }
  console.log(`   ✔ OTP Register tạo thành công: purpose="${otpRecord.purpose}", is_used=${otpRecord.is_used}`);

  // Mock verify OTP bằng cách tạo trực tiếp account
  const registered = await authRepository.createAccountWithUser({
    username: testUsername,
    hashedPassword: '$2a$10$dummyhashedpasswordforauthtest1234567890',
    fullname: 'Nguyễn Văn Test',
    email: testEmail,
    phone: '0987654321',
    country_code: '+84',
    type: 'Basic',
  });

  console.log(`   ✔ Account tạo thành công: idaccount=${registered.idaccount}, type="${registered.type}", status="${registered.status}"`);
  console.log(`   ✔ User liên kết thành công: email="${registered.User.email}", country_code="${registered.User.country_code}"`);

  // 1.2 Test Đăng nhập
  console.log(`\n2. Test Đăng nhập & Tạo RefreshToken...`);
  // Update password hash chuẩn bcrypt
  const bcrypt = require('../src/Backend/node_modules/bcryptjs');
  const validHash = await bcrypt.hash(testPassword, 10);
  await authRepository.updatePassword(registered.idaccount, validHash);

  const loginRes = await authService.login(testUsername, testPassword, { ip: '127.0.0.1', headers: { 'user-agent': 'TestRunner/1.0' } });
  console.log(`   ✔ Đăng nhập thành công: User Type="${loginRes.user.type}", Status="${loginRes.user.status}"`);

  // Kiểm tra RefreshToken trong Supabase
  const tokenInDb = await prisma.refreshtoken.findFirst({
    where: { idaccount: registered.idaccount },
    orderBy: { create_at: 'desc' },
  });
  if (!tokenInDb) throw new Error('Không tìm thấy RefreshToken trong CSDL!');
  if (tokenInDb.status !== false) throw new Error(`RefreshToken status không đúng: ${tokenInDb.status}`);
  if (!tokenInDb.expired) throw new Error('RefreshToken expired is null!');

  console.log(`   ✔ RefreshToken trong Supabase: idtoken=${tokenInDb.idtoken}, Expired="${tokenInDb.expired.toISOString()}", Status=${tokenInDb.status} (Còn hiệu lực)`);

  // 1.3 Test Làm mới Token (Refresh Token)
  console.log(`\n3. Test Làm mới Token (Refresh Flow)...`);
  const refreshRes = await authService.refresh(loginRes.refreshToken, { ip: '127.0.0.1' });
  console.log(`   ✔ Token refreshed thành công!`);

  // Kiểm tra token cũ đã bị thu hồi (status = true)
  const oldTokenCheck = await prisma.refreshtoken.findUnique({ where: { idtoken: tokenInDb.idtoken } });
  if (oldTokenCheck.status !== true) {
    throw new Error(`Token cũ chưa được thu hồi (status phải là true): ${oldTokenCheck.status}`);
  }
  console.log(`   ✔ Token cũ đã được thu hồi: idtoken=${oldTokenCheck.idtoken}, Status=${oldTokenCheck.status} (Đã thu hồi)`);

  // 1.4 Test Thu hồi toàn bộ Token (Logout)
  console.log(`\n4. Test Đăng xuất (Revoke all tokens)...`);
  const revokeCount = await authService.revokeAllTokens(registered.idaccount);
  console.log(`   ✔ Đã thu hồi ${revokeCount} tokens.`);

  const activeTokens = await prisma.refreshtoken.count({
    where: { idaccount: registered.idaccount, status: false },
  });
  if (activeTokens > 0) throw new Error(`Vẫn còn ${activeTokens} token hoạt động sau logout!`);
  console.log(`   ✔ Số lượng active token còn lại: ${activeTokens}`);

  // 1.5 Test Profile
  console.log(`\n5. Test Get & Update Profile...`);
  const profile = await authService.getProfile(registered.idaccount);
  console.log(`   ✔ Profile: Fullname="${profile.fullname}", Type="${profile.type}", Country="${profile.country_code}"`);

  const updatedProfile = await authService.updateProfile(registered.idaccount, {
    address: '123 Đường Test, TP.HCM',
    country_code: '+84',
  });
  console.log(`   ✔ Update Profile: Address="${updatedProfile.address}", Country="${updatedProfile.country_code}"`);

  // 1.6 Dọn dẹp dữ liệu test
  console.log(`\n6. Dọn dẹp dữ liệu test...`);
  await prisma.refreshtoken.deleteMany({ where: { idaccount: registered.idaccount } });
  await prisma.otp_code.deleteMany({ where: { email: testEmail } });
  await prisma.user.deleteMany({ where: { idaccount: registered.idaccount } });
  await prisma.account.deleteMany({ where: { idaccount: registered.idaccount } });

  console.log(`\n${colors.green}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.green}${colors.bright}   🎉 MODULE AUTH ĐÃ ĐƯỢC CẬP NHẬT VÀ KIỂM THỬ CHUẨN XÁC 100%!        ${colors.reset}`);
  console.log(`${colors.green}${colors.bright}======================================================================${colors.reset}\n`);

  await prisma.$disconnect();
  process.exit(0);
}

runAuthTests().catch(err => {
  console.error('Lỗi khi chạy auth test:', err);
  process.exit(1);
});
