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
    max: process.env.RATE_LIMIT_MAX !== undefined ? parseInt(process.env.RATE_LIMIT_MAX, 10) : 1000,
    enabled: process.env.RATE_LIMIT_ENABLED !== 'false' && process.env.RATE_LIMIT_MAX !== '0',
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

  sepay: {
    apiUrl: process.env.SEPAY_BANKHUB_API_URL || 'https://bankhub-api.sepay.vn',
    clientId: process.env.SEPAY_CLIENT_ID,
    clientSecret: process.env.SEPAY_CLIENT_SECRET,
    companyXid: process.env.SEPAY_COMPANY_XID,
    webhookApiKey: process.env.SEPAY_WEBHOOK_API_KEY,
  },

  gemini: {
    apiKey: process.env.GEMINI_API_KEY,
  },

  payos: {
    clientId: process.env.PAYOS_CLIENT_ID,
    apiKey: process.env.PAYOS_API_KEY,
    checksumKey: process.env.PAYOS_CHECKSUM_KEY,
    returnUrl: process.env.PAYOS_RETURN_URL || 'https://management-finance.app/payment/success',
    cancelUrl: process.env.PAYOS_CANCEL_URL || 'https://management-finance.app/payment/cancel',
  },

  payment: {
    premiumPriceVnd: parseInt(process.env.PREMIUM_PRICE_VND, 10) || 49000,
    packageDurationDays: parseInt(process.env.PREMIUM_PACKAGE_DAYS, 10) || 30,
  },
};

// Chốt chặn an ninh số (Data_Security.md & SOAT_SAU_GOP_B38367E):
// Trong môi trường production, bắt buộc phải có JWT_ACCESS_SECRET và JWT_REFRESH_SECRET
if (config.env === 'production') {
  if (!config.jwt.accessSecret || !config.jwt.refreshSecret) {
    console.error('\x1b[31m[SECURITY CRITICAL] Thiếu JWT_ACCESS_SECRET hoặc JWT_REFRESH_SECRET trong môi trường production. Từ chối khởi động.\x1b[0m');
    process.exit(1);
  }
}

module.exports = config;
