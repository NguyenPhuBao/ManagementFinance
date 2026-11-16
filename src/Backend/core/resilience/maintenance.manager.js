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

/** Lịch bảo trì chỉ được đặt trong 14 ngày tới (dưới giới hạn ~24,8 ngày của setTimeout). */
const MAX_LEAD_TIME_MS = 14 * 24 * 3600 * 1000;
/** Một phiên bảo trì kéo dài tối đa 7 ngày; phiên không có giờ kết thúc tự kết thúc khi đủ 7 ngày (chốt 2026-11-16). */
const MAX_SESSION_MS = 7 * 24 * 3600 * 1000;
const MAX_SESSION_END_REASON = 'Hết thời hạn tối đa 7 ngày của phiên bảo trì';

class MaintenanceManager {
  constructor(options = {}) {
    this.active = false;
    this.isEmergency = false;
    this.isUpgrade = false;
    this.reason = 'Hệ thống đang gặp sự cố. Quý khách vui lòng quay lại sau ít phút!';
    this.activatedBy = null;
    this.activatedAt = null;
    this.scheduledList = []; // Mảng chứa các lịch bảo trì tương lai
    this.scheduled = null; // Trỏ tới lịch gần nhất để tương thích ngược
    this._scheduledTimer = null;
    this._autoEndTimer = null;
    this.redis = options.redis || null;
    this.notificationService = options.notificationService || null;
    // Chưa đọc được trạng thái bảo trì từ CSDL lúc khởi động: khoá người dùng (fail-closed).
    this.restorePending = false;
    this._emitOverride = options.emitMaintenanceChanged || null;

    const isRunningInTest = Boolean(
      process.env.NODE_ENV === 'test' ||
      (Array.isArray(process.execArgv) && process.execArgv.some((a) => a && a.includes('--test'))) ||
      (Array.isArray(process.argv) && process.argv.some((a) => a && (a.includes('--test') || a.includes('.test.') || a.includes('.spec.'))))
    );

    this.repository = options.repository || (isRunningInTest ? {
      createRecord: async () => ({ id: 999 }),
      updateRecordStatus: async () => ({ id: 999 }),
      cancelScheduledRecord: async () => ({ id: 999 }),
      completeOngoingRecord: async () => ({ id: 999 }),
      getActiveScheduledRecords: async () => ([]),
      loadRestoreState: async () => ({ ongoing: [], scheduled: [] }),
      closeRecord: async () => ({ id: 999 }),
      getHistory: async () => ({ data: [], pagination: { total: 0 } }),
    } : null);
  }

  /** Người dùng thường có bị chặn không: đang bảo trì, hoặc chưa đọc được trạng thái từ CSDL. */
  isMaintenanceActive() {
    return this.active || this.restorePending;
  }

  _emitChanged() {
    try {
      if (this._emitOverride) return this._emitOverride(this.getStatus());
      const { emitMaintenanceChanged } = require('../socket');
      emitMaintenanceChanged(this.getStatus());
    } catch (_) {}
  }

  /** Gọi trước khi máy chủ nhận yêu cầu: khoá người dùng cho tới khi khôi phục xong. */
  beginRestore() {
    this.restorePending = true;
  }

  /**
   * Đọc CSDL tới khi thành công (thử lại mỗi `retryMs`), trong lúc đó giữ khoá.
   * @returns {Promise<object>} kết quả của lần khôi phục thành công
   */
  startRestoreLoop({ retryMs = 5000 } = {}) {
    this.beginRestore();
    return new Promise((resolve) => {
      const attempt = async () => {
        try {
          resolve(await this.restoreFromDatabase());
        } catch (err) {
          logger.warn('[MAINTENANCE] Chưa đọc được trạng thái bảo trì từ CSDL, giữ khoá và thử lại', { error: err.message });
          const t = setTimeout(attempt, retryMs);
          if (t && typeof t.unref === 'function') t.unref();
        }
      };
      attempt();
    });
  }

  /**
   * Khôi phục bảo trì từ CSDL (nguồn sự thật) sau khi khởi động / deploy.
   * Ném lỗi nếu không đọc được CSDL (người gọi giữ khoá và thử lại).
   */
  async restoreFromDatabase() {
    const repo = this.repository || require('../../modules/admin/maintenance.repository').defaultMaintenanceRepository;
    const { ongoing = [], scheduled = [] } = await repo.loadRestoreState();
    const now = Date.now();
    const result = { restoredId: null, closed: [], cancelled: [], rearmed: [], activated: [] };

    // 1. Phiên ONGOING: giữ bản mới nhất, đóng các bản cũ (dữ liệu lỗi).
    const sorted = [...ongoing].sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
    const [latest, ...stale] = sorted;
    for (const row of stale) {
      await repo.closeRecord(row.id, { status: 'COMPLETED', ended_at: latest.started_at });
      result.closed.push(row.id);
    }
    if (latest) {
      const hasEnd = Boolean(latest.scheduled_end_at);
      const endMs = hasEnd
        ? new Date(latest.scheduled_end_at).getTime()
        : new Date(latest.started_at).getTime() + MAX_SESSION_MS;
      if (endMs <= now) {
        await repo.closeRecord(latest.id, { status: 'COMPLETED', ended_at: new Date(endMs).toISOString() });
        result.closed.push(latest.id);
      } else {
        const type = latest.type || 'EMERGENCY';
        this.active = true;
        this.isEmergency = type === 'EMERGENCY';
        this.isUpgrade = type === 'UPGRADE';
        this.reason = latest.reason || this.reason;
        this.activatedBy = latest.activated_by || null;
        this.activatedAt = new Date(latest.started_at).toISOString();
        this._armAutoEnd(new Date(endMs).toISOString(), this.isUpgrade, hasEnd ? null : MAX_SESSION_END_REASON);
        result.restoredId = latest.id;
        logger.warn('[MAINTENANCE] Khôi phục phiên bảo trì từ CSDL sau khởi động', { id: latest.id, type });
      }
    }

    // 2. Lịch hẹn SCHEDULED.
    for (const row of scheduled) {
      const startMs = new Date(row.started_at).getTime();
      const endMs = row.scheduled_end_at ? new Date(row.scheduled_end_at).getTime() : null;
      if (endMs !== null && endMs <= now) {
        await repo.cancelScheduledRecord({ id: row.id, reason: 'Lỡ lịch do máy chủ không chạy trong khung giờ hẹn' });
        result.cancelled.push(row.id);
        continue;
      }
      const item = this._scheduleItemFromRecord(row);
      if (startMs <= now) {
        await this.activateScheduledItem(item);
        result.activated.push(row.id);
      } else {
        this._armScheduleItem(item, startMs - now);
        result.rearmed.push(row.id);
      }
    }

    this.restorePending = false;
    this._emitChanged();
    logger.info('[MAINTENANCE] Hoàn tất khôi phục trạng thái bảo trì từ CSDL', result);
    return result;
  }

  _scheduleItemFromRecord(row) {
    const type = row.type || 'SCHEDULED';
    return {
      id: row.id,
      recordId: row.id,
      scheduledAt: new Date(row.started_at).toISOString(),
      scheduledEndAt: row.scheduled_end_at ? new Date(row.scheduled_end_at).toISOString() : null,
      reason: row.reason,
      isEmergency: false,
      isUpgrade: type === 'UPGRADE',
      type,
      createdBy: row.activated_by,
      createdAt: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
      _timer: null,
    };
  }

  _armScheduleItem(schedItem, delayMs) {
    schedItem._timer = setTimeout(async () => {
      await this.activateScheduledItem(schedItem);
    }, delayMs);
    if (schedItem._timer && typeof schedItem._timer.unref === 'function') {
      schedItem._timer.unref();
    }
    this.scheduledList.push(schedItem);
    this.scheduledList.sort((a, b) => new Date(a.scheduledAt).getTime() - new Date(b.scheduledAt).getTime());
    this.scheduled = this.getNearestSchedule();
  }

  _armAutoEnd(endIso, isUpgrade, endReason = null) {
    const endDelayMs = new Date(endIso).getTime() - Date.now();
    if (!(endDelayMs > 0)) return;
    if (this._autoEndTimer) clearTimeout(this._autoEndTimer);
    this._autoEndTimer = setTimeout(() => {
      logger.info('[MAINTENANCE] Đến giờ kết thúc hẹn trước: Tự động khôi phục hệ thống');
      this._autoEndTimer = null;
      this.setMaintenance(false, endReason || (isUpgrade ? 'Hết thời gian nâng cấp hệ thống theo lịch hẹn' : 'Hết thời gian bảo trì định kỳ theo lịch hẹn'), 'Hệ thống tự động');
    }, endDelayMs);
    if (this._autoEndTimer && typeof this._autoEndTimer.unref === 'function') {
      this._autoEndTimer.unref();
    }
  }

  isEmergencyMode() {
    return this.active && this.isEmergency;
  }

  isUpgradeMode() {
    return this.active && this.isUpgrade;
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

  getScheduledList() {
    return (this.scheduledList || []).map((item) => ({
      id: item.id,
      recordId: item.recordId,
      scheduledAt: item.scheduledAt,
      scheduledEndAt: item.scheduledEndAt,
      reason: item.reason,
      isEmergency: item.isEmergency,
      isUpgrade: Boolean(item.isUpgrade),
      type: item.type || (item.isUpgrade ? 'UPGRADE' : (item.isEmergency ? 'EMERGENCY' : 'SCHEDULED')),
      createdBy: item.createdBy,
      createdAt: item.createdAt,
    }));
  }

  getNearestSchedule() {
    const list = this.getScheduledList();
    if (!list.length) return null;
    const now = Date.now();
    const futureList = list.filter((item) => new Date(item.scheduledAt).getTime() > now);
    if (!futureList.length) return list[0] || null;
    return futureList.sort((a, b) => new Date(a.scheduledAt).getTime() - new Date(b.scheduledAt).getTime())[0];
  }

  clearAllTimers() {
    if (this._scheduledTimer) {
      clearTimeout(this._scheduledTimer);
      this._scheduledTimer = null;
    }
    if (this._autoEndTimer) {
      clearTimeout(this._autoEndTimer);
      this._autoEndTimer = null;
    }
    if (Array.isArray(this.scheduledList)) {
      for (const item of this.scheduledList) {
        if (item._timer) {
          clearTimeout(item._timer);
          item._timer = null;
        }
      }
    }
  }

  setMaintenance(active, reason = null, activatedBy = 'system', options = {}) {
    const isActivating = Boolean(active);
    // MẶC ĐỊNH BẢO TRÌ TỨC THÌ LUÔN LÀ BẢO TRÌ KHẨN CẤP (PO Policy)
    const isEmergency = options.isEmergency !== undefined ? Boolean(options.isEmergency) : true;
    const isUpgrade = Boolean(options.isUpgrade || options.type === 'UPGRADE');
    const maintenanceType = options.type || (isUpgrade ? 'UPGRADE' : (isEmergency ? 'EMERGENCY' : 'ROUTINE'));

    if (isActivating && this.active) {
      // ĐẶC BIỆT: Nếu đang bảo trì thông thường, cho phép DUY NHẤT bảo trì khẩn cấp kích hoạt đè lên để can thiệp
      if (!this.isEmergency && isEmergency) {
        this.isEmergency = true;
        this.isUpgrade = false;
        if (reason) this.reason = reason;
        this.activatedBy = activatedBy;
        this.activatedAt = new Date().toISOString();
        // Khẩn cấp không có giờ kết thúc: bỏ giờ kết thúc của lịch cũ, tự kết thúc sau 7 ngày kể từ lúc bật khẩn cấp
        this._armAutoEnd(new Date(Date.now() + MAX_SESSION_MS).toISOString(), false, MAX_SESSION_END_REASON);

        logger.warn(`[MAINTENANCE] NÂNG CẤP phiên bảo trì lên [KHẨN CẤP]`, {
          reason: this.reason,
          isEmergency: this.isEmergency,
          activatedBy: this.activatedBy,
          activatedAt: this.activatedAt,
        });

        // Chốt 2026-11-16: phiên theo lịch đang chạy bị HỦY, khẩn cấp là bản ghi riêng.
        // Lịch còn chờ không hủy ở đây: tới giờ bắt đầu mà khẩn cấp còn chạy thì activateScheduledItem mới hủy.
        // Đóng phiên cũ XONG rồi mới tạo bản ghi khẩn cấp, kẻo lệnh đóng (theo status ONGOING) đóng luôn bản ghi mới.
        try {
          const repo = this.repository || require('../../modules/admin/maintenance.repository').defaultMaintenanceRepository;
          const emergencyRecord = {
            type: 'EMERGENCY',
            reason: this.reason,
            activated_by: this.activatedBy,
            started_at: this.activatedAt,
            scheduled_end_at: null,
            status: 'ONGOING',
          };
          repo.completeOngoingRecord({ ended_at: new Date(this.activatedAt), status: 'CANCELLED' })
            .then(() => repo.createRecord(emergencyRecord))
            .catch((err) => {
              logger.warn('[MAINTENANCE] Lỗi CSDL khi hủy phiên theo lịch và tạo phiên khẩn cấp', { error: err.message });
            });
        } catch (repoErr) {
          logger.warn('[MAINTENANCE] Không thể gọi maintenance repository khi nâng cấp khẩn cấp', { error: repoErr.message });
        }

        // Phát broadcast khẩn cấp tới toàn bộ client-app & người dùng
        const notifService = this.getNotificationService();
        if (notifService && typeof notifService.broadcast === 'function') {
          notifService.broadcast({
            title: '⚠️ BẢO TRÌ HỆ THỐNG KHẨN CẤP',
            message: this.reason,
            level: 'CRITICAL',
            metadata: {
              type: 'EMERGENCY_MAINTENANCE',
              isEmergency: true,
              isUpgrade: false,
              activatedAt: this.activatedAt,
              activatedBy: this.activatedBy,
            },
          }).catch((err) => {
            logger.error('[MAINTENANCE] Lỗi phát thông báo khẩn cấp khi nâng cấp', { error: err.message });
          });
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

      if (this.isEmergency) {
        throw new Error('Hệ thống hiện đang trong chế độ bảo trì khẩn cấp, không thể kích hoạt bảo trì nữa');
      }

      throw new Error('Hệ thống hiện đang trong phiên bảo trì thông thường. Chỉ có thể kích hoạt bảo trì khẩn cấp để can thiệp.');
    }

    this.active = isActivating;

    if (this.active) {
      this.reason = reason || this.reason || (isUpgrade ? 'Hệ thống đang tiến hành nâng cấp.' : 'Hệ thống đang bảo trì khẩn cấp.');
      this.activatedBy = activatedBy;
      this.activatedAt = new Date().toISOString();
      this.isEmergency = isEmergency;
      this.isUpgrade = isUpgrade;
      const plannedEnd = options.scheduled_end_at || options.scheduledEndAt;
      if (plannedEnd) this._armAutoEnd(plannedEnd, isUpgrade);
      else this._armAutoEnd(new Date(Date.now() + MAX_SESSION_MS).toISOString(), isUpgrade, MAX_SESSION_END_REASON);

      logger.warn(`[MAINTENANCE] BẬT chế độ [${isUpgrade ? 'NÂNG CẤP HỆ THỐNG' : (this.isEmergency ? 'KHẨN CẤP' : 'THÔNG THƯỜNG')}]`, {
        reason: this.reason,
        isEmergency: this.isEmergency,
        isUpgrade: this.isUpgrade,
        activatedBy: this.activatedBy,
        activatedAt: this.activatedAt,
      });

      // Lưu lịch sử bảo trì vào CSDL PostgreSQL (nếu chưa được lưu từ bước lên lịch SCHEDULED)
      if (!options.skipCreateRecord) {
        try {
          const repo = this.repository || require('../../modules/admin/maintenance.repository').defaultMaintenanceRepository;
          repo.createRecord({
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

      // Phát thông báo tới toàn bộ client-app & người dùng
      const notifService = this.getNotificationService();
      if (notifService && typeof notifService.broadcast === 'function') {
        if (isUpgrade) {
          notifService.broadcast({
            title: '🚀 NÂNG CẤP HỆ THỐNG',
            message: this.reason || 'Hệ thống đang tiến hành nâng cấp phiên bản mới. Quý khách vui lòng quay lại sau ít phút.',
            level: 'WARNING',
            metadata: {
              type: 'SYSTEM_UPGRADE',
              isEmergency: false,
              isUpgrade: true,
              activatedAt: this.activatedAt,
              activatedBy: this.activatedBy,
              scheduledEndAt: options.scheduled_end_at || null,
            },
          }).catch((err) => {
            logger.error('[MAINTENANCE] Lỗi phát thông báo nâng cấp hệ thống', { error: err.message });
          });
        } else if (this.isEmergency) {
          notifService.broadcast({
            title: '⚠️ BẢO TRÌ HỆ THỐNG KHẨN CẤP',
            message: this.reason,
            level: 'CRITICAL',
            metadata: {
              type: 'EMERGENCY_MAINTENANCE',
              isEmergency: true,
              isUpgrade: false,
              activatedAt: this.activatedAt,
              activatedBy: this.activatedBy,
            },
          }).catch((err) => {
            logger.error('[MAINTENANCE] Lỗi phát thông báo khẩn cấp', { error: err.message });
          });
        } else if (maintenanceType === 'SCHEDULED') {
          // PO POLICY: Bảo trì theo lịch phát thông báo "HỆ THỐNG ĐANG BẢO TRÌ" (Warning), KHÔNG chứa từ KHẨN CẤP
          notifService.broadcast({
            title: '🛠️ HỆ THỐNG ĐANG BẢO TRÌ',
            message: this.reason || 'Hệ thống đang tiến hành bảo trì kỹ thuật định kỳ theo lịch trình. Toàn bộ tính năng sẽ sớm khôi phục.',
            level: 'WARNING',
            metadata: {
              type: 'SCHEDULED_MAINTENANCE',
              isEmergency: false,
              isUpgrade: false,
              activatedAt: this.activatedAt,
              activatedBy: this.activatedBy,
              scheduledEndAt: options.scheduled_end_at || null,
            },
          }).catch((err) => {
            logger.error('[MAINTENANCE] Lỗi phát thông báo bảo trì theo lịch', { error: err.message });
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
        const repo = this.repository || require('../../modules/admin/maintenance.repository').defaultMaintenanceRepository;
        repo.completeOngoingRecord({
          ended_at: new Date(),
          status: 'COMPLETED',
        }).catch((err) => {
          logger.warn('[MAINTENANCE] Lỗi cập nhật kết thúc lịch sử bảo trì', { error: err.message });
        });
      } catch (repoErr) {
        logger.warn('[MAINTENANCE] Không thể gọi maintenance repository khi tắt', { error: repoErr.message });
      }

      const wasUpgrade = this.isUpgrade;
      this.isEmergency = false;
      this.isUpgrade = false;
      this.activatedBy = null;
      this.activatedAt = null;

      // Phát thông báo khôi phục tới toàn bộ client-app & người dùng
      const notifService = this.getNotificationService();
      if (notifService && typeof notifService.broadcast === 'function') {
        notifService.broadcast({
          title: wasUpgrade ? '✅ HỆ THỐNG ĐÃ HOÀN TẤT NÂNG CẤP' : '✅ HỆ THỐNG ĐÃ KẾT THÚC BẢO TRÌ',
          message: wasUpgrade
            ? 'Hệ thống đã hoàn tất nâng cấp phiên bản mới và hoạt động bình thường trở lại. Bạn có thể tiếp tục sử dụng tất cả các tính năng.'
            : 'Hệ thống đã hoàn tất bảo trì và hoạt động bình thường trở lại. Bạn có thể tiếp tục sử dụng tất cả các tính năng.',
          level: 'INFO',
          metadata: {
            type: wasUpgrade ? 'UPGRADE_COMPLETED' : 'MAINTENANCE_RESTORED',
            isEmergency: false,
            isUpgrade: false,
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

  async activateScheduledItem(sched) {
    if (!sched) return;
    logger.info('[MAINTENANCE] Kích hoạt phiên bảo trì theo lịch hẹn', { sched });

    if (sched._timer) {
      clearTimeout(sched._timer);
      sched._timer = null;
    }

    this.scheduledList = (this.scheduledList || []).filter(
      (x) => x !== sched && x.id !== sched.id && (!sched.recordId || x.recordId !== sched.recordId)
    );
    this.scheduled = this.getNearestSchedule();

    // PO YÊU CẦU: Nếu lúc này hệ thống đang trong phiên bảo trì (khẩn cấp), lịch này bị "vướng" và bị hủy bỏ!
    if (this.active) {
      logger.warn('[MAINTENANCE] Đến giờ hẹn nhưng hệ thống đang có bảo trì diễn ra: HỦY lịch bảo trì bị vướng', {
        sched,
        activeMaintenanceReason: this.reason,
      });
      try {
        const repo = this.repository || require('../../modules/admin/maintenance.repository').defaultMaintenanceRepository;
        if (sched.recordId) {
          await repo.cancelScheduledRecord({
            id: sched.recordId,
            reason: 'Bị hủy do trùng vào thời gian bảo trì khác đang diễn ra',
          });
        }
      } catch (repoErr) {
        logger.warn('[MAINTENANCE] Lỗi CSDL khi hủy lịch bị vướng', { error: repoErr.message });
      }
      return;
    }

    // Cập nhật CSDL sang ONGOING
    try {
      const repo = this.repository || require('../../modules/admin/maintenance.repository').defaultMaintenanceRepository;
      if (sched.recordId) {
        await repo.updateRecordStatus(sched.recordId, {
          status: 'ONGOING',
          started_at: new Date(),
        });
      }
    } catch (repoErr) {
      logger.warn('[MAINTENANCE] Lỗi cập nhật CSDL kích hoạt lịch', { error: repoErr.message });
    }

    // Kích hoạt bảo trì với isEmergency = false
    const isUpgrade = Boolean(sched.isUpgrade || sched.type === 'UPGRADE');
    this.setMaintenance(true, sched.reason, `Lịch hẹn bởi ${sched.createdBy}`, {
      isEmergency: false,
      isUpgrade,
      type: sched.type || (isUpgrade ? 'UPGRADE' : 'SCHEDULED'),
      scheduled_end_at: sched.scheduledEndAt,
      skipCreateRecord: true,
    });

    // Nếu có thời điểm kết thúc đã hẹn, thiết lập timer tự động kết thúc
    if (sched.scheduledEndAt) this._armAutoEnd(sched.scheduledEndAt, isUpgrade);
  }

  scheduleMaintenance({ scheduledAt, scheduledEndAt, reason, isEmergency = false, isUpgrade = false, type = null, createdBy = 'admin' }) {
    if (this.active) {
      throw new Error('Hệ thống hiện đang trong phiên bảo trì trực tiếp. Vui lòng kết thúc bảo trì trước khi lên lịch trình mới.');
    }

    if (!scheduledAt) {
      throw new Error('Vui lòng chọn thời điểm bảo trì');
    }

    const targetDate = new Date(scheduledAt);
    const now = Date.now();
    const delayMs = targetDate.getTime() - now;

    if (isNaN(delayMs) || delayMs <= 0) {
      throw new Error('Thời điểm bảo trì phải nằm trong tương lai');
    }

    // PO RÀNG BUỘC 1: Bắt buộc đặt trước thời điểm kích hoạt ít nhất 3 tiếng
    const minLeadTimeMs = 3 * 3600 * 1000;
    if (targetDate.getTime() < now + minLeadTimeMs) {
      throw new Error('Thời gian bảo trì theo lịch phải được thiết lập trước ít nhất 3 tiếng!');
    }

    // Chủ dự án chốt 2026-11-16: chỉ đặt lịch trong 14 ngày tới. Hẹn giờ của Node tối đa ~24,8 ngày,
    // quá mức đó setTimeout chạy ngay và bảo trì bật lập tức.
    if (targetDate.getTime() > now + MAX_LEAD_TIME_MS) {
      throw new Error('Chỉ được lên lịch bảo trì trong vòng 14 ngày tới!');
    }

    let targetEndDate = null;
    if (scheduledEndAt) {
      targetEndDate = new Date(scheduledEndAt);
      if (isNaN(targetEndDate.getTime()) || targetEndDate.getTime() <= targetDate.getTime()) {
        throw new Error('Thời điểm kết thúc bảo trì phải sau thời điểm bắt đầu bảo trì!');
      }
      if (targetEndDate.getTime() - targetDate.getTime() > MAX_SESSION_MS) {
        throw new Error('Một phiên bảo trì kéo dài tối đa 7 ngày!');
      }
    }

    const minIntervalMs = 12 * 3600 * 1000;
    const newStart = targetDate.getTime();
    const newEnd = targetEndDate ? targetEndDate.getTime() : newStart;

    // PO RÀNG BUỘC 2: Kiểm tra khoảng cách tối thiểu 12 tiếng với các lịch đã lên
    for (const item of this.scheduledList) {
      const itemStart = new Date(item.scheduledAt).getTime();
      const itemEnd = item.scheduledEndAt ? new Date(item.scheduledEndAt).getTime() : itemStart;

      // 1. Kiểm tra trùng lặp thời gian
      if (newStart < itemEnd && newEnd > itemStart) {
        throw new Error('Thời gian bảo trì bị trùng lặp với một lịch bảo trì đã tồn tại!');
      }

      // 2. Kiểm tra khoảng cách 12 tiếng
      if (newStart >= itemEnd) {
        const gap = newStart - itemEnd;
        if (gap < minIntervalMs) {
          throw new Error('Mỗi phiên bảo trì theo lịch phải cách nhau ít nhất 12 tiếng!');
        }
      } else if (newEnd <= itemStart) {
        const gap = itemStart - newEnd;
        if (gap < minIntervalMs) {
          throw new Error('Mỗi phiên bảo trì theo lịch phải cách nhau ít nhất 12 tiếng!');
        }
      }
    }

    const resolvedType = type || (isUpgrade ? 'UPGRADE' : 'SCHEDULED');
    const schedItem = {
      id: Date.now() + Math.floor(Math.random() * 1000),
      recordId: null,
      scheduledAt: targetDate.toISOString(),
      scheduledEndAt: targetEndDate ? targetEndDate.toISOString() : null,
      reason: reason || (resolvedType === 'UPGRADE' ? 'Nâng cấp hệ thống theo lịch trình.' : 'Bảo trì hệ thống theo lịch trình định kỳ.'),
      isEmergency: false,
      isUpgrade: Boolean(isUpgrade || resolvedType === 'UPGRADE'),
      type: resolvedType,
      createdBy,
      createdAt: new Date().toISOString(),
      _timer: null,
    };

    this._armScheduleItem(schedItem, delayMs);

    // PO YÊU CẦU: Lưu ngay vào CSDL PostgreSQL với trạng thái SCHEDULED (hoặc mock repository trong unit test)
    try {
      const repo = this.repository || require('../../modules/admin/maintenance.repository').defaultMaintenanceRepository;
      repo.createRecord({
        type: schedItem.type,
        reason: schedItem.reason,
        activated_by: schedItem.createdBy,
        started_at: schedItem.scheduledAt,
        scheduled_end_at: schedItem.scheduledEndAt,
        status: 'SCHEDULED',
      }).then((record) => {
        if (record && schedItem) {
          schedItem.recordId = record.id;
        }
      }).catch((err) => {
        logger.warn('[MAINTENANCE] Lỗi lưu CSDL lịch bảo trì SCHEDULED', { error: err.message });
      });
    } catch (repoErr) {
      logger.warn('[MAINTENANCE] Không thể gọi maintenance repository khi schedule', { error: repoErr.message });
    }

    logger.info('[MAINTENANCE] Đã lên lịch bảo trì hệ thống', {
      scheduledAt: schedItem.scheduledAt,
      scheduledEndAt: schedItem.scheduledEndAt,
      isEmergency: schedItem.isEmergency,
      delayMs,
    });

    try {
      const { emitMaintenanceChanged } = require('../socket');
      emitMaintenanceChanged(this.getStatus());
    } catch (_) {}

    return this.getStatus();
  }

  async cancelScheduledMaintenance(id = null) {
    let cancelled = false;
    let targetRecordId = null;

    if (id !== null && id !== undefined) {
      const numericId = Number(id);
      const targetIdx = this.scheduledList.findIndex(
        (x) => x.id === id || x.id === numericId || x.recordId === id || x.recordId === numericId
      );
      if (targetIdx !== -1) {
        const target = this.scheduledList[targetIdx];
        if (target._timer) {
          clearTimeout(target._timer);
          target._timer = null;
        }
        targetRecordId = target.recordId || target.id;
        this.scheduledList.splice(targetIdx, 1);
        cancelled = true;
      } else {
        targetRecordId = numericId || id;
        cancelled = true;
      }
    } else {
      if (this.scheduledList.length > 0) {
        for (const item of this.scheduledList) {
          if (item._timer) {
            clearTimeout(item._timer);
            item._timer = null;
          }
        }
        targetRecordId = this.scheduledList[0]?.recordId || null;
        this.scheduledList = [];
        cancelled = true;
      }
    }

    if (this._scheduledTimer) {
      clearTimeout(this._scheduledTimer);
      this._scheduledTimer = null;
    }
    this.scheduled = this.getNearestSchedule();

    if (targetRecordId) {
      try {
        const { defaultMaintenanceRepository } = require('../../modules/admin/maintenance.repository');
        await defaultMaintenanceRepository.cancelScheduledRecord({
          id: targetRecordId,
          reason: 'Admin chủ động hủy lịch bảo trì',
        });
      } catch (err) {
        logger.warn('[MAINTENANCE] Lỗi CSDL khi hủy lịch chủ động', { error: err.message });
      }
    }

    try {
      const { emitMaintenanceChanged } = require('../socket');
      emitMaintenanceChanged(this.getStatus());
    } catch (_) {}

    return { cancelled, remaining: this.scheduledList.length };
  }

  getStatus() {
    return {
      active: this.active,
      restorePending: Boolean(this.restorePending),
      isEmergency: this.isEmergency,
      isUpgrade: Boolean(this.isUpgrade),
      type: this.isUpgrade ? 'UPGRADE' : (this.isEmergency ? 'EMERGENCY' : 'SCHEDULED'),
      reason: this.reason,
      activatedBy: this.activatedBy,
      activatedAt: this.activatedAt,
      scheduled: this.getNearestSchedule(),
      scheduledList: this.getScheduledList(),
    };
  }

  /**
   * Kích hoạt đối soát trạng thái với CSDL (Reconciliation)
   * Đảm bảo CSDL và RAM/Redis đồng nhất, dọn dẹp các phiên bảo trì ma mồ côi
   * 
   * @param {Object} customRepository Tuỳ chọn repository (dùng khi inject trong test)
   */
  async reconcileStateWithDatabase(customRepository = null) {
    try {
      const repo = customRepository || require('../../modules/admin/maintenance.repository').defaultMaintenanceRepository;
      if (repo && typeof repo.reconcileWithDatabase === 'function') {
        const result = await repo.reconcileWithDatabase({
          currentActiveState: this.getStatus(),
        });
        logger.info('[MAINTENANCE] Hoàn tất đối soát trạng thái với CSDL (Reconciliation)', result);
        return { success: true, ...result };
      }
      return { success: false, reason: 'NO_REPOSITORY' };
    } catch (err) {
      logger.warn('[MAINTENANCE] Lỗi đối soát trạng thái bảo trì với CSDL:', { error: err.message });
      return { success: false, error: err.message };
    }
  }
}

const defaultMaintenanceManager = new MaintenanceManager();

module.exports = {
  MaintenanceManager,
  defaultMaintenanceManager,
};
