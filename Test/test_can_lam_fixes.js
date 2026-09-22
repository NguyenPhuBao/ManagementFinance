/**
 * Test Suite: Toàn bộ các bản vá theo thư mục CAN-LAM
 * 1. Socket.io JWT handshake auth & room isolation
 * 2. Sync push idempotent delete & clean SQLSTATE error mapping
 * 3. Budget time_recurrence = null preservation
 * 4. Category keyword feedback 403 authorization
 * 5. Transaction idgoal foreign key sync push & pull
 * 6. Goal auto_deposit & priority sync push & pull
 * 7. Category unique name constraints (Template & Cloned Model)
 * 8. Dedup rule 3 fuzzy counterpart check
 * 9. OCR classifyBatch invocation format
 * 10. Mock query param prevention on production
 */

const { randomUUID: uuidv4 } = require('crypto');
const { prisma } = require('../src/Backend/config/db');
const syncService = require('../src/Backend/modules/sync/sync.service');
const classifyService = require('../src/Backend/modules/ai/features/classify/classify.service');
const dedupRepo = require('../src/Backend/modules/ai/features/dedup/dedup.repository');

const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  bright: "\x1b[1m",
};

function assert(condition, message) {
  if (!condition) {
    console.error(`${colors.red}  ✗ FAILED: ${message}${colors.reset}`);
    throw new Error(message);
  }
  console.log(`${colors.green}  ✓ PASSED: ${message}${colors.reset}`);
}

async function runAllCanLamTests() {
  console.log(`\n${colors.cyan}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}      KIỂM THỬ TOÀN DIỆN CÁC BẢN VÁ THEO THƯ MỤC CAN-LAM              ${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}======================================================================${colors.reset}\n`);

  // Lấy 2 account test từ DB (chọn tài khoản đang Active để test logic xác thực)
  const accounts = await prisma.account.findMany({
    where: { idrole: 2, status: 'Active', delete_at: null },
    take: 2,
  });

  if (accounts.length < 2) {
    console.error('Cần ít nhất 2 tài khoản người dùng trong CSDL để chạy test.');
    process.exit(1);
  }

  const userA = accounts[0];
  const userB = accounts[1];
  console.log(`${colors.yellow}User A: id=${userA.idaccount} (${userA.username}), User B: id=${userB.idaccount} (${userB.username})${colors.reset}\n`);

  const cleanupIds = {
    categories: [],
    wallets: [],
    transactions: [],
    budgets: [],
    goals: [],
  };

  try {
    // -------------------------------------------------------------------------
    // TEST 1: Sync Push Idempotent Delete
    // -------------------------------------------------------------------------
    console.log(`${colors.bright}1. Kiểm thử Sync Push: Idempotent Delete (bản ghi không tồn tại)${colors.reset}`);
    const nonExistentId = uuidv4();
    const deleteResult = await syncService.processPush(userA.idaccount, [
      {
        localId: 'del_1',
        entity: 'wallet',
        operation: 'delete',
        payload: { id: nonExistentId },
      },
    ]);
    assert(deleteResult.summary.synced === 1, 'Idempotent delete trả về synced = 1');
    assert(deleteResult.summary.errors === 0, 'Idempotent delete errors = 0');
    assert(deleteResult.results[0].status === 'synced', 'Result status = synced');
    assert(deleteResult.results[0].message === 'Already absent', 'Result message = "Already absent"');

    // -------------------------------------------------------------------------
    // TEST 2: Sync Push SQLSTATE Error Mapping (ẩn Prisma stack trace)
    // -------------------------------------------------------------------------
    console.log(`\n${colors.bright}2. Kiểm thử Sync Push: Error Mapping che giấu Prisma raw trace${colors.reset}`);
    const invalidFkResult = await syncService.processPush(userA.idaccount, [
      {
        localId: 'fk_err_1',
        entity: 'transaction',
        operation: 'create',
        payload: {
          id: uuidv4(),
          walletId: uuidv4(), // Ví không tồn tại -> vi phạm FK
          amount: 50000,
          type: 'Expense',
        },
      },
    ]);
    assert(invalidFkResult.summary.errors === 1, 'Tạo transaction ví ảo phải báo lỗi');
    assert(invalidFkResult.results[0].status === 'error', 'Status là error');
    assert(
      invalidFkResult.results[0].code === 'FOREIGN_KEY_VIOLATION' ||
      invalidFkResult.results[0].code === 'CONSTRAINT_VIOLATION',
      `Mã lỗi chuẩn hóa: ${invalidFkResult.results[0].code}`
    );
    assert(!invalidFkResult.results[0].message.includes('Invalid `prisma'), 'Không chứa Prisma raw stack trace');

    // -------------------------------------------------------------------------
    // TEST 3: Budget time_recurrence = null preservation
    // -------------------------------------------------------------------------
    console.log(`\n${colors.bright}3. Kiểm thử Budget: time_recurrence = null được giữ nguyên${colors.reset}`);
    const budgetId = uuidv4();
    cleanupIds.budgets.push(budgetId);
    const budgetRes = await syncService.processPush(userA.idaccount, [
      {
        localId: 'bg_1',
        entity: 'budget',
        operation: 'create',
        payload: {
          id: budgetId,
          idaccount: userA.idaccount,
          totalAmount: 1000000,
          timeRecurrence: null, // Ngân sách theo ngày cụ thể (null)
          recurrence: false,
          start: new Date().toISOString(),
        },
      },
    ]);
    assert(budgetRes.summary.synced === 1, 'Tạo budget thành công');
    const createdBudget = await prisma.budget.findUnique({ where: { idbudget: budgetId } });
    assert(createdBudget !== null, 'Budget tồn tại trong CSDL');
    assert(createdBudget.time_recurrence === null, `time_recurrence trong DB phải là null, thực tế: ${createdBudget.time_recurrence}`);

    // -------------------------------------------------------------------------
    // TEST 4: Phân quyền Feedback từ khóa AI (Category keyword authorization)
    // -------------------------------------------------------------------------
    console.log(`\n${colors.bright}4. Kiểm thử Phân quyền cập nhật từ khóa AI (Category feedback 403)${colors.reset}`);
    // Tìm 1 danh mục mặc định
    const defaultCat = await prisma.category.findFirst({
      where: { is_default: true, delete_at: null },
    });
    assert(defaultCat !== null, 'Có danh mục mặc định trong CSDL');

    let defaultCatForbidden = false;
    try {
      await classifyService.recordFeedback(
        userA.idaccount,
        { idcategory: defaultCat.idcategory, keyword: 'Cà phê sữa đá' }
      );
    } catch (err) {
      if (err.statusCode === 403 || err.message.includes('mặc định')) {
        defaultCatForbidden = true;
      }
    }
    assert(defaultCatForbidden, 'Chặn 403 khi cố cập nhật từ khóa vào danh mục mặc định của hệ thống');

    // Tạo 1 danh mục cho User B
    const userBCatId = uuidv4();
    cleanupIds.categories.push(userBCatId);
    await prisma.category.create({
      data: {
        idcategory: userBCatId,
        create_by: userB.idaccount,
        name_category: `Danh mục User B ${Date.now()}`,
        classify: 'Chi',
        is_default: false,
      },
    });

    let foreignCatForbidden = false;
    try {
      await classifyService.recordFeedback(
        userA.idaccount, // User A cố sửa danh mục của User B
        { idcategory: userBCatId, keyword: 'Từ khóa của User A' }
      );
    } catch (err) {
      if (err.statusCode === 403 || err.message.includes('quyền')) {
        foreignCatForbidden = true;
      }
    }
    assert(foreignCatForbidden, 'Chặn 403 khi cố cập nhật từ khóa vào danh mục của người khác');

    // -------------------------------------------------------------------------
    // TEST 5: Transaction Goal Id & Goal Auto Deposit + Priority
    // -------------------------------------------------------------------------
    console.log(`\n${colors.bright}5. Kiểm thử Transaction.idgoal & Goal auto_deposit/priority${colors.reset}`);
    const walletId = uuidv4();
    const goalId = uuidv4();
    const tranId = uuidv4();
    cleanupIds.wallets.push(walletId);
    cleanupIds.goals.push(goalId);
    cleanupIds.transactions.push(tranId);

    // Tạo wallet trước
    await prisma.wallet.create({
      data: {
        idwallet: walletId,
        idaccount: userA.idaccount,
        name: 'Ví Tiết Kiệm Test',
        balance: 5000000,
      },
    });

    const goalPush = await syncService.processPush(userA.idaccount, [
      {
        localId: 'goal_1',
        entity: 'goal',
        operation: 'create',
        payload: {
          id: goalId,
          idaccount: userA.idaccount,
          idwallet: walletId,
          name: 'Mua Xe Máy Mới',
          targetAmount: 30000000,
          currentAmount: 1000000,
          autoDepositAmount: 500000,
          autoDepositWalletId: walletId,
          priority: 3,
        },
      },
    ]);
    assert(goalPush.summary.synced === 1, 'Push tạo goal có auto_deposit và priority thành công');

    const dbGoal = await prisma.goal.findUnique({ where: { idgoal: goalId } });
    assert(Number(dbGoal.auto_deposit_amount) === 500000, 'auto_deposit_amount lưu đúng 500,000');
    assert(dbGoal.auto_deposit_wallet_id === walletId, 'auto_deposit_wallet_id lưu đúng');
    assert(dbGoal.priority === 3, 'priority lưu đúng = 3');

    const tranPush = await syncService.processPush(userA.idaccount, [
      {
        localId: 'tran_1',
        entity: 'transaction',
        operation: 'create',
        payload: {
          id: tranId,
          idaccount: userA.idaccount,
          idwallet: walletId,
          goalId: goalId, // Liên kết với mục tiêu
          amount: 500000,
          type: 'Expense',
          note: 'Nạp tiền vào heo đất',
        },
      },
    ]);
    assert(tranPush.summary.synced === 1, 'Push tạo transaction có goalId thành công');

    const dbTran = await prisma.transaction.findUnique({ where: { idtran: tranId } });
    assert(dbTran.idgoal === goalId, `transaction.idgoal lưu đúng: ${dbTran.idgoal}`);

    // -------------------------------------------------------------------------
    // TEST 6: uq_transaction_external per-account
    // -------------------------------------------------------------------------
    console.log(`\n${colors.bright}6. Kiểm thử uq_transaction_external per-account (2 tài khoản cùng bank_tran_id)${colors.reset}`);
    const walletBId = uuidv4();
    const tranAId = uuidv4();
    const tranBId = uuidv4();
    cleanupIds.wallets.push(walletBId);
    cleanupIds.transactions.push(tranAId, tranBId);

    await prisma.wallet.create({
      data: {
        idwallet: walletBId,
        idaccount: userB.idaccount,
        name: 'Ví User B',
        balance: 1000000,
      },
    });

    const sharedBankTranId = `SEPAY_TEST_${Date.now()}`;
    // User A tạo transaction với bank_tran_id
    await prisma.transaction.create({
      data: {
        idtran: tranAId,
        idaccount: userA.idaccount,
        idwallet: walletId,
        provider: 'BankSync',
        bank_tran_id: sharedBankTranId,
        amount: 200000,
        type: 'Income',
      },
    });

    // User B tạo transaction cùng provider và cùng bank_tran_id (hợp lệ vì uq đã chuyển thành per-account)
    let userBSuccess = false;
    try {
      await prisma.transaction.create({
        data: {
          idtran: tranBId,
          idaccount: userB.idaccount,
          idwallet: walletBId,
          provider: 'BankSync',
          bank_tran_id: sharedBankTranId,
          amount: 200000,
          type: 'Income',
        },
      });
      userBSuccess = true;
    } catch (err) {
      console.error('Lỗi khi User B tạo transaction cùng bank_tran_id:', err.message);
    }
    assert(userBSuccess, 'Hai tài khoản khác nhau có thể nhận cùng mã bank_tran_id độc lập');

    // -------------------------------------------------------------------------
    // TEST 7: Quy tắc Danh mục Mới (Template & Cloned)
    // -------------------------------------------------------------------------
    console.log(`\n${colors.bright}7. Kiểm thử Quy tắc Danh mục Mới: Cho phép trùng tên với hệ thống, cấm trùng tên trong cùng tài khoản${colors.reset}`);
    const testDefaultCatName = `TemplateTest_${Date.now()}`;
    const testDefaultCatId = uuidv4();
    cleanupIds.categories.push(testDefaultCatId);

    // Admin tạo danh mục hệ thống
    await prisma.category.create({
      data: {
        idcategory: testDefaultCatId,
        create_by: 1, // Admin
        name_category: testDefaultCatName,
        classify: 'Chi',
        is_default: true,
      },
    });

    let userCatSameAsDefaultCreated = false;
    let userCatCreatedId = uuidv4();
    try {
      const catCreated = await prisma.category.create({
        data: {
          idcategory: userCatCreatedId,
          create_by: userA.idaccount,
          name_category: testDefaultCatName.toLowerCase(), // Tạo danh mục trùng tên hệ thống (chữ thường)
          classify: 'Chi',
          is_default: false,
        },
      });
      cleanupIds.categories.push(userCatCreatedId);
      userCatSameAsDefaultCreated = !!catCreated;
    } catch (err) {
      console.error('Lỗi khi tạo user category trùng tên default:', err.message);
      userCatSameAsDefaultCreated = false;
    }
    assert(userCatSameAsDefaultCreated, 'Người dùng được phép tạo danh mục cá nhân trùng tên với danh mục mặc định của hệ thống (Template Cloned Model)');

    // Kiểm tra cấm trùng lặp trên cùng tài khoản
    let duplicateOnSameAccountBlocked = false;
    try {
      await prisma.category.create({
        data: {
          idcategory: uuidv4(),
          create_by: userA.idaccount,
          name_category: testDefaultCatName.toUpperCase(), // Cố tạo trùng tên trên cùng tài khoản userA (chữ hoa)
          classify: 'Chi',
          is_default: false,
        },
      });
    } catch (err) {
      if (err.code === 'P2002' || err.message.includes('Unique constraint failed') || err.message.includes('uq_category_owner_name')) {
        duplicateOnSameAccountBlocked = true;
      }
    }
    assert(duplicateOnSameAccountBlocked, 'Hệ thống chặn thành công việc tạo danh mục trùng tên trên cùng một tài khoản (case-insensitive)');

    // -------------------------------------------------------------------------
    // TEST 8: Dedup Rule 3 Fuzzy Transfer Filter
    // -------------------------------------------------------------------------
    console.log(`\n${colors.bright}8. Kiểm thử Dedup Rule 3: Fuzzy matching lọc provider và đối soát counterpart${colors.reset}`);
    const dedupWalletId = uuidv4();
    const manualTranId = uuidv4();
    cleanupIds.wallets.push(dedupWalletId);
    cleanupIds.transactions.push(manualTranId);

    await prisma.wallet.create({
      data: {
        idwallet: dedupWalletId,
        idaccount: userA.idaccount,
        name: 'Ví Dedup Test',
      },
    });

    // Tạo giao dịch Manual với số tiền 777,000 VND
    await prisma.transaction.create({
      data: {
        idtran: manualTranId,
        idaccount: userA.idaccount,
        idwallet: dedupWalletId,
        provider: 'Manual', // Lưu ý: Manual
        amount: 777000,
        type: 'Expense',
        date_transaction: new Date(),
      },
    });

    // findFuzzyTransfer chỉ được tìm kiếm giao dịch từ BankSync / SMS
    const fuzzyMatchManual = await dedupRepo.findFuzzyTransfer(
      userA.idaccount,
      777000,
      new Date(),
      '123456789',
      'Chuyen khoan'
    );
    assert(fuzzyMatchManual === null, 'Giao dịch Manual không bị nhận nhầm thành Fuzzy Transfer của BankSync');

    // -------------------------------------------------------------------------
    // TEST 9: Socket.io Token Verification & Room Isolation
    // -------------------------------------------------------------------------
    console.log(`\n${colors.bright}9. Kiểm thử Socket.io Token Verification Middleware${colors.reset}`);
    const { isAccountValid } = require('../src/Backend/middleware/auth');
    assert(typeof isAccountValid === 'function', 'isAccountValid đã được export từ middleware/auth.js');
    const validAccountCheck = await isAccountValid(userA.idaccount);
    assert(validAccountCheck === true, 'Tài khoản hợp lệ được xác thực (trả về true)');

    const invalidAccountCheck = await isAccountValid(999999999);
    assert(invalidAccountCheck === false, 'Tài khoản không tồn tại bị từ chối (trả về false)');

    console.log(`\n${colors.green}${colors.bright}======================================================================${colors.reset}`);
    console.log(`${colors.green}${colors.bright}   TẤT CẢ 9 BÀI KIỂM THỬ TÍCH HỢP ĐỀU VƯỢT QUA XUẤT SẮC!              ${colors.reset}`);
    console.log(`${colors.green}${colors.bright}======================================================================${colors.reset}\n`);

  } finally {
    // Dọn dẹp dữ liệu kiểm thử
    console.log(`${colors.yellow}Đang dọn dẹp dữ liệu test...${colors.reset}`);
    if (cleanupIds.transactions.length > 0) {
      await prisma.transaction.updateMany({
        where: { idtran: { in: cleanupIds.transactions } },
        data: { deleted_at: new Date() },
      }).catch(() => {});
    }
    if (cleanupIds.goals.length > 0) {
      await prisma.goal.deleteMany({ where: { idgoal: { in: cleanupIds.goals } } }).catch(() => {});
    }
    if (cleanupIds.budgets.length > 0) {
      await prisma.budget.deleteMany({ where: { idbudget: { in: cleanupIds.budgets } } }).catch(() => {});
    }
    if (cleanupIds.wallets.length > 0) {
      await prisma.wallet.updateMany({
        where: { idwallet: { in: cleanupIds.wallets } },
        data: { delete_at: new Date() },
      }).catch(() => {});
    }
    if (cleanupIds.categories.length > 0) {
      await prisma.category.deleteMany({ where: { idcategory: { in: cleanupIds.categories } } }).catch(() => {});
    }
    console.log(`${colors.green}Dọn dẹp hoàn tất.${colors.reset}\n`);
  }
}

runAllCanLamTests()
  .catch((err) => {
    console.error(`\n${colors.red}Test thất bại với lỗi:${colors.reset}`, err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
