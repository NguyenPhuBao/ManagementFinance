/**
 * F012 — Transaction Classifier — Service
 * classifyTransaction(description) → { categoryId, confidence } (future)
 * Hiện tại: Lấy description từ DB → enqueue BullMQ job
 */

const classifyRepository = require('./classify.repository');
const aiJobs = require('../../ai.jobs');
const logger = require('../../../../core/logger');

const classifyService = {
  async requestClassify(transactionId) {
    // 1. Kiểm tra transaction tồn tại + lấy description
    const tx = await classifyRepository.getTransactionById(transactionId);
    if (!tx) {
      throw Object.assign(new Error('Khong tim thay giao dich'), { statusCode: 404 });
    }

    // 2. Enqueue job vào BullMQ
    const job = await aiJobs.enqueueClassifyJob(transactionId, tx.description);

    // 3. Trả về 202 — job đã được tiếp nhận
    return {
      transactionId,
      jobId: job.id,
      status: 'queued',
      queuedAt: new Date().toISOString(),
    };
  },
};

module.exports = classifyService;
