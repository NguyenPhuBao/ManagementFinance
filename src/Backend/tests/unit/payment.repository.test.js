const test = require('node:test');
const assert = require('node:assert/strict');
const { prisma } = require('../../config/db');

test('Payment Repository Suite', async (t) => {
  const paymentRepository = require('../../modules/payment/payment.repository');

  await t.test('1. createOrder() gọi prisma.payment_order.create với dữ liệu chuẩn hóa', async () => {
    let capturedCreateData = null;
    const origCreate = prisma.payment_order.create;
    prisma.payment_order.create = async ({ data }) => {
      capturedCreateData = data;
      return { ...data, created_at: new Date() };
    };

    try {
      const order = await paymentRepository.createOrder({
        id: 'mock-order-uuid',
        idaccount: 10,
        orderCode: 123456789,
        packageType: 'PREMIUM_1_MONTH',
        amount: 49000,
        checkoutUrl: 'https://pay.payos.vn/web/test',
        paymentLinkId: 'link_123',
      });

      assert.strictEqual(order.id, 'mock-order-uuid');
      assert.strictEqual(capturedCreateData.idaccount, 10);
      assert.strictEqual(capturedCreateData.order_code, BigInt(123456789));
      assert.strictEqual(capturedCreateData.status, 'PENDING');
      assert.strictEqual(capturedCreateData.amount, 49000);
    } finally {
      prisma.payment_order.create = origCreate;
    }
  });

  await t.test('2. findOrderByCode() chuyển đổi orderCode thành BigInt khi truy vấn', async () => {
    let capturedWhere = null;
    const origFindUnique = prisma.payment_order.findUnique;
    prisma.payment_order.findUnique = async ({ where }) => {
      capturedWhere = where;
      return {
        id: 'mock-order-uuid',
        order_code: BigInt(999999),
        idaccount: 10,
        status: 'PENDING',
        amount: 49000,
      };
    };

    try {
      const order = await paymentRepository.findOrderByCode(999999);
      assert.ok(order, 'Phải tìm thấy đơn hàng');
      assert.strictEqual(capturedWhere.order_code, BigInt(999999));
      assert.strictEqual(typeof order.order_code, 'number', 'Phải chuyển BigInt sang Number để an toàn JSON');
    } finally {
      prisma.payment_order.findUnique = origFindUnique;
    }
  });

  await t.test('3. activatePremiumSubscription() thực thi nguyên tử cập nhật order, ghi transaction và nâng cấp account', async () => {
    let transactionExecuted = false;
    const origTx = prisma.$transaction;
    prisma.$transaction = async (callback) => {
      transactionExecuted = true;
      const fakeTx = {
        payment_order: {
          update: async () => ({ id: 'mock-order-uuid', status: 'PAID' }),
        },
        payment_transaction: {
          create: async ({ data }) => data,
        },
        account: {
          update: async ({ where, data }) => ({ idaccount: where.idaccount, ...data }),
        },
      };
      return callback(fakeTx);
    };

    try {
      const newExpiry = new Date(Date.now() + 30 * 86400000);
      const result = await paymentRepository.activatePremiumSubscription({
        idaccount: 10,
        orderId: 'mock-order-uuid',
        paidAt: new Date(),
        newExpiresAt: newExpiry,
        transactionData: {
          id: 'mock-tx-uuid',
          payosTransactionId: 'payos_tx_999',
          amount: 49000,
          bankCode: 'MB',
          rawWebhookHash: 'hash123',
        },
      });

      assert.strictEqual(transactionExecuted, true, 'Bắt buộc phải bọc qua prisma.$transaction');
      assert.strictEqual(result.account.type, 'Premium');
      assert.strictEqual(result.account.premium_expires_at, newExpiry);
      assert.strictEqual(result.order.status, 'PAID');
    } finally {
      prisma.$transaction = origTx;
    }
  });
});
