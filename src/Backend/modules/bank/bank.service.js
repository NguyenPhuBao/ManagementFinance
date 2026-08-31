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
          delay: 2000,
        },
      });
      logger.info(`Enqueued webhook transaction to bank-webhook queue`, { tid });
    }
  },

  /**
   * Lấy danh sách các giao dịch ngân hàng đang ở trạng thái Pending của người dùng
   */
  async getPendingTransactions(idaccount) {
    return bankRepository.getPendingTransactions(idaccount);
  },

  /**
   * Xác nhận duyệt giao dịch ngân hàng (Gán danh mục, chuyển sang Confirmed)
   */
  async confirmTransaction(idaccount, { idtran, idcategory, note }) {
    if (!idtran) {
      throw new Error('Thiếu idtran của giao dịch cần xác nhận');
    }

    try {
      const updated = await bankRepository.confirmTransaction(idtran, idaccount, { idcategory, note });
      logger.info('Bank transaction confirmed successfully', { idtran, idaccount, idcategory });
      return updated;
    } catch (error) {
      logger.error('Failed to confirm bank transaction, marking as Fail', { idtran, idaccount, error: error.message });
      await bankRepository.failTransaction(idtran, idaccount).catch(() => {});
      throw error;
    }
  },

  /**
   * Từ chối giao dịch ngân hàng (Chuyển sang Rejected)
   */
  async rejectTransaction(idaccount, idtran) {
    if (!idtran) {
      throw new Error('Thiếu idtran của giao dịch cần từ chối');
    }
    const rejected = await bankRepository.rejectTransaction(idtran, idaccount);
    logger.info('Bank transaction rejected', { idtran, idaccount });
    return rejected;
  },
};

module.exports = bankService;
