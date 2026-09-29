/**
 * Request Timeout Middleware
 * Khống chế thời gian thực thi tối đa của mỗi HTTP Request nhằm tránh rò rỉ socket và cạn kiệt tài nguyên
 */

const logger = require('../core/logger');

const DEFAULT_TIMEOUT_MS = 30000; // 30s cho môi trường Cloud thông thường & Free Tier

function createRequestTimeoutMiddleware(options = {}) {
  const timeoutMs = options.timeoutMs || DEFAULT_TIMEOUT_MS;

  return function requestTimeoutMiddleware(req, res, next) {
    const url = req.originalUrl || req.path || '';

    // 1. Luôn bỏ qua cho Server-Sent Events (SSE) và Health check
    const isSse = req.headers && req.headers.accept === 'text/event-stream';
    const isStreamPath = url.includes('/stream') || url.includes('/sse');
    const isHealth = url.startsWith('/health');

    if (isSse || isStreamPath || isHealth) {
      return next();
    }

    // Tự động gia hạn 60s cho tác vụ OCR xử lý ảnh lớn
    const effectiveTimeoutMs = url.includes('/ocr') ? Math.max(timeoutMs, 60000) : timeoutMs;

    // 2. Khởi tạo Timer kiểm soát
    const timer = setTimeout(() => {
      if (!res.headersSent) {
        logger.warn('[RESILIENCE] Request timeout vượt ngưỡng cho phép', {
          path: url,
          method: req.method,
          timeoutMs: effectiveTimeoutMs,
        });

        res.status(504).json({
          success: false,
          statusCode: 504,
          code: 'REQUEST_TIMEOUT',
          message: `Yêu cầu vượt quá thời gian xử lý cho phép (${Math.round(effectiveTimeoutMs / 1000)}s). Vui lòng thử lại!`,
          timestamp: new Date().toISOString(),
        });

        // Đóng socket sau khi gửi xong payload để client nhận được mã 504 rõ ràng
        setTimeout(() => {
          if (req.socket && !req.socket.destroyed && typeof req.socket.destroy === 'function') {
            req.socket.destroy();
          }
        }, 1000).unref?.();
      }
    }, effectiveTimeoutMs);

    req._timeoutTimer = timer;

    // 3. Dọn dẹp timer khi response hoàn tất
    const cleanup = () => {
      clearTimeout(timer);
      req._timeoutCleared = true;
    };

    if (typeof res.on === 'function') {
      res.on('finish', cleanup);
      res.on('close', cleanup);
    }

    next();
  };
}

const defaultRequestTimeout = createRequestTimeoutMiddleware();

module.exports = {
  createRequestTimeoutMiddleware,
  defaultRequestTimeout,
};
