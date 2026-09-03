/**
 * F012 — Transaction Classifier — Repository
 * Truy vấn danh mục người dùng, cập nhật từ khóa tự học và gán danh mục giao dịch
 */

const { prisma } = require('../../../../config/db');
const logger = require('../../../../core/logger');

const classifyRepository = {
  /**
   * Lấy toàn bộ danh mục của tài khoản (gồm danh mục mặc định hệ thống + danh mục riêng của user)
   * @param {string} idaccount 
   * @returns {Promise<Array<object>>}
   */
  async getUserCategories(idaccount) {
    try {
      const parsedId = Number(idaccount) || 0;
      const categories = await prisma.category.findMany({
        where: {
          OR: [
            ...(parsedId > 0 ? [{ create_by: parsedId }] : []),
            { is_default: true },
          ],
          delete_at: null,
        },
        select: {
          idcategory: true,
          create_by: true,
          name_category: true,
          classify: true,
          keyword: true,
          icon: true,
          is_default: true,
          is_group: true,
          idgroup: true,
        },
        orderBy: {
          is_default: 'desc',
        },
      });

      return categories.map((c) => {
        const rawName = c.name_category || '';
        const rawKeyword = c.keyword || '';
        return {
          ...c,
          namecategory: rawName,
          namecategory_lower: rawName.trim().toLowerCase(),
          keyword_lower: rawKeyword.trim().toLowerCase(),
        };
      });
    } catch (error) {
      logger.error('ClassifyRepository.getUserCategories failed', { error: error.message, idaccount });
      return [];
    }
  },

  /**
   * Cập nhật thêm từ khóa mới vào trường Category.Keyword (Cơ chế Self-Learning)
   * @param {string} idcategory 
   * @param {string} newKeyword 
   * @returns {Promise<object>}
   */
  async appendCategoryKeyword(idcategory, newKeyword) {
    try {
      const category = await prisma.category.findUnique({
        where: { idcategory },
        select: { idcategory: true, keyword: true },
      });

      if (!category) {
        throw Object.assign(new Error('Khong tim thay danh muc'), { statusCode: 404 });
      }

      // Tách bằng dấu phẩy ',' chuẩn theo chỉ đạo của PO (không phụ thuộc khoảng trắng)
      const existingKeywords = (category.keyword || '')
        .split(',')
        .map((k) => k.trim().toLowerCase())
        .filter(Boolean);

      const normalizedNewKw = newKeyword.trim().toLowerCase();

      // Tránh trùng lặp từ khóa
      if (!existingKeywords.includes(normalizedNewKw)) {
        existingKeywords.push(normalizedNewKw);
      }

      // Nối từ khóa bằng dấu phẩy ',' không có khoảng trắng theo chỉ đạo của PO
      const updatedKeywordStr = existingKeywords.join(',');

      return await prisma.category.update({
        where: { idcategory },
        data: {
          keyword: updatedKeywordStr,
          update_at: new Date(),
        },
      });
    } catch (error) {
      logger.error('ClassifyRepository.appendCategoryKeyword failed', { error: error.message, idcategory });
      throw error;
    }
  },

  /**
   * Lấy thông tin giao dịch theo ID
   * @param {string} idtran 
   * @returns {Promise<object|null>}
   */
  async getTransactionById(idtran) {
    try {
      return await prisma.transaction.findUnique({
        where: { idtran },
        select: {
          idtran: true,
          idaccount: true,
          note: true,
          amount: true,
          idcategory: true,
          provider: true,
        },
      });
    } catch (error) {
      logger.error('ClassifyRepository.getTransactionById failed', { error: error.message, idtran });
      return null;
    }
  },

  /**
   * Cập nhật danh mục cho giao dịch
   * @param {string} idtran 
   * @param {string} idcategory 
   * @returns {Promise<object>}
   */
  async updateTransactionCategory(idtran, idcategory) {
    try {
      return await prisma.transaction.update({
        where: { idtran },
        data: {
          idcategory,
          update_at: new Date(),
        },
      });
    } catch (error) {
      logger.error('ClassifyRepository.updateTransactionCategory failed', { error: error.message, idtran, idcategory });
      throw error;
    }
  },
};

module.exports = classifyRepository;
