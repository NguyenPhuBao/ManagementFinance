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

    // 3. Nhận diện kênh quản trị Admin-web qua Header hoặc Origin/Referer
    const clientPlatform = (req.headers && (req.headers['x-client-platform'] || req.headers['x-client-type'])) || '';
    const origin = (req.headers && (req.headers.origin || req.headers.referer)) || '';
    const isAdminWebOrigin = origin.includes('management-finance-gamma.vercel.app') ||
                             origin.includes('localhost:5173') ||
                             origin.includes('localhost:3000') ||
                             origin.includes('localhost:5174');

    if (clientPlatform === 'admin-web' || isAdminWebOrigin) {
      req.isAdminWebClient = true;
      // Nếu là request xác thực hoặc quản trị từ Admin-web thì đánh dấu ưu tiên Fast-Lane
      if (
        url.includes('/auth/login') ||
        url.includes('/auth/refresh') ||
        url.startsWith('/api/admin') ||
        url.startsWith('/health/admin')
      ) {
        req.isAdmin = true;
        return next();
      }
    }

    // 4. Nhận diện sớm qua Authorization Bearer Token nếu role là admin
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
