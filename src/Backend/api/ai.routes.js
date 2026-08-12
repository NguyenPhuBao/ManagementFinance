const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validator');
const aiController = require('../modules/ai/ai.controller');
const { classifySchema } = require('../modules/ai/ai.validation');

// Tất cả AI routes yêu cầu đăng nhập (user)
router.use(authenticate);

// POST /api/ai/classify — phân loại giao dịch
router.post('/classify', validate(classifySchema), aiController.classify);

module.exports = router;
