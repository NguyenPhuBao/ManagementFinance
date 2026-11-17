const logger = require('../../core/logger');
const { ipLookupHash } = require('../../utils/ip-protection.util');
const { defaultAIOpsQuarantineRepository } = require('./aiops.quarantine.repository');
const {
  AIOPS_AUTO_REASON_PREFIX,
  AIOPS_ADMIN_TEMP_PREFIX,
  AIOPS_ADMIN_BAN_PREFIX,
  AIOPS_EXPIRING_PREFIXES,
  lyDoChoNguoiDung,
} = require('./aiops.reason');

// Điều kiện Prisma: lý do khoá mang dấu của khoá có thời hạn (AIOps tự khoá hoặc admin tạm khoá).
const EXPIRING_REASON_WHERE = { OR: AIOPS_EXPIRING_PREFIXES.map((p) => ({ reason_inactive: { startsWith: p } })) };
const IP_EXTEND_MS = 4 * 60 * 60 * 1000;
const { ROOT_ADMIN_EMAIL } = require('../auth/root-admin');
const NO_ACCOUNT = new Set(['', 'all', 'n/a']);

const lockKind = (row, now) => {
  if (!row) return 'unlocked';
  if (row.status === 'PERMANENT') return 'permanent';
  if (row.status === 'TEMPORARY' && row.expires_at && new Date(row.expires_at).getTime() > now) return 'temporary';
  return 'unlocked';
};
const isoOf = (v) => (v ? new Date(v).toISOString() : null);
const minutesLeft = (kind, expiresAt, now) =>
  kind === 'temporary' && expiresAt ? Math.max(0, Math.ceil((new Date(expiresAt).getTime() - now) / 60000)) : null;

/**
 * Che bớt thông tin IP để tuân thủ Data_Security.md & Nghị định 13/2023/NĐ-CP
 */
function maskIp(rawIp) {
  if (!rawIp) return '192.168.xxx.xxx';
  const clean = rawIp.replace(/^::ffff:/, '').trim();
  if (clean === '127.0.0.1' || clean === '::1' || clean === 'localhost') {
    return '127.0.xxx.xxx';
  }
  const v4Parts = clean.split('.');
  if (v4Parts.length === 4) {
    return `${v4Parts[0]}.${v4Parts[1]}.xxx.xxx`;
  }
  const v6Parts = clean.split(':');
  if (v6Parts.length > 2) {
    return `${v6Parts[0]}:${v6Parts[1]}:xxxx:xxxx`;
  }
  return '192.168.xxx.xxx';
}

function hashIp(rawIp) {
  return ipLookupHash(rawIp);
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
    this.defaultDurationMs = options.defaultDurationMs || 4 * 60 * 60 * 1000; // 4 tiếng (3-12h theo yêu cầu PO)
    this.io = options.io || null;
    this.repository = options.repository !== undefined ? options.repository : defaultAIOpsQuarantineRepository;
    this._map = new Map(); // key: normalizedIp -> record (tương thích legacy)
    this._byHash = new Map(); // key: hash -> record
    this._pairs = new Map(); // key: `${ipHash}:::${username || 'all'}` -> pairRecord (Ma trận Cặp IP - Tài khoản)
    this._expireTimer = null;

    // Tự động kích hoạt chu kỳ quét và tự động mở khóa khi hết hạn đếm ngược (mỗi 15s)
    if (options.autoExpire !== false && process.env.NODE_ENV !== 'test') {
      this.startAutoExpireTimer(60000);
    }
  }

  /**
   * Khởi động bộ quét định kỳ tự động giải phóng IP và Tài khoản hết hạn
   */
  startAutoExpireTimer(intervalMs = 15000) {
    if (this._expireTimer) clearInterval(this._expireTimer);
    this._expireTimer = setInterval(async () => {
      try {
        await this.sweepExpiredQuarantines();
      } catch (err) {
        logger.error('[AIOps Quarantine] Lỗi quét tự động hết hạn', { error: err.message });
      }
    }, intervalMs);
    if (this._expireTimer.unref) this._expireTimer.unref();
  }

  /**
   * Dừng bộ quét định kỳ
   */
  stopAutoExpireTimer() {
    if (this._expireTimer) {
      clearInterval(this._expireTimer);
      this._expireTimer = null;
    }
  }

  /**
   * Quét và tự động mở khóa toàn diện cả RAM lẫn CSDL cho các IP và Tài khoản đã hết thời gian đếm ngược
   */
  async sweepExpiredQuarantines() {
    const now = Date.now();
    let hasChanged = false;

    // 1. Quét trong RAM Ma trận _pairs
    for (const [key, record] of this._pairs.entries()) {
      // Tự động hết hạn IP
      if (record.ipStatus === 'temporary' && record.ipExpiresAt !== null && now >= record.ipExpiresAt) {
        record.ipStatus = 'unlocked';
        record.ipExpiresAt = null;
        if (record.ip) this._map.delete(record.ip);
        if (record.ipHash) this._byHash.delete(record.ipHash);
        if (this.repository && typeof this.repository.updateIpStatus === 'function') {
          this.repository.updateIpStatus({
            ipHash: record.ipHash,
            status: 'UNLOCKED',
            unblockedBy: 'AIOps Sentinel Auto-Expire',
            unblockReason: 'Tự động mở khóa do hết thời hạn tạm khóa',
          }).catch(() => { });
        }
        hasChanged = true;
        logger.info(`[AIOps Quarantine] Tự động mở khóa IP ${record.maskedIp} do hết thời gian tạm khóa.`);
      }

      // Tự động hết hạn Tài khoản
      if (record.accountStatus === 'temporary' && record.accountExpiresAt !== null && now >= record.accountExpiresAt) {
        record.accountStatus = 'unlocked';
        record.accountExpiresAt = null;
        if (this.repository && typeof this.repository.updateAccountStatus === 'function') {
          this.repository.updateAccountStatus({
            username: record.username,
            idaccount: record.idaccount,
            status: 'UNLOCKED',
            unblockedBy: 'AIOps Sentinel Auto-Expire',
            unblockReason: 'Tự động mở khóa do hết thời hạn tạm khóa',
          }).catch(() => { });
        }
        this._syncAccountStatusToDatabase(record.idaccount || record.username, 'Active', null, { onlyAIOpsLocked: true, idaccount: record.idaccount, username: record.username }).catch(() => { });
        hasChanged = true;
        logger.info(`[AIOps Quarantine] Tự động mở khóa Tài khoản [${record.username}] do hết thời gian tạm khóa.`);
      }
    }

    // 2. Quét dọn dẹp trong CSDL PostgreSQL
    if (this.repository && typeof this.repository.autoExpireInDatabase === 'function') {
      try {
        const dbResult = await this.repository.autoExpireInDatabase();
        const expiredAccounts = dbResult?.expiredAccounts || [];
        for (const acc of expiredAccounts) {
          await this._syncAccountStatusToDatabase(acc.idaccount || acc.username, 'Active', null, { onlyAIOpsLocked: true, idaccount: acc.idaccount, username: acc.username });
          hasChanged = true;
        }
        if ((dbResult?.expiredIps?.length || 0) > 0) {
          hasChanged = true;
        }
      } catch (err) {
        logger.warn('[AIOps Quarantine] Lỗi quét CSDL autoExpireInDatabase', { error: err.message });
      }
    }

    if (await this._reconcileAutoLocks()) {
      hasChanged = true;
    }

    if (hasChanged) {
      this._emitUpdatedEvent();
    }
    return hasChanged;
  }

  // Không có miễn khoá IP theo phiên admin: IP bị khoá thì chặn cả admin (mục 2.5, 2026-11-16).

  /**
   * Kiểm tra xem địa chỉ IP hoặc Actor Hash có thuộc vùng an toàn bất khả xâm phạm
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

    return false;
  }

  getIO() {
    if (this.io) return this.io;
    try {
      const { getIO } = require('../../core/socket');
      if (typeof getIO === 'function') {
        return getIO();
      }
    } catch (_) { }
    return null;
  }

  /**
   * Đăng ký cách ly một cặp (Địa chỉ IP, Tài khoản) - Hỗ trợ đa liên kết (Quarantine Matrix)
   * Mặc định ban đầu: Cả IP và Tài khoản đều bị Tạm Khóa (Temporary)
   */
  quarantinePair({
    ip = null,
    ipHash: ipHashParam = null,
    maskedIp: maskedIpParam = null,
    username = null,
    idaccount = null,
    reason = 'Phát hiện hành vi bất thường',
    durationMs = null,
    banType = 'temporary',
    vector = 'auth',
  } = {}) {
    const rawIp = ip ? normalizeIp(ip) : null;
    if (rawIp && this.isProtectedIp(rawIp)) {
      logger.warn(`[AIOps Quarantine] Từ chối cô lập IP nội bộ/được bảo vệ: ${rawIp} (Lá chắn Localhost Shield)`);
      return null;
    }
    if (ipHashParam && this.isProtectedIp(ipHashParam)) {
      logger.warn(`[AIOps Quarantine] Từ chối cô lập ipHash nội bộ/được bảo vệ: ${ipHashParam}`);
      return null;
    }

    const cleanUser = username ? String(username).trim() : null;
    const accountDefaultDuration = 15 * 60 * 1000; // 15 phút theo chuẩn Task 58.5 cho tài khoản
    const accountDuration = durationMs !== null ? durationMs : (cleanUser ? accountDefaultDuration : this.defaultDurationMs);
    const now = Date.now();
    const expiresAt = banType === 'permanent' ? null : now + accountDuration;
    const ipHash = ipHashParam || (rawIp ? hashIp(rawIp) : '0000000000000000');
    let masked = maskedIpParam || (rawIp ? maskIp(rawIp) : '192.168.xxx.xxx');
    if (!masked || masked === 'xx.xx.xx.xx' || masked === 'xx.xx.xxx.xxx' || masked === 'traffic_cluster_ip') {
      masked = rawIp ? maskIp(rawIp) : '192.168.xxx.xxx';
    }

    const pairKey = `${ipHash}:::${cleanUser ? cleanUser.toLowerCase() : 'all'}`;

    let record = this._pairs.get(pairKey);
    const ipDuration = durationMs !== null ? durationMs : this.defaultDurationMs;
    const ipExpiresAt = now + ipDuration;

    if (record) {
      record.hits += 1;
      // CHÍNH SÁCH AN NINH PO: IP LUÔN LUÔN LÀ TEMPORARY, KHÔNG BAO GIỜ KHÓA VĨNH VIỄN
      record.ipStatus = 'temporary';
      record.ipExpiresAt = record.ipExpiresAt ? Math.max(record.ipExpiresAt, ipExpiresAt) : ipExpiresAt;

      if (banType === 'permanent') {
        record.accountStatus = 'permanent';
        record.accountExpiresAt = null;
        record.expiresAt = null;
      } else {
        if (record.accountStatus !== 'permanent') {
          record.accountExpiresAt = record.accountExpiresAt ? Math.max(record.accountExpiresAt, expiresAt) : expiresAt;
          record.accountStatus = 'temporary';
        }
        record.expiresAt = Math.max(record.ipExpiresAt || 0, record.accountExpiresAt || 0) || null;
      }
      record.reason = reason;
      if (vector) record.vector = vector;
      if (masked && masked !== '192.168.xxx.xxx') record.maskedIp = masked;
      if (idaccount && !record.idaccount) record.idaccount = idaccount;
    } else {
      record = {
        id: pairKey,
        ip: rawIp,
        hash: ipHash,
        ipHash,
        maskedIp: masked,
        idaccount: idaccount || null,
        username: cleanUser || 'N/A',
        vector: vector || 'auth',
        ipStatus: 'temporary', // CHÍNH SÁCH BẤT BIẾN: IP chỉ tạm khóa 4 giờ
        ipExpiresAt,           // Luôn có thời hạn hết hạn tự động mở khóa
        accountStatus: banType === 'permanent' ? 'permanent' : 'temporary',
        accountExpiresAt: banType === 'permanent' ? null : expiresAt,
        banType,
        reason,
        bannedAt: new Date(now).toISOString(),
        expiresAt: banType === 'permanent' ? null : Math.max(ipExpiresAt, expiresAt || 0),
        hits: 1,
      };
      this._pairs.set(pairKey, record);
    }

    // Đồng bộ vào _map và _byHash để tương thích hoàn toàn middleware và logic cũ
    const legacyRecord = {
      ip: rawIp,
      maskedIp: masked,
      hash: ipHash,
      reason,
      bannedAt: record.bannedAt,
      expiresAt: record.expiresAt,
      hits: record.hits,
    };
    if (rawIp) {
      this._map.set(rawIp, legacyRecord);
    }
    this._byHash.set(ipHash, legacyRecord);

    logger.warn(`[AIOps Quarantine] Cách ly cặp (IP: ${masked}, User: ${cleanUser || 'N/A'})`, {
      reason,
      ipStatus: record.ipStatus,
      accountStatus: record.accountStatus,
      hits: record.hits,
    });

    // Ghi bất đồng bộ xuống CSDL qua repository (Write-through)
    if (this.repository && typeof this.repository.recordQuarantinePair === 'function') {
      record._persistPromise = this.repository.recordQuarantinePair({
        ip: rawIp,
        maskedIp: masked,
        ipHash,
        username: cleanUser,
        idaccount,
        reason,
        durationMs,
        banType,
        vector: record.violation_vector || null,
        threatScore: record.threat_score_at_ban || null,
      }).catch((err) => {
        logger.error('[AIOps Quarantine] Lỗi ghi async cặp quarantine vào CSDL', { error: err.message });
      });
    }

    // Tác động thực tế CSDL bảng account (Tầng 2 System Impact): Vô hiệu hóa tài khoản trong database
    if (cleanUser && cleanUser !== 'all' && cleanUser !== 'N/A') {
      const autoReason = reason && String(reason).startsWith(AIOPS_AUTO_REASON_PREFIX)
        ? reason
        : `${AIOPS_AUTO_REASON_PREFIX}: ${reason || 'Cách ly tự động do phát hiện vi phạm an ninh'}`;
      this._syncAccountStatusToDatabase(idaccount || cleanUser, 'Inactive', autoReason, { idaccount, username: cleanUser, autoQuarantine: true }).catch(() => { });
    }

    this._emitQuarantineEvents(record);
    return record;
  }

  /**
   * Tự động nạp (hydrate) các bản ghi phong tỏa đang có hiệu lực từ CSDL PostgreSQL vào RAM khi Server khởi động
   * @returns {Promise<number>} Số lượng bản ghi đã được nạp
   */
  async hydrateFromDatabase() {
    if (!this.repository || typeof this.repository.loadActiveQuarantines !== 'function') return 0;
    try {
      const activeData = await this.repository.loadActiveQuarantines();
      await this._reconcileAutoLocks();
      const ips = activeData.ips || [];
      const accounts = activeData.accounts || [];
      const links = activeData.links || [];
      let count = 0;

      const nowTs = Date.now();

      // 1. Nạp IP vào _map và _byHash để middleware chặn O(1)
      for (const ipRec of ips) {
        const rawIp = ipRec.raw_ip;
        const hash = ipRec.ip_hash;
        const rawMasked = ipRec.masked_ip;
        const masked = (!rawMasked || rawMasked === 'xx.xx.xx.xx' || rawMasked === 'xx.xx.xxx.xxx' || rawMasked === 'traffic_cluster_ip')
          ? (rawIp ? maskIp(rawIp) : '192.168.xxx.xxx')
          : rawMasked;
        const isPerm = ipRec.status === 'PERMANENT';
        const exp = isPerm ? null : (ipRec.expires_at ? new Date(ipRec.expires_at).getTime() : null);
        const isTempActive = ipRec.status === 'TEMPORARY' && exp && exp > nowTs;

        // Chỉ nạp vào O(1) middleware nếu thực sự đang bị phong tỏa
        if (!isPerm && !isTempActive) {
          continue;
        }

        const rec = {
          ip: rawIp,
          maskedIp: masked,
          hash,
          reason: ipRec.reason,
          bannedAt: ipRec.banned_at ? new Date(ipRec.banned_at).toISOString() : new Date().toISOString(),
          expiresAt: exp,
          hits: ipRec.hits || 1,
        };
        if (rawIp) this._map.set(rawIp, rec);
        if (hash) this._byHash.set(hash, rec);
        count += 1;
      }

      // 2. Nạp links vào _pairs (Ma trận Cặp)
      for (const link of links) {
        const pairKey = `${link.ip_hash}:::${link.username || 'all'}`;
        const ipRec = ips.find((x) => x.ip_hash === link.ip_hash);
        const accRec = accounts.find((x) => String(x.username || '').toLowerCase() === String(link.username || '').toLowerCase());

        const isPermIp = ipRec?.status === 'PERMANENT';
        const isPermAcc = accRec?.status === 'PERMANENT';
        const isTempIp = ipRec?.status === 'TEMPORARY' && ipRec?.expires_at && new Date(ipRec.expires_at).getTime() > nowTs;
        const isTempAcc = accRec?.status === 'TEMPORARY' && accRec?.expires_at && new Date(accRec.expires_at).getTime() > nowTs;

        const ipStatus = isPermIp ? 'permanent' : (isTempIp ? 'temporary' : 'unlocked');
        const accStatus = isPermAcc ? 'permanent' : (isTempAcc ? 'temporary' : 'unlocked');
        const ipExpiresAt = (ipStatus === 'temporary' && ipRec?.expires_at) ? new Date(ipRec.expires_at).getTime() : null;
        const accountExpiresAt = (accStatus === 'temporary' && accRec?.expires_at) ? new Date(accRec.expires_at).getTime() : null;
        const exp = Math.max(ipExpiresAt || 0, accountExpiresAt || 0) || null;

        const rawLinkMasked = ipRec?.masked_ip;
        const linkMasked = (!rawLinkMasked || rawLinkMasked === 'xx.xx.xx.xx' || rawLinkMasked === 'xx.xx.xxx.xxx' || rawLinkMasked === 'traffic_cluster_ip')
          ? (ipRec?.raw_ip ? maskIp(ipRec?.raw_ip) : '192.168.xxx.xxx')
          : rawLinkMasked;

        this._pairs.set(pairKey, {
          id: pairKey,
          ip: ipRec?.raw_ip || null,
          hash: link.ip_hash,
          ipHash: link.ip_hash,
          maskedIp: linkMasked,
          idaccount: accRec?.idaccount || null,
          username: link.username || 'N/A',
          ipStatus,
          ipExpiresAt,
          accountStatus: accStatus,
          accountExpiresAt,
          banType: (isPermIp || isPermAcc) ? 'permanent' : (isTempIp || isTempAcc ? 'temporary' : 'unlocked'),
          reason: link.reason,
          bannedAt: link.detected_at ? new Date(link.detected_at).toISOString() : new Date().toISOString(),
          expiresAt: exp,
          hits: 1,
        });
      }

      // 3. Đảm bảo các IP active chưa có link cũng xuất hiện trong _pairs
      for (const ipRec of ips) {
        const isPerm = ipRec.status === 'PERMANENT';
        const isTemp = ipRec.status === 'TEMPORARY' && ipRec.expires_at && new Date(ipRec.expires_at).getTime() > nowTs;
        if (!isPerm && !isTemp) continue;

        const pairKey = `${ipRec.ip_hash}:::all`;
        if (!this._pairs.has(pairKey)) {
          const ipExpiresAt = (isTemp && ipRec.expires_at) ? new Date(ipRec.expires_at).getTime() : null;
          const rawSoloMasked = ipRec.masked_ip;
          const soloMasked = (!rawSoloMasked || rawSoloMasked === 'xx.xx.xx.xx' || rawSoloMasked === 'xx.xx.xxx.xxx' || rawSoloMasked === 'traffic_cluster_ip')
            ? (ipRec.raw_ip ? maskIp(ipRec.raw_ip) : '192.168.xxx.xxx')
            : rawSoloMasked;

          this._pairs.set(pairKey, {
            id: pairKey,
            ip: ipRec.raw_ip || null,
            hash: ipRec.ip_hash,
            ipHash: ipRec.ip_hash,
            maskedIp: soloMasked,
            idaccount: null,
            username: 'all',
            ipStatus: isPerm ? 'permanent' : 'temporary',
            ipExpiresAt,
            accountStatus: 'unlocked',
            accountExpiresAt: null,
            banType: isPerm ? 'permanent' : 'temporary',
            reason: ipRec.reason,
            bannedAt: ipRec.banned_at ? new Date(ipRec.banned_at).toISOString() : new Date().toISOString(),
            expiresAt: ipExpiresAt,
            hits: ipRec.hits || 1,
          });
        }
      }

      logger.info(`[AIOps Quarantine] Đã khôi phục thành công ${count} nguồn phong tỏa từ CSDL PostgreSQL.`);
      return count;
    } catch (err) {
      logger.error('[AIOps Quarantine] Lỗi hydrate dữ liệu phong tỏa từ CSDL', { error: err.message });
      return 0;
    }
  }

  /**
   * Tương thích ngược: Đưa 1 địa chỉ IP vào danh sách cô lập
   */
  quarantine(rawIp, reason = 'Phát hiện hành vi bất thường', durationMs = null) {
    return this.quarantinePair({
      ip: rawIp,
      reason,
      durationMs,
    });
  }

  /**
   * Admin chủ động phong tỏa đối tượng khả nghi từ bảng Root Cause Analysis (RCA)
   */
  quarantineActor({
    rawIp = null,
    ipHash = null,
    maskedIp = null,
    username = null,
    idaccount = null,
    reason = 'Admin chủ động phong tỏa từ nhật ký RCA',
    durationMs = null,
    banType = 'temporary',
  } = {}) {
    if (rawIp && this.isProtectedIp(rawIp)) {
      logger.warn(`[AIOps Quarantine] Từ chối cô lập rawIp nội bộ/được bảo vệ: ${rawIp}`);
      return null;
    }
    if (ipHash && this.isProtectedIp(ipHash)) {
      logger.warn(`[AIOps Quarantine] Từ chối cô lập ipHash nội bộ/được bảo vệ: ${ipHash}`);
      return null;
    }

    return this.quarantinePair({
      ip: rawIp,
      ipHash,
      maskedIp,
      username,
      idaccount,
      reason,
      durationMs,
      banType,
    });
  }

  /**
   * Mở khóa IP: Đồng bộ TẤT CẢ các dòng/bản ghi có cùng địa chỉ IP và cập nhật DB
   * @returns {Promise<number>} Số lượng bản ghi đã được mở khóa
   */
  async unblockIp(ipHashOrIp, { unblockedBy = null, unblockReason = null } = {}) {
    if (!ipHashOrIp) return 0;
    let count = 0;
    for (const [key, record] of this._pairs.entries()) {
      if (record.ipHash === ipHashOrIp || record.ip === ipHashOrIp) {
        record.ipStatus = 'unlocked';
        record.ipExpiresAt = null;
        count += 1;
      }
    }
    // Gỡ khỏi _map & _byHash để middleware không chặn nữa
    this.unblock(ipHashOrIp);

    // Cập nhật CSDL qua repository
    if (this.repository && typeof this.repository.updateIpStatus === 'function') {
      try {
        await this.repository.updateIpStatus({
          ipHash: ipHashOrIp,
          status: 'UNLOCKED',
          unblockedBy,
          unblockReason,
        });
      } catch (err) {
        logger.error('[AIOps Quarantine] Lỗi cập nhật status UNLOCKED IP trong DB', { error: err.message });
      }
    }

    this._emitUpdatedEvent();
    return count;
  }

  /**
   * Khóa IP: Áp dụng chính sách an ninh mới của PO — Tuyệt đối không khóa vĩnh viễn IP
   * Chuyển hóa toàn bộ sang Tạm khóa 4 giờ (4 * 3600 * 1000 ms) để tránh chặn nhầm người dùng mạng CGNAT/4G.
   * @returns {Promise<number>} Số lượng bản ghi đã được cập nhật
   */
  async permanentBanIp(ipHashOrIp, { bannedBy = null } = {}) {
    if (!ipHashOrIp) return 0;
    // Tên cũ giữ cho tương thích: IP không có khoá vĩnh viễn, nên đây chính là "Khóa thêm 4 giờ".
    return this.extendIp(ipHashOrIp, { blockedBy: bannedBy });
  }

  /**
   * Đồng bộ trạng thái tài khoản xuống CSDL bảng account (Prisma)
   * Đảm bảo tính toàn vẹn và tác động thực tế (Tầng 2 System Impact)
   */
  async _syncAccountStatusToDatabase(usernameOrId, status, reason = null, options = {}) {
    if (!usernameOrId || usernameOrId === 'all' || usernameOrId === 'N/A') return;
    try {
      const { prisma } = require('../../config/db');
      if (!prisma || !prisma.account || typeof prisma.account.updateMany !== 'function') return;

      // Task 58.6 #2: Phân biệt chính xác giữa idaccount (số nguyên) và username (chuỗi)
      let resolvedTargetId = null;
      const isExplicitId = (typeof options.idaccount === 'number' && Number.isInteger(options.idaccount))
        || (typeof usernameOrId === 'number' && Number.isInteger(usernameOrId));

      if (isExplicitId) {
        resolvedTargetId = Number(options.idaccount || usernameOrId);
      } else if (options.username || typeof usernameOrId === 'string') {
        const userVal = String(options.username || usernameOrId).trim();
        if (typeof prisma.account.findFirst === 'function') {
          const acc = await prisma.account.findFirst({
            where: { username: userVal },
            select: { idaccount: true },
          });
          if (acc) resolvedTargetId = acc.idaccount;
        }
      }

      const isNum = !isNaN(Number(usernameOrId)) && typeof usernameOrId !== 'boolean';
      const identifierCondition = resolvedTargetId
        ? { idaccount: resolvedTargetId }
        : (options.username
            ? { username: String(options.username).trim() }
            : (isNum
                ? { OR: [{ idaccount: Number(usernameOrId) }, { username: String(usernameOrId).trim() }] }
                : { username: String(usernameOrId).trim() }));

      const andConditions = [identifierCondition];

      if (status === 'Active') {
        // Chỉ mở khóa nếu tài khoản đang Inactive (bảo vệ tuyệt đối PendingDelete và các trạng thái khác)
        andConditions.push({ status: 'Inactive' });

        // Nếu là quét tự động hết hạn, chỉ mở khóa tài khoản do AIOps/Sentinel khóa, tránh can thiệp khóa do Admin thủ công (Task 58.5)
        if (options && options.onlyAIOpsLocked) {
          andConditions.push(EXPIRING_REASON_WHERE);
        }
      } else if (options.autoQuarantine) {
        // Khoá tự động chỉ đụng hàng đang Active: không ghi đè khoá của admin, không đụng PendingDelete / Deleted
        andConditions.push({ status: 'Active' });
      } else {
        // Khi khóa (Inactive): Tuyệt đối không ghi đè nếu tài khoản đang trong quy trình chờ xóa (PendingDelete)
        andConditions.push({ status: { not: 'PendingDelete' } });
      }
      // Tài khoản quản trị gốc không bao giờ bị khoá (trigger CSDL 56 cũng chặn).
      if (status !== 'Active') andConditions.push({ email: { not: ROOT_ADMIN_EMAIL } });

      const updateResult = await prisma.account.updateMany({
        where: { AND: andConditions },
        data: {
          status,
          reason_inactive: status === 'Active' ? null : reason,
        },
      });

      const updatedCount = updateResult?.count ?? 0;
      logger.info(`[AIOps Quarantine] Đã đồng bộ CSDL bảng account -> ${status} cho [${usernameOrId}] (${updatedCount} hàng)`);

      // Task 58.6 & 43.A6: Chỉ phát socket account.force_logout khi thực sự có ít nhất 1 hàng chuyển sang Inactive thành công
      if (status === 'Inactive' && updatedCount > 0) {
        try {
          const { emitForceLogout } = require('../../core/socket');
          const { invalidateAccountCache } = require('../../middleware/auth');
          const targetId = resolvedTargetId;
          if (targetId) {
            invalidateAccountCache(targetId);
            emitForceLogout(targetId, 'ACCOUNT_INACTIVE', lyDoChoNguoiDung(reason) || 'Tài khoản của bạn đã bị cách ly tạm khóa để bảo vệ an toàn.');
          }
        } catch (socketErr) {
          logger.warn('[AIOps Quarantine] Không thể phát force_logout:', socketErr.message);
        }
      }
    } catch (err) {
      logger.warn(`[AIOps Quarantine] Cảnh báo đồng bộ CSDL bảng account cho [${usernameOrId}]`, { error: err.message });
    }
  }

  /**
   * Đối soát không phụ thuộc RAM (Task 58.5): account mang dấu AIOps mà không còn hàng phong tỏa hiệu lực ⇒ mở.
   * Chạy lúc khởi động và mỗi lượt quét, nên máy chủ dừng qua mốc hết hạn vẫn tự lành.
   */
  async _reconcileAutoLocks() {
    if (!this.repository || typeof this.repository.getAccountByUsername !== 'function') return false;
    try {
      const { prisma } = require('../../config/db');
      if (!prisma?.account?.findMany) return false;
      const locked = await prisma.account.findMany({
        where: { status: 'Inactive', ...EXPIRING_REASON_WHERE },
        select: { idaccount: true, username: true },
      });
      const now = Date.now();
      let changed = false;
      for (const acc of locked) {
        const clean = String(acc.username).toLowerCase();
        // Hàng vừa khoá có thể chưa ghi xong aiops_account_quarantine: RAM còn hiệu lực thì bỏ qua
        const conTrongRam = [...this._pairs.values()].some((r) => r.username && r.username.toLowerCase() === clean
          && (r.accountStatus === 'permanent' || (r.accountStatus === 'temporary' && r.accountExpiresAt > now)));
        if (conTrongRam) continue;
        const row = await this.repository.getAccountByUsername(acc.username);
        const conHieuLuc = row && (row.status === 'PERMANENT'
          || (row.status === 'TEMPORARY' && row.expires_at && new Date(row.expires_at).getTime() > now));
        if (conHieuLuc) continue;
        await this._syncAccountStatusToDatabase(acc.idaccount, 'Active', null, { onlyAIOpsLocked: true, idaccount: acc.idaccount, username: acc.username });
        changed = true;
      }
      return changed;
    } catch (err) {
      logger.warn('[AIOps Quarantine] Lỗi đối soát khoá tự động', { error: err.message });
      return false;
    }
  }

  /**
   * Mở khóa Tài khoản: Đồng bộ TẤT CẢ các dòng/bản ghi có cùng tên Tài khoản và cập nhật DB
   * @returns {Promise<number>} Số lượng bản ghi đã được mở khóa
   */
  async unblockAccount(usernameOrId, { unblockedBy = null, unblockReason = null } = {}) {
    if (!usernameOrId) return 0;
    const clean = String(usernameOrId).toLowerCase().trim();
    let count = 0;
    for (const [key, record] of this._pairs.entries()) {
      if (
        (record.username && record.username.toLowerCase() === clean) ||
        String(record.idaccount) === String(usernameOrId)
      ) {
        record.accountStatus = 'unlocked';
        record.accountExpiresAt = null;
        count += 1;
      }
    }

    const acc = await this._resolveAccount(usernameOrId);
    // Cập nhật CSDL bảng aiops_account_quarantine qua repository (dòng vẫn giữ, trạng thái UNLOCKED)
    if (this.repository && typeof this.repository.updateAccountStatus === 'function') {
      try {
        await this.repository.updateAccountStatus({
          username: acc?.username || usernameOrId,
          idaccount: acc?.idaccount || null,
          status: 'UNLOCKED',
          unblockedBy,
          unblockReason,
        });
      } catch (err) {
        logger.error('[AIOps Quarantine] Lỗi cập nhật status UNLOCKED Tài khoản trong DB', { error: err.message });
      }
    }

    // Tác động thực tế CSDL bảng account (Tầng 2 System Impact): Kích hoạt lại tài khoản
    await this._syncAccountStatusToDatabase(acc?.idaccount || usernameOrId, 'Active', null, { idaccount: acc?.idaccount });

    this._emitUpdatedEvent();
    return count;
  }

  /**
   * Khóa vĩnh viễn Tài khoản: Đồng bộ TẤT CẢ các dòng/bản ghi có cùng tên Tài khoản và cập nhật DB
   * @returns {Promise<number>} Số lượng bản ghi đã được cập nhật
   */
  async permanentBanAccount(usernameOrId, { bannedBy = null } = {}) {
    if (!usernameOrId) return 0;
    const clean = String(usernameOrId).toLowerCase().trim();
    let count = 0;
    for (const [key, record] of this._pairs.entries()) {
      if (
        (record.username && record.username.toLowerCase() === clean) ||
        String(record.idaccount) === String(usernameOrId)
      ) {
        record.accountStatus = 'permanent';
        record.accountExpiresAt = null;
        count += 1;
      }
    }

    // Dấu ADMIN_BAN: không bao giờ tự mở, chỉ admin mở thủ công.
    const reason = `${AIOPS_ADMIN_BAN_PREFIX} Quản trị viên khóa tài khoản do phát hiện vi phạm an ninh`;
    const acc = await this._recordAccountLock(usernameOrId, { status: 'PERMANENT', reason, bannedBy });
    await this._syncAccountStatusToDatabase(acc?.idaccount || usernameOrId, 'Inactive', reason, { idaccount: acc?.idaccount });

    this._emitUpdatedEvent();
    return count;
  }

  /**
   * Tạm khóa IP (3-12 tiếng, mặc định 4 tiếng theo yêu cầu PO)
   */
  async temporaryBlockIp(ipHashOrIp, { durationMs = null, blockedBy = null, reason = 'Admin tạm khóa IP' } = {}) {
    if (!ipHashOrIp) return 0;
    const dur = durationMs || this.defaultDurationMs;
    const exp = Date.now() + dur;
    let count = 0;
    for (const [key, record] of this._pairs.entries()) {
      if (record.ipHash === ipHashOrIp || record.ip === ipHashOrIp) {
        record.ipStatus = 'temporary';
        record.ipExpiresAt = exp;
        record.expiresAt = exp;
        record.reason = reason;
        count += 1;
      }
    }
    for (const [ip, rec] of this._map.entries()) {
      if (rec.hash === ipHashOrIp || ip === ipHashOrIp) {
        rec.expiresAt = exp;
      }
    }

    if (this.repository && typeof this.repository.updateIpStatus === 'function') {
      try {
        await this.repository.updateIpStatus({
          ipHash: ipHashOrIp,
          status: 'TEMPORARY',
          bannedBy: blockedBy,
          expiresAt: new Date(exp),
        });
      } catch (err) {
        logger.error('[AIOps Quarantine] Lỗi cập nhật status TEMPORARY IP trong DB', { error: err.message });
      }
    }

    this._emitUpdatedEvent();
    return count;
  }

  /**
   * Tạm khóa Tài khoản (3-12 tiếng, mặc định 4 tiếng theo yêu cầu PO)
   */
  async temporaryBlockAccount(usernameOrId, { durationMs = null, blockedBy = null } = {}) {
    if (!usernameOrId) return 0;
    const clean = String(usernameOrId).toLowerCase().trim();
    const dur = durationMs || this.defaultDurationMs;
    const exp = Date.now() + dur;
    const minutes = Math.round(dur / 60000);
    const span = minutes >= 60 ? `${Math.round(minutes / 60)} giờ` : `${Math.max(1, minutes)} phút`;
    // Dấu ADMIN_TEMP: hết hạn thì bộ quét tự mở (account về Active).
    const reason = `${AIOPS_ADMIN_TEMP_PREFIX} Quản trị viên tạm khóa tài khoản ${span}`;
    let count = 0;
    for (const [key, record] of this._pairs.entries()) {
      if (
        (record.username && record.username.toLowerCase() === clean) ||
        String(record.idaccount) === String(usernameOrId)
      ) {
        record.accountStatus = 'temporary';
        record.accountExpiresAt = exp;
        record.expiresAt = exp;
        record.reason = reason;
        count += 1;
      }
    }

    const acc = await this._recordAccountLock(usernameOrId, { status: 'TEMPORARY', reason, bannedBy: blockedBy, expiresAt: new Date(exp) });
    // Tác động thực tế CSDL bảng account (Tầng 2 System Impact): Vô hiệu hóa tài khoản tạm thời bởi Admin
    await this._syncAccountStatusToDatabase(acc?.idaccount || usernameOrId, 'Inactive', reason, { idaccount: acc?.idaccount });

    this._emitUpdatedEvent();
    return count;
  }

  /**
   * Admin mở tài khoản ở trang Người dùng: dòng khoá AIOps đang hiệu lực của tài khoản đó chuyển UNLOCKED
   * (account.status đã được trang Người dùng đổi, ở đây không đụng).
   */
  async releaseAccountFromUserPage({ idaccount = null, username, by = 'Admin' } = {}) {
    if (!username) return 0;
    const clean = String(username).toLowerCase();
    for (const record of this._pairs.values()) {
      if ((record.username && record.username.toLowerCase() === clean) || (idaccount && Number(record.idaccount) === Number(idaccount))) {
        record.accountStatus = 'unlocked';
        record.accountExpiresAt = null;
      }
    }
    if (!this.repository || typeof this.repository.getAccountByUsername !== 'function') return 0;
    const row = await this.repository.getAccountByUsername(username);
    if (!row || !['TEMPORARY', 'PERMANENT'].includes(row.status)) return 0;
    await this.repository.updateAccountStatus({ username, idaccount, status: 'UNLOCKED', unblockedBy: by, unblockReason: 'Mở từ trang Người dùng' });
    this._emitUpdatedEvent();
    return 1;
  }

  /** Tài khoản đích theo tên đăng nhập hoặc mã (không phân biệt hoa thường với tên). */
  async _resolveAccount(usernameOrId) {
    if (usernameOrId === null || usernameOrId === undefined || NO_ACCOUNT.has(String(usernameOrId).trim().toLowerCase())) return null;
    try {
      const { prisma } = require('../../config/db');
      if (!prisma?.account?.findFirst) return null;
      const s = String(usernameOrId).trim();
      const where = /^\d+$/.test(s)
        ? { OR: [{ idaccount: Number(s) }, { username: s }] }
        : { username: { equals: s, mode: 'insensitive' } };
      return await prisma.account.findFirst({ where, select: { idaccount: true, username: true, idrole: true, email: true } });
    } catch (err) {
      logger.warn('[AIOps Quarantine] Không tra được tài khoản đích', { error: err.message });
      return null;
    }
  }

  /** Ghi dòng theo dõi khoá tài khoản (tạo mới nếu chưa có). Trả về tài khoản đích đã tra. */
  async _recordAccountLock(usernameOrId, { status, reason, bannedBy = null, expiresAt = null }) {
    const acc = await this._resolveAccount(usernameOrId);
    if (this.repository && typeof this.repository.upsertAccountLock === 'function') {
      try {
        await this.repository.upsertAccountLock({
          username: acc?.username || String(usernameOrId).trim(),
          idaccount: acc?.idaccount || null,
          status,
          reason,
          bannedBy,
          expiresAt,
        });
      } catch (err) {
        logger.error('[AIOps Quarantine] Lỗi ghi dòng khoá tài khoản', { error: err.message });
      }
    }
    return acc;
  }

  /** "Khóa thêm 4 giờ" cho IP. IP chỉ có tạm khoá, không có khoá vĩnh viễn. */
  async extendIp(ipHashOrIp, { blockedBy = null } = {}) {
    return this.temporaryBlockIp(ipHashOrIp, { durationMs: IP_EXTEND_MS, blockedBy, reason: 'Admin khóa thêm 4 giờ' });
  }

  /**
   * Danh sách khoá cho Admin-web, đọc từ kho lưu (không phụ thuộc bộ nhớ): mọi IP và tài khoản từng bị khoá,
   * kể cả đã mở. Mỗi dòng là một cặp (IP, tài khoản) theo lần vi phạm gần nhất; IP hoặc tài khoản không có cặp
   * thì đứng riêng một dòng. Kho lưu không đọc được thì dùng danh sách trong bộ nhớ.
   */
  async listQuarantines() {
    const data = this.repository && typeof this.repository.listQuarantineRows === 'function'
      ? await this.repository.listQuarantineRows()
      : null;
    if (!data) return this.getQuarantinedList();

    const now = Date.now();
    const ipByHash = new Map(data.ips.map((r) => [r.ip_hash, r]));
    const accByName = new Map(
      data.accounts.filter((r) => !NO_ACCOUNT.has(String(r.username || '').toLowerCase())).map((r) => [String(r.username).toLowerCase(), r])
    );
    const usedIps = new Set();
    const usedAccounts = new Set();
    const rows = [];

    const push = (ipRow, accRow, link) => {
      const ipStatus = ipRow ? lockKind(ipRow, now) : null;
      const accountStatus = accRow ? lockKind(accRow, now) : null;
      const ipExpiresAt = ipStatus === 'temporary' ? isoOf(ipRow.expires_at) : null;
      const accountExpiresAt = accountStatus === 'temporary' ? isoOf(accRow.expires_at) : null;
      const bannedAt = [ipRow?.banned_at, accRow?.banned_at, link?.detected_at].filter(Boolean).map((v) => new Date(v).getTime());
      const ipRemainingMinutes = minutesLeft(ipStatus, ipRow?.expires_at, now);
      const accountRemainingMinutes = minutesLeft(accountStatus, accRow?.expires_at, now);
      rows.push({
        id: `${ipRow?.ip_hash || 'none'}:::${accRow ? String(accRow.username).toLowerCase() : 'all'}`,
        hash: ipRow?.ip_hash || null,
        ipHash: ipRow?.ip_hash || null,
        maskedIp: ipRow?.masked_ip || null,
        username: accRow?.username || 'N/A',
        idaccount: accRow?.idaccount || null,
        vector: ipRow?.violation_vector || accRow?.violation_vector || 'auth',
        ipStatus,
        accountStatus,
        reason: lyDoChoNguoiDung(link?.reason || accRow?.reason || ipRow?.reason || null),
        bannedAt: bannedAt.length ? new Date(Math.max(...bannedAt)).toISOString() : null,
        ipExpiresAt,
        accountExpiresAt,
        ipRemainingMinutes,
        accountRemainingMinutes,
        expiresAt: ipExpiresAt || accountExpiresAt,
        remainingMinutes: ipRemainingMinutes || accountRemainingMinutes || null,
        ipUnblockedBy: ipStatus === 'unlocked' ? ipRow?.unblocked_by || null : null,
        ipUnblockedAt: ipStatus === 'unlocked' ? isoOf(ipRow?.unblocked_at) : null,
        accountUnblockedBy: accountStatus === 'unlocked' ? accRow?.unblocked_by || null : null,
        accountUnblockedAt: accountStatus === 'unlocked' ? isoOf(accRow?.unblocked_at) : null,
        hits: Number(ipRow?.hits || accRow?.hits || 1),
      });
    };

    for (const link of data.links) {
      const ipRow = ipByHash.get(link.ip_hash);
      const accRow = accByName.get(String(link.username || '').toLowerCase()) || null;
      if (!ipRow) continue;
      push(ipRow, accRow, link);
      usedIps.add(link.ip_hash);
      if (accRow) usedAccounts.add(String(accRow.username).toLowerCase());
    }
    for (const ipRow of data.ips) if (!usedIps.has(ipRow.ip_hash)) push(ipRow, null, null);
    for (const [key, accRow] of accByName) if (!usedAccounts.has(key)) push(null, accRow, null);

    return rows.sort((a, b) => new Date(b.bannedAt || 0) - new Date(a.bannedAt || 0));
  }

  /**
   * Kiểm tra xem Tài khoản có đang bị cách ly tạm thời hay vĩnh viễn không ($O(1)$)
   * Kèm cơ chế Lazy Auto-Unlock nếu đã hết thời gian cách ly (Task 58.5)
   */
  isAccountQuarantined(usernameOrId) {
    if (!usernameOrId || usernameOrId === 'all' || usernameOrId === 'N/A') {
      return { quarantined: false };
    }
    const clean = String(usernameOrId).toLowerCase().trim();
    const now = Date.now();

    for (const [key, record] of this._pairs.entries()) {
      if (
        (record.username && record.username.toLowerCase() === clean) ||
        String(record.idaccount) === String(usernameOrId)
      ) {
        // Lazy auto-unlock nếu đã quá hạn 15 phút
        if (record.accountStatus === 'temporary' && record.accountExpiresAt !== null && now >= record.accountExpiresAt) {
          record.accountStatus = 'unlocked';
          record.accountExpiresAt = null;
          if (this.repository && typeof this.repository.updateAccountStatus === 'function') {
            this.repository.updateAccountStatus({
              username: record.username,
              idaccount: record.idaccount,
              status: 'UNLOCKED',
              unblockedBy: 'AIOps Sentinel Auto-Expire',
              unblockReason: 'Tự động mở khóa do hết thời hạn tạm khóa 15 phút',
            }).catch(() => { });
          }
          this._syncAccountStatusToDatabase(record.idaccount || record.username, 'Active', null, { onlyAIOpsLocked: true, idaccount: record.idaccount, username: record.username }).catch(() => { });
          continue;
        }

        if (record.accountStatus === 'temporary' || record.accountStatus === 'permanent') {
          return {
            quarantined: true,
            status: record.accountStatus,
            reason: record.reason,
            expiresAt: record.accountExpiresAt,
            remainingMinutes: record.accountExpiresAt ? Math.max(0, Math.ceil((record.accountExpiresAt - now) / 60000)) : null,
          };
        }
      }
    }

    return { quarantined: false };
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
    const now = Date.now();

    // 1. Kiểm tra ưu tiên trong danh sách _pairs
    let isBlocked = false;
    let hitRecord = null;
    for (const [key, record] of this._pairs.entries()) {
      if (record.ip === ip || record.ipHash === clientHash) {
        // Tự động hết hạn IP tạm khóa
        if (record.ipStatus === 'temporary' && record.ipExpiresAt !== null && now > record.ipExpiresAt) {
          record.ipStatus = 'unlocked';
          record.ipExpiresAt = null;
          if (this.repository && typeof this.repository.updateIpStatus === 'function') {
            this.repository.updateIpStatus({ ipHash: record.ipHash, status: 'UNLOCKED' }).catch(() => { });
          }
        }
        if (record.ipStatus === 'temporary' || record.ipStatus === 'permanent') {
          isBlocked = true;
          hitRecord = record;
          break;
        }
      }
    }

    if (isBlocked && hitRecord) {
      return {
        quarantined: true,
        reason: hitRecord.reason,
        expiresAt: hitRecord.ipExpiresAt,
        hits: hitRecord.hits,
        maskedIp: hitRecord.maskedIp,
      };
    }

    // 2. Fallback kiểm tra _map & _byHash nếu chưa qua pair
    let record = this._map.get(ip) || this._byHash.get(clientHash);
    if (!record) return { quarantined: false };

    if (record.expiresAt !== null && now > record.expiresAt) {
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

    // 1. Cập nhật giải phóng trong _pairs
    for (const [key, record] of this._pairs.entries()) {
      if (record.ipHash === ipHashOrIp || record.ip === ipHashOrIp) {
        record.ipStatus = 'unlocked';
        record.ipExpiresAt = null;
        unblocked = true;
      }
    }

    // 2. Kiểm tra và xóa trong _byHash
    if (this._byHash.has(ipHashOrIp)) {
      const rec = this._byHash.get(ipHashOrIp);
      this._byHash.delete(ipHashOrIp);
      if (rec.ip) this._map.delete(rec.ip);
      logger.info(`[AIOps Quarantine] Đã gỡ chặn IP ${rec.maskedIp} (Hash: ${rec.hash}) qua hash`);
      unblocked = true;
    }

    // 3. Kiểm tra và xóa trong _map
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
   * Lấy danh sách các cặp (IP, Tài khoản) đang bị quản lý cách ly
   */
  async revealFullIp(ipHash) {
    if (!ipHash) return null;
    for (const record of this._pairs.values()) {
      if (record.ipHash === ipHash && record.ip) return record.ip;
    }
    const legacy = this._byHash.get(ipHash);
    if (legacy && legacy.ip) return legacy.ip;
    if (this.repository && typeof this.repository.getIpByHash === 'function') {
      const row = await this.repository.getIpByHash(ipHash);
      if (row && row.raw_ip) return row.raw_ip;
    }
    return null;
  }

  getQuarantinedList() {
    const now = Date.now();
    const resultList = [];

    // Duyệt qua _pairs
    for (const [key, record] of this._pairs.entries()) {
      if (record.ipStatus === 'temporary' && record.ipExpiresAt !== null && now > record.ipExpiresAt) {
        record.ipStatus = 'unlocked';
        record.ipExpiresAt = null;
        if (this.repository && typeof this.repository.updateIpStatus === 'function') {
          this.repository.updateIpStatus({ ipHash: record.ipHash, status: 'UNLOCKED' }).catch(() => { });
        }
      }
      if (record.accountStatus === 'temporary' && record.accountExpiresAt !== null && now > record.accountExpiresAt) {
        record.accountStatus = 'unlocked';
        record.accountExpiresAt = null;
        if (this.repository && typeof this.repository.updateAccountStatus === 'function') {
          this.repository.updateAccountStatus({ username: record.username, idaccount: record.idaccount, status: 'UNLOCKED' }).catch(() => { });
        }
        this._syncAccountStatusToDatabase(record.idaccount || record.username, 'Active', null, { onlyAIOpsLocked: true, idaccount: record.idaccount, username: record.username }).catch(() => { });
      }

      // Thời gian còn lại cho IP: chỉ tính khi đang tạm khóa
      const ipRemainingMinutes = (record.ipStatus === 'temporary' && record.ipExpiresAt !== null)
        ? Math.max(0, Math.ceil((record.ipExpiresAt - now) / 60000))
        : null;

      // Thời gian còn lại cho Tài khoản: chỉ tính khi đang tạm khóa
      const accountRemainingMinutes = (record.accountStatus === 'temporary' && record.accountExpiresAt !== null)
        ? Math.max(0, Math.ceil((record.accountExpiresAt - now) / 60000))
        : null;

      const remainingMinutes = ipRemainingMinutes || accountRemainingMinutes || null;

      resultList.push({
        id: record.id,
        hash: record.ipHash, // tương thích ngược
        ipHash: record.ipHash,
        maskedIp: record.maskedIp,
        username: record.username || 'N/A',
        idaccount: record.idaccount,
        vector: record.vector || 'auth',
        ipStatus: record.ipStatus,
        accountStatus: record.accountStatus,
        reason: record.reason,
        bannedAt: record.bannedAt,
        ipExpiresAt: record.ipExpiresAt ? new Date(record.ipExpiresAt).toISOString() : null,
        accountExpiresAt: record.accountExpiresAt ? new Date(record.accountExpiresAt).toISOString() : null,
        ipRemainingMinutes,
        accountRemainingMinutes,
        expiresAt: (record.ipExpiresAt || record.accountExpiresAt) ? new Date(record.ipExpiresAt || record.accountExpiresAt).toISOString() : null,
        remainingMinutes,
        hits: record.hits,
      });
    }

    // Nếu _pairs rỗng nhưng có bản ghi trong _map/_byHash, fallback tương thích
    if (resultList.length === 0) {
      for (const [ip, rec] of this._map.entries()) {
        if (rec.expiresAt !== null && now > rec.expiresAt) {
          this._map.delete(ip);
          if (rec.hash) this._byHash.delete(rec.hash);
        } else {
          const remMin = rec.expiresAt ? Math.max(0, Math.ceil((rec.expiresAt - now) / 60000)) : null;
          resultList.push({
            id: rec.hash,
            hash: rec.hash,
            ipHash: rec.hash,
            maskedIp: rec.maskedIp,
            username: 'N/A',
            idaccount: null,
            ipStatus: 'temporary',
            accountStatus: 'temporary',
            reason: rec.reason,
            bannedAt: rec.bannedAt,
            ipExpiresAt: rec.expiresAt ? new Date(rec.expiresAt).toISOString() : null,
            accountExpiresAt: null,
            ipRemainingMinutes: remMin,
            accountRemainingMinutes: null,
            expiresAt: rec.expiresAt ? new Date(rec.expiresAt).toISOString() : null,
            remainingMinutes: remMin,
            hits: rec.hits,
          });
        }
      }
    }

    return resultList.sort((a, b) => new Date(b.bannedAt) - new Date(a.bannedAt));
  }

  _emitQuarantineEvents(record) {
    const io = this.getIO();
    if (!io) return;
    try {
      io.to('admin_room').emit('admin.security_blocked', {
        hash: record.ipHash,
        maskedIp: record.maskedIp,
        username: record.username,
        reason: record.reason,
        bannedAt: record.bannedAt,
        expiresAt: record.expiresAt ? new Date(record.expiresAt).toISOString() : null,
        hits: record.hits,
      });
    } catch (err) {
      logger.error('[AIOps Quarantine] Lỗi phát socket quarantine events', { error: err.message });
    }
  }

  _emitUpdatedEvent() {
    const io = this.getIO();
    if (!io) return;
    try {
      io.to('admin_room').emit('admin.quarantine_updated', {
        timestamp: new Date().toISOString(),
      });
    } catch (_) { }
  }

  /**
   * Express Middleware chặn đứng request từ IP bị cô lập với mã HTTP 403
   */
  createMiddleware() {
    return (req, res, next) => {
      // Không miễn trừ admin: IP đang khoá thì chặn mọi request (mục 2.5 kế hoạch sửa trang AIOps).
      // Ngoại lệ duy nhất: tài khoản quản trị gốc (token hợp lệ, hoặc request đăng nhập bằng tên tài khoản gốc).
      const rootAdmin = require('../auth/root-admin');
      if (rootAdmin.isRootTokenRequest(req) || rootAdmin.isRootLoginRequest(req)) {
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
          quarantineExpiresAt: check.expiresAt ? new Date(check.expiresAt).toISOString() : null,
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
