/**
 * Admin Priority Middleware
 * Nhận diện lưu lượng ưu tiên từ Admin-web (Fast-Lane)
 * Đảm bảo Admin luôn có lối thoát hiểm khi hệ thống nghẽn, đơ
 */

const jwt = require('jsonwebtoken');
const config = require('../config');

function createAdminPriorityMiddleware(options = {}) {
  const emergencyKey = options.emergencyKey || process.env.ADMIN_EMERGENCY_KEY;

  return function adminPriorityMiddleware(req, res, next) {
    const url = req.originalUrl || req.path || '';

    // 1. Nhận diện qua URL path Admin
    if (url.startsWith('/api/admin') || url.startsWith('/health/admin')) {
      req.isAdmin = true;
      return next();
    }

    // 2. Nhận diện qua Khóa khẩn cấp (Emergency Admin Key)
    const reqEmergencyKey = req.headers && req.headers['x-emergency-admin-key'];
    if (emergencyKey && reqEmergencyKey && reqEmergencyKey === emergencyKey) {
      req.isAdmin = true;
      return next();
    }

    // 3. Nhận diện sớm qua Authorization Bearer Token nếu role là admin
    const authHeader = req.headers && (req.headers.authorization || req.headers['authorization']);
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      try {
        const decoded = jwt.decode(token);
        if (decoded && (decoded.role === 'admin' || decoded.role === 'ADMIN')) {
          req.isAdmin = true;
          return next();
        }
      } catch (err) {
        // Bỏ qua lỗi parse token, để middleware authenticate phía sau xử lý
      }
    }

    req.isAdmin = false;
    next();
  };
}

const defaultAdminPriority = createAdminPriorityMiddleware();

module.exports = {
  createAdminPriorityMiddleware,
  defaultAdminPriority,
};
