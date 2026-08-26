const cassoClient = require('./casso/casso.client');
const bankRepository = require('./bank.repository');
const { getQueue } = require('../../core/queue');
const logger = require('../../core/logger');

const bankService = {
  /**
   * Lấy danh sách tài khoản ngân hàng từ Casso, lưu vào DB và trả về
   */
  async getAccounts(idaccount) {
    // 1. Gọi Casso API lấy toàn bộ tài khoản
    const accounts = await cassoClient.getAccounts();
    
    // 2. Lưu vào CSDL ánh xạ với idaccount này
    await bankRepository.upsertBankAccounts(idaccount, accounts);

    // 3. Trả về danh sách từ DB
    return bankRepository.getBankAccountsByUser(idaccount);
  },

  /**
   * Lấy lịch sử giao dịch (Chủ yếu từ Casso trực tiếp nếu cần xem nhanh)
   * Tuy nhiên giao dịch thực tế sẽ được webhook đẩy về DB.
   */
  async getTransactions(fromDate) {
    return cassoClient.getTransactions(fromDate);
  },

  /**
   * Đưa webhook payload vào hàng đợi BullMQ để worker xử lý
   */
  async enqueueWebhookJob(payload) {
    const queue = getQueue('bank-webhook');
    if (!queue) {
      throw new Error('Bank webhook queue is not initialized');
    }
    
    // Chuẩn hoá records: hỗ trợ cả Array, Single Object, hoặc rỗng
    let records = [];
    if (Array.isArray(payload.data)) {
      records = payload.data;
    } else if (payload.data && typeof payload.data === 'object') {
      records = [payload.data];
    } else if (Array.isArray(payload)) {
      records = payload;
    }
    
    for (const record of records) {
      if (!record || typeof record !== 'object') continue;
      const tid = record.tid || record.id || 'UNKNOWN';
      await queue.add('casso_webhook', { cassoTx: record }, {
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 2000
        }
      });
      logger.info(`Enqueued webhook transaction to bank-webhook queue`, { tid });
    }
  }
};

module.exports = bankService;
