/**
 * F012 — Transaction Classifier — Repository
 * getTransactionById(idtran) → { idtran, note }
 * updateTransactionCategory(transactionId, categoryId) → updated transaction
 *
 * CSDL mới: transaction PK = idtran, nội dung = note, phân loại = idcategory
 */

const { prisma } = require('../../../../config/db');
const logger = require('../../../../core/logger');

const classifyRepository = {
  async getTransactionById(id) {
    try {
      return prisma.transaction.findUnique({
        where: { idtran: id },
        select: { idtran: true, note: true, idcategory: true, amount: true },
      });
    } catch (error) {
      logger.warn('Transaction table not ready — returning mock data', { error: error.message });
      return { idtran: id, note: 'Giao dich mau — Transaction table chua san sang', amount: 0 };
    }
  },

  // Future: Sau khi worker predict xong sẽ gọi hàm này (CSDL mới: idcategory)
  // async updateTransactionCategory(transactionId, categoryId) {
  //   return prisma.transaction.update({
  //     where: { idtran: transactionId },
  //     data: { idcategory: categoryId, update_at: new Date() },
  //   });
  // },
};

module.exports = classifyRepository;
