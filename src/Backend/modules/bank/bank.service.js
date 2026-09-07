/**
 * Bank Service
 * Business logic cho module Ngân hàng (SePay Bank Hub)
 */

const sepayClient = require('./sepay/sepay.client');
const sepayWebhook = require('./sepay/sepay.webhook');
const bankRepository = require('./bank.repository');
const { getQueue } = require('../../core/queue');
const logger = require('../../core/logger');

const bankService = {
  /**
   * Đăng ký/Khai báo tài khoản ngân hàng thủ công từ Client-app
   */
  async registerAccount(idaccount, data) {
    if (!data.account_number) {
      throw new Error('Số tài khoản ngân hàng không được để trống');
    }
    return bankRepository.registerAccount(idaccount, data);
  },

  /**
   * Tạo đường dẫn Hosted Link (In-App WebView) để người dùng liên kết Internet Banking
   * @param {number} idaccount
   * @param {Object} [userInfo]
   */
  async createLinkUrl(idaccount, userInfo = {}) {
    const linkResult = await sepayClient.createLinkToken({
      idaccount,
      customerName: userInfo.fullname || `User ${idaccount}`,
      customerEmail: userInfo.email || `user_${idaccount}@flowmoney.io`,
    });

    logger.info('Generated SePay Hosted Link for user', {
      idaccount,
      linkToken: linkResult.link_token,
    });

    return linkResult;
  },

  /**
   * Lấy danh sách tài khoản ngân hàng từ SePay, lưu vào DB và trả về
   * @param {number} idaccount
   */
  async getAccounts(idaccount) {
    try {
      // 1. Gọi SePay Bank Hub API lấy toàn bộ tài khoản của customer_id = account_${idaccount}
      const accounts = await sepayClient.getBankAccounts(idaccount);

      // 2. Lưu vào CSDL ánh xạ với idaccount này
      if (Array.isArray(accounts) && accounts.length > 0) {
        await bankRepository.upsertBankAccounts(idaccount, accounts);
      }
    } catch (error) {
      logger.warn('Could not sync latest accounts directly from SePay, fallback to local DB', {
        idaccount,
        error: error.message,
      });
    }

    // 3. Luôn trả về danh sách tài khoản ngân hàng từ DB
    return bankRepository.getBankAccountsByUser(idaccount);
  },

  /**
   * Lấy lịch sử giao dịch trực tiếp từ ngân hàng/SePay (nếu cần tra cứu nhanh)
   */
  async getTransactions(since) {
    return sepayClient.getTransactions?.({ since }) || [];
  },

  /**
   * Đưa webhook payload vào hàng đợi BullMQ để worker xử lý bất đồng bộ
   * Phản hồi ngay lập tức cho SePay trong < 500ms
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
    } else if (payload && typeof payload === 'object') {
      records = [payload];
    }

    for (const record of records) {
      if (!record || typeof record !== 'object') continue;

      const normalizedTx = sepayWebhook.normalizeTransactionPayload(record);
      if (!normalizedTx || !normalizedTx.bank_tran_id) {
        logger.warn('Skipping invalid webhook record', { record });
        continue;
      }

      await queue.add(
        'sepay_webhook',
        { sepayTx: normalizedTx },
        {
          attempts: 3,
          backoff: {
            type: 'exponential',
            delay: 2000,
          },
        }
      );
      logger.info('Enqueued SePay webhook transaction to bank-webhook queue', {
        tid: normalizedTx.bank_tran_id,
        account: normalizedTx.account_number,
        amount: normalizedTx.amount,
      });
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
      const updated = await bankRepository.confirmTransaction(idtran, idaccount, {
        idcategory,
        note,
      });
      logger.info('Bank transaction confirmed successfully', { idtran, idaccount, idcategory });
      return updated;
    } catch (error) {
      logger.error('Failed to confirm bank transaction, marking as Fail', {
        idtran,
        idaccount,
        error: error.message,
      });
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
