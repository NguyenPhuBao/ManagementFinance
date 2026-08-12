const express = require('express');
const router = express.Router();
const syncController = require('../modules/sync/sync.controller');
const { authenticate } = require('../middleware/auth');

// Tất cả sync routes yêu cầu xác thực (user)
router.use(authenticate);

// Push — Nhận batch operations từ client
router.post('/push', syncController.push);

// Pull — Trả data mới cho client
router.get('/pull', syncController.pull);

// Status — Trạng thái sync
router.get('/status', syncController.status);

module.exports = router;
