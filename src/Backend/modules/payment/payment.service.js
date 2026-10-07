const crypto = require('crypto');
const config = require('../../config');
const logger = require('../../core/logger');
const paymentRepository = require('./payment.repository');
const permissionRepository = require('./permission.repository');
const payosClient = require('./payos.client');

/**
 * Tạo đơn hàng nâng cấp Premium và lấy link thanh toán VietQR từ PayOS
 * @param {number} idaccount 
 * @param {object} param1 
 */
async function createPremiumOrder(idaccount, { packageType = 'PREMIUM_1_MONTH' } = {}) {
  const orderId = crypto.randomUUID();
  const orderCode = payosClient.generateOrderCode();
  const amount = config.payment.premiumPriceVnd || 49000;
  const expiredAt = new Date(Date.now() + 30 * 60 * 1000); // Link hết hạn sau 30 phút

  // Gọi PayOS tạo liên kết thanh toán
  const payosResponse = await payosClient.createPaymentLink({
    orderCode,
    amount,
    description: `PFM Premium 1 Thang`.slice(0, 25),
  });

  // Lưu bản ghi đơn hàng trạng thái PENDING
  const order = await paymentRepository.createOrder({
    id: orderId,
    idaccount,
    orderCode,
    packageType,
    amount,
    currency: 'VND',
    status: 'PENDING',
    checkoutUrl: payosResponse.checkoutUrl,
    paymentLinkId: payosResponse.paymentLinkId,
    expiredAt,
  });

  logger.info('[PAYMENT] Đã tạo đơn hàng thành công', { orderId, orderCode, idaccount, amount });

  return {
    orderId: order.id,
    orderCode: order.order_code ?? order.orderCode ?? orderCode,
    packageType: order.package_type || packageType,
    amount: order.amount ?? amount,
    currency: order.currency || 'VND',
    checkoutUrl: order.checkout_url || payosResponse.checkoutUrl,
    qrCode: payosResponse.qrCode || null,
    bin: payosResponse.bin || null,
    accountNumber: payosResponse.accountNumber || null,
    accountName: payosResponse.accountName || null,
    description: payosResponse.description || null,
    expiredAt: order.expired_at || expiredAt,
  };
}

/**
 * Xử lý dữ liệu Webhook từ cổng thanh toán PayOS
 * @param {object} webhookPayload 
 */
async function handlePayOSWebhook(webhookPayload) {
  // Xử lý request test ping xác nhận Webhook URL từ PayOS
  if (!webhookPayload?.signature && (webhookPayload?.webhookUrl || webhookPayload?.desc?.toLowerCase()?.includes('test') || !webhookPayload?.data)) {
    logger.info('[PAYMENT_WEBHOOK] Nhận yêu cầu kiểm tra/xác nhận Webhook URL từ PayOS', { webhookPayload });
    return { success: true, message: 'Webhook URL verified successfully' };
  }

  // 1. Thẩm tra chữ ký số HMAC-SHA256
  let verifiedData;
  try {
    verifiedData = await payosClient.verifyWebhookData(webhookPayload);
  } catch (err) {
    logger.warn('[PAYMENT_WEBHOOK] Chữ ký không hợp lệ từ PayOS', { error: err.message });
    const error = new Error('Chữ ký Webhook không hợp lệ!');
    error.statusCode = 400;
    throw error;
  }

  const { orderCode, amount, reference, transactionDateTime } = verifiedData || {};
  if (!orderCode) {
    logger.info('[PAYMENT_WEBHOOK] Webhook không chứa orderCode (Test ping có chữ ký từ PayOS)');
    return { success: true, message: 'Webhook ping verified successfully' };
  }

  // 2. Tra cứu đơn hàng theo orderCode
  const order = await paymentRepository.findOrderByCode(orderCode);
  if (!order) {
    logger.warn('[PAYMENT_WEBHOOK] Không tìm thấy đơn hàng cho orderCode', { orderCode });
    return { success: true, message: 'Đơn hàng không tồn tại' };
  }

  // 3. Xử lý Idempotency - Tránh Replay Attack
  if (order.status === 'PAID') {
    logger.info('[PAYMENT_WEBHOOK] Đơn hàng đã được xử lý trước đó (Idempotent)', { orderCode });
    return { success: true, message: 'Đơn hàng đã được xử lý thành công trước đó' };
  }

  // 4. So khớp số tiền thanh toán thực tế với đơn hàng
  if (Number(amount) < Number(order.amount)) {
    logger.error('[PAYMENT_WEBHOOK] Số tiền thanh toán không khớp với đơn hàng', { 
      orderCode, 
      receivedAmount: amount, 
      expectedAmount: order.amount 
    });
    return { success: false, message: 'Số tiền thanh toán không khớp' };
  }

  // 5. Tính toán ngày hết hạn gói Premium (Hỗ trợ Stacking cộng dồn 30 ngày)
  const now = new Date();
  const DURATION_MS = (config.payment.packageDurationDays || 30) * 24 * 60 * 60 * 1000;

  let currentExpiry = null;
  if (order.account && order.account.type === 'Premium' && order.account.premium_expires_at) {
    const expDate = new Date(order.account.premium_expires_at);
    if (expDate > now) {
      currentExpiry = expDate;
    }
  }

  const newExpiresAt = currentExpiry 
    ? new Date(currentExpiry.getTime() + DURATION_MS) 
    : new Date(now.getTime() + DURATION_MS);

  // Băm SHA-256 payload webhook để lưu vết đối soát (Data_Security.md)
  const rawWebhookHash = crypto
    .createHash('sha256')
    .update(JSON.stringify(webhookPayload))
    .digest('hex');

  // 6. Thực thi kích hoạt nâng cấp nguyên tử qua Prisma $transaction
  const activationResult = await paymentRepository.activatePremiumSubscription({
    idaccount: order.idaccount,
    orderId: order.id,
    paidAt: transactionDateTime ? new Date(transactionDateTime) : now,
    newExpiresAt,
    transactionData: {
      id: crypto.randomUUID(),
      payosTransactionId: reference || String(orderCode),
      amount,
      bankCode: verifiedData.counterAccountBankId || null,
      transactionTime: transactionDateTime ? new Date(transactionDateTime) : now,
      signatureVerified: true,
      rawWebhookHash,
    },
  });

  // 7. Xóa cache xác thực tài khoản để cập nhật tức thì quyền hạn
  try {
    const { invalidateAccountCache } = require('../../middleware/auth');
    invalidateAccountCache(order.idaccount);
  } catch (_) {}

  // 8. Bắn sự kiện thời gian thực qua EventBus & Socket.IO
  try {
    const eventBus = require('../../core/event-bus');
    eventBus.publish('payment.success', {
      idaccount: order.idaccount,
      orderCode: order.order_code,
      amount: order.amount,
      premiumExpiresAt: newExpiresAt,
      title: 'Nâng cấp Premium thành công',
      message: `Chúc mừng bạn đã kích hoạt thành công gói Premium. Thời hạn sử dụng đến ngày ${newExpiresAt.toLocaleDateString('vi-VN')}.`,
    });
  } catch (_) {}

  try {
    const { emitToAccount } = require('../../core/socket');
    emitToAccount(order.idaccount, 'account.upgraded', {
      type: 'Premium',
      premiumExpiresAt: newExpiresAt,
    });
  } catch (_) {}

  logger.info('[PAYMENT_WEBHOOK] Kích hoạt Premium thành công cho tài khoản', { 
    idaccount: order.idaccount, 
    orderCode, 
    newExpiresAt 
  });

  return {
    success: true,
    message: 'Kích hoạt gói Premium thành công',
    data: activationResult,
  };
}

/**
 * Lấy trạng thái đơn hàng (kiểm tra phân quyền sở hữu)
 * @param {number|string} orderCode 
 * @param {number} idaccount 
 */
async function getOrderStatus(orderCode, idaccount) {
  const order = await paymentRepository.findOrderByCode(orderCode);
  if (!order || order.idaccount !== idaccount) {
    const error = new Error('Đơn hàng không tồn tại hoặc không thuộc quyền sở hữu của bạn');
    error.statusCode = 404;
    throw error;
  }
  return {
    orderId: order.id,
    orderCode: order.order_code,
    status: order.status,
    amount: order.amount,
    packageType: order.package_type,
    paidAt: order.paid_at,
    expiredAt: order.expired_at,
  };
}

/**
 * Lấy thông tin trạng thái gói cước hiện tại của người dùng
 * @param {number} idaccount 
 */
async function getSubscriptionInfo(idaccount) {
  const account = await paymentRepository.findAccountSubscription(idaccount);
  if (!account) {
    const error = new Error('Tài khoản không tồn tại');
    error.statusCode = 404;
    throw error;
  }

  const now = new Date();
  const isPremium = account.type === 'Premium';
  const hasExpiry = Boolean(account.premium_expires_at);
  const expiryDate = hasExpiry ? new Date(account.premium_expires_at) : null;
  const isExpired = !isPremium || !hasExpiry || expiryDate <= now;

  let daysRemaining = 0;
  if (!isExpired && expiryDate) {
    const diffMs = expiryDate.getTime() - now.getTime();
    daysRemaining = Math.max(0, Math.ceil(diffMs / (24 * 60 * 60 * 1000)));
  }

  const effectiveType = (!isExpired && isPremium) ? 'Premium' : 'Basic';
  const { limits, features } = await permissionRepository.getPermissionsByAccountType(effectiveType);

  return {
    accountType: account.type,
    premiumExpiresAt: account.premium_expires_at,
    daysRemaining,
    isExpired,
    limits,
    features,
    price: config.payment.premiumPriceVnd || 49000,
    packageDays: config.payment.packageDurationDays || 30,
  };
}

/**
 * Lấy lịch sử đơn hàng của người dùng có phân trang
 * @param {number} idaccount 
 * @param {object} options 
 */
async function getOrderHistory(idaccount, options) {
  return paymentRepository.findOrdersByAccount(idaccount, options);
}

module.exports = {
  createPremiumOrder,
  handlePayOSWebhook,
  getOrderStatus,
  getSubscriptionInfo,
  getOrderHistory,
};
