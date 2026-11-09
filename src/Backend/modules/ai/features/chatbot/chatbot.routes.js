/**
 * Chatbot AI Routes
 * /api/ai/chatbot/*
 *
 * Thứ tự middleware (rẻ trước, tốn kém sau): xác thực → quyền gói → giới hạn tần suất (15/phút) → làm sạch
 * đầu vào → hạn mức theo ngày (chỉ tính yêu cầu hợp lệ). Endpoint `/snapshot` đã gỡ: không còn nơi nào gọi.
 */

const express = require('express');
const router = express.Router();
const { redisTokenBucketLimiter } = require('./rate-limiter/redis-token-bucket');
const { dailyQuotaMiddleware } = require('./limits/quota.middleware');
const chatbotController = require('./chatbot.controller');
const { validateChatRequest } = require('./chatbot.validation');
const { authenticate } = require('../../../../middleware/auth');
const { requireFeature } = require('../../../../middleware/feature-permission.middleware');
const eventBus = require('../../../../core/event-bus');

chatbotController.chatbotService.snapshotService.listenForChanges(eventBus);

// 1. Endpoint SSE Streaming chính
router.post('/chat/stream', authenticate, requireFeature('ai_assistant'), redisTokenBucketLimiter, validateChatRequest, dailyQuotaMiddleware, chatbotController.handleChatStream);

// 2. Endpoint Chat Non-Streaming (dự phòng cho client đơn giản, và làm mốc so sánh trong thực nghiệm)
router.post('/chat', authenticate, requireFeature('ai_assistant'), redisTokenBucketLimiter, validateChatRequest, dailyQuotaMiddleware, chatbotController.handleChatNonStream);

// 3. Endpoint Làm mới hội thoại AI
router.post('/reset', authenticate, requireFeature('ai_assistant'), chatbotController.handleResetConversation);

module.exports = router;
