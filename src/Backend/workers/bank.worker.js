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
      where: { account_number: subAccId, connect_status: 'active' }
    });

    if (!bankAcc) {
      logger.warn(`Bank Worker: No active bank_account found for account_number ${subAccId}`, { tid });
      return;
    }

    const { idaccount } = bankAcc;

    // 2. Khử trùng lặp qua tid
    const existing = await prisma.transaction.findUnique({
      where: {
        uq_transaction_external: {
          provider: 'casso',
          external_transaction_id: String(tid)
        }
      }
    });

    if (existing) {
      logger.info(`Bank Worker: Transaction ${tid} already exists. Skipping.`, { tid });
      return;
    }

    // 3. Tìm hoặc tạo ví đồng bộ (wallet) tương ứng với tài khoản NH này
    const walletName = `${bankAcc.bank_name} - ${bankAcc.account_number}`;
    let wallet = await prisma.wallet.findFirst({
      where: { idaccount, name: walletName }
    });

    if (!wallet) {
      wallet = await prisma.wallet.create({
        data: {
          id: uuidv4(),
          idaccount,
          name: walletName,
          type: 'bank',
          balance: cusum_balance,
          updated_at: new Date()
        }
      });
    }

    // 4. Tạo giao dịch mới
    const type = amount >= 0 ? 'thu' : 'chi';
    const txDate = new Date(when);

    const newTx = await prisma.transaction.create({
      data: {
        id: uuidv4(),
        idaccount,
        wallet_id: wallet.id,
        amount: Math.abs(amount),
        type,
        note: description,
        date: isNaN(txDate) ? new Date() : txDate,
        provider: 'casso',
        external_transaction_id: String(tid),
        updated_at: new Date()
      }
    });

    // 5. Cập nhật số dư
    await prisma.bank_account.update({
      where: { id: bankAcc.id },
      data: { balance: cusum_balance, updated_at: new Date() }
    });

    await prisma.wallet.update({
      where: { id: wallet.id },
      data: { balance: cusum_balance, updated_at: new Date() }
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
