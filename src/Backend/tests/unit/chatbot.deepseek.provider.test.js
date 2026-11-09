/**
 * Unit Test — Tầng nhà cung cấp LLM DeepSeek (R&D): yêu cầu gửi đi, phân tích luồng SSE kiểu OpenAI,
 * ghép lời gọi công cụ bị chia nhiều mảnh, phân loại lỗi, chuyển khai báo công cụ.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const {
  streamDeepseek,
  LlmProviderError,
  toOpenAiTools,
} = require('../../modules/ai/features/chatbot/llm/deepseek.provider');
const { financialToolsDeclarations } = require('../../modules/ai/features/chatbot/tools/financial.tools');

/** Dựng Response giả có thân là luồng SSE, cắt nhỏ ở vị trí tuỳ ý để thử ghép mảnh. */
function sseResponse(frames, { status = 200, chunkSize = 17 } = {}) {
  const body = frames.map((f) => `data: ${typeof f === 'string' ? f : JSON.stringify(f)}\n\n`).join('');
  const bytes = new TextEncoder().encode(body);
  const stream = new ReadableStream({
    start(controller) {
      for (let i = 0; i < bytes.length; i += chunkSize) controller.enqueue(bytes.slice(i, i + chunkSize));
      controller.close();
    },
  });
  return new Response(stream, { status, headers: { 'Content-Type': 'text/event-stream' } });
}

async function collect(gen) {
  const events = [];
  for await (const ev of gen) events.push(ev);
  return events;
}

const baseArgs = {
  apiKey: 'sk-test',
  model: 'deepseek-flash',
  messages: [{ role: 'user', content: 'hi' }],
  maxTokens: 512,
  timeoutMs: 5000,
};

describe('toOpenAiTools — chuyển khai báo công cụ kiểu Gemini sang JSON Schema chuẩn', () => {
  it('1. Kiểu viết thường, bọc type=function, giữ tên và mô tả', () => {
    const tools = toOpenAiTools(financialToolsDeclarations);
    assert.strictEqual(tools.length, financialToolsDeclarations.length);
    for (const t of tools) {
      assert.strictEqual(t.type, 'function');
      assert.ok(t.function.name && t.function.description);
      assert.strictEqual(t.function.parameters.type, 'object');
    }
    const cat = tools.find((t) => t.function.name === 'get_category_transactions');
    assert.strictEqual(cat.function.parameters.properties.limit.type, 'integer');
    assert.strictEqual(cat.function.parameters.properties.categoryName.type, 'string');
    assert.deepStrictEqual(cat.function.parameters.required, ['categoryName']);
  });

  it('2. Không làm thay đổi khai báo gốc', () => {
    toOpenAiTools(financialToolsDeclarations);
    assert.strictEqual(financialToolsDeclarations[0].parameters.type, 'OBJECT');
  });
});

describe('streamDeepseek — yêu cầu gửi đi', () => {
  it('1. Tắt suy luận, đặt trần token, bật usage, nhiệt độ thấp, đúng URL và khoá', async () => {
    let captured;
    const fetchImpl = async (url, init) => {
      captured = { url, init, body: JSON.parse(init.body) };
      return sseResponse([{ choices: [{ delta: { content: 'ok' }, finish_reason: 'stop' }] }, '[DONE]']);
    };
    await collect(streamDeepseek({ ...baseArgs, fetchImpl }));
    assert.strictEqual(captured.url, 'https://api.deepseek.com/chat/completions');
    assert.strictEqual(captured.init.headers.Authorization, 'Bearer sk-test');
    assert.strictEqual(captured.body.model, 'deepseek-flash');
    assert.deepStrictEqual(captured.body.thinking, { type: 'disabled' });
    assert.strictEqual(captured.body.max_tokens, 512);
    assert.strictEqual(captured.body.stream, true);
    assert.deepStrictEqual(captured.body.stream_options, { include_usage: true });
    assert.strictEqual(captured.body.temperature, 0.1);
    assert.strictEqual(captured.body.tools, undefined);
  });

  it('2. Có công cụ thì gửi tools và tool_choice=auto', async () => {
    let body;
    const fetchImpl = async (url, init) => {
      body = JSON.parse(init.body);
      return sseResponse(['[DONE]']);
    };
    await collect(streamDeepseek({ ...baseArgs, tools: toOpenAiTools(financialToolsDeclarations), fetchImpl }));
    assert.ok(Array.isArray(body.tools) && body.tools.length === financialToolsDeclarations.length);
    assert.strictEqual(body.tool_choice, 'auto');
  });
});

describe('streamDeepseek — phân tích luồng', () => {
  it('1. Phát từng mẩu chữ rồi sự kiện done kèm usage', async () => {
    const fetchImpl = async () => sseResponse([
      { choices: [{ delta: { content: 'Xin ' } }] },
      { choices: [{ delta: { content: 'chào' } }] },
      { choices: [{ delta: {}, finish_reason: 'stop' }], usage: { prompt_tokens: 120, completion_tokens: 5, prompt_cache_hit_tokens: 100 } },
      '[DONE]',
    ]);
    const events = await collect(streamDeepseek({ ...baseArgs, fetchImpl }));
    const text = events.filter((e) => e.type === 'text').map((e) => e.text).join('');
    assert.strictEqual(text, 'Xin chào');
    const done = events[events.length - 1];
    assert.strictEqual(done.type, 'done');
    assert.strictEqual(done.finishReason, 'stop');
    assert.deepStrictEqual(done.toolCalls, []);
    assert.strictEqual(done.usage.prompt_tokens, 120);
  });

  it('2. Ghép lời gọi công cụ bị chia thành nhiều mảnh (arguments từng phần)', async () => {
    const fetchImpl = async () => sseResponse([
      { choices: [{ delta: { tool_calls: [{ index: 0, id: 'call_1', type: 'function', function: { name: 'get_bill_details', arguments: '' } }] } }] },
      { choices: [{ delta: { tool_calls: [{ index: 0, function: { arguments: '{"status":"Pen' } }] } }] },
      { choices: [{ delta: { tool_calls: [{ index: 0, function: { arguments: 'ding","daysAhead":7}' } }] } }] },
      { choices: [{ delta: { tool_calls: [{ index: 1, id: 'call_2', type: 'function', function: { name: 'compare_spending_periods', arguments: '{}' } }] } }] },
      { choices: [{ delta: {}, finish_reason: 'tool_calls' }] },
      '[DONE]',
    ], { chunkSize: 9 });
    const events = await collect(streamDeepseek({ ...baseArgs, fetchImpl }));
    const done = events[events.length - 1];
    assert.strictEqual(done.finishReason, 'tool_calls');
    assert.strictEqual(done.toolCalls.length, 2);
    assert.deepStrictEqual(done.toolCalls[0], { id: 'call_1', name: 'get_bill_details', args: '{"status":"Pending","daysAhead":7}' });
    assert.strictEqual(done.toolCalls[1].name, 'compare_spending_periods');
  });

  it('3. Bỏ qua dòng chú thích và khung JSON hỏng, luồng vẫn đi tiếp', async () => {
    const fetchImpl = async () => {
      const body = ': ping\n\ndata: {khong-phai-json\n\n' +
        `data: ${JSON.stringify({ choices: [{ delta: { content: 'A' }, finish_reason: 'stop' }] })}\n\ndata: [DONE]\n\n`;
      return new Response(body, { status: 200 });
    };
    const events = await collect(streamDeepseek({ ...baseArgs, fetchImpl }));
    assert.strictEqual(events.filter((e) => e.type === 'text').map((e) => e.text).join(''), 'A');
  });
});

describe('streamDeepseek — lỗi', () => {
  it('1. HTTP 429 và 5xx là lỗi có thể thử lại', async () => {
    for (const status of [429, 500, 503]) {
      const fetchImpl = async () => new Response(JSON.stringify({ error: { message: 'busy' } }), { status });
      await assert.rejects(collect(streamDeepseek({ ...baseArgs, fetchImpl })), (e) => {
        assert.ok(e instanceof LlmProviderError);
        assert.strictEqual(e.status, status);
        assert.strictEqual(e.retryable, true);
        return true;
      });
    }
  });

  it('2. HTTP 400/401/402 là lỗi của phía mình, không thử lại', async () => {
    for (const status of [400, 401, 402]) {
      const fetchImpl = async () => new Response('{}', { status });
      await assert.rejects(collect(streamDeepseek({ ...baseArgs, fetchImpl })), (e) => {
        assert.strictEqual(e.retryable, false);
        assert.strictEqual(e.status, status);
        return true;
      });
    }
  });

  it('3. Lỗi mạng là lỗi có thể thử lại', async () => {
    const fetchImpl = async () => { throw new TypeError('fetch failed'); };
    await assert.rejects(collect(streamDeepseek({ ...baseArgs, fetchImpl })), (e) => e instanceof LlmProviderError && e.retryable === true);
  });

  it('4. Người dùng huỷ (signal) thì ném AbortError gốc, không bọc thành lỗi nhà cung cấp', async () => {
    const ac = new AbortController();
    ac.abort();
    const fetchImpl = async (url, init) => {
      if (init.signal.aborted) { const e = new Error('aborted'); e.name = 'AbortError'; throw e; }
      return sseResponse(['[DONE]']);
    };
    await assert.rejects(collect(streamDeepseek({ ...baseArgs, signal: ac.signal, fetchImpl })), (e) => e.name === 'AbortError' && !(e instanceof LlmProviderError));
  });

  it('5. Thông báo lỗi không chứa khoá API', async () => {
    const fetchImpl = async () => new Response('{}', { status: 401 });
    await assert.rejects(collect(streamDeepseek({ ...baseArgs, fetchImpl })), (e) => !String(e.message).includes('sk-test'));
  });
});
