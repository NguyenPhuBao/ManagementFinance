const rateLimit = require('express-rate-limit');
const config = require('../config');

// Kiểm tra nếu RATE_LIMIT_MAX=0 hoặc RATE_LIMIT_ENABLED=false -> Tắt hoàn toàn rate limit
const isRateLimitDisabled = config.rateLimit.max === 0 || config.rateLimit.enabled === false;

const generalLimiter = isRateLimitDisabled
  ? (req, res, next) => next() // Không giới hạn bất kỳ request nào
  : rateLimit({
      windowMs: config.rateLimit.windowMs || 15 * 60 * 1000,
      max: config.env === 'development' ? Math.max(config.rateLimit.max || 1000, 10000) : (config.rateLimit.max || 1000),
      standardHeaders: true,
      legacyHeaders: false,
      skip: (req) => {
        // 1. Luôn bỏ qua preflight OPTIONS của CORS (tránh nghẽn rate limit khi gọi từ Vercel)
        if (req.method === 'OPTIONS') return true;

        // 2. Miễn rate limit cho webhook Casso (đẩy dữ liệu burst từ ngân hàng)
        if (req.originalUrl && req.originalUrl.startsWith('/api/bank/webhook')) return true;

        // 3. Miễn rate limit cho người dùng Client-app & Admin-web đã đăng nhập (có Authorization header)
        const authHeader = req.headers.authorization || req.headers['authorization'] || (typeof req.get === 'function' && req.get('Authorization'));
        if (authHeader) return true;

        return false;
      },
      message: {
        success: false,
        message: 'Too many requests, please try again later.',
        timestamp: new Date().toISOString(),
      },
    });

// Limiter dành riêng cho Auth (Login / Register / OTP) chống brute-force
const authLimiter = isRateLimitDisabled
  ? (req, res, next) => next()
  : rateLimit({
      windowMs: 15 * 60 * 1000, // 15 minutes
      max: config.env === 'development' ? 1000 : 50,
      standardHeaders: true,
      legacyHeaders: false,
      skip: (req) => req.method === 'OPTIONS',
      message: {
        success: false,
        message: 'Too many login attempts, please try again later.',
        timestamp: new Date().toISOString(),
      },
    });

module.exports = { generalLimiter, authLimiter };


