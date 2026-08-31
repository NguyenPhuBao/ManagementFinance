const bankService = require('./bank.service');
const cassoWebhook = require('./casso/casso.webhook');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const bankController = {
  /**
   * GET /api/bank/accounts
   */
  async getAccounts(req, res, next) {
    try {
      const idaccount = req.user.idaccount;
      const accounts = await bankService.getAccounts(idaccount);
      return ResponseHandler.success(res, accounts, 'Lấy danh sách tài khoản ngân hàng thành công');
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
      return ResponseHandler.success(res, transactions, 'Lấy lịch sử giao dịch thành công');
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/bank/pending-transactions
   * Lấy danh sách giao dịch ngân hàng đang chờ duyệt
   */
  async getPendingTransactions(req, res, next) {
    try {
      const idaccount = req.user.idaccount;
      const pendingTxs = await bankService.getPendingTransactions(idaccount);
      return ResponseHandler.success(res, pendingTxs, 'Lấy danh sách giao dịch chờ duyệt thành công');
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/bank/confirm-transaction
   * Xác nhận duyệt giao dịch và gán danh mục
   */
  async confirmTransaction(req, res, next) {
    try {
      const idaccount = req.user.idaccount;
      const { idtran, idcategory, note } = req.body;
      const confirmed = await bankService.confirmTransaction(idaccount, { idtran, idcategory, note });
      return ResponseHandler.success(res, confirmed, 'Xác nhận duyệt giao dịch thành công');
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/bank/reject-transaction
   * Từ chối giao dịch ngân hàng
   */
  async rejectTransaction(req, res, next) {
    try {
      const idaccount = req.user.idaccount;
      const { idtran } = req.body;
      const rejected = await bankService.rejectTransaction(idaccount, idtran);
      return ResponseHandler.success(res, rejected, 'Từ chối giao dịch thành công');
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
          message: 'Invalid Secure-Token',
        });
      }

      // 2. Lấy payload
      const payload = req.body;
      
      // 3. Đưa vào hàng đợi
      await bankService.enqueueWebhookJob(payload);

      // 4. Trả về ngay lập tức để webhook không bị timeout
      return res.status(200).json({
        error: 0,
        message: 'ok',
      });
    } catch (error) {
      logger.error('Webhook processing error:', { error: error.message, stack: error.stack });
      // Trả 200 kèm error code để Casso không retry spam vô hạn làm nghẽn hệ thống khi có sự cố nội bộ
      return res.status(200).json({
        error: 1,
        message: 'Webhook received but internal processing encountered an error',
      });
    }
  },
};

module.exports = bankController;
