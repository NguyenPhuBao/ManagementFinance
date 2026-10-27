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
async function createPremiumOrder(idaccount, { packageType = 'Premium' } = {}) {
  const orderId = crypto.randomUUID();
  const orderCode = payosClient.generateOrderCode();
  const recognitionCode = payosClient.generateRecognitionCode();
  const amount = config.payment.premiumPriceVnd || 49000;
  const expiredAt = new Date(Date.now() + 10 * 60 * 1000); // Link hết hạn sau 10 phút

  // Gọi PayOS tạo liên kết thanh toán với description là mã nhận diện 6 ký tự
  const payosResponse = await payosClient.createPaymentLink({
    orderCode,
    amount,
    description: recognitionCode,
    expiredAt: Math.floor(expiredAt.getTime() / 1000),
  });

  const transferContent = payosResponse.description || `CS... ${recognitionCode}`;
  const bin = payosResponse.bin || '970422';
  const accountNumber = payosResponse.accountNumber || '2512070399999';
  const accountName = payosResponse.accountName || 'NGUYEN PHU BAO';
  const qrUrl = `https://img.vietqr.io/image/${bin}-${accountNumber}-compact2.png?amount=${amount}&addInfo=${encodeURIComponent(transferContent)}&accountName=${encodeURIComponent(accountName)}`;

  // Lưu bản ghi đơn hàng trạng thái PENDING với mã nhận diện 6 ký tự và qr_url bền vững
  const order = await paymentRepository.createOrder({
    id: orderId,
    idaccount,
    orderCode,
    packageType,
    amount,
    amountReceived: 0,
    fee: 0,
    recognitionCode,
    transferContent,
    currency: 'VND',
    status: 'PENDING',
    checkoutUrl: payosResponse.checkoutUrl,
    qrUrl,
    paymentLinkId: payosResponse.paymentLinkId,
    expiredAt,
  });

  logger.info('[PAYMENT] Đã tạo đơn hàng thành công', { orderId, orderCode, recognitionCode, idaccount, amount });

  try {
    const { getIO } = require('../../core/socket');
    const io = getIO();
    if (io) {
      io.to('admin_room').emit('payment.order_created', {
        orderId: order.id,
        orderCode: order.order_code ?? order.orderCode ?? orderCode,
        amount: order.amount ?? amount,
        status: order.status,
        packageType: order.package_type || packageType,
        isTemplate: false,
      });
    }
  } catch (socketErr) {
    logger.warn('[PAYMENT] Không thể gửi socket payment.order_created:', socketErr.message);
  }

  return {
    orderId: order.id,
    orderCode: order.order_code ?? order.orderCode ?? orderCode,
    packageType: order.package_type || packageType,
    amount: order.amount ?? amount,
    currency: order.currency || 'VND',
    recognitionCode,
    transferContent,
    checkoutUrl: order.checkout_url || payosResponse.checkoutUrl,
    qrUrl,
    qrCode: payosResponse.qrCode || null,
    bin: payosResponse.bin || null,
    accountNumber: payosResponse.accountNumber || null,
    accountName: payosResponse.accountName || null,
    description: transferContent,
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

  const { orderCode, amount, reference, transactionDateTime, description } = verifiedData || {};
  if (!orderCode) {
    logger.info('[PAYMENT_WEBHOOK] Webhook không chứa orderCode (Test ping có chữ ký từ PayOS)');
    return { success: true, message: 'Webhook ping verified successfully' };
  }

  // 2. Tra cứu đơn hàng theo orderCode hoặc theo mã nhận diện 6 ký tự
  let order = await paymentRepository.findOrderByCode(orderCode);
  if (!order && description) {
    // PayOS có thể đính kèm tiền tố CSCYDE... Token cuối cùng trong nội dung chuyển khoản là mã nhận diện đơn
    const tokens = description.trim().split(/\s+/);
    const lastToken = tokens[tokens.length - 1];
    if (lastToken && /^[A-Z0-9]{6}$/.test(lastToken)) {
      order = await paymentRepository.findOrderByRecognitionCode(lastToken);
    }
  }

  if (!order) {
    logger.warn('[PAYMENT_WEBHOOK] Đơn hàng không tồn tại trong CSDL cho orderCode từ Webhook hợp lệ', { orderCode });
    return { success: true, message: 'Đơn hàng không tồn tại trong hệ thống' };
  }

  const now = new Date();
  const txTime = transactionDateTime ? new Date(transactionDateTime) : now;
  const receivedAmount = Number(amount);
  const expectedAmount = Number(order.amount);

  // Băm SHA-256 payload webhook để lưu vết đối soát (Data_Security.md)
  const rawWebhookHash = crypto
    .createHash('sha256')
    .update(JSON.stringify(webhookPayload))
    .digest('hex');

  const txData = {
    id: crypto.randomUUID(),
    orderId: order.id,
    idaccount: order.idaccount,
    payosTransactionId: reference || String(orderCode),
    amount: receivedAmount,
    bankCode: verifiedData.counterAccountBankId || null,
    transactionTime: txTime,
    signatureVerified: true,
    rawWebhookHash,
  };

  // 3. Xử lý Idempotency - Tránh Replay Attack và chống kéo ngược trạng thái
  // Chỉ tiếp tục xử lý thanh toán nếu đơn hàng còn ở trạng thái PENDING hoặc EXPIRED
  if (!['PENDING', 'EXPIRED'].includes(order.status)) {
    logger.info('[PAYMENT_WEBHOOK] Đơn hàng đã ở trạng thái đã xử lý hoặc đang trong quy trình đối soát (Idempotent)', { orderCode, status: order.status });
    try {
      await paymentRepository.recordTransaction(txData);
    } catch (_) {}
    return { success: true, message: 'Đơn hàng đã được xử lý hoặc đang trong quy trình đối soát trước đó' };
  }

  // -------------------------------------------------------------
  // ĐƠN HÀNG MẪU THỬ NGHIỆM (is_template = true)
  // Mục đích chính: Kiểm tra đường truyền và xác nhận chuyển khoản PayOS thành công.
  // Tuyệt đối không kích hoạt gói Premium và không tính vào doanh thu kinh doanh.
  // -------------------------------------------------------------
  if (order.is_template) {
    await paymentRepository.recordTransaction(txData);
    await paymentRepository.updateOrderPaymentStatus({
      orderId: order.id,
      status: 'PAID',
      amountReceived: receivedAmount,
      paidAt: txTime,
      transferContent: description || order.transfer_content,
    });

    try {
      const { getIO } = require('../../core/socket');
      const io = getIO();
      if (io) {
        io.to('admin_room').emit('payment.success', {
          orderId: order.id,
          orderCode: Number(order.order_code || orderCode),
          amount: order.amount,
          amountReceived: receivedAmount,
          status: 'PAID',
          paidAt: txTime,
          isTemplate: true,
        });
      }
    } catch (_) {}

    logger.info('[PAYMENT_WEBHOOK] Đơn hàng mẫu đã xác nhận chuyển khoản thành công qua PayOS (không kích hoạt Premium)', {
      orderCode,
      amount: receivedAmount,
    });

    return {
      success: true,
      isTemplate: true,
      message: 'Giao dịch mẫu đã đối soát thành công qua PayOS',
    };
  }

  // -------------------------------------------------------------
  // PHÂN LUỒNG 6.1 VS 6.2 THEO ĐẶC TẢ TÀI CHÍNH
  // -------------------------------------------------------------

  // 6.2a: Chuyển THỪA TIỀN (receivedAmount > expectedAmount)
  if (receivedAmount > expectedAmount) {
    await paymentRepository.recordTransaction(txData);
    await paymentRepository.updateOrderPaymentStatus({
      orderId: order.id,
      status: 'WAITING_CONFIRMATION',
      amountReceived: receivedAmount,
      transferContent: description || order.transfer_content,
    });

    try {
      const { emitToAccount, getIO } = require('../../core/socket');
      emitToAccount(order.idaccount, 'payment.overpaid_confirmation', {
        orderId: order.id,
        orderCode: Number(order.order_code || orderCode),
        expectedAmount,
        amountReceived: receivedAmount,
        excessAmount: receivedAmount - expectedAmount,
        message: `Bạn đã chuyển thừa ${receivedAmount - expectedAmount} ₫. Vui lòng xác nhận có muốn dùng số tiền này để kích hoạt gói Premium 30 ngày hay không.`,
      });

      const io = getIO();
      if (io) {
        io.to('admin_room').emit('payment.amount_mismatch', {
          orderId: order.id,
          orderCode: Number(order.order_code || orderCode),
          expectedAmount,
          amountReceived: receivedAmount,
          diff: receivedAmount - expectedAmount,
          type: 'OVERPAID',
          status: 'WAITING_CONFIRMATION',
        });
      }
    } catch (_) {}

    return {
      success: true,
      action: 'WAITING_CONFIRMATION',
      message: 'Giao dịch chuyển thừa tiền, đang chờ người dùng xác nhận kích hoạt',
    };
  }

  // 6.2b: Chuyển THIẾU TIỀN (receivedAmount < expectedAmount)
  if (receivedAmount < expectedAmount) {
    await paymentRepository.recordTransaction(txData);
    await paymentRepository.updateOrderPaymentStatus({
      orderId: order.id,
      status: 'REFUND_PENDING',
      amountReceived: receivedAmount,
      refundReason: 'Số tiền thanh toán không hợp lệ',
      transferContent: description || order.transfer_content,
    });

    try {
      const { emitToAccount, getIO } = require('../../core/socket');
      emitToAccount(order.idaccount, 'payment.underpaid_warning', {
        orderId: order.id,
        orderCode: Number(order.order_code || orderCode),
        expectedAmount,
        amountReceived: receivedAmount,
        shortage: expectedAmount - receivedAmount,
        fee: Number(order.fee || 0),
        message: `Bạn đã chuyển thiếu ${expectedAmount - receivedAmount} ₫. Đơn hàng không đủ điều kiện kích hoạt. Số tiền sẽ được hoàn trả lại sau khi trừ phí giao dịch.`,
      });

      const io = getIO();
      if (io) {
        io.to('admin_room').emit('payment.amount_mismatch', {
          orderId: order.id,
          orderCode: Number(order.order_code || orderCode),
          expectedAmount,
          amountReceived: receivedAmount,
          diff: receivedAmount - expectedAmount,
          type: 'UNDERPAID',
          status: 'REFUND_PENDING',
        });
      }
    } catch (_) {}

    return {
      success: true,
      action: 'REFUND_PENDING',
      message: 'Giao dịch chuyển thiếu tiền, đã chuyển trạng thái chờ hoàn trả',
    };
  }

  // 6.1: Số tiền KHỚP HOÀN TOÀN (receivedAmount == expectedAmount)
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

  // Kích hoạt nâng cấp nguyên tử qua Prisma $transaction
  const activationResult = await paymentRepository.activatePremiumSubscription({
    idaccount: order.idaccount,
    orderId: order.id,
    paidAt: txTime,
    newExpiresAt,
    transactionData: txData,
  });

  // Xóa cache xác thực tài khoản để cập nhật tức thì quyền hạn
  try {
    const { invalidateAccountCache } = require('../../middleware/auth');
    invalidateAccountCache(order.idaccount);
  } catch (_) {}

  // Bắn sự kiện thời gian thực qua EventBus & Socket.IO
  try {
    const eventBus = require('../../core/event-bus');
    eventBus.publish('payment.success', {
      idaccount: order.idaccount,
      orderCode: Number(order.order_code || orderCode),
      amount: order.amount,
      premiumExpiresAt: newExpiresAt,
      title: 'Nâng cấp Premium thành công',
      message: `Chúc mừng bạn đã kích hoạt thành công gói Premium. Thời hạn sử dụng đến ngày ${newExpiresAt.toLocaleDateString('vi-VN')}.`,
    });
  } catch (_) {}

  try {
    const { emitToAccount, getIO } = require('../../core/socket');
    emitToAccount(order.idaccount, 'account.upgraded', {
      type: 'Premium',
      premiumExpiresAt: newExpiresAt,
    });
    const io = getIO();
    if (io) {
      io.to('admin_room').emit('payment.success', {
        orderId: order.id,
        orderCode: Number(order.order_code || orderCode),
        amount: order.amount,
        status: 'PAID',
        paidAt: txTime,
      });
    }
  } catch (_) {}

  logger.info('[PAYMENT_WEBHOOK] Kích hoạt Premium thành công cho tài khoản', { 
    idaccount: order.idaccount, 
    orderCode: Number(order.order_code || orderCode), 
    newExpiresAt 
  });

  return {
    success: true,
    action: 'PAID',
    message: 'Kích hoạt gói Premium thành công',
    data: activationResult,
  };
}

/**
 * Xác nhận kích hoạt gói Premium khi khách chuyển thừa tiền hoặc từ chối hoàn tiền
 * @param {number} idaccount
 * @param {object} param1 { orderCode, accept }
 */
async function confirmUpgrade(idaccount, { orderCode, accept } = {}) {
  if (typeof accept !== 'boolean') {
    const error = new Error('Trường accept bắt buộc là kiểu boolean (true/false)');
    error.statusCode = 400;
    throw error;
  }

  const order = await paymentRepository.findOrderByCode(orderCode);
  if (!order || (idaccount && order.idaccount !== idaccount)) {
    const error = new Error('Đơn hàng không tồn tại hoặc không thuộc quyền sở hữu của bạn');
    error.statusCode = 404;
    throw error;
  }

  if (order.status !== 'WAITING_CONFIRMATION') {
    const error = new Error(`Đơn hàng đang ở trạng thái ${order.status}, không thể thực hiện xác nhận`);
    error.statusCode = 400;
    throw error;
  }

  if (accept) {
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

    await paymentRepository.activatePremiumSubscription({
      idaccount: order.idaccount,
      orderId: order.id,
      paidAt: now,
      newExpiresAt,
      transactionData: {
        id: crypto.randomUUID(),
        payosTransactionId: `OVERPAID-CONFIRMED-${orderCode}`,
        amount: Number(order.amount_received || order.amount),
        bankCode: 'VIETQR',
        transactionTime: now,
        signatureVerified: true,
        rawWebhookHash: 'CONFIRMED_BY_USER',
      },
    });

    try {
      const { invalidateAccountCache } = require('../../middleware/auth');
      invalidateAccountCache(order.idaccount);
    } catch (_) {}

    try {
      const { emitToAccount, getIO } = require('../../core/socket');
      emitToAccount(order.idaccount, 'account.upgraded', {
        type: 'Premium',
        premiumExpiresAt: newExpiresAt,
      });
      const io = getIO();
      if (io) {
        io.to('admin_room').emit('payment.success', {
          orderId: order.id,
          orderCode: Number(order.order_code || orderCode),
          amount: order.amount,
          status: 'PAID',
          paidAt: now,
        });
      }
    } catch (_) {}

    return {
      success: true,
      status: 'PAID',
      message: 'Đã xác nhận và kích hoạt gói Premium thành công',
      newExpiresAt,
    };
  } else {
    await paymentRepository.updateOrderPaymentStatus({
      orderId: order.id,
      status: 'REFUND_PENDING',
      refundReason: 'Do người dùng từ chối nâng cấp gói',
    });

    try {
      const { getIO } = require('../../core/socket');
      const io = getIO();
      if (io) {
        io.to('admin_room').emit('payment.refund_pending', {
          orderId: order.id,
          orderCode: Number(order.order_code || orderCode),
          amount: order.amount_received,
          reason: 'Do người dùng từ chối nâng cấp gói',
        });
      }
    } catch (_) {}

    return {
      success: true,
      status: 'REFUND_PENDING',
      message: 'Đã từ chối kích hoạt, đơn hàng chuyển sang hàng đợi hoàn tiền',
    };
  }
}

/**
 * Xử lý hoàn trả tiền cho khách hàng (Admin)
 * @param {string} orderId
 * @param {object} param1 { refundedAmount, refundProof, refundReason }
 */
async function processOrderRefund(orderId, { refundedAmount, refundProof, refundReason, refundedAt }) {
  const refundDate = refundedAt ? new Date(refundedAt) : new Date();
  const result = await paymentRepository.processRefund({
    orderId,
    refundedAmount: Number(refundedAmount),
    refundProof,
    refundReason,
    refundedAt: refundDate,
  });

  try {
    const { emitToAccount, getIO } = require('../../core/socket');
    if (result.idaccount) {
      emitToAccount(result.idaccount, 'payment.refunded', {
        orderId,
        refundedAmount: Number(refundedAmount),
        refundedAt: result.refunded_at || new Date(),
        refundReason,
        refundProof,
      });
    }
    const io = getIO();
    if (io) {
      io.to('admin_room').emit('payment.refunded', {
        orderId,
        refundedAmount: Number(refundedAmount),
        status: 'REFUNDED',
      });
    }
  } catch (_) {}

  return {
    success: true,
    message: 'Hoàn tiền thành công',
    data: result,
  };
}

/**
 * Giả lập Webhook dành cho chế độ Sandbox Roleplay của Admin
 * @param {object} param0 { orderCode, simulateType }
 */
async function simulateWebhook({ orderCode, simulateType = 'EXACT' }) {
  const order = await paymentRepository.findOrderByCode(orderCode);
  if (!order) {
    const error = new Error('Không tìm thấy đơn hàng để giả lập');
    error.statusCode = 404;
    throw error;
  }

  let simulatedAmount = Number(order.amount);
  if (simulateType === 'OVERPAID') {
    simulatedAmount = Number(order.amount) + 21000;
  } else if (simulateType === 'UNDERPAID') {
    simulatedAmount = Math.max(1000, Number(order.amount) - 29000);
  }

  const mockPayload = {
    code: '00',
    desc: 'Success',
    data: {
      orderCode: Number(order.order_code),
      amount: simulatedAmount,
      description: order.transfer_content || `CSCYDEZ2N10 ${order.recognition_code || 'MOCK6C'}`,
      accountNumber: '2512070399999',
      reference: `SIM-REF-${Date.now()}`,
      transactionDateTime: new Date().toISOString(),
      counterAccountBankId: 'MBBANK',
    },
    signature: 'SIMULATED_HMAC_SHA256_PASS',
  };

  const origVerify = payosClient.verifyWebhookData;
  payosClient.verifyWebhookData = async () => mockPayload.data;

  try {
    return await handlePayOSWebhook(mockPayload);
  } finally {
    payosClient.verifyWebhookData = origVerify;
  }
}

/**
 * Tự động đối soát tức thì (Just-in-Time Sync) trạng thái đơn hàng PENDING với cổng PayOS
 * @param {object} order Đơn hàng cần đồng bộ
 * @returns {Promise<object>} Đơn hàng đã được đồng bộ trạng thái mới nhất
 */
async function syncOrderWithPayOS(order) {
  if (!order || order.status !== 'PENDING' || order.is_template) {
    return order;
  }

  const orderCode = order.order_code;
  if (!orderCode) {
    return order;
  }

  try {
    const payosInfo = await payosClient.getPaymentLinkInfo(orderCode);

    if (payosInfo) {
      if (payosInfo.status === 'CANCELLED') {
        logger.info('[PAYOS_JIT_SYNC] Phát hiện đơn hàng đã bị hủy trên PayOS', { orderCode, orderId: order.id });
        await paymentRepository.updateOrderSyncStatus(order.id, {
          status: 'CANCELLED',
          qr_url: null,
          checkout_url: null,
        });

        order.status = 'CANCELLED';
        order.qr_url = null;
        order.checkout_url = null;
        order.bank_info = null;

        try {
          const { emitToAccount, getIO } = require('../../core/socket');
          if (order.idaccount) {
            emitToAccount(order.idaccount, 'payment.order_cancelled', {
              orderId: order.id,
              orderCode: Number(orderCode),
              status: 'CANCELLED',
              message: 'Đơn hàng đã bị hủy trên cổng thanh toán PayOS',
            });
          }
          const io = getIO();
          if (io) {
            io.to('admin_room').emit('payment.order_cancelled', {
              orderId: order.id,
              orderCode: Number(orderCode),
              status: 'CANCELLED',
            });
          }
        } catch (_) {}

        return order;
      }

      if (payosInfo.status === 'EXPIRED') {
        logger.info('[PAYOS_JIT_SYNC] Phát hiện đơn hàng đã hết hạn trên PayOS', { orderCode, orderId: order.id });
        await paymentRepository.updateOrderSyncStatus(order.id, {
          status: 'EXPIRED',
          qr_url: null,
          checkout_url: null,
        });

        order.status = 'EXPIRED';
        order.qr_url = null;
        order.checkout_url = null;
        order.bank_info = null;

        try {
          const { emitToAccount, getIO } = require('../../core/socket');
          if (order.idaccount) {
            emitToAccount(order.idaccount, 'payment.order_expired', {
              orderId: order.id,
              orderCode: Number(orderCode),
              status: 'EXPIRED',
            });
          }
          const io = getIO();
          if (io) {
            io.to('admin_room').emit('payment.status_changed', {
              orderId: order.id,
              orderCode: Number(orderCode),
              status: 'EXPIRED',
            });
          }
        } catch (_) {}

        return order;
      }

      if (payosInfo.status === 'PAID') {
        logger.info('[PAYOS_JIT_SYNC] Phát hiện đơn hàng đã được thanh toán trên PayOS (Bù trừ Webhook)', { orderCode, orderId: order.id });
        const receivedAmount = Number(payosInfo.amountPaid || order.amount);
        const paidAt = new Date();

        const DURATION_MS = (config.payment?.packageDurationDays || 30) * 24 * 60 * 60 * 1000;
        let currentExpiry = null;
        let accountObj = order.account;
        if (!accountObj && order.idaccount) {
          accountObj = await paymentRepository.findAccountSubscription(order.idaccount);
        }
        if (accountObj && accountObj.type === 'Premium' && accountObj.premium_expires_at) {
          const expDate = new Date(accountObj.premium_expires_at);
          if (expDate > paidAt) {
            currentExpiry = expDate;
          }
        }
        const newExpiresAt = currentExpiry 
          ? new Date(currentExpiry.getTime() + DURATION_MS) 
          : new Date(paidAt.getTime() + DURATION_MS);

        const latestTx = Array.isArray(payosInfo.transactions) && payosInfo.transactions.length > 0 
          ? payosInfo.transactions[payosInfo.transactions.length - 1] 
          : null;
        
        const txData = {
          id: crypto.randomUUID(),
          amount: receivedAmount,
          payosTransactionId: latestTx?.reference || latestTx?.transactionId || `JIT_${order.id}_${Date.now()}`,
          bankCode: latestTx?.counterAccountBankName || 'PAYOS_JIT',
          transactionTime: latestTx?.transactionDateTime ? new Date(latestTx.transactionDateTime) : paidAt,
          signatureVerified: true,
          rawWebhookHash: 'JIT_SYNC_DIRECT_API',
        };

        await paymentRepository.activatePremiumSubscription({
          idaccount: order.idaccount,
          orderId: order.id,
          paidAt,
          newExpiresAt,
          transactionData: txData,
        });

        order.status = 'PAID';
        order.qr_url = null;
        order.checkout_url = null;
        order.bank_info = null;
        order.paid_at = paidAt;

        try {
          const { emitToAccount, getIO } = require('../../core/socket');
          if (order.idaccount) {
            emitToAccount(order.idaccount, 'payment.success', {
              orderId: order.id,
              orderCode: Number(orderCode),
              status: 'PAID',
            });
            emitToAccount(order.idaccount, 'account.upgraded', {
              type: 'Premium',
              premiumExpiresAt: newExpiresAt,
            });
          }
          const io = getIO();
          if (io) {
            io.to('admin_room').emit('payment.order_paid', {
              orderId: order.id,
              orderCode: Number(orderCode),
              status: 'PAID',
            });
          }
        } catch (_) {}

        return order;
      }
    }
  } catch (err) {
    logger.warn('[PAYOS_JIT_SYNC] Bỏ qua lỗi tạm thời khi gọi PayOS JIT sync (Graceful degradation)', {
      orderCode,
      error: err.message,
    });
  }

  // Nếu đã quá thời gian hết hạn cục bộ thì cập nhật sang EXPIRED
  if (order.expired_at && new Date(order.expired_at) <= new Date()) {
    await paymentRepository.updateOrderSyncStatus(order.id, {
      status: 'EXPIRED',
      qr_url: null,
      checkout_url: null,
    });
    order.status = 'EXPIRED';
    order.qr_url = null;
    order.checkout_url = null;
    order.bank_info = null;
  }

  return order;
}

/**
 * Lấy trạng thái đơn hàng (kiểm tra phân quyền sở hữu)
 * @param {number|string} orderCode 
 * @param {number} idaccount 
 */
async function getOrderStatus(orderCode, idaccount) {
  let order = await paymentRepository.findOrderByCode(orderCode);
  if (!order || order.idaccount !== idaccount) {
    const error = new Error('Đơn hàng không tồn tại hoặc không thuộc quyền sở hữu của bạn');
    error.statusCode = 404;
    throw error;
  }
  if (order.status === 'PENDING') {
    order = await syncOrderWithPayOS(order);
  }
  return {
    orderId: order.id,
    orderCode: order.order_code,
    status: order.status,
    amount: order.amount,
    amountReceived: order.amount_received,
    recognitionCode: order.recognition_code,
    transferContent: order.transfer_content,
    packageType: order.package_type,
    paidAt: order.paid_at,
    expiredAt: order.expired_at,
    qrUrl: order.qr_url,
    checkoutUrl: order.checkout_url,
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
  const { limits, features, scopes, policies } = await permissionRepository.getPermissionsByAccountType(effectiveType);

  return {
    accountType: account.type,
    premiumExpiresAt: account.premium_expires_at,
    daysRemaining,
    isExpired,
    limits,
    features,
    scopes: scopes || {},
    policies: policies || {},
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

/**
 * Lấy danh sách đơn hàng cho Admin kèm bộ lọc và phân trang
 * @param {object} options
 */
async function getOrdersForAdmin(options) {
  return paymentRepository.findOrdersForAdmin(options);
}

/**
 * Lấy thống kê tổng quan thanh toán cho Admin
 * @param {object} options
 */
async function getPaymentStatsForAdmin(options) {
  return paymentRepository.getPaymentSummaryStats(options);
}

/**
 * Lấy chi tiết đơn hàng và lịch sử đối soát giao dịch cho Admin
 * @param {string} orderId
 */
async function getOrderDetailForAdmin(orderId) {
  let order = await paymentRepository.getOrderDetailForAdmin(orderId);
  if (!order) {
    const error = new Error('Không tìm thấy đơn hàng');
    error.statusCode = 404;
    throw error;
  }
  if (order.status === 'PENDING') {
    order = await syncOrderWithPayOS(order);
  }
  return order;
}

/**
 * Tạo đơn hàng mẫu thử nghiệm
 * @param {object} options
 */
async function createSampleOrder(options) {
  const result = await paymentRepository.createSampleOrder(options);
  try {
    const { getIO } = require('../../core/socket');
    const io = getIO();
    if (io) {
      io.to('admin_room').emit('payment.order_created', {
        orderId: result.id,
        orderCode: result.order_code,
        amount: result.amount,
        status: result.status,
        packageType: result.package_type,
        isTemplate: true,
      });
    }
  } catch (socketErr) {
    logger.warn('[PAYMENT] Không thể gửi socket payment.order_created:', socketErr.message);
  }
  return result;
}

/**
 * Xóa các đơn hàng mẫu thử nghiệm
 */
async function deleteSampleOrders() {
  return paymentRepository.deleteSampleOrders();
}

/**
 * Lấy danh mục các gói cước từ CSDL
 */
async function getPackageTypes() {
  return paymentRepository.getPackageTypes();
}

/**
 * Lấy hoặc sinh mã QR từ kênh thanh toán PayOS
 */
async function getOrCreatePayosQr(options) {
  return paymentRepository.getOrCreatePayosQr(options);
}

let _expiryInterval = null;

/**
 * Khởi động tác vụ định kỳ quét đơn hàng hết hạn (30 giây / lần)
 * Tự động chuyển PENDING sang EXPIRED, xóa QR và checkout URL, đồng thời phát socket realtime
 */
function initPaymentAutoExpiryJob() {
  if (_expiryInterval) return _expiryInterval;
  _expiryInterval = setInterval(async () => {
    try {
      const count = await paymentRepository.autoExpirePendingOrders();
      if (count > 0) {
        logger.info(`[PAYMENT_CRON] Đã tự động chuyển ${count} đơn hàng quá hạn sang EXPIRED và xóa mã QR`);
        try {
          const { getIO } = require('../../core/socket');
          const io = getIO();
          if (io) {
            io.to('admin_room').emit('payment.order_expired', { count });
          }
        } catch (_) {}
      }
    } catch (err) {
      // Bỏ qua lỗi ngầm để tránh dừng tiến trình
    }
  }, 30 * 1000);

  if (_expiryInterval.unref) _expiryInterval.unref();
  return _expiryInterval;
}

function stopPaymentAutoExpiryJob() {
  if (_expiryInterval) {
    clearInterval(_expiryInterval);
    _expiryInterval = null;
  }
}

// Tự động kích hoạt khi module được nạp
initPaymentAutoExpiryJob();

module.exports = {
  createPremiumOrder,
  handlePayOSWebhook,
  confirmUpgrade,
  processOrderRefund,
  simulateWebhook,
  getOrderStatus,
  getSubscriptionInfo,
  getOrderHistory,
  getOrdersForAdmin,
  getPaymentStatsForAdmin,
  getOrderDetailForAdmin,
  getPackageTypes,
  createSampleOrder,
  deleteSampleOrders,
  getOrCreatePayosQr,
  initPaymentAutoExpiryJob,
  stopPaymentAutoExpiryJob,
  syncOrderWithPayOS,
};


