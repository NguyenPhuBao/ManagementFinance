const express = require('express');
const router = express.Router();
const notificationController = require('../modules/notification/notification.controller');
const notificationValidation = require('../modules/notification/notification.validation');
const { authenticate } = require('../middleware/auth');
const authorize = require('../middleware/authorize');

// Tất cả notification routes đều yêu cầu đăng nhập
router.use(authenticate);

// === 1. User Endpoints ===
// Lấy danh sách thông báo của tài khoản hiện tại
router.get('/', notificationValidation.validatePagination, notificationController.getMyNotifications);

// Đếm số lượng thông báo chưa đọc
router.get('/unread-count', notificationController.getUnreadCount);

// Đánh dấu 1 thông báo là đã đọc
router.patch('/:id/read', notificationController.markAsRead);

// Đánh dấu tất cả thông báo là đã đọc
router.post('/read-all', notificationController.markAllAsRead);

// === 2. Admin Endpoints ===
// Lấy danh sách cảnh báo hệ thống (Chỉ Admin)
router.get(
  '/admin',
  authorize('admin'),
  notificationValidation.validatePagination,
  notificationController.getAdminAlerts
);

// Đánh dấu 1 cảnh báo hệ thống là đã đọc (Chỉ Admin)
router.patch(
  '/admin/:id/read',
  authorize('admin'),
  notificationController.markAdminAlertAsRead
);

// Phát thông báo Broadcast toàn hệ thống (Chỉ Admin)
router.post(
  '/broadcast',
  authorize('admin'),
  notificationValidation.validateBroadcast,
  notificationController.broadcast
);

module.exports = router;
