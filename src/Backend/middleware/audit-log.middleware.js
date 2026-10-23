const authService = require('../modules/auth/auth.service');
const logger = require('../core/logger');

/**
 * Middleware ghi nhận yêu cầu từ client vào bảng audit_log song song (non-blocking)
 * và phát sự kiện realtime lên Dashboard qua Socket.io.
 */
function auditLogMiddleware(req, res, next) {
  const time_req = new Date();

  let logged = false;

  // Bắt sự kiện request bị client ngắt kết nối giữa chừng
  req.on('aborted', () => {
    req.auditStatus = 'Interrupted';
  });

  const handleLog = (isInterrupted = false) => {
    if (logged) return;
    logged = true;

    // Chỉ coi là ngắt quãng nếu phản hồi CHƯA hoàn thành (socket bị đóng khi chưa hoàn tất ghi response)
    const isCompleted = Boolean(res.writableEnded || res.finished);
    if (!isCompleted && (isInterrupted || req.aborted)) {
      req.auditStatus = 'Interrupted';
    }

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
        path.includes('/admin/getusertotime') ||
        path.includes('/admin/login-stats') ||
        path.includes('/admin/request-stats') ||
        path.includes('/admin/aiops') ||
        path.includes('/admin/system/health') ||
        (req.method === 'GET' && path.includes('/admin/system/maintenance')) ||
        path.includes('/admin/maintenance/status') ||
        path.includes('/admin/audit-logs')
      ) {
        return;
      }

      const clientIp = req.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || req.socket?.remoteAddress || '127.0.0.1';
      const req_status = authService.determineReqStatus(res, req);
      const reason = authService.determineReqReason(res, req);
      const actionName = authService.formatActionName(req.method, path, req);
      const apiEndpoint = `${req.method.toUpperCase()} ${path}`;

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
            // Không ghi CSDL PostgreSQL để bảo toàn NOT NULL / FK constraint mà không vi phạm Rule 10
            // NHƯNG PHÁT Real-time Socket Event lên Admin-web để giám sát an ninh tức thời
            const { emitAuditActivity } = require('../core/socket');
            const timeReqIso = time_req.toISOString();
            const timeResIso = time_res.toISOString();
            const timeFormatted = typeof authService.formatVnTime === 'function' ? authService.formatVnTime(time_req) : 'Vừa xong';

            emitAuditActivity({
              id: Date.now(),
              idlog: Date.now(),
              idaccount: null,
              user: identifier || 'Anonymous / Guest',
              username: identifier || 'Guest',
              ip: clientIp,
              action: actionName,
              request: apiEndpoint,
              reason: reason || (res.statusCode === 429 ? 'Vượt quá giới hạn tần suất (Rate Limit)' : res.statusCode === 401 ? 'Chưa xác thực' : null),
              status: req_status,
              req_status,
              time: timeFormatted,
              timeReq: timeReqIso,
              timeRes: timeResIso,
              time_req: timeReqIso,
              time_res: timeResIso,
            });
            return;
          }

          await authService.recordAuditLog({
            idaccount: Number(targetId),
            request: apiEndpoint,
            action: actionName,
            req_status,
            reason,
            time_req,
            time_res,
            userDetails,
            ip: clientIp,
          });
        } catch (err) {
          logger.error('[AuditLog] Error saving log', { error: err.message, path });
        }
      });
    } catch (err) {
      logger.error('[AuditLog] Unexpected error in middleware log handler', { error: err.message });
    }
  };

  res.on('finish', () => handleLog(false));
  res.on('close', () => {
    if (!res.writableEnded) {
      handleLog(true);
    }
  });

  next();
}

module.exports = auditLogMiddleware;
