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

    // 1b. Khoá người dùng cho tới khi đọc được trạng thái bảo trì từ CSDL (fail-closed).
    require('./core/resilience/maintenance.manager').defaultMaintenanceManager.beginRestore();

    // 2. Mở cổng HTTP Server NGAY LẬP TỨC để Render / Cloud Port Scanner phát hiện thành công trong < 100ms
    const port = config.port;
    const host = config.host || '0.0.0.0';
    await new Promise((resolve, reject) => {
      httpServer.listen(port, host, () => {
        logger.info(`WealthCommand Backend running at http://${host}:${port}`);
        logger.info(`Environment: ${config.env}`);
        logger.info(`Database: PersonFinance @ PostgreSQL`);
        logger.info(`Health check: http://${host}:${port}/health`);
        logger.info(`Backend running at https://managementfinance.onrender.com (Internal port: ${port})`);
        logger.info(`Health check: https://managementfinance.onrender.com/health`);
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

    // 7. AIOps (tạm dừng mặc định, bật bằng AIOPS_ENABLED=true): vòng đo 10 giây chỉ chạy khi bật.
    //    Khi tắt vẫn nạp danh sách phong toả để bộ quét hết hạn mở các tài khoản đang bị khoá tạm.
    const { isAiopsEnabled, startAiops } = require('./modules/aiops/aiops.toggle');
    const { defaultAIOpsService } = require('./modules/aiops/aiops.service');
    const { defaultAIOpsQuarantine } = require('./modules/aiops/aiops.quarantine');
    const { defaultAIOpsQuarantineRepository } = require('./modules/aiops/aiops.quarantine.repository');
    logger.info(`[AIOps] ${isAiopsEnabled() ? 'Đang bật' : 'Tạm dừng (AIOPS_ENABLED khác true)'}`);
    startAiops({ service: defaultAIOpsService, quarantine: defaultAIOpsQuarantine, repository: defaultAIOpsQuarantineRepository })
      .catch((err) => logger.warn('[AIOps] Không thể nạp phong tỏa từ DB:', err.message));

    // 8. Khởi động System Metrics Streamer (3s/lần) phát nhịp tim tới admin_room
    const { emitSystemMetricsStream } = require('./core/socket');
    const { defaultEventLoopMonitor } = require('./core/resilience/event-loop-monitor');
    const { defaultDbBulkhead } = require('./core/resilience/db-bulkhead');
    const { defaultMaintenanceManager } = require('./core/resilience/maintenance.manager');
    const { defaultSystemHardwareMonitor } = require('./core/resilience/system-hardware-monitor');
    const { defaultMaintenanceRepository } = require('./modules/admin/maintenance.repository');
    // Ghi phiên chạy (server_session) để tính độ khả dụng theo kỳ, bền vững qua khởi động lại.
    require('./core/resilience/server-session').getDefaultServerSession().start();

    // CSDL là nguồn sự thật: khôi phục phiên bảo trì / lịch hẹn, thử lại tới khi đọc được.
    defaultMaintenanceRepository.initTable()
      .catch(() => {})
      .then(() => defaultMaintenanceManager.startRestoreLoop());
    const os = require('os');

    const metricsInterval = setInterval(async () => {
      try {
        // Tự động kiểm tra và bù dữ liệu Outbox nếu CSDL đã phục hồi
        if (typeof defaultMaintenanceRepository.hasPendingSync === 'function' && defaultMaintenanceRepository.hasPendingSync()) {
          defaultMaintenanceRepository.flushPendingQueue().catch(() => {});
        }
        const aiopsStatus = (isAiopsEnabled() && defaultAIOpsService.getStatus()) || {};
        const lastSample = aiopsStatus.sample || {};
        // Chạy liên tục (không trừ bảo trì) + độ khả dụng tháng hiện tại (đệm 60 giây, không truy vấn CSDL mỗi 3 giây)
        const uptime = await require('./modules/admin/admin.service').buildUptimeInfo();

        const hwMetrics = defaultSystemHardwareMonitor.getMetrics();
        const memRssMb = hwMetrics.ram.rssMb;
        const totalMemMb = hwMetrics.ram.totalMb;
        const usedMemMb = hwMetrics.ram.usedMb;
        const freeMemMb = hwMetrics.ram.freeMb;
        const usedMemPct = hwMetrics.ram.percent;
        const cpuPct = hwMetrics.cpu.percent;

        const payload = {
          runningSeconds: uptime.runningSeconds,
          runningFormatted: uptime.runningFormatted,
          version: uptime.version,
          availability: uptime.availability,
          // Khoá cũ, nghĩa mới (gỡ ở đợt sau): chạy liên tục / độ khả dụng tháng
          uptimeSeconds: uptime.uptimeSeconds,
          totalSeconds: uptime.totalSeconds,
          rawUptimeSeconds: uptime.rawUptimeSeconds,
          uptimePercent: uptime.uptimePercent,
          uptimeFormatted: uptime.uptimeFormatted,
          downtimeSeconds: uptime.downtimeSeconds,
          startedAt: uptime.startedAt,
          eventLoopLagMs: defaultEventLoopMonitor.getLag(),
          cpuPercent: cpuPct,
          cpuCores: hwMetrics.cpu.cores,
          ramPercent: usedMemPct,
          ramUsedMb: usedMemMb,
          ramTotalMb: totalMemMb,
          ramFreeMb: freeMemMb,
          ramRssMb: memRssMb,
          requestsPerMin: lastSample.requestsPerMin || 0,
          threatScore: aiopsStatus.threatScore ?? 0,
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

// Đóng phiên chạy GRACEFUL (tắt có chủ đích), chặn tối đa 2 giây để không treo việc tắt máy.
async function closeServerSession() {
  try {
    const tracker = require('./core/resilience/server-session').getDefaultServerSession();
    await Promise.race([tracker.stop(), new Promise((r) => setTimeout(r, 2000))]);
  } catch (_) {}
}

// Graceful shutdown
process.on('SIGINT', async () => {
  logger.info('Shutting down gracefully...');
  await closeServerSession();
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
  await closeServerSession();
  const { defaultAIOpsService } = require('./modules/aiops/aiops.service');
  defaultAIOpsService.stop();
  const { prisma } = require('./config/db');
  const { redis } = require('./config/redis');
  await prisma.$disconnect();
  await redis.quit();
  process.exit(0);
});

bootstrap();
