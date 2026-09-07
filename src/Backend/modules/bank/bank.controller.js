/**
 * Bank Controller
 * Điều phối các endpoint của Module Bank (SePay Bank Hub)
 */

const bankService = require('./bank.service');
const sepayWebhook = require('./sepay/sepay.webhook');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const bankController = {
  /**
   * POST /api/bank/register-account
   * Người dùng tự khai báo/đăng ký tài khoản ngân hàng trên Client-app
   */
  async registerAccount(req, res, next) {
    try {
      const idaccount = req.user.idaccount;
      const { account_number, bank_name, account_name, balance } = req.body;
      const result = await bankService.registerAccount(idaccount, {
        account_number,
        bank_name,
        account_name,
        balance,
      });
      return ResponseHandler.success(res, result, 'Đăng ký tài khoản ngân hàng thành công', 201);
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/bank/link-url
   * Sinh đường dẫn Hosted Link (In-App WebView) cho người dùng cuối liên kết ngân hàng
   */
  async createLinkUrl(req, res, next) {
    try {
      const idaccount = req.user.idaccount;
      const userInfo = {
        fullname: req.user.fullname || req.user.username,
        email: req.user.email,
      };

      const result = await bankService.createLinkUrl(idaccount, userInfo);
      return ResponseHandler.success(res, result, 'Tạo liên kết ngân hàng thành công');
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/bank/accounts
   * Lấy danh sách tài khoản ngân hàng của user
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
   * Lấy lịch sử giao dịch từ ngân hàng
   */
  async getTransactions(req, res, next) {
    try {
      const { since } = req.query;
      const transactions = await bankService.getTransactions(since);
      return ResponseHandler.success(res, transactions, 'Lấy lịch sử giao dịch thành công');
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/bank/pending-transactions
   * Lấy danh sách giao dịch ngân hàng đang chờ duyệt của user
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
   * Người dùng xác nhận duyệt giao dịch và gán danh mục
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
   * Người dùng từ chối giao dịch ngân hàng
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
   * Endpoint tiếp nhận Webhook IPN từ SePay Bank Hub
   * Xác thực an toàn qua Header: Authorization: ApiKey <KEY>
   * Phản hồi ngay lập tức trong < 500ms
   */
  async handleWebhook(req, res, next) {
    try {
      // 1. Xác thực chữ ký/API Key của Webhook (Timing-Safe)
      const isValid = sepayWebhook.verifySignature(req);
      if (!isValid) {
        logger.warn('Unauthorized Webhook attempt on /api/bank/webhook', {
          ip: req.ip,
          headers: req.headers,
        });
        return res.status(401).json({
          success: false,
          error: 1,
          message: 'Invalid Webhook Authorization ApiKey',
        });
      }

      // 2. Đưa payload vào hàng đợi BullMQ để xử lý bất đồng bộ
      const payload = req.body;
      await bankService.enqueueWebhookJob(payload);

      // 3. Phản hồi HTTP 200 OK ngay lập tức
      return res.status(200).json({
        success: true,
        error: 0,
        message: 'Webhook received successfully',
      });
    } catch (error) {
      logger.error('Webhook processing error:', { error: error.message, stack: error.stack });
      // Trả 200 kèm error code để tránh retry bão hòa queue nếu lỗi nội bộ
      return res.status(200).json({
        success: false,
        error: 1,
        message: 'Webhook received but internal queueing failed',
      });
    }
  },
};

module.exports = bankController;
