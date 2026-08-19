const express = require('express');
const router = express.Router();
const bankController = require('../modules/bank/bank.controller');
const { authenticate } = require('../middleware/auth');

// GET /api/bank/accounts - Lấy danh sách tài khoản ngân hàng (Yêu cầu đăng nhập)
router.get('/accounts', authenticate, bankController.getAccounts);

// GET /api/bank/transactions - Lấy lịch sử giao dịch (Yêu cầu đăng nhập)
router.get('/transactions', authenticate, bankController.getTransactions);

// POST /api/bank/webhook - Nhận Webhook từ Casso (Public, xác thực bằng Secure-Token)
router.post('/webhook', bankController.handleWebhook);

module.exports = router;
