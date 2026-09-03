/**
 * F013 — Receipt & Bank Transfer OCR — Routes
 * 
 * POST /api/ai/ocr/parse - Bóc tách hóa đơn / biên lai từ ảnh
 * POST /api/ai/ocr       - Shortcut bóc tách ảnh
 */

const express = require('express');
const router = express.Router();
const ocrController = require('./ocr.controller');

// Routes
router.post('/parse', ocrController.handleParseReceipt);
router.post('/', ocrController.handleParseReceipt);

module.exports = router;
