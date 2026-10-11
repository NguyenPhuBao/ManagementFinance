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

    // Memory fallback
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
    return updated;
  }

  /**
   * Hủy phiên bảo trì theo lịch (chuyển ONGOING hoặc SCHEDULED -> CANCELLED)
   */
  async cancelScheduledRecord({ cancelled_by = 'admin', reason = 'Bị hủy hoặc bị bảo trì khẩn cấp ghi đè' } = {}) {
    const nowIso = new Date().toISOString();
    if (this.pool && typeof this.pool.query === 'function') {
      try {
        const query = `
          UPDATE "maintenance_history"
          SET "ended_at" = $1, "status" = 'CANCELLED'
          WHERE "status" = 'ONGOING' AND "type" = 'SCHEDULED'
          RETURNING *;
        `;
        const res = await this.pool.query(query, [nowIso]);
        return res.rows;
      } catch (err) {
        logger.error('[Maintenance Repository] cancelScheduledRecord DB error', { error: err.message });
      }
    }

    const updated = [];
    for (const item of this._inMemoryFallback) {
      if (item.status === 'ONGOING' && item.type === 'SCHEDULED') {
        item.ended_at = nowIso;
        item.status = 'CANCELLED';
        updated.push(item);
      }
    }
    return updated;
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
}

const defaultMaintenanceRepository = new MaintenanceRepository();

module.exports = {
  MaintenanceRepository,
  defaultMaintenanceRepository,
};
