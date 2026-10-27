const { pool } = require('../../config/db');
const logger = require('../../core/logger');

/**
 * AIOps Quarantine Repository
 * Quản lý đọc/ghi CSDL PostgreSQL cho 3 bảng ma trận phong tỏa:
 * 1. aiops_ip_quarantine: Quản lý trạng thái & vòng đời địa chỉ IP
 * 2. aiops_account_quarantine: Quản lý trạng thái & vòng đời Tài khoản
 * 3. aiops_quarantine_incident_link: Nhật ký liên kết vi phạm N-N phục vụ điều tra
 */
class AIOpsQuarantineRepository {
  constructor(options = {}) {
    if (options && typeof options.query === 'function') {
      this.pool = options;
    } else {
      this.pool = options?.pool !== undefined ? options.pool : pool;
    }
    // In-memory fallback dự phòng an toàn cho Unit Test hoặc khi gián đoạn CSDL
    this._fallbackIps = new Map(); // key: ip_hash -> record
    this._fallbackAccounts = new Map(); // key: username.toLowerCase() -> record
    this._fallbackLinks = []; // array of link records
  }

  /**
   * Khởi tạo an toàn 3 bảng CSDL nếu chưa tồn tại (IF NOT EXISTS)
   */
  async initTables() {
    if (!this.pool || typeof this.pool.query !== 'function') return false;
    const sql = `
      CREATE TABLE IF NOT EXISTS "aiops_ip_quarantine" (
        "id" VARCHAR(64) PRIMARY KEY,
        "ip_hash" VARCHAR(64) NOT NULL UNIQUE,
        "masked_ip" VARCHAR(45) NOT NULL,
        "raw_ip" VARCHAR(45) NULL,
        "status" VARCHAR(20) NOT NULL DEFAULT 'TEMPORARY',
        "reason" TEXT NOT NULL,
        "violation_vector" VARCHAR(20) NULL,
        "threat_score_at_ban" INT NULL,
        "hits" INT NOT NULL DEFAULT 1,
        "banned_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        "expires_at" TIMESTAMP WITH TIME ZONE NULL,
        "unblocked_at" TIMESTAMP WITH TIME ZONE NULL,
        "banned_by" VARCHAR(100) NOT NULL DEFAULT 'AIOps Sentinel',
        "unblocked_by" VARCHAR(100) NULL,
        "unblock_reason" TEXT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS "idx_aiops_ip_quarantine_status" ON "aiops_ip_quarantine"("status");
      CREATE INDEX IF NOT EXISTS "idx_aiops_ip_quarantine_ip_hash" ON "aiops_ip_quarantine"("ip_hash");
      CREATE INDEX IF NOT EXISTS "idx_aiops_ip_quarantine_expires_at" ON "aiops_ip_quarantine"("expires_at");
      CREATE INDEX IF NOT EXISTS "idx_aiops_ip_quarantine_banned_at" ON "aiops_ip_quarantine"("banned_at" DESC);

      CREATE TABLE IF NOT EXISTS "aiops_account_quarantine" (
        "id" VARCHAR(64) PRIMARY KEY,
        "idaccount" INT NULL,
        "username" VARCHAR(255) NOT NULL,
        "status" VARCHAR(20) NOT NULL DEFAULT 'TEMPORARY',
        "reason" TEXT NOT NULL,
        "violation_vector" VARCHAR(20) NULL,
        "threat_score_at_ban" INT NULL,
        "hits" INT NOT NULL DEFAULT 1,
        "banned_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        "expires_at" TIMESTAMP WITH TIME ZONE NULL,
        "unblocked_at" TIMESTAMP WITH TIME ZONE NULL,
        "banned_by" VARCHAR(100) NOT NULL DEFAULT 'AIOps Sentinel',
        "unblocked_by" VARCHAR(100) NULL,
        "unblock_reason" TEXT NULL,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS "idx_aiops_account_quarantine_status" ON "aiops_account_quarantine"("status");
      CREATE INDEX IF NOT EXISTS "idx_aiops_account_quarantine_username" ON "aiops_account_quarantine"("username");
      CREATE INDEX IF NOT EXISTS "idx_aiops_account_quarantine_idaccount" ON "aiops_account_quarantine"("idaccount");
      CREATE INDEX IF NOT EXISTS "idx_aiops_account_quarantine_banned_at" ON "aiops_account_quarantine"("banned_at" DESC);

      CREATE TABLE IF NOT EXISTS "aiops_quarantine_incident_link" (
        "id" SERIAL PRIMARY KEY,
        "ip_quarantine_id" VARCHAR(64) NOT NULL REFERENCES "aiops_ip_quarantine"("id") ON DELETE CASCADE,
        "account_quarantine_id" VARCHAR(64) NOT NULL REFERENCES "aiops_account_quarantine"("id") ON DELETE CASCADE,
        "ip_hash" VARCHAR(64) NOT NULL,
        "username" VARCHAR(255) NOT NULL,
        "reason" TEXT NOT NULL,
        "incident_code" VARCHAR(50) NULL,
        "detected_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS "idx_quarantine_link_ip" ON "aiops_quarantine_incident_link"("ip_quarantine_id");
      CREATE INDEX IF NOT EXISTS "idx_quarantine_link_account" ON "aiops_quarantine_incident_link"("account_quarantine_id");
      CREATE INDEX IF NOT EXISTS "idx_quarantine_link_ip_hash" ON "aiops_quarantine_incident_link"("ip_hash");
      CREATE INDEX IF NOT EXISTS "idx_quarantine_link_username" ON "aiops_quarantine_incident_link"("username");
      CREATE INDEX IF NOT EXISTS "idx_quarantine_link_detected_at" ON "aiops_quarantine_incident_link"("detected_at" DESC);
    `;
    try {
      await this.pool.query(sql);
      // Tự động chuẩn hóa dữ liệu cũ đã lưu dạng placeholder/mockup
      await this.pool.query(`
        UPDATE "aiops_ip_quarantine"
        SET "masked_ip" = '192.168.xxx.xxx'
        WHERE "masked_ip" LIKE '%xx.xx%' OR "masked_ip" = 'traffic_cluster_ip';

        UPDATE "aiops_incident"
        SET "actor_identity" = '192.168.xxx.xxx'
        WHERE "actor_identity" LIKE '%địa chỉ IP%' OR "actor_identity" LIKE '%xx.xx%' OR "actor_identity" = 'traffic_cluster_ip';
      `).catch(() => {});
      logger.info('[AIOps Quarantine Repo] 3 bảng CSDL ma trận phong tỏa đã sẵn sàng trong PostgreSQL.');
      return true;
    } catch (err) {
      logger.warn('[AIOps Quarantine Repo] Khởi tạo bảng CSDL thất bại (dùng in-memory fallback)', { error: err.message });
      return false;
    }
  }

  /**
   * Lưu trữ hoặc cập nhật cặp (IP, Tài khoản) vi phạm vào cả 3 bảng
   */
  async recordQuarantinePair({
    ip = null,
    maskedIp = '192.168.xxx.xxx',
    ipHash,
    username = 'N/A',
    idaccount = null,
    reason = 'Phát hiện hành vi vi phạm an ninh',
    durationMs = 15 * 60 * 1000,
    banType = 'temporary',
    vector = null,
    threatScore = null,
    bannedBy = 'AIOps Sentinel',
    incidentCode = null,
  }) {
    let finalMaskedIp = maskedIp;
    if (!finalMaskedIp || finalMaskedIp === 'xx.xx.xx.xx' || finalMaskedIp === 'xx.xx.xxx.xxx' || finalMaskedIp === 'traffic_cluster_ip') {
      finalMaskedIp = '192.168.xxx.xxx';
    }

    const now = new Date();
    const isPermanent = banType === 'permanent';
    // CHÍNH SÁCH PO: IP LUÔN LUÔN là TEMPORARY (mặc định 4 tiếng)
    const ipStatus = 'TEMPORARY';
    const ipDuration = durationMs !== null ? durationMs : (4 * 60 * 60 * 1000);
    const ipExpiresAt = new Date(now.getTime() + ipDuration);

    // Account có thể là TEMPORARY hoặc PERMANENT
    const accountStatus = isPermanent ? 'PERMANENT' : 'TEMPORARY';
    const accountExpiresAt = isPermanent ? null : new Date(now.getTime() + ipDuration);

    const ipId = `ip_${ipHash}`;
    const cleanUsername = String(username || 'N/A').trim();
    const accId = `acc_${Buffer.from(cleanUsername).toString('hex').substring(0, 32)}`;

    const fallbackPayload = {
      ipId,
      ipHash,
      maskedIp: finalMaskedIp,
      ip,
      ipStatus,
      accountStatus,
      reason,
      vector,
      threatScore,
      now,
      ipExpiresAt,
      accountExpiresAt,
      bannedBy,
      accId,
      idaccount,
      cleanUsername,
      incidentCode,
    };

    // In-memory fallback
    if (!this.pool || typeof this.pool.query !== 'function') {
      this._saveToFallback(fallbackPayload);
      return {
        ipHash,
        username: cleanUsername,
        idaccount,
        maskedIp: finalMaskedIp,
        ipStatus: 'temporary',
        accountStatus: accountStatus.toLowerCase(),
        reason,
        expiresAt: ipExpiresAt ? ipExpiresAt.toISOString() : null,
      };
    }

    // Ghi vào CSDL PostgreSQL bằng Parameterized Queries an toàn
    try {
      // 1. Upsert aiops_ip_quarantine (Tuân thủ Check Constraint: luôn là TEMPORARY có expires_at)
      const ipSql = `
        INSERT INTO "aiops_ip_quarantine" (
          "id", "ip_hash", "masked_ip", "raw_ip", "status", "reason",
          "violation_vector", "threat_score_at_ban", "hits", "banned_at",
          "expires_at", "banned_by", "created_at", "updated_at"
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 1, $9, $10, $11, $9, $9)
        ON CONFLICT ("ip_hash") DO UPDATE SET
          "hits" = "aiops_ip_quarantine"."hits" + 1,
          "status" = EXCLUDED."status",
          "reason" = EXCLUDED."reason",
          "expires_at" = EXCLUDED."expires_at",
          "updated_at" = EXCLUDED."updated_at"
        RETURNING *;
      `;
      await this.pool.query(ipSql, [
        ipId,
        ipHash,
        finalMaskedIp,
        ip,
        ipStatus,
        reason,
        vector,
        threatScore,
        now,
        ipExpiresAt,
        bannedBy,
      ]);

      // 2. Upsert aiops_account_quarantine
      const accSql = `
        INSERT INTO "aiops_account_quarantine" (
          "id", "idaccount", "username", "status", "reason",
          "violation_vector", "threat_score_at_ban", "hits", "banned_at",
          "expires_at", "banned_by", "created_at", "updated_at"
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, 1, $8, $9, $10, $8, $8)
        ON CONFLICT ("id") DO UPDATE SET
          "hits" = "aiops_account_quarantine"."hits" + 1,
          "status" = EXCLUDED."status",
          "reason" = EXCLUDED."reason",
          "expires_at" = EXCLUDED."expires_at",
          "idaccount" = COALESCE(EXCLUDED."idaccount", "aiops_account_quarantine"."idaccount"),
          "updated_at" = EXCLUDED."updated_at"
        RETURNING *;
      `;
      await this.pool.query(accSql, [
        accId,
        idaccount ? Number(idaccount) : null,
        cleanUsername,
        accountStatus,
        reason,
        vector,
        threatScore,
        now,
        accountExpiresAt,
        bannedBy,
      ]);

      // 3. Insert Incident Link N-N
      const linkSql = `
        INSERT INTO "aiops_quarantine_incident_link" (
          "ip_quarantine_id", "account_quarantine_id", "ip_hash", "username", "reason", "incident_code", "detected_at"
        ) VALUES ($1, $2, $3, $4, $5, $6, $7);
      `;
      await this.pool.query(linkSql, [
        ipId,
        accId,
        ipHash,
        cleanUsername,
        reason,
        incidentCode,
        now,
      ]);

      // Đồng thời cập nhật vào memory fallback cache để tra cứu nhanh
      this._saveToFallback(fallbackPayload);

      return {
        ipHash,
        username: cleanUsername,
        idaccount,
        maskedIp: finalMaskedIp,
        ipStatus: 'temporary',
        accountStatus: accountStatus.toLowerCase(),
        reason,
        expiresAt: ipExpiresAt ? ipExpiresAt.toISOString() : null,
      };
    } catch (err) {
      logger.warn('[AIOps Quarantine Repo] Lỗi DB khi ghi nhận quarantine, chuyển sang fallback bộ nhớ', { error: err.message });
      // Tự động fallback vào bộ nhớ an toàn
      this._saveToFallback(fallbackPayload);

      return {
        ipHash,
        username: cleanUsername,
        idaccount,
        maskedIp: finalMaskedIp,
        ipStatus: 'temporary',
        accountStatus: accountStatus.toLowerCase(),
        reason,
        expiresAt: ipExpiresAt ? ipExpiresAt.toISOString() : null,
      };
    }
  }

  /**
   * Lưu trữ nội bộ an toàn vào Fallback Cache
   */
  _saveToFallback({
    ipId,
    ipHash,
    maskedIp,
    ip,
    ipStatus = 'TEMPORARY',
    accountStatus = 'TEMPORARY',
    reason,
    vector,
    threatScore,
    now,
    ipExpiresAt,
    accountExpiresAt,
    bannedBy,
    accId,
    idaccount,
    cleanUsername,
    incidentCode,
  }) {
    let ipRec = this._fallbackIps.get(ipHash);
    if (ipRec) {
      ipRec.hits += 1;
      ipRec.reason = reason;
      ipRec.status = ipStatus;
      ipRec.expires_at = ipExpiresAt;
      ipRec.updated_at = now;
    } else {
      this._fallbackIps.set(ipHash, {
        id: ipId,
        ip_hash: ipHash,
        masked_ip: maskedIp,
        raw_ip: ip,
        status: ipStatus,
        reason,
        violation_vector: vector,
        threat_score_at_ban: threatScore,
        hits: 1,
        banned_at: now,
        expires_at: ipExpiresAt,
        unblocked_at: null,
        banned_by: bannedBy,
        unblocked_by: null,
        unblock_reason: null,
        created_at: now,
        updated_at: now,
      });
    }

    const accKey = cleanUsername.toLowerCase();
    let accRec = this._fallbackAccounts.get(accKey);
    if (accRec) {
      accRec.hits += 1;
      accRec.reason = reason;
      accRec.status = accountStatus;
      accRec.expires_at = accountExpiresAt;
      if (idaccount && !accRec.idaccount) accRec.idaccount = Number(idaccount);
      accRec.updated_at = now;
    } else {
      this._fallbackAccounts.set(accKey, {
        id: accId,
        idaccount: idaccount ? Number(idaccount) : null,
        username: cleanUsername,
        status: accountStatus,
        reason,
        violation_vector: vector,
        threat_score_at_ban: threatScore,
        hits: 1,
        banned_at: now,
        expires_at: accountExpiresAt,
        unblocked_at: null,
        banned_by: bannedBy,
        unblocked_by: null,
        unblock_reason: null,
        created_at: now,
        updated_at: now,
      });
    }

    this._fallbackLinks.push({
      id: this._fallbackLinks.length + 1,
      ip_quarantine_id: ipId,
      account_quarantine_id: accId,
      ip_hash: ipHash,
      username: cleanUsername,
      reason,
      incident_code: incidentCode,
      detected_at: now,
    });
  }

  /**
   * Tải toàn bộ các IP và Tài khoản đang có hiệu lực phong tỏa để nạp vào RAM
   */
  /**
   * Tự động quét và giải phóng các bản ghi TEMPORARY đã hết hạn trong CSDL
   * Đồng bộ status -> UNLOCKED và expires_at -> NULL
   */
  async autoExpireInDatabase() {
    const now = new Date();

    if (!this.pool || typeof this.pool.query !== 'function') {
      const expiredAccounts = [];
      const expiredIps = [];
      for (const rec of this._fallbackIps.values()) {
        if (rec.status === 'TEMPORARY' && rec.expires_at && new Date(rec.expires_at) <= now) {
          rec.status = 'UNLOCKED';
          rec.expires_at = null;
          rec.unblocked_at = now;
          rec.unblocked_by = 'AIOps Auto-Expire';
          expiredIps.push(rec);
        }
      }
      for (const rec of this._fallbackAccounts.values()) {
        if (rec.status === 'TEMPORARY' && rec.expires_at && new Date(rec.expires_at) <= now) {
          rec.status = 'UNLOCKED';
          rec.expires_at = null;
          rec.unblocked_at = now;
          rec.unblocked_by = 'AIOps Auto-Expire';
          expiredAccounts.push(rec);
        }
      }
      return { expiredIps, expiredAccounts };
    }

    try {
      const ipSql = `
        UPDATE "aiops_ip_quarantine"
        SET "status" = 'UNLOCKED', "expires_at" = NULL, "unblocked_at" = $1, "unblocked_by" = 'AIOps Auto-Expire', "updated_at" = $1
        WHERE "status" = 'TEMPORARY' AND "expires_at" IS NOT NULL AND "expires_at" <= $1
        RETURNING "ip_hash", "masked_ip";
      `;
      const accSql = `
        UPDATE "aiops_account_quarantine"
        SET "status" = 'UNLOCKED', "expires_at" = NULL, "unblocked_at" = $1, "unblocked_by" = 'AIOps Auto-Expire', "updated_at" = $1
        WHERE "status" = 'TEMPORARY' AND "expires_at" IS NOT NULL AND "expires_at" <= $1
        RETURNING "username", "idaccount";
      `;

      const [ipRes, accRes] = await Promise.all([
        this.pool.query(ipSql, [now]),
        this.pool.query(accSql, [now]),
      ]);

      const expiredIps = ipRes.rows || [];
      const expiredAccounts = accRes.rows || [];

      if (expiredIps.length > 0 || expiredAccounts.length > 0) {
        logger.info(`[AIOps Quarantine Repo] Đã tự động giải phóng CSDL cho ${expiredIps.length} IP và ${expiredAccounts.length} Tài khoản hết hạn tạm khóa.`);
      }

      return { expiredIps, expiredAccounts };
    } catch (err) {
      logger.error('[AIOps Quarantine Repo] Lỗi autoExpireInDatabase', { error: err.message });
      return { expiredIps: [], expiredAccounts: [] };
    }
  }

  /**
   * Tải toàn bộ trạng thái phong tỏa của IP, Tài khoản và các liên kết vi phạm từ CSDL
   */
  async loadActiveQuarantines() {
    const now = new Date();

    // 1. Dọn dẹp các bản ghi đã quá hạn trước khi nạp
    await this.autoExpireInDatabase();

    if (!this.pool || typeof this.pool.query !== 'function') {
      return {
        ips: Array.from(this._fallbackIps.values()),
        accounts: Array.from(this._fallbackAccounts.values()),
        links: this._fallbackLinks,
      };
    }

    try {
      const ipSql = `SELECT * FROM "aiops_ip_quarantine" ORDER BY "updated_at" DESC;`;
      const accSql = `SELECT * FROM "aiops_account_quarantine" ORDER BY "updated_at" DESC;`;
      const linkSql = `
        SELECT * FROM "aiops_quarantine_incident_link"
        ORDER BY "detected_at" DESC
        LIMIT 500;
      `;

      const [ipRes, accRes, linkRes] = await Promise.all([
        this.pool.query(ipSql),
        this.pool.query(accSql),
        this.pool.query(linkSql),
      ]);

      const rawIps = ipRes.rows || [];
      const sanitizedIps = rawIps.map((r) => {
        if (!r.masked_ip || r.masked_ip === 'xx.xx.xx.xx' || r.masked_ip === 'xx.xx.xxx.xxx' || r.masked_ip === 'traffic_cluster_ip') {
          return { ...r, masked_ip: '192.168.xxx.xxx' };
        }
        return r;
      });

      return {
        ips: sanitizedIps,
        accounts: accRes.rows || [],
        links: linkRes.rows || [],
      };
    } catch (err) {
      logger.error('[AIOps Quarantine Repo] Lỗi nạp active quarantines từ DB', { error: err.message });
      return { ips: [], accounts: [], links: [] };
    }
  }

  /**
   * Cập nhật trạng thái IP (Mở khóa hoặc Tạm khóa 4 giờ)
   * CHÍNH SÁCH PO: Tuyệt đối không lưu status = 'PERMANENT' cho IP, tự động chuyển thành 'TEMPORARY' 4 giờ
   */
  async updateIpStatus({ ipHash, status, unblockedBy = null, unblockReason = null, expiresAt = null, bannedBy = null }) {
    const now = new Date();
    const isUnblocked = status === 'UNLOCKED';
    // CHÍNH SÁCH AN NINH PO: Ép toàn bộ yêu cầu PERMANENT về TEMPORARY
    const safeStatus = isUnblocked ? 'UNLOCKED' : 'TEMPORARY';
    const safeExpiresAt = isUnblocked 
      ? null 
      : (expiresAt || new Date(now.getTime() + 4 * 60 * 60 * 1000));

    if (!this.pool || typeof this.pool.query !== 'function') {
      const rec = this._fallbackIps.get(ipHash);
      if (!rec) return 0;
      rec.status = safeStatus;
      rec.updated_at = now;
      if (isUnblocked) {
        rec.unblocked_at = now;
        rec.unblocked_by = unblockedBy;
        rec.unblock_reason = unblockReason;
        rec.expires_at = null;
      } else {
        rec.expires_at = safeExpiresAt;
        if (bannedBy) rec.banned_by = bannedBy;
      }
      return 1;
    }

    try {
      const sql = `
        UPDATE "aiops_ip_quarantine"
        SET
          "status" = $1::varchar,
          "unblocked_at" = CASE WHEN $1::varchar = 'UNLOCKED' THEN $2::timestamptz ELSE "unblocked_at" END,
          "unblocked_by" = CASE WHEN $1::varchar = 'UNLOCKED' THEN $3::varchar ELSE "unblocked_by" END,
          "unblock_reason" = CASE WHEN $1::varchar = 'UNLOCKED' THEN $4::text ELSE "unblock_reason" END,
          "expires_at" = CASE 
            WHEN $1::varchar = 'UNLOCKED' THEN NULL 
            WHEN $6::timestamptz IS NOT NULL THEN $6::timestamptz 
            ELSE COALESCE("expires_at", $2::timestamptz + INTERVAL '4 hours')
          END,
          "banned_by" = CASE WHEN $7::varchar IS NOT NULL THEN $7::varchar ELSE "banned_by" END,
          "updated_at" = $2::timestamptz
        WHERE "ip_hash" = $5 OR "id" = $5;
      `;
      const res = await this.pool.query(sql, [safeStatus, now, unblockedBy, unblockReason, ipHash, safeExpiresAt, bannedBy]);
      const updatedCount = res.rowCount || 0;
      if (updatedCount === 0) {
        const rec = this._fallbackIps.get(ipHash);
        if (rec) {
          rec.status = safeStatus;
          rec.updated_at = now;
          if (isUnblocked) {
            rec.unblocked_at = now;
            rec.unblocked_by = unblockedBy;
            rec.unblock_reason = unblockReason;
            rec.expires_at = null;
          } else {
            rec.expires_at = safeExpiresAt;
            if (bannedBy) rec.banned_by = bannedBy;
          }
          return 1;
        }
      }
      return updatedCount;
    } catch (err) {
      logger.warn('[AIOps Quarantine Repo] Lỗi DB khi cập nhật trạng thái IP, fallback sang bộ nhớ', { error: err.message });
      const rec = this._fallbackIps.get(ipHash);
      if (rec) {
        rec.status = status;
        rec.updated_at = now;
        if (isUnblocked) {
          rec.unblocked_at = now;
          rec.unblocked_by = unblockedBy;
          rec.unblock_reason = unblockReason;
          rec.expires_at = null;
        } else if (isPermanent) {
          rec.expires_at = null;
          if (bannedBy) rec.banned_by = bannedBy;
        } else if (status === 'TEMPORARY') {
          if (expiresAt) rec.expires_at = expiresAt;
          if (bannedBy) rec.banned_by = bannedBy;
        }
        return 1;
      }
      return 0;
    }
  }

  /**
   * Cập nhật trạng thái Tài khoản (Mở khóa hoặc Khóa vĩnh viễn hoặc Tạm khóa)
   */
  async updateAccountStatus({ username, idaccount = null, status, unblockedBy = null, unblockReason = null, bannedBy = null, expiresAt = null }) {
    const now = new Date();
    const isUnblocked = status === 'UNLOCKED';
    const isPermanent = status === 'PERMANENT';
    const cleanUser = String(username || '').trim().toLowerCase();

    if (!this.pool || typeof this.pool.query !== 'function') {
      let count = 0;
      for (const [key, rec] of this._fallbackAccounts.entries()) {
        if (key === cleanUser || (idaccount && rec.idaccount === Number(idaccount))) {
          rec.status = status;
          rec.updated_at = now;
          if (isUnblocked) {
            rec.unblocked_at = now;
            rec.unblocked_by = unblockedBy;
            rec.unblock_reason = unblockReason;
            rec.expires_at = null;
          } else if (isPermanent) {
            rec.expires_at = null;
            if (bannedBy) rec.banned_by = bannedBy;
          } else if (status === 'TEMPORARY') {
            if (expiresAt) rec.expires_at = expiresAt;
            if (bannedBy) rec.banned_by = bannedBy;
          }
          count += 1;
        }
      }
      return count;
    }

    try {
      const sql = `
        UPDATE "aiops_account_quarantine"
        SET
          "status" = $1::varchar,
          "unblocked_at" = CASE WHEN $1::varchar = 'UNLOCKED' THEN $2::timestamptz ELSE "unblocked_at" END,
          "unblocked_by" = CASE WHEN $1::varchar = 'UNLOCKED' THEN $3::varchar ELSE "unblocked_by" END,
          "unblock_reason" = CASE WHEN $1::varchar = 'UNLOCKED' THEN $4::text ELSE "unblock_reason" END,
          "expires_at" = CASE 
            WHEN $1::varchar IN ('UNLOCKED', 'PERMANENT') THEN NULL 
            WHEN $8::timestamptz IS NOT NULL THEN $8::timestamptz 
            ELSE "expires_at" 
          END,
          "banned_by" = CASE WHEN $5::varchar IS NOT NULL THEN $5::varchar ELSE "banned_by" END,
          "updated_at" = $2::timestamptz
        WHERE LOWER("username") = LOWER($6) OR ("idaccount" IS NOT NULL AND "idaccount" = $7);
      `;
      const res = await this.pool.query(sql, [
        status,
        now,
        unblockedBy,
        unblockReason,
        bannedBy,
        cleanUser,
        idaccount ? Number(idaccount) : null,
        expiresAt,
      ]);
      const updatedCount = res.rowCount || 0;
      if (updatedCount === 0) {
        let count = 0;
        for (const [key, rec] of this._fallbackAccounts.entries()) {
          if (key === cleanUser || (idaccount && rec.idaccount === Number(idaccount))) {
            rec.status = status;
            rec.updated_at = now;
            if (isUnblocked) {
              rec.unblocked_at = now;
              rec.unblocked_by = unblockedBy;
              rec.unblock_reason = unblockReason;
              rec.expires_at = null;
            } else if (isPermanent) {
              rec.expires_at = null;
              if (bannedBy) rec.banned_by = bannedBy;
            } else if (status === 'TEMPORARY') {
              if (expiresAt) rec.expires_at = expiresAt;
              if (bannedBy) rec.banned_by = bannedBy;
            }
            count += 1;
          }
        }
        return count;
      }
      return updatedCount;
    } catch (err) {
      logger.warn('[AIOps Quarantine Repo] Lỗi DB khi cập nhật trạng thái Tài khoản, fallback sang bộ nhớ', { error: err.message });
      let count = 0;
      for (const [key, rec] of this._fallbackAccounts.entries()) {
        if (key === cleanUser || (idaccount && rec.idaccount === Number(idaccount))) {
          rec.status = status;
          rec.updated_at = now;
          if (isUnblocked) {
            rec.unblocked_at = now;
            rec.unblocked_by = unblockedBy;
            rec.unblock_reason = unblockReason;
            rec.expires_at = null;
          } else if (isPermanent) {
            rec.expires_at = null;
            if (bannedBy) rec.banned_by = bannedBy;
          } else if (status === 'TEMPORARY') {
            if (expiresAt) rec.expires_at = expiresAt;
            if (bannedBy) rec.banned_by = bannedBy;
          }
          count += 1;
        }
      }
      return count;
    }
  }

  /**
   * Truy vết dữ liệu điều tra an ninh (Forensics Query N-N)
   */
  async getForensicInvestigationLogs({ ipHash = null, username = null, page = 1, limit = 50 } = {}) {
    const p = Math.max(1, parseInt(page, 10) || 1);
    const l = Math.min(100, Math.max(1, parseInt(limit, 10) || 50));
    const offset = (p - 1) * l;

    if (!this.pool || typeof this.pool.query !== 'function') {
      let filtered = [...this._fallbackLinks];
      if (ipHash) filtered = filtered.filter((x) => x.ip_hash === ipHash);
      if (username) filtered = filtered.filter((x) => x.username.toLowerCase() === username.toLowerCase());

      const total = filtered.length;
      const paginated = filtered.slice(offset, offset + l);
      return { total, page: p, limit: l, incidents: paginated };
    }

    try {
      const conditions = [];
      const params = [];
      let idx = 1;

      if (ipHash) {
        conditions.push(`"ip_hash" = $${idx++}`);
        params.push(ipHash);
      }
      if (username) {
        conditions.push(`LOWER("username") = LOWER($${idx++})`);
        params.push(username);
      }

      const whereClause = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
      const countSql = `SELECT COUNT(*) AS total FROM "aiops_quarantine_incident_link" ${whereClause};`;
      const countRes = await this.pool.query(countSql, params);
      const total = parseInt(countRes.rows[0]?.total || 0, 10);

      const dataSql = `
        SELECT * FROM "aiops_quarantine_incident_link"
        ${whereClause}
        ORDER BY "detected_at" DESC
        LIMIT $${idx++} OFFSET $${idx++};
      `;
      const dataRes = await this.pool.query(dataSql, [...params, l, offset]);

      return {
        total,
        page: p,
        limit: l,
        incidents: dataRes.rows || [],
      };
    } catch (err) {
      logger.warn('[AIOps Quarantine Repo] Lỗi truy vấn điều tra an ninh từ DB, fallback sang bộ nhớ', { error: err.message });
      let filtered = [...this._fallbackLinks];
      if (ipHash) filtered = filtered.filter((x) => x.ip_hash === ipHash);
      if (username) filtered = filtered.filter((x) => x.username.toLowerCase() === String(username || '').toLowerCase());

      const total = filtered.length;
      const paginated = filtered.slice(offset, offset + l);
      return { total, page: p, limit: l, incidents: paginated };
    }
  }

  // --- Helper Methods Cho Unit Testing & Internal Access ---
  async getIpByHash(ipHash) {
    if (!this.pool || typeof this.pool.query !== 'function') {
      return this._fallbackIps.get(ipHash) || null;
    }
    try {
      const res = await this.pool.query(`SELECT * FROM "aiops_ip_quarantine" WHERE "ip_hash" = $1 LIMIT 1;`, [ipHash]);
      return res.rows[0] || this._fallbackIps.get(ipHash) || null;
    } catch (_) {
      return this._fallbackIps.get(ipHash) || null;
    }
  }

  async getAccountByUsername(username) {
    if (!this.pool || typeof this.pool.query !== 'function') {
      return this._fallbackAccounts.get(String(username).toLowerCase()) || null;
    }
    try {
      const res = await this.pool.query(`SELECT * FROM "aiops_account_quarantine" WHERE LOWER("username") = LOWER($1) LIMIT 1;`, [username]);
      return res.rows[0] || this._fallbackAccounts.get(String(username).toLowerCase()) || null;
    } catch (_) {
      return this._fallbackAccounts.get(String(username).toLowerCase()) || null;
    }
  }

  async getLinksByIpHash(ipHash) {
    if (!this.pool || typeof this.pool.query !== 'function') {
      return this._fallbackLinks.filter((x) => x.ip_hash === ipHash);
    }
    try {
      const res = await this.pool.query(`SELECT * FROM "aiops_quarantine_incident_link" WHERE "ip_hash" = $1 ORDER BY "detected_at" DESC;`, [ipHash]);
      return res.rows?.length ? res.rows : this._fallbackLinks.filter((x) => x.ip_hash === ipHash);
    } catch (_) {
      return this._fallbackLinks.filter((x) => x.ip_hash === ipHash);
    }
  }
}

const defaultAIOpsQuarantineRepository = new AIOpsQuarantineRepository();

module.exports = {
  AIOpsQuarantineRepository,
  defaultAIOpsQuarantineRepository,
};
