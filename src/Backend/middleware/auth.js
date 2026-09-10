const jwt = require('jsonwebtoken');
const config = require('../config');
const ResponseHandler = require('../core/response-handler');
const { prisma } = require('../config/db');
const logger = require('../core/logger');

// In-memory cache to verify account existence without querying DB on every single request
// Structure: idaccount (number) -> { valid: boolean, timestamp: number }
const accountCache = new Map();
const CACHE_TTL_MS = 60 * 1000; // 60 seconds TTL

async function getAccountValidity(idaccount) {
  if (!idaccount) return { valid: false, status: null, reason_inactive: null };
  const numId = Number(idaccount);
  const now = Date.now();
  const cached = accountCache.get(numId);
  if (cached && now - cached.timestamp < CACHE_TTL_MS) {
    return cached;
  }

  try {
    const account = await prisma.account.findUnique({
      where: { idaccount: numId },
      select: { idaccount: true, status: true, delete_at: true, reason_inactive: true, countdown: true },
    });
    const statusLower = account?.status ? account.status.toLowerCase() : '';
    
    // Tài khoản PendingDelete vẫn hợp lệ nếu còn trong thời hạn 30 ngày (countdown > 0)
    const isPendingDeleteValid = statusLower === 'pendingdelete' && 
      (account.countdown === null || account.countdown > 0) &&
      (!account.delete_at || new Date(account.delete_at) > new Date());

    const valid = !!account && (
      (statusLower === 'active' && !account.delete_at) ||
      isPendingDeleteValid
    );

    const result = {
      valid,
      status: account?.status || null,
      reason_inactive: account?.reason_inactive || null,
      countdown: account?.countdown ?? null,
      timestamp: now,
    };
    accountCache.set(numId, result);
    return result;
  } catch (error) {
    logger.warn('isAccountValid DB check failed, defaulting to optimistic pass', { idaccount, error: error.message });
    return { valid: true, status: 'Active', reason_inactive: null, timestamp: now };
  }
}

async function isAccountValid(idaccount) {
  const info = await getAccountValidity(idaccount);
  return info.valid;
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

  const accountInfo = await getAccountValidity(decoded.idaccount);
  if (!accountInfo.valid) {
    const isInactive = accountInfo.status?.toLowerCase() === 'inactive';
    const errorMsg = isInactive
      ? (accountInfo.reason_inactive ? `Tài khoản đã bị vô hiệu hóa. Lý do: ${accountInfo.reason_inactive}` : 'Tài khoản đã bị vô hiệu hóa')
      : 'Account no longer exists or has been deleted';

    return ResponseHandler.unauthorized(res, errorMsg, {
      code: isInactive ? 'ACCOUNT_INACTIVE' : 'ACCOUNT_DELETED',
      idaccount: Number(decoded.idaccount),
      reason_inactive: accountInfo.reason_inactive || null,
    });
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

module.exports = { authenticate, authenticateOptional, invalidateAccountCache, isAccountValid, getAccountValidity };
