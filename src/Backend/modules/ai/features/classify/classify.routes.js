/**
 * F012 — Transaction Classifier — Routes
 * 
 * POST /api/ai/classify/single   - Phân loại 1 giao dịch
 * POST /api/ai/classify/batch    - Phân loại danh sách món hàng (OCR)
 * POST /api/ai/classify/feedback - Ghi nhận phản hồi người dùng tự học
 */

const express = require('express');
const router = express.Router();
const classifyController = require('./classify.controller');

// Routes
router.post('/single', classifyController.handleClassifySingle);
router.post('/batch', classifyController.handleClassifyBatch);
router.post('/feedback', classifyController.handleFeedback);
router.post('/transaction', classifyController.handleClassifyTransaction);

module.exports = router;
