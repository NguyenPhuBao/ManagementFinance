const crypto = require('crypto');
const logger = require('../../core/logger');

/**
 * Che bớt thông tin IP để tuân thủ Data_Security.md & Nghị định 13/2023/NĐ-CP
 */
function maskIp(rawIp) {
  if (!rawIp) return 'xx.xx.xx.xx';
  const clean = rawIp.replace(/^::ffff:/, '').trim();
  const v4Parts = clean.split('.');
  if (v4Parts.length === 4) {
    return `${v4Parts[0]}.${v4Parts[1]}.xx.xx`;
  }
  const v6Parts = clean.split(':');
  if (v6Parts.length > 2) {
    return `${v6Parts[0]}:${v6Parts[1]}:xxxx:xxxx`;
  }
  return 'xx.xx.xx.xx';
}

function hashIp(rawIp, salt = 'aiops-quarantine-salt') {
  if (!rawIp) return '0000000000000000';
  const clean = rawIp.replace(/^::ffff:/, '').trim();
  return crypto.createHash('sha256').update(`${salt}:${clean}`).digest('hex').substring(0, 16);
}

function normalizeIp(rawIp) {
  if (!rawIp) return '';
  return rawIp.split(',')[0].replace(/^::ffff:/, '').trim();
}

/**
 * AIOps Quarantine & Active Auto-Blocking Shield
 * Quản lý danh sách IP bị cô lập trong bộ nhớ In-Memory, tự động ngắt kết nối HTTP 403
 * và phát sự kiện cảnh báo thời gian thực lên Admin-web qua Socket.io.
 */
class AIOpsQuarantine {
  constructor(options = {}) {
    this.defaultDurationMs = options.defaultDurationMs || 15 * 60 * 1000; // 15 phút
    this.io = options.io || null;
    this._map = new Map(); // key: normalizedIp -> record
    this._byHash = new Map(); // key: hash -> record (cho phép phong tỏa theo SHA-256 Actor Hash từ RCA)
  }

  getIO() {
    if (this.io) return this.io;
    try {
      const { getIO } = require('../../core/socket');
      if (typeof getIO === 'function') {
        return getIO();
      }
    } catch (_) {}
    return null;
  }

  /**
   * Đưa 1 địa chỉ IP vào danh sách cô lập và phát sự kiện Socket.io
   */
  quarantine(rawIp, reason = 'Phát hiện hành vi bất thường', durationMs = null) {
    const ip = normalizeIp(rawIp);
    if (!ip) return null;

    // Trong môi trường development, không cô lập IP loopback để bảo vệ dàn máy test adb reverse
    if (process.env.NODE_ENV === 'development' && (ip === '127.0.0.1' || ip === '::1' || ip === 'localhost')) {
      logger.info(`[AIOps Quarantine] Bỏ qua cô lập IP loopback ${ip} trong môi trường development`);
      return null;
    }

    const duration = durationMs !== null ? durationMs : this.defaultDurationMs;
    const now = Date.now();
    const expiresAt = now + duration;
    const ipHash = hashIp(ip);
    const masked = maskIp(ip);

    let record = this._map.get(ip) || this._byHash.get(ipHash);
    if (record) {
      record.hits += 1;
      record.expiresAt = Math.max(record.expiresAt, expiresAt);
      record.reason = reason;
    } else {
      record = {
        ip,
        maskedIp: masked,
        hash: ipHash,
        reason,
        bannedAt: new Date(now).toISOString(),
        expiresAt,
        hits: 1,
      };
      this._map.set(ip, record);
      this._byHash.set(ipHash, record);
    }

    logger.warn(`[AIOps Quarantine] Chặn đứng nguồn IP ${masked}`, {
      reason,
      hits: record.hits,
      expiresAt: new Date(record.expiresAt).toISOString(),
    });

    // Phát sự kiện Socket.io thời gian thực tới Admin
    const io = this.getIO();
    if (io) {
      try {
        io.to('admin_room').emit('admin.security_blocked', {
          hash: record.hash,
          maskedIp: record.maskedIp,
          reason: record.reason,
          bannedAt: record.bannedAt,
          expiresAt: new Date(record.expiresAt).toISOString(),
          hits: record.hits,
        });
      } catch (err) {
        logger.error('[AIOps Quarantine] Lỗi phát socket admin.security_blocked', { error: err.message });
      }
    }

    return record;
  }

  /**
   * Admin chủ động phong tỏa đối tượng khả nghi từ bảng Root Cause Analysis (RCA)
   * Hỗ trợ phong tỏa qua rawIp, hoặc qua ipHash + maskedIp tuân thủ Data_Security.md
   */
  quarantineActor({ rawIp = null, ipHash = null, maskedIp = null, reason = 'Admin chủ động phong tỏa từ nhật ký RCA', durationMs = null } = {}) {
    if (rawIp && !rawIp.includes('xx')) {
      return this.quarantine(rawIp, reason, durationMs);
    }

    const hash = ipHash || (rawIp ? hashIp(rawIp) : null);
    if (!hash) return null;

    const duration = durationMs !== null ? durationMs : this.defaultDurationMs;
    const now = Date.now();
    const expiresAt = now + duration;
    const masked = maskedIp || (rawIp ? maskIp(rawIp) : 'xx.xx.xx.xx');

    let record = this._byHash.get(hash);
    if (record) {
      record.hits += 1;
      record.expiresAt = Math.max(record.expiresAt, expiresAt);
      record.reason = reason;
      if (masked && masked !== 'xx.xx.xx.xx') record.maskedIp = masked;
    } else {
      record = {
        ip: null,
        maskedIp: masked,
        hash,
        reason,
        bannedAt: new Date(now).toISOString(),
        expiresAt,
        hits: 1,
      };
      this._byHash.set(hash, record);
    }

    logger.warn(`[AIOps Quarantine] Admin đã chủ động phong tỏa nguồn ${masked} (Hash: #${hash.slice(0, 8)})`, {
      reason,
      hits: record.hits,
      expiresAt: new Date(record.expiresAt).toISOString(),
    });

    const io = this.getIO();
    if (io) {
      try {
        io.to('admin_room').emit('admin.security_blocked', {
          hash: record.hash,
          maskedIp: record.maskedIp,
          reason: record.reason,
          bannedAt: record.bannedAt,
          expiresAt: new Date(record.expiresAt).toISOString(),
          hits: record.hits,
        });
      } catch (err) {
        logger.error('[AIOps Quarantine] Lỗi phát socket admin.security_blocked', { error: err.message });
      }
    }

    return record;
  }

  /**
   * Kiểm tra nhanh xem IP có đang bị cô lập hay không ($O(1)$)
   */
  isQuarantined(rawIp) {
    const ip = normalizeIp(rawIp);
    if (!ip) return { quarantined: false };

    // Miễn trừ loopback khi dev để tránh ảnh hưởng đến các thiết bị test qua adb reverse
    if (process.env.NODE_ENV === 'development' && (ip === '127.0.0.1' || ip === '::1' || ip === 'localhost')) {
      return { quarantined: false };
    }

    const clientHash = hashIp(ip);
    let record = this._map.get(ip) || this._byHash.get(clientHash);
    if (!record) return { quarantined: false };

    if (Date.now() > record.expiresAt) {
      this._map.delete(ip);
      this._byHash.delete(clientHash);
      return { quarantined: false };
    }

    return {
      quarantined: true,
      reason: record.reason,
      expiresAt: record.expiresAt,
      hits: record.hits,
      maskedIp: record.maskedIp,
    };
  }

  /**
   * Admin mở khóa / gỡ chặn IP thủ công qua token hash hoặc IP
   */
  unblock(ipHashOrIp) {
    if (!ipHashOrIp) return false;

    let unblocked = false;
    // Kiểm tra và xóa trong _byHash
    if (this._byHash.has(ipHashOrIp)) {
      const rec = this._byHash.get(ipHashOrIp);
      this._byHash.delete(ipHashOrIp);
      if (rec.ip) this._map.delete(rec.ip);
      logger.info(`[AIOps Quarantine] Đã gỡ chặn IP ${rec.maskedIp} (Hash: ${rec.hash}) qua hash`);
      unblocked = true;
    }

    // Kiểm tra và xóa trong _map
    for (const [ip, record] of this._map.entries()) {
      if (record.hash === ipHashOrIp || ip === ipHashOrIp) {
        this._map.delete(ip);
        if (record.hash) this._byHash.delete(record.hash);
        logger.info(`[AIOps Quarantine] Đã gỡ chặn IP ${record.maskedIp} (Hash: ${record.hash}) qua IP`);
        unblocked = true;
      }
    }
    return unblocked;
  }

  /**
   * Giải phóng phong tỏa nhanh chóng cho 1 địa chỉ IP
   */
  unquarantine(rawIp) {
    const ip = normalizeIp(rawIp);
    if (!ip) return false;
    return this.unblock(ip);
  }

  /**
   * Lấy danh sách các IP đang bị cô lập (đã mask IP)
   */
  getQuarantinedList() {
    const now = Date.now();
    const listMap = new Map();

    // Duyệt qua _map
    for (const [ip, record] of this._map.entries()) {
      if (now > record.expiresAt) {
        this._map.delete(ip);
        if (record.hash) this._byHash.delete(record.hash);
      } else {
        listMap.set(record.hash, {
          hash: record.hash,
          maskedIp: record.maskedIp,
          reason: record.reason,
          bannedAt: record.bannedAt,
          expiresAt: new Date(record.expiresAt).toISOString(),
          remainingMinutes: Math.max(0, Math.ceil((record.expiresAt - now) / 60000)),
          hits: record.hits,
        });
      }
    }

    // Duyệt qua _byHash (bổ sung các bản ghi phong tỏa theo hash)
    for (const [hash, record] of this._byHash.entries()) {
      if (now > record.expiresAt) {
        this._byHash.delete(hash);
        if (record.ip) this._map.delete(record.ip);
      } else if (!listMap.has(hash)) {
        listMap.set(hash, {
          hash: record.hash,
          maskedIp: record.maskedIp,
          reason: record.reason,
          bannedAt: record.bannedAt,
          expiresAt: new Date(record.expiresAt).toISOString(),
          remainingMinutes: Math.max(0, Math.ceil((record.expiresAt - now) / 60000)),
          hits: record.hits,
        });
      }
    }

    const list = Array.from(listMap.values());
    return list.sort((a, b) => new Date(b.bannedAt) - new Date(a.bannedAt));
  }

  /**
   * Express Middleware chặn đứng request từ IP bị cô lập với mã HTTP 403
   */
  createMiddleware() {
    return (req, res, next) => {
      // Fast-lane: Miễn trừ cho request đã được SERVER XÁC THỰC là Admin thật (Token hợp lệ, Khóa khẩn cấp)
      if (req.isAdmin || (req.originalUrl && req.originalUrl.startsWith('/api/admin'))) {
        return next();
      }

      // Đọc IP an toàn tuân thủ app.set('trust proxy', 1)
      const clientIp = req.ip || req.socket?.remoteAddress;
      const check = this.isQuarantined(clientIp);

      if (check.quarantined) {
        return res.status(403).json({
          success: false,
          code: 'AIOPS_QUARANTINED',
          error: 'AIOPS_QUARANTINED',
          message: 'Kết nối từ thiết bị của bạn tạm thời bị phong tỏa do hệ thống phát hiện hành vi bất thường hoặc dấu hiệu tấn công an ninh.',
          reason: check.reason,
          quarantineExpiresAt: new Date(check.expiresAt).toISOString(),
          timestamp: new Date().toISOString(),
        });
      }

      next();
    };
  }
}

const defaultAIOpsQuarantine = new AIOpsQuarantine();

module.exports = {
  AIOpsQuarantine,
  defaultAIOpsQuarantine,
  maskIp,
  hashIp,
};
