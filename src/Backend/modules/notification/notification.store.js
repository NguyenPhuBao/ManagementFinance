/**
 * Notification Store — Quản lý lưu trữ thông báo (Redis List + In-Memory Fallback)
 * Tuân thủ Data_Security.md: Không lưu dữ liệu nhạy cảm, tự động cắt tỉa giới hạn 50 mục.
 */

const crypto = require('crypto');
const logger = require('../../core/logger');

class NotificationStore {
  /**
   * @param {Object} options
   * @param {Object|null} options.redisClient - ioredis client instance (nếu có)
   * @param {number} options.maxItemsPerUser - Giới hạn số thông báo tối đa lưu cho 1 tài khoản (mặc định: 50)
   * @param {number} options.ttlSeconds - Thời gian sống trong Redis (mặc định: 30 ngày)
   */
  constructor(options = {}) {
    this.redisClient = options.redisClient || null;
    this.maxItemsPerUser = options.maxItemsPerUser || 50;
    this.ttlSeconds = options.ttlSeconds || 30 * 24 * 3600;

    // In-memory fallback
    this.userStore = new Map(); // idaccount -> Array<notification>
    this.adminStore = []; // Array<notification>
  }

  _isRedisReady() {
    return Boolean(this.redisClient && this.redisClient.status === 'ready');
  }

  _userKey(idaccount) {
    return `notifications:account:${idaccount}`;
  }

  _adminKey() {
    return 'notifications:admin';
  }

  /**
   * Thêm thông báo mới cho người dùng
   */
  async addNotification(idaccount, data) {
    if (!idaccount) {
      throw new Error('idaccount is required to add notification');
    }

    const notification = {
      id: crypto.randomUUID(),
      idaccount,
      title: data.title || '',
      message: data.message || '',
      type: data.type || 'SYSTEM_INFO',
      metadata: data.metadata || {},
      isRead: false,
      readAt: null,
      createdAt: new Date().toISOString(),
    };

    if (this._isRedisReady()) {
      try {
        const key = this._userKey(idaccount);
        await this.redisClient.lpush(key, JSON.stringify(notification));
        await this.redisClient.ltrim(key, 0, this.maxItemsPerUser - 1);
        await this.redisClient.expire(key, this.ttlSeconds);
        return notification;
      } catch (err) {
        logger.warn('NotificationStore: Redis lpush failed, falling back to memory', { error: err.message });
      }
    }

    // In-memory fallback (chuẩn hóa idaccount thành string)
    const accKey = String(idaccount);
    if (!this.userStore.has(accKey)) {
      this.userStore.set(accKey, []);
    }
    const list = this.userStore.get(accKey);
    list.unshift(notification);
    if (list.length > this.maxItemsPerUser) {
      list.length = this.maxItemsPerUser;
    }
    return notification;
  }

  /**
   * Lấy danh sách thông báo của người dùng kèm phân trang và số chưa đọc
   */
  async getNotifications(idaccount, options = {}) {
    const page = Math.max(1, parseInt(options.page, 10) || 1);
    const limit = Math.max(1, parseInt(options.limit, 10) || 20);
    const unreadOnly = Boolean(options.unreadOnly);
    const accKey = String(idaccount);

    let allItems = [];

    if (this._isRedisReady()) {
      try {
        const raw = await this.redisClient.lrange(this._userKey(idaccount), 0, -1);
        allItems = raw.map((item) => JSON.parse(item));
      } catch (err) {
        logger.warn('NotificationStore: Redis lrange failed, falling back to memory', { error: err.message });
        allItems = this.userStore.get(accKey) || [];
      }
    } else {
      allItems = this.userStore.get(accKey) || [];
    }

    const unreadCount = allItems.filter((n) => !n.isRead).length;
    let filtered = unreadOnly ? allItems.filter((n) => !n.isRead) : allItems;

    const total = filtered.length;
    const startIndex = (page - 1) * limit;
    const paginated = filtered.slice(startIndex, startIndex + limit);

    return {
      notifications: paginated,
      total,
      unreadCount,
      page,
      limit,
    };
  }

  /**
   * Đếm số lượng thông báo chưa đọc của người dùng
   */
  async getUnreadCount(idaccount) {
    const { unreadCount } = await this.getNotifications(idaccount);
    return unreadCount;
  }

  /**
   * Đánh dấu 1 thông báo đã đọc
   */
  async markAsRead(idaccount, notificationId) {
    const accKey = String(idaccount);

    if (this._isRedisReady()) {
      try {
        const key = this._userKey(idaccount);
        const raw = await this.redisClient.lrange(key, 0, -1);
        let found = null;
        const updated = raw.map((item) => {
          const parsed = JSON.parse(item);
          if (parsed.id === notificationId) {
            parsed.isRead = true;
            parsed.readAt = new Date().toISOString();
            found = parsed;
          }
          return JSON.stringify(parsed);
        });

        if (found) {
          const pipeline = this.redisClient.pipeline();
          pipeline.del(key);
          if (updated.length > 0) {
            pipeline.rpush(key, ...updated);
            pipeline.expire(key, this.ttlSeconds);
          }
          await pipeline.exec();
          return found;
        }
      } catch (err) {
        logger.warn('NotificationStore: Redis markAsRead failed, falling back to memory', { error: err.message });
      }
    }

    // In-memory fallback
    const list = this.userStore.get(accKey) || [];
    const item = list.find((n) => n.id === notificationId);
    if (item) {
      item.isRead = true;
      item.readAt = new Date().toISOString();
      return item;
    }
    return null;
  }

  /**
   * Đánh dấu tất cả thông báo của người dùng là đã đọc
   */
  async markAllAsRead(idaccount) {
    const now = new Date().toISOString();
    const accKey = String(idaccount);


    if (this._isRedisReady()) {
      try {
        const key = this._userKey(idaccount);
        const raw = await this.redisClient.lrange(key, 0, -1);
        let count = 0;
        const updated = raw.map((item) => {
          const parsed = JSON.parse(item);
          if (!parsed.isRead) {
            parsed.isRead = true;
            parsed.readAt = now;
            count++;
          }
          return JSON.stringify(parsed);
        });

        if (count > 0) {
          const pipeline = this.redisClient.pipeline();
          pipeline.del(key);
          pipeline.rpush(key, ...updated);
          pipeline.expire(key, this.ttlSeconds);
          await pipeline.exec();
        }
        return count;
      } catch (err) {
        logger.warn('NotificationStore: Redis markAllAsRead failed, falling back to memory', { error: err.message });
      }
    }

    // In-memory fallback
    const list = this.userStore.get(accKey) || [];
    let count = 0;

    list.forEach((item) => {
      if (!item.isRead) {
        item.isRead = true;
        item.readAt = now;
        count++;
      }
    });
    return count;
  }

  /**
   * Thêm cảnh báo dành riêng cho Admin
   */
  async addAdminNotification(data) {
    const alert = {
      id: crypto.randomUUID(),
      title: data.title || '',
      message: data.message || '',
      level: data.level || 'INFO', // INFO | WARNING | CRITICAL
      category: data.category || 'SYSTEM',
      metadata: data.metadata || {},
      isRead: false,
      readAt: null,
      createdAt: new Date().toISOString(),
    };

    if (this._isRedisReady()) {
      try {
        const key = this._adminKey();
        await this.redisClient.lpush(key, JSON.stringify(alert));
        await this.redisClient.ltrim(key, 0, this.maxItemsPerUser - 1);
        await this.redisClient.expire(key, this.ttlSeconds);
        return alert;
      } catch (err) {
        logger.warn('NotificationStore: Redis addAdminNotification failed', { error: err.message });
      }
    }

    this.adminStore.unshift(alert);
    if (this.adminStore.length > this.maxItemsPerUser) {
      this.adminStore.length = this.maxItemsPerUser;
    }
    return alert;
  }

  /**
   * Lấy danh sách cảnh báo Admin
   */
  async getAdminNotifications(options = {}) {
    const page = Math.max(1, parseInt(options.page, 10) || 1);
    const limit = Math.max(1, parseInt(options.limit, 10) || 20);
    const unreadOnly = Boolean(options.unreadOnly);

    let allItems = [];

    if (this._isRedisReady()) {
      try {
        const raw = await this.redisClient.lrange(this._adminKey(), 0, -1);
        allItems = raw.map((item) => JSON.parse(item));
      } catch (err) {
        logger.warn('NotificationStore: Redis getAdminNotifications failed', { error: err.message });
        allItems = this.adminStore;
      }
    } else {
      allItems = this.adminStore;
    }

    const unreadCount = allItems.filter((n) => !n.isRead).length;
    let filtered = unreadOnly ? allItems.filter((n) => !n.isRead) : allItems;

    const total = filtered.length;
    const startIndex = (page - 1) * limit;
    const paginated = filtered.slice(startIndex, startIndex + limit);

    return {
      notifications: paginated,
      total,
      unreadCount,
      page,
      limit,
    };
  }

  /**
   * Đánh dấu cảnh báo Admin đã đọc
   */
  async markAdminAsRead(notificationId) {
    if (this._isRedisReady()) {
      try {
        const key = this._adminKey();
        const raw = await this.redisClient.lrange(key, 0, -1);
        let found = null;
        const updated = raw.map((item) => {
          const parsed = JSON.parse(item);
          if (parsed.id === notificationId) {
            parsed.isRead = true;
            parsed.readAt = new Date().toISOString();
            found = parsed;
          }
          return JSON.stringify(parsed);
        });

        if (found) {
          const pipeline = this.redisClient.pipeline();
          pipeline.del(key);
          if (updated.length > 0) {
            pipeline.rpush(key, ...updated);
            pipeline.expire(key, this.ttlSeconds);
          }
          await pipeline.exec();
          return found;
        }
      } catch (err) {
        logger.warn('NotificationStore: Redis markAdminAsRead failed', { error: err.message });
      }
    }

    const item = this.adminStore.find((n) => n.id === notificationId);
    if (item) {
      item.isRead = true;
      item.readAt = new Date().toISOString();
      return item;
    }
    return null;
  }

  /**
   * Dọn dẹp dữ liệu (phục vụ test hoặc hủy tài khoản)
   */
  async clear(idaccount) {
    if (this._isRedisReady()) {
      try {
        await this.redisClient.del(this._userKey(idaccount));
      } catch (_) {}
    }
    this.userStore.delete(String(idaccount));
  }


  async clearAdmin() {
    if (this._isRedisReady()) {
      try {
        await this.redisClient.del(this._adminKey());
      } catch (_) {}
    }
    this.adminStore = [];
  }
}

// Lazy init default store để tránh kích hoạt kết nối ioredis trong môi trường test
let _defaultStore = null;

function getDefaultNotificationStore() {
  if (!_defaultStore) {
    let redisClient = null;
    if (process.env.NODE_ENV !== 'test') {
      try {
        const { connection } = require('../../core/queue');
        redisClient = connection;
      } catch (_) {}
    }
    _defaultStore = new NotificationStore({ redisClient });
  }
  return _defaultStore;
}

module.exports = {
  NotificationStore,
  getDefaultNotificationStore,
  get defaultNotificationStore() {
    return getDefaultNotificationStore();
  },
};

