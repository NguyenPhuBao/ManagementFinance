const logger = require('../../../core/logger');

/**
 * Verify webhook request từ Casso
 * Casso sẽ gửi một header `secure-token` (thường biến thành `secure-token` trong nodejs headers).
 * Ta so sánh nó với CASSO_WEBHOOK_SECRET.
 */
function verifySignature(req) {
  const secret = process.env.CASSO_WEBHOOK_SECRET;
  if (!secret) {
    logger.error('CASSO_WEBHOOK_SECRET is not configured in .env');
    return false;
  }

  // Node.js Express chuyển headers thành lowercase
  const secureToken = req.headers['secure-token'];

  if (!secureToken) {
    logger.warn('Webhook missing Secure-Token header');
    return false;
  }

  return secureToken === secret;
}

module.exports = {
  verifySignature
};
