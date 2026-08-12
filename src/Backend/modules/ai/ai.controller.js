/**
 * AI Module — Shared Controller
 * Router chung, phân phối request đến feature controller tương ứng.
 *
 * POST /api/ai/classify  → features/classify/classify.controller.js
 * POST /api/ai/ocr       → features/ocr/ocr.controller.js (future)
 * GET  /api/ai/advice    → features/advice/advice.controller.js (future)
 * GET  /api/ai/budget    → features/budget/budget.controller.js (future)
 * POST /api/ai/chatbot   → features/chatbot/chatbot.controller.js (future)
 */

const classifyController = require('./features/classify/classify.controller');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const aiController = {
  // POST /api/ai/classify
  async classify(req, res) {
    try {
      const { transactionId } = req.body;
      const result = await classifyController.handleClassify(transactionId);
      return ResponseHandler.success(res, result, 'Yeu cau phan loai da duoc tiep nhan', 202);
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('AI classify failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },
};

module.exports = aiController;
