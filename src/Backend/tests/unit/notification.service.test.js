/**
 * Unit Test — Notification Service & Socket Integration (TDD Red -> Green -> Refactor)
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const notificationService = require('../../modules/notification/notification.service');
const { NotificationStore } = require('../../modules/notification/notification.store');
const eventBus = require('../../core/event-bus');
const socket = require('../../core/socket');

describe('NotificationService — Xử lý sự kiện EventBus & Phát Realtime', () => {
  let mockStore;
  let emittedSocketEvents = [];

  beforeEach(() => {
    emittedSocketEvents = [];

    // Tạo store độc lập cho test
    mockStore = new NotificationStore({ redisClient: null, maxItemsPerUser: 10 });
    notificationService.setStore(mockStore);

    // Mock các socket emitter để bắt sự kiện
    socket.emitOcrCompleted = (idaccount, data) => {
      emittedSocketEvents.push({ event: 'ocr.completed', idaccount, data });
    };
    socket.emitOcrDuplicate = (idaccount, data) => {
      emittedSocketEvents.push({ event: 'ocr.duplicate', idaccount, data });
    };
    socket.emitAdminNotification = (data) => {
      emittedSocketEvents.push({ event: 'admin.notification', data });
    };
    socket.emitSystemBroadcast = (data) => {
      emittedSocketEvents.push({ event: 'system.broadcast', data });
    };
  });

  it('1. Khởi tạo listeners và xử lý sự kiện ocr.completed: lưu Store & phát Socket', async () => {
    await notificationService.initNotificationListeners();

    // Giả lập phát sự kiện từ AI OCR module
    await eventBus.publish('ocr.completed', {
      idaccount: 101,
      document_type: 'invoice',
      detected_type: 'Purchase',
      merchant_name: 'Circle K',
      total_amount: 55000,
    });

    // 1. Kiểm tra Socket đã phát
    const socketEvent = emittedSocketEvents.find((e) => e.event === 'ocr.completed');
    assert.ok(socketEvent, 'Phải phát socket ocr.completed');
    assert.strictEqual(socketEvent.idaccount, 101);
    assert.ok(socketEvent.data.message.includes('Circle K'));

    // 2. Kiểm tra Store đã lưu thông báo
    const userNotifs = await mockStore.getNotifications(101);
    assert.strictEqual(userNotifs.total, 1);
    assert.strictEqual(userNotifs.notifications[0].type, 'OcrCompleted');
    assert.strictEqual(userNotifs.notifications[0].isRead, false);
  });

  it('2. Xử lý sự kiện cảnh báo quá tải system.overload: lưu Admin Store & phát admin.notification', async () => {
    await notificationService.initNotificationListeners();

    await eventBus.publish('system.overload', {
      title: 'Quá tải CPU',
      message: 'Event Loop Lag đạt 200ms',
      level: 'CRITICAL',
      category: 'LOAD_SHEDDING',
    });

    // 1. Kiểm tra Socket admin.notification
    const adminEvent = emittedSocketEvents.find((e) => e.event === 'admin.notification');
    assert.ok(adminEvent, 'Phải phát socket admin.notification');
    assert.strictEqual(adminEvent.data.level, 'CRITICAL');

    // 2. Kiểm tra Admin Store
    const adminNotifs = await mockStore.getAdminNotifications();
    assert.strictEqual(adminNotifs.total, 1);
    assert.strictEqual(adminNotifs.notifications[0].title, 'Quá tải CPU');
  });

  it('3. Hàm broadcast gửi thông báo tới tất cả người dùng và lưu Admin Store', async () => {
    const result = await notificationService.broadcast({
      title: 'Bảo trì hệ thống định kỳ',
      message: 'Hệ thống sẽ bảo trì từ 02:00 đến 03:00 sáng mai',
      level: 'WARNING',
    });

    assert.ok(result.id);
    const broadcastEvent = emittedSocketEvents.find((e) => e.event === 'system.broadcast');
    assert.ok(broadcastEvent, 'Phải phát socket system.broadcast');
    assert.strictEqual(broadcastEvent.data.title, 'Bảo trì hệ thống định kỳ');
  });

  it('4. Gửi thông báo trực tiếp cho người dùng (sendDirectNotification)', async () => {
    const notif = await notificationService.sendDirectNotification(202, {
      title: 'Nhắc nhở ngân sách',
      message: 'Bạn đã chi tiêu 90% hạn mức danh mục Ăn uống',
      type: 'BUDGET_WARNING',
    });

    assert.ok(notif.id);
    const check = await mockStore.getNotifications(202);
    assert.strictEqual(check.total, 1);
    assert.strictEqual(check.notifications[0].title, 'Nhắc nhở ngân sách');
  });
});
