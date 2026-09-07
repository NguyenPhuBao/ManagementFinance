/**
 * SePay Bank Hub & Personal Webhook Verifier & Normalizer
 * Cung cấp cơ chế xác thực chữ ký Webhook Timing-Safe
 * Chuẩn hóa đa định dạng payload (Hỗ trợ cả SePay Cá nhân my.sepay.vn và SePay Bank Hub)
 */

const crypto = require('crypto');
const config = require('../../../config');
const logger = require('../../../core/logger');

const sepayWebhook = {
  /**
   * Xác thực Webhook gửi từ SePay qua API Key
   * Sử dụng crypto.timingSafeEqual để chống Timing Attack
   * Header chuẩn: Authorization: ApiKey <KEY> (hoặc x-api-key)
   *
   * @param {Object} req Express request object
   * @param {string} [customKey] Key dùng trong unit test (nếu có)
   * @returns {boolean}
   */
  verifySignature(req, customKey) {
    const configuredKey = customKey || config.sepay?.webhookApiKey || process.env.SEPAY_WEBHOOK_API_KEY;

    if (!configuredKey) {
      logger.error('SePay Webhook Verification: SEPAY_WEBHOOK_API_KEY is not configured');
      return false;
    }

    const authHeader = req.headers?.authorization || req.headers?.Authorization || req.headers?.['x-api-key'];

    if (!authHeader) {
      logger.warn('SePay Webhook Verification: Missing Authorization header');
      return false;
    }

    let receivedKey = '';
    if (authHeader.startsWith('ApiKey ') || authHeader.startsWith('apikey ')) {
      receivedKey = authHeader.substring(7).trim();
    } else if (req.headers?.['x-api-key']) {
      receivedKey = authHeader.trim();
    } else {
      logger.warn('SePay Webhook Verification: Invalid header format, expected "ApiKey <KEY>"');
      return false;
    }

    try {
      const bufferReceived = Buffer.from(receivedKey);
      const bufferExpected = Buffer.from(configuredKey);

      if (bufferReceived.length !== bufferExpected.length) {
        return false;
      }

      return crypto.timingSafeEqual(bufferReceived, bufferExpected);
    } catch (error) {
      logger.error('Error during Webhook signature verification:', { error: error.message });
      return false;
    }
  },

  /**
   * Chuẩn hóa payload IPN của SePay (Tương thích cả SePay Cá Nhân và SePay Bank Hub)
   * @param {Object} rawPayload
   * @returns {Object} normalized payload
   */
  normalizeTransactionPayload(rawPayload) {
    if (!rawPayload || typeof rawPayload !== 'object') {
      return null;
    }

    // 1. Mã giao dịch ngân hàng (Hỗ trợ referenceCode, reference_code, code, reference_number, id)
    const tid =
      rawPayload.referenceCode ||
      rawPayload.reference_code ||
      rawPayload.code ||
      rawPayload.reference_number ||
      (rawPayload.id ? String(rawPayload.id) : null);

    // 2. Số tài khoản (Hỗ trợ accountNumber, account_number, subAccount, sub_account)
    const accountNumber =
      rawPayload.accountNumber ||
      rawPayload.account_number ||
      rawPayload.subAccount ||
      rawPayload.sub_account;

    const bankAccountXid = rawPayload.bank_account_xid || null;

    // 3. Xác định transfer_type:
    // SePay Cá nhân: transferType = 'in' hoặc 'out'
    // SePay Bank Hub: transfer_type = 'credit' hoặc 'debit'
    const rawTransferType = String(rawPayload.transferType || rawPayload.transfer_type || '').toLowerCase();
    let transferType = 'credit';

    if (
      rawTransferType === 'out' ||
      rawTransferType === 'debit' ||
      (rawPayload.amount_out && Number(rawPayload.amount_out) > 0)
    ) {
      transferType = 'debit';
    } else {
      transferType = 'credit';
    }

    // 4. Số tiền biến động (Hỗ trợ transferAmount, amount, amount_in, amount_out)
    let amount = 0;
    if (rawPayload.transferAmount !== undefined && rawPayload.transferAmount !== null) {
      amount = Number(rawPayload.transferAmount);
    } else if (rawPayload.amount !== undefined && rawPayload.amount !== null) {
      amount = Number(rawPayload.amount);
    } else if (transferType === 'debit' && rawPayload.amount_out) {
      amount = Number(rawPayload.amount_out);
    } else if (rawPayload.amount_in) {
      amount = Number(rawPayload.amount_in);
    }
    amount = Math.abs(Number(amount) || 0);

    // 5. Số dư lũy kế (accumulated)
    let accumulated = null;
    if (rawPayload.accumulated !== undefined && rawPayload.accumulated !== null) {
      accumulated = Number(rawPayload.accumulated);
    }

    // 6. Nội dung chuyển khoản
    const content =
      rawPayload.content ||
      rawPayload.transaction_content ||
      rawPayload.description ||
      rawPayload.body ||
      'Giao dịch ngân hàng SePay';

    // 7. Thời gian giao dịch (Hỗ trợ transactionDate, transaction_date)
    let txDate = new Date();
    const rawDate = rawPayload.transactionDate || rawPayload.transaction_date;
    if (rawDate) {
      const parsed = new Date(rawDate);
      if (!isNaN(parsed.getTime())) {
        txDate = parsed;
      }
    }

    return {
      bank_tran_id: tid ? String(tid) : null,
      account_number: accountNumber ? String(accountNumber) : null,
      bank_account_xid: bankAccountXid ? String(bankAccountXid) : null,
      gateway: rawPayload.gateway || 'Bank',
      transfer_type: transferType,
      type: transferType === 'debit' ? 'Chi' : 'Thu',
      amount,
      accumulated,
      note: content,
      date_transaction: txDate,
      raw_payload: rawPayload,
    };
  },
};

module.exports = sepayWebhook;
