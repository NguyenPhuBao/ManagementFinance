/**
 * Admin Priority Middleware
 * Nhận diện lưu lượng ưu tiên thực sự từ Quản trị viên (Fast-Lane)
 * Đảm bảo Admin luôn có lối thoát hiểm khi hệ thống nghẽn, đơ
 * 
 * Nguyên tắc bảo mật (Data_Security.md & SOAT_UU_TIEN_ADMIN_VA_CHAN_IP.md):
 * - Chỉ ưu tiên dựa trên điều SERVER TỰ KIỂM CHỨNG ĐƯỢC:
 *   1. Khóa khẩn cấp phía server (x-emergency-admin-key) so khớp bằng crypto.timingSafeEqual.
 *   2. Chữ ký số JWT token hợp lệ do server phát hành (jwt.verify) mang role admin.
 *   3. Route nội bộ dành riêng cho admin (/api/admin, /health/admin).
 * - Thứ client tự gửi (x-client-platform, Origin, Referer) CHỈ làm nhãn thống kê, KHÔNG cấp isAdmin.
 */

const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const config = require('../config');

function createAdminPriorityMiddleware(options = {}) {
  const emergencyKey = options.emergencyKey || process.env.ADMIN_EMERGENCY_KEY;
  const jwtSecret = options.jwtSecret || (config.jwt && (config.jwt.accessSecret || config.jwt.secret)) || process.env.JWT_ACCESS_SECRET || process.env.JWT_SECRET || 'secret';

  return function adminPriorityMiddleware(req, res, next) {
    const url = req.originalUrl || req.path || '';

    // 1. Nhận diện qua URL path Admin nội bộ
    if (url.startsWith('/api/admin') || url.startsWith('/health/admin')) {
      req.isAdmin = true;
      return next();
    }

    // 2. Nhận diện qua Khóa khẩn cấp (Emergency Admin Key) với so khớp Timing-Safe
    const reqEmergencyKey = req.headers && req.headers['x-emergency-admin-key'];
    if (emergencyKey && reqEmergencyKey && typeof reqEmergencyKey === 'string') {
      try {
        const bufReq = Buffer.from(reqEmergencyKey);
        const bufKey = Buffer.from(emergencyKey);
        if (bufReq.length === bufKey.length && crypto.timingSafeEqual(bufReq, bufKey)) {
          req.isAdmin = true;
          return next();
        }
      } catch (_) {}
    }

    // 3. Nhận diện kênh quản trị Admin-web qua Header hoặc Origin/Referer
    // CHỈ gán cờ nhãn phục vụ thống kê/audit log, TUYỆT ĐỐI KHÔNG cấp req.isAdmin
    const clientPlatform = (req.headers && (req.headers['x-client-platform'] || req.headers['x-client-type'])) || '';
    const origin = (req.headers && (req.headers.origin || req.headers.referer)) || '';
    const isAdminWebOrigin = origin.includes('management-finance-gamma.vercel.app') ||
                             origin.includes('localhost:5173') ||
                             origin.includes('localhost:3000') ||
                             origin.includes('localhost:5174');

    if (clientPlatform === 'admin-web' || isAdminWebOrigin) {
      req.isAdminWebClient = true;
    }

    // 4. Nhận diện sớm qua Authorization Bearer Token ĐƯỢC SERVER XÁC THỰC CHỮ KÝ (jwt.verify)
    const authHeader = req.headers && (req.headers.authorization || req.headers['authorization']);
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      try {
        const decoded = jwt.verify(token, jwtSecret);
        const role = decoded && (decoded.rolename || decoded.role);
        if (decoded && (decoded.idrole === 1 || String(role || '').toLowerCase() === 'admin')) {
          req.isAdmin = true;
          return next();
        }
      } catch (err) {
        // Token giả mạo, sai chữ ký hoặc hết hạn -> Bỏ qua, tuyệt đối không cấp req.isAdmin
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
