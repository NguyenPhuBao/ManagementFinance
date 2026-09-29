/**
 * Notification Worker — Lắng nghe BullMQ queue 'send-notification' và xử lý background jobs
 */

const { Worker } = require('bullmq');
const logger = require('../core/logger');
const defaultEmailService = require('../core/email.service');
const defaultSocket = require('../core/socket');

/**
 * Xử lý từng job cụ thể (Core processor — độc lập, dễ kiểm thử)
 */
async function processNotificationJob(job, dependencies = {}) {
  const emailService = dependencies.emailService || defaultEmailService;
  const socket = dependencies.socket || defaultSocket;

  logger.info(`[Notification Worker] Processing job: ${job.name}`, { jobId: job.id });

  switch (job.name) {
    case 'send-email': {
      const { to, payload, type } = job.data || {};
      if (!to || typeof to !== 'string' || !to.trim()) {
        throw new Error('Email recipient is required');
      }

      await emailService.sendSecurityAlert(to, {
        title: payload?.title || 'Cảnh báo bảo mật',
        message: payload?.message || '',
        time: payload?.time,
        type,
      });

      logger.info(`[Notification Worker] Email sent successfully to ${to}`, { jobId: job.id });
      return { success: true, jobId: job.id, to };
    }

    case 'send-socket': {
      const { idaccount, payload } = job.data || {};
      if (idaccount && socket && typeof socket.emitBankTransaction === 'function') {
        socket.emitBankTransaction(idaccount, payload);
      }
      logger.info(`[Notification Worker] Socket dispatched to account ${idaccount}`, { jobId: job.id });
      return { success: true, jobId: job.id, idaccount };
    }

    default: {
      logger.warn(`[Notification Worker] Unknown job name: ${job.name}`, { jobId: job.id });
      return { success: false, reason: 'UNKNOWN_JOB_NAME' };
    }
  }
}

/**
 * Factory khởi tạo BullMQ Worker
 */
function createNotificationWorker(connection) {
  const worker = new Worker(
    'send-notification',
    async (job) => {
      return await processNotificationJob(job);
    },
    {
      connection,
      concurrency: 5,
      limiter: {
        max: 30,
        duration: 60000,
      },
    }
  );

  worker.on('completed', (job) => {
    logger.debug(`[Notification Worker] Job ${job.id} completed`);
  });

  worker.on('failed', (job, err) => {
    logger.error(`[Notification Worker] Job ${job?.id} failed`, { error: err.message });
  });

  logger.info('Notification Worker started — listening on queue: send-notification');
  return worker;
}

let notificationWorker = null;

// Chỉ khởi tạo worker tự động khi chạy thực tế (không phải môi trường test)
const isTestEnv = process.env.NODE_ENV === 'test' || process.argv.some((arg) => arg.includes('test'));
if (!isTestEnv) {
  try {
    const { connection } = require('../core/queue');
    notificationWorker = createNotificationWorker(connection);
  } catch (error) {
    logger.warn('[Notification Worker] Could not auto-start worker (Redis not available)', {
      error: error.message,
    });
  }
}


module.exports = {
  processNotificationJob,
  createNotificationWorker,
  get notificationWorker() {
    return notificationWorker;
  },
};
