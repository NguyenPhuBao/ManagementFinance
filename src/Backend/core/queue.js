const { Queue, Worker } = require('bullmq');
const logger = require('./logger');
const Redis = require('ioredis');
const { resolveRedisUrl } = require('../config/redis.resolver');

const redisUrl = resolveRedisUrl();
const connection = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
});

connection.on('connect', () => {
  logger.info(`[Redis Queue Connection] Connected to Redis [${process.env.REDIS_PROVIDER || 'default'}]`);
});

connection.on('error', (err) => {
  if (err?.message?.includes('max requests limit exceeded')) {
    logger.error('[Redis Queue Connection] Quota limit exceeded: Upstash commands limit reached.', {
      error: err.message,
    });
    // Chủ động ngắt kết nối tạm thời để tránh ioredis/BullMQ retry liên tục làm ngập log
    try {
      connection.disconnect(false);
    } catch (_) {}
  } else {
    logger.error('[Redis Queue Connection] Error', { error: err.message });
  }
});

// Queue definitions (4 queue — khớp Project.md 3.2.3)
const queues = {
  aiClassify: new Queue('ai-classify-transaction', { connection }),
  ocrProcess: new Queue('ocr-process-receipt', { connection }),
  sendNotification: new Queue('send-notification', { connection }),
  bankWebhook: new Queue('bank-webhook', { connection }),
};

// Helper: add job to a queue
async function enqueue(queueName, jobName, data, opts = {}) {
  try {
    const queue = queues[queueName];
    if (!queue) throw new Error(`Queue not found: ${queueName}`);
    const job = await queue.add(jobName, data, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 1000 },
      ...opts,
    });
    logger.debug(`Job enqueued: ${queueName}/${jobName}`, { jobId: job.id });
    return job;
  } catch (error) {
    logger.error(`Failed to enqueue job: ${queueName}/${jobName}`, { error: error.message });
    throw error;
  }
}

// Helper: get a queue instance by key (camelCase) or by queue name (kebab-case)
function getQueue(name) {
  if (!name) return null;
  if (queues[name]) return queues[name];
  return Object.values(queues).find((q) => q && q.name === name) || null;
}

module.exports = { queues, enqueue, getQueue, connection };
