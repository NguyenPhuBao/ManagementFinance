const jwt = require('jsonwebtoken');
const config = require('../config');
const ResponseHandler = require('../core/response-handler');
const { prisma } = require('../config/db');
const logger = require('../core/logger');

// In-memory cache to verify account existence without querying DB on every single request
// Structure: idaccount (number) -> { valid: boolean, timestamp: number }
const accountCache = new Map();
const CACHE_TTL_MS = 60 * 1000; // 60 seconds TTL

async function isAccountValid(idaccount) {
  if (!idaccount) return false;
  const numId = Number(idaccount);
  const now = Date.now();
  const cached = accountCache.get(numId);
  if (cached && now - cached.timestamp < CACHE_TTL_MS) {
    return cached.valid;
  }

  try {
    const account = await prisma.account.findUnique({
      where: { idaccount: numId },
      select: { idaccount: true, status: true },
    });
    const valid = !!account && account.status !== 'inactive';
    accountCache.set(numId, { valid, timestamp: now });
    return valid;
  } catch (error) {
    logger.warn('isAccountValid DB check failed, defaulting to optimistic pass', { idaccount, error: error.message });
    return true; // Fallback optimistically if DB has transient error
  }
}

function invalidateAccountCache(idaccount) {
  if (idaccount) {
    accountCache.delete(Number(idaccount));
  }
}

// Bắt buộc có token và tài khoản phải tồn tại trong CSDL
async function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return ResponseHandler.unauthorized(res, 'Missing or invalid token');
  }

  const token = authHeader.split(' ')[1];
  let decoded;
  try {
    decoded = jwt.verify(token, config.jwt.accessSecret);
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return ResponseHandler.unauthorized(res, 'Token expired');
    }
    return ResponseHandler.unauthorized(res, 'Invalid token');
  }

  const valid = await isAccountValid(decoded.idaccount);
  if (!valid) {
    return ResponseHandler.unauthorized(res, 'Account no longer exists or is inactive');
  }

  req.user = decoded;
  next();
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

module.exports = { authenticate, authenticateOptional, invalidateAccountCache };
