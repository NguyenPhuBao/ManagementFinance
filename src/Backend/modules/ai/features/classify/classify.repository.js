/**
 * F012 — Transaction Classifier — Repository
 * getTransactionById(id) → { id, description }
 * updateTransactionCategory(transactionId, categoryId) → updated transaction (future)
 *
 * ⚠️ Hiện tại bảng Transaction chưa có trong Prisma schema.
 * Khi schema được cập nhật (bởi team Sync), code ở đây sẽ hoạt động ngay
 * sau khi chạy `prisma generate`.
 * Nếu tên field khác (vd: transactionId thay vì id), chỉ cần sửa 1 dòng where.
 */

const { prisma } = require('../../../../config/db');
const logger = require('../../../../core/logger');

const classifyRepository = {
  async getTransactionById(id) {
    try {
      // Khi bảng Transaction chưa có trong Prisma schema,
      // prisma.transaction sẽ là undefined → catch sẽ bắt lỗi này
      if (!prisma.transaction) {
        logger.warn('Transaction model not found in Prisma schema yet — returning mock data for development');
        return { id, description: 'Giao dich mau — Transaction table chua san sang' };
      }
      return prisma.transaction.findUnique({
        where: { id },
        select: { id: true, description: true },
      });
    } catch (error) {
      logger.warn('Transaction table not ready — returning mock data', { error: error.message });
      return { id, description: 'Giao dich mau — Transaction table chua san sang' };
    }
  },

  // Future: Sau khi worker predict xong sẽ gọi hàm này
  // async updateTransactionCategory(transactionId, categoryId) {
  //   return prisma.transaction.update({
  //     where: { id: transactionId },
  //     data: { categoryId },
  //   });
  // },
};

module.exports = classifyRepository;
