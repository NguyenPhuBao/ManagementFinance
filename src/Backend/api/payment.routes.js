const express = require('express');
const { authenticate } = require('../middleware/auth');
const paymentController = require('../modules/payment/payment.controller');

const router = express.Router();

// 1. Tạo đơn hàng và lấy link thanh toán VietQR PayOS
router.post('/create-order', authenticate, paymentController.createOrder);

// 2. Tra cứu trạng thái đơn hàng (polling)
router.get('/order-status/:orderCode', authenticate, paymentController.getOrderStatus);

// 3. Lấy thông tin trạng thái gói cước người dùng hiện tại
router.get('/subscription-info', authenticate, paymentController.getSubscriptionInfo);

// 4. Lấy lịch sử giao dịch mua gói của người dùng
router.get('/history', authenticate, paymentController.getOrderHistory);

// 5. Endpoint tiếp nhận Webhook từ cổng thanh toán PayOS (Công khai, bảo vệ bằng HMAC-SHA256)
router.post('/webhook', paymentController.handleWebhook);

module.exports = router;
