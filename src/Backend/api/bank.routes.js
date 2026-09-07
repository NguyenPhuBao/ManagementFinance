const express = require('express');
const router = express.Router();
const bankController = require('../modules/bank/bank.controller');
const { authenticate } = require('../middleware/auth');

// POST /api/bank/register-account - Người dùng tự khai báo/đăng ký tài khoản ngân hàng trên App
router.post('/register-account', authenticate, bankController.registerAccount);

// POST /api/bank/link-url - Sinh link nhúng Hosted Link (In-App WebView) liên kết ngân hàng
router.post('/link-url', authenticate, bankController.createLinkUrl);

// GET /api/bank/accounts - Lấy danh sách tài khoản ngân hàng (Yêu cầu đăng nhập)
router.get('/accounts', authenticate, bankController.getAccounts);

// GET /api/bank/transactions - Lấy lịch sử giao dịch (Yêu cầu đăng nhập)
router.get('/transactions', authenticate, bankController.getTransactions);

// GET /api/bank/pending-transactions - Lấy danh sách giao dịch ngân hàng đang chờ duyệt
router.get('/pending-transactions', authenticate, bankController.getPendingTransactions);

// POST /api/bank/confirm-transaction - Xác nhận duyệt giao dịch và gán danh mục
router.post('/confirm-transaction', authenticate, bankController.confirmTransaction);

// POST /api/bank/reject-transaction - Từ chối giao dịch ngân hàng
router.post('/reject-transaction', authenticate, bankController.rejectTransaction);

// POST /api/bank/webhook - Nhận Webhook IPN từ SePay Bank Hub (Xác thực bằng ApiKey)
router.post('/webhook', bankController.handleWebhook);

module.exports = router;
