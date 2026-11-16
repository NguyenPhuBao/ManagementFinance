/**
 * Chatbot Service — Nhạc trưởng điều phối Trợ lý Tài chính AI
 * Dual-Phase Reasoning with Privacy Shield + Tools + RAG, truyền dòng (SSE).
 *
 * Nhà cung cấp LLM chọn qua `llm/provider.config.js` (CHATBOT_LLM_PROVIDER): DeepSeek (mặc định khi có khoá)
 * hoặc Gemini (đường cũ, giữ nguyên hành vi). Hai đường dùng chung: snapshot, RAG, prompt, che PII, giới hạn,
 * circuit breaker riêng của chatbot.
 */

const { GoogleGenerativeAI } = require('@google/generative-ai');
const { prisma } = require('../../../../config/db');
const FinancialSnapshotService = require('./snapshot/financial.snapshot.service');
const ToolsExecutor = require('./tools/tools.executor');
const { financialToolsDeclarations, KNOWLEDGE_TOOL_NAME } = require('./tools/financial.tools');
const LexicalKnowledgeSearch = require('./rag/lexical.search');
const PIIMasker = require('./privacy/pii.masker');
const { buildSystemPrompt } = require('./prompts/advisor.system.prompt');
const { chatbotCircuitBreaker } = require('./resilience/circuit-breaker');
const { getChatbotLimits } = require('./limits/chatbot.limits');
const { sanitizeHistory } = require('./limits/request-sanitizer');
const { usageToMicroUsd, estimateMicroUsd } = require('./limits/usage-cost');
const { streamDeepseek, toOpenAiTools, LlmProviderError } = require('./llm/deepseek.provider');
const { resolveProvider, getDeepseekConfig } = require('./llm/provider.config');
const logger = require('../../../../core/logger');

const TRUNCATED_NOTE = '\n\n(Câu trả lời dài hơn giới hạn nên bị cắt bớt. Bạn có thể hỏi tiếp phần còn lại.)';
const BROKEN_ARGS_RESULT = { error: 'Tham số công cụ bị hỏng hoặc thiếu. Gọi lại với đủ tham số hợp lệ nếu vẫn cần dữ liệu này.' };

/** Đối số do mô hình sinh: chỉ nhận object JSON. Bị cắt vì hết token, null, số, mảng… đều là hỏng. */
function parseToolArgs(raw) {
  if (raw === undefined || raw === null || raw === '') return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : null;
  } catch (_) {
    return null;
  }
}

class ChatbotService {
  constructor() {
    this.snapshotService = new FinancialSnapshotService();
    this.knowledgeSearch = new LexicalKnowledgeSearch();
    this.toolsExecutor = new ToolsExecutor({ knowledgeSearch: this.knowledgeSearch });
    this.piiMasker = new PIIMasker();
    this.breaker = chatbotCircuitBreaker;
    this.deepseekStream = streamDeepseek; // tiêm được khi test
    this.geminiClient = (apiKey) => new GoogleGenerativeAI(apiKey); // tiêm được khi test
  }

  /** Lấy bản chụp sức khỏe tài chính của người dùng (dùng nội bộ để dựng ngữ cảnh). */
  async getSnapshot(idaccount) {
    return await this.snapshotService.generateSnapshot(idaccount);
  }

  async _getUserName(idaccount) {
    try {
      if (!idaccount) return '';
      const user = await prisma.user.findFirst({ where: { idaccount }, select: { fullname: true } });
      return user?.fullname || '';
    } catch (err) {
      logger.debug('[ChatbotService] Không thể lấy thông tin user để mask PII:', err?.message);
      return '';
    }
  }

  /**
   * Báo dịch vụ AI không phản hồi: chỉ gửi `done{fallback, reason}`, không sinh chữ thay thế và không giả lập số liệu.
   * Client-app bỏ chữ của lượt này và rơi về AI trên máy; `/chat` trả 503.
   */
  _fallback({ reason, onDone }) {
    if (typeof onDone === 'function') {
      onDone({ fallback: true, reason: reason || 'Hệ thống AI tạm thời không phản hồi hoặc đang bảo trì.' });
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
   * @param {Function} [params.onTool] - Báo công cụ đang chạy: `{name, status: 'start'|'done'}`
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
    onUsage,
    onTool,
    turnCostCapMicroUsd,
    contextWindowDays,
    scopeNote,
  }) {
    const startTime = Date.now();
    const limits = getChatbotLimits();

    try {
      // BƯỚC 1: Bản chụp Sức khỏe Tài chính (Dual-Phase Shield: Phase 1). Cần họ tên trước để che PII trong tên danh mục.
      const userName = await this._getUserName(idaccount);
      const snapshot = await this.snapshotService.generateSnapshot(idaccount, { userName, windowDays: contextWindowDays });

      if (typeof onMeta === 'function') {
        onMeta({
          snapshotLoaded: !!snapshot,
          healthScore: snapshot ? snapshot.financialHealthScore : null,
          snapshot: snapshot || null,
        });
      }

      // BƯỚC 2: System Prompt. Tri thức tĩnh không chèn sẵn: mô hình tự gọi công cụ tra cứu khi cần.
      const systemInstruction = buildSystemPrompt(snapshot, { scopeNote });
      const safeHistory = sanitizeHistory(history, limits);

      // BƯỚC 3: Gọi nhà cung cấp LLM qua Circuit Breaker riêng của chatbot
      const provider = resolveProvider();
      const stats = { toolRounds: 0, lookups: 0, forcedLookup: false, citationAppended: false, truncated: false };
      const ctx = { message, safeHistory, systemInstruction, userName, idaccount, onChunk, onUsage, onTool, signal, limits, turnCostCapMicroUsd, stats };

      const callProvider = provider === 'deepseek'
        ? () => this._runDeepseek(ctx)
        : () => this._runGemini(ctx);

      if (provider === 'deepseek' ? !getDeepseekConfig().apiKey : !(process.env.GEMINI_API_KEY)) {
        logger.warn(`[ChatbotService] Chưa cấu hình khóa dịch vụ AI (${provider}). Kích hoạt dự phòng.`);
        return this._fallback({ reason: 'Hệ thống chưa thiết lập khóa dịch vụ AI', onDone });
      }

      await this.breaker.execute(callProvider, {
        // Không phản ánh sức khỏe dịch vụ: người dùng tự dừng, hoặc lỗi 4xx do phía mình gửi sai.
        boQuaLoi: (err) =>
          signal?.aborted === true ||
          err?.name === 'AbortError' ||
          (err instanceof LlmProviderError && !err.retryable),
      });

      if (signal?.aborted) return;

      const duration = Date.now() - startTime;
      logger.info(`[ChatbotService] Hoàn tất phiên chat streaming trong ${duration}ms`);
      if (typeof onDone === 'function') {
        onDone({ responseTimeMs: duration, ...stats });
      }
    } catch (error) {
      // Chỉ signal của client mới nghĩa là người dùng dừng. Hết giờ của nhà cung cấp phải đi nhánh dự phòng
      // để client có `done`, không thì luồng treo tới khi client tự bỏ.
      if (signal?.aborted) {
        logger.info('[ChatbotService] Client đã ngắt kết nối hoặc hủy request — bỏ qua xử lý dự phòng.');
        return;
      }
      const isCircuitOpen = error.name === 'CircuitBreakerOpenError';
      const reason = isCircuitOpen ? error.message : 'Dịch vụ AI phản hồi chậm hoặc lỗi mạng';
      logger.warn('[ChatbotService] Kích hoạt dự phòng do:', { circuitOpen: isCircuitOpen, error: error.message });
      try {
        return this._fallback({ reason, onDone });
      } catch (fbError) {
        logger.error('[ChatbotService] Lỗi dự phòng:', fbError);
        if (typeof onDone === 'function') onDone({ error: error.message });
      }
    }
  }

  // ───────────────────────────── DeepSeek (OpenAI-compatible) ─────────────────────────────

  /**
   * Bảo đảm trích nguồn: nếu lượt này đã tra được tri thức mà câu trả lời không nêu nguồn nào trong số đó thì gửi thêm
   * nguồn thật. Chữ đã truyền dòng không rút lại được nên chỉ có thể bổ sung ở cuối, và nằm ở đây để hai cách phân phối
   * nhận cùng một nội dung.
   */
  _appendMissingCitation({ citations, turnText, onChunk, stats }) {
    const distinct = [...new Set(citations)];
    if (distinct.length === 0) return;
    // Mô hình đã nói kho không có nội dung đúng câu hỏi (luật trong prompt): gắn nguồn lúc này là trích dẫn sai.
    if (/chưa có (nội dung|thông tin)/i.test(turnText)) return;
    const cited = distinct.some((c) => turnText.includes(c.slice('[Nguồn: '.length, -1)));
    if (cited) return;
    stats.citationAppended = true;
    if (typeof onChunk === 'function') onChunk(`\n\n${distinct.join(' ')}`);
  }

  async _runDeepseek({ message, safeHistory, systemInstruction, userName, idaccount, onChunk, onUsage, onTool, signal, limits, turnCostCapMicroUsd, stats }) {
    const cfg = getDeepseekConfig();
    const turnCap = turnCostCapMicroUsd ?? limits.maxTurnCostMicroUsd;
    const tools = toOpenAiTools(financialToolsDeclarations);

    const messages = [{ role: 'system', content: systemInstruction }];
    const history = safeHistory.slice();
    while (history.length > 0 && history[0].role !== 'user') history.shift();
    for (const item of history) {
      messages.push({
        role: item.role === 'model' ? 'assistant' : 'user',
        content: this.piiMasker.maskPII(item.text, { userName }),
      });
    }
    const maskedMessage = this.piiMasker.maskPII(message, { userName });
    messages.push({ role: 'user', content: maskedMessage });

    // Ép phải quyết định TRƯỚC vòng đầu: chữ đã truyền dòng thì không thu hồi được để tra rồi trả lời lại.
    stats.forcedLookup = this.knowledgeSearch.shouldForceLookup(maskedMessage);
    const citations = [];
    let turnText = '';

    let turnCostMicroUsd = 0;
    const report = async (round, usage, promptChars, outputChars) => {
      const estimated = !usage;
      const entry = {
        provider: 'deepseek',
        model: cfg.model,
        round,
        promptTokens: usage?.prompt_tokens ?? null,
        completionTokens: usage?.completion_tokens ?? null,
        cacheHitTokens: usage?.prompt_cache_hit_tokens ?? null,
        costMicroUsd: estimated ? estimateMicroUsd({ promptChars, outputChars }) : usageToMicroUsd(usage),
        ...(estimated ? { estimated: true } : {}),
      };
      turnCostMicroUsd += entry.costMicroUsd;
      logger.info('[Chatbot LLM] usage', entry); // chỉ số liệu, không nội dung
      if (typeof onUsage === 'function') {
        try { await onUsage(entry); } catch (err) { logger.warn('[Chatbot LLM] onUsage lỗi:', err?.message); }
      }
    };

    for (let round = 0; ; round++) {
      // Đa bước: còn vòng và lượt này chưa vượt trần chi phí thì mô hình được tiếp tục gọi công cụ.
      const allowTools = round < limits.maxToolRounds && turnCostMicroUsd < turnCap;
      let roundText = '';
      let final = null;
      let received = false;
      // Nhà cung cấp chỉ gửi `usage` ở khung cuối: lượt bị huỷ hoặc đứt giữa chừng vẫn tốn tiền nên phải ước tính.
      const promptChars = JSON.stringify(messages).length + (allowTools ? JSON.stringify(tools).length : 0);

      try {
        for await (const ev of this.deepseekStream({
          apiKey: cfg.apiKey,
          baseUrl: cfg.baseUrl,
          model: cfg.model,
          messages,
          tools: allowTools ? tools : undefined,
          toolChoice: allowTools && round === 0 && stats.forcedLookup
            ? { type: 'function', function: { name: KNOWLEDGE_TOOL_NAME } }
            : undefined,
          maxTokens: limits.maxOutputTokens,
          signal,
          timeoutMs: limits.llmTimeoutMs,
        })) {
          received = true;
          if (signal?.aborted) break;
          if (ev.type === 'text') {
            roundText += ev.text;
            turnText += ev.text;
            if (typeof onChunk === 'function') onChunk(ev.text);
          } else if (ev.type === 'done') {
            final = ev;
          }
        }
      } catch (err) {
        // Chưa nhận được gì và không phải do huỷ (kết nối hỏng, HTTP lỗi): nhà cung cấp chưa sinh gì để tính tiền.
        if (received || signal?.aborted) await report(round, null, promptChars, roundText.length);
        throw err;
      }

      await report(round, final?.usage || null, promptChars, roundText.length);
      if (signal?.aborted) return;

      const calls = (final?.toolCalls || []).slice(0, limits.maxToolCallsPerRound);
      if (!allowTools || calls.length === 0) {
        if (!['stop', 'tool_calls', null, undefined].includes(final?.finishReason)) {
          stats.truncated = true;
          if (typeof onChunk === 'function') onChunk(TRUNCATED_NOTE);
        }
        this._appendMissingCitation({ citations, turnText, onChunk, stats });
        return;
      }

      stats.toolRounds += 1;
      const parsedCalls = calls.map((call) => ({ ...call, parsed: parseToolArgs(call.args) }));
      messages.push({
        role: 'assistant',
        content: roundText,
        // Gửi lại đối số hỏng có thể bị nhà cung cấp từ chối cả lượt nên thay bằng object rỗng.
        tool_calls: parsedCalls.map((c) => ({
          id: c.id,
          type: 'function',
          function: { name: c.name, arguments: c.parsed ? (c.args || '{}') : '{}' },
        })),
      });

      for (const call of parsedCalls) {
        if (signal?.aborted) return;
        logger.info(`[Chatbot Function Call] Mô hình kích hoạt tool: ${call.name}`);
        if (!call.parsed) {
          messages.push({ role: 'tool', tool_call_id: call.id, content: JSON.stringify(BROKEN_ARGS_RESULT) });
          continue;
        }
        const args = call.parsed;
        const isLookup = call.name === KNOWLEDGE_TOOL_NAME;
        if (isLookup) {
          stats.lookups += 1;
          if (typeof args.query !== 'string' || !args.query.trim()) args.query = maskedMessage;
        }
        if (typeof onTool === 'function') onTool({ name: call.name, status: 'start' });
        const result = await this.toolsExecutor.executeTool(call.name, args, idaccount, { userName, maxResultChars: limits.maxToolResultChars });
        if (typeof onTool === 'function') {
          // NCKH (v4): sự kiện done của tra cứu mang chẩn đoán truy hồi như bản thực nghiệm (client chỉ đọc name / status, bỏ qua trường lạ).
          const retrieval = isLookup ? this.toolsExecutor.lastRetrieval : null;
          onTool(retrieval ? { name: call.name, status: 'done', retrieval } : { name: call.name, status: 'done' });
        }
        // Chỉ lấy nguồn của đoạn đứng đầu: các đoạn xếp sau có thể lệch chủ đề, gắn vào sẽ thành trích dẫn sai.
        if (isLookup && result?.found) citations.push(result.results[0].citation);
        let content = JSON.stringify(result);
        if (content.length > limits.maxToolResultChars) {
          content = `${content.slice(0, limits.maxToolResultChars)}…[đã cắt bớt]`;
        }
        messages.push({ role: 'tool', tool_call_id: call.id, content });
      }
    }
  }

  // ───────────────────────────── Gemini (đường cũ, giữ nguyên hành vi) ─────────────────────────────

  async _runGemini({ message, safeHistory, systemInstruction, userName, idaccount, onChunk, onUsage, signal, limits, stats }) {
    const apiKey = process.env.GEMINI_API_KEY;
    const modelName = process.env.GEMINI_MODEL || require('../../config').DEFAULT_GEMINI_MODEL;
    const genAI = this.geminiClient(apiKey);
    const model = genAI.getGenerativeModel({
      model: modelName,
      systemInstruction,
      generationConfig: {
        temperature: 0.1, // Chống ảo giác
        maxOutputTokens: limits.maxOutputTokens,
      },
      tools: [{ functionDeclarations: financialToolsDeclarations }],
    });

    const formattedHistory = [];
    for (const item of safeHistory) {
      formattedHistory.push({
        role: item.role,
        parts: [{ text: this.piiMasker.maskPII(item.text, { userName }) }],
      });
    }
    // SDK Gemini yêu cầu turn đầu tiên phải là 'user'
    while (formattedHistory.length > 0 && formattedHistory[0].role !== 'user') {
      formattedHistory.shift();
    }

    const chatSession = model.startChat({ history: formattedHistory });
    const reqOptions = { timeout: limits.llmTimeoutMs };
    if (signal) reqOptions.signal = signal;

    const safeUserMessage = this.piiMasker.maskPII(message, { userName });
    const citations = [];
    let turnText = '';
    let promptChars = systemInstruction.length + JSON.stringify(formattedHistory).length + safeUserMessage.length;
    const emit = (text) => {
      turnText += text;
      if (typeof onChunk === 'function') onChunk(text);
    };

    try {
      await this._streamGemini({ chatSession, safeUserMessage, reqOptions, idaccount, userName, signal, limits, stats, citations, emit, addPromptChars: (n) => { promptChars += n; } });
    } finally {
      // Đường này chưa đọc `usageMetadata`: tính theo ước lượng để ngân sách tháng vẫn là trần cứng.
      if (typeof onUsage === 'function') {
        const costMicroUsd = estimateMicroUsd({ promptChars, outputChars: turnText.length });
        try { await onUsage({ provider: 'gemini', model: modelName, costMicroUsd, estimated: true }); } catch (err) { logger.warn('[Chatbot LLM] onUsage lỗi:', err?.message); }
      }
    }
    if (!signal?.aborted) this._appendMissingCitation({ citations, turnText, onChunk, stats });
  }

  async _streamGemini({ chatSession, safeUserMessage, reqOptions, idaccount, userName, signal, limits, stats, citations, emit, addPromptChars }) {
    const resultStream = await chatSession.sendMessageStream(safeUserMessage, reqOptions);

    for await (const chunk of resultStream.stream) {
      if (signal?.aborted) {
        logger.info('[ChatbotService] Client đã ngắt kết nối — hủy luồng streaming.');
        break;
      }

      const functionCalls = chunk.functionCalls();
      if (functionCalls && functionCalls.length > 0) {
        for (const call of functionCalls.slice(0, limits.maxToolCallsPerRound)) {
          if (signal?.aborted) break;
          logger.info(`[Chatbot Function Call] Mô hình kích hoạt tool: ${call.name}`);
          const isLookup = call.name === KNOWLEDGE_TOOL_NAME;
          if (isLookup) stats.lookups += 1;
          const toolResult = await this.toolsExecutor.executeTool(call.name, call.args, idaccount, { userName, maxResultChars: limits.maxToolResultChars });
          if (isLookup && toolResult?.found) citations.push(toolResult.results[0].citation);
          addPromptChars(JSON.stringify(toolResult).length);
          if (signal?.aborted) break;

          const nextStream = await chatSession.sendMessageStream([
            { functionResponse: { name: call.name, response: toolResult } },
          ], reqOptions);

          for await (const nextChunk of nextStream.stream) {
            if (signal?.aborted) break;
            const text = nextChunk.text();
            if (text) emit(text);
          }
        }
      } else {
        const text = chunk.text();
        if (text) emit(text);
      }
    }
  }
}

module.exports = ChatbotService;
