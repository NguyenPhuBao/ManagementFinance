const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');

test('Payment Service Suite', async (t) => {
  const paymentService = require('../../modules/payment/payment.service');
  const paymentRepository = require('../../modules/payment/payment.repository');
  const payosClient = require('../../modules/payment/payos.client');

  await t.test('1. createPremiumOrder() tạo đơn hàng với orderCode duy nhất và gọi PayOS tạo link', async () => {
    let capturedOrder = null;
    const origCreateOrder = paymentRepository.createOrder;
    paymentRepository.createOrder = async (orderData) => {
      capturedOrder = orderData;
      return orderData;
    };

    payosClient.setPayOSClientMock({
      paymentRequests: {
        create: async (body) => ({
          checkoutUrl: 'https://pay.payos.vn/web/mock',
          paymentLinkId: 'link_mock',
          orderCode: body.orderCode,
        }),
      },
    });

    try {
      const res = await paymentService.createPremiumOrder(10, { packageType: 'PREMIUM_1_MONTH' });

      assert.ok(res.orderCode > 0, 'Phải có orderCode hợp lệ');
      assert.strictEqual(res.amount, 49000);
      assert.strictEqual(res.checkoutUrl, 'https://pay.payos.vn/web/mock');
      assert.strictEqual(capturedOrder.idaccount, 10);
      assert.strictEqual(capturedOrder.status, 'PENDING');
    } finally {
      paymentRepository.createOrder = origCreateOrder;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('2. handlePayOSWebhook() từ chối khi chữ ký webhook không hợp lệ', async () => {
    payosClient.setPayOSClientMock({
      webhooks: {
        verify: () => {
          throw new Error('Invalid signature');
        },
      },
    });

    try {
      await assert.rejects(
        async () => {
          await paymentService.handlePayOSWebhook({
            code: '00',
            data: { orderCode: 123 },
            signature: 'fake',
          });
        },
        (err) => {
          assert.strictEqual(err.statusCode, 400);
          assert.match(err.message, /Chữ ký Webhook không hợp lệ/);
          return true;
        }
      );
    } finally {
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('3. handlePayOSWebhook() xử lý Idempotency - trả về thành công ngay nếu đơn hàng đã PAID', async () => {
    payosClient.setPayOSClientMock({
      webhooks: {
        verify: (payload) => payload.data,
      },
    });

    const origFind = paymentRepository.findOrderByCode;
    paymentRepository.findOrderByCode = async () => ({
      id: 'mock-order-id',
      order_code: 123456,
      idaccount: 10,
      status: 'PAID', // Đã thanh toán trước đó
      amount: 49000,
    });

    let activated = false;
    const origActivate = paymentRepository.activatePremiumSubscription;
    paymentRepository.activatePremiumSubscription = async () => {
      activated = true;
    };

    try {
      const res = await paymentService.handlePayOSWebhook({
        code: '00',
        data: { orderCode: 123456, amount: 49000 },
        signature: 'valid',
      });

      assert.strictEqual(res.success, true);
      assert.match(res.message, /đã được xử lý/i);
      assert.strictEqual(activated, false, 'Tuyệt đối không được kích hoạt lại lần 2');
    } finally {
      paymentRepository.findOrderByCode = origFind;
      paymentRepository.activatePremiumSubscription = origActivate;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('4. handlePayOSWebhook() cộng dồn thời hạn (Stacking) khi tài khoản còn hạn Premium', async () => {
    payosClient.setPayOSClientMock({
      webhooks: {
        verify: (payload) => payload.data,
      },
    });

    // Giả lập tài khoản còn 10 ngày Premium
    const currentExpiry = new Date(Date.now() + 10 * 86400000);
    const origFind = paymentRepository.findOrderByCode;
    paymentRepository.findOrderByCode = async () => ({
      id: 'mock-order-id',
      order_code: 777888,
      idaccount: 10,
      status: 'PENDING',
      amount: 49000,
      account: {
        idaccount: 10,
        type: 'Premium',
        premium_expires_at: currentExpiry,
      },
    });

    let calculatedNewExpiry = null;
    const origActivate = paymentRepository.activatePremiumSubscription;
    paymentRepository.activatePremiumSubscription = async ({ newExpiresAt }) => {
      calculatedNewExpiry = newExpiresAt;
      return {
        order: { id: 'mock-order-id', status: 'PAID' },
        account: { idaccount: 10, type: 'Premium', premium_expires_at: newExpiresAt },
      };
    };

    try {
      await paymentService.handlePayOSWebhook({
        code: '00',
        data: {
          orderCode: 777888,
          amount: 49000,
          reference: 'MB123456',
          transactionDateTime: new Date().toISOString(),
        },
        signature: 'valid',
      });

      assert.ok(calculatedNewExpiry, 'Phải tính toán ngày hết hạn mới');
      // Ngày hết hạn mới phải bằng currentExpiry + 30 ngày (sai số trong 1 giây)
      const expectedDiff = 30 * 86400000;
      const actualDiff = calculatedNewExpiry.getTime() - currentExpiry.getTime();
      assert.ok(Math.abs(actualDiff - expectedDiff) < 1000, 'Phải cộng dồn thêm đúng 30 ngày');
    } finally {
      paymentRepository.findOrderByCode = origFind;
      paymentRepository.activatePremiumSubscription = origActivate;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('5. getSubscriptionInfo() tính toán chính xác daysRemaining và isExpired', async () => {
    const origFind = paymentRepository.findAccountSubscription;

    // Ca 1: Tài khoản Basic
    paymentRepository.findAccountSubscription = async () => ({
      idaccount: 10,
      type: 'Basic',
      premium_expires_at: null,
    });
    const basicInfo = await paymentService.getSubscriptionInfo(10);
    assert.strictEqual(basicInfo.accountType, 'Basic');
    assert.strictEqual(basicInfo.daysRemaining, 0);
    assert.strictEqual(basicInfo.isExpired, true);
    assert.deepStrictEqual(basicInfo.limits, { wallets: 3, budgets: 3, goals: 3 });
    assert.strictEqual(basicInfo.price, 49000);
    assert.strictEqual(basicInfo.packageDays, 30);

    // Ca 2: Tài khoản Premium còn 15 ngày
    const futureDate = new Date(Date.now() + 15 * 86400000);
    paymentRepository.findAccountSubscription = async () => ({
      idaccount: 10,
      type: 'Premium',
      premium_expires_at: futureDate,
    });
    const premiumInfo = await paymentService.getSubscriptionInfo(10);
    assert.strictEqual(premiumInfo.accountType, 'Premium');
    assert.strictEqual(premiumInfo.daysRemaining, 15);
    assert.strictEqual(premiumInfo.isExpired, false);
    assert.deepStrictEqual(premiumInfo.limits, { wallets: 3, budgets: 3, goals: 3 });
    assert.strictEqual(premiumInfo.price, 49000);
    assert.strictEqual(premiumInfo.packageDays, 30);

    paymentRepository.findAccountSubscription = origFind;
  });
});
