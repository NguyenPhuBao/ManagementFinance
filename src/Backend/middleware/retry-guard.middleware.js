/**
 * Retry Guard Middleware
 * Kiểm soát và ngăn chặn bão request / vòng lặp gọi lại vô tận (Infinite Retry Storm)
 */

const crypto = require('crypto');
const logger = require('../core/logger');

const DEFAULT_MAX_RETRIES = 3;
const DEFAULT_WINDOW_MS = 10000; // 10s cửa sổ trượt

function createRetryGuardMiddleware(options = {}) {
  const maxRetries = options.maxRetries || DEFAULT_MAX_RETRIES;
  const windowMs = options.windowMs || DEFAULT_WINDOW_MS;
  const requestHistory = new Map();

  // Dọn dẹp bộ nhớ định kỳ tránh rò rỉ RAM
  const cleanupInterval = setInterval(() => {
    const now = Date.now();
    for (const [key, record] of requestHistory.entries()) {
      if (now - record.lastSeen > windowMs * 2) {
        requestHistory.delete(key);
      }
    }
  }, Math.max(windowMs * 2, 30000));

  if (cleanupInterval.unref) {
    cleanupInterval.unref(); // Không giữ tiến trình Node.js khi exit
  }

  return function retryGuardMiddleware(req, res, next) {
    const url = req.originalUrl || req.path || '';
    const isAdmin = req.isAdmin === true;
    const isHealth = url.startsWith('/health');
    const isBankWebhook = url.startsWith('/api/bank/webhook');

    // 0. Miễn trừ hoàn toàn cho Admin, Health check và Webhook Ngân hàng (tránh miss biến động số dư)
    if (isAdmin || isHealth || isBankWebhook) {
      return next();
    }

    // 1. Kiểm tra header 'x-retry-count' rõ ràng từ client
    const headerRetryCount = req.headers && req.headers['x-retry-count']
      ? parseInt(req.headers['x-retry-count'], 10)
      : 0;

    if (headerRetryCount > maxRetries) {
      logger.warn('[RESILIENCE] Bị chặn bởi x-retry-count vượt ngưỡng', {
        path: url,
        retryCount: headerRetryCount,
        ip: req.ip,
      });

      return res.status(429).json({
        success: false,
        statusCode: 429,
        code: 'RETRY_LIMIT_EXCEEDED',
        message: 'Phát hiện vòng lặp yêu cầu thử lại liên tục. Vui lòng dừng lại và thử lại sau ít phút!',
        backoffSeconds: Math.ceil(windowMs / 1000),
        timestamp: new Date().toISOString(),
      });
    }

    const method = req.method || 'GET';
    const isReadMethod = method === 'GET' || method === 'HEAD' || method === 'OPTIONS';

    // Đối với GET/HEAD/OPTIONS không có header retry, cho phép qua tự nhiên (tránh false positive khi nhiều user cùng NAT/Wi-Fi)
    if (isReadMethod && headerRetryCount === 0) {
      return next();
    }

    // 2. Tạo chữ ký định danh cho request ghi/đột biến
    const ip = req.ip || req.connection?.remoteAddress || '127.0.0.1';
    const bodyStr = req.body ? JSON.stringify(req.body) : '';
    
    // Hash nhanh chữ ký request
    const signature = crypto
      .createHash('sha256')
      .update(`${ip}:${method}:${url}:${bodyStr}`)
      .digest('hex');

    const now = Date.now();
    const record = requestHistory.get(signature) || { count: 0, firstSeen: now, lastSeen: now };

    // Reset nếu ngoài cửa sổ thời gian
    if (now - record.firstSeen > windowMs) {
      record.count = 1;
      record.firstSeen = now;
      record.lastSeen = now;
    } else {
      record.count += 1;
      record.lastSeen = now;
    }

    requestHistory.set(signature, record);
    req._retryAttempt = record.count;

    // 3. Nếu vượt quá số lần retry cho phép
    if (record.count > maxRetries) {
      logger.warn('[RESILIENCE] Phát hiện bão request lặp lại (Retry Storm)', {
        signature,
        path: url,
        method,
        attempts: record.count,
        maxRetries,
      });

      return res.status(429).json({
        success: false,
        statusCode: 429,
        code: 'RETRY_LIMIT_EXCEEDED',
        message: 'Phát hiện vòng lặp yêu cầu thử lại liên tục. Vui lòng dừng lại và thử lại sau ít phút!',
        backoffSeconds: Math.ceil(windowMs / 1000),
        timestamp: new Date().toISOString(),
      });
    }

    next();
  };
}

const defaultRetryGuard = createRetryGuardMiddleware();

module.exports = {
  createRetryGuardMiddleware,
  defaultRetryGuard,
};
