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

function getStaticProtectedIps() {
  const defaults = ['127.0.0.1', '::1', 'localhost', '0.0.0.0'];
  const envIps = (process.env.ADMIN_TRUSTED_IPS || '')
    .split(',')
    .map((ip) => normalizeIp(ip.trim()))
    .filter(Boolean);
  return new Set([...defaults, ...envIps]);
}

const PROTECTED_ACTOR_HASHES = new Set([
  hashIp('127.0.0.1'),
  hashIp('::1'),
  hashIp('localhost'),
  hashIp('0.0.0.0'),
  'system_core',
  'system_host',
]);

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
    this._activeAdminSessions = new Map(); // key: normalizedIp -> { userId, username, expiresAt, registeredAt }
  }

  /**
   * Đăng ký bảo vệ động cho địa chỉ IP của Quản trị viên khi đăng nhập
   * (Dynamic Admin Session Protection)
   */
  registerAdminSession(rawIp, { userId = null, username = null, ttlMs = 24 * 60 * 60 * 1000 } = {}) {
    const ip = normalizeIp(rawIp);
    if (!ip) return false;

    const expiresAt = Date.now() + (ttlMs || 24 * 60 * 60 * 1000);
    this._activeAdminSessions.set(ip, {
      userId,
      username,
      expiresAt,
      registeredAt: Date.now(),
    });

    // Nếu IP này từng bị phong tỏa trước đó, tự động gỡ phong tỏa ngay
    this.unquarantine(ip);

    logger.info(`[AIOps Quarantine] Đăng ký bảo vệ IP Admin động cho [${username || 'Admin'}] tại IP ${maskIp(ip)} (hết hạn sau ${Math.round((ttlMs || 86400000) / 60000)}p)`);
    return true;
  }

  /**
   * Hủy đăng ký bảo vệ động khi Quản trị viên đăng xuất (Logout)
   */
  unregisterAdminSession(rawIp) {
    const ip = normalizeIp(rawIp);
    if (!ip) return false;
    const deleted = this._activeAdminSessions.delete(ip);
    if (deleted) {
      logger.info(`[AIOps Quarantine] Đã giải phóng bảo vệ IP Admin động tại IP ${maskIp(ip)}`);
    }
    return deleted;
  }

  /**
   * Lấy danh sách toàn bộ các IP Admin đang hoạt động còn hiệu lực
   */
  getActiveAdminIps() {
    const now = Date.now();
    const active = [];
    for (const [ip, session] of this._activeAdminSessions.entries()) {
      if (session && session.expiresAt > now) {
        active.push({ ip, ...session });
      } else {
        this._activeAdminSessions.delete(ip);
      }
    }
    return active;
  }

  /**
   * Kiểm tra xem địa chỉ IP hoặc Actor Hash có thuộc vùng an toàn bất khả xâm phạm
   * (Cấu hình .env, Phiên Admin động, Loopback, hoặc Hạ tầng Máy chủ Nội bộ) hay không.
   */
  isProtectedIp(rawIpOrHash) {
    if (!rawIpOrHash) return false;
    const str = String(rawIpOrHash).trim();
    const clean = normalizeIp(str);

    // 1. Kiểm tra IP tĩnh từ cấu hình .env (kèm fallback loopback)
    const staticIps = getStaticProtectedIps();
    if (staticIps.has(clean) || staticIps.has(str)) return true;
    if (str.includes('127.0.0.1') || str.includes('::1') || str.includes('localhost') || str.includes('Internal')) return true;

    // 2. Kiểm tra Actor Hash tĩnh của các IP tĩnh & hệ thống
    for (const sip of staticIps) {
      if (str === hashIp(sip) || clean === hashIp(sip)) return true;
    }
    if (PROTECTED_ACTOR_HASHES.has(str) || PROTECTED_ACTOR_HASHES.has(clean)) return true;

    // 3. Kiểm tra IP động theo phiên hoạt động của Admin
    if (clean && this._activeAdminSessions.has(clean)) {
      const session = this._activeAdminSessions.get(clean);
      if (session && session.expiresAt > Date.now()) {
        return true;
      }
      this._activeAdminSessions.delete(clean);
    }

    // 4. Kiểm tra Actor Hash của các IP Admin động
    for (const [adminIp, session] of this._activeAdminSessions.entries()) {
      if (session && session.expiresAt > Date.now()) {
        const h = hashIp(adminIp);
        if (str === h || clean === h) return true;
      }
    }

    return false;
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

    // Khóa Chống Tự Phong Tỏa (Localhost & Loopback Shield Protection):
    // Tuyệt đối không bao giờ cô lập IP loopback/máy chủ trong mọi môi trường (kể cả dev lẫn prod)
    if (this.isProtectedIp(ip)) {
      logger.warn(`[AIOps Quarantine] Từ chối cô lập IP nội bộ/được bảo vệ: ${ip} (Lá chắn Localhost Shield)`);
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
    if (rawIp && this.isProtectedIp(rawIp)) {
      logger.warn(`[AIOps Quarantine] Từ chối cô lập rawIp nội bộ/được bảo vệ: ${rawIp} (Localhost Shield)`);
      return null;
    }
    if (ipHash && this.isProtectedIp(ipHash)) {
      logger.warn(`[AIOps Quarantine] Từ chối cô lập ipHash nội bộ/được bảo vệ: ${ipHash} (Localhost Shield)`);
      return null;
    }
    if (maskedIp && this.isProtectedIp(maskedIp)) {
      logger.warn(`[AIOps Quarantine] Từ chối cô lập maskedIp nội bộ/được bảo vệ: ${maskedIp} (Localhost Shield)`);
      return null;
    }

    if (rawIp && !rawIp.includes('xx')) {
      return this.quarantine(rawIp, reason, durationMs);
    }

    const hash = ipHash || (rawIp ? hashIp(rawIp) : null);
    if (!hash || this.isProtectedIp(hash)) return null;

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
      if (req.isAdmin === true) {
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
