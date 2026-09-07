const logger = require('../core/logger');
const ResponseHandler = require('../core/response-handler');

function errorHandler(err, req, res, _next) {
  logger.error('Unhandled error', {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  if (err.name === 'ValidationError') {
    return ResponseHandler.badRequest(res, err.message, err.errors);
  }

  if (err.name === 'PrismaClientKnownRequestError') {
    if (err.code === 'P2002') {
      return ResponseHandler.badRequest(res, 'Duplicate entry', err.meta);
    }
    if (err.code === 'P2025') {
      return ResponseHandler.notFound(res, 'Record not found');
    }
  }

  const statusCode = err.statusCode || (typeof err.status === 'number' ? err.status : 500);
  const errorCode = err.errorCode || err.code || undefined;
  const message = (process.env.NODE_ENV === 'production' && statusCode === 500 && !err.errorCode)
    ? 'Internal Server Error'
    : err.message;

  return res.status(statusCode).json({
    success: false,
    statusCode,
    code: errorCode,
    message,
    ...(err.data ? { data: err.data } : {}),
    timestamp: new Date().toISOString(),
  });
}

module.exports = errorHandler;
