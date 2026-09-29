/**
 * Notification Controller — Xử lý các REST API Endpoint thông báo
 */

const notificationService = require('./notification.service');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const notificationController = {
  /**
   * GET /api/notifications
   * Lấy danh sách thông báo của người dùng hiện hành
   */
  async getMyNotifications(req, res) {
    try {
      const idaccount = req.user?.idaccount;
      if (!idaccount) {
        return ResponseHandler.unauthorized(res, 'Chưa xác thực người dùng');
      }

      const { page, limit, unreadOnly } = req.query;
      const store = notificationService.getStore();
      const result = await store.getNotifications(idaccount, {
        page,
        limit,
        unreadOnly: unreadOnly === 'true' || unreadOnly === true,
      });

      return ResponseHandler.success(res, result, 'Lấy danh sách thông báo thành công');
    } catch (error) {
      logger.error('[NotificationController] getMyNotifications error', { error: error.message });
      return ResponseHandler.error(res, 'Không thể tải danh sách thông báo');
    }
  },

  /**
   * GET /api/notifications/unread-count
   * Đếm số lượng thông báo chưa đọc của người dùng
   */
  async getUnreadCount(req, res) {
    try {
      const idaccount = req.user?.idaccount;
      if (!idaccount) {
        return ResponseHandler.unauthorized(res, 'Chưa xác thực người dùng');
      }

      const store = notificationService.getStore();
      const unreadCount = await store.getUnreadCount(idaccount);

      return ResponseHandler.success(res, { unreadCount }, 'Lấy số thông báo chưa đọc thành công');
    } catch (error) {
      logger.error('[NotificationController] getUnreadCount error', { error: error.message });
      return ResponseHandler.error(res, 'Không thể lấy số lượng thông báo chưa đọc');
    }
  },

  /**
   * PATCH /api/notifications/:id/read
   * Đánh dấu 1 thông báo là đã đọc
   */
  async markAsRead(req, res) {
    try {
      const idaccount = req.user?.idaccount;
      const notificationId = req.params.id;

      if (!idaccount) {
        return ResponseHandler.unauthorized(res, 'Chưa xác thực người dùng');
      }

      const store = notificationService.getStore();
      const updated = await store.markAsRead(idaccount, notificationId);

      if (!updated) {
        return ResponseHandler.notFound(res, 'Không tìm thấy thông báo hoặc thông báo đã bị xóa');
      }

      return ResponseHandler.success(res, updated, 'Đã đánh dấu thông báo là đã đọc');
    } catch (error) {
      logger.error('[NotificationController] markAsRead error', { error: error.message });
      return ResponseHandler.error(res, 'Không thể cập nhật trạng thái thông báo');
    }
  },

  /**
   * POST /api/notifications/read-all
   * Đánh dấu tất cả thông báo của người dùng là đã đọc
   */
  async markAllAsRead(req, res) {
    try {
      const idaccount = req.user?.idaccount;
      if (!idaccount) {
        return ResponseHandler.unauthorized(res, 'Chưa xác thực người dùng');
      }

      const store = notificationService.getStore();
      const affected = await store.markAllAsRead(idaccount);

      return ResponseHandler.success(res, { affected }, 'Đã đánh dấu tất cả thông báo là đã đọc');
    } catch (error) {
      logger.error('[NotificationController] markAllAsRead error', { error: error.message });
      return ResponseHandler.error(res, 'Không thể cập nhật tất cả thông báo');
    }
  },

  /**
   * GET /api/notifications/admin
   * Lấy danh sách cảnh báo hệ thống dành cho Admin
   */
  async getAdminAlerts(req, res) {
    try {
      const { page, limit, unreadOnly } = req.query;
      const store = notificationService.getStore();
      const result = await store.getAdminNotifications({
        page,
        limit,
        unreadOnly: unreadOnly === 'true' || unreadOnly === true,
      });

      return ResponseHandler.success(res, result, 'Lấy danh sách cảnh báo hệ thống thành công');
    } catch (error) {
      logger.error('[NotificationController] getAdminAlerts error', { error: error.message });
      return ResponseHandler.error(res, 'Không thể tải danh sách cảnh báo hệ thống');
    }
  },

  /**
   * PATCH /api/notifications/admin/:id/read
   * Đánh dấu cảnh báo Admin đã đọc
   */
  async markAdminAlertAsRead(req, res) {
    try {
      const notificationId = req.params.id;
      const store = notificationService.getStore();
      const updated = await store.markAdminAsRead(notificationId);

      if (!updated) {
        return ResponseHandler.notFound(res, 'Không tìm thấy cảnh báo');
      }

      return ResponseHandler.success(res, updated, 'Đã đánh dấu cảnh báo là đã đọc');
    } catch (error) {
      logger.error('[NotificationController] markAdminAlertAsRead error', { error: error.message });
      return ResponseHandler.error(res, 'Không thể cập nhật trạng thái cảnh báo');
    }
  },

  /**
   * POST /api/notifications/broadcast
   * Admin phát thông báo tới tất cả người dùng và ghi nhận
   */
  async broadcast(req, res) {
    try {
      const { title, message, level, metadata } = req.body || {};
      const result = await notificationService.broadcast({
        title,
        message,
        level: level || 'INFO',
        metadata: metadata || {},
      });

      return ResponseHandler.success(res, result, 'Phát thông báo toàn hệ thống thành công');
    } catch (error) {
      logger.error('[NotificationController] broadcast error', { error: error.message });
      return ResponseHandler.error(res, 'Không thể phát thông báo hệ thống');
    }
  },
};

module.exports = notificationController;
