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
    
    // Payload của Casso thường trả về mảng các giao dịch trong trường `data`
    const records = payload.data || [];
    
    for (const record of records) {
      await queue.add('casso_webhook', { cassoTx: record }, {
        attempts: 3,
        backoff: {
          type: 'exponential',
          delay: 2000
        }
      });
      logger.info(`Enqueued webhook transaction to bank-webhook queue`, { tid: record.tid });
    }
  }
};

module.exports = bankService;
