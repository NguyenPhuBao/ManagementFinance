const Redis = require('ioredis');
const logger = require('../core/logger');

const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: null,
  retryStrategy(times) {
    if (times > 10) return null;
    return Math.min(times * 200, 2000);
  },
  lazyConnect: true,
});

redis.on('connect', () => {
  logger.info('Redis connected');
});

redis.on('error', (err) => {
  logger.error('Redis error', { error: err.message });
});

async function verifyRedisConnection() {
  try {
    await redis.connect();
    const pong = await redis.ping();
    logger.info('Redis ping', { response: pong });
    return true;
  } catch (error) {
    logger.warn('Redis unavailable — continuing without cache/queue', { error: error.message });
    return false;
  }
}

module.exports = { redis, verifyRedisConnection };
