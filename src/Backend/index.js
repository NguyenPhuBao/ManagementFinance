require('dotenv').config();
const app = require('./app');
const config = require('./config');
const logger = require('./core/logger');
const { verifyConnection } = require('./config/db');
const { verifyRedisConnection } = require('./config/redis');

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
    }

    // 3. Start Express server
    app.listen(config.port, config.host, () => {
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
