const test = require('node:test');
const assert = require('node:assert/strict');

test('Payment Config & PayOS Configuration Suite', async (t) => {
  await t.test('1. Module config phải xuất đầy đủ thông tin cấu hình PayOS', () => {
    // Đặt biến môi trường giả lập để kiểm tra
    process.env.PAYOS_CLIENT_ID = 'test-client-id';
    process.env.PAYOS_API_KEY = 'test-api-key';
    process.env.PAYOS_CHECKSUM_KEY = 'test-checksum-key';
    process.env.PAYOS_RETURN_URL = 'https://app.test/success';
    process.env.PAYOS_CANCEL_URL = 'https://app.test/cancel';
    process.env.PREMIUM_PRICE_VND = '49000';

    // Xóa cache require để nạp lại config
    delete require.cache[require.resolve('../../config')];
    const config = require('../../config');

    assert.ok(config.payos, 'config.payos phải tồn tại');
    assert.strictEqual(config.payos.clientId, 'test-client-id');
    assert.strictEqual(config.payos.apiKey, 'test-api-key');
    assert.strictEqual(config.payos.checksumKey, 'test-checksum-key');
    assert.strictEqual(config.payos.returnUrl, 'https://app.test/success');
    assert.strictEqual(config.payos.cancelUrl, 'https://app.test/cancel');

    assert.ok(config.payment, 'config.payment phải tồn tại');
    assert.strictEqual(config.payment.premiumPriceVnd, 49000);
    assert.strictEqual(config.payment.packageDurationDays, 30);
  });
});
