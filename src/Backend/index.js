// Thiết lập múi giờ chuẩn Việt Nam (GMT+7) cho toàn bộ Node.js runtime trên Cloud Server
process.env.TZ = process.env.TZ || 'Asia/Ho_Chi_Minh';
require('dotenv').config();
const { setupProcessSafety } = require('./core/resilience/process-safety');

// 0. Bẫy lỗi toàn cục chống sập dây chuyền (SPOF Trap: uncaughtException & unhandledRejection)
setupProcessSafety();

const http = require('http');
const app = require('./app');
const config = require('./config');
const logger = require('./core/logger');
const { verifyConnection } = require('./config/db');
const { verifyRedisConnection } = require('./config/redis');
const { initSocket } = require('./core/socket');

async function bootstrap() {
  try {
    // 1. Tạo HTTP Server & Initialize Socket.io
    const httpServer = http.createServer(app);
    initSocket(httpServer);

    // 2. Mở cổng HTTP Server NGAY LẬP TỨC để Render / Cloud Port Scanner phát hiện thành công trong < 100ms
    const port = config.port;
    const host = config.host || '0.0.0.0';
    await new Promise((resolve, reject) => {
      httpServer.listen(port, host, () => {
        logger.info(`WealthCommand Backend running at http://${host}:${port}`);
        logger.info(`Environment: ${config.env}`);
        logger.info(`Database: PersonFinance @ PostgreSQL`);
        logger.info(`Health check: http://${host}:${port}/health`);
        resolve();
      });
      httpServer.on('error', reject);
    });

    // 3. Kết nối PostgreSQL (Supabase) bất đồng bộ và kiểm tra kết nối
    logger.info('Connecting to PostgreSQL...');
    verifyConnection()
      .then(() => logger.info('PostgreSQL connected successfully'))
      .catch((err) => logger.error('PostgreSQL connection failed at startup', { error: err.message }));

    // 4. Kết nối Redis (non-blocking) và khởi động Worker nếu khả dụng
    logger.info('Connecting to Redis...');
    verifyRedisConnection()
      .then((redisOk) => {
        if (redisOk) {
          logger.info('Starting AI Worker...');
          require('./workers/ai.worker');

          logger.info('Starting Notification Worker...');
          require('./workers/notification.worker');
        } else {
          logger.warn('Redis unavailable — running without cache/queues');
        }
      })
      .catch((err) => logger.warn('Redis check failed', { error: err.message }));

    // 5. Initialize Notification Service Listeners
    const notificationService = require('./modules/notification/notification.service');
    notificationService.initNotificationListeners().catch((err) => logger.warn('Notification listeners init error', { error: err.message }));

    // 6. Initialize Scheduler Service (Daily Countdown at 0h00 UTC+7)
    const { initScheduler } = require('./core/scheduler.service');
    initScheduler();

    // 7. Start AIOps Sentinel Machine Learning Monitoring Engine (10s cycle)
    const { defaultAIOpsService } = require('./modules/aiops/aiops.service');
    defaultAIOpsService.start();

    // 7b. Khởi tạo 3 bảng CSDL và Hydrate dữ liệu phong tỏa còn hiệu lực vào RAM Cache (Zero-loss on restart)
    const { defaultAIOpsQuarantine } = require('./modules/aiops/aiops.quarantine');
    const { defaultAIOpsQuarantineRepository } = require('./modules/aiops/aiops.quarantine.repository');
    defaultAIOpsQuarantineRepository.initTables()
      .then(() => defaultAIOpsQuarantine.hydrateFromDatabase())
      .catch((err) => logger.warn('[AIOps] Không thể nạp phong tỏa từ DB:', err.message));

    // 8. Khởi động System Metrics Streamer (3s/lần) phát nhịp tim tới admin_room
    const { emitSystemMetricsStream } = require('./core/socket');
    const { defaultEventLoopMonitor } = require('./core/resilience/event-loop-monitor');
    const { defaultDbBulkhead } = require('./core/resilience/db-bulkhead');
    const { defaultMaintenanceManager } = require('./core/resilience/maintenance.manager');
    const { defaultSystemHardwareMonitor } = require('./core/resilience/system-hardware-monitor');
    const { defaultMaintenanceRepository } = require('./modules/admin/maintenance.repository');
    defaultMaintenanceRepository.initTable().catch(() => {});
    const os = require('os');

    const metricsInterval = setInterval(() => {
      try {
        const aiopsStatus = defaultAIOpsService.getStatus() || {};
        const lastSample = aiopsStatus.sample || {};
        const uptimeSec = Math.floor(process.uptime());

        const hwMetrics = defaultSystemHardwareMonitor.getMetrics();
        const memRssMb = hwMetrics.ram.rssMb;
        const totalMemMb = hwMetrics.ram.totalMb;
        const usedMemMb = hwMetrics.ram.usedMb;
        const freeMemMb = hwMetrics.ram.freeMb;
        const usedMemPct = hwMetrics.ram.percent;
        const cpuPct = hwMetrics.cpu.percent;

        const payload = {
          uptimeSeconds: uptimeSec,
          uptimeFormatted: `${Math.floor(uptimeSec / 86400)}d ${Math.floor((uptimeSec % 86400) / 3600)}h ${Math.floor((uptimeSec % 3600) / 60)}m ${uptimeSec % 60}s`,
          eventLoopLagMs: defaultEventLoopMonitor.getLag(),
          cpuPercent: cpuPct,
          cpuCores: hwMetrics.cpu.cores,
          ramPercent: usedMemPct,
          ramUsedMb: usedMemMb,
          ramTotalMb: totalMemMb,
          ramFreeMb: freeMemMb,
          ramRssMb: memRssMb,
          requestsPerMin: lastSample.requestsPerMin || 0,
          threatScore: aiopsStatus.threatScore ?? 5,
          threatStatus: aiopsStatus.status || 'NORMAL',
          vectorScores: aiopsStatus.vectorScores || { auth: 0, traffic: 0, exploit: 0, resource: 0 },
          vectorDefenses: aiopsStatus.vectorDefenses || {},
          vectorConfig: aiopsStatus.vectorConfig || defaultAIOpsService.getVectorConfig() || {},
          recommendedAction: aiopsStatus.recommendedAction || null,
          targetConcurrency: aiopsStatus.targetConcurrency || 1000,
          activeQuarantines: aiopsStatus.quarantinedCount || 0,
          maintenance: defaultMaintenanceManager.getStatus(),
          dbPool: defaultDbBulkhead.getStats(),
          timestamp: new Date().toISOString(),
        };

        emitSystemMetricsStream(payload);
      } catch (err) {
        // Silent catch for stream stability
      }
    }, 3000);
    metricsInterval.unref();
  } catch (error) {
    logger.error('Failed to bootstrap application', { error: error.message });
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  logger.info('Shutting down gracefully...');
  const { defaultAIOpsService } = require('./modules/aiops/aiops.service');
  defaultAIOpsService.stop();
  const { prisma } = require('./config/db');
  const { redis } = require('./config/redis');
  await prisma.$disconnect();
  await redis.quit();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down...');
  const { defaultAIOpsService } = require('./modules/aiops/aiops.service');
  defaultAIOpsService.stop();
  const { prisma } = require('./config/db');
  const { redis } = require('./config/redis');
  await prisma.$disconnect();
  await redis.quit();
  process.exit(0);
});

bootstrap();
