/**
 * Chatbot AI Routes
 * /api/ai/chatbot/*
 */

const express = require('express');
const router = express.Router();
const { redisTokenBucketLimiter } = require('./rate-limiter/redis-token-bucket');
const chatbotController = require('./chatbot.controller');
const { validateChatRequest } = require('./chatbot.validation');
const { authenticate } = require('../../../../middleware/auth');
const { requireFeature } = require('../../../../middleware/feature-permission.middleware');

// 1. Endpoint SSE Streaming chính (bảo vệ bởi Redis Token-Bucket Limiter 15 req/phút & Phân quyền AI)
router.post('/chat/stream', authenticate, requireFeature('ai_assistant'), redisTokenBucketLimiter, validateChatRequest, chatbotController.handleChatStream);

// 2. Endpoint lấy Bản chụp Sức khỏe Tài chính (và alias /financial-health)
router.get('/snapshot', authenticate, requireFeature('financial_health_fhs'), chatbotController.handleGetSnapshot);
router.get('/financial-health', authenticate, requireFeature('financial_health_fhs'), chatbotController.handleGetSnapshot);

// 3. Endpoint Chat Non-Streaming (Dự phòng cho client đơn giản)
router.post('/chat', authenticate, requireFeature('ai_assistant'), redisTokenBucketLimiter, validateChatRequest, chatbotController.handleChatNonStream);

// 4. Endpoint Làm mới hội thoại AI
router.post('/reset', authenticate, requireFeature('ai_assistant'), chatbotController.handleResetConversation);

module.exports = router;
