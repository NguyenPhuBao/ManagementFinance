const test = require('node:test');
const assert = require('node:assert/strict');

test('PayOS Client Wrapper Suite', async (t) => {
  const payosClientModule = require('../../modules/payment/payos.client');

  await t.test('1. generateOrderCode() sinh số nguyên an toàn trong giới hạn MAX_SAFE_INTEGER', () => {
    const code1 = payosClientModule.generateOrderCode();
    const code2 = payosClientModule.generateOrderCode();

    assert.ok(typeof code1 === 'number', 'orderCode phải là number');
    assert.ok(Number.isInteger(code1), 'orderCode phải là số nguyên');
    assert.ok(code1 > 0, 'orderCode phải dương');
    assert.ok(code1 <= Number.MAX_SAFE_INTEGER, 'orderCode không vượt quá MAX_SAFE_INTEGER');
    assert.notStrictEqual(code1, code2, 'Hai lần sinh liên tiếp phải khác nhau');
  });

  await t.test('2. createPaymentLink() gọi payOS.paymentRequests.create với tham số chuẩn hóa', async () => {
    let capturedBody = null;
    const mockPayOS = {
      paymentRequests: {
        create: async (body) => {
          capturedBody = body;
          return {
            checkoutUrl: 'https://pay.payos.vn/web/mock123',
            paymentLinkId: 'link_mock_123',
            orderCode: body.orderCode,
            amount: body.amount,
          };
        },
      },
      webhooks: {
        verify: (data) => data.data,
      },
    };

    payosClientModule.setPayOSClientMock(mockPayOS);

    try {
      const res = await payosClientModule.createPaymentLink({
        orderCode: 12345678,
        amount: 49000,
        description: 'PFM Premium 1 Thang',
      });

      assert.strictEqual(res.checkoutUrl, 'https://pay.payos.vn/web/mock123');
      assert.strictEqual(res.paymentLinkId, 'link_mock_123');
      assert.strictEqual(capturedBody.orderCode, 12345678);
      assert.strictEqual(capturedBody.amount, 49000);
      assert.strictEqual(capturedBody.description, 'PFM Premium 1 Thang');
    } finally {
      payosClientModule.setPayOSClientMock(null);
    }
  });

  await t.test('3. verifyWebhookData() xác thực hợp lệ khi chữ ký đúng và ném lỗi khi chữ ký sai', async () => {
    const mockPayOS = {
      webhooks: {
        verify: async (payload) => {
          if (payload.signature === 'valid-signature') {
            return payload.data;
          }
          throw new Error('Invalid signature');
        },
      },
    };

    payosClientModule.setPayOSClientMock(mockPayOS);

    try {
      // Ca chữ ký đúng
      const validPayload = {
        code: '00',
        desc: 'success',
        data: { orderCode: 888999, amount: 49000 },
        signature: 'valid-signature',
      };
      const verified = await payosClientModule.verifyWebhookData(validPayload);
      assert.deepStrictEqual(verified, { orderCode: 888999, amount: 49000 });

      // Ca chữ ký sai
      const invalidPayload = {
        code: '00',
        desc: 'success',
        data: { orderCode: 888999, amount: 49000 },
        signature: 'fake-signature',
      };
      await assert.rejects(async () => {
        await payosClientModule.verifyWebhookData(invalidPayload);
      }, /Invalid signature/);
    } finally {
      payosClientModule.setPayOSClientMock(null);
    }
  });
});
