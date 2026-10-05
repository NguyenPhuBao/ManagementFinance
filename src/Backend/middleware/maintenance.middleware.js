/**
 * Maintenance Middleware
 * Chặn traffic người dùng thông thường khi hệ thống đang trong chế độ bảo trì khẩn cấp
 * Cho phép Admin-web tiếp tục truy cập để thao tác cứu hộ
 */

const { defaultMaintenanceManager } = require('../core/resilience/maintenance.manager');

function createMaintenanceMiddleware(options = {}) {
  const manager = options.manager || defaultMaintenanceManager;

  return function maintenanceMiddleware(req, res, next) {
    if (!manager.isMaintenanceActive()) {
      return next();
    }

    // 1. Ngoại lệ đặc quyền: Admin, Health Check probe và route /auth/login
    // Route /auth/login được đi qua để Admin có thể đăng nhập cứu hộ.
    // auth.service sẽ kiểm tra mật khẩu & role trong CSDL, người dùng thường sẽ bị từ chối 503 sau khi kiểm tra.
    const cleanUrl = (req.originalUrl || req.path || '').split('?')[0];

    const isHealthCheck = cleanUrl === '/health' || cleanUrl.startsWith('/health/');

    const isLoginRoute = req.method === 'POST' && (cleanUrl === '/api/auth/login' || cleanUrl === '/auth/login');

    const isAdmin = req.isAdmin === true;

    if (isAdmin || isHealthCheck || isLoginRoute) {
      return next();
    }

    // 2. Chặn các request người dùng thông thường
    const status = manager.getStatus();

    if (typeof res.setHeader === 'function') {
      res.setHeader('Retry-After', '60');
    }

    return res.status(503).json({
      success: false,
      statusCode: 503,
      code: 'MAINTENANCE_MODE',
      message: status.reason || 'Hệ thống đang bảo trì để nâng cấp định kỳ. Quý khách vui lòng quay lại sau ít phút!',
      isEmergency: Boolean(status.isEmergency),
      activatedAt: status.activatedAt,
      timestamp: new Date().toISOString(),
    });
  };
}

const defaultMaintenance = createMaintenanceMiddleware();

module.exports = {
  createMaintenanceMiddleware,
  defaultMaintenance,
};
