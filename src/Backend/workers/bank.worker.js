const { Worker } = require('bullmq');
const logger = require('../core/logger');
const { prisma } = require('../config/db');
const { v4: uuidv4 } = require('uuid');
const eventBus = require('../core/event-bus');

const Redis = require('ioredis');
/**const connection = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT, 10) || 6379,
}; */
const connection = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: null,
});

const bankWorker = new Worker(
  'bank-webhook',
  async (job) => {
    const { cassoTx } = job.data;

    // Casso webhook transaction payload thường có cấu trúc:
    // tid, amount, description, cusum_balance, when, subAccId
    const { tid, amount, description, cusum_balance, when, subAccId } = cassoTx;

    logger.info('Bank Worker: Processing webhook transaction', { jobId: job.id, tid });

    // 1. Tìm tài khoản NH dựa trên subAccId (số tài khoản)
    const bankAcc = await prisma.bank_account.findFirst({
      where: { account_number: subAccId, connect_status: 'active', delete_at: null }
    });

    if (!bankAcc) {
      logger.warn(`Bank Worker: No active bank_account found for account_number ${subAccId}`, { tid });
      return;
    }

    const { idaccount } = bankAcc;

    // 2. Khử trùng lặp qua (provider, bank_tran_id) — CSDL mới
    const existing = await prisma.transaction.findFirst({
      where: {
        provider: 'Casso',
        bank_tran_id: String(tid)
      }
    });

    if (existing) {
      logger.info(`Bank Worker: Transaction ${tid} already exists. Skipping.`, { tid });
      return;
    }

    // 3. Tìm hoặc tạo ví đồng bộ (wallet) tương ứng với tài khoản NH này
    // CSDL mới: ví từ Casso = Type 'Banking' + Id_bank_casso
    const walletName = `${bankAcc.bank_name} - ${bankAcc.account_number}`;
    let wallet = await prisma.wallet.findFirst({
      where: { idaccount, id_bank_casso: bankAcc.id_bank_account, delete_at: null }
    });

    if (!wallet) {
      wallet = await prisma.wallet.create({
        data: {
          idwallet: uuidv4(),
          idaccount,
          name: walletName,
          type: 'Banking',
          id_bank_casso: bankAcc.id_bank_account,
          balance: cusum_balance,
          update_at: new Date()
        }
      });
    }

    // 4. Tạo giao dịch mới
    // CSDL mới: Amount GIỮ DẤU ± (dương = vào, âm = ra), type = Transaction, Idcategory = NULL chờ phân loại
    const txDate = new Date(when);

    const newTx = await prisma.transaction.create({
      data: {
        idtran: uuidv4(),
        idaccount,
        idwallet: wallet.idwallet,
        amount: amount, // giữ nguyên dấu từ Casso
        type: 'Transaction',
        note: description,
        create_at: isNaN(txDate) ? new Date() : txDate,
        update_at: new Date(),
        provider: 'Casso',
        bank_tran_id: String(tid),
        idcategory: null // chờ AI phân loại sau
      }
    });

    // 5. Cập nhật số dư
    await prisma.bank_account.update({
      where: { id_bank_account: bankAcc.id_bank_account },
      data: { balance: cusum_balance, update_at: new Date() }
    });

    await prisma.wallet.update({
      where: { idwallet: wallet.idwallet },
      data: { balance: cusum_balance, update_at: new Date() }
    });

    // 6. Phát sự kiện để báo cho Sync/Notification/Classify
    if (eventBus && eventBus.publish) {
      await eventBus.publish('transaction.created', { transactionId: newTx.id, idaccount });
    }

    logger.info('Bank Worker: Webhook transaction processed successfully', { jobId: job.id, tid });
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
