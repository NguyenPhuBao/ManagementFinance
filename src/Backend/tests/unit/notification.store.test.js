/**
 * Unit Test — Notification Store (TDD Red -> Green -> Refactor)
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const { NotificationStore } = require('../../modules/notification/notification.store');

describe('NotificationStore — Lưu trữ & Quản lý Thông báo (User & Admin)', () => {
  let store;

  beforeEach(() => {
    // Khởi tạo store với in-memory fallback (redisClient: null)
    store = new NotificationStore({
      redisClient: null,
      maxItemsPerUser: 5, // Đặt giới hạn 5 để kiểm tra auto-trimming
      ttlSeconds: 3600,
    });
  });

  describe('1. Quản lý thông báo người dùng (User-scoped)', () => {
    it('1.1. Thêm thông báo mới thành công với đầy đủ metadata', async () => {
      const notif = await store.addNotification('acc_user_1', {
        title: 'OCR hoàn tất',
        message: 'Hóa đơn đã được quét thành công',
        type: 'OCR_COMPLETED',
        metadata: { billId: 'bill_123' },
      });

      assert.ok(notif.id, 'Phải có UUID id');
      assert.strictEqual(notif.idaccount, 'acc_user_1');
      assert.strictEqual(notif.title, 'OCR hoàn tất');
      assert.strictEqual(notif.isRead, false);
      assert.ok(notif.createdAt, 'Phải có timestamp createdAt');
    });

    it('1.2. Lấy danh sách thông báo và đếm số chưa đọc', async () => {
      await store.addNotification('acc_user_1', { title: 'Thông báo 1', type: 'INFO' });
      await store.addNotification('acc_user_1', { title: 'Thông báo 2', type: 'INFO' });

      const result = await store.getNotifications('acc_user_1', { page: 1, limit: 10 });
      assert.strictEqual(result.total, 2);
      assert.strictEqual(result.unreadCount, 2);
      assert.strictEqual(result.notifications.length, 2);
      // Mới nhất lên đầu (LIFO)
      assert.strictEqual(result.notifications[0].title, 'Thông báo 2');
    });

    it('1.3. Đánh dấu một thông báo đã đọc', async () => {
      const notif = await store.addNotification('acc_user_1', { title: 'Thông báo 1', type: 'INFO' });
      const updated = await store.markAsRead('acc_user_1', notif.id);

      assert.strictEqual(updated.isRead, true);
      assert.ok(updated.readAt, 'Phải có timestamp readAt');

      const count = await store.getUnreadCount('acc_user_1');
      assert.strictEqual(count, 0);
    });

    it('1.4. Đánh dấu tất cả thông báo đã đọc', async () => {
      await store.addNotification('acc_user_1', { title: 'Notif 1', type: 'INFO' });
      await store.addNotification('acc_user_1', { title: 'Notif 2', type: 'INFO' });

      const affected = await store.markAllAsRead('acc_user_1');
      assert.strictEqual(affected, 2);

      const unread = await store.getUnreadCount('acc_user_1');
      assert.strictEqual(unread, 0);
    });

    it('1.5. Lọc thông báo chưa đọc (unreadOnly: true)', async () => {
      const n1 = await store.addNotification('acc_user_1', { title: 'Notif 1', type: 'INFO' });
      await store.addNotification('acc_user_1', { title: 'Notif 2', type: 'INFO' });

      await store.markAsRead('acc_user_1', n1.id);

      const unreadList = await store.getNotifications('acc_user_1', { unreadOnly: true });
      assert.strictEqual(unreadList.notifications.length, 1);
      assert.strictEqual(unreadList.notifications[0].title, 'Notif 2');
    });

    it('1.6. Tự động cắt tỉa (Trim) khi vượt quá giới hạn maxItemsPerUser (5 mục)', async () => {
      for (let i = 1; i <= 7; i++) {
        await store.addNotification('acc_user_1', { title: `Notif ${i}`, type: 'INFO' });
      }

      const list = await store.getNotifications('acc_user_1', { page: 1, limit: 10 });
      assert.strictEqual(list.total, 5, 'Chỉ được giữ 5 thông báo gần nhất');
      assert.strictEqual(list.notifications[0].title, 'Notif 7', 'Thông báo mới nhất phải là Notif 7');
      assert.strictEqual(list.notifications[4].title, 'Notif 3', 'Thông báo cũ nhất còn lưu là Notif 3');
    });

    it('1.7. Phân lập dữ liệu hoàn toàn giữa các tài khoản khác nhau', async () => {
      await store.addNotification('user_A', { title: 'Tin của A' });
      await store.addNotification('user_B', { title: 'Tin của B' });

      const listA = await store.getNotifications('user_A');
      const listB = await store.getNotifications('user_B');

      assert.strictEqual(listA.total, 1);
      assert.strictEqual(listA.notifications[0].title, 'Tin của A');
      assert.strictEqual(listB.total, 1);
      assert.strictEqual(listB.notifications[0].title, 'Tin của B');
    });

    it('1.8. Đồng nhất truy xuất dữ liệu khi idaccount truyền vào dạng Number hoặc String', async () => {
      // Thêm bằng Number
      await store.addNotification(999, { title: 'Thêm bằng Number' });
      
      // Truy xuất bằng String
      const listWithString = await store.getNotifications('999');
      assert.strictEqual(listWithString.total, 1);
      assert.strictEqual(listWithString.notifications[0].title, 'Thêm bằng Number');

      // Đánh dấu đã đọc bằng String
      const affected = await store.markAllAsRead('999');
      assert.strictEqual(affected, 1);

      // Đếm số chưa đọc bằng Number
      const unreadCount = await store.getUnreadCount(999);
      assert.strictEqual(unreadCount, 0);
    });
  });


  describe('2. Quản lý thông báo Admin (Admin-scoped)', () => {
    it('2.1. Thêm cảnh báo hệ thống cho Admin', async () => {
      const alert = await store.addAdminNotification({
        title: 'Cảnh báo quá tải hệ thống',
        message: 'Event Loop Lag > 150ms',
        level: 'WARNING',
        category: 'LOAD_SHEDDING',
      });

      assert.ok(alert.id);
      assert.strictEqual(alert.isRead, false);
      assert.strictEqual(alert.level, 'WARNING');

      const adminList = await store.getAdminNotifications();
      assert.strictEqual(adminList.total, 1);
      assert.strictEqual(adminList.unreadCount, 1);
      assert.strictEqual(adminList.notifications[0].title, 'Cảnh báo quá tải hệ thống');
    });

    it('2.2. Đánh dấu cảnh báo Admin đã đọc', async () => {
      const alert = await store.addAdminNotification({
        title: 'DB Pool > 80%',
        level: 'CRITICAL',
      });

      const updated = await store.markAdminAsRead(alert.id);
      assert.strictEqual(updated.isRead, true);

      const unreadCount = (await store.getAdminNotifications({ unreadOnly: true })).total;
      assert.strictEqual(unreadCount, 0);
    });
  });
});
