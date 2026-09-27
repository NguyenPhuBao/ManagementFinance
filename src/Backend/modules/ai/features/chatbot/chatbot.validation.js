/**
 * Validation Schemas for Chatbot Module
 */

function validateChatRequest(req, res, next) {
  const message = req.body?.message;
  const history = req.body?.history || req.body?.conversationHistory;
  if (history) {
    req.body.history = history;
  }

  if (!message || typeof message !== 'string' || !message.trim()) {
    return res.status(400).json({
      success: false,
      message: 'Tin nhắn (message) là bắt buộc và không được để trống',
    });
  }

  if (message.length > 2000) {
    return res.status(400).json({
      success: false,
      message: 'Tin nhắn quá dài (tối đa 2000 ký tự)',
    });
  }

  if (history && !Array.isArray(history)) {
    return res.status(400).json({
      success: false,
      message: 'Lịch sử hội thoại (history/conversationHistory) phải là một mảng',
    });
  }

  next();
}

module.exports = {
  validateChatRequest,
};
