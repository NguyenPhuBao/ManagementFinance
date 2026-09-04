/**
 * F013 — AI Deduplication Engine — Service
 * Kiểm tra và khử trùng lặp dữ liệu trước khi chuyển sang Module AI Classify
 */

const dedupRepository = require('./dedup.repository');
const logger = require('../../../../core/logger');

const dedupService = {
  /**
   * Kiểm tra trùng lặp dữ liệu giao dịch dựa trên 3 cấp độ quy tắc
   * @param {number|string} idaccount
   * @param {object} extraction - Kết quả bóc tách từ OCR
   * @param {string} provider - 'ORC' | 'BankSync' | 'SMS'
   * @param {string|null} bankTranId - Mã giao dịch chống trùng
   * @param {object} [options] - Tuỳ chọn (vd mock data trong test)
   * @returns {Promise<{ is_duplicate: boolean, reason?: string, existing_transaction?: object }>}
   */
  async checkDuplicate(idaccount, extraction = {}, provider, bankTranId = null, options = {}) {
    const docType = extraction.document_type || 'RECEIPT';
    const totalAmount = Number(extraction.total_amount || extraction.amount) || 0;
    const txDate = extraction.transaction_date ? new Date(extraction.transaction_date) : new Date();

    // ----------------------------------------------------
    // Quy Tắc 1: Strict Unique Code Matching (Khẳng định 100%)
    // ----------------------------------------------------
    if (bankTranId) {
      const existing = await dedupRepository.findByBankTranId(idaccount, provider, bankTranId, options);
      if (existing) {
        logger.info('Dedup Service: Duplicate detected by strict bank_tran_id', {
          idaccount,
          provider,
          bankTranId,
          existingIdtran: existing.idtran,
        });
        return {
          is_duplicate: true,
          reason: 'duplicate_bank_tran_id',
          existing_transaction: existing,
        };
      }
    }

    // ----------------------------------------------------
    // Quy Tắc 2: Fuzzy Invoice Matching (Khi hóa đơn không có invoice_no)
    // ----------------------------------------------------
    if (docType === 'RECEIPT' && extraction.merchant_name && totalAmount > 0) {
      const existing = await dedupRepository.findFuzzyInvoice(
        idaccount,
        provider,
        totalAmount,
        txDate,
        extraction.merchant_name,
        options
      );

      if (existing) {
        logger.info('Dedup Service: Duplicate detected by fuzzy invoice matching', {
          idaccount,
          merchantName: extraction.merchant_name,
          amount: totalAmount,
          existingIdtran: existing.idtran,
        });
        return {
          is_duplicate: true,
          reason: 'fuzzy_invoice_matched',
          existing_transaction: existing,
        };
      }
    }

    // ----------------------------------------------------
    // Quy Tắc 3: Transfer / SMS Matching (Khi biên lai/SMS không có mã FT)
    // ----------------------------------------------------
    if ((docType === 'BANK_TRANSFER' || docType === 'SMS_BANKING') && totalAmount > 0) {
      const counterpartAccount = extraction.destination_account || extraction.source_account || null;
      const note = extraction.note || '';

      const existing = await dedupRepository.findFuzzyTransfer(
        idaccount,
        totalAmount,
        txDate,
        counterpartAccount,
        note,
        options
      );

      if (existing) {
        logger.info('Dedup Service: Duplicate detected by transfer/SMS matching', {
          idaccount,
          amount: totalAmount,
          existingIdtran: existing.idtran,
        });
        return {
          is_duplicate: true,
          reason: 'transfer_sms_matched',
          existing_transaction: existing,
        };
      }
    }

    // Không phát hiện trùng lặp
    return {
      is_duplicate: false,
    };
  },
};

module.exports = dedupService;
