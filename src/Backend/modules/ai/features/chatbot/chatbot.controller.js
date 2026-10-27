/**
 * Chatbot Controller — Xử lý HTTP Request & SSE Streaming
 */

const ChatbotService = require('./chatbot.service');
const ResponseHandler = require('../../../../core/response-handler');
const logger = require('../../../../core/logger');

class ChatbotController {
  constructor() {
    this.chatbotService = new ChatbotService();
  }

  /**
   * Endpoint SSE Streaming: POST /api/ai/chatbot/chat/stream
   */
  handleChatStream = async (req, res) => {
    const idaccount = req.user?.idaccount;
    const { message, conversationId, history } = req.body;

    // Thiết lập headers cho Server-Sent Events (SSE)
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no'); // Tắt buffering của Nginx
    if (typeof res.flushHeaders === 'function') {
      res.flushHeaders();
    }

    const abortController = new AbortController();

    // Keep-alive SSE comment ping (mỗi 15s) chống timeout 45s của Client khi Gemini đang suy luận
    const pingInterval = setInterval(() => {
      if (!abortController.signal.aborted && !res.writableEnded) {
        res.write(': ping\n\n');
      }
    }, 15000);

    const cleanup = () => {
      clearInterval(pingInterval);
    };

    const handleDisconnect = () => {
      if (!abortController.signal.aborted) {
        logger.info(`[SSE Controller] Client idaccount: ${idaccount} đã ngắt kết nối stream.`);
        req.auditReason = 'Người dùng dừng phản hồi hoặc đổi khung chat mới';
        cleanup();
        abortController.abort();
      }
    };

    req.on('close', handleDisconnect);
    res.on('close', handleDisconnect);

    try {
      await this.chatbotService.chatStream({
        message,
        conversationId,
        history,
        idaccount,
        signal: abortController.signal,
        onMeta: (metaData) => {
          if (!abortController.signal.aborted && !res.writableEnded) {
            res.write(`event: meta\ndata: ${JSON.stringify(metaData)}\n\n`);
          }
        },
        onChunk: (textChunk) => {
          if (!abortController.signal.aborted && !res.writableEnded) {
            res.write(`event: delta\ndata: ${JSON.stringify({ text: textChunk, content: textChunk })}\n\n`);
          }
        },
        onDone: (doneData) => {
          cleanup();
          if (!abortController.signal.aborted && !res.writableEnded) {
            res.write(`event: done\ndata: ${JSON.stringify(doneData || { status: 'completed' })}\n\n`);
            res.end();
          }
        },
      });
    } catch (error) {
      cleanup();
      logger.error('[SSE Controller] Lỗi trong quá trình stream:', error);
      if (!abortController.signal.aborted && !res.writableEnded) {
        res.write(`event: error\ndata: ${JSON.stringify({ message: error.message })}\n\n`);
        res.end();
      }
    }
  };

  /**
   * Endpoint lấy Bản chụp Sức khỏe Tài chính: GET /api/ai/chatbot/snapshot
   */
  handleGetSnapshot = async (req, res) => {
    const idaccount = req.user?.idaccount;

    try {
      const snapshot = await this.chatbotService.getSnapshot(idaccount);
      if (!snapshot) {
        return ResponseHandler.error(res, 'Không thể lấy dữ liệu phân tích tài chính lúc này', 503);
      }
      return ResponseHandler.success(res, snapshot, 'Lấy bản chụp sức khỏe tài chính thành công');
    } catch (error) {
      logger.error('[Chatbot Controller] Lỗi lấy snapshot:', error);
      return ResponseHandler.error(res, 'Không thể lấy dữ liệu phân tích tài chính lúc này', 503);
    }
  };

  /**
   * Endpoint Chat dạng JSON (Non-streaming fallback): POST /api/ai/chatbot/chat
   */
  handleChatNonStream = async (req, res) => {
    const idaccount = req.user?.idaccount;
    const { message, conversationId, history } = req.body;

    let fullReply = '';
    let snapshotInfo = null;

    try {
      await this.chatbotService.chatStream({
        message,
        conversationId,
        history,
        idaccount,
        onMeta: (meta) => { snapshotInfo = meta; },
        onChunk: (chunk) => { fullReply += chunk; },
        onDone: () => {
          return ResponseHandler.success(res, {
            reply: fullReply,
            text: fullReply,
            content: fullReply,
            snapshot: snapshotInfo,
            conversationId,
          }, 'Phản hồi thành công');
        },
      });
    } catch (error) {
      logger.error('[Chatbot Controller] Lỗi chat non-stream:', error);
      return ResponseHandler.error(res, 'Lỗi khi xử lý phản hồi từ AI', 500);
    }
  };

  /**
   * Endpoint Làm mới hội thoại AI: POST /api/ai/chatbot/reset
   */
  handleResetConversation = async (req, res) => {
    return ResponseHandler.success(res, { reset: true }, 'Làm mới hội thoại AI thành công');
  };
}

module.exports = new ChatbotController();
