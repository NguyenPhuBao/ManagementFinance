const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { prisma } = require('../../config/db');
const paymentRepository = require('../../modules/payment/payment.repository');

describe('Payment Repository - Real Database Integration Test (Supabase Cloud)', () => {
  let testAccount = null;
  let originalAccountType = null;
  let originalPremiumExpiresAt = null;
  let createdOrderId = null;
  let createdTransactionId = null;
  const testOrderCode = Number(Date.now().toString().slice(-9)); // 9 chữ số an toàn

  before(async () => {
    // 1. Tìm một tài khoản thật trong CSDL
    testAccount = await prisma.account.findFirst({
      where: {
        delete_at: null,
      },
      select: {
        idaccount: true,
        username: true,
        email: true,
        type: true,
        premium_expires_at: true,
      },
    });

    assert.ok(testAccount, 'Phải có ít nhất 1 tài khoản trong CSDL để thực hiện integration test');
    originalAccountType = testAccount.type;
    originalPremiumExpiresAt = testAccount.premium_expires_at;

    console.log(`[Integration Test] Đang chạy kiểm thử CSDL thật với Account ID: ${testAccount.idaccount}, Email: ${testAccount.email}`);
  });

  after(async () => {
    // Dọn dẹp dữ liệu kiểm thử (Rollback trạng thái)
    console.log('[Integration Test Cleanup] Bắt đầu dọn dẹp test records trên CSDL Supabase...');
    if (createdTransactionId) {
      await prisma.payment_transaction.deleteMany({
        where: { id: createdTransactionId },
      });
    }
    if (createdOrderId) {
      await prisma.payment_order.deleteMany({
        where: { id: createdOrderId },
      });
    }
    if (testAccount) {
      await prisma.account.update({
        where: { idaccount: testAccount.idaccount },
        data: {
          type: originalAccountType,
          premium_expires_at: originalPremiumExpiresAt,
        },
      });
    }
    await prisma.$disconnect();
    console.log('[Integration Test Cleanup] Đã hoàn tất dọn dẹp và khôi phục CSDL an toàn 100%.');
  });

  it('1. Nên tạo mới đơn hàng payment_order thành công trên CSDL thật', async () => {
    createdOrderId = crypto.randomUUID();
    const orderData = {
      id: createdOrderId,
      idaccount: testAccount.idaccount,
      orderCode: testOrderCode,
      packageType: 'PREMIUM_1_MONTH',
      amount: 49000,
      currency: 'VND',
      status: 'PENDING',
      checkoutUrl: 'https://pay.payos.vn/web/test-link',
      paymentLinkId: 'link_test_123',
      expiredAt: new Date(Date.now() + 15 * 60 * 1000),
    };

    const result = await paymentRepository.createOrder(orderData);

    assert.equal(result.id, createdOrderId);
    assert.equal(result.idaccount, testAccount.idaccount);
    assert.equal(result.order_code, testOrderCode);
    assert.equal(result.status, 'PENDING');
    assert.equal(result.amount, 49000);
  });

  it('2. Nên tìm được đơn hàng vừa tạo bằng mã order_code trên CSDL thật', async () => {
    const found = await paymentRepository.findOrderByCode(testOrderCode);

    assert.ok(found, 'Không tìm thấy đơn hàng vừa tạo bằng order_code');
    assert.equal(found.id, createdOrderId);
    assert.equal(found.account.idaccount, testAccount.idaccount);
  });

  it('3. Nên kích hoạt thành công gói Premium nguyên tử (Prisma $transaction)', async () => {
    createdTransactionId = crypto.randomUUID();
    const paidAt = new Date();
    const newExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // +30 ngày

    const activationResult = await paymentRepository.activatePremiumSubscription({
      idaccount: testAccount.idaccount,
      orderId: createdOrderId,
      paidAt,
      newExpiresAt,
      transactionData: {
        id: createdTransactionId,
        orderId: createdOrderId,
        idaccount: testAccount.idaccount,
        payosTransactionId: 'PAYOS_TX_REAL_999',
        amount: 49000,
        bankCode: 'MBBANK',
        transactionTime: paidAt,
        signatureVerified: true,
        rawWebhookHash: crypto.createHash('sha256').update('test-payload').digest('hex'),
      },
    });

    assert.equal(activationResult.order.status, 'PAID');
    assert.equal(activationResult.account.type, 'Premium');
    assert.ok(activationResult.account.premium_expires_at);

    // Thẩm tra trực tiếp từ bảng account trên CSDL thật
    const updatedAccount = await prisma.account.findUnique({
      where: { idaccount: testAccount.idaccount },
    });
    assert.equal(updatedAccount.type, 'Premium');
    assert.ok(updatedAccount.premium_expires_at instanceof Date);

    // Thẩm tra bảng payment_transaction
    const txRecord = await prisma.payment_transaction.findUnique({
      where: { id: createdTransactionId },
    });
    assert.ok(txRecord);
    assert.equal(txRecord.payos_transaction_id, 'PAYOS_TX_REAL_999');
    assert.equal(Number(txRecord.amount), 49000);
  });

  it('4. Nên đọc được thông tin subscription và lịch sử thanh toán trên CSDL thật', async () => {
    const subInfo = await paymentRepository.findAccountSubscription(testAccount.idaccount);
    assert.equal(subInfo.type, 'Premium');
    assert.ok(subInfo.premium_expires_at);

    const history = await paymentRepository.findOrdersByAccount(testAccount.idaccount, { page: 1, limit: 10 });
    assert.ok(history.items.length > 0);
    const matchedOrder = history.items.find((item) => item.id === createdOrderId);
    assert.ok(matchedOrder, 'Đơn hàng vừa tạo phải có trong danh sách lịch sử');
    assert.equal(matchedOrder.status, 'PAID');
  });
});
