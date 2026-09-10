const express = require('express');
const ResponseHandler = require('../core/response-handler');

const router = express.Router();

// API root
router.get('/', (req, res) => {
  ResponseHandler.success(res, {
    name: 'WealthCommand API',
    version: '1.0.0',
    docs: '/api/docs',
  }, 'WealthCommand Backend API');
});

// DB test route - queries PersonFinance
router.get('/db-test', async (req, res) => {
  const { prisma, pool } = require('../config/db');
  try {
    // Using native pg
    const pgResult = await pool.query('SELECT table_name FROM information_schema.tables WHERE table_schema = $1 ORDER BY table_name', ['public']);
    const tables = pgResult.rows.map(r => r.table_name);

    // Using Prisma
    const userCount = await prisma.user.count();

    ResponseHandler.success(res, {
      database: 'PersonFinance',
      tables,
      userCount,
      connection: 'OK',
    }, 'Database connection successful');
  } catch (error) {
    ResponseHandler.error(res, `Database error: ${error.message}`);
  }
});

const { verifyPresignedUrl } = require('../utils/storage.util');

// Endpoint xác thực & truy cập ảnh chứng từ Private Bucket qua Pre-signed URL (Nghị định 13/2023/NĐ-CP)
router.get('/v1/storage/private/:key', (req, res) => {
  const { key } = req.params;
  const { expires, sig } = req.query;

  const decodedKey = decodeURIComponent(key);
  const isValid = verifyPresignedUrl(decodedKey, Number(expires), String(sig || ''));

  if (!isValid) {
    return res.status(403).json({
      success: false,
      statusCode: 403,
      message: 'Đường dẫn Pre-signed URL không hợp lệ hoặc đã hết thời hạn truy cập (TTL 30 phút)!',
    });
  }

  return res.json({
    success: true,
    message: 'Pre-signed URL hợp lệ',
    key: decodedKey,
    expiresAt: new Date(Number(expires) * 1000).toISOString(),
  });
});

// Mount sub-routers (will be populated later)
router.use('/auth', require('./auth.routes'));
router.use('/admin', require('./admin.routes'));
router.use('/ai', require('./ai.routes'));
router.use('/bank', require('./bank.routes'));
router.use('/sync', require('./sync.routes'));
router.use('/notifications', require('./notification.routes'));

module.exports = router;

