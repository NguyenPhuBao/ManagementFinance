/**
 * F013 — Deduplication Engine — Repository
 * Đối soát CSDL bảng transaction để phát hiện trùng lặp
 */

const { prisma } = require('../../../../config/db');
const logger = require('../../../../core/logger');
const { removeVietnameseTones } = require('../classify/classify.preprocess');

const dedupRepository = {
  /**
   * Tìm giao dịch theo mã duy nhất bank_tran_id và provider
   */
  async findByBankTranId(idaccount, provider, bankTranId, options = {}) {
    const rawCode = String(bankTranId).toLowerCase().trim();
    if (options._mockExistingTransactions) {
      return options._mockExistingTransactions.find((tx) => {
        if (Number(tx.idaccount) !== Number(idaccount)) return false;
        if (tx.provider !== provider) return false;
        const existingCode = String(tx.bank_tran_id || '').toLowerCase().trim();
        return existingCode === rawCode || existingCode.startsWith(`${rawCode}_grp_`);
      }) || null;
    }

    try {
      const parsedId = Number(idaccount) || 0;
      return await prisma.transaction.findFirst({
        where: {
          idaccount: parsedId,
          provider: provider,
          deleted_at: null,
          OR: [
            { bank_tran_id: String(bankTranId) },
            { bank_tran_id: { startsWith: `${String(bankTranId)}_grp_` } },
          ],
        },
        select: {
          idtran: true,
          idaccount: true,
          amount: true,
          date_transaction: true,
          type: true,
          provider: true,
          bank_tran_id: true,
          note: true,
          status: true,
        },
      });
    } catch (err) {

      logger.error('Dedup Repository: findByBankTranId failed', { error: err.message });
      return null;
    }
  },

  /**
   * Tìm giao dịch mờ theo merchant_name + amount + date_transaction (Hóa đơn)
   */
  async findFuzzyInvoice(idaccount, provider, amount, transactionDate, merchantName, options = {}) {
    const targetAmount = Number(amount);
    const targetDate = new Date(transactionDate);
    const normalizedMerchant = removeVietnameseTones(merchantName);

    if (options._mockExistingTransactions) {
      return options._mockExistingTransactions.find((tx) => {
        if (Number(tx.idaccount) !== Number(idaccount)) return false;
        if (tx.provider !== provider) return false;
        if (Number(tx.amount) !== targetAmount) return false;

        const txD = new Date(tx.date_transaction);
        const sameDay =
          txD.getFullYear() === targetDate.getFullYear() &&
          txD.getMonth() === targetDate.getMonth() &&
          txD.getDate() === targetDate.getDate();
        if (!sameDay) return false;

        const normalizedNote = removeVietnameseTones(tx.note || '');
        return normalizedNote.includes(normalizedMerchant) || normalizedMerchant.includes(normalizedNote);
      }) || null;
    }

    try {
      const parsedId = Number(idaccount) || 0;
      const startOfDay = new Date(targetDate);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(targetDate);
      endOfDay.setHours(23, 59, 59, 999);

      const candidates = await prisma.transaction.findMany({
        where: {
          idaccount: parsedId,
          provider: provider,
          amount: targetAmount,
          date_transaction: {
            gte: startOfDay,
            lte: endOfDay,
          },
          deleted_at: null,
        },
        select: {
          idtran: true,
          idaccount: true,
          amount: true,
          date_transaction: true,
          type: true,
          provider: true,
          bank_tran_id: true,
          note: true,
          status: true,
        },
      });

      if (!candidates || candidates.length === 0) return null;

      // So khớp tên cửa hàng trong note
      const matched = candidates.find((c) => {
        const normNote = removeVietnameseTones(c.note || '');
        return normNote.includes(normalizedMerchant) || normalizedMerchant.includes(normNote);
      });

      return matched || null;
    } catch (err) {
      logger.error('Dedup Repository: findFuzzyInvoice failed', { error: err.message });
      return null;
    }
  },

  /**
   * Tìm giao dịch mờ theo amount + date_transaction + counterpart (Biên lai / SMS)
   */
  async findFuzzyTransfer(idaccount, amount, transactionDate, counterpartAccount, note, options = {}) {
    const targetAmount = Number(amount);
    const targetDate = new Date(transactionDate);

    if (options._mockExistingTransactions) {
      return options._mockExistingTransactions.find((tx) => {
        if (Number(tx.idaccount) !== Number(idaccount)) return false;
        if (Number(tx.amount) !== targetAmount) return false;

        const txD = new Date(tx.date_transaction);
        const sameDay =
          txD.getFullYear() === targetDate.getFullYear() &&
          txD.getMonth() === targetDate.getMonth() &&
          txD.getDate() === targetDate.getDate();
        if (!sameDay) return false;

        return true;
      }) || null;
    }

    try {
      const parsedId = Number(idaccount) || 0;
      const startOfDay = new Date(targetDate);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(targetDate);
      endOfDay.setHours(23, 59, 59, 999);

      const candidates = await prisma.transaction.findMany({
        where: {
          idaccount: parsedId,
          amount: targetAmount,
          date_transaction: {
            gte: startOfDay,
            lte: endOfDay,
          },
          deleted_at: null,
        },
        select: {
          idtran: true,
          idaccount: true,
          amount: true,
          date_transaction: true,
          type: true,
          provider: true,
          bank_tran_id: true,
          note: true,
          status: true,
        },
      });

      if (!candidates || candidates.length === 0) return null;
      return candidates[0];
    } catch (err) {
      logger.error('Dedup Repository: findFuzzyTransfer failed', { error: err.message });
      return null;
    }
  },
};

module.exports = dedupRepository;
