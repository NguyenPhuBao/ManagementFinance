const crypto = require('crypto');
const logger = require('../../../core/logger');
const config = require('../../../config');

/**
 * Verify webhook request từ Casso
 * Casso sẽ gửi một header `secure-token` (thường biến thành `secure-token` trong nodejs headers).
 * Ta so sánh nó với CASSO_WEBHOOK_SECRET bằng timingSafeEqual chống timing attack.
 */
function verifySignature(req) {
  const secret = config.casso.webhookSecret;
  if (!secret) {
    logger.error('CASSO_WEBHOOK_SECRET is not configured in .env');
    return false;
  }

  // Node.js Express chuyển headers thành lowercase
  const secureToken = req.headers['secure-token'];

  if (!secureToken || typeof secureToken !== 'string') {
    logger.warn('Webhook missing or invalid Secure-Token header');
    return false;
  }

  const tokenBuffer = Buffer.from(secureToken);
  const secretBuffer = Buffer.from(secret);

  if (tokenBuffer.length !== secretBuffer.length) {
    return false;
  }

  return crypto.timingSafeEqual(tokenBuffer, secretBuffer);
}

module.exports = {
  verifySignature
};
