const winston = require('winston');
const path = require('path');

const SENSITIVE_KEYS = ['password', 'token', 'otp', 'code_hash', 'balance', 'cvv', 'cvc', 'refreshtoken'];

function sanitizeMeta(meta) {
  if (!meta || typeof meta !== 'object') return meta;
  if (Array.isArray(meta)) return meta.map(sanitizeMeta);
  const clean = {};
  for (const [key, val] of Object.entries(meta)) {
    if (SENSITIVE_KEYS.includes(key.toLowerCase())) {
      clean[key] = '[BẢO MẬT: ĐÃ CHE DỮ LIỆU NHẠY CẢM]';
    } else if (typeof val === 'object' && val !== null) {
      clean[key] = sanitizeMeta(val);
    } else {
      clean[key] = val;
    }
  }
  return clean;
}

const sanitizeFormat = winston.format((info) => {
  for (const key of Object.keys(info)) {
    if (SENSITIVE_KEYS.includes(key.toLowerCase())) {
      info[key] = '[BẢO MẬT: ĐÃ CHE DỮ LIỆU NHẠY CẢM]';
    } else if (typeof info[key] === 'object' && info[key] !== null) {
      info[key] = sanitizeMeta(info[key]);
    }
  }
  return info;
});

const logFormat = winston.format.combine(
  sanitizeFormat(),
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.printf(({ timestamp, level, message, stack, ...meta }) => {
    const cleanMeta = sanitizeMeta(meta);
    const metaStr = Object.keys(cleanMeta).length ? JSON.stringify(cleanMeta) : '';
    return `${timestamp} [${level.toUpperCase()}] ${message} ${metaStr}`.trim();
  })
);

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'debug',
  format: logFormat,
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        logFormat
      ),
    }),
  ],
});

logger.sanitizeMeta = sanitizeMeta;

module.exports = logger;

