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
    // 1. Verify PostgreSQL connection
    logger.info('Connecting to PostgreSQL...');
    await verifyConnection();

    // 2. Verify Redis connection (non-blocking)
    logger.info('Connecting to Redis...');
    const redisOk = await verifyRedisConnection();
    if (redisOk) {
      // 2b. Start workers (BullMQ) — chỉ khi Redis available
      logger.info('Starting AI Worker...');
      require('./workers/ai.worker');

      logger.info('Starting Notification Worker...');
      require('./workers/notification.worker');
    } else {
      logger.warn('Redis unavailable — running without cache/queues');
    }


    // 3. Create HTTP Server & Initialize Socket.io
    const httpServer = http.createServer(app);
    initSocket(httpServer);

    // 3b. Initialize Notification Service Listeners
    const notificationService = require('./modules/notification/notification.service');
    await notificationService.initNotificationListeners();

    // 3c. Initialize Scheduler Service (Daily Countdown at 0h00 UTC+7)
    const { initScheduler } = require('./core/scheduler.service');
    initScheduler();

    // 3d. Start AIOps Sentinel Machine Learning Monitoring Engine (10s cycle)
    const { defaultAIOpsService } = require('./modules/aiops/aiops.service');
    defaultAIOpsService.start();

    // 3e. Khởi động System Metrics Streamer (3s/lần) phát nhịp tim tới admin_room
    const { emitSystemMetricsStream } = require('./core/socket');
    const { defaultEventLoopMonitor } = require('./core/resilience/event-loop-monitor');
    const { defaultDbBulkhead } = require('./core/resilience/db-bulkhead');
    const { defaultMaintenanceManager } = require('./core/resilience/maintenance.manager');
    const os = require('os');

    const metricsInterval = setInterval(() => {
      try {
        const aiopsStatus = defaultAIOpsService.getStatus() || {};
        const lastSample = aiopsStatus.sample || {};
        const uptimeSec = Math.floor(process.uptime());

        const memRssMb = Math.round(process.memoryUsage().rss / 1024 / 1024);
        const totalMemMb = Math.round(os.totalmem() / 1024 / 1024);
        const freeMemMb = Math.round(os.freemem() / 1024 / 1024);
        const usedMemPct = Math.round(((totalMemMb - freeMemMb) / totalMemMb) * 100);

        const payload = {
          uptimeSeconds: uptimeSec,
          uptimeFormatted: `${Math.floor(uptimeSec / 86400)}d ${Math.floor((uptimeSec % 86400) / 3600)}h ${Math.floor((uptimeSec % 3600) / 60)}m ${uptimeSec % 60}s`,
          eventLoopLagMs: defaultEventLoopMonitor.getLag(),
          cpuPercent: lastSample.cpuPercent || 0,
          ramPercent: usedMemPct,
          ramRssMb: memRssMb,
          requestsPerMin: lastSample.requestsPerMin || 0,
          threatScore: aiopsStatus.threatScore ?? 5,
          threatStatus: aiopsStatus.status || 'NORMAL',
          vectorScores: aiopsStatus.vectorScores || { auth: 0, traffic: 0, exploit: 0, resource: 0 },
          vectorDefenses: aiopsStatus.vectorDefenses || {},
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

    // 4. Start listening
    httpServer.listen(config.port, config.host, () => {
      logger.info(`WealthCommand Backend running at http://${config.host}:${config.port}`);
      logger.info(`Environment: ${config.env}`);
      logger.info(`Database: PersonFinance @ PostgreSQL`);
      logger.info(`Health check: http://localhost:${config.port}/health`);
    });
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
