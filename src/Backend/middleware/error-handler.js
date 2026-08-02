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

  return ResponseHandler.error(res, process.env.NODE_ENV === 'production'
    ? 'Internal Server Error'
    : err.message
  );
}

module.exports = errorHandler;
