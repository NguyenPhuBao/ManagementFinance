/**
 * Process Safety & Exception Trap
 * Bẫy lỗi toàn cục chống Single Point of Failure (SPOF) cho Node.js Runtime
 */

const defaultLogger = require('../logger');

function formatCrashReport(error, type = 'uncaughtException') {
  const err = error instanceof Error ? error : new Error(String(error));
  return {
    type,
    name: err.name || 'Error',
    message: err.message || 'Unknown error occurred',
    stack: err.stack || '',
    timestamp: new Date().toISOString(),
    pid: process.pid,
  };
}

function handleUncaughtException(error, options = {}) {
  const logger = options.logger || defaultLogger;
  const report = formatCrashReport(error, 'uncaughtException');

  logger.error('[CRITICAL] Uncaught Exception phát hiện — Nguy cơ SPOF', {
    name: report.name,
    message: report.message,
    stack: report.stack,
    timestamp: report.timestamp,
    pid: report.pid,
  });

  if (typeof options.onCrash === 'function') {
    options.onCrash(report);
  }

  const exitFn = options.exitFn || process.exit;
  // Cho phép thoát có kiểm soát để tránh tiến trình rơi vào trạng thái zombie
  exitFn(1);
}

function handleUnhandledRejection(reason, promise, options = {}) {
  const logger = options.logger || defaultLogger;
  const report = formatCrashReport(reason, 'unhandledRejection');

  logger.error('[PROCESS SAFETY] Unhandled Promise Rejection phát hiện', {
    name: report.name,
    message: report.message,
    stack: report.stack,
    timestamp: report.timestamp,
    pid: report.pid,
  });

  if (typeof options.onRejection === 'function') {
    options.onRejection(report);
  }
}

function setupProcessSafety(options = {}) {
  process.on('uncaughtException', (err) => {
    handleUncaughtException(err, options);
  });

  process.on('unhandledRejection', (reason, promise) => {
    handleUnhandledRejection(reason, promise, options);
  });
}

module.exports = {
  formatCrashReport,
  handleUncaughtException,
  handleUnhandledRejection,
  setupProcessSafety,
};
