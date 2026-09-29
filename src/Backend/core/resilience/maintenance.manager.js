/**
 * Maintenance Manager
 * Quản lý trạng thái bảo trì khẩn cấp (Emergency Maintenance Mode)
 * Lưu trữ cờ trong RAM / Redis nhẹ, hoàn toàn không phụ thuộc CSDL
 */

const logger = require('../logger');

class MaintenanceManager {
  constructor(options = {}) {
    this.active = false;
    this.reason = 'Hệ thống đang gặp sự cố. Quý khách vui lòng quay lại sau ít phút!';
    this.activatedBy = null;
    this.activatedAt = null;
    this.redis = options.redis || null;
  }

  isMaintenanceActive() {
    return this.active;
  }

  setMaintenance(active, reason = null, activatedBy = 'system') {
    this.active = Boolean(active);
    if (this.active) {
      this.reason = reason || this.reason;
      this.activatedBy = activatedBy;
      this.activatedAt = new Date().toISOString();
      logger.warn('[MAINTENANCE] BẬT chế độ bảo trì khẩn cấp', {
        reason: this.reason,
        activatedBy: this.activatedBy,
        activatedAt: this.activatedAt,
      });
    } else {
      logger.info('[MAINTENANCE] TẮT chế độ bảo trì — Hệ thống trở lại bình thường', {
        deactivatedBy: activatedBy,
      });
      this.activatedBy = null;
      this.activatedAt = null;
    }

    // Đồng bộ vào Redis nếu có kết nối
    if (this.redis && typeof this.redis.set === 'function') {
      const payload = JSON.stringify(this.getStatus());
      this.redis.set('system:maintenance_mode', payload).catch(() => { });
    }

    return this.getStatus();
  }

  getStatus() {
    return {
      active: this.active,
      reason: this.reason,
      activatedBy: this.activatedBy,
      activatedAt: this.activatedAt,
    };
  }
}

const defaultMaintenanceManager = new MaintenanceManager();

module.exports = {
  MaintenanceManager,
  defaultMaintenanceManager,
};
