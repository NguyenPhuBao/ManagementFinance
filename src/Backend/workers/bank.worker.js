const { Worker } = require('bullmq');
const { randomUUID } = require('crypto');
const logger = require('../core/logger');
const { prisma } = require('../config/db');
const eventBus = require('../core/event-bus');

const Redis = require('ioredis');
const connection = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: null,
});

const bankWorker = new Worker(
  'bank-webhook',
  async (job) => {
    const { cassoTx } = job.data;
    if (!cassoTx || typeof cassoTx !== 'object') {
      logger.warn('Bank Worker: Invalid job payload, skipping', { jobId: job.id });
      return;
    }

    // 1. Trích xuất an toàn với fallback đa nguồn (Casso v2 / Casso Flow)
    const tid = cassoTx.tid || (cassoTx.id ? String(cassoTx.id) : null);
    const subAccId = cassoTx.subAccId || cassoTx.bank_sub_acc_id || cassoTx.bankSubAccId || cassoTx.accountNumber;
    const amount = Number(cassoTx.amount) || 0;
    const description = cassoTx.description || cassoTx.memo || 'Giao dịch ngân hàng';
    const rawCusum = cassoTx.cusum_balance !== undefined ? cassoTx.cusum_balance : cassoTx.cusumBalance;
    const when = cassoTx.when || cassoTx.transactionDate || cassoTx.createdAt;

    logger.info('Bank Worker: Processing webhook transaction', { jobId: job.id, tid, subAccId, amount });

    if (!subAccId) {
      logger.warn('Bank Worker: Missing account number in webhook payload', { jobId: job.id, cassoTx });
      return;
    }

    if (!tid) {
      logger.warn('Bank Worker: Missing transaction ID (tid/id) in webhook payload', { jobId: job.id, cassoTx });
      return;
    }

    // 2. Tìm tài khoản NH dựa trên subAccId (số tài khoản)
    const bankAcc = await prisma.bank_account.findFirst({
      where: {
        account_number: String(subAccId),
        connect_status: { in: ['Active', 'active'] },
        delete_at: null,
      },
    });

    if (!bankAcc) {
      logger.warn(`Bank Worker: No active bank_account found for account_number ${subAccId}`, { tid });
      return;
    }

    const { idaccount } = bankAcc;

    // 3. Khử trùng lặp qua (provider, bank_tran_id) — CSDL mới
    const existing = await prisma.transaction.findFirst({
      where: {
        provider: { in: ['BankSync', 'Casso'] },
        bank_tran_id: String(tid),
      },
    });

    if (existing) {
      logger.info(`Bank Worker: Transaction ${tid} already exists. Skipping.`, { tid });
      return;
    }

    // 4. Tìm hoặc tạo ví đồng bộ (wallet) tương ứng với tài khoản NH này
    // CSDL mới: ví từ Casso = Type 'Banking' + Id_bank_casso
    let wallet = await prisma.wallet.findFirst({
      where: { idaccount, id_bank_casso: bankAcc.id_bank_account, delete_at: null },
    });

    // Tính toán số dư mới: ưu tiên cusum_balance từ ngân hàng, nếu thiếu sẽ fallback cộng dồn
    let newBalance;
    if (rawCusum !== undefined && rawCusum !== null) {
      newBalance = Number(rawCusum);
    } else {
      // Prisma Decimal -> Number để tính toán an toàn
      newBalance = Number(bankAcc.balance) + amount;
      logger.warn('Bank Worker: cusum_balance is missing in webhook payload, fallback to current balance + amount', {
        tid,
        accountNumber: bankAcc.account_number,
        currentBalance: Number(bankAcc.balance),
        amount,
        computedNewBalance: newBalance,
      });
    }

    if (!wallet) {
      const bankDisplayName = bankAcc.bank_name || 'Bank';
      const rawWalletName = `${bankDisplayName} - ${bankAcc.account_number}`;
      // CSDL mới: name nvarchar(100)
      const walletName = rawWalletName.length > 100 ? rawWalletName.substring(0, 100) : rawWalletName;

      wallet = await prisma.wallet.create({
        data: {
          idwallet: randomUUID(),
          idaccount,
          name: walletName,
          type: 'Banking',
          id_bank_casso: bankAcc.id_bank_account,
          balance: newBalance,
          update_at: new Date(),
        },
      });
    }

    // 5. Tự động gọi AI Phân loại giao dịch (Classify AI 3-Tier)
    let predictedCategoryId = null;
    try {
      const classifyService = require('../modules/ai/features/classify/classify.service');
      const predicted = await classifyService.classifySingle(idaccount, {
        text: description,
        amount,
        merchant: bankAcc.bank_name || '',
        source: 'BankSync',
        counterpart_name: cassoTx.corresponsiveName || '',
      });
      if (predicted && predicted.category_id) {
        predictedCategoryId = predicted.category_id;
        logger.info('Bank Worker: Transaction auto-classified by AI', {
          tid,
          categoryId: predicted.category_id,
          categoryName: predicted.category_name,
          confidence: predicted.confidence,
          tier: predicted.tier_used,
        });
      }
    } catch (classifyErr) {
      logger.warn('Bank Worker: Auto-classification failed, keeping category as null', {
        tid,
        error: classifyErr.message,
      });
    }

    // 6. Tạo giao dịch mới
    // CSDL mới: date_transaction, provider = 'BankSync', bank_tran_id
    const parsedDate = when ? new Date(when) : new Date();
    const txDate = isNaN(parsedDate.getTime()) ? new Date() : parsedDate;

    const newTx = await prisma.transaction.create({
      data: {
        idtran: randomUUID(),
        idaccount,
        idwallet: wallet.idwallet,
        amount: amount, // giữ nguyên dấu từ Casso (dương = vào, âm = ra)
        type: 'Transaction',
        status: 'Pending', // CSDL mới: Giao dịch ngân hàng luôn khởi tạo Pending chờ người dùng duyệt
        note: description,
        date_transaction: txDate, // CSDL mới: DateTransaction
        update_at: new Date(),
        provider: 'BankSync', // CSDL mới: BankSync
        bank_tran_id: String(tid),
        idcategory: predictedCategoryId, // Gán idcategory do AI dự đoán (hoặc null nếu chưa phân loại)
      },
    });

    // 6. Cập nhật số dư cho cả bank_account và wallet
    await prisma.bank_account.update({
      where: { id_bank_account: bankAcc.id_bank_account },
      data: { balance: newBalance, update_at: new Date() },
    });

    await prisma.wallet.update({
      where: { idwallet: wallet.idwallet },
      data: { balance: newBalance, update_at: new Date() },
    });

    // 7. Phát sự kiện sang Module Notification và EventBus hệ thống
    if (eventBus && eventBus.publish) {
      await eventBus.publish('bank_transaction.pending', {
        idtran: newTx.idtran,
        idaccount,
        amount: newTx.amount,
        bankName: bankAcc.bank_name,
        accountNumber: bankAcc.account_number,
        description: newTx.note,
        date: newTx.date_transaction,
      });
      await eventBus.publish('transaction.created', { transactionId: newTx.idtran, idaccount });
    }

    logger.info('Bank Worker: Webhook transaction processed successfully', { jobId: job.id, tid, idtran: newTx.idtran });
  },
  {
    connection,
    concurrency: 5,
    limiter: {
      max: 20,
      duration: 60000,
    },
  }
);

bankWorker.on('completed', (job) => {
  logger.debug('Bank job completed', { jobId: job.id });
});

bankWorker.on('failed', (job, err) => {
  logger.error('Bank job failed', { jobId: job?.id, error: err.message });
});

logger.info('Bank Worker started — listening on queue: bank-webhook');

module.exports = { bankWorker };
