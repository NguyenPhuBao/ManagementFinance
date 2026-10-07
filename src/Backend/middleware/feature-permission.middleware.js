const ResponseHandler = require('../core/response-handler');
const permissionRepository = require('../modules/payment/permission.repository');
const { prisma } = require('../config/db');
const logger = require('../core/logger');

/**
 * Middleware kiểm tra quyền sử dụng tính năng theo loại tài khoản (Role/Account Type)
 * @param {string} featureId - Mã tính năng (ví dụ: 'ai_assistant', 'ai_quick_input', 'ocr_receipt')
 */
function requireFeature(featureId) {
  return async (req, res, next) => {
    try {
      const idaccount = req.user?.idaccount;
      if (!idaccount) {
        return ResponseHandler.unauthorized(res, 'Vui lòng đăng nhập để sử dụng tính năng này');
      }

      // 1. Quản trị viên (Admin) luôn có toàn quyền truy cập mọi tính năng
      if (req.user?.idrole === 1 || String(req.user?.rolename || '').toLowerCase() === 'admin') {
        return next();
      }

      // 2. Tra cứu loại tài khoản thực tế và hạn Premium từ CSDL (chống gian lận token cũ)
      let effectiveType = req.user?.type || 'Basic';
      try {
        const account = await prisma.account.findUnique({
          where: { idaccount: Number(idaccount) },
          select: { type: true, premium_expires_at: true },
        });

        if (account) {
          effectiveType = account.type || 'Basic';
          if (effectiveType === 'Premium' && account.premium_expires_at && new Date(account.premium_expires_at) < new Date()) {
            effectiveType = 'Basic';
          }
        }
      } catch (dbErr) {
        logger.warn('[Permission Guard] Lỗi truy vấn tài khoản, dùng type từ token:', dbErr.message);
      }

      // 3. Đọc cấu hình quyền từ permissionRepository
      const { features } = await permissionRepository.getPermissionsByAccountType(effectiveType);

      // 4. Nếu tính năng bị tắt (false), từ chối với HTTP 403 Forbidden
      if (features && features[featureId] === false) {
        logger.warn(`[Permission Guard] Chặn truy cập tính năng '${featureId}' cho tài khoản ${idaccount} (Gói ${effectiveType})`);
        return ResponseHandler.forbidden(
          res,
          `Tính năng này chưa được kích hoạt cho loại tài khoản ${effectiveType}. Vui lòng nâng cấp gói để tiếp tục sử dụng!`,
          {
            code: 'FEATURE_DISABLED',
            featureId,
            accountType: effectiveType,
          }
        );
      }

      next();
    } catch (error) {
      logger.error(`[Permission Guard] Lỗi kiểm tra quyền tính năng '${featureId}':`, error);
      // Fallback an toàn: Cho qua để tránh chặn nhầm người dùng hợp lệ khi lỗi hệ thống
      next();
    }
  };
}

module.exports = { requireFeature };
