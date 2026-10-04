/**
 * Maintenance Manager
 * Quản lý trạng thái bảo trì hệ thống (Maintenance & Emergency Maintenance Mode)
 * Hỗ trợ:
 * 1. Bảo trì kỹ thuật thông thường (Im lặng - không phát broadcast người dùng).
 * 2. Bảo trì khẩn cấp (Phát broadcast CRITICAL tới toàn bộ client-app & người dùng).
 * 3. Lên lịch bảo trì (Scheduled Maintenance hẹn giờ).
 * 4. Ghi đè khẩn cấp (Emergency Overrides): Kích hoạt khẩn cấp sẽ tự động xóa sạch lịch hẹn trước.
 */

const logger = require('../logger');

class MaintenanceManager {
  constructor(options = {}) {
    this.active = false;
    this.isEmergency = false;
    this.reason = 'Hệ thống đang gặp sự cố. Quý khách vui lòng quay lại sau ít phút!';
    this.activatedBy = null;
    this.activatedAt = null;
    this.scheduled = null; // { scheduledAt, reason, isEmergency, createdBy, createdAt }
    this._scheduledTimer = null;
    this.redis = options.redis || null;
    this.notificationService = options.notificationService || null;
  }

  isMaintenanceActive() {
    return this.active;
  }

  isEmergencyMode() {
    return this.active && this.isEmergency;
  }

  getNotificationService() {
    if (!this.notificationService) {
      try {
        const notif = require('../../modules/notification/notification.service');
        this.notificationService = notif;
      } catch (e) {
        // Ignored if circular dependency during startup
      }
    }
    return this.notificationService;
  }

  setMaintenance(active, reason = null, activatedBy = 'system', options = {}) {
    const isActivating = Boolean(active);
    const isEmergency = Boolean(options.isEmergency);

    this.active = isActivating;

    if (this.active) {
      this.reason = reason || this.reason || 'Hệ thống đang bảo trì kỹ thuật.';
      this.activatedBy = activatedBy;
      this.activatedAt = new Date().toISOString();
      this.isEmergency = isEmergency;

      // RULE CỐT LÕI TỪ PO: Nếu kích hoạt BẢO TRÌ KHẨN CẤP, lập tức HỦY & XÓA SẠCH LỊCH BẢO TRÌ ĐÃ HẸN
      if (this.isEmergency && this.scheduled) {
        logger.warn('[MAINTENANCE] Phát hiện sự cố khẩn cấp: TỰ ĐỘNG XÓA LỊCH BẢO TRÌ ĐÃ HẸN TRƯỚC', {
          clearedSchedule: this.scheduled,
          emergencyActivatedBy: this.activatedBy,
        });
        this.cancelScheduledMaintenance();
      }

      logger.warn(`[MAINTENANCE] BẬT chế độ bảo trì [${this.isEmergency ? 'KHẨN CẤP' : 'THÔNG THƯỜNG'}]`, {
        reason: this.reason,
        isEmergency: this.isEmergency,
        activatedBy: this.activatedBy,
        activatedAt: this.activatedAt,
      });

      // RULE CỐT LÕI TỪ PO: Khi check "Bảo trì khẩn cấp" mới phát thông báo tới toàn bộ hệ thống & người dùng.
      // Bảo trì thông thường: Không phát thông báo, chỉ chặn traffic client.
      if (this.isEmergency) {
        const notifService = this.getNotificationService();
        if (notifService && typeof notifService.broadcast === 'function') {
          notifService.broadcast({
            title: '⚠️ BẢO TRÌ HỆ THỐNG KHẨN CẤP',
            message: this.reason,
            level: 'CRITICAL',
            metadata: {
              type: 'EMERGENCY_MAINTENANCE',
              isEmergency: true,
              activatedAt: this.activatedAt,
              activatedBy: this.activatedBy,
            },
          }).catch((err) => {
            logger.error('[MAINTENANCE] Lỗi phát thông báo khẩn cấp', { error: err.message });
          });
        }
      }
    } else {
      if (this._autoEndTimer) {
        clearTimeout(this._autoEndTimer);
        this._autoEndTimer = null;
      }
      logger.info('[MAINTENANCE] TẮT chế độ bảo trì — Hệ thống trở lại bình thường', {
        deactivatedBy: activatedBy,
      });
      this.isEmergency = false;
      this.activatedBy = null;
      this.activatedAt = null;
    }

    // Đồng bộ vào Redis nếu có
    if (this.redis && typeof this.redis.set === 'function') {
      const payload = JSON.stringify(this.getStatus());
      this.redis.set('system:maintenance_mode', payload).catch(() => {});
    }

    // Phát sự kiện realtime tới admin_room và toàn bộ client
    try {
      const { emitMaintenanceChanged } = require('../socket');
      emitMaintenanceChanged(this.getStatus());
    } catch (_) {}

    return this.getStatus();
  }

  scheduleMaintenance({ scheduledAt, scheduledEndAt, reason, isEmergency = false, createdBy = 'admin' }) {
    if (this.active) {
      throw new Error('Hệ thống hiện đang trong phiên bảo trì trực tiếp. Vui lòng kết thúc bảo trì trước khi lên lịch trình mới.');
    }

    if (!scheduledAt) {
      throw new Error('Vui lòng chọn thời điểm bảo trì');
    }

    const targetDate = new Date(scheduledAt);
    const now = new Date();
    const delayMs = targetDate.getTime() - now.getTime();

    if (isNaN(delayMs) || delayMs <= 0) {
      throw new Error('Thời điểm bảo trì phải nằm trong tương lai');
    }

    let targetEndDate = null;
    if (scheduledEndAt) {
      targetEndDate = new Date(scheduledEndAt);
      if (isNaN(targetEndDate.getTime()) || targetEndDate.getTime() <= targetDate.getTime()) {
        throw new Error('Thời điểm kết thúc bảo trì phải sau thời điểm bắt đầu bảo trì!');
      }
    }

    // Hủy timer cũ nếu có
    this.cancelScheduledMaintenance();

    this.scheduled = {
      scheduledAt: targetDate.toISOString(),
      scheduledEndAt: targetEndDate ? targetEndDate.toISOString() : null,
      reason: reason || 'Bảo trì hệ thống theo lịch trình định kỳ.',
      isEmergency: Boolean(isEmergency),
      createdBy,
      createdAt: now.toISOString(),
    };

    logger.info('[MAINTENANCE] Đã lên lịch bảo trì hệ thống', {
      scheduledAt: this.scheduled.scheduledAt,
      scheduledEndAt: this.scheduled.scheduledEndAt,
      isEmergency: this.scheduled.isEmergency,
      delayMs,
    });

    // Thiết lập timer Node.js
    this._scheduledTimer = setTimeout(() => {
      logger.info('[MAINTENANCE] Đến giờ hẹn: Tự động kích hoạt bảo trì hệ thống', {
        scheduled: this.scheduled,
      });
      const sched = this.scheduled;
      this._scheduledTimer = null;
      this.scheduled = null;

      if (sched) {
        this.setMaintenance(true, sched.reason, `Lịch hẹn bởi ${sched.createdBy}`, {
          isEmergency: sched.isEmergency,
        });

        // Nếu có thời điểm kết thúc đã hẹn, thiết lập timer tự động kết thúc
        if (sched.scheduledEndAt) {
          const endDelayMs = new Date(sched.scheduledEndAt).getTime() - Date.now();
          if (endDelayMs > 0) {
            this._autoEndTimer = setTimeout(() => {
              logger.info('[MAINTENANCE] Đến giờ kết thúc hẹn trước: Tự động khôi phục hệ thống');
              this._autoEndTimer = null;
              this.setMaintenance(false, 'Hết thời gian bảo trì định kỳ theo lịch hẹn', 'Hệ thống tự động');
            }, endDelayMs);
            if (this._autoEndTimer && typeof this._autoEndTimer.unref === 'function') {
              this._autoEndTimer.unref();
            }
          }
        }
      }
    }, delayMs);

    // Không làm treo tiến trình Node.js nếu có scheduler
    if (this._scheduledTimer && typeof this._scheduledTimer.unref === 'function') {
      this._scheduledTimer.unref();
    }

    try {
      const { emitMaintenanceChanged } = require('../socket');
      emitMaintenanceChanged(this.getStatus());
    } catch (_) {}

    return this.getStatus();
  }

  cancelScheduledMaintenance() {
    if (this._scheduledTimer) {
      clearTimeout(this._scheduledTimer);
      this._scheduledTimer = null;
    }
    if (this._autoEndTimer) {
      clearTimeout(this._autoEndTimer);
      this._autoEndTimer = null;
    }
    const hadSchedule = Boolean(this.scheduled);
    this.scheduled = null;

    try {
      const { emitMaintenanceChanged } = require('../socket');
      emitMaintenanceChanged(this.getStatus());
    } catch (_) {}

    return { cancelled: hadSchedule };
  }

  getStatus() {
    return {
      active: this.active,
      isEmergency: this.isEmergency,
      reason: this.reason,
      activatedBy: this.activatedBy,
      activatedAt: this.activatedAt,
      scheduled: this.scheduled,
    };
  }
}

const defaultMaintenanceManager = new MaintenanceManager();

module.exports = {
  MaintenanceManager,
  defaultMaintenanceManager,
};
