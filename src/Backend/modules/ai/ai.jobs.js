/**
 * AI Module — Shared Jobs (BullMQ Enqueue Helpers)
 *
 * enqueueClassifyJob(transactionId, description)  → ai-classify-transaction
 * enqueueOCRJob(imageBuffer, userId)               → ocr-process-receipt (future)
 */

const { enqueue } = require('../../core/queue');
const logger = require('../../core/logger');

const aiJobs = {
  /**
   * Enqueue transaction classification job
   * @param {string} transactionId - UUID của transaction
   * @param {string} description - Mô tả giao dịch
   * @returns {Promise<Job>}
   */
  async enqueueClassifyJob(transactionId, description) {
    try {
      const job = await enqueue('aiClassify', 'classify-transaction', {
        transactionId,
        description,
        timestamp: new Date().toISOString(),
      });
      logger.info('AI classify job enqueued', { transactionId, jobId: job.id });
      return job;
    } catch (error) {
      logger.error('Failed to enqueue classify job', { transactionId, error: error.message });
      throw error;
    }
  },
};

module.exports = aiJobs;
