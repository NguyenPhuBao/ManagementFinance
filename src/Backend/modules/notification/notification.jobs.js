/**
 * Notification Jobs — Helper đưa các tác vụ thông báo vào BullMQ Queue
 */

const logger = require('../../core/logger');

function getEnqueueHelper() {
  const { enqueue } = require('../../core/queue');
  return enqueue;
}

const notificationJobs = {
  /**
   * Đưa job gửi email vào hàng đợi send-notification
   * @param {Object} data
   * @param {string} data.to - Email người nhận
   * @param {string} data.type - Loại thông báo (SECURITY_ALERT, OTP, etc.)
   * @param {Object} data.payload - Dữ liệu chi tiết
   * @param {Object} opts - BullMQ options (delay, attempts, etc.)
   */
  async enqueueEmailNotification(data, opts = {}) {
    try {
      const enqueue = getEnqueueHelper();
      const job = await enqueue('sendNotification', 'send-email', data, {
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
        ...opts,
      });
      logger.info('Notification email job enqueued', { to: data.to, jobId: job.id });
      return job;
    } catch (error) {
      logger.error('Failed to enqueue email notification', { error: error.message });
      throw error;
    }
  },

  /**
   * Đưa job phát realtime socket trễ vào hàng đợi
   * @param {Object} data
   * @param {Object} opts
   */
  async enqueueSocketNotification(data, opts = {}) {
    try {
      const enqueue = getEnqueueHelper();
      const job = await enqueue('sendNotification', 'send-socket', data, opts);

      logger.info('Notification socket job enqueued', { jobId: job.id });
      return job;
    } catch (error) {
      logger.error('Failed to enqueue socket notification', { error: error.message });
      throw error;
    }
  },
};

module.exports = notificationJobs;
