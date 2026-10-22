const { pool } = require('../../config/db');
const logger = require('../../core/logger');

/**
 * Maintenance History Repository
 * Quản lý đọc/ghi CSDL PostgreSQL cho lịch sử các phiên bảo trì hệ thống (Khẩn cấp & Theo lịch).
 * Đảm bảo ghi nhận danh tính Admin kích hoạt, thời gian bắt đầu/kết thúc, thời lượng và trạng thái.
 */
class MaintenanceRepository {
  constructor(options = {}) {
    this.pool = options.pool !== undefined ? options.pool : pool;
    this._inMemoryFallback = [];
    this._pendingDbSyncQueue = [];
    this._nextId = 1;
  }

  /**
   * Khởi tạo bảng maintenance_history nếu chưa tồn tại
   */
  async initTable() {
    if (!this.pool || typeof this.pool.query !== 'function') return false;
    const sql = `
      CREATE TABLE IF NOT EXISTS "maintenance_history" (
        "id" SERIAL PRIMARY KEY,
        "type" VARCHAR(20) NOT NULL DEFAULT 'EMERGENCY',
        "reason" TEXT NOT NULL,
        "activated_by" VARCHAR(100) NOT NULL,
        "started_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        "scheduled_end_at" TIMESTAMP WITH TIME ZONE NULL,
        "ended_at" TIMESTAMP WITH TIME ZONE NULL,
        "status" VARCHAR(20) NOT NULL DEFAULT 'ONGOING',
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS "idx_maintenance_history_started_at" ON "maintenance_history" ("started_at" DESC);
      CREATE INDEX IF NOT EXISTS "idx_maintenance_history_status" ON "maintenance_history" ("status");
      CREATE INDEX IF NOT EXISTS "idx_maintenance_history_type" ON "maintenance_history" ("type");
    `;
    try {
      await this.pool.query(sql);
      logger.info('[Maintenance Repository] Bảng maintenance_history đã sẵn sàng trong PostgreSQL.');
      return true;
    } catch (err) {
      logger.warn('[Maintenance Repository] Không thể khởi tạo bảng maintenance_history (dùng fallback)', { error: err.message });
      return false;
    }
  }

  /**
   * Tạo bản ghi phiên bảo trì mới
   */
  async createRecord({
    type = 'EMERGENCY',
    reason = 'Bảo trì hệ thống.',
    activated_by = 'admin',
    started_at = new Date(),
    scheduled_end_at = null,
    status = 'ONGOING',
  } = {}) {
    const startedAtIso = started_at instanceof Date ? started_at.toISOString() : new Date(started_at).toISOString();
    const scheduledEndAtIso = scheduled_end_at
      ? (scheduled_end_at instanceof Date ? scheduled_end_at.toISOString() : new Date(scheduled_end_at).toISOString())
      : null;

    if (this.pool && typeof this.pool.query === 'function') {
      try {
        const query = `
          INSERT INTO "maintenance_history" ("type", "reason", "activated_by", "started_at", "scheduled_end_at", "status")
          VALUES ($1, $2, $3, $4, $5, $6)
          RETURNING *;
        `;
        const res = await this.pool.query(query, [
          type,
          reason,
          activated_by,
          startedAtIso,
          scheduledEndAtIso,
          status,
        ]);
        return res.rows[0];
      } catch (err) {
        logger.error('[Maintenance Repository] createRecord DB error, fallback to memory', { error: err.message });
      }
    }

    // Memory fallback & Outbox Queue
    const record = {
      id: this._nextId++,
      type,
      reason,
      activated_by,
      started_at: startedAtIso,
      scheduled_end_at: scheduledEndAtIso,
      ended_at: null,
      status,
      created_at: new Date().toISOString(),
    };
    this._inMemoryFallback.unshift(record);
    this._pendingDbSyncQueue.push({
      action: 'CREATE_RECORD',
      payload: { ...record },
      queuedAt: new Date().toISOString(),
    });
    return record;
  }

  /**
   * Đóng phiên bảo trì đang diễn ra (chuyển ONGOING -> COMPLETED)
   */
  async completeOngoingRecord({ ended_at = new Date(), status = 'COMPLETED' } = {}) {
    const endedAtIso = ended_at instanceof Date ? ended_at.toISOString() : new Date(ended_at).toISOString();

    if (this.pool && typeof this.pool.query === 'function') {
      try {
        const query = `
          UPDATE "maintenance_history"
          SET "ended_at" = $1, "status" = $2
          WHERE "status" = 'ONGOING'
          RETURNING *;
        `;
        const res = await this.pool.query(query, [endedAtIso, status]);
        return res.rows;
      } catch (err) {
        logger.error('[Maintenance Repository] completeOngoingRecord DB error, fallback to memory', { error: err.message });
      }
    }

    // Memory fallback
    const updated = [];
    for (const item of this._inMemoryFallback) {
      if (item.status === 'ONGOING') {
        item.ended_at = endedAtIso;
        item.status = status;
        updated.push(item);
      }
    }
    this._pendingDbSyncQueue.push({
      action: 'COMPLETE_ONGOING',
      payload: { ended_at: endedAtIso, status },
      queuedAt: new Date().toISOString(),
    });
    return updated;
  }

  /**
   * Nâng cấp bản ghi ONGOING thông thường sang EMERGENCY khi có sự cố khẩn cấp can thiệp
   */
  async updateOngoingToEmergency({ reason = null, activated_by = null } = {}) {
    if (this.pool && typeof this.pool.query === 'function') {
      try {
        const query = `
          UPDATE "maintenance_history"
          SET "type" = 'EMERGENCY', "reason" = COALESCE($1, "reason"), "activated_by" = COALESCE($2, "activated_by")
          WHERE "status" = 'ONGOING'
          RETURNING *;
        `;
        const res = await this.pool.query(query, [reason, activated_by]);
        return res.rows;
      } catch (err) {
        logger.error('[Maintenance Repository] updateOngoingToEmergency DB error, fallback to memory', { error: err.message });
      }
    }

    // Memory fallback
    const updated = [];
    for (const item of this._inMemoryFallback) {
      if (item.status === 'ONGOING') {
        item.type = 'EMERGENCY';
        if (reason) item.reason = reason;
        if (activated_by) item.activated_by = activated_by;
        updated.push(item);
      }
    }
    this._pendingDbSyncQueue.push({
      action: 'UPDATE_TO_EMERGENCY',
      payload: { reason, activated_by },
      queuedAt: new Date().toISOString(),
    });
    return updated;
  }

  /**
   * Cập nhật trạng thái một bản ghi bảo trì theo ID (dùng khi chuyển SCHEDULED -> ONGOING hoặc CANCELLED)
   */
  async updateRecordStatus(id, { status, ended_at = null, started_at = null, reason = null } = {}) {
    if (!id) return null;
    const endedAtIso = ended_at ? (ended_at instanceof Date ? ended_at.toISOString() : new Date(ended_at).toISOString()) : null;
    const startedAtIso = started_at ? (started_at instanceof Date ? started_at.toISOString() : new Date(started_at).toISOString()) : null;

    if (this.pool && typeof this.pool.query === 'function') {
      try {
        const setClauses = ['"status" = $1'];
        const params = [status];
        let idx = 2;

        if (endedAtIso !== null) {
          setClauses.push(`"ended_at" = $${idx++}`);
          params.push(endedAtIso);
        }
        if (startedAtIso !== null) {
          setClauses.push(`"started_at" = $${idx++}`);
          params.push(startedAtIso);
        }
        if (reason !== null) {
          setClauses.push(`"reason" = $${idx++}`);
          params.push(reason);
        }

        params.push(id);
        const query = `
          UPDATE "maintenance_history"
          SET ${setClauses.join(', ')}
          WHERE "id" = $${idx}
          RETURNING *;
        `;
        const res = await this.pool.query(query, params);
        return res.rows[0] || null;
      } catch (err) {
        logger.error('[Maintenance Repository] updateRecordStatus DB error, fallback to memory', { error: err.message });
      }
    }

    // Memory fallback
    const item = this._inMemoryFallback.find((x) => x.id === id);
    if (item) {
      if (status) item.status = status;
      if (endedAtIso !== null) item.ended_at = endedAtIso;
      if (startedAtIso !== null) item.started_at = startedAtIso;
      if (reason !== null) item.reason = reason;
      return item;
    }
    return null;
  }

  /**
   * Hủy phiên bảo trì theo lịch (chuyển SCHEDULED hoặc ONGOING theo lịch -> CANCELLED)
   */
  async cancelScheduledRecord({ id = null, cancelled_by = 'admin', reason = 'Bị hủy hoặc bị trùng lịch bảo trì khẩn cấp' } = {}) {
    const nowIso = new Date().toISOString();
    if (this.pool && typeof this.pool.query === 'function') {
      try {
        let query;
        let params;
        if (id) {
          query = `
            UPDATE "maintenance_history"
            SET "ended_at" = $1, "status" = 'CANCELLED'
            WHERE "id" = $2
            RETURNING *;
          `;
          params = [nowIso, id];
        } else {
          query = `
            UPDATE "maintenance_history"
            SET "ended_at" = $1, "status" = 'CANCELLED'
            WHERE ("status" = 'SCHEDULED' OR ("status" = 'ONGOING' AND "type" = 'SCHEDULED'))
            RETURNING *;
          `;
          params = [nowIso];
        }
        const res = await this.pool.query(query, params);
        return res.rows;
      } catch (err) {
        logger.error('[Maintenance Repository] cancelScheduledRecord DB error', { error: err.message });
      }
    }

    const updated = [];
    for (const item of this._inMemoryFallback) {
      if (id && item.id === id) {
        item.ended_at = nowIso;
        item.status = 'CANCELLED';
        updated.push(item);
      } else if (!id && (item.status === 'SCHEDULED' || (item.status === 'ONGOING' && item.type === 'SCHEDULED'))) {
        item.ended_at = nowIso;
        item.status = 'CANCELLED';
        updated.push(item);
      }
    }
    return updated;
  }

  /**
   * Lấy danh sách tất cả các lịch bảo trì đang chờ thực hiện (status = 'SCHEDULED')
   */
  async getActiveScheduledRecords() {
    if (this.pool && typeof this.pool.query === 'function') {
      try {
        const query = `
          SELECT * FROM "maintenance_history"
          WHERE "status" = 'SCHEDULED'
          ORDER BY "started_at" ASC;
        `;
        const res = await this.pool.query(query);
        return res.rows;
      } catch (err) {
        logger.error('[Maintenance Repository] getActiveScheduledRecords DB error, fallback to memory', { error: err.message });
      }
    }

    return this._inMemoryFallback
      .filter((x) => x.status === 'SCHEDULED')
      .sort((a, b) => new Date(a.started_at).getTime() - new Date(b.started_at).getTime());
  }

  /**
   * Lấy danh sách lịch sử bảo trì phân trang
   */
  async getHistory({ page = 1, limit = 10, type = null, status = null } = {}) {
    const p = Math.max(1, parseInt(page, 10) || 1);
    const l = Math.min(100, Math.max(1, parseInt(limit, 10) || 10));
    const offset = (p - 1) * l;

    if (this.pool && typeof this.pool.query === 'function') {
      try {
        const whereClauses = [];
        const params = [];
        let idx = 1;

        if (type && type !== 'ALL') {
          whereClauses.push(`"type" = $${idx++}`);
          params.push(type.toUpperCase());
        }
        if (status && status !== 'ALL') {
          whereClauses.push(`"status" = $${idx++}`);
          params.push(status.toUpperCase());
        }

        const whereSql = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';

        const countQuery = `SELECT COUNT(*) AS total FROM "maintenance_history" ${whereSql};`;
        const countRes = await this.pool.query(countQuery, params);
        const total = parseInt(countRes.rows[0]?.total || 0, 10);

        const dataQuery = `
          SELECT * FROM "maintenance_history"
          ${whereSql}
          ORDER BY "started_at" DESC
          LIMIT $${idx++} OFFSET $${idx++};
        `;
        const dataRes = await this.pool.query(dataQuery, [...params, l, offset]);

        return {
          data: dataRes.rows,
          pagination: {
            page: p,
            limit: l,
            total,
            totalPages: Math.ceil(total / l) || 1,
          },
        };
      } catch (err) {
        logger.error('[Maintenance Repository] getHistory DB error, fallback to memory', { error: err.message });
      }
    }

    // Memory fallback
    let list = [...this._inMemoryFallback];
    if (type && type !== 'ALL') {
      list = list.filter((x) => x.type === type.toUpperCase());
    }
    if (status && status !== 'ALL') {
      list = list.filter((x) => x.status === status.toUpperCase());
    }

    const total = list.length;
    const paged = list.slice(offset, offset + l);

    return {
      data: paged,
      pagination: {
        page: p,
        limit: l,
        total,
        totalPages: Math.ceil(total / l) || 1,
      },
    };
  }

  /**
   * Tính tổng số giây hệ thống bị gián đoạn do Bảo trì khẩn cấp (Emergency Outage)
   * Phục vụ tính toán SLA và Uptime hoạt động thực tế (Phương án 1 được PO duyệt).
   * @param {Date} sinceDate
   * @returns {Promise<number>}
   */
  async getEmergencyDowntimeSeconds(sinceDate = null) {
    const since = sinceDate instanceof Date ? sinceDate : new Date(Date.now() - 30 * 24 * 3600 * 1000);
    const sinceIso = since.toISOString();

    if (this.pool && typeof this.pool.query === 'function') {
      try {
        const query = `
          SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (COALESCE("ended_at", NOW()) - "started_at"))), 0) AS total_sec
          FROM "maintenance_history"
          WHERE "type" = 'EMERGENCY'
            AND "status" IN ('COMPLETED', 'ONGOING')
            AND "started_at" >= $1;
        `;
        const res = await this.pool.query(query, [sinceIso]);
        const sec = parseFloat(res.rows[0]?.total_sec || 0);
        return Math.max(0, Math.floor(sec));
      } catch (err) {
        logger.warn('[Maintenance Repository] getEmergencyDowntimeSeconds DB error, fallback to memory', { error: err.message });
      }
    }

    // Memory fallback
    let totalSec = 0;
    const sinceTime = since.getTime();
    for (const item of this._inMemoryFallback) {
      if (item.type === 'EMERGENCY' && (item.status === 'COMPLETED' || item.status === 'ONGOING')) {
        const start = new Date(item.started_at).getTime();
        if (start >= sinceTime) {
          const end = item.ended_at ? new Date(item.ended_at).getTime() : Date.now();
          totalSec += Math.max(0, Math.floor((end - start) / 1000));
        }
      }
    }
    return totalSec;
  }

  /**
   * Kiểm tra xem còn tác vụ ghi CSDL nào đang tồn đọng trong Outbox hay không
   */
  hasPendingSync() {
    return Array.isArray(this._pendingDbSyncQueue) && this._pendingDbSyncQueue.length > 0;
  }

  /**
   * Tự động flush các tác vụ trong Outbox Queue vào CSDL PostgreSQL khi kết nối sẵn sàng
   */
  async flushPendingQueue() {
    if (!this.pool || typeof this.pool.query !== 'function') return 0;
    if (!this.hasPendingSync()) return 0;

    let flushed = 0;
    const remaining = [];

    while (this._pendingDbSyncQueue.length > 0) {
      const task = this._pendingDbSyncQueue.shift();
      try {
        if (task.action === 'CREATE_RECORD') {
          const { type, reason, activated_by, started_at, scheduled_end_at, status } = task.payload;
          const query = `
            INSERT INTO "maintenance_history" ("type", "reason", "activated_by", "started_at", "scheduled_end_at", "status")
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *;
          `;
          await this.pool.query(query, [type, reason, activated_by, started_at, scheduled_end_at, status]);
          flushed++;
        } else if (task.action === 'COMPLETE_ONGOING') {
          const { ended_at, status } = task.payload;
          const query = `
            UPDATE "maintenance_history"
            SET "ended_at" = $1, "status" = $2
            WHERE "status" = 'ONGOING'
            RETURNING *;
          `;
          await this.pool.query(query, [ended_at, status]);
          flushed++;
        } else if (task.action === 'UPDATE_TO_EMERGENCY') {
          const { reason, activated_by } = task.payload;
          const query = `
            UPDATE "maintenance_history"
            SET "type" = 'EMERGENCY', "reason" = COALESCE($1, "reason"), "activated_by" = COALESCE($2, "activated_by")
            WHERE "status" = 'ONGOING'
            RETURNING *;
          `;
          await this.pool.query(query, [reason, activated_by]);
          flushed++;
        }
      } catch (err) {
        logger.warn('[Maintenance Repository] Lỗi khi flush tác vụ outbox, hoàn trả lại queue', { action: task.action, error: err.message });
        remaining.push(task);
        break;
      }
    }

    if (remaining.length > 0) {
      this._pendingDbSyncQueue.unshift(...remaining);
    }

    if (flushed > 0) {
      logger.info(`[Maintenance Repository] Đã flush thành công ${flushed} tác vụ bảo trì tồn đọng vào CSDL.`);
    }

    return flushed;
  }

  /**
   * Cơ chế Đối soát & Đồng bộ Hai chiều (Bi-directional Reconciliation Engine)
   * Triệt tiêu hoàn toàn lỗi "Bảo trì ma" (Ghost Maintenance) khi CSDL khôi phục.
   * 
   * @param {Object} options
   * @param {Object} options.currentActiveState Trạng thái sống hiện tại trên RAM/Redis
   */
  async reconcileWithDatabase({ currentActiveState } = {}) {
    if (!this.pool || typeof this.pool.query !== 'function') {
      return { success: false, reason: 'NO_POOL' };
    }

    let ghostSessionsClosed = 0;
    let alignedWithActive = false;

    try {
      const isSystemCurrentlyActive = currentActiveState && Boolean(currentActiveState.active);

      if (!isSystemCurrentlyActive) {
        // CHỐT CHẶN: GHOST MAINTENANCE KILLER
        // Nếu hệ thống hiện tại đang KHÔNG bảo trì, mọi bản ghi ONGOING trong CSDL đều là bản ghi mồ côi
        // do CSDL bị sập lúc Admin tắt bảo trì. Buộc phải đóng lại ngay lập tức!
        const query = `
          UPDATE "maintenance_history"
          SET "status" = 'COMPLETED', "ended_at" = COALESCE("ended_at", NOW())
          WHERE "status" = 'ONGOING'
          RETURNING *;
        `;
        const res = await this.pool.query(query, [new Date().toISOString()]);
        ghostSessionsClosed = (res?.rows || []).length;
        if (ghostSessionsClosed > 0) {
          logger.warn(`[Maintenance Reconciliation] [GHOST KILLER] Đã đóng ${ghostSessionsClosed} phiên bảo trì mồ côi (ONGOING) trong CSDL để triệt tiêu lỗi bảo trì ma!`);
        }
      } else {
        // STATE ALIGNMENT: Nếu hệ thống ĐANG bảo trì thật sự, đảm bảo CSDL có bản ghi ONGOING đồng bộ
        const checkSql = `SELECT * FROM "maintenance_history" WHERE "status" = 'ONGOING' LIMIT 1;`;
        const checkRes = await this.pool.query(checkSql);
        if (!checkRes?.rows || checkRes.rows.length === 0) {
          const insertSql = `
            INSERT INTO "maintenance_history" ("type", "reason", "activated_by", "started_at", "status")
            VALUES ($1, $2, $3, $4, 'ONGOING')
            RETURNING *;
          `;
          await this.pool.query(insertSql, [
            currentActiveState.isEmergency ? 'EMERGENCY' : 'SCHEDULED',
            currentActiveState.reason || 'Bảo trì hệ thống.',
            currentActiveState.activatedBy || 'admin',
            currentActiveState.activatedAt || new Date().toISOString(),
          ]);
          alignedWithActive = true;
          logger.info('[Maintenance Reconciliation] Đã tạo bản ghi ONGOING trong CSDL để đồng bộ với phiên bảo trì đang diễn ra.');
        }
      }

      // Flush các tác vụ còn tồn trong Outbox Queue
      const flushedCount = await this.flushPendingQueue();

      return {
        success: true,
        ghostSessionsClosed,
        flushedCount,
        alignedWithActive,
      };
    } catch (err) {
      logger.error('[Maintenance Reconciliation] Lỗi đối soát trạng thái với CSDL', { error: err.message });
      return { success: false, error: err.message };
    }
  }
}

const defaultMaintenanceRepository = new MaintenanceRepository();

module.exports = {
  MaintenanceRepository,
  defaultMaintenanceRepository,
};
