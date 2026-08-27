const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const config = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 3000,
  host: process.env.HOST || '0.0.0.0',

  db: {
    url: process.env.DATABASE_URL,
  },

  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
  },

  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET,
    refreshSecret: process.env.JWT_REFRESH_SECRET,
    admin: {
      accessExpires: process.env.JWT_ADMIN_ACCESS_EXPIRES || '15m',
      refreshExpires: process.env.JWT_ADMIN_REFRESH_EXPIRES || '7d',
    },
    user: {
      accessExpires: process.env.JWT_USER_ACCESS_EXPIRES || '7d',
      refreshExpires: process.env.JWT_USER_REFRESH_EXPIRES || '90d',
    },
  },

  cors: {
    origin: process.env.CORS_ORIGIN
      ? (process.env.CORS_ORIGIN.includes(',')
          ? process.env.CORS_ORIGIN.split(',').map((s) => s.trim())
          : (process.env.CORS_ORIGIN === '*' ? '*' : process.env.CORS_ORIGIN))
      : ['http://localhost:5173', 'http://localhost:3000', 'http://localhost:5174'],
  },

  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 900000,
    max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 100,
  },

  logLevel: process.env.LOG_LEVEL || 'debug',

  smtp: {
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT, 10) || 587,
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
    from: process.env.SMTP_FROM || '"FlowMoney" <no-reply@flowmoney.app>',
  },

  casso: {
    apiUrl: process.env.CASSO_API_URL || 'https://api.casso.vn/v2',
    apiKey: process.env.CASSO_API_KEY,
    webhookSecret: process.env.CASSO_WEBHOOK_SECRET,
  },
};

module.exports = config;
