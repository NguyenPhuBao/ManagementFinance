/**
 * Unit Test — Notification Controller & REST API (TDD Red -> Green -> Refactor)
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const notificationController = require('../../modules/notification/notification.controller');
const notificationService = require('../../modules/notification/notification.service');
const { NotificationStore } = require('../../modules/notification/notification.store');

describe('NotificationController — Quản lý API Thông Báo (User & Admin)', () => {
  let mockStore;

  function createMockRes() {
    const res = {
      statusCode: 200,
      body: null,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.body = data;
        return this;
      },
    };
    return res;
  }

  beforeEach(async () => {
    mockStore = new NotificationStore({ redisClient: null, maxItemsPerUser: 10 });
    notificationService.setStore(mockStore);

    // Chuẩn bị dữ liệu mẫu cho user 100
    await mockStore.addNotification(100, { title: 'Thông báo 1', message: 'Nội dung 1' });
    await mockStore.addNotification(100, { title: 'Thông báo 2', message: 'Nội dung 2' });

    // Chuẩn bị dữ liệu mẫu cho Admin
    await mockStore.addAdminNotification({ title: 'Cảnh báo CPU', level: 'CRITICAL' });
  });

  describe('1. User Endpoints', () => {
    it('1.1. getMyNotifications trả về danh sách thông báo của user đăng nhập', async () => {
      const req = {
        user: { idaccount: 100 },
        query: { page: 1, limit: 10 },
      };
      const res = createMockRes();

      await notificationController.getMyNotifications(req, res);

      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.data.notifications.length, 2);
      assert.strictEqual(res.body.data.unreadCount, 2);
    });

    it('1.2. getUnreadCount trả về số lượng chưa đọc', async () => {
      const req = { user: { idaccount: 100 } };
      const res = createMockRes();

      await notificationController.getUnreadCount(req, res);

      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.data.unreadCount, 2);
    });

    it('1.3. markAsRead đánh dấu 1 thông báo thành công', async () => {
      const { notifications } = await mockStore.getNotifications(100);
      const targetId = notifications[0].id;

      const req = {
        user: { idaccount: 100 },
        params: { id: targetId },
      };
      const res = createMockRes();

      await notificationController.markAsRead(req, res);

      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.data.isRead, true);

      const count = await mockStore.getUnreadCount(100);
      assert.strictEqual(count, 1);
    });

    it('1.4. markAllAsRead đánh dấu toàn bộ thông báo đã đọc', async () => {
      const req = { user: { idaccount: 100 } };
      const res = createMockRes();

      await notificationController.markAllAsRead(req, res);

      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.data.affected, 2);

      const count = await mockStore.getUnreadCount(100);
      assert.strictEqual(count, 0);
    });
  });

  describe('2. Admin Endpoints', () => {
    it('2.1. getAdminAlerts trả về danh sách cảnh báo hệ thống cho Admin', async () => {
      const req = {
        user: { idaccount: 1, role: 'admin' },
        query: { page: 1, limit: 10 },
      };
      const res = createMockRes();

      await notificationController.getAdminAlerts(req, res);

      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.data.notifications.length, 1);
      assert.strictEqual(res.body.data.notifications[0].title, 'Cảnh báo CPU');
    });

    it('2.2. markAdminAlertAsRead đánh dấu cảnh báo admin đã đọc', async () => {
      const { notifications } = await mockStore.getAdminNotifications();
      const alertId = notifications[0].id;

      const req = { params: { id: alertId } };
      const res = createMockRes();

      await notificationController.markAdminAlertAsRead(req, res);

      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.data.isRead, true);
    });

    it('2.3. broadcast gửi thông báo tới toàn hệ thống', async () => {
      const req = {
        body: {
          title: 'Nâng cấp cụm máy chủ',
          message: 'Hệ thống bảo trì 15 phút vào đêm nay',
          level: 'WARNING',
        },
      };
      const res = createMockRes();

      await notificationController.broadcast(req, res);

      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.success, true);
      assert.strictEqual(res.body.data.title, 'Nâng cấp cụm máy chủ');
    });
  });

  describe('3. Validation Middleware', () => {
    const notificationValidation = require('../../modules/notification/notification.validation');

    it('3.1. validateBroadcast chặn request thiếu title hoặc message', () => {
      const req = { body: { title: '', message: '' } };
      const res = createMockRes();
      let nextCalled = false;

      notificationValidation.validateBroadcast(req, res, () => {
        nextCalled = true;
      });

      assert.strictEqual(nextCalled, false);
      assert.strictEqual(res.statusCode, 400);
    });

    it('3.2. validatePagination chặn page hoặc limit không hợp lệ', () => {
      const req = { query: { page: -1, limit: 200 } };
      const res = createMockRes();
      let nextCalled = false;

      notificationValidation.validatePagination(req, res, () => {
        nextCalled = true;
      });

      assert.strictEqual(nextCalled, false);
      assert.strictEqual(res.statusCode, 400);
    });

    it('3.3. validatePagination cho phép tham số hợp lệ gọi next()', () => {
      const req = { query: { page: 2, limit: 50 } };
      const res = createMockRes();
      let nextCalled = false;

      notificationValidation.validatePagination(req, res, () => {
        nextCalled = true;
      });

      assert.strictEqual(nextCalled, true);
    });
  });
});

