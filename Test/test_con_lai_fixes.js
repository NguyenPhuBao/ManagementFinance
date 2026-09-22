/**
 * Test Suite: Kiểm thử tự động các nội dung kỹ thuật còn lại sau cbbeeb4 (CON_LAI_SAU_CBBEEB4.md)
 * 
 * 1. Chốt chống thanh toán hai lần (BILL_ALREADY_PAID) tại upsertTransaction
 * 2. Bẫy thứ tự trong lô (dangXoaTrongLo) cho phép hoàn tác và trả lại trong cùng lô
 * 3. Cho phép cập nhật thông tin giao dịch hiện tại mà không bị tự chặn
 * 4. Kiểm thử mã lỗi WALLET_NAME_DUPLICATE khi tạo ví trùng tên
 * 5. Kiểm thử /auth/refresh trả kèm mã ACCOUNT_DELETED / idaccount khi token đã thu hồi của tài khoản bị xoá (G36)
 */

const { prisma } = require('../src/Backend/config/db');
const syncService = require('../src/Backend/modules/sync/sync.service');
const authService = require('../src/Backend/modules/auth/auth.service');
const assert = require('assert');
const crypto = require('crypto');

function uuidv4() {
  return crypto.randomUUID();
}

async function runTests() {
  console.log('======================================================================');
  console.log('   BẮT ĐẦU KIỂM THỬ TỰ ĐỘNG CÁC NỘI DUNG KỸ THUẬT (CON_LAI_SAU_CBBEEB4)   ');
  console.log('======================================================================\n');

  let testAccount = null;
  let testWallet = null;
  let testCategory = null;
  let testBill = null;

  try {
    // 0. Chuẩn bị dữ liệu mẫu
    const uniqueSuffix = Date.now();
    testAccount = await prisma.account.create({
      data: {
        idrole: 2,
        email: `test_con_lai_${uniqueSuffix}@example.com`,
        username: `user_con_lai_${uniqueSuffix}`,
        password: 'hashed_password_placeholder',
        status: 'Active',
        type: 'Basic',
      },
    });

    testWallet = await prisma.wallet.create({
      data: {
        idwallet: uuidv4(),
        idaccount: testAccount.idaccount,
        name: `Ví Test Bill ${uniqueSuffix}`,
        type: 'Cash',
        balance: 1000000,
        currency: 'VND',
        status: 'Active',
        include_in_total: true,
        is_default: false,
      },
    });

    testCategory = await prisma.category.create({
      data: {
        idcategory: uuidv4(),
        create_by: testAccount.idaccount,
        name_category: `Danh Mục Test ${uniqueSuffix}`,
        classify: 'Chi',
        is_default: false,
        is_group: false,
      },
    });

    const billId = uuidv4();
    const billPush = await syncService.processPush(testAccount.idaccount, [
      {
        localId: 'loc_b1',
        entity: 'bill',
        operation: 'create',
        payload: {
          id: billId,
          idaccount: testAccount.idaccount,
          idwallet: testWallet.idwallet,
          idcategory: testCategory.idcategory,
          name: `Hóa Đơn Tiền Điện ${uniqueSuffix}`,
          amount: 250000,
          startDate: new Date(),
          dueDate: new Date(Date.now() + 86400000 * 7),
          payStatus: 'Pending',
        },
      },
    ]);
    assert.strictEqual(billPush.results[0].status, 'synced', 'Tạo bill qua sync push phải thành công');
    testBill = { idbill: billId };

    console.log('✓ Đã khởi tạo dữ liệu kiểm thử (Account, Wallet, Category, Bill)');

    // ─────────────────────────────────────────────────────────────────
    // 1. Chốt chống thanh toán hai lần (BILL_ALREADY_PAID)
    // ─────────────────────────────────────────────────────────────────
    console.log('\n1. Kiểm thử chốt chống thanh toán hai lần (BILL_ALREADY_PAID):');

    const t1Id = uuidv4();
    const push1 = await syncService.processPush(testAccount.idaccount, [
      {
        localId: 'loc_t1',
        entity: 'transaction',
        operation: 'create',
        payload: {
          idtran: t1Id,
          idaccount: testAccount.idaccount,
          idwallet: testWallet.idwallet,
          idcategory: testCategory.idcategory,
          idbill: testBill.idbill,
          amount: -250000,
          type: 'Transaction',
          status: 'Confirmed',
          provider: 'Manual',
        },
      },
    ]);

    assert.strictEqual(push1.results[0].status, 'synced', 'Giao dịch T1 đầu tiên liên kết bill phải synced thành công');
    console.log('  ✓ Lô 1: Giao dịch T1 thanh toán hóa đơn đã synced thành công');

    const t2Id = uuidv4();
    const push2 = await syncService.processPush(testAccount.idaccount, [
      {
        localId: 'loc_t2',
        entity: 'transaction',
        operation: 'create',
        payload: {
          idtran: t2Id,
          idaccount: testAccount.idaccount,
          idwallet: testWallet.idwallet,
          idcategory: testCategory.idcategory,
          idbill: testBill.idbill,
          amount: -250000,
          type: 'Transaction',
          status: 'Confirmed',
          provider: 'Manual',
        },
      },
    ]);

    assert.strictEqual(push2.results[0].status, 'error', 'Giao dịch T2 thứ hai cùng bill phải bị từ chối');
    assert.strictEqual(push2.results[0].code, 'BILL_ALREADY_PAID', 'Mã lỗi phải là BILL_ALREADY_PAID');
    console.log('  ✓ Lô 2: Giao dịch T2 thứ hai cùng bill bị chặn chính xác với mã BILL_ALREADY_PAID');

    const billTxCount = await prisma.transaction.count({
      where: { idbill: testBill.idbill, deleted_at: null },
    });
    assert.strictEqual(billTxCount, 1, 'Chỉ được có đúng 1 giao dịch active liên kết với bill');
    console.log('  ✓ CSDL xác nhận: Chỉ duy nhất 1 giao dịch active liên kết hóa đơn');

    // ─────────────────────────────────────────────────────────────────
    // 2. Bẫy thứ tự trong lô (dangXoaTrongLo)
    // ─────────────────────────────────────────────────────────────────
    console.log('\n2. Kiểm thử hoàn tác và trả lại trong cùng một lô (dangXoaTrongLo):');

    const t3Id = uuidv4();
    const pushSameBatch = await syncService.processPush(testAccount.idaccount, [
      {
        localId: 'loc_del_t1',
        entity: 'transaction',
        operation: 'delete',
        payload: { id: t1Id },
      },
      {
        localId: 'loc_t3',
        entity: 'transaction',
        operation: 'create',
        payload: {
          idtran: t3Id,
          idaccount: testAccount.idaccount,
          idwallet: testWallet.idwallet,
          idcategory: testCategory.idcategory,
          idbill: testBill.idbill,
          amount: -250000,
          type: 'Transaction',
          status: 'Confirmed',
          provider: 'Manual',
        },
      },
    ]);

    assert.strictEqual(pushSameBatch.results[0].status, 'synced', 'Xóa T1 trong lô phải synced');
    assert.strictEqual(pushSameBatch.results[1].status, 'synced', 'Tạo mới T3 cho bill trong cùng lô phải synced (không bị T1 chặn)');
    console.log('  ✓ Xóa T1 và tạo T3 cho cùng hóa đơn trong 1 lô đều synced thành công (dangXoaTrongLo hoạt động chuẩn)');

    // ─────────────────────────────────────────────────────────────────
    // 3. Cho phép cập nhật chính giao dịch đang gắn bill
    // ─────────────────────────────────────────────────────────────────
    console.log('\n3. Kiểm thử cập nhật thông tin chính giao dịch đang gắn bill:');

    const pushUpdate = await syncService.processPush(testAccount.idaccount, [
      {
        localId: 'loc_upd_t3',
        entity: 'transaction',
        operation: 'update',
        payload: {
          idtran: t3Id,
          amount: -260000,
          note: 'Đã cập nhật số tiền tiền điện',
          update_at: new Date(Date.now() + 1000).toISOString(),
        },
      },
    ]);

    assert.strictEqual(pushUpdate.results[0].status, 'synced', 'Cập nhật giao dịch T3 phải synced');
    console.log('  ✓ Cập nhật giao dịch hiện tại không bị chặn nhầm bởi chanTraHaiLan');

    // ─────────────────────────────────────────────────────────────────
    // 4. Mã lỗi WALLET_NAME_DUPLICATE
    // ─────────────────────────────────────────────────────────────────
    console.log('\n4. Kiểm thử mã lỗi WALLET_NAME_DUPLICATE khi trùng tên ví:');

    const w1Id = uuidv4();
    const w2Id = uuidv4();
    const dupWalletName = `Ví Trùng Tên ${uniqueSuffix}`;

    const pushW1 = await syncService.processPush(testAccount.idaccount, [
      {
        localId: 'loc_w1',
        entity: 'wallet',
        operation: 'create',
        payload: {
          idwallet: w1Id,
          name: dupWalletName,
          type: 'Cash',
          balance: 0,
        },
      },
    ]);
    assert.strictEqual(pushW1.results[0].status, 'synced', 'Ví W1 phải synced');

    const pushW2 = await syncService.processPush(testAccount.idaccount, [
      {
        localId: 'loc_w2',
        entity: 'wallet',
        operation: 'create',
        payload: {
          idwallet: w2Id,
          name: dupWalletName,
          type: 'Cash',
          balance: 0,
        },
      },
    ]);
    assert.strictEqual(pushW2.results[0].status, 'error', 'Ví W2 trùng tên phải bị lỗi');
    assert.strictEqual(pushW2.results[0].code, 'WALLET_NAME_DUPLICATE', 'Mã lỗi phải là WALLET_NAME_DUPLICATE');
    console.log('  ✓ Tạo ví trùng tên trong tài khoản bắn chính xác mã WALLET_NAME_DUPLICATE');

    // ─────────────────────────────────────────────────────────────────
    // 5. Kiểm thử /auth/refresh trả mã ACCOUNT_DELETED (Lỗi G36)
    // ─────────────────────────────────────────────────────────────────
    console.log('\n5. Kiểm thử /auth/refresh với token thu hồi của tài khoản bị xoá (G36):');

    const testUserG36 = await prisma.account.create({
      data: {
        idrole: 2,
        email: `g36_test_${uniqueSuffix}@example.com`,
        username: `g36_${uniqueSuffix}`,
        password: 'hashed_password_placeholder',
        status: 'Active',
        type: 'Basic',
      },
    });

    // Cấp refresh token hợp lệ cho tài khoản này
    const dummyRawToken = `dummy_rt_${uniqueSuffix}_${uuidv4()}`;
    const tokenHash = crypto.createHash('sha256').update(dummyRawToken).digest('hex');
    await prisma.refreshtoken.create({
      data: {
        token_hash: tokenHash,
        idaccount: testUserG36.idaccount,
        idrole: 2,
        expired: new Date(Date.now() + 86400000 * 7),
        status: false, // Còn sống
      },
    });

    // Admin xoá mềm tài khoản (Status = Deleted, thu hồi token)
    await prisma.account.update({
      where: { idaccount: testUserG36.idaccount },
      data: { status: 'Deleted', delete_at: new Date() },
    });
    await prisma.refreshtoken.updateMany({
      where: { idaccount: testUserG36.idaccount },
      data: { status: true }, // Đã bị thu hồi
    });

    // Gọi refresh bằng token đã thu hồi
    let g36Error = null;
    try {
      await authService.refresh(dummyRawToken);
    } catch (err) {
      g36Error = err;
    }

    assert(g36Error !== null, 'Phải ném lỗi');
    assert.strictEqual(g36Error.statusCode, 401, 'Mã HTTP status phải là 401');
    assert.strictEqual(g36Error.code, 'ACCOUNT_DELETED', 'Lỗi phải chứa code: ACCOUNT_DELETED');
    assert.strictEqual(g36Error.idaccount, testUserG36.idaccount, 'Lỗi phải chứa đúng idaccount');
    console.log('  ✓ Token thu hồi của tài khoản Deleted trả về 401 kèm code: ACCOUNT_DELETED và idaccount ở cấp gốc (Khắc phục G36)');

    // Dọn dẹp tài khoản G36
    await prisma.refreshtoken.deleteMany({ where: { idaccount: testUserG36.idaccount } });
    await prisma.account.delete({ where: { idaccount: testUserG36.idaccount } });

    console.log('\n======================================================================');
    console.log('   TẤT CẢ 5 MỤC KIỂM THỬ TỰ ĐỘNG ĐỀU VƯỢT QUA XUẤT SẮC!              ');
    console.log('======================================================================\n');

  } finally {
    // Dọn dẹp dữ liệu kiểm thử (tuân thủ chốt chặn bảo mật CSDL không xoá vật lý transaction)
    console.log('Đang dọn dẹp dữ liệu kiểm thử...');
    if (testBill) {
      await prisma.transaction.updateMany({ where: { idbill: testBill.idbill }, data: { deleted_at: new Date() } });
      await prisma.bill.updateMany({ where: { idbill: testBill.idbill }, data: { delete_at: new Date() } });
    }
    if (testWallet) {
      await prisma.wallet.updateMany({ where: { idaccount: testAccount.idaccount }, data: { delete_at: new Date() } });
    }
    if (testCategory) {
      await prisma.category.updateMany({ where: { idcategory: testCategory.idcategory }, data: { delete_at: new Date() } });
    }
    if (testAccount) {
      await prisma.account.updateMany({ where: { idaccount: testAccount.idaccount }, data: { delete_at: new Date() } });
    }
    console.log('Dọn dẹp hoàn tất.');
  }
}

runTests()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Test FAILED with error:', err);
    process.exit(1);
  });
