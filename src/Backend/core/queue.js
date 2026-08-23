const { Queue, Worker } = require('bullmq');
const logger = require('./logger');

const Redis = require('ioredis');

const connection = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
  maxRetriesPerRequest: null,
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
