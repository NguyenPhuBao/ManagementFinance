class ResponseHandler {
  static success(res, data = null, message = 'OK', statusCode = 200) {
    return res.status(statusCode).json({
      success: true,
      message,
      data,
      timestamp: new Date().toISOString(),
    });
  }

  static created(res, data = null, message = 'Created') {
    return this.success(res, data, message, 201);
  }

  static error(res, message = 'Internal Server Error', statusCode = 500, errors = null, code = null) {
    if (res.locals) {
      res.locals.errorMessage = message;
      if (errors) res.locals.errorDetails = errors;
    }
    const responsePayload = {
      success: false,
      message,
      errors,
      timestamp: new Date().toISOString(),
    };
    if (code) {
      responsePayload.code = code;
    } else if (errors && typeof errors === 'object' && errors.code) {
      responsePayload.code = errors.code;
    }
    return res.status(statusCode).json(responsePayload);
  }

  static badRequest(res, message = 'Bad Request', errors = null) {
    return this.error(res, message, 400, errors);
  }

  static unauthorized(res, message = 'Unauthorized', extra = null) {
    if (!extra) return this.error(res, message, 401);
    if (res.locals) res.locals.errorMessage = message;
    return res.status(401).json({
      success: false,
      message,
      ...extra,
      errors: null,
      timestamp: new Date().toISOString(),
    });
  }

  static forbidden(res, message = 'Forbidden', extra = null) {
    if (!extra) return this.error(res, message, 403);
    if (res.locals) res.locals.errorMessage = message;
    return res.status(403).json({
      success: false,
      message,
      ...extra,
      errors: null,
      timestamp: new Date().toISOString(),
    });
  }

  static notFound(res, message = 'Not Found') {
    return this.error(res, message, 404);
  }

  static paginated(res, { data, pagination, message = 'OK' }) {
    return res.status(200).json({
      success: true,
      message,
      data,
      pagination,
      timestamp: new Date().toISOString(),
    });
  }
}

module.exports = ResponseHandler;
