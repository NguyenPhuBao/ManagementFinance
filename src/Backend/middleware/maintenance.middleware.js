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

    // 1. Ngoại lệ đặc quyền: Admin và Health Check probe luôn được phép truy cập
    const isHealthCheck = (req.path && req.path.startsWith('/health')) ||
      (req.originalUrl && req.originalUrl.startsWith('/health'));

    const isAdmin = req.isAdmin === true ||
      (req.path && req.path.startsWith('/api/admin')) ||
      (req.originalUrl && req.originalUrl.startsWith('/api/admin'));

    if (isAdmin || isHealthCheck) {
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
