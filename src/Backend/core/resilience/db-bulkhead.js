/**
 * DB Bulkhead Pattern
 * Phân chia hạn ngạch kết nối Database Supabase giữa Client-app (80%) và Admin-web (20% Headroom)
 */

class DbBulkhead {
  constructor(options = {}) {
    this.maxConnections = options.maxConnections || 10;
    this.clientQuotaPercent = options.clientQuotaPercent || 80;

    // Tính toán trần kết nối cho Client
    this.clientLimit = Math.floor((this.maxConnections * this.clientQuotaPercent) / 100);
    this.adminReserved = this.maxConnections - this.clientLimit;

    this.activeClientConnections = 0;
    this.activeAdminConnections = 0;
  }

  canAcquire(role = 'client') {
    if (role === 'admin') {
      // Admin được phép dùng nếu tổng số kết nối đang hoạt động chưa vượt quá maxConnections
      return (this.activeClientConnections + this.activeAdminConnections) < this.maxConnections;
    }

    // Client chỉ được dùng nếu số client active chưa vượt clientLimit
    return this.activeClientConnections < this.clientLimit;
  }

  acquire(role = 'client') {
    if (!this.canAcquire(role)) {
      throw new Error(`DB_POOL_EXHAUSTED: Hạn ngạch kết nối CSDL cho vai trò '${role}' đã cạn kiệt!`);
    }

    if (role === 'admin') {
      this.activeAdminConnections += 1;
    } else {
      this.activeClientConnections += 1;
    }

    return true;
  }

  release(role = 'client') {
    if (role === 'admin') {
      this.activeAdminConnections = Math.max(0, this.activeAdminConnections - 1);
    } else {
      this.activeClientConnections = Math.max(0, this.activeClientConnections - 1);
    }
  }

  getStats() {
    return {
      maxConnections: this.maxConnections,
      clientLimit: this.clientLimit,
      adminReserved: this.adminReserved,
      activeClientConnections: this.activeClientConnections,
      activeAdminConnections: this.activeAdminConnections,
      availableClientSlots: Math.max(0, this.clientLimit - this.activeClientConnections),
      availableAdminSlots: Math.max(0, this.maxConnections - (this.activeClientConnections + this.activeAdminConnections)),
    };
  }
}

const defaultDbBulkhead = new DbBulkhead({
  maxConnections: parseInt(process.env.PG_POOL_MAX || '10', 10),
  clientQuotaPercent: 80,
});

function createDbBulkheadMiddleware(options = {}) {
  const bulkhead = options.bulkhead || defaultDbBulkhead;

  return function dbBulkheadMiddleware(req, res, next) {
    const url = req.originalUrl || req.path || '';
    if (req.method === 'OPTIONS' || url.startsWith('/health')) {
      return next();
    }

    const role = (req.isAdmin || url.startsWith('/api/admin')) ? 'admin' : 'client';

    if (!bulkhead.canAcquire(role)) {
      return res.status(503).json({
        success: false,
        statusCode: 503,
        code: 'DB_POOL_OVERLOADED',
        message: 'Hệ thống cơ sở dữ liệu đang phục vụ tối đa công suất. Vui lòng thử lại sau ít giây!',
        retryAfter: 3,
        timestamp: new Date().toISOString(),
      });
    }

    bulkhead.acquire(role);
    let released = false;
    const releaseOnce = () => {
      if (!released) {
        released = true;
        bulkhead.release(role);
      }
    };

    if (typeof res.on === 'function') {
      res.on('finish', releaseOnce);
      res.on('close', releaseOnce);
    }

    next();
  };
}

const defaultDbBulkheadMiddleware = createDbBulkheadMiddleware();

module.exports = {
  DbBulkhead,
  defaultDbBulkhead,
  createDbBulkheadMiddleware,
  defaultDbBulkheadMiddleware,
};
