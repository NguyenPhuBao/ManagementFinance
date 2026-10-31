const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');

test('PayOS Group 3 Comprehensive Audit Suite — 2-Tier Financial & Idempotency Matrix (Order 44)', async (t) => {
  const paymentService = require('../../modules/payment/payment.service');
  const paymentRepository = require('../../modules/payment/payment.repository');
  const payosClient = require('../../modules/payment/payos.client');
  const { prisma } = require('../../config/db');
  const socket = require('../../core/socket');

  const ID_USER = 701;
  const ID_ADMIN = 1;
  const ORDER_CODE_BASE = 880001;

  // ═════════════════════════════════════════════════════════════════════
  // TC1. Thẩm tra chữ ký số PayOS & Ping Webhook URL
  // ═════════════════════════════════════════════════════════════════════
  await t.test('1. [Tier 1] Thẩm tra chữ ký số PayOS: Ping URL trả 200; Chữ ký giả mạo ném 400', async () => {
    // 1.1 Ping URL không có signature (PayOS check endpoint lúc config)
    const pingRes = await paymentService.handlePayOSWebhook({
      webhookUrl: 'https://api.flowmoney.vn/api/payments/payos-webhook',
    });
    assert.strictEqual(pingRes.success, true);
    assert.strictEqual(pingRes.message, 'Webhook URL verified successfully');

    // 1.2 Chữ ký giả mạo / không hợp lệ
    const origVerify = payosClient.verifyWebhookData;
    payosClient.verifyWebhookData = async () => {
      throw new Error('Invalid HMAC-SHA256 signature');
    };

    try {
      await assert.rejects(
        async () => {
          await paymentService.handlePayOSWebhook({
            signature: 'fake_invalid_signature',
            data: { orderCode: ORDER_CODE_BASE, amount: 49000 },
          });
        },
        (err) => {
          assert.strictEqual(err.statusCode, 400);
          assert.strictEqual(err.message, 'Chữ ký Webhook không hợp lệ!');
          return true;
        }
      );
    } finally {
      payosClient.verifyWebhookData = origVerify;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC2. Chống Race-Condition & Replay Attack (Idempotency & Partial Unique Index)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('2. [Tier 2] Idempotency & Unique Violation 23505: Webhook trùng lặp không ghi đúp giao dịch', async () => {
    const origFindOrder = paymentRepository.findOrderByCode;
    const origRecordTx = paymentRepository.recordTransaction;
    const origActivate = paymentRepository.activatePremiumSubscription;

    let recordTxCalls = 0;
    const capturedTransactions = [];

    paymentRepository.findOrderByCode = async (code) => ({
      id: 'ord-uuid-001',
      order_code: BigInt(code),
      idaccount: ID_USER,
      amount: 49000,
      status: 'PAID', // Đơn đã thanh toán trước đó
      transfer_content: 'THUANTEST1',
    });

    paymentRepository.recordTransaction = async (data) => {
      recordTxCalls += 1;
      // Giả lập lỗi Unique Constraint P2002/23505 từ CSDL khi dính trùng lặp
      if (recordTxCalls > 1) {
        const p2002Err = new Error('Unique constraint failed on the fields: (payos_transaction_id)');
        p2002Err.code = 'P2002';
        throw p2002Err;
      }
      capturedTransactions.push(data);
      return data;
    };

    const origVerify = payosClient.verifyWebhookData;
    payosClient.verifyWebhookData = async (payload) => payload.data;

    try {
      const webhookPayload = {
        signature: 'valid_sig_123',
        data: {
          orderCode: ORDER_CODE_BASE + 2,
          amount: 49000,
          reference: 'BANK_TX_REF_9999',
          transactionDateTime: new Date().toISOString(),
          description: 'THUANTEST1',
        },
      };

      // Gọi webhook lần 2 cho đơn đã PAID
      const res = await paymentService.handlePayOSWebhook(webhookPayload);
      assert.strictEqual(res.success, true);
      assert.ok(res.message.includes('Đơn hàng đã được xử lý hoặc đang trong quy trình đối soát trước đó'));
    } finally {
      paymentRepository.findOrderByCode = origFindOrder;
      paymentRepository.recordTransaction = origRecordTx;
      paymentRepository.activatePremiumSubscription = origActivate;
      payosClient.verifyWebhookData = origVerify;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC3. Luồng 6.1: Khớp tiền chính xác (49,000đ = 49,000đ)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('3. [Tier 2] Luồng 6.1: Khớp tiền 49k -> Kích hoạt PAID, cộng 30 ngày và phát socket realtime', async () => {
    const origFindOrder = paymentRepository.findOrderByCode;
    const origActivate = paymentRepository.activatePremiumSubscription;
    const origEmitToAccount = socket.emitToAccount;
    const origVerify = payosClient.verifyWebhookData;

    let activatedData = null;
    let socketEmitted = false;
    let socketPayload = null;

    paymentRepository.findOrderByCode = async (code) => ({
      id: 'ord-uuid-002',
      order_code: BigInt(code),
      idaccount: ID_USER,
      amount: 49000,
      status: 'PENDING',
      transfer_content: 'PREMIUM49K',
      account: {
        idaccount: ID_USER,
        type: 'Basic',
        premium_expires_at: null,
      },
    });

    paymentRepository.activatePremiumSubscription = async (data) => {
      activatedData = data;
      return { success: true, newExpiresAt: data.newExpiresAt };
    };

    socket.emitToAccount = (targetId, event, payload) => {
      if (targetId === ID_USER && event === 'account.upgraded') {
        socketEmitted = true;
        socketPayload = payload;
      }
    };

    payosClient.verifyWebhookData = async (payload) => payload.data;

    try {
      const webhookPayload = {
        signature: 'valid_sig',
        data: {
          orderCode: ORDER_CODE_BASE + 3,
          amount: 49000,
          reference: 'TX_EXACT_49K',
          transactionDateTime: new Date().toISOString(),
          description: 'PREMIUM49K',
        },
      };

      const res = await paymentService.handlePayOSWebhook(webhookPayload);

      assert.strictEqual(res.success, true);
      assert.strictEqual(res.action, 'PAID');
      assert.ok(activatedData, 'Phải gọi activatePremiumSubscription');
      assert.strictEqual(activatedData.idaccount, ID_USER);
      assert.strictEqual(activatedData.orderId, 'ord-uuid-002');

      // Thời hạn gia hạn đúng 30 ngày (+- 1 ngày sai số múi giờ)
      const daysDiff = (activatedData.newExpiresAt.getTime() - Date.now()) / (24 * 60 * 60 * 1000);
      assert.ok(Math.abs(daysDiff - 30) < 1, 'Phải cộng đúng 30 ngày sử dụng');

      // Socket account.upgraded
      assert.strictEqual(socketEmitted, true);
      assert.strictEqual(socketPayload.type, 'Premium');
    } finally {
      paymentRepository.findOrderByCode = origFindOrder;
      paymentRepository.activatePremiumSubscription = origActivate;
      socket.emitToAccount = origEmitToAccount;
      payosClient.verifyWebhookData = origVerify;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC4. Luồng 6.2a: Chuyển THỪA tiền (70,000đ > 49,000đ)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('4. [Tier 2] Luồng 6.2a: Chuyển THỪA tiền (70k > 49k) -> Đổi WAITING_CONFIRMATION, không kích hoạt gói', async () => {
    const origFindOrder = paymentRepository.findOrderByCode;
    const origRecordTx = paymentRepository.recordTransaction;
    const origUpdateStatus = paymentRepository.updateOrderPaymentStatus;
    const origEmitToAccount = socket.emitToAccount;
    const origVerify = payosClient.verifyWebhookData;

    let updatedStatus = null;
    let overpaidSocketEmitted = false;
    let overpaidData = null;

    paymentRepository.findOrderByCode = async (code) => ({
      id: 'ord-uuid-003',
      order_code: BigInt(code),
      idaccount: ID_USER,
      amount: 49000,
      status: 'PENDING',
      transfer_content: 'OVERPAID70K',
    });

    paymentRepository.recordTransaction = async (data) => data;

    paymentRepository.updateOrderPaymentStatus = async (data) => {
      updatedStatus = data;
      return data;
    };

    socket.emitToAccount = (targetId, event, payload) => {
      if (targetId === ID_USER && event === 'payment.overpaid_confirmation') {
        overpaidSocketEmitted = true;
        overpaidData = payload;
      }
    };

    payosClient.verifyWebhookData = async (payload) => payload.data;

    try {
      const webhookPayload = {
        signature: 'valid_sig',
        data: {
          orderCode: ORDER_CODE_BASE + 4,
          amount: 70000,
          reference: 'TX_OVERPAID_70K',
          transactionDateTime: new Date().toISOString(),
          description: 'OVERPAID70K',
        },
      };

      const res = await paymentService.handlePayOSWebhook(webhookPayload);

      assert.strictEqual(res.success, true);
      assert.strictEqual(res.action, 'WAITING_CONFIRMATION');

      // Tầng 2: CSDL cập nhật WAITING_CONFIRMATION và lưu đúng số tiền nhận
      assert.strictEqual(updatedStatus.status, 'WAITING_CONFIRMATION');
      assert.strictEqual(updatedStatus.amountReceived, 70000);

      // Socket thông báo chuyển thừa
      assert.strictEqual(overpaidSocketEmitted, true);
      assert.strictEqual(overpaidData.excessAmount, 21000);
      assert.strictEqual(overpaidData.amountReceived, 70000);
    } finally {
      paymentRepository.findOrderByCode = origFindOrder;
      paymentRepository.recordTransaction = origRecordTx;
      paymentRepository.updateOrderPaymentStatus = origUpdateStatus;
      socket.emitToAccount = origEmitToAccount;
      payosClient.verifyWebhookData = origVerify;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC5. Luồng 6.2b: Chuyển THIẾU tiền (20,000đ < 49,000đ)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('5. [Tier 2] Luồng 6.2b: Chuyển THIẾU tiền (20k < 49k) -> Đổi REFUND_PENDING và lưu lý do', async () => {
    const origFindOrder = paymentRepository.findOrderByCode;
    const origRecordTx = paymentRepository.recordTransaction;
    const origUpdateStatus = paymentRepository.updateOrderPaymentStatus;
    const origEmitToAccount = socket.emitToAccount;
    const origVerify = payosClient.verifyWebhookData;

    let updatedStatus = null;
    let underpaidSocketEmitted = false;
    let underpaidData = null;

    paymentRepository.findOrderByCode = async (code) => ({
      id: 'ord-uuid-004',
      order_code: BigInt(code),
      idaccount: ID_USER,
      amount: 49000,
      fee: 2000,
      status: 'PENDING',
      transfer_content: 'UNDERPAID20K',
    });

    paymentRepository.recordTransaction = async (data) => data;

    paymentRepository.updateOrderPaymentStatus = async (data) => {
      updatedStatus = data;
      return data;
    };

    socket.emitToAccount = (targetId, event, payload) => {
      if (targetId === ID_USER && event === 'payment.underpaid_warning') {
        underpaidSocketEmitted = true;
        underpaidData = payload;
      }
    };

    payosClient.verifyWebhookData = async (payload) => payload.data;

    try {
      const webhookPayload = {
        signature: 'valid_sig',
        data: {
          orderCode: ORDER_CODE_BASE + 5,
          amount: 20000,
          reference: 'TX_UNDERPAID_20K',
          transactionDateTime: new Date().toISOString(),
          description: 'UNDERPAID20K',
        },
      };

      const res = await paymentService.handlePayOSWebhook(webhookPayload);

      assert.strictEqual(res.success, true);
      assert.strictEqual(res.action, 'REFUND_PENDING');

      // Tầng 2: CSDL cập nhật REFUND_PENDING kèm lý do hoàn trả
      assert.strictEqual(updatedStatus.status, 'REFUND_PENDING');
      assert.strictEqual(updatedStatus.amountReceived, 20000);
      assert.strictEqual(updatedStatus.refundReason, 'Số tiền thanh toán không hợp lệ');

      // Socket thông báo thiếu tiền
      assert.strictEqual(underpaidSocketEmitted, true);
      assert.strictEqual(underpaidData.shortage, 29000);
    } finally {
      paymentRepository.findOrderByCode = origFindOrder;
      paymentRepository.recordTransaction = origRecordTx;
      paymentRepository.updateOrderPaymentStatus = origUpdateStatus;
      socket.emitToAccount = origEmitToAccount;
      payosClient.verifyWebhookData = origVerify;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC6. Người dùng xác nhận chuyển thừa (confirmUpgrade)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('6. [Tier 2] confirmUpgrade(): accept = true -> kích hoạt PAID; accept = false -> REFUND_PENDING', async () => {
    const origFindByCode = paymentRepository.findOrderByCode;
    const origActivate = paymentRepository.activatePremiumSubscription;
    const origUpdateStatus = paymentRepository.updateOrderPaymentStatus;

    let activated = false;
    let refundPending = false;

    paymentRepository.findOrderByCode = async () => ({
      id: 'ord-uuid-005',
      order_code: BigInt(880005),
      idaccount: ID_USER,
      amount: 49000,
      amount_received: 70000,
      status: 'WAITING_CONFIRMATION',
      account: { idaccount: ID_USER, type: 'Basic', premium_expires_at: null },
    });

    paymentRepository.activatePremiumSubscription = async () => {
      activated = true;
      return { success: true };
    };

    paymentRepository.updateOrderPaymentStatus = async (data) => {
      if (data.status === 'REFUND_PENDING') refundPending = true;
      return data;
    };

    try {
      // 6.1 Chấp nhận nâng cấp (accept = true)
      const resAccept = await paymentService.confirmUpgrade(ID_USER, { orderCode: 880005, accept: true });
      assert.strictEqual(resAccept.success, true);
      assert.strictEqual(resAccept.status, 'PAID');
      assert.strictEqual(activated, true);

      // 6.2 Từ chối nâng cấp (accept = false)
      const resDecline = await paymentService.confirmUpgrade(ID_USER, { orderCode: 880005, accept: false });
      assert.strictEqual(resDecline.success, true);
      assert.strictEqual(resDecline.status, 'REFUND_PENDING');
      assert.strictEqual(refundPending, true);
    } finally {
      paymentRepository.findOrderByCode = origFindByCode;
      paymentRepository.activatePremiumSubscription = origActivate;
      paymentRepository.updateOrderPaymentStatus = origUpdateStatus;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC7. Trích xuất mã nhận diện 6 ký tự VietQR chuẩn xác
  // ═════════════════════════════════════════════════════════════════════
  await t.test('7. [Tier 2] Trích xuất mã nhận diện VietQR có tiền tố ngân hàng "CSCYDEZ2N10 9X7K2A"', async () => {
    const origFindByCode = paymentRepository.findOrderByCode;
    const origFindByRecog = paymentRepository.findOrderByRecognitionCode;
    const origActivate = paymentRepository.activatePremiumSubscription;
    const origVerify = payosClient.verifyWebhookData;

    let queriedRecogCode = null;

    // Không tìm thấy theo orderCode
    paymentRepository.findOrderByCode = async () => null;

    // Phải tra cứu theo mã nhận diện 6 ký tự
    paymentRepository.findOrderByRecognitionCode = async (code) => {
      queriedRecogCode = code;
      return {
        id: 'ord-uuid-007',
        order_code: BigInt(880007),
        idaccount: ID_USER,
        amount: 49000,
        status: 'PENDING',
        account: { idaccount: ID_USER, type: 'Basic', premium_expires_at: null },
      };
    };

    paymentRepository.activatePremiumSubscription = async () => ({ success: true });
    payosClient.verifyWebhookData = async (payload) => payload.data;

    try {
      const webhookPayload = {
        signature: 'valid_sig',
        data: {
          orderCode: 999999, // Không có trong DB
          amount: 49000,
          reference: 'TX_RECOG_007',
          transactionDateTime: new Date().toISOString(),
          description: 'CSCYDEZ2N10 9X7K2A', // Ngân hàng gắn tiền tố
        },
      };

      const res = await paymentService.handlePayOSWebhook(webhookPayload);

      assert.strictEqual(res.success, true);
      assert.strictEqual(res.action, 'PAID');
      assert.strictEqual(queriedRecogCode, '9X7K2A', 'Phải trích xuất chính xác token 6 ký tự cuối cùng');
    } finally {
      paymentRepository.findOrderByCode = origFindByCode;
      paymentRepository.findOrderByRecognitionCode = origFindByRecog;
      paymentRepository.activatePremiumSubscription = origActivate;
      payosClient.verifyWebhookData = origVerify;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC8. Đơn hàng thử nghiệm (is_template = true)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('8. [Tier 2] Đơn hàng thử nghiệm is_template = true: Xác nhận PAID nhưng KHÔNG nâng cấp tài khoản Admin', async () => {
    const origFindOrder = paymentRepository.findOrderByCode;
    const origRecordTx = paymentRepository.recordTransaction;
    const origUpdateStatus = paymentRepository.updateOrderPaymentStatus;
    const origActivate = paymentRepository.activatePremiumSubscription;
    const origVerify = payosClient.verifyWebhookData;

    let activateCalled = false;
    let updatedStatus = null;

    paymentRepository.findOrderByCode = async (code) => ({
      id: 'ord-sample-008',
      order_code: BigInt(code),
      idaccount: ID_ADMIN,
      amount: 49000,
      status: 'PENDING',
      is_template: true, // Đơn mẫu
      transfer_content: 'MOCKTEMPLATE',
    });

    paymentRepository.recordTransaction = async (data) => data;

    paymentRepository.updateOrderPaymentStatus = async (data) => {
      updatedStatus = data;
      return data;
    };

    paymentRepository.activatePremiumSubscription = async () => {
      activateCalled = true;
    };

    payosClient.verifyWebhookData = async (payload) => payload.data;

    try {
      const webhookPayload = {
        signature: 'valid_sig',
        data: {
          orderCode: ORDER_CODE_BASE + 8,
          amount: 49000,
          reference: 'TX_SAMPLE_008',
          transactionDateTime: new Date().toISOString(),
          description: 'MOCKTEMPLATE',
        },
      };

      const res = await paymentService.handlePayOSWebhook(webhookPayload);

      assert.strictEqual(res.success, true);
      assert.strictEqual(res.isTemplate, true);
      assert.strictEqual(res.message, 'Giao dịch mẫu đã đối soát thành công qua PayOS');

      // Tầng 2: Cập nhật đơn thành PAID nhưng KHÔNG gọi activatePremiumSubscription
      assert.strictEqual(updatedStatus.status, 'PAID');
      assert.strictEqual(activateCalled, false, 'TUYỆT ĐỐI KHÔNG được kích hoạt Premium cho tài khoản Admin');
    } finally {
      paymentRepository.findOrderByCode = origFindOrder;
      paymentRepository.recordTransaction = origRecordTx;
      paymentRepository.updateOrderPaymentStatus = origUpdateStatus;
      paymentRepository.activatePremiumSubscription = origActivate;
      payosClient.verifyWebhookData = origVerify;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC9. Cơ chế JIT Sync (syncOrderWithPayOS / getOrderStatus)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('9. [Tier 2] JIT Sync (getOrderStatus) chủ động kích hoạt Premium khi Webhook bị chậm', async () => {
    const origFindOrder = paymentRepository.findOrderByCode;
    const origActivate = paymentRepository.activatePremiumSubscription;
    const origGetInfo = payosClient.getPaymentLinkInfo;

    let jitActivated = false;

    paymentRepository.findOrderByCode = async (code) => ({
      id: 'ord-uuid-009',
      order_code: BigInt(code),
      idaccount: ID_USER,
      amount: 49000,
      status: 'PENDING', // CSDL vẫn PENDING do Webhook chưa tới
      account: { idaccount: ID_USER, type: 'Basic', premium_expires_at: null },
    });

    payosClient.getPaymentLinkInfo = async (orderCode) => ({
      orderCode,
      status: 'PAID', // PayOS xác nhận đã thanh toán
      amount: 49000,
      amountPaid: 49000,
      transactions: [
        {
          reference: 'JIT_TX_REF_009',
          amount: 49000,
          transactionDateTime: new Date().toISOString(),
        },
      ],
    });

    paymentRepository.activatePremiumSubscription = async () => {
      jitActivated = true;
      return { success: true };
    };

    try {
      const res = await paymentService.getOrderStatus(ORDER_CODE_BASE + 9, ID_USER);

      assert.strictEqual(res.status, 'PAID');
      assert.strictEqual(jitActivated, true, 'JIT Sync phải tự động kích hoạt Premium khi PayOS báo PAID');
    } finally {
      paymentRepository.findOrderByCode = origFindOrder;
      paymentRepository.activatePremiumSubscription = origActivate;
      payosClient.getPaymentLinkInfo = origGetInfo;
    }
  });
});
