/**
 * Load Shedding Middleware
 * Cắt tải thông minh khi hệ thống quá tải (Event Loop lag > 100ms)
 * Thông báo minh bạch cho người dùng, tuyệt đối không âm thầm ngắt kết nối
 * Ưu tiên đặc quyền cho Admin-web luôn thông suốt
 */

const { defaultEventLoopMonitor } = require('../core/resilience/event-loop-monitor');
const logger = require('../core/logger');

let lastOverloadAlert = 0;

// --- Load Shedding Counter (reset mỗi 24h) ---
let _shedCount = 0;
const _shedResetTimer = setInterval(() => { _shedCount = 0; }, 24 * 60 * 60 * 1000);
if (_shedResetTimer.unref) _shedResetTimer.unref();
function getLoadSheddingCount() { return _shedCount; }

const _STARTUP_TIME = Date.now();

function createLoadSheddingMiddleware(options = {}) {

  const monitor = options.monitor || defaultEventLoopMonitor;
  const retryAfterSeconds = options.retryAfterSeconds || 5;
  const isTestEnv = process.env.NODE_ENV === 'test' || Boolean(process.env.NODE_TEST_CONTEXT);
  const warmupMs = options.warmupMs !== undefined ? options.warmupMs : (isTestEnv ? 0 : 45000);

  return function loadSheddingMiddleware(req, res, next) {
    // 1. Kiểm tra nếu request thuộc về Admin-web hoặc Health Check (Bypass hoàn toàn)
    const p = req.path || req.originalUrl || '';
    const isHealthCheck = p.startsWith('/health') || (p === '/' && (req.method === 'HEAD' || req.method === 'GET'));

    const isAdmin = req.isAdmin === true;

    if (isAdmin || isHealthCheck) {
      return next();
    }

    // 2. Warmup Grace Period: Bỏ qua cắt tải trong thời gian nạp ban đầu máy chủ (tránh lỗi 503 khi cold-start)
    if (Date.now() - _STARTUP_TIME < warmupMs) {
      return next();
    }

    // 2. Kiểm tra tình trạng Event Loop
    if (monitor.isOverloaded()) {
      const lag = typeof monitor.getLag === 'function' ? monitor.getLag() : 100;
      logger.warn('[RESILIENCE] Kích hoạt Load Shedding — Từ chối client để giải tỏa CPU', {
        lagMs: lag,
        path: req.originalUrl || req.path,
        method: req.method,
      });

      if (typeof res.setHeader === 'function') {
        res.setHeader('Retry-After', String(retryAfterSeconds));
      }

      // Phát cảnh báo hệ thống tới Admin (throttled tối đa 1 cảnh báo mỗi 30s)
      const now = Date.now();
      if (now - lastOverloadAlert > 30000) {
        lastOverloadAlert = now;
        try {
          const eventBus = require('../core/event-bus');
          eventBus.publish('system.overload', {
            title: 'Cảnh báo quá tải hệ thống (Load Shedding)',
            message: `Event Loop Lag đạt ${lag}ms, kích hoạt cơ chế cắt tải bảo vệ hệ thống.`,
            level: 'CRITICAL',
            category: 'LOAD_SHEDDING',
            metadata: { lagMs: lag, path: req.originalUrl || req.path },
          });
        } catch (_) {}
      }


      _shedCount++;
      return res.status(503).json({
        success: false,
        statusCode: 503,
        code: 'SERVER_OVERLOADED',
        message: 'Hệ thống đang xử lý lượng truy cập lớn. Vui lòng thử lại sau ít giây!',
        retryAfter: retryAfterSeconds,
        timestamp: new Date().toISOString(),
      });
    }

    next();
  };
}

const defaultLoadShedding = createLoadSheddingMiddleware();

module.exports = {
  createLoadSheddingMiddleware,
  defaultLoadShedding,
  getLoadSheddingCount,
};
