const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const config = require('./config');
const { generalLimiter } = require('./middleware/rate-limiter');
const auditLogMiddleware = require('./middleware/audit-log.middleware');
const errorHandler = require('./middleware/error-handler');
const apiRoutes = require('./api');
const logger = require('./core/logger');

const app = express();

// Trust reverse proxy (Render, Cloudflare, Nginx) for correct client IP
app.set('trust proxy', 1);

// Security
app.use(helmet());

// CORS
app.use(cors({
  origin: config.cors.origin,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-client-platform', 'x-emergency-admin-key'],
}));

// Parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging
if (config.env === 'development') {
  app.use(morgan('dev'));
}

// ─── AIOPS SENTINEL REAL-TIME METRIC STREAMING ───────────────────
const { defaultFeatureCollector } = require('./modules/aiops/feature.collector');
app.use(defaultFeatureCollector.createMiddleware());

// ─── RESILIENCE & ADMIN PRIORITY PIPELINE ───────────────────────
const { defaultAdminPriority } = require('./middleware/admin-priority.middleware');
const { defaultAIOpsQuarantine } = require('./modules/aiops/aiops.quarantine');
const { defaultMaintenance } = require('./middleware/maintenance.middleware');
const { defaultLoadShedding } = require('./middleware/load-shedding.middleware');
const { defaultRetryGuard } = require('./middleware/retry-guard.middleware');
const { defaultRequestTimeout } = require('./middleware/request-timeout.middleware');

// 1. Làn ưu tiên Admin-web (Fast-Lane Identification)
app.use(defaultAdminPriority);

// 1b. AIOps Active Quarantine Shield (Chặn đứng tức thì các IP tấn công/bất thường)
app.use(defaultAIOpsQuarantine.createMiddleware());

// 2. Kiểm tra chế độ bảo trì khẩn cấp (Chặn client, giữ admin thông suốt)
app.use(defaultMaintenance);

// 3. Cắt tải thông minh khi CPU/Event Loop quá tải (Chỉ shed client, giữ admin)
app.use(defaultLoadShedding);

// 4. Chống vòng lặp gọi lại vô tận / bão request (Retry Storm Protection)
app.use(defaultRetryGuard);

// 5. Khống chế thời gian thực thi tối đa (30s timeout giải phóng socket treo)
app.use(defaultRequestTimeout);

// Rate limiting
app.use('/api/', generalLimiter);

// Audit log middleware
app.use(auditLogMiddleware);

// Health check (no auth required)
app.get('/health', async (req, res) => {
  const { pool } = require('./config/db');
  try {
    const result = await pool.query('SELECT 1 AS ok');
    res.json({
      success: true,
      message: 'Server is healthy',
      database: 'connected',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(503).json({
      success: false,
      message: 'Database unavailable',
      timestamp: new Date().toISOString(),
    });
  }
});

// Admin Health & Resilience Monitor (Cửa sổ tra cứu sức khỏe máy chủ siêu nhẹ)
app.get('/health/admin', (req, res) => {
  const { defaultEventLoopMonitor } = require('./core/resilience/event-loop-monitor');
  const { defaultDbBulkhead } = require('./core/resilience/db-bulkhead');
  const { defaultMaintenanceManager } = require('./core/resilience/maintenance.manager');

  res.json({
    success: true,
    server: 'WealthCommand Backend',
    eventLoopLagMs: defaultEventLoopMonitor.getLag(),
    isOverloaded: defaultEventLoopMonitor.isOverloaded(),
    dbBulkhead: defaultDbBulkhead.getStats(),
    maintenance: defaultMaintenanceManager.getStatus(),
    timestamp: new Date().toISOString(),
  });
});

// DB Bulkhead Quota Protection (Bảo vệ 80% client / 20% admin headroom)
const { defaultDbBulkheadMiddleware } = require('./core/resilience/db-bulkhead');
app.use('/api', defaultDbBulkheadMiddleware);

// API routes
app.use('/api', apiRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.path}`,
    timestamp: new Date().toISOString(),
  });
});

// Global error handler
app.use(errorHandler);

module.exports = app;
