const EventEmitter = require('events');
const { redis } = require('../config/redis');
const logger = require('./logger');

const EVENT_PREFIX = 'wealthcommand:events:';
const localBus = new EventEmitter();

let subRedis = null;

function getSubClient() {
  if (!subRedis && redis) {
    subRedis = redis.duplicate();
    subRedis.on('error', (err) => {
      logger.warn('EventBus SubClient error', { error: err.message });
    });
  }
  return subRedis;
}

const EventBus = {
  // Publish an event
  async publish(eventName, payload) {
    try {
      // 1. Emit locally ngay lập tức
      localBus.emit(eventName, payload);

      // 2. Publish to Redis nếu Redis sẵn sàng
      const channel = `${EVENT_PREFIX}${eventName}`;
      const message = JSON.stringify({
        event: eventName,
        payload,
        timestamp: new Date().toISOString(),
      });
      if (redis && (redis.status === 'ready' || redis.status === 'connect')) {
        await redis.publish(channel, message);
      }
      logger.debug(`Event published: ${eventName}`, { payload });
    } catch (error) {
      logger.error(`Failed to publish event: ${eventName}`, { error: error.message });
    }
  },

  // Subscribe to an event
  async subscribe(eventName, handler) {
    try {
      // 1. Subscribe local EventEmitter
      localBus.on(eventName, handler);

      // 2. Subscribe qua client riêng biệt (duplicate) nếu Redis kết nối
      const sub = getSubClient();
      if (sub && (sub.status === 'ready' || sub.status === 'connect')) {
        const channel = `${EVENT_PREFIX}${eventName}`;
        await sub.subscribe(channel);
        sub.on('message', (ch, message) => {
          if (ch === channel) {
            try {
              const data = JSON.parse(message);
              handler(data.payload || data);
            } catch (err) {
              logger.error(`Failed to handle event: ${eventName}`, { error: err.message });
            }
          }
        });
        logger.info(`Subscribed to event: ${eventName}`);
      }
    } catch (error) {
      logger.warn(`Failed to subscribe to event: ${eventName}`, { error: error.message });
    }
  },
};

module.exports = EventBus;

