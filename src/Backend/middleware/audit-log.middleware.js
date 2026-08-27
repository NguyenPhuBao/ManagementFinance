const authService = require('../modules/auth/auth.service');
const logger = require('../core/logger');

/**
 * Middleware ghi nhận yêu cầu từ client vào bảng audit_log song song (non-blocking)
 * và phát sự kiện realtime lên Dashboard qua Socket.io.
 */
function auditLogMiddleware(req, res, next) {
  const time_req = new Date();

  // Bắt sự kiện request bị client ngắt kết nối giữa chừng
  req.on('aborted', () => {
    req.auditStatus = 'Interrupted';
  });

  // Lắng nghe sự kiện finish khi response đã hoàn tất gửi về client
  res.on('finish', () => {
    try {
      const time_res = new Date();
      const path = req.baseUrl ? `${req.baseUrl}${req.path}` : (req.originalUrl || req.url || '');

      // Bỏ qua các endpoint nội bộ/health check/options và các API polling thống kê của Admin
      if (
        req.method === 'OPTIONS' ||
        path.startsWith('/health') ||
        !path.startsWith('/api') ||
        path.includes('/auth/recent-activities') ||
        path.includes('/admin/totaluser') ||
        path.includes('/admin/totalcategories') ||
        path.includes('/admin/getusertotime')
      ) {
        return;
      }

      const req_status = authService.determineReqStatus(res, req);
      const actionName = authService.formatActionName(req.method, path);

      // Xác định idaccount đã xác thực hoặc từ payload
      const initialId = req.user?.idaccount || req.auditAccountId;
      const initialUser = {
        idaccount: initialId,
        fullname: req.user?.fullname || req.user?.name || req.auditAccountFullname || null,
        username: req.user?.username || req.auditAccountUsername || null,
      };

      const identifier = !initialId && req.body ? (req.body.username || req.body.email || req.body.identifier) : null;

      // Ghi nhận bất đồng bộ vào CSDL & phát socket (non-blocking)
      setImmediate(async () => {
        try {
          let targetId = initialId;
          let userDetails = initialUser;

          // Nếu chưa có idaccount nhưng có username/email gửi lên (ví dụ login sai mật khẩu -> Rejected)
          if (!targetId && identifier) {
            const authRepository = require('../modules/auth/auth.repository');
            const found = await authRepository.findAccountByUsernameOrEmail(identifier);
            if (found) {
              targetId = found.idaccount;
              userDetails = {
                idaccount: found.idaccount,
                fullname: found.User?.fullname || null,
                username: found.username,
              };
            }
          }

          if (!targetId) {
            return;
          }

          await authService.recordAuditLog({
            idaccount: Number(targetId),
            request: actionName,
            req_status,
            time_req,
            time_res,
            userDetails,
          });
        } catch (err) {
          logger.error('[AuditLog] Error saving log', { error: err.message, path });
        }
      });
    } catch (err) {
      logger.error('[AuditLog] Unexpected error in middleware finish handler', { error: err.message });
    }
  });

  next();
}

module.exports = auditLogMiddleware;
