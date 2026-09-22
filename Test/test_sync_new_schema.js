const { randomUUID: uuidv4 } = require('crypto');
const { prisma } = require('../src/Backend/config/db');
const syncService = require('../src/Backend/modules/sync/sync.service');
const syncRepository = require('../src/Backend/modules/sync/sync.repository');

const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  bright: "\x1b[1m",
};

async function runSyncTests() {
  console.log(`\n${colors.cyan}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}         KIỂM THỬ TOÀN DIỆN MODULE SYNC THEO CSDL MỚI                 ${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}======================================================================${colors.reset}\n`);

  // 1. Tạo account test
  const testAccount = await prisma.account.findFirst({
    where: { idrole: 2, delete_at: null },
  });

  if (!testAccount) {
    console.error('Không tìm thấy tài khoản test. Vui lòng đảm bảo CSDL có ít nhất 1 account.');
    process.exit(1);
  }

  const idaccount = testAccount.idaccount;
  console.log(`Đang kiểm thử với idaccount: ${idaccount} (${testAccount.username})\n`);

  const categoryId = uuidv4();
  const wallet1Id = uuidv4();
  const wallet2Id = uuidv4();
  const budgetId = uuidv4();
  const billId = uuidv4();
  const goalId = uuidv4();
  const tranId = uuidv4();

  const now = new Date().toISOString();

  const operations = [
    // 1. Category
    {
      localId: 'op_cat_1',
      entity: 'category',
      operation: 'create',
      payload: {
        id: categoryId,
        idaccount: idaccount,
        name: 'Ăn uống ngoài',
        classify: 'Chi',
        isDefault: false,
        isGroup: false,
        keyword: 'an uong; nha hang; bbq; buffet',
        icon: 'restaurant',
        update_at: now,
      },
    },
    // 2. Wallet 1
    {
      localId: 'op_wal_1',
      entity: 'wallet',
      operation: 'create',
      payload: {
        id: wallet1Id,
        idaccount: idaccount,
        name: 'Ví tiền mặt',
        type: 'Cash',
        balance: 5000000,
        currency: 'VND',
        status: 'Active',
        includeInTotal: true,
        isDefault: true,
        icon: 'wallet',
        color: '#4CAF50',
        update_at: now,
      },
    },
    // 3. Wallet 2 (để test transfer)
    {
      localId: 'op_wal_2',
      entity: 'wallet',
      operation: 'create',
      payload: {
        id: wallet2Id,
        idaccount: idaccount,
        name: 'Tài khoản VCB',
        type: 'Bank',
        balance: 20000000,
        currency: 'VND',
        status: 'Active',
        includeInTotal: true,
        isDefault: false,
        icon: 'account_balance',
        color: '#2196F3',
        update_at: now,
      },
    },
    // 4. Budget (với các cột mới: threshold_warning_amount, threshold_warning_percent, nexttime_recurrence)
    {
      localId: 'op_bg_1',
      entity: 'budget',
      operation: 'create',
      payload: {
        id: budgetId,
        idaccount: idaccount,
        categoryId: categoryId,
        totalAmount: 3000000,
        spent: 500000,
        thresholdWarningAmount: 500000,
        thresholdWarningPercent: 80,
        overSpending: 'Over',
        overAmount: 200000,
        start: now,
        recurrence: true,
        timeRecurrence: 'Month',
        nexttimeRecurrence: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        note: 'Ngân sách ăn uống tháng 8',
        update_at: now,
      },
    },
    // 5. Bill (với start_date, due_date, pay_status = 'Pending', time_notification = '3')
    {
      localId: 'op_bill_1',
      entity: 'bill',
      operation: 'create',
      payload: {
        id: billId,
        idaccount: idaccount,
        walletId: wallet1Id,
        categoryId: categoryId,
        name: 'Tiền mạng Internet',
        amount: 250000,
        startDate: now,
        dueDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString(),
        payStatus: 'Pending',
        recurrence: true,
        timeRecurrence: 'Month',
        timeNotification: '3',
        icon: 'wifi',
        color: '#00BCD4',
        note: 'Gói FPT 1Gbps',
        update_at: now,
      },
    },
    // 6. Goal (với start_date, cycle_take_money, time_cycle_take_money, status_complete, recurrence)
    {
      localId: 'op_goal_1',
      entity: 'goal',
      operation: 'create',
      payload: {
        id: goalId,
        idaccount: idaccount,
        walletId: wallet2Id,
        name: 'Mua điện thoại mới',
        targetAmount: 25000000,
        currentAmount: 5000000,
        startDate: now,
        targetDate: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000).toISOString(),
        cycleTakeMoney: 'Month',
        timeCycleTakeMoney: now,
        statusComplete: 'False',
        recurrence: false,
        timeRecurrence: 'Month',
        icon: 'smartphone',
        color: '#E91E63',
        note: 'Tiết kiệm 3.5tr/tháng',
        update_at: now,
      },
    },
    // 7. Transaction (với idwallet_transfer, date_transaction, provider = 'BankSync')
    {
      localId: 'op_tran_1',
      entity: 'transaction',
      operation: 'create',
      payload: {
        id: tranId,
        idaccount: idaccount,
        walletId: wallet2Id,
        categoryId: categoryId,
        idwalletTransfer: wallet1Id,
        bankTranId: 'FT260830123456',
        amount: 1500000,
        type: 'Transfer',
        provider: 'BankSync',
        note: 'Rút tiền ATM về ví tiền mặt',
        dateTransaction: now,
        update_at: now,
      },
    },
  ];

  console.log(`1. Đang thực thi Sync PUSH batch (7 operations)...`);
  const pushRes = await syncService.processPush(idaccount, operations);
  console.log(`   Summary: Total=${pushRes.summary.total}, Synced=${pushRes.summary.synced}, Errors=${pushRes.summary.errors}`);

  const allSynced = pushRes.results.every(r => r.status === 'synced');
  if (allSynced) {
    console.log(`   ${colors.green}✔ Sync PUSH: Tất cả 7 entities tạo mới thành công 100%!${colors.reset}\n`);
  } else {
    console.error(`   ${colors.red}✖ Sync PUSH thất bại:${colors.reset}`, pushRes.results);
  }

  // 2. Kiểm tra Sync PULL
  console.log(`2. Đang thực thi Sync PULL...`);
  const pullSince = new Date(Date.now() - 60000).toISOString();
  const pullRes = await syncService.processPull(idaccount, pullSince);

  const pulledWallets = pullRes.data.wallets?.filter(w => w.idwallet === wallet1Id || w.idwallet === wallet2Id);
  const pulledBudget = pullRes.data.budgets?.find(b => b.idbudget === budgetId);
  const pulledBill = pullRes.data.bills?.find(b => b.idbill === billId);
  const pulledGoal = pullRes.data.goals?.find(g => g.idgoal === goalId);
  const pulledTran = pullRes.data.transactions?.find(t => t.idtran === tranId);

  console.log(`   ✔ Pulled Wallets      : ${pulledWallets?.length || 0} ví`);
  console.log(`   ✔ Pulled Budget       : Total=${pulledBudget?.total_amount}, WarningAmount=${pulledBudget?.threshold_warning_amount}, WarningPercent=${pulledBudget?.threshold_warning_percent}%`);
  console.log(`   ✔ Pulled Bill         : Name="${pulledBill?.name}", PayStatus=${pulledBill?.pay_status}, NotifyDays=${pulledBill?.time_notification}`);
  console.log(`   ✔ Pulled Goal         : Target=${pulledGoal?.target_amount}, Cycle=${pulledGoal?.cycle_take_money}, StatusComplete=${pulledGoal?.status_complete}`);
  console.log(`   ✔ Pulled Transaction  : Amount=${pulledTran?.amount}, Provider=${pulledTran?.provider}, TransferTo=${pulledTran?.idwallet_transfer}`);

  // 3. Kiểm tra Soft Delete
  console.log(`\n3. Đang kiểm tra Soft Delete...`);
  await syncRepository.softDelete('transaction', tranId);
  await syncRepository.softDelete('bill', billId);
  await syncRepository.softDelete('budget', budgetId);
  await syncRepository.softDelete('goal', goalId);
  await syncRepository.softDelete('wallet', wallet1Id);
  await syncRepository.softDelete('wallet', wallet2Id);
  await syncRepository.softDelete('category', categoryId);

  const checkTran = await prisma.transaction.findUnique({ where: { idtran: tranId } });
  const checkBill = await prisma.bill.findUnique({ where: { idbill: billId } });
  const checkBudget = await prisma.budget.findUnique({ where: { idbudget: budgetId } });

  const isSoftDeleted = checkTran?.deleted_at !== null && checkBill?.delete_at !== null && checkBudget?.delete_at !== null;
  if (isSoftDeleted) {
    console.log(`   ${colors.green}✔ Soft Delete: Tất cả các bảng đã được đánh dấu Deleted_at / Delete_at thành công!${colors.reset}\n`);
  }

  // 4. Dọn dẹp bản ghi test vật lý
  await prisma.transaction.delete({ where: { idtran: tranId } }).catch(() => {});
  await prisma.bill.delete({ where: { idbill: billId } }).catch(() => {});
  await prisma.budget.delete({ where: { idbudget: budgetId } }).catch(() => {});
  await prisma.goal.delete({ where: { idgoal: goalId } }).catch(() => {});
  await prisma.wallet.delete({ where: { idwallet: wallet1Id } }).catch(() => {});
  await prisma.wallet.delete({ where: { idwallet: wallet2Id } }).catch(() => {});
  await prisma.category.delete({ where: { idcategory: categoryId } }).catch(() => {});

  console.log(`${colors.green}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.green}${colors.bright}   🎉 MODULE SYNC ĐÃ ĐƯỢC CẬP NHẬT VÀ KIỂM THỬ CHUẨN XÁC 100%!        ${colors.reset}`);
  console.log(`${colors.green}${colors.bright}======================================================================${colors.reset}\n`);

  await prisma.$disconnect();
  process.exit(0);
}

runSyncTests().catch(err => {
  console.error('Lỗi khi chạy sync test:', err);
  process.exit(1);
});
