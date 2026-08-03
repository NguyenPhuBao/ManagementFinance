const { redis } = require('../config/redis');
const logger = require('./logger');

const EVENT_PREFIX = 'wealthcommand:events:';

const EventBus = {
  // Publish an event
  async publish(eventName, payload) {
    try {
      const channel = `${EVENT_PREFIX}${eventName}`;
      const message = JSON.stringify({
        event: eventName,
        payload,
        timestamp: new Date().toISOString(),
      });
      await redis.publish(channel, message);
      logger.debug(`Event published: ${eventName}`, { payload });
    } catch (error) {
      logger.error(`Failed to publish event: ${eventName}`, { error: error.message });
    }
  },

  // Subscribe to an event
  async subscribe(eventName, handler) {
    try {
      const channel = `${EVENT_PREFIX}${eventName}`;
      await redis.subscribe(channel);
      redis.on('message', (ch, message) => {
        if (ch === channel) {
          try {
            const data = JSON.parse(message);
            handler(data);
          } catch (err) {
            logger.error(`Failed to handle event: ${eventName}`, { error: err.message });
          }
        }
      });
      logger.info(`Subscribed to event: ${eventName}`);
    } catch (error) {
      logger.warn(`Failed to subscribe to event: ${eventName}`, { error: error.message });
    }
  },
};

module.exports = EventBus;
