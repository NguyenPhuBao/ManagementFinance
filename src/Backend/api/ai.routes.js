const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validator');
const aiController = require('../modules/ai/ai.controller');
const { classifySchema } = require('../modules/ai/ai.validation');
const classifyRoutes = require('../modules/ai/features/classify/classify.routes');
const ocrRoutes = require('../modules/ai/features/ocr/ocr.routes');

// Tất cả AI routes yêu cầu đăng nhập (user)
router.use(authenticate);

// Feature: Transaction Classification
router.use('/classify', classifyRoutes);

// Feature: Receipt & Bank Transfer OCR
router.use('/ocr', ocrRoutes);

// Backward compatibility: POST /api/ai/classify
router.post('/classify', validate(classifySchema), aiController.classify);

module.exports = router;
