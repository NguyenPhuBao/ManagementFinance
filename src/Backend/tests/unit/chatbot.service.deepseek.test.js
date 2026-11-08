/**
 * Unit Test — ChatbotService với nhà cung cấp DeepSeek (R&D)
 * Phủ: vòng gọi công cụ (một bước = bản đối chứng, đa bước = biến thực nghiệm), trần số lời gọi,
 * rơi về dự phòng không gửi chữ qua SSE, circuit breaker chỉ đếm lỗi dịch vụ, chọn nhà cung cấp.
 */

const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

const ChatbotService = require('../../modules/ai/features/chatbot/chatbot.service');
const { CircuitBreaker } = require('../../modules/ai/features/chatbot/resilience/circuit-breaker');
const { LlmProviderError } = require('../../modules/ai/features/chatbot/llm/deepseek.provider');
const { resolveProvider } = require('../../modules/ai/features/chatbot/llm/provider.config');

const ENV_KEYS = ['CHATBOT_LLM_PROVIDER', 'DEEPSEEK_API_KEY', 'DEEPSEEK_MODEL', 'AI_MAX_TOOL_ROUNDS', 'AI_MAX_TOOL_CALLS_PER_ROUND', 'AI_MAX_OUTPUT_TOKENS', 'AI_MAX_TURN_COST_MICRO_USD'];

function makeService({ rounds, toolResult = { ok: true } }) {
  const svc = new ChatbotService();
  svc.snapshotService = { generateSnapshot: async () => null };
  svc.toolsExecutor = { executeTool: async (name, args) => { svc._toolLog.push({ name, args }); return toolResult; } };
  svc._getUserName = async () => '';
  svc.breaker = new CircuitBreaker({ failureThreshold: 2, cooldownPeriodMs: 60000, windowMs: 60000 });
  svc._toolLog = [];
  svc._requests = [];
  let i = 0;
  svc.deepseekStream = async function* (args) {
    svc._requests.push(args);
    const step = rounds[Math.min(i++, rounds.length - 1)];
    if (step instanceof Error) throw step;
    for (const ev of step) yield ev;
  };
  return svc;
}

const text = (t) => ({ type: 'text', text: t });
const done = (extra = {}) => ({ type: 'done', finishReason: 'stop', toolCalls: [], usage: { prompt_tokens: 10, completion_tokens: 2 }, ...extra });
const toolDone = (calls) => ({ type: 'done', finishReason: 'tool_calls', toolCalls: calls, usage: null });

async function run(svc, over = {}) {
  const chunks = [];
  let doneArg;
  await svc.chatStream({
    message: 'Tháng này tôi chi bao nhiêu?',
    history: [{ role: 'user', text: 'chào' }, { role: 'model', text: 'chào bạn' }],
    idaccount: 5,
    onChunk: (c) => chunks.push(c),
    onDone: (d) => { doneArg = d; },
    ...over,
  });
  return { chunks, done: doneArg };
}

describe('resolveProvider — chọn nhà cung cấp cho Chatbot', () => {
  it('1. Chỉ định rõ thì theo chỉ định', () => {
    assert.strictEqual(resolveProvider({ CHATBOT_LLM_PROVIDER: 'gemini', DEEPSEEK_API_KEY: 'k' }), 'gemini');
    assert.strictEqual(resolveProvider({ CHATBOT_LLM_PROVIDER: 'deepseek' }), 'deepseek');
  });
  it('2. Không chỉ định: có khoá DeepSeek thì dùng DeepSeek, không thì giữ Gemini (không vỡ khi chưa cấu hình)', () => {
    assert.strictEqual(resolveProvider({ DEEPSEEK_API_KEY: 'k' }), 'deepseek');
    assert.strictEqual(resolveProvider({}), 'gemini');
  });
});

describe('ChatbotService (DeepSeek)', () => {
  const saved = {};
  beforeEach(() => {
    ENV_KEYS.forEach((k) => { saved[k] = process.env[k]; delete process.env[k]; });
    process.env.CHATBOT_LLM_PROVIDER = 'deepseek';
    process.env.DEEPSEEK_API_KEY = 'sk-test';
  });
  afterEach(() => ENV_KEYS.forEach((k) => { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }));

  it('1. Lượt thường: truyền từng mẩu chữ, gửi system + lịch sử (model→assistant) + câu hỏi, tắt suy luận qua provider', async () => {
    const svc = makeService({ rounds: [[text('Bạn '), text('đã chi 2 triệu'), done()]] });
    const { chunks, done: d } = await run(svc);
    assert.deepStrictEqual(chunks, ['Bạn ', 'đã chi 2 triệu']);
    assert.ok(typeof d.responseTimeMs === 'number');
    const req = svc._requests[0];
    assert.strictEqual(req.model, 'deepseek-flash');
    assert.strictEqual(req.messages[0].role, 'system');
    assert.deepStrictEqual(req.messages.slice(1).map((m) => m.role), ['user', 'assistant', 'user']);
    assert.strictEqual(req.maxTokens, 1024);
    assert.ok(Array.isArray(req.tools) && req.tools.length === 5);
  });

  it('1c. MẶC ĐỊNH là đa bước: công cụ nối tiếp 3 vòng rồi mới trả lời, không dừng ở bước 2', async () => {
    const svc = makeService({
      rounds: [
        [toolDone([{ id: 'c1', name: 'compare_spending_periods', args: '{}' }])],
        [toolDone([{ id: 'c2', name: 'get_goal_simulation', args: '{"goalName":"xe"}' }])],
        [toolDone([{ id: 'c3', name: 'get_bill_details', args: '{}' }])],
        [text('Đã có đủ số liệu.'), done()],
      ],
    });
    const { chunks } = await run(svc);
    assert.deepStrictEqual(svc._toolLog.map((t) => t.name), ['compare_spending_periods', 'get_goal_simulation', 'get_bill_details']);
    assert.strictEqual(svc._requests.length, 4);
    assert.ok(svc._requests.slice(0, 3).every((r) => r.tools), 'ba vòng đầu vẫn được khai công cụ');
    assert.strictEqual(chunks.join(''), 'Đã có đủ số liệu.');
  });

  it('1d. Chặn vòng lặp bằng CHI PHÍ mỗi lượt: vượt trần thì vòng sau không khai công cụ nhưng vẫn trả lời', async () => {
    process.env.AI_MAX_TURN_COST_MICRO_USD = '1000';
    const expensive = { prompt_tokens: 6000, prompt_cache_miss_tokens: 6000, prompt_cache_hit_tokens: 0, completion_tokens: 100 }; // ≈ 1920 µ$
    const svc = makeService({
      rounds: [
        [{ type: 'done', finishReason: 'tool_calls', toolCalls: [{ id: 'c1', name: 'get_bill_details', args: '{}' }], usage: expensive }],
        [text('Trả lời với dữ liệu đã có.'), done()],
      ],
    });
    const { chunks } = await run(svc);
    assert.strictEqual(svc._requests.length, 2);
    assert.strictEqual(svc._requests[1].tools, undefined, 'đã vượt trần chi phí lượt: không cho gọi công cụ nữa');
    assert.strictEqual(chunks.join(''), 'Trả lời với dữ liệu đã có.');
  });

  it('2. Cấu hình một vòng (AI_MAX_TOOL_ROUNDS=1): chạy công cụ, vòng hai KHÔNG khai công cụ, trả lời cuối', async () => {
    process.env.AI_MAX_TOOL_ROUNDS = '1';
    const svc = makeService({
      rounds: [
        [text('Để mình tra. '), toolDone([{ id: 'c1', name: 'get_bill_details', args: '{"daysAhead":7}' }])],
        [text('Có 2 hóa đơn sắp tới hạn.'), done()],
      ],
    });
    const { chunks } = await run(svc);
    assert.deepStrictEqual(svc._toolLog, [{ name: 'get_bill_details', args: { daysAhead: 7 } }]);
    assert.strictEqual(svc._requests.length, 2);
    assert.strictEqual(svc._requests[1].tools, undefined, 'vòng hai không được khai công cụ khi maxToolRounds = 1');
    const msgs = svc._requests[1].messages;
    const assistant = msgs.find((m) => m.role === 'assistant' && m.tool_calls);
    assert.strictEqual(assistant.tool_calls[0].id, 'c1');
    assert.strictEqual(assistant.tool_calls[0].function.name, 'get_bill_details');
    const tool = msgs.find((m) => m.role === 'tool');
    assert.strictEqual(tool.tool_call_id, 'c1');
    assert.deepStrictEqual(JSON.parse(tool.content), { ok: true });
    assert.strictEqual(chunks.join(''), 'Để mình tra. Có 2 hóa đơn sắp tới hạn.');
  });

  it('3. Đa bước (AI_MAX_TOOL_ROUNDS=2): vòng hai vẫn được gọi công cụ tiếp', async () => {
    process.env.AI_MAX_TOOL_ROUNDS = '2';
    const svc = makeService({
      rounds: [
        [toolDone([{ id: 'c1', name: 'compare_spending_periods', args: '{}' }])],
        [toolDone([{ id: 'c2', name: 'get_goal_simulation', args: '{"goalName":"xe"}' }])],
        [text('Xong.'), done()],
      ],
    });
    await run(svc);
    assert.deepStrictEqual(svc._toolLog.map((t) => t.name), ['compare_spending_periods', 'get_goal_simulation']);
    assert.ok(svc._requests[1].tools, 'vòng hai còn khai công cụ');
    assert.strictEqual(svc._requests[2].tools, undefined, 'vòng ba hết quyền gọi công cụ');
  });

  it('4. Trần số lời gọi công cụ mỗi vòng', async () => {
    process.env.AI_MAX_TOOL_CALLS_PER_ROUND = '2';
    const calls = [1, 2, 3, 4, 5].map((n) => ({ id: `c${n}`, name: 'get_bill_details', args: '{}' }));
    const svc = makeService({ rounds: [[toolDone(calls)], [text('ok'), done()]] });
    await run(svc);
    assert.strictEqual(svc._toolLog.length, 2);
    const assistant = svc._requests[1].messages.find((m) => m.tool_calls);
    assert.strictEqual(assistant.tool_calls.length, 2);
  });

  it('5. Đối số công cụ hỏng JSON: không chạy công cụ (tránh truy vấn sai), báo lỗi cho mô hình, không vỡ lượt', async () => {
    const svc = makeService({ rounds: [[toolDone([{ id: 'c1', name: 'get_bill_details', args: '{hong' }])], [text('ok'), done()]] });
    const { chunks } = await run(svc);
    assert.strictEqual(svc._toolLog.length, 0);
    assert.ok(JSON.parse(svc._requests[1].messages.find((m) => m.role === 'tool').content).error);
    assert.strictEqual(chunks.join(''), 'ok');
  });

  it('6. Kết quả công cụ quá dài bị cắt để chặn token', async () => {
    const svc = makeService({
      toolResult: { blob: 'x'.repeat(100000) },
      rounds: [[toolDone([{ id: 'c1', name: 'get_bill_details', args: '{}' }])], [text('ok'), done()]],
    });
    await run(svc);
    const tool = svc._requests[1].messages.find((m) => m.role === 'tool');
    assert.ok(tool.content.length <= 2600, `kết quả công cụ phải bị cắt ở ~2500 ký tự, thực tế ${tool.content.length}`);
  });

  it('7. Lỗi dịch vụ (retryable): chỉ báo done{fallback}, KHÔNG sinh chữ, lý do không nêu tên nhà cung cấp', async () => {
    const svc = makeService({ rounds: [new LlmProviderError('x', { status: 503, retryable: true })] });
    const { chunks, done: d } = await run(svc);
    assert.deepStrictEqual(chunks, []);
    assert.strictEqual(d.fallback, true);
    assert.ok(typeof d.reason === 'string' && d.reason.length > 0);
    assert.ok(!/gemini|deepseek|google/i.test(d.reason));
  });

  it('9. Circuit breaker: lỗi 4xx của phía mình KHÔNG được đếm, lỗi dịch vụ thì đếm', async () => {
    const svc = makeService({ rounds: [new LlmProviderError('bad', { status: 400, retryable: false })] });
    await run(svc);
    assert.strictEqual(svc.breaker.failureCount, 0);

    const svc2 = makeService({ rounds: [new LlmProviderError('busy', { status: 503, retryable: true })] });
    await run(svc2);
    assert.strictEqual(svc2.breaker.failureCount, 1);
  });

  it('10. Breaker mở thì rơi về dự phòng ngay, không gọi nhà cung cấp', async () => {
    const svc = makeService({ rounds: [new LlmProviderError('busy', { status: 503, retryable: true })] });
    await run(svc);
    await run(svc); // đủ 2 lỗi → mở
    const before = svc._requests.length;
    const { done: d } = await run(svc);
    assert.strictEqual(svc._requests.length, before);
    assert.strictEqual(d.fallback, true);
  });

  it('11. Thiếu khoá DeepSeek thì rơi về dự phòng, không gọi mạng', async () => {
    delete process.env.DEEPSEEK_API_KEY;
    const svc = makeService({ rounds: [[done()]] });
    const { done: d } = await run(svc);
    assert.strictEqual(svc._requests.length, 0);
    assert.strictEqual(d.fallback, true);
  });

  it('12. Người dùng huỷ giữa chừng: không gọi onDone, không rơi về dự phòng', async () => {
    const ac = new AbortController();
    const svc = makeService({ rounds: [[text('a'), text('b'), done()]] });
    svc.deepseekStream = async function* () {
      yield text('a');
      ac.abort();
      yield text('b');
      yield done();
    };
    const { chunks, done: d } = await run(svc, { signal: ac.signal });
    assert.strictEqual(d, undefined);
    assert.deepStrictEqual(chunks, ['a']);
  });

  it('13. Lịch sử và câu hỏi được che PII trước khi gửi đi', async () => {
    const svc = makeService({ rounds: [[text('ok'), done()]] });
    await run(svc, {
      message: 'số điện thoại tôi là 0912345678',
      history: [{ role: 'user', text: 'stk 0123456789012' }, { role: 'model', text: 'ok' }],
    });
    const all = JSON.stringify(svc._requests[0].messages);
    assert.ok(!all.includes('0912345678'));
    assert.ok(!all.includes('0123456789012'));
  });
});
