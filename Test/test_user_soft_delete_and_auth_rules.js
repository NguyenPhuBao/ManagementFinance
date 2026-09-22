const path = require('path');
const dbPath = path.resolve(__dirname, '../src/Backend/config/db');
const { prisma } = require(dbPath);
const bcrypt = require('../src/Backend/node_modules/bcryptjs');
const { randomUUID } = require('crypto');
const adminService = require('../src/Backend/modules/admin/admin.service');
const authService = require('../src/Backend/modules/auth/auth.service');
const { isAccountValid } = require('../src/Backend/middleware/auth');
const { encrypt, hashBlindIndex } = require('../src/Backend/utils/crypto.util');

async function runTests() {
  console.log('=== TEST SUITE: USER SOFT DELETE & AUTH RULES ===\n');
  let testsPassed = 0;
  let testsTotal = 0;

  const timestamp = Date.now();
  const testEmail = `test_delete_${timestamp}@example.com`;
  const testUsername = `user_del_${timestamp}`;
  const testPassword = 'Password123!';
  const testPhone = '0987654321';

  let createdAccount = null;
  let createdUser = null;
  let wallet1 = null;
  let wallet2 = null;
  let bankAcc = null;

  try {
    // ----------------------------------------------------------------
    // SETUP: Tạo một user hoàn chỉnh kèm 2 ví và 1 bank account
    // ----------------------------------------------------------------
    console.log('1. [SETUP] Tạo user test kèm 2 ví và 1 tài khoản ngân hàng...');
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(testPassword, salt);

    createdAccount = await prisma.account.create({
      data: {
        username: testUsername,
        email: testEmail,
        password: hashedPassword,
        status: 'Active',
        type: 'Basic',
        idrole: 2,
      },
    });

    createdUser = await prisma.user.create({
      data: {
        idaccount: createdAccount.idaccount,
        fullname: 'Nguyễn Văn Test Delete',
        email: testEmail,
        phone: encrypt(testPhone),
      },
    });

    wallet1 = await prisma.wallet.create({
      data: {
        idwallet: randomUUID(),
        idaccount: createdAccount.idaccount,
        name: 'Ví Tiền Mặt Test',
        status: 'Active',
      },
    });

    wallet2 = await prisma.wallet.create({
      data: {
        idwallet: randomUUID(),
        idaccount: createdAccount.idaccount,
        name: 'Ví Tiết Kiệm Test',
        status: 'Active',
      },
    });

    bankAcc = await prisma.bank_account.create({
      data: {
        id_bank_account: randomUUID(),
        idaccount: createdAccount.idaccount,
        id_casso_account: `casso_${timestamp}`,
        account_number: encrypt('1234567890'),
        account_number_hash: hashBlindIndex('1234567890'),
        account_name: 'NGUYEN VAN TEST DELETE',
        bank_name: 'MBBank',
        connect_status: 'Active',
      },
    });

    // Tạo 1 refresh token
    await prisma.refreshtoken.create({
      data: {
        token_hash: `hash_${timestamp}`,
        idaccount: createdAccount.idaccount,
        idrole: 2,
        expired: new Date(Date.now() + 86400000),
        status: false,
      },
    });

    console.log(`   -> Tạo thành công user id=${createdUser.iduser}, idaccount=${createdAccount.idaccount}`);

    // ----------------------------------------------------------------
    // TEST 1: Soft-delete User via adminService.deleteUser
    // ----------------------------------------------------------------
    testsTotal++;
    console.log('\n2. [TEST 1] Thực thi adminService.deleteUser()...');
    const deleteResult = await adminService.deleteUser(createdUser.iduser);
    console.log('   deleteResult:', deleteResult);

    // Kiểm tra DB
    const checkAccount = await prisma.account.findUnique({ where: { idaccount: createdAccount.idaccount } });
    const checkUser = await prisma.user.findUnique({ where: { iduser: createdUser.iduser } });
    const checkWallets = await prisma.wallet.findMany({ where: { idaccount: createdAccount.idaccount } });
    const checkBank = await prisma.bank_account.findUnique({ where: { id_bank_account: bankAcc.id_bank_account } });
    const checkTokens = await prisma.refreshtoken.findMany({ where: { idaccount: createdAccount.idaccount } });

    const isAccountSoftDeleted = checkAccount.delete_at !== null && (checkAccount.status === 'Deleted' || checkAccount.status === 'Inactive');
    const isUserSoftDeleted = checkUser.delete_at !== null;
    const allWalletsInactive = checkWallets.every(w => w.status === 'Inactive');
    const bankDisconnected = checkBank.connect_status === 'Disconnected';
    const allTokensRevoked = checkTokens.every(t => t.status === true);
    const validCheck = await isAccountValid(createdAccount.idaccount);

    if (isAccountSoftDeleted && isUserSoftDeleted && allWalletsInactive && bankDisconnected && allTokensRevoked && validCheck === false) {
      console.log('   ✓ PASS: Xóa mềm account, user, ví inactive, bank disconnected, tokens revoked, cache invalid!');
      testsPassed++;
    } else {
      console.error('   ❌ FAIL: Trạng thái sau xóa mềm không đúng!', {
        isAccountSoftDeleted,
        isUserSoftDeleted,
        allWalletsInactive,
        bankDisconnected,
        allTokensRevoked,
        validCheck,
      });
    }

    // ----------------------------------------------------------------
    // TEST 2: Tạo lại tài khoản mới với Email & SĐT trùng sau khi đã xóa mềm
    // ----------------------------------------------------------------
    testsTotal++;
    console.log('\n3. [TEST 2] Tạo lại tài khoản mới với Email & SĐT trùng của tài khoản đã xóa mềm...');
    const reRegisterUsername = `new_acc_${timestamp}`;
    const reRegisterPassword = 'DifferentPassword456!';
    try {
      const newSalt = await bcrypt.genSalt(10);
      const newHashed = await bcrypt.hash(reRegisterPassword, newSalt);

      const reAccount = await prisma.account.create({
        data: {
          username: reRegisterUsername,
          email: testEmail, // Email trùng tài khoản đã xóa mềm
          password: newHashed,
          status: 'Active',
          type: 'Basic',
          idrole: 2,
        },
      });

      const reUser = await prisma.user.create({
        data: {
          idaccount: reAccount.idaccount,
          fullname: 'Người dùng tái tạo',
          email: testEmail, // Email trùng
          phone: encrypt(testPhone), // SĐT trùng
        },
      });

      console.log(`   ✓ PASS: Tạo thành công tài khoản mới (idaccount=${reAccount.idaccount}) dùng trùng email & sđt!`);
      testsPassed++;

      // Dọn dẹp tài khoản tái tạo
      await prisma.user.delete({ where: { iduser: reUser.iduser } });
      await prisma.account.delete({ where: { idaccount: reAccount.idaccount } });
    } catch (err) {
      console.error('   ❌ FAIL: Không thể tạo tài khoản với email/sđt trùng:', err.message);
    }

    // ----------------------------------------------------------------
    // TEST 3: Ràng buộc cặp (Username + Password)
    // ----------------------------------------------------------------
    testsTotal++;
    console.log('\n4. [TEST 3] Kiểm tra logic cặp (Username + Password)...');

    // Tạo 1 tài khoản base để test cặp username/password
    const baseUsername = `base_user_${timestamp}`;
    const basePassword = 'BasePassword123!';
    const baseSalt = await bcrypt.genSalt(10);
    const baseHash = await bcrypt.hash(basePassword, baseSalt);

    const baseAccount = await prisma.account.create({
      data: {
        username: baseUsername,
        email: `base_${timestamp}@example.com`,
        password: baseHash,
        status: 'Active',
        type: 'Basic',
        idrole: 2,
      },
    });
    const baseUser = await prisma.user.create({
      data: {
        idaccount: baseAccount.idaccount,
        fullname: 'Base User Test',
        email: `base_${timestamp}@example.com`,
      },
    });

    // Case 3a: Trùng CẢ Username VÀ Password -> Bị từ chối
    let case3aBlocked = false;
    try {
      await authService.validateUsernamePasswordPair(baseUsername, basePassword);
    } catch (err) {
      case3aBlocked = true;
      console.log('   ✓ Case 3a: Trùng cả username & password bị chặn thành công:', err.message);
    }

    // Case 3b: Trùng Username nhưng KHÁC Password -> Cho phép
    let case3bAllowed = false;
    try {
      await authService.validateUsernamePasswordPair(baseUsername, 'DifferentPassword789!');
      case3bAllowed = true;
      console.log('   ✓ Case 3b: Trùng username nhưng khác password được phép!');
    } catch (err) {
      console.error('   ❌ Case 3b: Lẽ ra phải cho phép nhưng bị chặn:', err.message);
    }

    // Case 3c: Khác Username nhưng CÙNG Password -> Cho phép
    let case3cAllowed = false;
    try {
      await authService.validateUsernamePasswordPair(`diff_user_${timestamp}`, basePassword);
      case3cAllowed = true;
      console.log('   ✓ Case 3c: Khác username nhưng cùng password được phép!');
    } catch (err) {
      console.error('   ❌ Case 3c: Lẽ ra phải cho phép nhưng bị chặn:', err.message);
    }

    if (case3aBlocked && case3bAllowed && case3cAllowed) {
      console.log('   ✓ PASS: Ràng buộc cặp (Username + Password) hoạt động chính xác 100%!');
      testsPassed++;
    } else {
      console.error('   ❌ FAIL: Một trong các case ràng buộc username/password bị sai!', {
        case3aBlocked,
        case3bAllowed,
        case3cAllowed,
      });
    }

    // Dọn dẹp base user
    await prisma.user.delete({ where: { iduser: baseUser.iduser } });
    await prisma.account.delete({ where: { idaccount: baseAccount.idaccount } });

    // ----------------------------------------------------------------
    // TEST 4: Đăng nhập với tài khoản bị xóa mềm -> Bị từ chối
    // ----------------------------------------------------------------
    testsTotal++;
    console.log('\n5. [TEST 4] Kiểm tra đăng nhập tài khoản đã xóa mềm...');
    try {
      await authService.login(testUsername, testPassword);
      console.error('   ❌ FAIL: Đăng nhập được vào tài khoản đã xóa mềm!');
    } catch (err) {
      if (err.statusCode === 403) {
        console.log('   ✓ PASS: Đăng nhập vào tài khoản đã xóa mềm bị từ chối với mã 403:', err.message);
        testsPassed++;
      } else {
        console.error('   ❌ FAIL: Mã lỗi không phải 403:', err);
      }
    }

  } catch (error) {
    console.error('Unexpected test failure:', error);
  } finally {
    // Cleanup created test data
    console.log('\n[CLEANUP] Dọn dẹp dữ liệu test...');
    if (wallet1) await prisma.wallet.deleteMany({ where: { idwallet: { in: [wallet1.idwallet, wallet2?.idwallet].filter(Boolean) } } });
    if (bankAcc) await prisma.bank_account.deleteMany({ where: { id_bank_account: bankAcc.id_bank_account } });
    if (createdAccount) await prisma.refreshtoken.deleteMany({ where: { idaccount: createdAccount.idaccount } });
    if (createdUser) await prisma.user.deleteMany({ where: { iduser: createdUser.iduser } });
    if (createdAccount) await prisma.account.deleteMany({ where: { idaccount: createdAccount.idaccount } });
    console.log('[CLEANUP] Hoàn tất.');
    await prisma.$disconnect();
  }

  console.log(`\n========================================`);
  console.log(`KẾT QUẢ KIỂM THỬ: ${testsPassed}/${testsTotal} BÀI PASS`);
  console.log(`========================================\n`);

  if (testsPassed === testsTotal) {
    process.exit(0);
  } else {
    process.exit(1);
  }
}

runTests();
