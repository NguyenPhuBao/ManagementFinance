/**
 * Notification Validation Middleware
 */

const ResponseHandler = require('../../core/response-handler');

const notificationValidation = {
  /**
   * Validate thông số phân trang
   */
  validatePagination(req, res, next) {
    const page = parseInt(req.query.page, 10);
    const limit = parseInt(req.query.limit, 10);

    if (req.query.page !== undefined && (isNaN(page) || page < 1)) {
      return ResponseHandler.badRequest(res, 'Tham số page phải là số nguyên dương >= 1');
    }
    if (req.query.limit !== undefined && (isNaN(limit) || limit < 1 || limit > 100)) {
      return ResponseHandler.badRequest(res, 'Tham số limit phải là số nguyên từ 1 đến 100');
    }
    next();
  },

  /**
   * Validate body gửi thông báo Broadcast
   */
  validateBroadcast(req, res, next) {
    const { title, message, level } = req.body || {};

    if (!title || typeof title !== 'string' || title.trim().length < 3) {
      return ResponseHandler.badRequest(res, 'Tiêu đề thông báo (title) là bắt buộc và phải có ít nhất 3 ký tự');
    }
    if (title.length > 200) {
      return ResponseHandler.badRequest(res, 'Tiêu đề thông báo không được vượt quá 200 ký tự');
    }

    if (!message || typeof message !== 'string' || message.trim().length < 3) {
      return ResponseHandler.badRequest(res, 'Nội dung thông báo (message) là bắt buộc và phải có ít nhất 3 ký tự');
    }
    if (message.length > 2000) {
      return ResponseHandler.badRequest(res, 'Nội dung thông báo không được vượt quá 2000 ký tự');
    }

    if (level && !['INFO', 'WARNING', 'CRITICAL'].includes(level.toUpperCase())) {
      return ResponseHandler.badRequest(res, 'Mức độ cảnh báo (level) phải là một trong: INFO, WARNING, CRITICAL');
    }

    next();
  },
};

module.exports = notificationValidation;
