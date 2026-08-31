require('dotenv').config();
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
    if (!redisOk) {
      logger.warn('Redis unavailable — running without cache/queues');
    } else {
      // 2b. Start workers (BullMQ) — chỉ khi Redis available
      logger.info('Starting AI Worker...');
      require('./workers/ai.worker');
      
      logger.info('Starting Bank Worker...');
      require('./workers/bank.worker');
    }

    // 3. Create HTTP Server & Initialize Socket.io
    const httpServer = http.createServer(app);
    initSocket(httpServer);

    // 3b. Initialize Notification Service Listeners
    const notificationService = require('./modules/notification/notification.service');
    await notificationService.initNotificationListeners();

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
  const { prisma } = require('./config/db');
  const { redis } = require('./config/redis');
  await prisma.$disconnect();
  await redis.quit();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down...');
  const { prisma } = require('./config/db');
  const { redis } = require('./config/redis');
  await prisma.$disconnect();
  await redis.quit();
  process.exit(0);
});

bootstrap();
