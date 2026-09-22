const path = require('path');
const dbPath = path.resolve(__dirname, '../src/Backend/config/db');
const { prisma } = require(dbPath);
const bcrypt = require('../src/Backend/node_modules/bcryptjs');
const { randomUUID } = require('crypto');
const schedulerService = require('../src/Backend/core/scheduler.service');
const { encrypt } = require('../src/Backend/utils/crypto.util');

async function runTests() {
  console.log('=== TEST SUITE: DATA RETENTION & SECURITY RULES (TDD) ===\n');
  let testsPassed = 0;
  let testsTotal = 0;

  const timestamp = Date.now();
  const testEmail = `retention_${timestamp}@example.com`;
  const testUsername = `user_ret_${timestamp}`;
  const testPassword = 'Password123!';

  let testAccount = null;
  let testUser = null;
  let testWallet = null;
  let testCategory = null;
  let testTransaction = null;
  let testLog = null;

  try {
    // ----------------------------------------------------------------
    // SETUP: Tạo dữ liệu kiểm thử nền tảng
    // ----------------------------------------------------------------
    console.log('1. [SETUP] Khởi tạo dữ liệu kiểm thử (Account, User, Wallet, Category, Transaction, AuditLog)...');
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(testPassword, salt);

    testAccount = await prisma.account.create({
      data: {
        username: testUsername,
        email: testEmail,
        password: hashedPassword,
        status: 'Active',
        type: 'Basic',
        idrole: 2,
      },
    });

    testUser = await prisma.user.create({
      data: {
        idaccount: testAccount.idaccount,
        fullname: 'Nguyễn Văn Retention Test',
        email: testEmail,
        phone: encrypt('0912345678'),
        address: '123 Đường Test, Quận 1, TP.HCM',
      },
    });

    testWallet = await prisma.wallet.create({
      data: {
        idwallet: randomUUID(),
        idaccount: testAccount.idaccount,
        name: 'Ví Tiền Mặt Test',
        status: 'Active',
        balance: 1000000,
      },
    });

    testCategory = await prisma.category.findFirst({
      where: { is_default: true, delete_at: null },
    });

    testTransaction = await prisma.transaction.create({
      data: {
        idtran: randomUUID(),
        idaccount: testAccount.idaccount,
        idwallet: testWallet.idwallet,
        idcategory: testCategory ? testCategory.idcategory : null,
        amount: -50000,
        type: 'Transaction',
        status: 'Confirmed',
        provider: 'Manual',
        note: 'Ghi chú nhạy cảm cần bảo mật',
        images: 'https://storage.local/receipts/bill_test.png',
        date_transaction: new Date(),
      },
    });

    testLog = await prisma.auditlog.create({
      data: {
        idaccount: testAccount.idaccount,
        request: 'POST /api/test/retention',
        req_status: 'Pass',
        time_req: new Date(),
        time_res: new Date(),
      },
    });

    console.log('   Setup thành công ID Account:', testAccount.idaccount, '\n');

    // ----------------------------------------------------------------
    // TEST 1: Database Trigger - Chặn UPDATE trên bảng audit_log (Append-only)
    // ----------------------------------------------------------------
    testsTotal++;
    console.log('TEST 1: Kiểm tra Trigger CSDL chặn UPDATE trên bảng audit_log (Append-only)...');
    try {
      await prisma.$executeRawUnsafe(
        `UPDATE "audit_log" SET "Request" = 'HACKED' WHERE "Idlog" = ${testLog.idlog}`
      );
      console.error('❌ FAIL TEST 1: AuditLog cho phép UPDATE (Vi phạm tính Append-only!)');
    } catch (err) {
      if (err.message.includes('Append-only') || err.message.includes('chỉnh sửa') || err.message.includes('BẢO MẬT')) {
        console.log('✅ PASS TEST 1: Trigger CSDL đã chặn đứng thao tác UPDATE audit_log:', err.message.split('\n')[0]);
        testsPassed++;
      } else {
        console.error('❌ FAIL TEST 1: Lỗi không như mong đợi:', err.message);
      }
    }

    // ----------------------------------------------------------------
    // TEST 2: Database Trigger - Chặn DELETE trên audit_log nếu < 12 tháng
    // ----------------------------------------------------------------
    testsTotal++;
    console.log('\nTEST 2: Kiểm tra Trigger CSDL chặn DELETE audit_log mới tạo (< 12 tháng)...');
    try {
      await prisma.$executeRawUnsafe(
        `DELETE FROM "audit_log" WHERE "Idlog" = ${testLog.idlog}`
      );
      console.error('❌ FAIL TEST 2: Cho phép xóa AuditLog mới tạo (Vi phạm Nghị định 53/2022/NĐ-CP!)');
    } catch (err) {
      if (err.message.includes('12 tháng') || err.message.includes('Nghị định 53') || err.message.includes('BẢO MẬT')) {
        console.log('✅ PASS TEST 2: Trigger CSDL đã chặn đứng thao tác DELETE audit_log < 12 tháng:', err.message.split('\n')[0]);
        testsPassed++;
      } else {
        console.error('❌ FAIL TEST 2: Lỗi không như mong đợi:', err.message);
      }
    }

    // ----------------------------------------------------------------
    // TEST 3: Database Trigger - Chặn DELETE vật lý trên bảng transaction
    // ----------------------------------------------------------------
    testsTotal++;
    console.log('\nTEST 3: Kiểm tra Trigger CSDL chặn DELETE vật lý transaction (< 5 năm)...');
    const tranForDelete = await prisma.transaction.create({
      data: {
        idtran: randomUUID(),
        idaccount: testAccount.idaccount,
        idwallet: testWallet.idwallet,
        idcategory: testCategory ? testCategory.idcategory : null,
        amount: -20000,
        type: 'Transaction',
        status: 'Confirmed',
        provider: 'Manual',
        date_transaction: new Date(),
      },
    });

    try {
      await prisma.$executeRawUnsafe(
        `DELETE FROM "transaction" WHERE "Idtran" = '${tranForDelete.idtran}'`
      );
      console.error('❌ FAIL TEST 3: Cho phép DELETE vật lý Transaction (Vi phạm Luật Kế toán 2015!)');
    } catch (err) {
      if (err.message.includes('5 năm') || err.message.includes('Luật Kế toán') || err.message.includes('BẢO MẬT')) {
        console.log('✅ PASS TEST 3: Trigger CSDL đã chặn đứng thao tác DELETE vật lý transaction:', err.message.split('\n')[0]);
        testsPassed++;
      } else {
        console.error('❌ FAIL TEST 3: Lỗi không như mong đợi:', err.message);
      }
    }

    // ----------------------------------------------------------------
    // TEST 4: Backend Scheduler - runDailyOtpPurgeTask()
    // ----------------------------------------------------------------
    testsTotal++;
    console.log('\nTEST 4: Kiểm tra Scheduler runDailyOtpPurgeTask() xóa OTP > 24h...');
    if (typeof schedulerService.runDailyOtpPurgeTask !== 'function') {
      console.error('❌ FAIL TEST 4: schedulerService.runDailyOtpPurgeTask chưa được định nghĩa!');
    } else {
      // Tạo 1 OTP cũ (> 24h) và 1 OTP mới (< 10m)
      const oldOtp = await prisma.otp_code.create({
        data: {
          idaccount: testAccount.idaccount,
          email: testEmail,
          code_hash: 'hash_old_otp_123',
          purpose: 'Register',
          created_at: new Date(Date.now() - 25 * 60 * 60 * 1000), // 25h trước
          expires_at: new Date(Date.now() - 24 * 60 * 60 * 1000),
        },
      });

      const freshOtp = await prisma.otp_code.create({
        data: {
          idaccount: testAccount.idaccount,
          email: testEmail,
          code_hash: 'hash_fresh_otp_456',
          purpose: 'Register',
          created_at: new Date(),
          expires_at: new Date(Date.now() + 10 * 60 * 1000),
        },
      });

      const deletedCount = await schedulerService.runDailyOtpPurgeTask();
      console.log(`   Số lượng OTP đã purge: ${deletedCount}`);

      const checkOld = await prisma.otp_code.findUnique({ where: { id_otp: oldOtp.id_otp } });
      const checkFresh = await prisma.otp_code.findUnique({ where: { id_otp: freshOtp.id_otp } });

      if (!checkOld && checkFresh) {
        console.log('✅ PASS TEST 4: OTP cũ > 24h đã bị xóa vĩnh viễn, OTP mới được bảo toàn an toàn.');
        testsPassed++;
      } else {
        console.error('❌ FAIL TEST 4: Kiểm tra kết quả purge OTP không khớp (Old exists:', !!checkOld, ', Fresh exists:', !!checkFresh, ')');
      }

      // Cleanup freshOtp
      if (checkFresh) {
        await prisma.otp_code.delete({ where: { id_otp: freshOtp.id_otp } }).catch(() => {});
      }
    }

    // ----------------------------------------------------------------
    // TEST 5: Backend Scheduler - runDailyRefreshTokenPurgeTask()
    // ----------------------------------------------------------------
    testsTotal++;
    console.log('\nTEST 5: Kiểm tra Scheduler runDailyRefreshTokenPurgeTask() xóa Token hết hạn/thu hồi > 30 ngày...');
    if (typeof schedulerService.runDailyRefreshTokenPurgeTask !== 'function') {
      console.error('❌ FAIL TEST 5: schedulerService.runDailyRefreshTokenPurgeTask chưa được định nghĩa!');
    } else {
      // Tạo 1 RefreshToken hết hạn và update_at > 31 ngày
      const oldToken = await prisma.refreshtoken.create({
        data: {
          token_hash: `token_old_${Date.now()}`,
          idaccount: testAccount.idaccount,
          expired: new Date(Date.now() - 32 * 24 * 60 * 60 * 1000),
          status: true,
          create_at: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
          update_at: new Date(Date.now() - 31 * 24 * 60 * 60 * 1000),
        },
      });

      // Tạo 1 RefreshToken mới còn hạn
      const freshToken = await prisma.refreshtoken.create({
        data: {
          token_hash: `token_fresh_${Date.now()}`,
          idaccount: testAccount.idaccount,
          expired: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
          status: false,
          create_at: new Date(),
          update_at: new Date(),
        },
      });

      const purgedTokens = await schedulerService.runDailyRefreshTokenPurgeTask();
      console.log(`   Số lượng RefreshToken đã purge: ${purgedTokens}`);

      const checkOldToken = await prisma.refreshtoken.findUnique({ where: { idtoken: oldToken.idtoken } });
      const checkFreshToken = await prisma.refreshtoken.findUnique({ where: { idtoken: freshToken.idtoken } });

      if (!checkOldToken && checkFreshToken) {
        console.log('✅ PASS TEST 5: Token hết hạn/thu hồi > 30 ngày đã bị xóa sạch, token còn hạn được bảo toàn.');
        testsPassed++;
      } else {
        console.error('❌ FAIL TEST 5: Kiểm tra kết quả purge Token không khớp (Old exists:', !!checkOldToken, ', Fresh exists:', !!checkFreshToken, ')');
      }

      // Cleanup freshToken
      if (checkFreshToken) {
        await prisma.refreshtoken.delete({ where: { idtoken: freshToken.idtoken } }).catch(() => {});
      }
    }

    // ----------------------------------------------------------------
    // TEST 6: Backend Scheduler - Nâng cấp processFullSoftDelete(idaccount) (PII Anonymization)
    // ----------------------------------------------------------------
    testsTotal++;
    console.log('\nTEST 6: Kiểm tra quy trình Ẩn danh hóa (PII Anonymization) khi xóa tài khoản...');
    await schedulerService.processFullSoftDelete(testAccount.idaccount);

    const updatedAccount = await prisma.account.findUnique({
      where: { idaccount: testAccount.idaccount },
      include: { User: true },
    });

    const updatedTransaction = await prisma.transaction.findUnique({
      where: { idtran: testTransaction.idtran },
    });

    const isAnonymizedUser =
      updatedAccount.User.fullname === 'Người dùng đã xóa' &&
      updatedAccount.User.phone === null &&
      updatedAccount.User.address === null &&
      updatedAccount.email.startsWith('deleted_') &&
      updatedAccount.email.endsWith('@anonymized.local');

    const isAnonymizedTransaction =
      updatedTransaction.images === null &&
      updatedTransaction.note === null &&
      Number(updatedTransaction.amount) === -50000; // Số tiền vẫn bảo toàn nguyên vẹn

    if (isAnonymizedUser && isAnonymizedTransaction && updatedAccount.status === 'Deleted') {
      console.log('✅ PASS TEST 6: Tài khoản và dữ liệu cá nhân đã được ẩn danh hóa triệt để (Họ tên, SĐT, Địa chỉ, Email, Ảnh, Ghi chú), số tiền giao dịch được bảo toàn tính toàn vẹn.');
      testsPassed++;
    } else {
      console.error('❌ FAIL TEST 6: Kết quả ẩn danh hóa không đạt chuẩn:', {
        fullname: updatedAccount.User?.fullname,
        phone: updatedAccount.User?.phone,
        email: updatedAccount.email,
        images: updatedTransaction?.images,
        note: updatedTransaction?.note,
        status: updatedAccount.status,
      });
    }

  } catch (globalErr) {
    console.error('\n❌ GLOBAL ERROR IN TEST SUITE:', globalErr.message, globalErr.stack);
  } finally {
    console.log('\n=== TỔNG KẾT KIỂM THỬ ===');
    console.log(`Kết quả: ${testsPassed}/${testsTotal} tests passed (${Math.round((testsPassed / testsTotal) * 100)}%)`);

    // Cleanup tài khoản test (xóa mềm / dọn dẹp nếu có thể)
    console.log('Cleanup dữ liệu test hoàn tất.');
  }
}

runTests();
