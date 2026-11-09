/**
 * Unit Test — Các lỗi do kiểm chứng độc lập tìm thấy 2026-11-08 (Chatbot AI).
 * Mỗi nhóm là một lỗi đã tái hiện được: kết quả sai cho người dùng, lộ PII, ngân sách tính thiếu, câu cụt coi là hoàn chỉnh,
 * `/chat` báo thành công khi lỗi, tham số công cụ hỏng làm vỡ lượt. Không chạm mạng hay CSDL.
 */

const { describe, it, beforeEach, afterEach, mock } = require('node:test');
const assert = require('node:assert');

const { prisma } = require('../../config/db');
const ChatbotService = require('../../modules/ai/features/chatbot/chatbot.service');
const ToolsExecutor = require('../../modules/ai/features/chatbot/tools/tools.executor');
const PIIMasker = require('../../modules/ai/features/chatbot/privacy/pii.masker');
const { CircuitBreaker } = require('../../modules/ai/features/chatbot/resilience/circuit-breaker');
const { streamDeepseek, LlmProviderError } = require('../../modules/ai/features/chatbot/llm/deepseek.provider');
const { estimateMicroUsd, getPrices } = require('../../modules/ai/features/chatbot/limits/usage-cost');
const { KNOWLEDGE_TOOL_NAME } = require('../../modules/ai/features/chatbot/tools/financial.tools');

const USER = 'Nguyễn Văn An';
const PHONE = '0912345678';

// Đối tượng model của Prisma là proxy nên `mock.method` không thấy hàm; gán rồi trả lại như các test khác.
const restores = [];
function stubPrisma(model, method, impl) {
  const original = prisma[model][method];
  const fn = mock.fn(impl);
  prisma[model][method] = fn;
  restores.push(() => { prisma[model][method] = original; });
  return fn;
}
afterEach(() => { while (restores.length) restores.pop()(); });

describe('get_goal_simulation — không được báo sai "đã xong"', () => {
  const GOAL = { name: 'Mua nhà', target_amount: 100000000, current_amount: 10000000 };
  const exec = new ToolsExecutor();
  const stubGoal = (goal) => stubPrisma('goal', 'findFirst', async () => goal);

  it('1. Thiếu hoặc sai số tiền đóng góp: giữ đúng số còn thiếu, số tháng là null kèm ghi chú', async () => {
    stubGoal(GOAL);
    for (const monthlyContribution of [undefined, null, 0, -5, 'abc']) {
      const r = await exec.executeTool('get_goal_simulation', { goalName: 'nhà', monthlyContribution }, 5);
      assert.strictEqual(r.remainingAmount, 90000000, `còn thiếu với ${monthlyContribution}`);
      assert.strictEqual(r.monthsNeeded, null);
      assert.ok(r.note && r.note.length > 0);
      assert.strictEqual(r.monthlyContribution, null);
    }
  });

  it('2. Có số tiền hợp lệ (kể cả dạng chuỗi số): tính đúng số tháng', async () => {
    stubGoal(GOAL);
    const a = await exec.executeTool('get_goal_simulation', { goalName: 'nhà', monthlyContribution: 3000000 }, 5);
    assert.strictEqual(a.monthsNeeded, 30);
    const b = await exec.executeTool('get_goal_simulation', { goalName: 'nhà', monthlyContribution: '3000000' }, 5);
    assert.strictEqual(b.monthsNeeded, 30);
  });

  it('3. Mục tiêu đã đủ tiền: còn 0 và 0 tháng là đúng, kể cả khi không có số tiền đóng góp', async () => {
    stubGoal({ ...GOAL, current_amount: 100000000 });
    const r = await exec.executeTool('get_goal_simulation', { goalName: 'nhà' }, 5);
    assert.strictEqual(r.remainingAmount, 0);
    assert.strictEqual(r.monthsNeeded, 0);
  });

  it('4. Thiếu tên mục tiêu: báo lỗi, không truy vấn (contains rỗng từng khớp mục tiêu bất kỳ)', async () => {
    const fn = stubGoal(GOAL);
    for (const goalName of [undefined, '', '   ', 123]) {
      const r = await exec.executeTool('get_goal_simulation', { goalName, monthlyContribution: 1000000 }, 5);
      assert.ok(r.error, `phải báo lỗi với ${goalName}`);
    }
    assert.strictEqual(fn.mock.callCount(), 0);
  });

  it('5. Truy vấn luôn ràng theo chủ sở hữu và bỏ bản ghi đã xoá', async () => {
    const fn = stubGoal(GOAL);
    await exec.executeTool('get_goal_simulation', { goalName: 'nhà', monthlyContribution: 1000000 }, 5);
    const { where } = fn.mock.calls[0].arguments[0];
    assert.strictEqual(where.idaccount, 5);
    assert.strictEqual(where.delete_at, null);
  });
});

describe('Che PII trong kết quả công cụ và bản chụp', () => {
  const exec = new ToolsExecutor();
  const opts = { userName: USER };
  const leaked = (obj) => {
    const s = JSON.stringify(obj);
    return s.includes(USER) || s.includes(PHONE);
  };

  it('1. Tên mục tiêu không lộ họ tên, SĐT', async () => {
    stubPrisma('goal', 'findFirst', async () => ({ name: `Mua nhà cho ${USER} ${PHONE}`, target_amount: 10, current_amount: 1 }));
    const r = await exec.executeTool('get_goal_simulation', { goalName: 'nhà', monthlyContribution: 1 }, 5, opts);
    assert.ok(!leaked(r), JSON.stringify(r));
    assert.ok(r.goalName.includes('Mua nhà'), 'phần không nhạy cảm vẫn còn để mô hình đọc được');
  });

  it('2. Tên hóa đơn và tên danh mục của hóa đơn không lộ họ tên, SĐT', async () => {
    stubPrisma('bill', 'findMany', async () => [{ idbill: 'b', name: `Tiền nhà ${USER}`, amount: 1, due_date: new Date(), pay_status: 'Pending', category: { name_category: `Nợ ${USER} ${PHONE}` } }]);
    const r = await exec.executeTool('get_bill_details', {}, 5, opts);
    assert.ok(!leaked(r), JSON.stringify(r));
  });

  it('3. Tên danh mục của giao dịch không lộ họ tên, SĐT', () => {
    const r = exec.sanitizeTransactionList([{ idtran: 't', amount: -1, type: 'Transaction', note: '', category: { name_category: `Trả ${USER} ${PHONE}`, classify: 'Chi' } }], USER);
    assert.ok(!leaked(r), JSON.stringify(r));
  });

  it('4. Bản chụp che họ tên trong tên danh mục và cảnh báo khi có userName', () => {
    const r = new PIIMasker().anonymizeSnapshot({
      topExpenseCategories: [{ category: `Nợ ${USER}`, percentage: 10 }],
      overBudgetAlerts: [`Nợ ${USER} đã chạm 90%`],
    }, { userName: USER });
    assert.ok(!leaked(r), JSON.stringify(r));
  });

  it('5. Service lấy họ tên trước rồi truyền vào bản chụp', async () => {
    const svc = baseService([[{ type: 'text', text: 'ok' }, doneEv()]]);
    const seen = [];
    svc.snapshotService = { generateSnapshot: async (id, o) => { seen.push([id, o]); return null; } };
    svc._getUserName = async () => USER;
    await withDeepseek(() => svc.chatStream({ message: 'chào', idaccount: 5, onChunk: () => {}, onDone: () => {} }));
    assert.strictEqual(seen[0][0], 5);
    assert.strictEqual(seen[0][1].userName, USER);
  });
});

function doneEv(extra = {}) {
  return { type: 'done', finishReason: 'stop', toolCalls: [], usage: { prompt_tokens: 100, prompt_cache_miss_tokens: 100, prompt_cache_hit_tokens: 0, completion_tokens: 10 }, ...extra };
}

function baseService(rounds) {
  const svc = new ChatbotService();
  svc.snapshotService = { generateSnapshot: async () => null };
  svc._getUserName = async () => '';
  svc.breaker = new CircuitBreaker({ failureThreshold: 5, cooldownPeriodMs: 60000, windowMs: 60000 });
  svc._requests = [];
  let i = 0;
  svc.deepseekStream = async function* (args) {
    svc._requests.push(args);
    const step = rounds[Math.min(i++, rounds.length - 1)];
    if (step instanceof Error) throw step;
    for (const ev of step) {
      if (ev instanceof Error) throw ev;
      if (typeof ev === 'function') { ev(); continue; }
      yield ev;
    }
  };
  return svc;
}

async function withDeepseek(fn) {
  const keys = ['CHATBOT_LLM_PROVIDER', 'DEEPSEEK_API_KEY'];
  const saved = keys.map((k) => process.env[k]);
  process.env.CHATBOT_LLM_PROVIDER = 'deepseek';
  process.env.DEEPSEEK_API_KEY = 'sk-test';
  try {
    return await fn();
  } finally {
    keys.forEach((k, i) => { if (saved[i] === undefined) delete process.env[k]; else process.env[k] = saved[i]; });
  }
}

async function turn(svc, over = {}) {
  const chunks = [];
  const usages = [];
  let done;
  await withDeepseek(() => svc.chatStream({
    message: 'xin chào',
    idaccount: 5,
    onChunk: (c) => chunks.push(c),
    onDone: (d) => { done = d; },
    onUsage: (u) => usages.push(u),
    ...over,
  }));
  return { text: chunks.join(''), chunks, usages, done };
}

describe('Ngân sách không được tính thiếu khi lượt không có usage', () => {
  const retryable = () => new LlmProviderError('x', { status: 503, retryable: true });

  it('1. estimateMicroUsd: ước theo số ký tự, coi cả prompt là không trúng bộ đệm (bảo thủ)', () => {
    const p = getPrices();
    assert.strictEqual(estimateMicroUsd({ promptChars: 3000, outputChars: 300 }), Math.ceil(1000 * p.missPerM + 100 * p.outPerM));
    assert.strictEqual(estimateMicroUsd({}), 0);
  });

  it('2. Huỷ giữa luồng: ghi một khoản ước tính', async () => {
    const ac = new AbortController();
    const svc = baseService([[{ type: 'text', text: 'Chữ đầu ' }, () => ac.abort(), { type: 'text', text: 'không tới' }, doneEv()]]);
    const { usages, done } = await turn(svc, { signal: ac.signal });
    assert.strictEqual(usages.length, 1);
    assert.strictEqual(usages[0].estimated, true);
    assert.ok(usages[0].costMicroUsd > 0);
    assert.strictEqual(done, undefined);
  });

  it('3. Huỷ ở vòng hai: vòng một tính thật, vòng hai tính ước lượng', async () => {
    const ac = new AbortController();
    const call = { id: 'c1', name: 'get_bill_details', args: '{}' };
    const svc = baseService([
      [doneEv({ finishReason: 'tool_calls', toolCalls: [call] })],
      [{ type: 'text', text: 'a' }, () => ac.abort(), doneEv()],
    ]);
    svc.toolsExecutor = { executeTool: async () => ({ ok: true }) };
    const { usages } = await turn(svc, { signal: ac.signal });
    assert.deepStrictEqual(usages.map((u) => Boolean(u.estimated)), [false, true]);
  });

  it('4. Lỗi trước khi có dữ liệu (kết nối, 503): không ghi chi phí', async () => {
    const svc = baseService([retryable()]);
    const { usages, done } = await turn(svc);
    assert.strictEqual(usages.length, 0);
    assert.strictEqual(done.fallback, true);
  });

  it('5. Lỗi giữa luồng: ghi ước tính rồi vẫn đi đường dự phòng', async () => {
    const svc = baseService([[{ type: 'text', text: 'Một phần' }, retryable()]]);
    const { usages, done } = await turn(svc);
    assert.strictEqual(usages.length, 1);
    assert.strictEqual(usages[0].estimated, true);
    assert.strictEqual(done.fallback, true);
  });

  it('6. Nhà cung cấp không gửi usage: ghi ước tính; có usage thì không gắn cờ ước tính', async () => {
    const a = await turn(baseService([[{ type: 'text', text: 'ok' }, doneEv({ usage: null })]]));
    assert.strictEqual(a.usages[0].estimated, true);
    const b = await turn(baseService([[{ type: 'text', text: 'ok' }, doneEv()]]));
    assert.ok(!b.usages[0].estimated);
  });
});

describe('Luồng từ nhà cung cấp kết thúc bất thường', () => {
  const base = { apiKey: 'k', model: 'm', messages: [], maxTokens: 10, timeoutMs: 5000 };
  const frame = (o) => `data: ${JSON.stringify(o)}\n\n`;
  const respond = (body) => async () => new Response(body, { status: 200 });
  const collect = async (gen) => { const out = []; for await (const e of gen) out.push(e); return out; };

  it('1. Đóng sớm, không có finish_reason lẫn [DONE]: ném lỗi tính vào dịch vụ, không coi là xong', async () => {
    await assert.rejects(
      collect(streamDeepseek({ ...base, fetchImpl: respond(frame({ choices: [{ delta: { content: 'Một nửa' } }] })) })),
      (e) => e instanceof LlmProviderError && e.retryable === true && e.code === 'STREAM_TRUNCATED',
    );
  });

  it('2. Có finish_reason nhưng thiếu [DONE]: vẫn là hoàn chỉnh', async () => {
    const out = await collect(streamDeepseek({ ...base, fetchImpl: respond(frame({ choices: [{ delta: { content: 'a' }, finish_reason: 'stop' }] })) }));
    assert.strictEqual(out.at(-1).finishReason, 'stop');
  });

  it('3. Service: câu trả lời bị cắt vì hết token thì báo cho người đọc và ghi vào done', async () => {
    const { text, done } = await turn(baseService([[{ type: 'text', text: 'Câu bị' }, doneEv({ finishReason: 'length' })]]));
    assert.ok(text.startsWith('Câu bị'));
    assert.ok(text.length > 'Câu bị'.length, 'phải có ghi chú đi kèm');
    assert.strictEqual(done.truncated, true);
  });

  it('4. Service: kết thúc bình thường thì truncated = false, không thêm chữ', async () => {
    const { text, done } = await turn(baseService([[{ type: 'text', text: 'Đủ.' }, doneEv()]]));
    assert.strictEqual(text, 'Đủ.');
    assert.strictEqual(done.truncated, false);
  });
});

describe('Tham số công cụ hỏng không làm vỡ lượt', () => {
  const run = (args, name = 'get_bill_details') => {
    const svc = baseService([
      [doneEv({ finishReason: 'tool_calls', toolCalls: [{ id: 'c1', name, args }] })],
      [{ type: 'text', text: 'Trả lời.' }, doneEv()],
    ]);
    const log = [];
    svc.toolsExecutor = { executeTool: async (n, a) => { log.push([n, a]); return { ok: true }; } };
    return turn(svc).then((r) => ({ ...r, svc, log }));
  };

  for (const [label, args] of [['JSON bị cắt', '{"daysAhead":'], ['null', 'null'], ['số', '123'], ['chuỗi', '"abc"'], ['mảng', '[1]']]) {
    it(`Tham số ${label}: không chạy công cụ, báo lỗi cho mô hình, lịch sử gửi lại vẫn là JSON hợp lệ, lượt không hỏng`, async () => {
      const { log, svc, done, text } = await run(args);
      assert.strictEqual(log.length, 0);
      const msgs = svc._requests[1].messages;
      assert.strictEqual(msgs.find((m) => m.tool_calls).tool_calls[0].function.arguments, '{}');
      assert.ok(JSON.parse(msgs.find((m) => m.role === 'tool').content).error);
      assert.strictEqual(text, 'Trả lời.');
      assert.ok(!done.fallback);
      assert.strictEqual(svc.breaker.failureCount, 0);
    });
  }

  it('Tra cứu với query không phải chuỗi: dùng chính câu hỏi', async () => {
    const { log } = await run('{"query":123}', KNOWLEDGE_TOOL_NAME);
    assert.strictEqual(log[0][1].query, 'xin chào');
  });

  it('Đối số hợp lệ chạy như cũ', async () => {
    const { log } = await run('{"daysAhead":7}');
    assert.deepStrictEqual(log, [['get_bill_details', { daysAhead: 7 }]]);
  });
});

describe('Máy chủ không gắn nguồn vào câu nói kho chưa có nội dung', () => {
  const call = { id: 'c1', name: KNOWLEDGE_TOOL_NAME, args: JSON.stringify({ query: 'giảm trừ gia cảnh thuế thu nhập' }) };
  const answer = async (t) => turn(baseService([[doneEv({ finishReason: 'tool_calls', toolCalls: [call] })], [{ type: 'text', text: t }, doneEv()]]));

  it('1. Mô hình nói kho chưa có: giữ nguyên, không gắn', async () => {
    for (const t of ['Kho kiến thức hiện chưa có nội dung về thuế chuyển nhượng bất động sản.', 'Rất tiếc, kho chưa có thông tin này.']) {
      const { text, done } = await answer(t);
      assert.strictEqual(text, t);
      assert.strictEqual(done.citationAppended, false);
    }
  });

  it('2. Trả lời bình thường mà quên nguồn: vẫn gắn', async () => {
    const { done } = await answer('Mức giảm trừ là 15,5 triệu đồng mỗi tháng.');
    assert.strictEqual(done.citationAppended, true);
  });
});

describe('Prompt — không trích nguồn cho nội dung kho không có', () => {
  it('Đoạn tra được không trả lời đúng câu hỏi thì coi như không tìm thấy, không ghi dòng nguồn (lỗi thấy khi chạy thật)', () => {
    const { buildSystemPrompt } = require('../../modules/ai/features/chatbot/prompts/advisor.system.prompt');
    assert.ok(buildSystemPrompt(null).includes('không trả lời đúng câu hỏi thì coi như không tìm thấy'));
  });
});

describe('Kết quả tra cứu luôn là JSON hợp lệ', () => {
  it('Đoạn đầu dài hơn trần: cắt phần nội dung có đánh dấu, JSON vẫn đọc được và vừa trần', () => {
    const search = { search: () => [{ chunkId: 'd#1', title: 'T', attribution: '[Nguồn: S]', content: 'x'.repeat(5000) }] };
    const r = new ToolsExecutor({ knowledgeSearch: search }).searchKnowledge({ query: 'q' }, { maxResultChars: 500 });
    const json = JSON.stringify(r);
    assert.ok(json.length <= 500, `dài ${json.length}`);
    assert.strictEqual(JSON.parse(json).results[0].citation, '[Nguồn: S]');
    assert.ok(r.results[0].content.endsWith('[đã cắt bớt]'));
  });
});

describe('Đường /chat (trả một lần)', () => {
  const controller = require('../../modules/ai/features/chatbot/chatbot.controller');
  const { StreamGuard } = require('../../modules/ai/features/chatbot/limits/stream-guard');

  function jsonRes() {
    const handlers = {};
    return {
      handlers,
      statusCode: 200,
      body: undefined,
      writableEnded: false,
      setHeader() {},
      on(ev, fn) { handlers[ev] = fn; },
      status(c) { this.statusCode = c; return this; },
      json(b) { this.body = b; this.writableEnded = true; return this; },
    };
  }
  const req = () => ({ user: { idaccount: 5, type: 'Premium' }, body: { message: 'chi tiêu tháng này' }, on() {} });

  beforeEach(() => {
    controller.getBudget = () => ({ add: async () => {} });
    controller.streamGuard = new StreamGuard({ perUser: 1, global: 5 });
  });

  it('1. Dịch vụ lỗi: 503 có cờ fallback, không trả "thành công"', async () => {
    controller.chatbotService = { chatStream: async (p) => { p.onDone({ fallback: true, reason: 'Dịch vụ AI phản hồi chậm' }); } };
    const res = jsonRes();
    await controller.handleChatNonStream(req(), res);
    assert.strictEqual(res.statusCode, 503);
    assert.strictEqual(res.body.fallback, true);
    assert.strictEqual(res.body.code, 'AI_SERVICE_UNAVAILABLE');
    assert.strictEqual(res.body.reply, undefined);
  });

  it('2. Chữ đã sinh trước khi lỗi không bị trả về như câu trả lời', async () => {
    controller.chatbotService = { chatStream: async (p) => { p.onChunk('Mức giảm trừ là'); p.onDone({ fallback: true, reason: 'x' }); } };
    const res = jsonRes();
    await controller.handleChatNonStream(req(), res);
    assert.strictEqual(res.statusCode, 503);
    assert.ok(!JSON.stringify(res.body).includes('Mức giảm trừ'));
  });

  it('3. done mang error: cũng là 503', async () => {
    controller.chatbotService = { chatStream: async (p) => { p.onDone({ error: 'x' }); } };
    const res = jsonRes();
    await controller.handleChatNonStream(req(), res);
    assert.strictEqual(res.statusCode, 503);
  });

  it('4. Bình thường: trả cả câu và số liệu của lượt', async () => {
    controller.chatbotService = { chatStream: async (p) => { p.onChunk('Câu '); p.onChunk('trả lời'); p.onDone({ responseTimeMs: 5, truncated: false }); } };
    const res = jsonRes();
    await controller.handleChatNonStream(req(), res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.data.reply, 'Câu trả lời');
  });

  it('5. Client đóng kết nối giữa chừng: huỷ cuộc gọi LLM', async () => {
    let signal;
    const res = jsonRes();
    controller.chatbotService = { chatStream: async (p) => { signal = p.signal; res.handlers.close(); assert.strictEqual(signal.aborted, true); } };
    await controller.handleChatNonStream(req(), res);
    assert.ok(signal);
  });

  it('6. Đóng kết nối sau khi đã trả lời xong: không tính là huỷ', async () => {
    let signal;
    const res = jsonRes();
    controller.chatbotService = { chatStream: async (p) => { signal = p.signal; p.onChunk('x'); p.onDone({}); } };
    await controller.handleChatNonStream(req(), res);
    res.handlers.close();
    assert.strictEqual(signal.aborted, false);
  });

  it('7. Service không còn tự chèn thông báo lỗi vào nội dung (mặc định, không cần cờ)', async () => {
    const svc = baseService([new LlmProviderError('x', { status: 503, retryable: true })]);
    const { chunks, done } = await turn(svc);
    assert.deepStrictEqual(chunks, []);
    assert.strictEqual(done.fallback, true);
  });
});

describe('Đường Gemini cũ cũng phải vào ngân sách', () => {
  const keys = ['CHATBOT_LLM_PROVIDER', 'GEMINI_API_KEY'];
  const saved = {};
  beforeEach(() => {
    keys.forEach((k) => { saved[k] = process.env[k]; });
    process.env.CHATBOT_LLM_PROVIDER = 'gemini';
    process.env.GEMINI_API_KEY = 'k';
  });
  afterEach(() => keys.forEach((k) => { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }));

  const textChunk = (t) => ({ functionCalls: () => null, text: () => t });
  const callChunk = (name, args) => ({ functionCalls: () => [{ name, args }], text: () => '' });
  const gen = (chunks) => ({ stream: (async function* () { for (const c of chunks) yield c; })() });

  function geminiService(replies) {
    const svc = new ChatbotService();
    svc.snapshotService = { generateSnapshot: async () => null };
    svc._getUserName = async () => '';
    svc.breaker = new CircuitBreaker({});
    let i = 0;
    svc.geminiClient = () => ({ getGenerativeModel: () => ({ startChat: () => ({ sendMessageStream: async () => gen(replies[i++]) }) }) });
    return svc;
  }

  it('1. Lượt Gemini phát một khoản chi phí ước tính vào onUsage', async () => {
    const usages = [];
    await geminiService([[textChunk('Chào bạn.')]]).chatStream({ message: 'xin chào', idaccount: 5, onChunk: () => {}, onDone: () => {}, onUsage: (u) => usages.push(u) });
    assert.strictEqual(usages.length, 1);
    assert.strictEqual(usages[0].provider, 'gemini');
    assert.strictEqual(usages[0].estimated, true);
    assert.ok(usages[0].costMicroUsd > 0);
  });

  it('2. Tra được tri thức mà mô hình không nêu nguồn: máy chủ gắn nguồn như đường chính', async () => {
    const svc = geminiService([[callChunk(KNOWLEDGE_TOOL_NAME, { query: 'quy tắc 50/30/20' })], [textChunk('Chia thu nhập làm ba phần.')]]);
    let text = '';
    let done;
    await svc.chatStream({ message: 'quy tắc 50/30/20 là gì', idaccount: 5, onChunk: (c) => { text += c; }, onDone: (d) => { done = d; } });
    assert.ok(text.includes('[Nguồn: '), text);
    assert.strictEqual(done.citationAppended, true);
  });
});
