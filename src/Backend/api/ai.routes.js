const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const validate = require('../middleware/validator');
const aiController = require('../modules/ai/ai.controller');
const { classifySchema } = require('../modules/ai/ai.validation');
const classifyRoutes = require('../modules/ai/features/classify/classify.routes');
const ocrRoutes = require('../modules/ai/features/ocr/ocr.routes');
const chatbotRoutes = require('../modules/ai/features/chatbot/chatbot.routes');

// Tất cả AI routes yêu cầu đăng nhập (user)
router.use(authenticate);

// Feature: Transaction Classification
router.use('/classify', classifyRoutes);

// Feature: Receipt & Bank Transfer OCR
router.use('/ocr', ocrRoutes);

// Feature: AI Financial Copilot / Chatbot (Dual-Phase Reasoning with Privacy Shield)
router.use('/chatbot', chatbotRoutes);

// Backward compatibility: POST /api/ai/classify
router.post('/classify', validate(classifySchema), aiController.classify);

module.exports = router;
