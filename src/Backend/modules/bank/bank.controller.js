const bankService = require('./bank.service');
const cassoWebhook = require('./casso/casso.webhook');
const logger = require('../../core/logger');

const bankController = {
  /**
   * GET /api/bank/accounts
   */
  async getAccounts(req, res, next) {
    try {
      const idaccount = req.user.idaccount;
      const accounts = await bankService.getAccounts(idaccount);
      res.status(200).json({
        success: true,
        data: accounts
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/bank/transactions
   */
  async getTransactions(req, res, next) {
    try {
      const { since } = req.query; // YYYY-MM-DD
      const transactions = await bankService.getTransactions(since);
      res.status(200).json({
        success: true,
        data: transactions
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/bank/webhook
   * Public endpoint, chỉ verify qua Secure-Token
   */
  async handleWebhook(req, res, next) {
    try {
      // 1. Verify signature
      if (!cassoWebhook.verifySignature(req)) {
        return res.status(401).json({
          error: 1,
          message: 'Invalid Secure-Token'
        });
      }

      // 2. Lấy payload
      const payload = req.body;
      
      // 3. Đưa vào hàng đợi
      await bankService.enqueueWebhookJob(payload);

      // 4. Trả về ngay lập tức để webhook không bị timeout
      return res.status(200).json({
        error: 0,
        message: 'ok'
      });
    } catch (error) {
      logger.error('Webhook error:', error);
      // Vẫn nên trả 200 cho Casso nếu lỗi không phải do Authentication để họ khỏi gửi lại nhiều lần (tùy yêu cầu)
      // Nhưng theo chuẩn thì 500
      next(error);
    }
  }
};

module.exports = bankController;
