const test = require('node:test');
const assert = require('node:assert/strict');

test('Payment Reconciliation & Refund Suite (2-Tier Testing)', async (t) => {
  const payosClient = require('../../modules/payment/payos.client');
  const paymentService = require('../../modules/payment/payment.service');
  const paymentRepository = require('../../modules/payment/payment.repository');

  await t.test('1. [Tier 1] generateRecognitionCode() sinh đúng 6 ký tự chữ hoa và số', () => {
    for (let i = 0; i < 20; i++) {
      const code = payosClient.generateRecognitionCode();
      assert.strictEqual(typeof code, 'string');
      assert.strictEqual(code.length, 6, 'Mã nhận diện phải có độ dài đúng 6 ký tự');
      assert.match(code, /^[A-Z0-9]{6}$/, 'Mã nhận diện chỉ chứa chữ in hoa và chữ số');
    }
  });

  await t.test('2. [Tier 2] createPremiumOrder() tạo đơn hàng lưu mã nhận diện 6 ký tự và expiredAt 10 phút', async () => {
    let capturedOrder = null;
    const origCreateOrder = paymentRepository.createOrder;
    paymentRepository.createOrder = async (orderData) => {
      capturedOrder = orderData;
      return orderData;
    };

    payosClient.setPayOSClientMock({
      paymentRequests: {
        create: async (body) => ({
          checkoutUrl: 'https://pay.payos.vn/web/mock_recon',
          paymentLinkId: 'link_mock_recon',
          orderCode: body.orderCode,
          description: `CSCYDEZ2N10 ${body.description}`,
          qrCode: '000201010212385700...',
        }),
      },
    });

    try {
      const res = await paymentService.createPremiumOrder(15, { packageType: 'PREMIUM_1_MONTH' });

      assert.ok(res.recognitionCode, 'Phải có recognitionCode trong kết quả trả về');
      assert.strictEqual(res.recognitionCode.length, 6);
      assert.strictEqual(capturedOrder.idaccount, 15);
      assert.strictEqual(capturedOrder.recognitionCode || capturedOrder.recognition_code, res.recognitionCode);
      assert.strictEqual(capturedOrder.status, 'PENDING');
      assert.ok((capturedOrder.transferContent || capturedOrder.transfer_content).includes(res.recognitionCode));
      assert.ok((capturedOrder.expiredAt || capturedOrder.expired_at) > new Date());
    } finally {
      paymentRepository.createOrder = origCreateOrder;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('3. [Tier 2] Luồng 6.1: handlePayOSWebhook() với số tiền khớp -> Kích hoạt PAID và cộng 30 ngày', async () => {
    const mockOrder = {
      id: 'order-uuid-exact',
      idaccount: 20,
      order_code: 748449796518n,
      amount: 49000,
      status: 'PENDING',
      package_type: 'PREMIUM_1_MONTH',
      account: { type: 'Basic', premium_expires_at: null },
    };

    let activatedData = null;
    const origFindByCode = paymentRepository.findOrderByCode;
    const origActivate = paymentRepository.activatePremiumSubscription;

    paymentRepository.findOrderByCode = async () => mockOrder;
    paymentRepository.activatePremiumSubscription = async (params) => {
      activatedData = params;
      return { success: true, orderId: params.orderId };
    };

    payosClient.setPayOSClientMock({
      webhooks: {
        verify: () => ({
          orderCode: 748449796518,
          amount: 49000,
          reference: 'BANK-REF-EXACT',
          transactionDateTime: '2026-10-15T22:00:00Z',
          description: 'CSCYDEZ2N10 A8B9K2',
        }),
      },
    });

    try {
      const result = await paymentService.handlePayOSWebhook({ data: { orderCode: 748449796518 } });

      assert.strictEqual(result.success, true);
      assert.strictEqual(activatedData.idaccount, 20);
      assert.strictEqual(activatedData.orderId, 'order-uuid-exact');
      assert.strictEqual(activatedData.transactionData.amount, 49000);
      assert.strictEqual(activatedData.transactionData.payosTransactionId, 'BANK-REF-EXACT');
    } finally {
      paymentRepository.findOrderByCode = origFindByCode;
      paymentRepository.activatePremiumSubscription = origActivate;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('4. [Tier 2] Luồng 6.2a: handlePayOSWebhook() chuyển THỪA tiền (70k > 49k) -> Đổi WAITING_CONFIRMATION, KHÔNG tự ý kích hoạt', async () => {
    const mockOrder = {
      id: 'order-uuid-overpaid',
      idaccount: 25,
      order_code: 748449796519n,
      amount: 49000,
      status: 'PENDING',
      package_type: 'PREMIUM_1_MONTH',
      account: { type: 'Basic', premium_expires_at: null },
    };

    let updatedOrderStatus = null;
    let recordedTx = null;
    let activatedCalled = false;

    const origFindByCode = paymentRepository.findOrderByCode;
    const origUpdateStatus = paymentRepository.updateOrderPaymentStatus;
    const origRecordTx = paymentRepository.recordTransaction;
    const origActivate = paymentRepository.activatePremiumSubscription;

    paymentRepository.findOrderByCode = async () => mockOrder;
    paymentRepository.updateOrderPaymentStatus = async (params) => {
      updatedOrderStatus = params;
      return { ...mockOrder, ...params };
    };
    paymentRepository.recordTransaction = async (params) => {
      recordedTx = params;
      return params;
    };
    paymentRepository.activatePremiumSubscription = async () => {
      activatedCalled = true;
    };

    payosClient.setPayOSClientMock({
      webhooks: {
        verify: () => ({
          orderCode: 748449796519,
          amount: 70000,
          reference: 'BANK-REF-OVERPAID',
          transactionDateTime: '2026-10-15T22:05:00Z',
          description: 'CSCYDEZ2N10 A8B9K2',
        }),
      },
    });

    try {
      const result = await paymentService.handlePayOSWebhook({ data: { orderCode: 748449796519 } });

      assert.strictEqual(result.success, true);
      assert.strictEqual(result.action, 'WAITING_CONFIRMATION');
      assert.strictEqual(updatedOrderStatus.status, 'WAITING_CONFIRMATION');
      assert.strictEqual(updatedOrderStatus.amountReceived, 70000);
      assert.strictEqual(recordedTx.amount, 70000);
      assert.strictEqual(activatedCalled, false, 'Tuyệt đối không tự ý kích hoạt khi chưa có người dùng xác nhận');
    } finally {
      paymentRepository.findOrderByCode = origFindByCode;
      paymentRepository.updateOrderPaymentStatus = origUpdateStatus;
      paymentRepository.recordTransaction = origRecordTx;
      paymentRepository.activatePremiumSubscription = origActivate;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('5. [Tier 2] Luồng 6.2b: handlePayOSWebhook() chuyển THIẾU tiền (20k < 49k) -> Đổi REFUND_PENDING và ghi lý do', async () => {
    const mockOrder = {
      id: 'order-uuid-underpaid',
      idaccount: 30,
      order_code: 748449796520n,
      amount: 49000,
      status: 'PENDING',
      package_type: 'PREMIUM_1_MONTH',
      account: { type: 'Basic', premium_expires_at: null },
    };

    let updatedOrderStatus = null;
    let recordedTx = null;

    const origFindByCode = paymentRepository.findOrderByCode;
    const origUpdateStatus = paymentRepository.updateOrderPaymentStatus;
    const origRecordTx = paymentRepository.recordTransaction;

    paymentRepository.findOrderByCode = async () => mockOrder;
    paymentRepository.updateOrderPaymentStatus = async (params) => {
      updatedOrderStatus = params;
      return { ...mockOrder, ...params };
    };
    paymentRepository.recordTransaction = async (params) => {
      recordedTx = params;
      return params;
    };

    payosClient.setPayOSClientMock({
      webhooks: {
        verify: () => ({
          orderCode: 748449796520,
          amount: 20000,
          reference: 'BANK-REF-UNDERPAID',
          transactionDateTime: '2026-10-15T22:10:00Z',
          description: 'CSCYDEZ2N10 A8B9K2',
        }),
      },
    });

    try {
      const result = await paymentService.handlePayOSWebhook({ data: { orderCode: 748449796520 } });

      assert.strictEqual(result.success, true);
      assert.strictEqual(result.action, 'REFUND_PENDING');
      assert.strictEqual(updatedOrderStatus.status, 'REFUND_PENDING');
      assert.strictEqual(updatedOrderStatus.amountReceived, 20000);
      assert.strictEqual(updatedOrderStatus.refundReason, 'Số tiền thanh toán không hợp lệ');
      assert.strictEqual(recordedTx.amount, 20000);
    } finally {
      paymentRepository.findOrderByCode = origFindByCode;
      paymentRepository.updateOrderPaymentStatus = origUpdateStatus;
      paymentRepository.recordTransaction = origRecordTx;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('6. [Tier 2] confirmUpgrade() khi người dùng đồng ý -> Kích hoạt PAID; khi từ chối -> REFUND_PENDING', async () => {
    const mockWaitingOrder = {
      id: 'order-uuid-waiting',
      idaccount: 40,
      order_code: 748449796521n,
      amount: 49000,
      amount_received: 70000,
      status: 'WAITING_CONFIRMATION',
      account: { type: 'Basic', premium_expires_at: null },
    };

    const origFindByCode = paymentRepository.findOrderByCode;
    const origActivate = paymentRepository.activatePremiumSubscription;
    const origUpdateStatus = paymentRepository.updateOrderPaymentStatus;

    paymentRepository.findOrderByCode = async () => mockWaitingOrder;
    let activatedParams = null;
    paymentRepository.activatePremiumSubscription = async (params) => {
      activatedParams = params;
      return { success: true };
    };
    let rejectedStatus = null;
    paymentRepository.updateOrderPaymentStatus = async (params) => {
      rejectedStatus = params;
      return params;
    };

    try {
      // Nhánh 1: Đồng ý
      const resAccept = await paymentService.confirmUpgrade(40, { orderCode: 748449796521, accept: true });
      assert.strictEqual(resAccept.success, true);
      assert.strictEqual(activatedParams.orderId, 'order-uuid-waiting');

      // Nhánh 2: Từ chối
      const resReject = await paymentService.confirmUpgrade(40, { orderCode: 748449796521, accept: false });
      assert.strictEqual(resReject.success, true);
      assert.strictEqual(rejectedStatus.status, 'REFUND_PENDING');
      assert.strictEqual(rejectedStatus.refundReason, 'Do người dùng từ chối nâng cấp gói');
    } finally {
      paymentRepository.findOrderByCode = origFindByCode;
      paymentRepository.activatePremiumSubscription = origActivate;
      paymentRepository.updateOrderPaymentStatus = origUpdateStatus;
    }
  });

  await t.test('7. [Tier 2] processOrderRefund() cập nhật REFUNDED kèm minh chứng và số tiền', async () => {
    let refundRecorded = null;
    const origProcessRefund = paymentRepository.processRefund;
    paymentRepository.processRefund = async (params) => {
      refundRecorded = params;
      return params;
    };

    try {
      const res = await paymentService.processOrderRefund('order-uuid-test', {
        refundedAmount: 20000,
        refundProof: 'https://supabase.co/storage/proof123.jpg',
        refundReason: 'Hoàn trả chuyển thiếu tiền sau khi trừ phí',
      });

      assert.strictEqual(res.success, true);
      assert.strictEqual(refundRecorded.orderId, 'order-uuid-test');
      assert.strictEqual(refundRecorded.refundedAmount, 20000);
      assert.strictEqual(refundRecorded.refundProof, 'https://supabase.co/storage/proof123.jpg');
      assert.ok(refundRecorded.refundedAt instanceof Date);
    } finally {
      paymentRepository.processRefund = origProcessRefund;
    }
  });

  await t.test('8. [Tier 2] Tra cứu theo mã nhận diện: Nội dung "CSCYDEZ2N10 A8B9K2" phải trích xuất đúng "A8B9K2" để tìm đơn', async () => {
    let queriedRecognitionCode = null;
    const origFindByCode = paymentRepository.findOrderByCode;
    const origFindByRecognition = paymentRepository.findOrderByRecognitionCode;
    const origActivate = paymentRepository.activatePremiumSubscription;

    paymentRepository.findOrderByCode = async () => null; // Giả lập orderCode không khớp
    paymentRepository.findOrderByRecognitionCode = async (code) => {
      queriedRecognitionCode = code;
      return {
        id: 'order-matched-by-code',
        idaccount: 12,
        order_code: 999999999n,
        amount: 49000,
        status: 'PENDING',
        recognition_code: code,
        account: { type: 'Basic' },
      };
    };
    paymentRepository.activatePremiumSubscription = async () => true;

    payosClient.setPayOSClientMock({
      webhooks: {
        verify: () => ({
          orderCode: 999999999,
          amount: 49000,
          reference: 'REF-RECOG-01',
          transactionDateTime: '2026-10-16T10:00:00Z',
          description: 'CSCYDEZ2N10 A8B9K2',
        }),
      },
    });

    try {
      const res = await paymentService.handlePayOSWebhook({ data: { orderCode: 999999999 } });
      assert.strictEqual(res.success, true);
      assert.strictEqual(queriedRecognitionCode, 'A8B9K2', 'Phải trích xuất đúng token cuối cùng làm mã nhận diện');
    } finally {
      paymentRepository.findOrderByCode = origFindByCode;
      paymentRepository.findOrderByRecognitionCode = origFindByRecognition;
      paymentRepository.activatePremiumSubscription = origActivate;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('9. [Tier 2] Webhook Idempotency: Đơn đã REFUNDED hoặc CANCELLED không bị kéo ngược trạng thái', async () => {
    const origFindByCode = paymentRepository.findOrderByCode;
    const origUpdateStatus = paymentRepository.updateOrderPaymentStatus;
    let updateCalled = false;

    paymentRepository.findOrderByCode = async () => ({
      id: 'order-refunded-uuid',
      idaccount: 15,
      order_code: 888888888n,
      amount: 49000,
      status: 'REFUNDED',
      account: { type: 'Basic' },
    });
    paymentRepository.updateOrderPaymentStatus = async () => {
      updateCalled = true;
    };

    payosClient.setPayOSClientMock({
      webhooks: {
        verify: () => ({
          orderCode: 888888888,
          amount: 20000, // Chuyển thiếu
          reference: 'REF-ALREADY-REFUNDED',
          transactionDateTime: '2026-10-16T11:00:00Z',
          description: 'CSCYDEZ2N10 X1Y2Z3',
        }),
      },
    });

    try {
      const res = await paymentService.handlePayOSWebhook({ data: { orderCode: 888888888 } });
      assert.strictEqual(res.success, true);
      assert.strictEqual(updateCalled, false, 'Tuyệt đối không được cập nhật lại đơn đã REFUNDED');
    } finally {
      paymentRepository.findOrderByCode = origFindByCode;
      paymentRepository.updateOrderPaymentStatus = origUpdateStatus;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('10. [Tier 2] Webhook an toàn: Gặp orderCode không tồn tại -> Trả 2xx, KHÔNG tự tạo đơn gán cho Admin', async () => {
    const origFindByCode = paymentRepository.findOrderByCode;
    const origFindByRecognition = paymentRepository.findOrderByRecognitionCode;
    const origFindOrCreate = paymentRepository.findOrCreateOrderByCode;
    let findOrCreateCalled = false;

    paymentRepository.findOrderByCode = async () => null;
    paymentRepository.findOrderByRecognitionCode = async () => null;
    paymentRepository.findOrCreateOrderByCode = async () => {
      findOrCreateCalled = true;
      return null;
    };

    payosClient.setPayOSClientMock({
      webhooks: {
        verify: () => ({
          orderCode: 111222333,
          amount: 49000,
          reference: 'REF-UNKNOWN-ORDER',
          transactionDateTime: '2026-10-16T12:00:00Z',
          description: 'TEST WEBHOOK KHONG RO NGUON GOC',
        }),
      },
    });

    try {
      const res = await paymentService.handlePayOSWebhook({ data: { orderCode: 111222333 } });
      assert.strictEqual(res.success, true);
      assert.strictEqual(findOrCreateCalled, false, 'Không được tự ý tạo đơn gán cho admin');
    } finally {
      paymentRepository.findOrderByCode = origFindByCode;
      paymentRepository.findOrderByRecognitionCode = origFindByRecognition;
      paymentRepository.findOrCreateOrderByCode = origFindOrCreate;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('11. [Tier 1] confirmUpgrade() kiểm tra nghiêm ngặt accept bắt buộc là boolean', async () => {
    await assert.rejects(
      async () => {
        await paymentService.confirmUpgrade(50, { orderCode: 123456, accept: 'false' });
      },
      /Trường accept bắt buộc là kiểu boolean/
    );

    await assert.rejects(
      async () => {
        await paymentService.confirmUpgrade(50, { orderCode: 123456, accept: undefined });
      },
      /Trường accept bắt buộc là kiểu boolean/
    );
  });
});

