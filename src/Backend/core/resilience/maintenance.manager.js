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
    // MẶC ĐỊNH BẢO TRÌ TỨC THÌ LUÔN LÀ BẢO TRÌ KHẨN CẤP (PO Policy)
    const isEmergency = options.isEmergency !== undefined ? Boolean(options.isEmergency) : true;
    const maintenanceType = options.type || (isEmergency ? 'EMERGENCY' : 'SCHEDULED');

    if (isActivating && this.active) {
      throw new Error('Hệ thống hiện đang trong chế độ bảo trì, không thể kích hoạt bảo trì nữa');
    }

    this.active = isActivating;

    if (this.active) {
      this.reason = reason || this.reason || 'Hệ thống đang bảo trì khẩn cấp.';
      this.activatedBy = activatedBy;
      this.activatedAt = new Date().toISOString();
      this.isEmergency = isEmergency;

      logger.warn(`[MAINTENANCE] BẬT chế độ bảo trì [${this.isEmergency ? 'KHẨN CẤP' : 'THÔNG THƯỜNG'}]`, {
        reason: this.reason,
        isEmergency: this.isEmergency,
        activatedBy: this.activatedBy,
        activatedAt: this.activatedAt,
      });

      // Lưu lịch sử bảo trì vào CSDL PostgreSQL (nếu chưa được lưu từ bước lên lịch SCHEDULED)
      if (!options.skipCreateRecord) {
        try {
          const { defaultMaintenanceRepository } = require('../../modules/admin/maintenance.repository');
          defaultMaintenanceRepository.createRecord({
            type: maintenanceType,
            reason: this.reason,
            activated_by: this.activatedBy,
            started_at: this.activatedAt,
            scheduled_end_at: options.scheduled_end_at || null,
            status: 'ONGOING',
          }).catch((err) => {
            logger.warn('[MAINTENANCE] Lỗi lưu lịch sử bảo trì CSDL', { error: err.message });
          });
        } catch (repoErr) {
          logger.warn('[MAINTENANCE] Không thể gọi maintenance repository', { error: repoErr.message });
        }
      }

      // Phát thông báo khẩn cấp tới toàn bộ client-app & người dùng
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

      // Cập nhật trạng thái phiên bảo trì trong CSDL thành COMPLETED
      try {
        const { defaultMaintenanceRepository } = require('../../modules/admin/maintenance.repository');
        defaultMaintenanceRepository.completeOngoingRecord({
          ended_at: new Date(),
          status: 'COMPLETED',
        }).catch((err) => {
          logger.warn('[MAINTENANCE] Lỗi cập nhật kết thúc lịch sử bảo trì', { error: err.message });
        });
      } catch (repoErr) {
        logger.warn('[MAINTENANCE] Không thể gọi maintenance repository khi tắt', { error: repoErr.message });
      }

      this.isEmergency = false;
      this.activatedBy = null;
      this.activatedAt = null;

      // Phát thông báo khôi phục tới toàn bộ client-app & người dùng
      const notifService = this.getNotificationService();
      if (notifService && typeof notifService.broadcast === 'function') {
        notifService.broadcast({
          title: '✅ HỆ THỐNG ĐÃ KẾT THÚC BẢO TRÌ',
          message: 'Hệ thống đã hoàn tất bảo trì và hoạt động bình thường trở lại. Bạn có thể tiếp tục sử dụng tất cả các tính năng.',
          level: 'INFO',
          metadata: {
            type: 'MAINTENANCE_RESTORED',
            isEmergency: false,
            endedAt: new Date().toISOString(),
            deactivatedBy: activatedBy,
          },
        }).catch((err) => {
          logger.error('[MAINTENANCE] Lỗi phát thông báo kết thúc bảo trì', { error: err.message });
        });
      }
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
      recordId: null,
      scheduledAt: targetDate.toISOString(),
      scheduledEndAt: targetEndDate ? targetEndDate.toISOString() : null,
      reason: reason || 'Bảo trì hệ thống theo lịch trình định kỳ.',
      isEmergency: Boolean(isEmergency),
      createdBy,
      createdAt: now.toISOString(),
    };

    // PO YÊU CẦU: Lưu ngay vào CSDL PostgreSQL với trạng thái SCHEDULED
    try {
      const { defaultMaintenanceRepository } = require('../../modules/admin/maintenance.repository');
      defaultMaintenanceRepository.createRecord({
        type: 'SCHEDULED',
        reason: this.scheduled.reason,
        activated_by: this.scheduled.createdBy,
        started_at: this.scheduled.scheduledAt,
        scheduled_end_at: this.scheduled.scheduledEndAt,
        status: 'SCHEDULED',
      }).then((record) => {
        if (record && this.scheduled) {
          this.scheduled.recordId = record.id;
        }
      }).catch((err) => {
        logger.warn('[MAINTENANCE] Lỗi lưu CSDL lịch bảo trì SCHEDULED', { error: err.message });
      });
    } catch (repoErr) {
      logger.warn('[MAINTENANCE] Không thể gọi maintenance repository khi schedule', { error: repoErr.message });
    }

    logger.info('[MAINTENANCE] Đã lên lịch bảo trì hệ thống', {
      scheduledAt: this.scheduled.scheduledAt,
      scheduledEndAt: this.scheduled.scheduledEndAt,
      isEmergency: this.scheduled.isEmergency,
      delayMs,
    });

    // Thiết lập timer Node.js
    this._scheduledTimer = setTimeout(async () => {
      logger.info('[MAINTENANCE] Đến giờ hẹn: Kiểm tra và kích hoạt bảo trì hệ thống', {
        scheduled: this.scheduled,
      });
      const sched = this.scheduled;
      this._scheduledTimer = null;
      this.scheduled = null;

      if (!sched) return;

      // PO YÊU CẦU: Nếu lúc này hệ thống đang trong phiên bảo trì (khẩn cấp), lịch này bị "vướng" và bị hủy bỏ!
      if (this.active) {
        logger.warn('[MAINTENANCE] Đến giờ hẹn nhưng hệ thống đang có bảo trì diễn ra: HỦY lịch bảo trì bị vướng', {
          sched,
          activeMaintenanceReason: this.reason,
        });
        try {
          const { defaultMaintenanceRepository } = require('../../modules/admin/maintenance.repository');
          await defaultMaintenanceRepository.cancelScheduledRecord({
            id: sched.recordId,
            reason: 'Bị hủy do trùng vào thời gian bảo trì khác đang diễn ra',
          });
        } catch (repoErr) {
          logger.warn('[MAINTENANCE] Lỗi CSDL khi hủy lịch bị vướng', { error: repoErr.message });
        }
        return;
      }

      // Nếu không bị vướng: Cập nhật bản ghi CSDL sang ONGOING và kích hoạt bảo trì bình thường!
      try {
        const { defaultMaintenanceRepository } = require('../../modules/admin/maintenance.repository');
        if (sched.recordId) {
          await defaultMaintenanceRepository.updateRecordStatus(sched.recordId, {
            status: 'ONGOING',
            started_at: new Date(),
          });
        }
      } catch (repoErr) {
        logger.warn('[MAINTENANCE] Lỗi cập nhật CSDL kích hoạt lịch', { error: repoErr.message });
      }

      this.setMaintenance(true, sched.reason, `Lịch hẹn bởi ${sched.createdBy}`, {
        isEmergency: Boolean(sched.isEmergency),
        type: 'SCHEDULED',
        scheduled_end_at: sched.scheduledEndAt,
        skipCreateRecord: true,
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
    const sched = this.scheduled;
    const hadSchedule = Boolean(sched);
    this.scheduled = null;

    if (hadSchedule && sched?.recordId) {
      try {
        const { defaultMaintenanceRepository } = require('../../modules/admin/maintenance.repository');
        defaultMaintenanceRepository.cancelScheduledRecord({
          id: sched.recordId,
          reason: 'Admin chủ động hủy lịch bảo trì',
        }).catch((err) => {
          logger.warn('[MAINTENANCE] Lỗi CSDL khi hủy lịch chủ động', { error: err.message });
        });
      } catch (_) {}
    }

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
