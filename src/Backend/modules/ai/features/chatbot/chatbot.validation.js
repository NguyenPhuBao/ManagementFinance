/**
 * Validation Schemas for Chatbot Module
 * Ngoài việc kiểm tra, còn LÀM SẠCH `history` (cắt số tin và độ dài từng tin) để chặn lỗ hổng chi phí:
 * lịch sử không giới hạn có thể kéo theo hàng triệu token cho mỗi yêu cầu.
 */

const { getChatbotLimits } = require('./limits/chatbot.limits');
const { sanitizeHistory } = require('./limits/request-sanitizer');

function validateChatRequest(req, res, next) {
  const limits = getChatbotLimits();
  const message = req.body?.message;
  const rawHistory = req.body?.history || req.body?.conversationHistory;

  if (!message || typeof message !== 'string' || !message.trim()) {
    return res.status(400).json({
      success: false,
      message: 'Tin nhắn (message) là bắt buộc và không được để trống',
    });
  }

  if (message.length > limits.maxMessageChars) {
    return res.status(400).json({
      success: false,
      message: `Tin nhắn quá dài (tối đa ${limits.maxMessageChars} ký tự)`,
    });
  }

  if (rawHistory && !Array.isArray(rawHistory)) {
    return res.status(400).json({
      success: false,
      message: 'Lịch sử hội thoại (history/conversationHistory) phải là một mảng',
    });
  }

  req.body.history = sanitizeHistory(rawHistory, limits);
  next();
}

module.exports = {
  validateChatRequest,
};
