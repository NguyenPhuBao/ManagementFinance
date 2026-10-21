const { pool } = require('../../config/db');
const logger = require('../../core/logger');

/**
 * Broadcast Repository — Quản lý lưu trữ CSDL PostgreSQL cho lịch sử phát sóng thông báo hệ thống (System Broadcast).
 * Tuân thủ Data_Security.md: Không lưu dữ liệu nhạy cảm, lưu vết Audit Trail người gửi và thời điểm.
 * Tuân thủ DB Guard Rule 10: Khởi tạo bảng qua script SQL / query an toàn, không dùng prisma db push/migrate dev.
 */
class BroadcastRepository {
  constructor(options = {}) {
    this.pool = options.pool !== undefined ? options.pool : pool;
    this._inMemoryFallback = [];
    this._nextId = 1;
  }

  /**
   * Khởi tạo bảng broadcast_notification nếu chưa tồn tại
   */
  async initTable() {
    if (!this.pool || typeof this.pool.query !== 'function') return false;
    const sql = `
      CREATE TABLE IF NOT EXISTS "broadcast_notification" (
        "id" SERIAL PRIMARY KEY,
        "title" VARCHAR(255) NOT NULL,
        "message" TEXT NOT NULL,
        "level" VARCHAR(20) NOT NULL DEFAULT 'INFO',
        "sender_username" VARCHAR(100) NOT NULL DEFAULT 'admin',
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS "idx_broadcast_notification_created_at" ON "broadcast_notification" ("created_at" DESC);
      CREATE INDEX IF NOT EXISTS "idx_broadcast_notification_level" ON "broadcast_notification" ("level");
    `;
    try {
      await this.pool.query(sql);
      logger.info('[Broadcast Repository] Bảng broadcast_notification đã sẵn sàng trong PostgreSQL.');
      return true;
    } catch (err) {
      logger.warn('[Broadcast Repository] Không thể khởi tạo bảng broadcast_notification (dùng fallback)', { error: err.message });
      return false;
    }
  }

  /**
   * Lưu thông báo phát sóng mới vào CSDL
   */
  async createRecord({
    title,
    message,
    level = 'INFO',
    sender_username = 'admin',
  } = {}) {
    const normLevel = String(level || 'INFO').toUpperCase();
    const createdAt = new Date().toISOString();

    if (this.pool && typeof this.pool.query === 'function') {
      try {
        const query = `
          INSERT INTO "broadcast_notification" ("title", "message", "level", "sender_username", "created_at")
          VALUES ($1, $2, $3, $4, $5)
          RETURNING *;
        `;
        const res = await this.pool.query(query, [
          title,
          message,
          normLevel,
          sender_username,
          createdAt,
        ]);
        return res.rows[0];
      } catch (err) {
        logger.error('[Broadcast Repository] createRecord DB error, fallback to memory', { error: err.message });
      }
    }

    // In-memory fallback
    const record = {
      id: this._nextId++,
      title,
      message,
      level: normLevel,
      sender_username,
      created_at: createdAt,
    };
    this._inMemoryFallback.unshift(record);
    return record;
  }

  /**
   * Lấy danh sách lịch sử phát sóng có phân trang và lọc theo cấp độ
   */
  async getHistory({ page = 1, limit = 5, level } = {}) {
    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.max(1, Math.min(100, parseInt(limit, 10) || 5));
    const offset = (pageNum - 1) * limitNum;

    if (this.pool && typeof this.pool.query === 'function') {
      try {
        const whereClauses = [];
        const params = [];
        let pIndex = 1;

        if (level && level !== 'ALL') {
          whereClauses.push(`"level" = $${pIndex++}`);
          params.push(String(level).toUpperCase());
        }

        const whereSql = whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';

        // Query tổng số bản ghi
        const countRes = await this.pool.query(
          `SELECT COUNT(*)::int AS total FROM "broadcast_notification" ${whereSql}`,
          params
        );
        const total = countRes.rows[0]?.total || 0;

        // Query dữ liệu phân trang
        const dataQuery = `
          SELECT "id", "title", "message", "level", "sender_username", "created_at"
          FROM "broadcast_notification"
          ${whereSql}
          ORDER BY "created_at" DESC, "id" DESC
          LIMIT $${pIndex++} OFFSET $${pIndex++};
        `;
        const dataRes = await this.pool.query(dataQuery, [...params, limitNum, offset]);

        return {
          data: dataRes.rows,
          pagination: {
            page: pageNum,
            limit: limitNum,
            total,
            totalPages: Math.ceil(total / limitNum) || 1,
          },
        };
      } catch (err) {
        logger.error('[Broadcast Repository] getHistory DB error, fallback to memory', { error: err.message });
      }
    }

    // In-memory fallback
    let filtered = [...this._inMemoryFallback];
    if (level && level !== 'ALL') {
      filtered = filtered.filter((r) => r.level === String(level).toUpperCase());
    }

    const total = filtered.length;
    const paginated = filtered.slice(offset, offset + limitNum);

    return {
      data: paginated,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        totalPages: Math.ceil(total / limitNum) || 1,
      },
    };
  }
}

const defaultBroadcastRepository = new BroadcastRepository();
defaultBroadcastRepository.initTable().catch(() => {});

module.exports = {
  BroadcastRepository,
  defaultBroadcastRepository,
};
