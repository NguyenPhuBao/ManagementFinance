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

    // Lắng nghe sự kiện ngắt kết nối từ Client (tắt tab hoặc hủy stream)
    req.on('close', () => {
      logger.info(`[SSE Controller] Client idaccount: ${idaccount} đã ngắt kết nối stream.`);
      abortController.abort();
    });

    try {
      await this.chatbotService.chatStream({
        message,
        conversationId,
        history,
        idaccount,
        signal: abortController.signal,
        onMeta: (metaData) => {
          res.write(`event: meta\ndata: ${JSON.stringify(metaData)}\n\n`);
        },
        onChunk: (textChunk) => {
          res.write(`event: delta\ndata: ${JSON.stringify({ text: textChunk })}\n\n`);
        },
        onDone: (doneData) => {
          res.write(`event: done\ndata: ${JSON.stringify(doneData || { status: 'completed' })}\n\n`);
          res.end();
        },
      });
    } catch (error) {
      logger.error('[SSE Controller] Lỗi trong quá trình stream:', error);
      res.write(`event: error\ndata: ${JSON.stringify({ message: error.message })}\n\n`);
      res.end();
    }
  };

  /**
   * Endpoint lấy Bản chụp Sức khỏe Tài chính: GET /api/ai/chatbot/snapshot
   */
  handleGetSnapshot = async (req, res) => {
    const idaccount = req.user?.idaccount;

    try {
      const snapshot = await this.chatbotService.getSnapshot(idaccount);
      return ResponseHandler.success(res, snapshot, 'Lấy bản chụp sức khỏe tài chính thành công');
    } catch (error) {
      logger.error('[Chatbot Controller] Lỗi lấy snapshot:', error);
      return ResponseHandler.error(res, 'Không thể lấy thông tin sức khỏe tài chính', 500);
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
}

module.exports = new ChatbotController();
