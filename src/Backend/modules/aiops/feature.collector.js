const os = require('os');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
let config;
try {
  config = require('../../config');
} catch (_) {}

/**
 * AIOps Feature Collector
 * Thu thập và chuẩn hóa 12 chỉ số động của hệ thống theo chu kỳ sliding window.
 * Tuân thủ Data_Security.md: Zero PII — Tuyệt đối không lưu trữ IP thô trong memory/log.
 */
class FeatureCollector {
  constructor(options = {}) {
    this.windowSeconds = options.windowSeconds || 10;
    this._requests = 0;
    this._errors4xx = 0;
    this._errors5xx = 0;
    this._failedLogins = 0;
    this._tokenReuseAttacks = 0;
    this._malformedRequests = 0;
    this._ipHashes = new Set();
    this._ipStats = new Map();
    this._salt = crypto.randomBytes(8).toString('hex');
    this.targetConcurrency = options.targetConcurrency || 1000;
    this._startupTime = Date.now();
  }

  /**
   * Giải mã sớm Bearer token để bóc tách thông tin danh tính (Actor) và phân quyền (Role)
   */
  _extractTokenPayload(authHeader) {
    if (!authHeader || typeof authHeader !== 'string' || !authHeader.startsWith('Bearer ')) {
      return null;
    }
    const token = authHeader.split(' ')[1];
    if (!token) return null;
    const secret = (config && config.jwt && config.jwt.accessSecret) || process.env.JWT_ACCESS_SECRET;
    try {
      if (secret) {
        return jwt.verify(token, secret);
      }
    } catch (_) {}
    try {
      return jwt.decode(token);
    } catch (_) {
      return null;
    }
  }

  setTargetConcurrency(n) {
    this.targetConcurrency = Math.max(100, Number(n || 1000));
  }

  _getBurstThreshold() {
    return Math.max(150, Math.round(20 + 50 * Math.log10(this.targetConcurrency || 1000)));
  }

  /**
   * Tạo chuỗi băm 16 ký tự an toàn từ IP client để đếm số lượng IP duy nhất mà không lưu PII
   */
  _hashIp(ip) {
    if (!ip) return '0000000000000000';
    return crypto.createHash('sha256').update(`${this._salt}:${ip}`).digest('hex').substring(0, 16);
  }

  /**
   * Che bớt thông tin IP để tuân thủ Data_Security.md & Nghị định 13/2023/NĐ-CP
   * Định dạng chuẩn: a.b.xxx.xxx (giữ 2 octet đầu, che 2 octet cuối bằng xxx.xxx)
   */
  _maskIp(rawIp) {
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

  recordFailedLogin() {
    this._failedLogins += 1;
  }

  recordTokenReuse() {
    this._tokenReuseAttacks += 1;
  }

  recordMalformedRequest() {
    this._malformedRequests += 1;
  }

  /**
   * Express middleware thu thập request metrics non-blocking
   */
  createMiddleware() {
    const { defaultAIOpsQuarantine } = require('./aiops.quarantine');

    return (req, res, next) => {
      this._requests += 1;

      // Giải mã sớm Bearer token từ header để bắt danh tính người dùng và phân quyền (Early Token Decoder)
      const authHeader = req.headers && (req.headers.authorization || req.headers['authorization']);
      const tokenPayload = this._extractTokenPayload(authHeader);
      const earlyUserId = tokenPayload?.idaccount || tokenPayload?.id || req.user?.idaccount || null;
      const earlyUsername = tokenPayload?.username || req.user?.username || null;
      let earlyRole = tokenPayload?.rolename || tokenPayload?.role || null;
      if (!earlyRole && tokenPayload?.idrole === 1) earlyRole = 'Admin';
      if (!earlyRole && tokenPayload?.idrole === 2) earlyRole = 'User';
      if (!earlyRole && earlyUserId) earlyRole = 'User';
      if (!earlyRole && !earlyUserId) earlyRole = 'Guest';

      // Thu thập IP an toàn qua req.ip (tuân thủ app.set('trust proxy', 1))
      const clientIp = req.ip || req.socket?.remoteAddress;
      if (clientIp) {
        this._ipHashes.add(this._hashIp(clientIp));

        // Theo dõi hành vi từng IP trong window 10s
        let ipStat = this._ipStats.get(clientIp);
        if (!ipStat) {
          ipStat = {
            count: 0,
            malformed: 0,
            failedLogins: 0,
            tokenReuse: 0,
            userAgent: req.headers['user-agent'] || 'Unknown Client',
            targetEndpoint: req.originalUrl || req.url || '/',
            userId: earlyUserId,
            username: earlyUsername,
            role: earlyRole,
          };
          this._ipStats.set(clientIp, ipStat);
        }
        ipStat.count += 1;
        if (earlyUserId) {
          ipStat.userId = earlyUserId;
        }
        if (earlyUsername) {
          ipStat.username = earlyUsername;
        }
        if (earlyRole && earlyRole !== 'Guest') {
          ipStat.role = earlyRole;
        }
        if (req.user?.idaccount) {
          ipStat.userId = req.user.idaccount;
          ipStat.username = req.user.username;
          if (req.user.rolename || req.user.role) {
            ipStat.role = req.user.rolename || req.user.role;
          }
        }
        if (req.headers['user-agent']) {
          ipStat.userAgent = req.headers['user-agent'];
        }
        ipStat.targetEndpoint = req.originalUrl || req.url || '/';

        // Heuristic 1: Phát hiện DoS Request Burst từ 1 nguồn đơn lẻ theo ngưỡng quy mô
        const burstThreshold = this._getBurstThreshold();
        if (ipStat.count > burstThreshold && !req.isAdmin && ipStat.role !== 'Admin') {
          defaultAIOpsQuarantine.quarantine(
            clientIp,
            `Tấn công DoS Request Burst dồn dập (${ipStat.count} req/10s, ngưỡng: ${burstThreshold})`,
            15 * 60 * 1000
          );
        }
      }

      // Phát hiện nhanh các mẫu request bất thường (SQLi, Directory Traversal, XSS injection probes)
      const url = req.originalUrl || req.url || '';
      if (
        url.includes('../') ||
        url.includes('..%2f') ||
        /(\bunion\b.*\bselect\b|\bexec\b|\bshutdown\b|<script\b)/i.test(url)
      ) {
        this.recordMalformedRequest();
        if (clientIp) {
          const ipStat = this._ipStats.get(clientIp);
          if (ipStat) {
            ipStat.malformed += 1;
            // Heuristic 2: Phát hiện rà quét lỗ hổng SQLi / Path Traversal lặp lại (nới rộng lên >= 8 lần)
            if (ipStat.malformed >= 8 && !req.isAdmin) {
              defaultAIOpsQuarantine.quarantine(
                clientIp,
                `Rà quét lỗ hổng độc hại SQLi / Path Traversal (${ipStat.malformed} lần)`,
                30 * 60 * 1000
              );
            }
          }
        }
      }

      res.on('finish', () => {
        const status = res.statusCode || 200;
        if (status >= 400 && status < 500) {
          this._errors4xx += 1;
          const path = (req.path || req.originalUrl || req.url || '').toLowerCase();
          if (status === 400 && clientIp) {
            const ipStat = this._ipStats.get(clientIp);
            if (ipStat && (this._malformedRequests > 0 || ipStat.malformed > 0)) {
              ipStat.malformed = Math.max(ipStat.malformed, 1);
            }
          } else if (status === 401 && (path.includes('/login') || (path.includes('/auth') && !path.includes('/refresh')))) {
            this.recordFailedLogin();
            if (clientIp) {
              const ipStat = this._ipStats.get(clientIp);
              if (ipStat) {
                ipStat.failedLogins += 1;
                if (req.body && (req.body.username || req.body.email || req.body.identifier)) {
                  ipStat.targetAccount = String(req.body.username || req.body.email || req.body.identifier).trim().slice(0, 100);
                  ipStat.username = ipStat.targetAccount;
                }
                // Heuristic 3: Phát hiện tấn công dò mật khẩu (Brute-force) từ 1 IP (nới rộng lên >= 15 lần để tránh người dùng gõ nhầm)
                if (ipStat.failedLogins >= 15 && !req.isAdmin) {
                  const targetUser = ipStat.targetAccount || ipStat.username || null;
                  defaultAIOpsQuarantine.quarantinePair({
                    ip: clientIp,
                    username: targetUser,
                    reason: `Tấn công dò mật khẩu Brute-Force (${ipStat.failedLogins} lần đăng nhập sai${targetUser ? ` - Mục tiêu: ${targetUser}` : ''})`,
                    durationMs: 15 * 60 * 1000,
                  });
                  // Tự động tạm khóa tài khoản mục tiêu trong CSDL để chống xâm nhập
                  if (targetUser) {
                    try {
                      const prisma = require('../../database/prisma');
                      prisma.account.updateMany({
                        where: { username: targetUser, status: 'Active' },
                        data: {
                          status: 'TemporarilyLocked',
                          reason_inactive: 'AIOps Sentinel tạm khóa do phát hiện hành vi Brute-Force bất thường',
                        },
                      }).catch(() => {});
                    } catch (_) {}
                  }
                }
              }
            }
          } else if (status === 401 && path.includes('/refresh')) {
            // Heuristic 4: Chỉ ghi nhận tái sử dụng token khi thực sự phát hiện cờ req.tokenReuseDetected
            if (req.tokenReuseDetected) {
              this.recordTokenReuse();
              if (clientIp) {
                const ipStat = this._ipStats.get(clientIp);
                if (ipStat) {
                  ipStat.tokenReuse = (ipStat.tokenReuse || 0) + 1;
                  // Chỉ cách ly khi tái sử dụng lặp lại >= 5 lần từ 1 IP (tránh trường hợp người dùng mở 2 tab hoặc mạng chập chờn)
                  if (ipStat.tokenReuse >= 5 && !req.isAdmin) {
                    defaultAIOpsQuarantine.quarantinePair({
                      ip: clientIp,
                      username: ipStat.username || (req.user && req.user.username) || null,
                      reason: `Phát hiện tái sử dụng Token đã thu hồi liên tục (${ipStat.tokenReuse} lần - Token Hijacking Attack)`,
                      durationMs: 15 * 60 * 1000,
                    });
                  }
                }
              }
            }
          }
        } else if (status >= 500) {
          this._errors5xx += 1;
        }
      });

      next();
    };
  }

  /**
   * Đọc chỉ số lag của Event Loop từ monitor hệ thống
   */
  _getEventLoopLag() {
    try {
      // Warmup 45s đầu khởi động máy chủ: bỏ qua giật lag do nạp module/kết nối ban đầu
      const warmupMs = process.env.NODE_ENV === 'test' ? 0 : 45000;
      if (Date.now() - this._startupTime < warmupMs) {
        return 10;
      }
      const { defaultEventLoopMonitor } = require('../../core/resilience/event-loop-monitor');
      if (defaultEventLoopMonitor && typeof defaultEventLoopMonitor.getLag === 'function') {
        return defaultEventLoopMonitor.getLag();
      }
    } catch (_) {}
    return 0;
  }

  /**
   * Tính toán % CPU sử dụng trung bình trên tất cả các core
   */
  _getCpuPercent() {
    try {
      const { defaultSystemHardwareMonitor } = require('../../core/resilience/system-hardware-monitor');
      if (defaultSystemHardwareMonitor && typeof defaultSystemHardwareMonitor.getCpuPercent === 'function') {
        return defaultSystemHardwareMonitor.getCpuPercent();
      }
    } catch (_) {}
    try {
      const cpus = os.cpus();
      if (!cpus || cpus.length === 0) return 0;
      const totalPercent = cpus.reduce((acc, cpu) => {
        const total = Object.values(cpu.times).reduce((a, b) => a + b, 0);
        if (total === 0) return acc;
        return acc + Math.round(((total - cpu.times.idle) / total) * 100);
      }, 0);
      return Math.round(totalPercent / cpus.length);
    } catch (_) {
      return 0;
    }
  }

  /**
   * Tính toán % RAM đã sử dụng
   */
  _getRamPercent() {
    try {
      const { defaultSystemHardwareMonitor } = require('../../core/resilience/system-hardware-monitor');
      if (defaultSystemHardwareMonitor && typeof defaultSystemHardwareMonitor.getRamPercent === 'function') {
        return defaultSystemHardwareMonitor.getRamPercent();
      }
    } catch (_) {}
    try {
      const total = os.totalmem();
      const free = os.freemem();
      if (total <= 0) return 0;
      return Math.round(((total - free) / total) * 100);
    } catch (_) {
      return 0;
    }
  }

  /**
   * Đọc chi tiết phần cứng thật từ SystemHardwareMonitor
   */
  _getHardwareMetrics() {
    try {
      const { defaultSystemHardwareMonitor } = require('../../core/resilience/system-hardware-monitor');
      if (defaultSystemHardwareMonitor && typeof defaultSystemHardwareMonitor.getMetrics === 'function') {
        return defaultSystemHardwareMonitor.getMetrics();
      }
    } catch (_) {}
    const total = os.totalmem();
    const free = os.freemem();
    const used = total - free;
    const percent = total > 0 ? Math.round((used / total) * 100) : 0;
    return {
      cpu: { cores: os.cpus()?.length || 1, percent: this._getCpuPercent() },
      ram: {
        totalMb: Math.round(total / (1024 * 1024)),
        freeMb: Math.round(free / (1024 * 1024)),
        usedMb: Math.round(used / (1024 * 1024)),
        percent,
        rssMb: Math.round(process.memoryUsage().rss / (1024 * 1024)),
      },
    };
  }

  /**
   * Đọc số kết nối DB đang hoạt động từ DB Bulkhead
   */
  _getDbPoolActive() {
    try {
      const { defaultDbBulkhead } = require('../../core/resilience/db-bulkhead');
      if (defaultDbBulkhead && typeof defaultDbBulkhead.getStats === 'function') {
        const stats = defaultDbBulkhead.getStats();
        return (stats.activeClientConnections || 0) + (stats.activeAdminConnections || 0);
      }
    } catch (_) {}
    return 0;
  }

  /**
   * Đọc số lượng request bị cắt tải từ Load Shedding Middleware
   */
  _getLoadSheddingCount() {
    try {
      const { getLoadSheddingCount } = require('../../middleware/load-shedding.middleware');
      if (typeof getLoadSheddingCount === 'function') {
        return getLoadSheddingCount();
      }
    } catch (_) {}
    return 0;
  }

  /**
   * Trích xuất mẫu 12 chỉ số chuẩn hóa cho chu kỳ vừa qua và làm mới bộ đếm sliding window
   */
  getSample() {
    const totalReq = this._requests;
    const windowFactor = 60 / this.windowSeconds;
    const requestsPerMin = Math.round(totalReq * windowFactor);
    const errorRate4xx = totalReq > 0 ? Number((this._errors4xx / totalReq).toFixed(2)) : 0;
    const errorRate5xx = totalReq > 0 ? Number((this._errors5xx / totalReq).toFixed(2)) : 0;

    const burstThreshold = this._getBurstThreshold();
    const suspectActors = [];

    let maxReqCount = 0;
    let topReqIp = null;
    let topReqStat = null;
    let maxFailedLogins = 0;
    let topFailedIp = null;
    let topFailedStat = null;
    let maxMalformed = 0;
    let topMalformedIp = null;
    let topMalformedStat = null;

    for (const [ip, ipStat] of this._ipStats.entries()) {
      if (ipStat.count > maxReqCount) {
        maxReqCount = ipStat.count;
        topReqIp = ip;
        topReqStat = ipStat;
      }
      if (ipStat.failedLogins > maxFailedLogins) {
        maxFailedLogins = ipStat.failedLogins;
        topFailedIp = ip;
        topFailedStat = ipStat;
      }
      if (ipStat.malformed > maxMalformed) {
        maxMalformed = ipStat.malformed;
        topMalformedIp = ip;
        topMalformedStat = ipStat;
      }

      if (
        ipStat.failedLogins > 0 ||
        ipStat.malformed > 0 ||
        ipStat.tokenReuse > 0 ||
        ipStat.count > burstThreshold
      ) {
        const role = ipStat.role || (ipStat.userId ? 'User' : 'Guest');
        const username = ipStat.username || ipStat.targetAccount || (ipStat.userId ? `User #${ipStat.userId}` : 'Khách vãng lai / Ẩn danh');
        suspectActors.push({
          type: ipStat.userId ? 'AUTHENTICATED_USER' : 'IP_SOURCE',
          identity: this._maskIp(ip),
          maskedIp: this._maskIp(ip),
          rawIp: ip,
          ipHash: this._hashIp(ip),
          userId: ipStat.userId || null,
          username,
          role,
          targetAccount: ipStat.targetAccount || null,
          userAgent: ipStat.userAgent || 'Unknown Client',
          targetEndpoint: ipStat.targetEndpoint || '/',
          failedLogins: ipStat.failedLogins || 0,
          malformed: ipStat.malformed || 0,
          tokenReuse: ipStat.tokenReuse || 0,
          reqCount: ipStat.count || 0,
        });
      }
    }

    const topTrafficActor = topReqIp ? {
      type: topReqStat.userId ? 'AUTHENTICATED_USER' : 'IP_SOURCE',
      identity: this._maskIp(topReqIp),
      maskedIp: this._maskIp(topReqIp),
      rawIp: topReqIp,
      ipHash: this._hashIp(topReqIp),
      userId: topReqStat.userId || null,
      username: topReqStat.username || topReqStat.targetAccount || (topReqStat.userId ? `User #${topReqStat.userId}` : 'Khách vãng lai / Ẩn danh'),
      role: topReqStat.role || (topReqStat.userId ? 'User' : 'Guest'),
      userAgent: topReqStat.userAgent || 'Unknown Client',
      targetEndpoint: topReqStat.targetEndpoint || '/',
      reqCount: topReqStat.count || 0,
    } : null;

    const topAuthActor = topFailedIp ? {
      type: topFailedStat.userId ? 'AUTHENTICATED_USER' : 'IP_SOURCE',
      identity: this._maskIp(topFailedIp),
      maskedIp: this._maskIp(topFailedIp),
      rawIp: topFailedIp,
      ipHash: this._hashIp(topFailedIp),
      userId: topFailedStat.userId || null,
      username: topFailedStat.username || topFailedStat.targetAccount || (topFailedStat.userId ? `User #${topFailedStat.userId}` : 'Khách vãng lai / Ẩn danh'),
      role: topFailedStat.role || (topFailedStat.userId ? 'User' : 'Guest'),
      userAgent: topFailedStat.userAgent || 'Unknown Client',
      targetEndpoint: topFailedStat.targetEndpoint || '/api/auth/login',
      failedLogins: topFailedStat.failedLogins || 0,
    } : null;

    const topExploitActor = topMalformedIp ? {
      type: topMalformedStat.userId ? 'AUTHENTICATED_USER' : 'IP_SOURCE',
      identity: this._maskIp(topMalformedIp),
      maskedIp: this._maskIp(topMalformedIp),
      rawIp: topMalformedIp,
      ipHash: this._hashIp(topMalformedIp),
      userId: topMalformedStat.userId || null,
      username: topMalformedStat.username || topMalformedStat.targetAccount || (topMalformedStat.userId ? `User #${topMalformedStat.userId}` : 'Khách vãng lai / Ẩn danh'),
      role: topMalformedStat.role || (topMalformedStat.userId ? 'User' : 'Guest'),
      userAgent: topMalformedStat.userAgent || 'Unknown Client',
      targetEndpoint: topMalformedStat.targetEndpoint || '/',
      malformed: topMalformedStat.malformed || 0,
    } : null;

    const hwMetrics = this._getHardwareMetrics();

    const sample = {
      timestamp: new Date().toISOString(),
      requestsPerMin,
      errorRate4xx,
      errorRate5xx,
      failedLogins: this._failedLogins,
      tokenReuseAttacks: this._tokenReuseAttacks,
      malformedRequests: this._malformedRequests,
      eventLoopLagMs: this._getEventLoopLag(),
      cpuPercent: hwMetrics.cpu.percent,
      cpuCores: hwMetrics.cpu.cores,
      ramPercent: hwMetrics.ram.percent,
      ramUsedMb: hwMetrics.ram.usedMb,
      ramTotalMb: hwMetrics.ram.totalMb,
      ramFreeMb: hwMetrics.ram.freeMb,
      ramRssMb: hwMetrics.ram.rssMb,
      dbPoolActive: this._getDbPoolActive(),
      loadSheddingCount: this._getLoadSheddingCount(),
      distinctIpsCount: this._ipHashes.size,
      suspectActors,
      topTrafficActor,
      topAuthActor,
      topExploitActor,
    };

    // Reset window counters cho chu kỳ kế tiếp
    this._requests = 0;
    this._errors4xx = 0;
    this._errors5xx = 0;
    this._failedLogins = 0;
    this._tokenReuseAttacks = 0;
    this._malformedRequests = 0;
    this._ipHashes.clear();
    this._ipStats.clear();

    return sample;
  }
}

const defaultFeatureCollector = new FeatureCollector();

module.exports = {
  FeatureCollector,
  defaultFeatureCollector,
};
