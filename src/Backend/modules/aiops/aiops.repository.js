const { pool } = require('../../config/db');
const logger = require('../../core/logger');

/**
 * AIOps Incident Repository
 * Quản lý đọc/ghi CSDL PostgreSQL cho các sự cố bất thường của hệ thống AIOps Sentinel.
 * Đảm bảo dữ liệu được lưu vĩnh viễn (tối thiểu 12 tháng theo NĐ 53/2022/NĐ-CP) và hỗ trợ phân trang Server-side.
 */
class AIOpsIncidentRepository {
  constructor(options = {}) {
    this.pool = options.pool !== undefined ? options.pool : pool;
    this._inMemoryFallback = []; // Dự phòng an toàn cho môi trường test khi không có CSDL
    this._settingsFallback = new Map([['target_concurrency', '1000']]); // Lưu cứng mặc định 1,000 CCU
  }

  /**
   * Khởi tạo bảng CSDL aiops_incident và aiops_setting nếu chưa tồn tại
   */
  async initTable() {
    if (!this.pool || typeof this.pool.query !== 'function') return false;
    const sql = `
      CREATE TABLE IF NOT EXISTS "aiops_incident" (
        "id" VARCHAR(256) PRIMARY KEY,
        "code" VARCHAR(50) NOT NULL,
        "vector" VARCHAR(20) NOT NULL,
        "severity" VARCHAR(10) NOT NULL,
        "message" TEXT NOT NULL,
        "status" VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
        "actor_type" VARCHAR(30) NOT NULL,
        "actor_identity" VARCHAR(256) NOT NULL,
        "actor_hash" VARCHAR(256) NOT NULL,
        "user_id" INT NULL,
        "username" VARCHAR(255) NULL,
        "user_agent" TEXT NULL,
        "target_endpoint" VARCHAR(255) NULL,
        "metric_current" NUMERIC NULL,
        "metric_baseline" NUMERIC NULL,
        "metric_unit" VARCHAR(50) NULL,
        "mitigation_taken" TEXT NULL,
        "root_cause_diagnosis" TEXT NULL,
        "hits" INT NOT NULL DEFAULT 1,
        "first_detected_at" TIMESTAMP(6) NOT NULL DEFAULT NOW(),
        "last_seen_at" TIMESTAMP(6) NOT NULL DEFAULT NOW(),
        "mitigated_at" TIMESTAMP(6) NULL
      );
      CREATE INDEX IF NOT EXISTS "idx_aiops_incident_status" ON "aiops_incident"("status");
      CREATE INDEX IF NOT EXISTS "idx_aiops_incident_vector" ON "aiops_incident"("vector");
      CREATE INDEX IF NOT EXISTS "idx_aiops_incident_detected_at" ON "aiops_incident"("first_detected_at" DESC);
      CREATE INDEX IF NOT EXISTS "idx_aiops_incident_actor_hash" ON "aiops_incident"("actor_hash");

      CREATE TABLE IF NOT EXISTS "aiops_setting" (
        "key" VARCHAR(64) PRIMARY KEY,
        "value" TEXT NOT NULL,
        "updated_at" TIMESTAMP(6) NOT NULL DEFAULT NOW()
      );
      INSERT INTO "aiops_setting" ("key", "value", "updated_at")
      VALUES ('target_concurrency', '1000', NOW())
      ON CONFLICT ("key") DO NOTHING;
    `;
    try {
      await this.pool.query(sql);
      logger.info('[AIOps Repository] Các bảng aiops_incident & aiops_setting đã sẵn sàng trong PostgreSQL.');
      return true;
    } catch (err) {
      logger.warn('[AIOps Repository] Không thể khởi tạo bảng aiops_incident / aiops_setting (dùng fallback bộ nhớ)', { error: err.message });
      return false;
    }
  }

  /**
   * Chèn mới hoặc cập nhật sự cố đang diễn ra vào CSDL
   */
  async upsertIncident(data) {
    const id = data.id || `inc_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const code = data.code || 'UNKNOWN_ANOMALY';
    const vector = data.vector || 'system';
    const severity = data.severity || 'HIGH';
    const message = data.message || 'Phát hiện bất thường';
    const status = data.status || 'ACTIVE';
    
    const actor = data.actor || {};
    const actorType = actor.type || 'IP_SOURCE';
    const actorIdentity = actor.identity || actor.maskedIp || 'xx.xx.xx.xx';
    const actorHash = actor.ipHash || actor.hash || '0000000000000000';
    const userId = actor.userId || null;
    const username = actor.username || null;
    const userAgent = actor.userAgent || null;
    const targetEndpoint = actor.targetEndpoint || actor.endpoint || null;

    const metricCurrent = data.current !== undefined ? data.current : (data.metricCurrent || null);
    const metricBaseline = data.baseline !== undefined ? data.baseline : (data.metricBaseline || null);
    const metricUnit = data.unit || data.metricUnit || '';
    const mitigationTaken = data.mitigationTaken || null;
    const rootCauseDiagnosis = data.rootCauseDiagnosis || null;

    try {
      if (this.pool && typeof this.pool.query === 'function') {
        // Tìm sự cố cùng loại đang ACTIVE của đối tượng này trong 15 phút gần nhất
        const findSql = `
          SELECT * FROM "aiops_incident"
          WHERE "code" = $1 AND "actor_hash" = $2 AND "status" = 'ACTIVE'
            AND "last_seen_at" >= NOW() - INTERVAL '15 minutes'
          ORDER BY "first_detected_at" DESC
          LIMIT 1
        `;
        const existing = await this.pool.query(findSql, [code, actorHash]);
        if (existing.rows.length > 0) {
          const row = existing.rows[0];
          const updateSql = `
            UPDATE "aiops_incident"
            SET "hits" = "hits" + 1,
                "last_seen_at" = NOW(),
                "metric_current" = $1,
                "message" = $2
            WHERE "id" = $3
            RETURNING *
          `;
          const updated = await this.pool.query(updateSql, [metricCurrent, message, row.id]);
          return this._mapRow(updated.rows[0]);
        }

        // Chèn mới
        const insertSql = `
          INSERT INTO "aiops_incident" (
            "id", "code", "vector", "severity", "message", "status",
            "actor_type", "actor_identity", "actor_hash", "user_id", "username", "user_agent", "target_endpoint",
            "metric_current", "metric_baseline", "metric_unit", "mitigation_taken", "root_cause_diagnosis",
            "hits", "first_detected_at", "last_seen_at"
          ) VALUES (
            $1, $2, $3, $4, $5, $6,
            $7, $8, $9, $10, $11, $12, $13,
            $14, $15, $16, $17, $18,
            1, NOW(), NOW()
          )
          RETURNING *
        `;
        const res = await this.pool.query(insertSql, [
          id, code, vector, severity, message, status,
          actorType, actorIdentity, actorHash, userId, username, userAgent, targetEndpoint,
          metricCurrent, metricBaseline, metricUnit, mitigationTaken, rootCauseDiagnosis,
        ]);
        return this._mapRow(res.rows[0]);
      }
    } catch (err) {
      logger.warn('[AIOps Repository] Lỗi ghi DB khi upsert incident, dùng memory fallback', { error: err.message });
    }

    // Fallback bộ nhớ in-memory
    const existingIdx = this._inMemoryFallback.findIndex(
      (i) => i.code === code && i.actor?.ipHash === actorHash && i.status === 'ACTIVE'
    );
    const nowIso = new Date().toISOString();
    if (existingIdx >= 0) {
      const item = this._inMemoryFallback[existingIdx];
      item.hits = (item.hits || 1) + 1;
      item.lastSeenAt = nowIso;
      item.metricCurrent = metricCurrent;
      item.message = message;
      return item;
    }

    const fallbackRecord = {
      id,
      code,
      vector,
      severity,
      message,
      status,
      actor: {
        type: actorType,
        identity: actorIdentity,
        maskedIp: actorIdentity,
        ipHash: actorHash,
        userId,
        username,
        userAgent,
        targetEndpoint,
      },
      current: metricCurrent,
      baseline: metricBaseline,
      unit: metricUnit,
      mitigationTaken,
      rootCauseDiagnosis,
      hits: 1,
      firstDetectedAt: nowIso,
      lastSeenAt: nowIso,
      mitigatedAt: null,
    };
    this._inMemoryFallback.unshift(fallbackRecord);
    if (this._inMemoryFallback.length > 200) {
      this._inMemoryFallback.pop();
    }
    return fallbackRecord;
  }

  /**
   * Cập nhật trạng thái sự cố sang MITIGATED
   */
  async markMitigated(id) {
    const nowIso = new Date().toISOString();
    try {
      if (this.pool && typeof this.pool.query === 'function') {
        const sql = `
          UPDATE "aiops_incident"
          SET "status" = 'MITIGATED', "mitigated_at" = NOW()
          WHERE "id" = $1
          RETURNING *
        `;
        const res = await this.pool.query(sql, [id]);
        if (res.rows.length > 0) return this._mapRow(res.rows[0]);
      }
    } catch (_) {}

    const item = this._inMemoryFallback.find((i) => i.id === id);
    if (item) {
      item.status = 'MITIGATED';
      item.mitigatedAt = nowIso;
      return item;
    }
    return null;
  }

  /**
   * Tự động chuyển các sự cố ACTIVE không còn thấy sau staleSeconds sang MITIGATED
   */
  async autoMitigateStaleIncidents(staleSeconds = 60) {
    try {
      if (this.pool && typeof this.pool.query === 'function') {
        const sql = `
          UPDATE "aiops_incident"
          SET "status" = 'MITIGATED', "mitigated_at" = NOW()
          WHERE "status" = 'ACTIVE' AND "last_seen_at" < NOW() - ($1 || ' seconds')::INTERVAL
          RETURNING *
        `;
        const res = await this.pool.query(sql, [staleSeconds]);
        return res.rows.map((r) => this._mapRow(r));
      }
    } catch (_) {}

    const cutoff = Date.now() - staleSeconds * 1000;
    const mitigated = [];
    for (const item of this._inMemoryFallback) {
      if (item.status === 'ACTIVE' && new Date(item.lastSeenAt).getTime() < cutoff) {
        item.status = 'MITIGATED';
        item.mitigatedAt = new Date().toISOString();
        mitigated.push(item);
      }
    }
    return mitigated;
  }

  /**
   * Lấy danh sách sự cố có phân trang và bộ lọc trực tiếp từ CSDL
   */
  async getIncidents({ page = 1, limit = 10, vector = 'all', status = 'all', search = '' } = {}) {
    const currentPage = Math.max(1, parseInt(page, 10) || 1);
    const pageSize = Math.max(1, Math.min(100, parseInt(limit, 10) || 10));
    const offset = (currentPage - 1) * pageSize;

    try {
      if (this.pool && typeof this.pool.query === 'function') {
        const conditions = [];
        const params = [];
        let pIdx = 1;

        if (vector && vector !== 'all') {
          conditions.push(`"vector" = $${pIdx++}`);
          params.push(vector);
        }

        if (status && status !== 'all') {
          conditions.push(`"status" = $${pIdx++}`);
          params.push(status);
        }

        if (search && search.trim()) {
          const s = `%${search.trim()}%`;
          conditions.push(`(
            "actor_identity" ILIKE $${pIdx} OR 
            "username" ILIKE $${pIdx} OR 
            "code" ILIKE $${pIdx} OR 
            "message" ILIKE $${pIdx}
          )`);
          params.push(s);
          pIdx++;
        }

        const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
        const countSql = `SELECT COUNT(*) AS total FROM "aiops_incident" ${whereClause}`;
        const countRes = await this.pool.query(countSql, params);
        const total = parseInt(countRes.rows[0]?.total || '0', 10);

        const dataSql = `
          SELECT * FROM "aiops_incident"
          ${whereClause}
          ORDER BY "first_detected_at" DESC
          LIMIT $${pIdx++} OFFSET $${pIdx++}
        `;
        const dataRes = await this.pool.query(dataSql, [...params, pageSize, offset]);
        const incidents = dataRes.rows.map((r) => this._mapRow(r));

        return {
          incidents,
          total,
          page: currentPage,
          limit: pageSize,
          totalPages: Math.ceil(total / pageSize) || 1,
        };
      }
    } catch (err) {
      logger.warn('[AIOps Repository] Lỗi query CSDL, dùng memory fallback', { error: err.message });
    }

    // Memory Fallback
    let filtered = [...this._inMemoryFallback];
    if (vector && vector !== 'all') {
      filtered = filtered.filter((i) => i.vector === vector);
    }
    if (status && status !== 'all') {
      filtered = filtered.filter((i) => i.status === status);
    }
    if (search && search.trim()) {
      const s = search.trim().toLowerCase();
      filtered = filtered.filter(
        (i) =>
          (i.actor?.identity && i.actor.identity.toLowerCase().includes(s)) ||
          (i.actor?.username && i.actor.username.toLowerCase().includes(s)) ||
          (i.code && i.code.toLowerCase().includes(s)) ||
          (i.message && i.message.toLowerCase().includes(s))
      );
    }

    const total = filtered.length;
    const sliced = filtered.slice(offset, offset + pageSize);
    return {
      incidents: sliced,
      total,
      page: currentPage,
      limit: pageSize,
      totalPages: Math.ceil(total / pageSize) || 1,
    };
  }

  /**
   * Xóa toàn bộ sự cố khi Admin yêu cầu
   */
  async clearIncidents() {
    try {
      if (this.pool && typeof this.pool.query === 'function') {
        await this.pool.query('DELETE FROM "aiops_incident"');
      }
    } catch (_) {}
    this._inMemoryFallback = [];
    return true;
  }

  _mapRow(row) {
    if (!row) return null;
    return {
      id: row.id,
      code: row.code,
      vector: row.vector,
      severity: row.severity,
      message: row.message,
      status: row.status,
      actor: {
        type: row.actor_type,
        identity: row.actor_identity,
        maskedIp: row.actor_identity,
        ipHash: row.actor_hash,
        userId: row.user_id,
        username: row.username,
        userAgent: row.user_agent,
        targetEndpoint: row.target_endpoint,
      },
      current: row.metric_current !== null ? Number(row.metric_current) : null,
      baseline: row.metric_baseline !== null ? Number(row.metric_baseline) : null,
      unit: row.metric_unit,
      mitigationTaken: row.mitigation_taken,
      rootCauseDiagnosis: row.root_cause_diagnosis,
      hits: row.hits,
      firstDetectedAt: row.first_detected_at ? new Date(row.first_detected_at).toISOString() : null,
      lastSeenAt: row.last_seen_at ? new Date(row.last_seen_at).toISOString() : null,
      mitigatedAt: row.mitigated_at ? new Date(row.mitigated_at).toISOString() : null,
    };
  }

  /**
   * Lấy cấu hình tham số AIOps từ CSDL (PostgreSQL aiops_setting)
   */
  async getSetting(key, defaultValue = '1000') {
    if (!this.pool || typeof this.pool.query !== 'function') {
      return this._settingsFallback.get(key) || defaultValue;
    }
    try {
      const res = await this.pool.query(
        'SELECT "value" FROM "aiops_setting" WHERE "key" = $1 LIMIT 1;',
        [key]
      );
      if (res.rows && res.rows.length > 0) {
        return res.rows[0].value;
      }
      return defaultValue;
    } catch (err) {
      logger.warn('[AIOps Repository] Lỗi lấy cài đặt từ CSDL, dùng fallback', { key, error: err.message });
      return this._settingsFallback.get(key) || defaultValue;
    }
  }

  /**
   * Lưu cứng cấu hình tham số AIOps vào CSDL (PostgreSQL aiops_setting)
   */
  async setSetting(key, value) {
    this._settingsFallback.set(key, String(value));
    if (!this.pool || typeof this.pool.query !== 'function') return true;
    try {
      const sql = `
        INSERT INTO "aiops_setting" ("key", "value", "updated_at")
        VALUES ($1, $2, NOW())
        ON CONFLICT ("key") 
        DO UPDATE SET "value" = EXCLUDED.value, "updated_at" = NOW();
      `;
      await this.pool.query(sql, [key, String(value)]);
      logger.info(`[AIOps Repository] Đã lưu cứng cài đặt [${key} = ${value}] vào CSDL PostgreSQL`);
      return true;
    } catch (err) {
      logger.warn('[AIOps Repository] Lỗi lưu cài đặt vào CSDL PostgreSQL', { key, value, error: err.message });
      return false;
    }
  }
}

const defaultAIOpsIncidentRepository = new AIOpsIncidentRepository();

module.exports = {
  AIOpsIncidentRepository,
  defaultAIOpsIncidentRepository,
};
