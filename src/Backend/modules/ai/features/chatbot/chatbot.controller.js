/**
 * Chatbot Controller — Xử lý HTTP Request & SSE Streaming
 */

const ChatbotService = require('./chatbot.service');
const ResponseHandler = require('../../../../core/response-handler');
const logger = require('../../../../core/logger');
const { checkScope } = require('./scope/scope-guard');
const { confirmScope } = require('./scope/scope-confirm');
const { streamDeepseek } = require('./llm/deepseek.provider');
const { resolveProvider, getDeepseekConfig } = require('./llm/provider.config');
const { StreamGuard } = require('./limits/stream-guard');
const { getChatbotLimits } = require('./limits/chatbot.limits');
const { getUsageBudget, isAdmin } = require('./limits/quota.middleware');

const STREAM_BUSY_BODY = {
  success: false,
  code: 'AI_STREAM_BUSY',
  message: 'Trợ lý AI đang bận xử lý yêu cầu trước đó của bạn hoặc hệ thống đang quá tải. Vui lòng thử lại sau giây lát.',
};

class ChatbotController {
  constructor() {
    this.chatbotService = new ChatbotService();
    const limits = getChatbotLimits();
    this.streamGuard = new StreamGuard({ perUser: limits.maxStreamsPerUser, global: limits.maxStreamsGlobal });
    this.getBudget = getUsageBudget; // tiêm được khi test
    // Hỏi AI xác nhận phạm vi trước khi loại câu bộ lọc từ khoá chặn (tiêm được khi test)
    this.scopeConfirmer = (p) => confirmScope({ ...p, llm: streamDeepseek, cfg: resolveProvider() === 'deepseek' ? getDeepseekConfig() : null });
  }

  /**
   * Bước 3 (PO duyệt 2026-11-09): bộ lọc từ khoá chặn vì lạc đề thì hỏi AI xác nhận trước khi loại; câu tiêm lệnh chặn thẳng.
   * @returns {Promise<{allowed: true, scopeNote?: string} | {allowed: false, scope: object}>}
   */
  async _checkScope(req, message, signal) {
    const scope = checkScope(message);
    if (scope.allowed) return { allowed: true };
    if (scope.code !== 'OFF_TOPIC') return { allowed: false, scope };
    let userName = '';
    try { userName = (await this.chatbotService._getUserName?.(req.user?.idaccount)) || ''; } catch (_) { /* che theo mẫu chung */ }
    const verdict = await this.scopeConfirmer({ message, userName, onUsage: this._usageRecorder(req), signal });
    if (verdict?.allowed) return { allowed: true, scopeNote: verdict.reason || '' };
    logger.info(`[Chatbot Controller] AI xác nhận câu ngoài phạm vi (${scope.code}) của idaccount: ${req.user?.idaccount}`);
    return { allowed: false, scope };
  }

  /** Ghi chi phí thật của từng vòng gọi LLM vào ngân sách tháng của người dùng (quản trị viên không bị tính). */
  _usageRecorder(req) {
    if (isAdmin(req.user)) return undefined;
    const idaccount = req.user?.idaccount;
    return (usage) => this.getBudget().add(idaccount, usage.costMicroUsd);
  }

  /**
   * Trả lại lượt hỏi trong ngày khi hệ thống không trả được câu trả lời (dịch vụ AI lỗi / rơi về máy, lỗi ngoại lệ,
   * bận hoặc quá tải). Người dùng tự huỷ thì nơi gọi không hoàn. Ngân sách tháng giữ nguyên chi phí thật đã phát sinh.
   */
  _refundTurn(req) {
    if (typeof req.aiQuotaRefund !== 'function') return;
    req.aiQuotaRefund().catch((err) => logger.warn('[Chatbot Controller] Không hoàn được lượt hỏi:', err?.message));
  }

  /**
   * Endpoint SSE Streaming: POST /api/ai/chatbot/chat/stream
   * Sự kiện: `meta` → (`tool` | `delta`)* → `done` (hoặc `error`). Dòng `: ping` mỗi 15 s giữ kết nối.
   * `tool` = `{name, status: 'start'|'done'}` báo công cụ đang chạy lúc luồng chữ dừng; client bản cũ bỏ qua sự kiện lạ.
   */
  handleChatStream = async (req, res) => {
    const idaccount = req.user?.idaccount;
    const { message, conversationId, history } = req.body;

    const release = this.streamGuard.acquire(idaccount);
    if (!release) {
      this._refundTurn(req);
      return res.status(429).json(STREAM_BUSY_BODY);
    }

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no'); // Tắt buffering của Nginx
    if (typeof res.flushHeaders === 'function') {
      res.flushHeaders();
    }

    const abortController = new AbortController();

    // Keep-alive SSE comment ping (mỗi 15s) chống timeout 45s của Client khi mô hình đang suy luận
    const pingInterval = setInterval(() => {
      if (!abortController.signal.aborted && !res.writableEnded) {
        res.write(': ping\n\n');
      }
    }, 15000);

    const cleanup = () => {
      clearInterval(pingInterval);
      release();
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
      // Lớp quy tắc chặn việc ngoài phạm vi; câu bị chặn vì lạc đề được AI xác nhận một lần trước khi loại hẳn.
      // Loại hẳn: trả câu từ chối cố định như một lượt bình thường và trả lại lượt (chi phí xác nhận vẫn vào ngân sách).
      const pv = await this._checkScope(req, message, abortController.signal);
      if (abortController.signal.aborted) return;
      if (!pv.allowed) {
        const scope = pv.scope;
        this._refundTurn(req);
        logger.info(`[SSE Controller] Chặn câu ngoài phạm vi (${scope.code}) của idaccount: ${idaccount}`);
        res.write(`event: delta\ndata: ${JSON.stringify({ text: scope.refusalText, content: scope.refusalText })}\n\n`);
        res.write(`event: done\ndata: ${JSON.stringify({ status: 'completed', scopeRefusal: true, code: scope.code })}\n\n`);
        cleanup();
        res.end();
        return;
      }

      await this.chatbotService.chatStream({
        scopeNote: pv.scopeNote,
        message,
        conversationId,
        history,
        idaccount,
        signal: abortController.signal,
        turnCostCapMicroUsd: req.aiTurnCostCapMicroUsd,
        contextWindowDays: req.aiContextWindowDays,
        onUsage: this._usageRecorder(req),
        onMeta: (metaData) => {
          if (!abortController.signal.aborted && !res.writableEnded) {
            res.write(`event: meta\ndata: ${JSON.stringify(metaData)}\n\n`);
          }
        },
        onTool: (toolEvent) => {
          if (!abortController.signal.aborted && !res.writableEnded) {
            res.write(`event: tool\ndata: ${JSON.stringify(toolEvent)}\n\n`);
          }
        },
        onChunk: (textChunk) => {
          if (!abortController.signal.aborted && !res.writableEnded) {
            res.write(`event: delta\ndata: ${JSON.stringify({ text: textChunk, content: textChunk })}\n\n`);
          }
        },
        onDone: (doneData) => {
          cleanup();
          if (!abortController.signal.aborted && (doneData?.fallback || doneData?.error)) this._refundTurn(req);
          if (!abortController.signal.aborted && !res.writableEnded) {
            res.write(`event: done\ndata: ${JSON.stringify(doneData || { status: 'completed' })}\n\n`);
            res.end();
          }
        },
      });
    } catch (error) {
      cleanup();
      if (!abortController.signal.aborted) this._refundTurn(req);
      logger.error('[SSE Controller] Lỗi trong quá trình stream:', error);
      if (!abortController.signal.aborted && !res.writableEnded) {
        res.write(`event: error\ndata: ${JSON.stringify({ message: error.message })}\n\n`);
        res.end();
      }
    } finally {
      cleanup();
    }
  };

  /**
   * Endpoint Chat dạng JSON (Non-streaming, dự phòng và làm mốc so sánh): POST /api/ai/chatbot/chat
   */
  handleChatNonStream = async (req, res) => {
    const idaccount = req.user?.idaccount;
    const { message, conversationId, history } = req.body;

    const pv = await this._checkScope(req, message);
    if (!pv.allowed) {
      const scope = pv.scope;
      this._refundTurn(req);
      return ResponseHandler.success(res, {
        reply: scope.refusalText, text: scope.refusalText, content: scope.refusalText, snapshot: null, conversationId,
      }, 'Phản hồi thành công');
    }

    const release = this.streamGuard.acquire(idaccount);
    if (!release) {
      this._refundTurn(req);
      return res.status(429).json(STREAM_BUSY_BODY);
    }

    let fullReply = '';
    let snapshotInfo = null;
    const abortController = new AbortController();
    // Client bỏ đi giữa chừng thì dừng gọi LLM. Sự kiện này cũng phát khi đã trả lời xong nên phải loại trường hợp đó.
    res.on('close', () => {
      if (!res.writableEnded) abortController.abort();
    });

    try {
      await this.chatbotService.chatStream({
        scopeNote: pv.scopeNote,
        message,
        conversationId,
        history,
        idaccount,
        signal: abortController.signal,
        turnCostCapMicroUsd: req.aiTurnCostCapMicroUsd,
        contextWindowDays: req.aiContextWindowDays,
        onUsage: this._usageRecorder(req),
        onMeta: (meta) => { snapshotInfo = meta; },
        onChunk: (chunk) => { fullReply += chunk; },
        onDone: (done) => {
          // Dịch vụ lỗi không được báo thành công, và chữ đã sinh dở không phải câu trả lời.
          if (done?.fallback || done?.error) {
            if (!abortController.signal.aborted) this._refundTurn(req);
            return res.status(503).json({
              success: false,
              code: 'AI_SERVICE_UNAVAILABLE',
              message: done.reason || 'Dịch vụ AI tạm thời không phản hồi',
              fallback: true,
            });
          }
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
      if (!abortController.signal.aborted) this._refundTurn(req);
      return ResponseHandler.error(res, 'Lỗi khi xử lý phản hồi từ AI', 500);
    } finally {
      release();
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
