const os = require('os');
const crypto = require('crypto');

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
  }

  /**
   * Tạo chuỗi băm 16 ký tự an toàn từ IP client để đếm số lượng IP duy nhất mà không lưu PII
   */
  _hashIp(ip) {
    if (!ip) return '0000000000000000';
    return crypto.createHash('sha256').update(`${this._salt}:${ip}`).digest('hex').substring(0, 16);
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

      // Thu thập IP an toàn
      const clientIp = req.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || req.socket?.remoteAddress;
      if (clientIp) {
        this._ipHashes.add(this._hashIp(clientIp));

        // Theo dõi hành vi từng IP trong window 10s
        let ipStat = this._ipStats.get(clientIp);
        if (!ipStat) {
          ipStat = { count: 0, malformed: 0, failedLogins: 0 };
          this._ipStats.set(clientIp, ipStat);
        }
        ipStat.count += 1;

        // Heuristic 1: Phát hiện DoS Request Burst từ 1 nguồn đơn lẻ (> 120 req trong 10s)
        if (ipStat.count > 120 && !req.isAdmin && (!req.originalUrl || !req.originalUrl.startsWith('/api/admin'))) {
          defaultAIOpsQuarantine.quarantine(
            clientIp,
            `Tấn công DoS Request Burst dồn dập (${ipStat.count} req/10s)`,
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
            // Heuristic 2: Phát hiện rà quét lỗ hổng SQLi / Path Traversal lặp lại
            if (ipStat.malformed >= 3 && !req.isAdmin) {
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
          const path = (req.path || '').toLowerCase();
          if (status === 401 && path.includes('/login')) {
            this.recordFailedLogin();
            if (clientIp) {
              const ipStat = this._ipStats.get(clientIp);
              if (ipStat) {
                ipStat.failedLogins += 1;
                // Heuristic 3: Phát hiện tấn công dò mật khẩu (Brute-force) từ 1 IP
                if (ipStat.failedLogins >= 5 && !req.isAdmin) {
                  defaultAIOpsQuarantine.quarantine(
                    clientIp,
                    `Tấn công dò mật khẩu Brute-Force (${ipStat.failedLogins} lần đăng nhập sai)`,
                    15 * 60 * 1000
                  );
                }
              }
            }
          } else if (status === 401 && path.includes('/refresh')) {
            this.recordTokenReuse();
            if (clientIp && !req.isAdmin) {
              // Heuristic 4: Phát hiện sử dụng token đã thu hồi (Token Hijacking)
              defaultAIOpsQuarantine.quarantine(
                clientIp,
                'Phát hiện tái sử dụng Token đã thu hồi (Token Hijacking Attack)',
                15 * 60 * 1000
              );
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
      const total = os.totalmem();
      const free = os.freemem();
      if (total <= 0) return 0;
      return Math.round(((total - free) / total) * 100);
    } catch (_) {
      return 0;
    }
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

    const sample = {
      timestamp: new Date().toISOString(),
      requestsPerMin,
      errorRate4xx,
      errorRate5xx,
      failedLogins: this._failedLogins,
      tokenReuseAttacks: this._tokenReuseAttacks,
      malformedRequests: this._malformedRequests,
      eventLoopLagMs: this._getEventLoopLag(),
      cpuPercent: this._getCpuPercent(),
      ramPercent: this._getRamPercent(),
      dbPoolActive: this._getDbPoolActive(),
      loadSheddingCount: this._getLoadSheddingCount(),
      distinctIpsCount: this._ipHashes.size,
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
