/**
 * AI Worker — Lắng nghe BullMQ queue và xử lý job
 *
 * Queue: ai-classify-transaction
 * Queue: ocr-process-receipt (future)
 *
 * GĐ1 (hiện tại): Chạy chung process với Express.
 * Worker chỉ log job — chưa có model predict thật (sẽ làm ở Bước 3).
 *
 * GĐ2 (production): Tách ra process riêng, scale độc lập.
 */

const { Worker } = require('bullmq');
const logger = require('../core/logger');
const config = require('../config');
const { resolveRedisUrl } = require('../config/redis.resolver');
const Redis = require('ioredis');

const connection = new Redis(resolveRedisUrl(), {
  maxRetriesPerRequest: null,
});
/**const connection = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT, 10) || 6379,
}; */
const classifyWorker = new Worker(
  'ai-classify-transaction',
  async (job) => {
    const { transactionId, description } = job.data;
    logger.info('AI Worker: Processing classify job', { jobId: job.id, transactionId });

    // Bước 2+3 (future): Preprocess + Inference
    // const cleanText = preprocess(description);
    // const { categoryId, confidence } = await classifier.predict(cleanText);
    // await classifyRepository.updateTransactionCategory(transactionId, categoryId);
    // await EventBus.publish('transaction.classified', { transactionId, categoryId, confidence });

    logger.info('AI Worker: Classify job completed (shell mode — no model yet)', { jobId: job.id, transactionId });
  },
  {
    connection,
    concurrency: 5, // Xử lý tối đa 5 job đồng thời
    stalledInterval: config.queue?.stalledInterval || 300000,
    drainDelay: config.queue?.drainDelay || 5,
    lockDuration: config.queue?.lockDuration || 60000,
    limiter: {
      max: 20,       // Tối đa 20 job trong 1 phút (tránh quá tải Redis)
      duration: 60000,
    },
  }
);

classifyWorker.on('completed', (job) => {
  logger.debug('Classify job completed', { jobId: job.id, transactionId: job.data.transactionId });
});

classifyWorker.on('failed', (job, err) => {
  logger.error('Classify job failed', { jobId: job?.id, error: err.message });
});

classifyWorker.on('error', (err) => {
  if (err?.message?.includes('max requests limit exceeded')) {
    logger.error('[AI Worker] Redis Upstash quota limit exceeded (500k reached). Pausing worker to avoid loop.', {
      error: err.message,
    });
    try {
      classifyWorker.pause(true);
    } catch (_) {}
  } else {
    logger.error('[AI Worker] Worker connection error', { error: err.message });
  }
});

logger.info('AI Worker started — listening on queue: ai-classify-transaction');

module.exports = { classifyWorker };
