/**
 * Bank Worker (BullMQ)
 * Lắng nghe và xử lý các jobs từ hàng đợi 'bank-webhook'
 * Hỗ trợ tiếp nhận SePay Bank Hub IPN, khử trùng lặp giao dịch (Idempotency),
 * cập nhật số dư lũy kế (accumulated), gọi AI Classify 3-Tier và phát Socket.io realtime
 */

const { Worker } = require('bullmq');
const { randomUUID } = require('crypto');
const logger = require('../core/logger');
const { prisma: defaultPrisma } = require('../config/db');
const eventBus = require('../core/event-bus');
const socketService = require('../core/socket');
const { hashBlindIndex, encrypt } = require('../utils/crypto.util');
const { maskAccountNumber } = require('../utils/masking.util');
const { filterSensitiveNote } = require('../utils/content-filter.util');

const Redis = require('ioredis');
const connection = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: null,
});

/**
 * Xử lý logic nghiệp vụ một giao dịch từ SePay Bank Hub
 * Tách độc lập để tối ưu khả năng Unit Test & Reusability
 */
async function processSepayTransaction({
  txData,
  prismaClient = defaultPrisma,
  socketService: customSocket = socketService,
  classifyService: customClassifyService,
}) {
  const {
    bank_tran_id,
    account_number,
    bank_account_xid,
    amount,
    accumulated,
    type,
    transfer_type,
    note,
    gateway,
    date_transaction,
  } = txData;

  if (!account_number) {
    logger.warn('processSepayTransaction: Missing account_number', { txData });
    return { status: 'invalid_payload', reason: 'Missing account_number' };
  }

  if (!bank_tran_id) {
    logger.warn('processSepayTransaction: Missing bank_tran_id', { txData });
    return { status: 'invalid_payload', reason: 'Missing bank_tran_id' };
  }

  // 1. Tìm tài khoản ngân hàng tương ứng trong CSDL
  // Ưu tiên tìm theo bank_account_xid nếu có, hoặc tìm theo account_number đang Active
  let bankAcc = null;
  if (bank_account_xid) {
    bankAcc = await prismaClient.bank_account.findFirst({
      where: {
        id_casso_account: String(bank_account_xid),
        connect_status: { in: ['Active', 'active'] },
        delete_at: null,
      },
    });
  }

  if (!bankAcc) {
    const accHash = hashBlindIndex(account_number);
    bankAcc = await prismaClient.bank_account.findFirst({
      where: {
        OR: [
          ...(accHash ? [{ account_number_hash: accHash }] : []),
          { account_number: String(account_number) },
        ],
        connect_status: { in: ['Active', 'active'] },
        delete_at: null,
      },
    });
  }

  if (!bankAcc) {
    logger.warn(`processSepayTransaction: No active bank_account found for account_number ${maskAccountNumber(account_number)}`, {
      bank_tran_id,
      bank_account_xid,
    });
    return { status: 'bank_account_not_found' };
  }

  const { idaccount } = bankAcc;

  // 2. Khử trùng lặp tuyệt đối qua (provider = 'BankSync', bank_tran_id)
  const existing = await prismaClient.transaction.findFirst({
    where: {
      provider: { in: ['BankSync', 'Casso'] },
      bank_tran_id: String(bank_tran_id),
    },
  });

  if (existing) {
    logger.info(`processSepayTransaction: Transaction ${bank_tran_id} already exists. Skipping.`, {
      bank_tran_id,
    });
    return { status: 'skipped_duplicate', existingId: existing.idtran };
  }

  // 3. Tìm hoặc tự động tạo ví Banking tương ứng
  let wallet = await prismaClient.wallet.findFirst({
    where: {
      idaccount,
      id_bank_casso: bankAcc.id_bank_account,
      delete_at: null,
    },
  });

  // Tính toán số dư mới: Ưu tiên số dư lũy kế từ SePay nếu có
  let newBalance;
  if (accumulated !== undefined && accumulated !== null && !isNaN(Number(accumulated))) {
    newBalance = Number(accumulated);
  } else {
    // Fallback nếu thiếu accumulated: cộng hoặc trừ theo transfer_type
    const currentBalance = Number(bankAcc.balance) || 0;
    const isDebit = transfer_type === 'debit' || type === 'Chi';
    newBalance = isDebit ? currentBalance - Math.abs(amount) : currentBalance + Math.abs(amount);
  }

  if (!wallet) {
    const bankDisplayName = bankAcc.bank_name || gateway || 'Bank';
    const rawWalletName = `${bankDisplayName} - ${bankAcc.account_number}`;
    const walletName = rawWalletName.length > 100 ? rawWalletName.substring(0, 100) : rawWalletName;

    wallet = await prismaClient.wallet.create({
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

  // 4. Tự động gọi AI Classify gợi ý danh mục chi tiêu (3-Tier)
  let predictedCategoryId = null;
  let predictedCategoryName = null;
  let aiConfidence = 0;

  const classifyService =
    customClassifyService || require('../modules/ai/features/classify/classify.service');

  if (classifyService && typeof classifyService.classifySingle === 'function') {
    try {
      const predicted = await classifyService.classifySingle(idaccount, {
        text: note || 'Giao dịch ngân hàng',
        amount: Math.abs(amount),
        merchant: bankAcc.bank_name || gateway || '',
        source: 'BankSync',
      });
      if (predicted && predicted.category_id) {
        predictedCategoryId = predicted.category_id;
        predictedCategoryName = predicted.category_name;
        aiConfidence = predicted.confidence || 0;
        logger.info('processSepayTransaction: Auto-classified by AI', {
          bank_tran_id,
          categoryId: predicted.category_id,
          categoryName: predicted.category_name,
        });
      }
    } catch (classifyErr) {
      logger.warn('processSepayTransaction: AI classification failed, category set to null', {
        bank_tran_id,
        error: classifyErr.message,
      });
    }
  }

  // 5. Làm sạch ghi chú PII/Card/Password & Tạo bản ghi giao dịch với status = 'Pending'
  const txDate = date_transaction instanceof Date && !isNaN(date_transaction.getTime())
    ? date_transaction
    : new Date();

  const safeNote = filterSensitiveNote(note || 'Giao dịch ngân hàng SePay');

  const newTx = await prismaClient.transaction.create({
    data: {
      idtran: randomUUID(),
      idaccount,
      idwallet: wallet.idwallet,
      amount: Math.abs(amount),
      type: type || (transfer_type === 'debit' ? 'Chi' : 'Thu'),
      status: 'Pending',
      provider: 'BankSync',
      bank_tran_id: String(bank_tran_id),
      idcategory: predictedCategoryId,
      note: encrypt(safeNote),
      date_transaction: txDate,
      update_at: new Date(),
    },
  });

  // 6. Cập nhật số dư đồng bộ cho cả bank_account và wallet
  await prismaClient.bank_account.update({
    where: { id_bank_account: bankAcc.id_bank_account },
    data: { balance: newBalance, update_at: new Date() },
  });

  await prismaClient.wallet.update({
    where: { idwallet: wallet.idwallet },
    data: { balance: newBalance, update_at: new Date() },
  });

  // 7. Phát sự kiện thời gian thực qua Socket.io
  const socketPayload = {
    idtran: newTx.idtran,
    amount: newTx.amount,
    type: newTx.type,
    status: newTx.status,
    transaction_status: newTx.status,
    note: safeNote,
    gateway: bankAcc.bank_name || gateway,
    account_number: bankAcc.account_number,
    date_transaction: newTx.date_transaction,
    suggested_category: predictedCategoryName,
    confidence: aiConfidence,
  };

  if (customSocket) {
    if (typeof customSocket.emitBankTransaction === 'function') {
      customSocket.emitBankTransaction(idaccount, socketPayload);
    } else if (typeof customSocket.emitToUser === 'function') {
      customSocket.emitToUser(idaccount, 'bank_transaction.incoming', socketPayload);
    }
    if (typeof customSocket.emitToAdmin === 'function') {
      customSocket.emitToAdmin('admin.bank_transaction_created', socketPayload);
    }
  }

  // 8. Publish EventBus nội bộ
  if (eventBus && typeof eventBus.publish === 'function') {
    await eventBus.publish('bank_transaction.pending', {
      idtran: newTx.idtran,
      idaccount,
      amount: newTx.amount,
      bankName: bankAcc.bank_name,
      accountNumber: bankAcc.account_number,
      description: safeNote,
      date: newTx.date_transaction,
    });
    await eventBus.publish('transaction.created', { transactionId: newTx.idtran, idaccount });
  }

  logger.info('processSepayTransaction: Transaction successfully processed', {
    bank_tran_id,
    idtran: newTx.idtran,
    newBalance,
  });

  return { status: 'created', transaction: { ...newTx, note: safeNote }, newBalance };
}

// BullMQ Worker instance
const bankWorker = new Worker(
  'bank-webhook',
  async (job) => {
    const { sepayTx, cassoTx } = job.data;
    const tx = sepayTx || cassoTx;

    if (!tx || typeof tx !== 'object') {
      logger.warn('Bank Worker: Invalid job payload, skipping', { jobId: job.id });
      return;
    }

    logger.info('Bank Worker: Processing job', { jobId: job.id, tx });
    await processSepayTransaction({ txData: tx });
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

module.exports = {
  bankWorker,
  processSepayTransaction,
};
