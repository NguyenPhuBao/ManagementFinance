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

// Mount sub-routers (will be populated later)
router.use('/auth', require('./auth.routes'));
router.use('/admin', require('./admin.routes'));
router.use('/ai', require('./ai.routes'));
router.use('/bank', require('./bank.routes'));
router.use('/sync', require('./sync.routes'));
router.use('/notifications', require('./notification.routes'));

module.exports = router;
