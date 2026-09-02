/**
 * F012 — Transaction Classifier — Controller
 * Xử lý các request API phân loại giao dịch (Single, Batch, Feedback)
 */

const classifyService = require('./classify.service');
const logger = require('../../../../core/logger');

const classifyController = {
  /**
   * POST /api/ai/classify/single
   * Phân loại giao dịch đơn lẻ
   */
  async handleClassifySingle(req, res, next) {
    try {
      const idaccount = req.user?.idaccount || req.user?.userId;
      if (!idaccount) {
        return res.status(401).json({ success: false, message: 'Chua xac thuc nguoi dung' });
      }

      const { text, amount, merchant, source, counterpart_name } = req.body;
      const result = await classifyService.classifySingle(idaccount, {
        text,
        amount,
        merchant,
        source,
        counterpart_name,
      });

      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      logger.error('ClassifyController.handleClassifySingle error', { error: error.message });
      next(error);
    }
  },

  /**
   * POST /api/ai/classify/batch
   * Phân loại hàng loạt mặt hàng từ hóa đơn OCR
   */
  async handleClassifyBatch(req, res, next) {
    try {
      const idaccount = req.user?.idaccount || req.user?.userId;
      if (!idaccount) {
        return res.status(401).json({ success: false, message: 'Chua xac thuc nguoi dung' });
      }

      const { items, merchant, source } = req.body;
      const results = await classifyService.classifyBatch(idaccount, {
        items,
        merchant,
        source,
      });

      return res.status(200).json({
        success: true,
        data: results,
      });
    } catch (error) {
      logger.error('ClassifyController.handleClassifyBatch error', { error: error.message });
      next(error);
    }
  },

  /**
   * POST /api/ai/classify/feedback
   * Ghi nhận thói quen người dùng (Self-Learning Feedback Loop)
   */
  async handleFeedback(req, res, next) {
    try {
      const idaccount = req.user?.idaccount || req.user?.userId;
      if (!idaccount) {
        return res.status(401).json({ success: false, message: 'Chua xac thuc nguoi dung' });
      }

      const { idcategory, keyword, rawText } = req.body;
      const result = await classifyService.recordFeedback(idaccount, {
        idcategory,
        keyword,
        rawText,
      });

      return res.status(200).json({
        success: true,
        message: 'Đã cập nhật thói quen phân loại cho danh mục',
        data: result,
      });
    } catch (error) {
      logger.error('ClassifyController.handleFeedback error', { error: error.message });
      next(error);
    }
  },
};

module.exports = classifyController;
