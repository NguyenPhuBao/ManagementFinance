/**
 * Chatbot Service — Nhạc trưởng điều phối Trợ lý Tài chính AI
 * Tích hợp Dual-Phase Reasoning with Privacy Shield, Gemini 2.0 Flash, Tools & RAG
 */

const { GoogleGenerativeAI } = require('@google/generative-ai');
const FinancialSnapshotService = require('./snapshot/financial.snapshot.service');
const ToolsExecutor = require('./tools/tools.executor');
const { financialToolsDeclarations } = require('./tools/financial.tools');
const HybridKnowledgeSearch = require('./rag/hybrid.search');
const PIIMasker = require('./privacy/pii.masker');
const { buildSystemPrompt } = require('./prompts/advisor.system.prompt');
const { geminiCircuitBreaker } = require('./resilience/circuit-breaker');
const logger = require('../../../../core/logger');

class ChatbotService {
  constructor() {
    this.geminiApiKey = process.env.GEMINI_API_KEY || null;
    this.snapshotService = new FinancialSnapshotService();
    this.toolsExecutor = new ToolsExecutor();
    this.knowledgeSearch = new HybridKnowledgeSearch();
    this.piiMasker = new PIIMasker();
  }

  /**
   * Lấy bản chụp sức khỏe tài chính của người dùng
   * @param {number} idaccount 
   * @returns {Promise<object>}
   */
  async getSnapshot(idaccount) {
    return await this.snapshotService.generateSnapshot(idaccount);
  }

  /**
   * Luồng thông báo minh bạch khi dịch vụ LLM gián đoạn hoặc ngoại tuyến
   * TUYỆT ĐỐI KHÔNG GIẢ LẬP SỐ LIỆU TÀI CHÍNH GIẢ
   * @param {string} message
   * @param {object} snapshot
   * @param {Function} onChunk
   * @param {Function} onDone
   * @param {string} [reason]
   */
  async _streamFallbackResponse(message, snapshot, onChunk, onDone, reason = '') {
    const errorReason = reason || 'Hệ thống AI đám mây tạm thời không phản hồi hoặc đang bảo trì.';
    const notice = `⚠️ **Thông báo từ Hệ thống Trợ lý Tài chính AI**\n\n` +
      `Hiện tại mô hình ngôn ngữ lớn (LLM) không thể phản hồi yêu cầu của bạn do: **${errorReason}**\n\n` +
      `🛡️ **Đảm bảo An toàn Dữ liệu:** Toàn bộ thông tin tài khoản và dữ liệu giao dịch của bạn vẫn an toàn tuyệt đối và nguyên vẹn trên hệ thống CSDL.\n\n` +
      `📌 **Khuyến nghị:**\n` +
      `- Vui lòng thử lại sau giây lát.\n` +
      `- Bạn có thể theo dõi trực tiếp các chỉ số tài chính, biểu đồ chi tiêu và ngân sách tại các màn hình **Sức khỏe Tài chính**, **Thống kê** hoặc **Ngân sách** của ứng dụng.`;

    const tokens = notice.split(' ');

    for (const token of tokens) {
      if (typeof onChunk === 'function') {
        onChunk(token + ' ');
      }
      await new Promise(r => setTimeout(r, 15));
    }

    if (typeof onDone === 'function') {
      onDone({ fallback: true, reason: errorReason });
    }
  }

  /**
   * Xử lý luồng chat thời gian thực qua Server-Sent Events (SSE Streaming)
   * @param {object} params
   * @param {string} params.message
   * @param {string} [params.conversationId]
   * @param {Array<object>} [params.history=[]]
   * @param {number} params.idaccount
   * @param {Function} params.onChunk - Callback nhận token text
   * @param {Function} params.onMeta - Callback nhận metadata (snapshot, fhs)
   * @param {Function} params.onDone - Callback khi kết thúc
   * @param {AbortSignal} [params.signal] - Lắng nghe hủy kết nối từ client
   */
  async chatStream({
    message,
    conversationId,
    history = [],
    idaccount,
    onChunk,
    onMeta,
    onDone,
    signal,
  }) {
    const startTime = Date.now();

    try {
      // BƯỚC 1: Sinh Bản chụp Sức khỏe Tài chính Ẩn danh (Dual-Phase Shield: Phase 1)
      const snapshot = await this.snapshotService.generateSnapshot(idaccount);

      // Bắn metadata sớm về cho Client hiển thị UI (TTFT < 100ms)
      if (typeof onMeta === 'function') {
        onMeta({
          snapshotLoaded: true,
          healthScore: snapshot.financialHealthScore,
          snapshot,
        });
      }

      // BƯỚC 2: Truy vấn Tri thức Tĩnh RAG (Chuẩn Standard_RAG.md)
      const ragResults = this.knowledgeSearch.search(message, 1);
      let knowledgeContext = '';
      if (ragResults.length > 0) {
        knowledgeContext = `Tài liệu: ${ragResults[0].title}\nNội dung: ${ragResults[0].content}\n${ragResults[0].attribution}`;
      }

      // BƯỚC 3: Lắp ráp System Prompt chuyên gia CFP
      const systemInstruction = buildSystemPrompt(snapshot, knowledgeContext);

      // BƯỚC 4: Kiểm tra API Key Gemini
      const apiKey = process.env.GEMINI_API_KEY || this.geminiApiKey;
      if (!apiKey) {
        logger.warn('[ChatbotService] GEMINI_API_KEY chưa cấu hình. Kích hoạt Fallback Stream.');
        return await this._streamFallbackResponse(message, snapshot, onChunk, onDone, 'Hệ thống chưa thiết lập API Key Google Gemini');
      }

      // BƯỚC 5: Gọi Google Gemini qua Circuit Breaker với Streaming & Function Calling
      await geminiCircuitBreaker.execute(async () => {
        const modelName = process.env.GEMINI_MODEL || 'gemini-3.8-flash';
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({
          model: modelName,
          systemInstruction,
          generationConfig: {
            temperature: 0.1, // Chống ảo giác
            maxOutputTokens: 1024,
          },
          tools: [{ functionDeclarations: financialToolsDeclarations }],
        });

        // Chuẩn hóa format lịch sử hội thoại
        const formattedHistory = [];
        if (Array.isArray(history)) {
          for (const item of history.slice(-6)) { // Tối đa 6 tin nhắn gần nhất
            if (item.text && (item.role === 'user' || item.role === 'model')) {
              formattedHistory.push({
                role: item.role,
                parts: [{ text: this.piiMasker.maskPII(item.text) }],
              });
            }
          }
        }

        const chatSession = model.startChat({
          history: formattedHistory,
        });

        // Gửi prompt người dùng (đã che PII)
        const safeUserMessage = this.piiMasker.maskPII(message);
        const resultStream = await chatSession.sendMessageStream(safeUserMessage);

        // Xử lý stream
        for await (const chunk of resultStream.stream) {
          // Kiểm tra client đã ngắt kết nối chưa
          if (signal?.aborted) {
            logger.info('[ChatbotService] Client đã ngắt kết nối — hủy luồng streaming.');
            break;
          }

          // 1. Kiểm tra Function Call (Tool call on-demand)
          const functionCalls = chunk.functionCalls();
          if (functionCalls && functionCalls.length > 0) {
            for (const call of functionCalls) {
              logger.info(`[Chatbot Function Call] Gemini kích hoạt tool: ${call.name}`);
              const toolResult = await this.toolsExecutor.executeTool(call.name, call.args, idaccount);

              // Bắn kết quả tool ngược lại cho session để Gemini tiếp tục suy luận
              const nextStream = await chatSession.sendMessageStream([
                {
                  functionResponse: {
                    name: call.name,
                    response: toolResult,
                  },
                },
              ]);

              for await (const nextChunk of nextStream.stream) {
                if (signal?.aborted) break;
                const text = nextChunk.text();
                if (text && typeof onChunk === 'function') {
                  onChunk(text);
                }
              }
            }
          } else {
            // 2. Stream các token text bình thường
            const text = chunk.text();
            if (text && typeof onChunk === 'function') {
              onChunk(text);
            }
          }
        }
      });

      const duration = Date.now() - startTime;
      logger.info(`[ChatbotService] Hoàn tất phiên chat streaming trong ${duration}ms`);

      if (typeof onDone === 'function') {
        onDone({ responseTimeMs: duration });
      }
    } catch (error) {
      const isCircuitOpen = error.name === 'CircuitBreakerOpenError';
      const reason = isCircuitOpen
        ? error.message
        : `Dịch vụ AI phản hồi chậm hoặc lỗi mạng: ${error.message}`;

      logger.warn('[ChatbotService] Kích hoạt Fallback Notice Stream do:', reason);
      try {
        const snapshot = await this.snapshotService.generateSnapshot(idaccount);
        return await this._streamFallbackResponse(message, snapshot, onChunk, onDone, reason);
      } catch (fbError) {
        logger.error('[ChatbotService] Lỗi fallback:', fbError);
        if (typeof onChunk === 'function') {
          onChunk(`\n⚠️ Sự cố kết nối: ${reason}. Dữ liệu của bạn an toàn, xin vui lòng thử lại sau giây lát.`);
        }
        if (typeof onDone === 'function') {
          onDone({ error: error.message });
        }
      }
    }
  }
}

module.exports = ChatbotService;
