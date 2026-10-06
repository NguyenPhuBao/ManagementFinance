const { PayOS } = require('@payos/node');
const config = require('../../config');
const logger = require('../../core/logger');

let payosInstance = null;
let mockClient = null;

/**
 * Lấy đối tượng PayOS client (Singleton)
 */
function getPayOSClient() {
  if (mockClient) {
    return mockClient;
  }

  if (!payosInstance) {
    const { clientId, apiKey, checksumKey } = config.payos || {};
    if (!clientId || !apiKey || !checksumKey) {
      logger.warn('[PAYOS] Chưa cấu hình đầy đủ PAYOS_CLIENT_ID, PAYOS_API_KEY hoặc PAYOS_CHECKSUM_KEY');
    }
    payosInstance = new PayOS({
      clientId: clientId || 'MISSING_CLIENT_ID',
      apiKey: apiKey || 'MISSING_API_KEY',
      checksumKey: checksumKey || 'MISSING_CHECKSUM_KEY',
    });
  }
  return payosInstance;
}

/**
 * Mocking helper dành cho Unit Test
 * @param {object|null} mock 
 */
function setPayOSClientMock(mock) {
  mockClient = mock;
}

/**
 * Sinh mã đơn hàng số nguyên dương ngẫu nhiên an toàn (orderCode cho PayOS)
 * Định dạng: Timestamp mili-giây (13 chữ số) + 2 chữ số ngẫu nhiên = 15 chữ số (< MAX_SAFE_INTEGER 9007199254740991)
 * @returns {number}
 */
function generateOrderCode() {
  const timestamp = Date.now();
  const randomSuffix = Math.floor(Math.random() * 90 + 10); // 2 chữ số (10 - 99)
  const codeStr = `${timestamp.toString().slice(-9)}${randomSuffix}${Math.floor(Math.random() * 90 + 10)}`;
  return parseInt(codeStr, 10);
}

/**
 * Tạo liên kết thanh toán PayOS (VietQR / Ngân hàng)
 * @param {object} param0
 * @param {number} param0.orderCode
 * @param {number} param0.amount
 * @param {string} param0.description
 * @param {string} [param0.returnUrl]
 * @param {string} [param0.cancelUrl]
 * @param {Array} [param0.items]
 * @returns {Promise<{ checkoutUrl: string, paymentLinkId: string, orderCode: number, amount: number }>}
 */
async function createPaymentLink({ orderCode, amount, description, returnUrl, cancelUrl, items }) {
  const client = getPayOSClient();

  const body = {
    orderCode,
    amount,
    description: (description || 'PFM Premium').slice(0, 25), // PayOS quy định tối đa 25 ký tự
    returnUrl: returnUrl || config.payos.returnUrl,
    cancelUrl: cancelUrl || config.payos.cancelUrl,
  };

  if (Array.isArray(items) && items.length > 0) {
    body.items = items;
  }

  logger.info('[PAYOS] Đang tạo liên kết thanh toán', { orderCode, amount });
  const paymentLinkResponse = await client.paymentRequests.create(body);
  logger.info('[PAYOS] Tạo liên kết thanh toán thành công', { 
    orderCode, 
    paymentLinkId: paymentLinkResponse.paymentLinkId,
    checkoutUrl: paymentLinkResponse.checkoutUrl 
  });

  return paymentLinkResponse;
}

/**
 * Thẩm tra tính hợp lệ của dữ liệu Webhook từ PayOS qua chữ ký số HMAC-SHA256
 * @param {object} webhookPayload 
 * @returns {Promise<object>} Dữ liệu data đã được xác thực
 * @throws {Error} Nếu chữ ký không khớp
 */
async function verifyWebhookData(webhookPayload) {
  const client = getPayOSClient();
  if (!webhookPayload) {
    throw new Error('Webhook payload rỗng');
  }

  // Phương thức verify trả về Promise<WebhookData> và ném lỗi nếu chữ ký HMAC-SHA256 không hợp lệ
  return client.webhooks.verify(webhookPayload);
}

/**
 * Đăng ký & xác nhận Webhook URL với PayOS qua API
 * @param {string} webhookUrl 
 */
async function confirmWebhook(webhookUrl) {
  const client = getPayOSClient();
  return client.webhooks.confirm(webhookUrl);
}

/**
 * Lấy thông tin thanh toán theo mã đơn hàng
 * @param {number|string} orderIdOrCode 
 */
async function getPaymentLinkInfo(orderIdOrCode) {
  const client = getPayOSClient();
  return client.paymentRequests.get(orderIdOrCode);
}

module.exports = {
  getPayOSClient,
  setPayOSClientMock,
  generateOrderCode,
  createPaymentLink,
  verifyWebhookData,
  confirmWebhook,
  getPaymentLinkInfo,
};

