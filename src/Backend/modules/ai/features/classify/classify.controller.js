/**
 * F012 — Transaction Classifier — Controller
 * POST /api/ai/classify
 * Nhận { transactionId } → enqueue job → 202 Accepted
 */

const classifyService = require('./classify.service');
const logger = require('../../../../core/logger');

const classifyController = {
  async handleClassify(transactionId) {
    logger.info('Classify request received', { transactionId });
    const result = await classifyService.requestClassify(transactionId);
    return result;
  },
};

module.exports = classifyController;
