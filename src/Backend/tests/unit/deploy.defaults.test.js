/**
 * Giá trị mặc định khi môi trường không đặt biến (2026-11-14):
 * - Mô hình Gemini cho OCR / phân loại / chatbot dự phòng: gemini-3.5-flash, khai báo một chỗ.
 * - Địa chỉ trả về của PayOS trỏ tên miền Admin-web thật trên Vercel.
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

// Đặt chuỗi rỗng (không xóa) để dotenv không nạp lại giá trị từ .env khi require lại.
function freshRequire(modulePath, emptyVars) {
  const saved = {};
  for (const k of emptyVars) { saved[k] = process.env[k]; process.env[k] = ''; }
  const resolved = require.resolve(modulePath);
  const cached = require.cache[resolved];
  delete require.cache[resolved];
  try {
    return require(resolved);
  } finally {
    if (cached) require.cache[resolved] = cached; else delete require.cache[resolved];
    for (const k of emptyVars) { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }
  }
}

describe('Giá trị mặc định khi thiếu biến môi trường', () => {
  it('Gemini mặc định gemini-3.5-flash', () => {
    const aiConfig = freshRequire('../../modules/ai/config', ['GEMINI_MODEL']);
    assert.strictEqual(aiConfig.DEFAULT_GEMINI_MODEL, 'gemini-3.5-flash');
    assert.strictEqual(aiConfig.llm.defaultModel, 'gemini-3.5-flash');
  });

  it('OCR, phân loại, chatbot dự phòng không ghi cứng tên mô hình khác', () => {
    const files = [
      'modules/ai/features/ocr/pipeline/vision.extractor.js',
      'modules/ai/features/classify/pipeline/llm.classifier.js',
      'modules/ai/features/chatbot/chatbot.service.js',
    ];
    for (const f of files) {
      const src = fs.readFileSync(path.join(__dirname, '../..', f), 'utf8');
      assert.doesNotMatch(src, /'gemini-\d/, `${f} còn ghi cứng tên mô hình`);
      assert.match(src, /DEFAULT_GEMINI_MODEL/, `${f} chưa dùng DEFAULT_GEMINI_MODEL`);
    }
  });

  it('PayOS trả về / hủy về tên miền Admin-web thật', () => {
    const config = freshRequire('../../config', ['PAYOS_RETURN_URL', 'PAYOS_CANCEL_URL']);
    assert.strictEqual(config.payos.returnUrl, 'https://management-finance-gamma.vercel.app/payment/success');
    assert.strictEqual(config.payos.cancelUrl, 'https://management-finance-gamma.vercel.app/payment/cancel');
  });

  it('Tầng 2: link PayOS gửi đi mang địa chỉ trả về / hủy khớp route công khai của Admin-web', async () => {
    const config = require('../../config');
    const payosClient = require('../../modules/payment/payos.client');
    let sent = null;
    payosClient.setPayOSClientMock({
      paymentRequests: {
        create: async (body) => { sent = body; return { checkoutUrl: 'https://pay.payos.vn/web/thu', paymentLinkId: 'thu' }; },
      },
    });
    try {
      await payosClient.createPaymentLink({ orderCode: 123456, amount: 49000, description: 'THU' });
    } finally {
      payosClient.setPayOSClientMock(null);
    }
    assert.strictEqual(sent.returnUrl, config.payos.returnUrl);
    assert.strictEqual(sent.cancelUrl, config.payos.cancelUrl);
    assert.match(sent.returnUrl, /^https:\/\/[^/]+\/payment\/success$/);
    assert.match(sent.cancelUrl, /^https:\/\/[^/]+\/payment\/cancel$/);
    const routes = fs.readFileSync(path.join(__dirname, '../../../Admin-web/src/router/routes.jsx'), 'utf8');
    assert.match(routes, /path: '\/payment\/success',\s*element: <PaymentResultPage outcome="success" \/>,\s*public: true/);
    assert.match(routes, /path: '\/payment\/cancel',\s*element: <PaymentResultPage outcome="cancel" \/>,\s*public: true/);
  });
});
