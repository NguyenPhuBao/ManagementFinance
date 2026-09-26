/**
 * Chatbot AI Routes
 * /api/ai/chatbot/*
 */

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const chatbotController = require('./chatbot.controller');
const { validateChatRequest } = require('./chatbot.validation');
const { authenticate } = require('../../../../middleware/auth');

// Rate limiter: Giới hạn 15 request / phút / user để bảo vệ hạn ngạch LLM và chống spam
const chatRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 phút
  max: 15,
  message: {
    success: false,
    message: 'Bạn đang gửi yêu cầu quá nhanh. Vui lòng chờ 1 phút trước khi tiếp tục trò chuyện.',
  },
  keyGenerator: (req) => {
    return req.user?.idaccount ? `account_${req.user.idaccount}` : req.ip;
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// 1. Endpoint SSE Streaming chính
router.post('/chat/stream', authenticate, chatRateLimiter, validateChatRequest, chatbotController.handleChatStream);

// 2. Endpoint lấy Bản chụp Sức khỏe Tài chính
router.get('/snapshot', authenticate, chatbotController.handleGetSnapshot);

// 3. Endpoint Chat Non-Streaming (Dự phòng cho client đơn giản)
router.post('/chat', authenticate, chatRateLimiter, validateChatRequest, chatbotController.handleChatNonStream);

module.exports = router;
