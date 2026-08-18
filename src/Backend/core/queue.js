const { Queue, Worker } = require('bullmq');
const logger = require('./logger');

const Redis = require('ioredis');

const connection = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: null,
});
/**const connection = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT, 10) || 6379,
}; */
// Queue definitions
const queues = {
  aiClassify: new Queue('ai-classify-transaction', { connection }),
  ocrProcess: new Queue('ocr-process-receipt', { connection }),
  smsParse: new Queue('sms-parse', { connection }),
  sendNotification: new Queue('send-notification', { connection }),
  syncData: new Queue('sync-data', { connection }),
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

module.exports = { queues, enqueue, connection };
