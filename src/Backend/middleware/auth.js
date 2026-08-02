const jwt = require('jsonwebtoken');
const config = require('../config');
const ResponseHandler = require('../core/response-handler');

// Bắt buộc có token
function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return ResponseHandler.unauthorized(res, 'Missing or invalid token');
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, config.jwt.accessSecret);
    req.user = decoded;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return ResponseHandler.unauthorized(res, 'Token expired');
    }
    return ResponseHandler.unauthorized(res, 'Invalid token');
  }
}

// Không bắt buộc token — nếu có thì giải mã, không có thì vẫn cho qua
function authenticateOptional(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    req.user = null;
    return next();
  }

  const token = authHeader.split(' ')[1];
  try {
    req.user = jwt.verify(token, config.jwt.accessSecret);
  } catch {
    req.user = null;
  }
  next();
}

module.exports = { authenticate, authenticateOptional };
