/**
 * Nhà cung cấp LLM DeepSeek cho Chatbot AI — API tương thích OpenAI (`/chat/completions`), truyền dòng SSE.
 *
 * Thiết kế cho thực nghiệm:
 *  - Suy luận TẮT (`thinking: disabled`): để `temperature` có tác dụng và thời gian suy luận không cộng vào TTFT.
 *  - Không thêm phụ thuộc: dùng `fetch` có sẵn của Node.
 *  - Phát luồng sự kiện chuẩn hoá `{type:'text'} … {type:'done', finishReason, toolCalls, usage}` để lớp điều
 *    phối không phụ thuộc định dạng của nhà cung cấp.
 *  - Lỗi được phân loại: `retryable` (mạng, hết giờ, 429, 5xx) tính vào circuit breaker; lỗi 4xx còn lại là
 *    lỗi của phía mình, không được làm ngắt mạch cho mọi người dùng.
 * Nhật ký chỉ ghi số liệu, không bao giờ ghi nội dung câu hỏi / câu trả lời / khoá API.
 */

const DEFAULT_BASE_URL = 'https://api.deepseek.com';

class LlmProviderError extends Error {
  constructor(message, { status = null, retryable = false, code = 'LLM_PROVIDER_ERROR' } = {}) {
    super(message);
    this.name = 'LlmProviderError';
    this.status = status;
    this.retryable = retryable;
    this.code = code;
  }
}

/** Khai báo công cụ kiểu Gemini (`type: 'OBJECT'`) → JSON Schema chuẩn bọc `type: 'function'`. Không sửa bản gốc. */
function lowerSchemaTypes(node) {
  if (Array.isArray(node)) return node.map(lowerSchemaTypes);
  if (!node || typeof node !== 'object') return node;
  const out = {};
  for (const [key, value] of Object.entries(node)) {
    out[key] = key === 'type' && typeof value === 'string' ? value.toLowerCase() : lowerSchemaTypes(value);
  }
  return out;
}

function toOpenAiTools(declarations) {
  return declarations.map((d) => ({
    type: 'function',
    function: {
      name: d.name,
      description: d.description,
      parameters: lowerSchemaTypes(d.parameters || { type: 'OBJECT', properties: {} }),
    },
  }));
}

/**
 * @param {object} p
 * @param {string} p.apiKey
 * @param {string} p.model
 * @param {Array<object>} p.messages - định dạng OpenAI (system/user/assistant/tool)
 * @param {Array<object>} [p.tools] - đã qua toOpenAiTools
 * @param {string|object} [p.toolChoice='auto'] - hàm cụ thể cần ép gọi (cần suy luận tắt, xem tài liệu nhà cung cấp)
 * @param {number} p.maxTokens
 * @param {number} [p.temperature=0.1]
 * @param {AbortSignal} [p.signal] - huỷ do người dùng
 * @param {number} p.timeoutMs - trần cho cả lượt gọi
 * @param {string} [p.baseUrl]
 * @param {Function} [p.fetchImpl] - tiêm khi test
 * @returns {AsyncGenerator<object>}
 */
async function* streamDeepseek({
  apiKey,
  model,
  messages,
  tools,
  toolChoice = 'auto',
  maxTokens,
  temperature = 0.1,
  signal,
  timeoutMs,
  baseUrl = DEFAULT_BASE_URL,
  fetchImpl = fetch,
}) {
  const body = {
    model,
    messages,
    stream: true,
    stream_options: { include_usage: true },
    max_tokens: maxTokens,
    temperature,
    thinking: { type: 'disabled' },
  };
  if (tools && tools.length > 0) {
    body.tools = tools;
    body.tool_choice = toolChoice;
  }

  const signals = [AbortSignal.timeout(timeoutMs)];
  if (signal) signals.push(signal);
  const combined = AbortSignal.any(signals);

  const wrap = (err) => {
    if (signal?.aborted) return err; // người dùng huỷ: giữ nguyên, không phải lỗi dịch vụ
    if (err?.name === 'TimeoutError' || combined.aborted) {
      return new LlmProviderError('Dịch vụ AI phản hồi quá chậm', { retryable: true, code: 'TIMEOUT' });
    }
    return new LlmProviderError('Không kết nối được tới dịch vụ AI', { retryable: true, code: 'NETWORK' });
  };

  let res;
  try {
    res = await fetchImpl(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify(body),
      signal: combined,
    });
  } catch (err) {
    throw wrap(err);
  }

  if (!res.ok) {
    let detail = '';
    try {
      const parsed = JSON.parse(await res.text());
      detail = String(parsed?.error?.message || '').slice(0, 200);
    } catch (_) { /* thân không phải JSON */ }
    throw new LlmProviderError(`Dịch vụ AI trả lỗi HTTP ${res.status}${detail ? `: ${detail}` : ''}`, {
      status: res.status,
      retryable: res.status === 429 || res.status >= 500,
      code: 'HTTP_ERROR',
    });
  }

  const toolAcc = new Map();
  let finishReason = null;
  let usage = null;
  let finished = false;

  const handleLine = (line) => {
    if (!line.startsWith('data:')) return [];
    const payload = line.slice(5).trim();
    if (payload === '[DONE]') { finished = true; return []; }
    let json;
    try { json = JSON.parse(payload); } catch (_) { return []; }

    if (json.usage) usage = json.usage;
    const choice = json.choices?.[0];
    if (!choice) return [];
    if (choice.finish_reason) finishReason = choice.finish_reason;

    const events = [];
    const delta = choice.delta || {};
    if (typeof delta.content === 'string' && delta.content !== '') {
      events.push({ type: 'text', text: delta.content });
    }
    for (const tc of delta.tool_calls || []) {
      const index = tc.index ?? 0;
      const entry = toolAcc.get(index) || { id: '', name: '', args: '' };
      if (tc.id) entry.id = tc.id;
      if (tc.function?.name) entry.name += tc.function.name;
      if (tc.function?.arguments) entry.args += tc.function.arguments;
      toolAcc.set(index, entry);
    }
    return events;
  };

  try {
    const reader = res.body.getReader();
    const decoder = new TextDecoder('utf-8');
    let buffer = '';
    while (!finished) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      let newline;
      while ((newline = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, newline).replace(/\r$/, '');
        buffer = buffer.slice(newline + 1);
        for (const ev of handleLine(line)) yield ev;
      }
    }
    if (buffer.trim()) for (const ev of handleLine(buffer.trim())) yield ev;
  } catch (err) {
    throw wrap(err);
  }

  // Máy chủ đóng kết nối sớm: không có `finish_reason` lẫn `[DONE]` nên phần đã nhận là câu cụt, không phải lượt hoàn chỉnh.
  if (!finished && !finishReason) {
    throw new LlmProviderError('Dịch vụ AI đóng luồng giữa chừng', { retryable: true, code: 'STREAM_TRUNCATED' });
  }

  const toolCalls = [...toolAcc.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([, v]) => v)
    .filter((v) => v.name);

  yield { type: 'done', finishReason, toolCalls, usage };
}

module.exports = { streamDeepseek, LlmProviderError, toOpenAiTools, DEFAULT_BASE_URL };
