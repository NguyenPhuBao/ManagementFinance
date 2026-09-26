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
   * Luồng phản hồi thông minh dự phòng khi chưa cấu hình GEMINI_API_KEY (hoặc môi trường offline)
   */
  async _streamFallbackResponse(message, snapshot, onChunk, onDone) {
    const score = snapshot.financialHealthScore || 70;
    const needs = snapshot.budgetAllocation?.needs_essential || '50%';
    const emergency = snapshot.liquidityAndObligations?.emergencyFundMonths || 1.5;

    const intro = `Chào bạn! Tôi là Cố vấn Tài chính FlowMoney (Chế độ Phân tích Cục bộ).\n\n`;
    const analysis = `Dựa trên bản chụp sức khỏe tài chính tháng này của bạn:\n` +
      `- Điểm sức khỏe tài chính (FHS): **${score}/100** điểm.\n` +
      `- Cơ cấu chi tiêu thiết yếu: **${needs}**.\n` +
      `- Quỹ dự phòng khẩn cấp: Đang duy trì được khoảng **${emergency} tháng** chi tiêu trung bình.\n\n`;
    const advice = `💡 **Khuyến nghị hành động:**\n` +
      `1. Tiếp tục duy trì tỷ lệ tích lũy ít nhất 15-20% thu nhập hàng tháng.\n` +
      `2. Kiểm tra các hóa đơn sắp đến hạn trong 7 ngày tới để tránh phí phạt trễ hạn.\n` +
      `3. Đặt ngưỡng cảnh báo ngân sách cho các danh mục chi tiêu lớn như Ăn uống và Mua sắm.`;

    const fullText = intro + analysis + advice;
    const tokens = fullText.split(' ');

    for (const token of tokens) {
      onChunk(token + ' ');
      await new Promise(r => setTimeout(r, 20));
    }

    onDone();
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
        logger.warn('[ChatbotService] GEMINI_API_KEY chưa cấu hình. Kích hoạt Fallback Analytics Stream.');
        return await this._streamFallbackResponse(message, snapshot, onChunk, onDone);
      }

      // BƯỚC 5: Gọi Google Gemini với Streaming & Function Calling
      const modelName = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
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

      const duration = Date.now() - startTime;
      logger.info(`[ChatbotService] Hoàn tất phiên chat streaming trong ${duration}ms`);

      if (typeof onDone === 'function') {
        onDone({ responseTimeMs: duration });
      }
    } catch (error) {
      logger.warn('[ChatbotService] Lỗi kết nối Gemini, tự động kích hoạt Fallback Analytics Stream:', error.message);
      try {
        const snapshot = await this.snapshotService.generateSnapshot(idaccount);
        return await this._streamFallbackResponse(message, snapshot, onChunk, onDone);
      } catch (fbError) {
        logger.error('[ChatbotService] Lỗi fallback:', fbError);
        if (typeof onChunk === 'function') {
          onChunk('\nRất tiếc, đã có sự cố gián đoạn kết nối. Xin vui lòng thử lại sau giây lát.');
        }
        if (typeof onDone === 'function') {
          onDone({ error: error.message });
        }
      }
    }
  }
}

module.exports = ChatbotService;
