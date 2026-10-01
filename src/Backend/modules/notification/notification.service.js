const eventBus = require('../../core/event-bus');
const defaultSocket = require('../../core/socket');
const logger = require('../../core/logger');

let currentStore = null;
let currentSocket = defaultSocket;
let isInitialized = false;

const notificationService = {
  /**
   * Thiết lập store tùy biến (dùng cho test hoặc DI)
   */
  setStore(store) {
    currentStore = store;
  },

  /**
   * Thiết lập socket module tùy biến
   */
  setSocket(socketModule) {
    currentSocket = socketModule || defaultSocket;
  },

  /**
   * Lấy NotificationStore hiện hành
   */
  getStore() {
    if (!currentStore) {
      const { defaultNotificationStore } = require('./notification.store');
      currentStore = defaultNotificationStore;
    }
    return currentStore;
  },

  getSocket() {
    return currentSocket || defaultSocket;
  },

  /**
   * Khởi tạo các listener lắng nghe sự kiện từ EventBus
   * Tách biệt hoàn toàn xử lý thông báo khỏi Module Bank & Module OCR
   */
  async initNotificationListeners() {
    if (isInitialized) {
      return;
    }

    try {
      if (eventBus && typeof eventBus.subscribe === 'function') {
        // 1. Lắng nghe sự kiện biến động số dư ngân hàng (legacy — Module Bank đã dừng 2026-09-18)
        // Subscriber được giữ nguyên để không phá vỡ kiến trúc event-driven.
        // KHÔNG lưu vào store user — accountNumber/amount là dữ liệu nhạy cảm (Data_Security.md §3)
        await eventBus.subscribe('bank_transaction.pending', async (data) => {
          // Không log accountNumber/amount — tuân thủ Data_Security.md
          logger.info('[Notification Module] bank_transaction.pending received (legacy — Bank module suspended 2026-09-18)', {
            idtran: data.idtran,
            idaccount: data.idaccount,
          });

          // Chỉ forward real-time qua socket cho client đang online, KHÔNG persist vào store
          // (tránh lộ accountNumber/amount qua GET /api/notifications)
          this.getSocket().emitBankTransaction(data.idaccount, {
            title: 'Giao dịch mới từ Ngân hàng',
            message: 'Bạn vừa có giao dịch từ ngân hàng. Nhấn để xem chi tiết.',
            type: 'BankTransactionPending',
            createdAt: new Date().toISOString(),
            // accountNumber và amount bị loại bỏ — Data_Security.md §3
          });
          // TODO: Fix EventBus double-fire khi Redis sẵn sàng (issue riêng — event-bus.js:47+54)
        });

        // 2. Lắng nghe sự kiện bóc tách và phân loại OCR hoàn tất
        await eventBus.subscribe('ocr.completed', async (data) => {
          logger.info('[Notification Module] Received ocr.completed event', {
            idaccount: data.idaccount,
            document_type: data.document_type,
            detected_type: data.detected_type,
          });

          const title = data.detected_type === 'Transfer'
            ? 'Biên lai chuyển tiền đã được bóc tách'
            : 'Hóa đơn đã được bóc tách thành công';

          const message = data.detected_type === 'Transfer'
            ? `Biên lai chuyển tiền ${Number(data.amount || 0).toLocaleString('vi-VN')}đ đã sẵn sàng để xác nhận.`
            : `Hóa đơn ${data.merchant_name || ''} (${Number(data.total_amount || 0).toLocaleString('vi-VN')}đ) đã được bóc tách và phân loại.`;

          const store = this.getStore();
          if (store && typeof store.addNotification === 'function') {
            await store.addNotification(data.idaccount, {
              title,
              message,
              type: 'OcrCompleted',
              metadata: data,
            });
          }

          this.getSocket().emitOcrCompleted(data.idaccount, {
            title,
            message,
            type: 'OcrCompleted',
            data,
            createdAt: new Date().toISOString(),
          });
        });

        // 3. Lắng nghe sự kiện giao dịch OCR bị trùng lặp
        await eventBus.subscribe('ocr.duplicate', async (data) => {
          logger.info('[Notification Module] Received ocr.duplicate event', {
            idaccount: data.idaccount,
            provider: data.provider,
            bank_tran_id: data.bank_tran_id,
            reason: data.reason,
          });

          const title = 'Giao dịch đã tồn tại';
          const message = 'Hình ảnh này trùng khớp với giao dịch đã được ghi nhận trên hệ thống trước đó.';

          const store = this.getStore();
          if (store && typeof store.addNotification === 'function') {
            await store.addNotification(data.idaccount, {
              title,
              message,
              type: 'OcrDuplicate',
              metadata: data,
            });
          }

          this.getSocket().emitOcrDuplicate(data.idaccount, {
            title,
            message,
            type: 'OcrDuplicate',
            data,
            createdAt: new Date().toISOString(),
          });
        });

        // 4. Lắng nghe sự kiện hoàn tất đồng bộ dữ liệu (Sync Engine)
        await eventBus.subscribe('sync.completed', async (data) => {
          logger.info('[Notification Module] Received sync.completed event', {
            idaccount: data.idaccount,
            summary: data.summary,
          });

          this.getSocket().emitSyncCompleted(data.idaccount, {
            summary: data.summary,
            timestamp: data.timestamp || new Date().toISOString(),
          });
        });

        // 5. Lắng nghe cảnh báo quá tải hệ thống (Load Shedding)
        await eventBus.subscribe('system.overload', async (data) => {
          logger.warn('[Notification Module] Received system.overload event', data);
          await this.sendAdminAlert({
            title: data.title || 'Cảnh báo quá tải hệ thống',
            message: data.message || '',
            level: data.level || 'CRITICAL',
            category: data.category || 'LOAD_SHEDDING',
            metadata: data.metadata || {},
          });
        });

        // 6. Lắng nghe cảnh báo bảo mật hệ thống
        await eventBus.subscribe('security.alert', async (data) => {
          logger.warn('[Notification Module] Received security.alert event', data);
          await this.sendAdminAlert({
            title: data.title || 'Cảnh báo bảo mật',
            message: data.message || '',
            level: data.level || 'WARNING',
            category: 'SECURITY',
            metadata: data.metadata || {},
          });
        });

        // 7. Lắng nghe thông báo đếm ngược ngừng hoạt động tài khoản
        await eventBus.subscribe('account.countdown', async (data) => {
          logger.info('[Notification Module] Received account.countdown event', data);
          const store = this.getStore();
          if (store && typeof store.addNotification === 'function') {
            await store.addNotification(data.idaccount, {
              title: data.title || 'Cảnh báo ngừng hoạt động tài khoản',
              message: data.message || `Tài khoản sẽ bị ngừng hoạt động sau ${data.daysRemaining || 0} ngày.`,
              type: 'AccountCountdown',
              metadata: data,
            });
          }

          const io = typeof this.getSocket().getIO === 'function' ? this.getSocket().getIO() : null;
          if (io) {
            io.to(`account_${data.idaccount}`).emit('account.countdown', data);
          }
        });

        isInitialized = true;
        logger.info('[Notification Module] Notification event listeners initialized successfully');
      }
    } catch (error) {
      logger.error('[Notification Module] Failed to initialize listeners', { error: error.message });
    }
  },

  /**
   * Phát thông báo Broadcast toàn hệ thống
   */
  async broadcast(payload = {}) {
    const store = this.getStore();
    const alertData = {
      title: payload.title || 'Thông báo hệ thống',
      message: payload.message || '',
      level: payload.level || 'INFO',
      category: 'BROADCAST',
      metadata: payload.metadata || {},
    };

    let saved = null;
    if (store && typeof store.addAdminNotification === 'function') {
      saved = await store.addAdminNotification(alertData);
    }

    const broadcastPayload = saved || {
      ...alertData,
      id: require('crypto').randomUUID(),
      createdAt: new Date().toISOString(),
    };

    this.getSocket().emitSystemBroadcast(broadcastPayload);
    return broadcastPayload;
  },

  /**
   * Gửi thông báo trực tiếp cho một tài khoản cụ thể
   */
  async sendDirectNotification(idaccount, notification) {
    const store = this.getStore();
    let saved = null;
    if (store && typeof store.addNotification === 'function') {
      saved = await store.addNotification(idaccount, notification);
    }

    const io = typeof this.getSocket().getIO === 'function' ? this.getSocket().getIO() : null;
    if (io) {
      io.to(`account_${idaccount}`).emit('user.notification', saved || notification);
    }
    return saved || notification;
  },

  /**
   * Gửi cảnh báo hệ thống cho Admin
   */
  async sendAdminAlert(alertData) {
    const store = this.getStore();
    let saved = null;
    if (store && typeof store.addAdminNotification === 'function') {
      saved = await store.addAdminNotification(alertData);
    }
    const finalAlert = saved || {
      ...alertData,
      id: require('crypto').randomUUID(),
      createdAt: new Date().toISOString(),
    };
    this.getSocket().emitAdminNotification(finalAlert);
    return finalAlert;
  },

  /**
   * Backward-compatibility wrapper
   */
  async notifyUser(idaccount, notification) {
    return this.sendDirectNotification(idaccount, notification);
  },
};

const os = require('os');
const _cloudAlertDebounce = new Map();
const CLOUD_ALERT_DEBOUNCE_MS = 30 * 60 * 1000; // 30 phút

async function checkAndAlertCloudHealth() {
  const now = Date.now();
  const result = { ramAlert: false, errorRateAlert: false };

  // Kiểm tra RAM
  const totalMem = os.totalmem();
  const usedMem = totalMem - os.freemem();
  const ramPercent = Math.round((usedMem / totalMem) * 100);
  if (ramPercent > 85) {
    const last = _cloudAlertDebounce.get('ram') || 0;
    if (now - last > CLOUD_ALERT_DEBOUNCE_MS) {
      _cloudAlertDebounce.set('ram', now);
      result.ramAlert = true;
      await notificationService.sendAdminAlert({
        type: 'RAM_CRITICAL',
        level: 'CRITICAL',
        title: '🔴 RAM Cloud Vượt Ngưỡng Nguy Hiểm',
        message: `RAM đạt ${ramPercent}% (${Math.round(usedMem / 1024 / 1024)}MB / ${Math.round(totalMem / 1024 / 1024)}MB). Nguy cơ OOM crash!`,
      });
    }
  }

  // Kiểm tra Error Rate từ AuditLog 5 phút gần nhất
  try {
    const { prisma } = require('../../config/db');
    const since = new Date(now - 5 * 60 * 1000);
    const [total, failed] = await Promise.all([
      prisma.auditlog.count({ where: { time_req: { gte: since } } }),
      prisma.auditlog.count({
        where: {
          time_req: { gte: since },
          req_status: { in: ['Fail', 'Rejected'] },
        },
      }),
    ]);
    if (total >= 10) {
      const rate = Math.round((failed / total) * 100);
      if (rate > 10) {
        const last = _cloudAlertDebounce.get('errorRate') || 0;
        if (now - last > CLOUD_ALERT_DEBOUNCE_MS) {
          _cloudAlertDebounce.set('errorRate', now);
          result.errorRateAlert = true;
          await notificationService.sendAdminAlert({
            type: 'HIGH_ERROR_RATE',
            level: 'CRITICAL',
            title: '🔴 Tỉ Lệ Lỗi Request Tăng Đột Biến',
            message: `${failed}/${total} request thất bại (${rate}%) trong 5 phút qua. Cần kiểm tra ngay!`,
          });
        }
      }
    }
  } catch (_) {
    /* Không để lỗi query crash scheduler */
  }

  return result;
}

notificationService.checkAndAlertCloudHealth = checkAndAlertCloudHealth;

module.exports = notificationService;
