/**
 * Unit Test — Ngân sách chi phí AI theo người dùng theo tháng (R&D).
 * Lý do tồn tại: số đo thật cho thấy một lượt "xấu nhất" tốn gấp ~5–10 lần lượt thường, nên chỉ giới hạn SỐ LƯỢT
 * không chặn được lỗ; phải tính TIỀN thật theo trường `usage` của nhà cung cấp.
 */

const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

const { getChatbotLimits } = require('../../modules/ai/features/chatbot/limits/chatbot.limits');
const { usageToMicroUsd, getPrices } = require('../../modules/ai/features/chatbot/limits/usage-cost');
const { UsageBudget } = require('../../modules/ai/features/chatbot/limits/usage-budget');
const { createDailyQuotaMiddleware } = require('../../modules/ai/features/chatbot/limits/quota.middleware');
const { UsageQuota } = require('../../modules/ai/features/chatbot/limits/usage-quota');
const ChatbotService = require('../../modules/ai/features/chatbot/chatbot.service');
const { CircuitBreaker } = require('../../modules/ai/features/chatbot/resilience/circuit-breaker');

const PRICES = { missPerM: 0.30, hitPerM: 0.006, outPerM: 1.20 };

describe('Giá trị mặc định đã đo lại bằng DeepSeek thật', () => {
  const keys = ['AI_MAX_MESSAGE_CHARS', 'AI_MAX_HISTORY_ITEMS', 'AI_MAX_HISTORY_ITEM_CHARS', 'AI_MAX_TOOL_RESULT_CHARS', 'AI_MONTHLY_BUDGET_MICRO_USD', 'AI_PRICE_MISS_PER_M', 'AI_PRICE_HIT_PER_M', 'AI_PRICE_OUT_PER_M', 'AI_MAX_TOOL_ROUNDS', 'AI_MAX_TOOL_CALLS_PER_ROUND', 'AI_MAX_TURN_COST_MICRO_USD'];
  const saved = {};
  beforeEach(() => keys.forEach((k) => { saved[k] = process.env[k]; delete process.env[k]; }));
  afterEach(() => keys.forEach((k) => { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }));

  it('1. Trần đầu vào thu hẹp theo số đo; ngân sách tháng 0.80 USD (PO nâng 2026-11-08)', () => {
    const l = getChatbotLimits();
    assert.strictEqual(l.maxMessageChars, 1000);
    assert.strictEqual(l.maxHistoryItems, 4);
    assert.strictEqual(l.maxHistoryItemChars, 800);
    assert.strictEqual(l.maxToolResultChars, 2500);
    assert.strictEqual(l.monthlyBudgetMicroUsd, 800000);
  });

  it('1b. Gọi công cụ ĐA BƯỚC là mặc định, bị chặn bằng chi phí mỗi lượt chứ không bằng "một vòng"', () => {
    const l = getChatbotLimits();
    assert.strictEqual(l.maxToolRounds, 5);
    assert.strictEqual(l.maxToolCallsPerRound, 5);
    assert.strictEqual(l.maxTurnCostMicroUsd, 12000);
  });

  it('2. Bảng giá mặc định là giá GIỜ CAO ĐIỂM (bảo thủ) của deepseek-flash, ghi đè được', () => {
    assert.deepStrictEqual(getPrices(), PRICES);
    process.env.AI_PRICE_MISS_PER_M = '0.15';
    assert.strictEqual(getPrices().missPerM, 0.15);
  });
});

describe('usageToMicroUsd — công thức chi phí một lần gọi', () => {
  it('1. miss×giá_miss + hit×giá_hit + out×giá_out (đơn vị micro-USD, làm tròn lên)', () => {
    // số đo thật của vòng 1 trường hợp xấu nhất: miss 3497, hit 2944, out 251
    const usage = { prompt_tokens: 6441, prompt_cache_hit_tokens: 2944, prompt_cache_miss_tokens: 3497, completion_tokens: 251 };
    assert.strictEqual(usageToMicroUsd(usage, PRICES), 1368);
  });

  it('2. Không có trường cache thì coi toàn bộ prompt là miss (bảo thủ)', () => {
    assert.strictEqual(usageToMicroUsd({ prompt_tokens: 1000, completion_tokens: 100 }, PRICES), Math.ceil(1000 * 0.30 + 100 * 1.20));
  });

  it('3. Thiếu usage thì 0, không ném lỗi', () => {
    assert.strictEqual(usageToMicroUsd(null, PRICES), 0);
    assert.strictEqual(usageToMicroUsd({}, PRICES), 0);
  });
});

describe('UsageBudget — ngân sách theo tháng (giờ Việt Nam)', () => {
  const t = (s) => () => new Date(s);

  it('1. Cộng dồn và đọc lại', async () => {
    const b = new UsageBudget({ redis: null, now: t('2026-11-07T03:00:00Z') });
    assert.strictEqual(await b.spent(1), 0);
    await b.add(1, 1200);
    await b.add(1, 300);
    assert.strictEqual(await b.spent(1), 1500);
    assert.strictEqual(await b.spent(2), 0);
  });

  it('2. Sang tháng mới (giờ VN) thì về 0', async () => {
    let now = new Date('2026-11-30T16:30:00Z'); // 23:30 ngày 30/11 giờ VN
    const b = new UsageBudget({ redis: null, now: () => now });
    await b.add(1, 5000);
    assert.strictEqual(await b.spent(1), 5000);
    now = new Date('2026-11-30T17:30:00Z'); // 00:30 ngày 1/12 giờ VN
    assert.strictEqual(await b.spent(1), 0);
  });

  it('3. Redis sẵn sàng: dùng INCRBY và đặt hạn khóa; lỗi thì rơi về bộ nhớ', async () => {
    const calls = [];
    const redis = {
      status: 'ready',
      incrby: async (k, n) => { calls.push(['incrby', k, n]); return n; },
      expire: async (k, s) => { calls.push(['expire', k, s]); },
      get: async () => '7000',
    };
    const b = new UsageBudget({ redis, now: t('2026-11-07T03:00:00Z') });
    await b.add(9, 700);
    assert.ok(calls.some((c) => c[0] === 'incrby' && c[1].includes(':9:202611') && c[2] === 700));
    assert.ok(calls.some((c) => c[0] === 'expire'));
    assert.strictEqual(await b.spent(9), 7000);

    const broken = new UsageBudget({ redis: { status: 'ready', incrby: async () => { throw new Error('x'); }, get: async () => { throw new Error('x'); }, expire: async () => {} }, now: t('2026-11-07T03:00:00Z') });
    await broken.add(1, 800);
    assert.strictEqual(await broken.spent(1), 800);
  });

  it('4. Số âm hoặc không hữu hạn bị bỏ qua', async () => {
    const b = new UsageBudget({ redis: null, now: t('2026-11-07T03:00:00Z') });
    await b.add(1, -5);
    await b.add(1, NaN);
    assert.strictEqual(await b.spent(1), 0);
  });
});

describe('Middleware: chặn khi hết ngân sách tháng', () => {
  function fakeRes() {
    return { statusCode: 200, headers: {}, body: undefined, setHeader(k, v) { this.headers[k] = v; }, status(c) { this.statusCode = c; return this; }, json(b) { this.body = b; return this; } };
  }
  const repo = { getPermissionsByAccountType: async () => ({ scopes: { ai_assistant: { daily_prompts: 100 } } }) };
  const mk = (budget, budgetLimit) => createDailyQuotaMiddleware({
    quota: new UsageQuota({ redis: null, now: () => new Date('2026-11-07T03:00:00Z') }),
    budget,
    permissionRepository: repo,
    getLimits: () => ({ dailyPromptsDefault: 100, monthlyBudgetMicroUsd: budgetLimit }),
  });

  it('1. Đã tiêu ≥ ngân sách thì 429 AI_MONTHLY_BUDGET, KHÔNG tính vào hạn mức ngày', async () => {
    const budget = new UsageBudget({ redis: null, now: () => new Date('2026-11-07T03:00:00Z') });
    await budget.add(5, 400000);
    const res = fakeRes();
    let next = false;
    await mk(budget, 400000)({ user: { idaccount: 5, type: 'Premium' } }, res, () => { next = true; });
    assert.strictEqual(next, false);
    assert.strictEqual(res.statusCode, 429);
    assert.strictEqual(res.body.code, 'AI_MONTHLY_BUDGET');
    assert.ok(Number(res.headers['Retry-After']) > 0);
  });

  it('2. Còn ngân sách thì cho qua', async () => {
    const budget = new UsageBudget({ redis: null, now: () => new Date('2026-11-07T03:00:00Z') });
    await budget.add(5, 1000);
    let next = false;
    await mk(budget, 400000)({ user: { idaccount: 5, type: 'Premium' } }, fakeRes(), () => { next = true; });
    assert.strictEqual(next, true);
  });

  it('3. Quản trị viên không bị tính ngân sách', async () => {
    const budget = new UsageBudget({ redis: null, now: () => new Date('2026-11-07T03:00:00Z') });
    await budget.add(1, 999999999);
    let next = false;
    await mk(budget, 1)({ user: { idaccount: 1, idrole: 1 } }, fakeRes(), () => { next = true; });
    assert.strictEqual(next, true);
  });
});

describe('Controller ghi chi phí thật vào ngân sách người dùng', () => {
  const chatbotController = require('../../modules/ai/features/chatbot/chatbot.controller');
  const { StreamGuard } = require('../../modules/ai/features/chatbot/limits/stream-guard');
  const res = () => ({ headers: {}, written: [], ended: false, setHeader() {}, flushHeaders() {}, write(s) { this.written.push(s); return true; }, end() { this.ended = true; }, on() {}, get writableEnded() { return this.ended; } });
  const req = (user) => ({ user, body: { message: 'chi tiêu tháng này' }, on() {} });

  it('1. Mỗi vòng usage được cộng vào ngân sách của đúng người dùng', async () => {
    const added = [];
    chatbotController.getBudget = () => ({ add: async (id, n) => { added.push([id, n]); } });
    chatbotController.streamGuard = new StreamGuard({ perUser: 1, global: 5 });
    chatbotController.chatbotService = { chatStream: async (p) => { await p.onUsage({ costMicroUsd: 1368 }); await p.onUsage({ costMicroUsd: 700 }); p.onDone({}); } };
    await chatbotController.handleChatStream(req({ idaccount: 5, type: 'Premium' }), res());
    assert.deepStrictEqual(added, [[5, 1368], [5, 700]]);
  });

  it('2. Quản trị viên không bị ghi chi phí', async () => {
    const added = [];
    chatbotController.getBudget = () => ({ add: async (id, n) => { added.push([id, n]); } });
    chatbotController.streamGuard = new StreamGuard({ perUser: 1, global: 5 });
    chatbotController.chatbotService = { chatStream: async (p) => { assert.strictEqual(p.onUsage, undefined); p.onDone({}); } };
    await chatbotController.handleChatStream(req({ idaccount: 1, idrole: 1 }), res());
    assert.deepStrictEqual(added, []);
  });
});

describe('ChatbotService báo chi phí thật của từng lượt qua onUsage', () => {
  const saved = {};
  const keys = ['CHATBOT_LLM_PROVIDER', 'DEEPSEEK_API_KEY'];
  beforeEach(() => { keys.forEach((k) => { saved[k] = process.env[k]; }); process.env.CHATBOT_LLM_PROVIDER = 'deepseek'; process.env.DEEPSEEK_API_KEY = 'sk-test'; });
  afterEach(() => keys.forEach((k) => { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }));

  it('1. Mỗi vòng gọi nhà cung cấp phát một lần onUsage; tổng khớp công thức', async () => {
    const svc = new ChatbotService();
    svc.snapshotService = { generateSnapshot: async () => null };
    svc.toolsExecutor = { executeTool: async () => ({ ok: true }) };
    svc._getUserName = async () => '';
    svc.breaker = new CircuitBreaker({});
    const u1 = { prompt_tokens: 2600, prompt_cache_hit_tokens: 2432, prompt_cache_miss_tokens: 168, completion_tokens: 77 };
    const u2 = { prompt_tokens: 1924, prompt_cache_hit_tokens: 1280, prompt_cache_miss_tokens: 644, completion_tokens: 378 };
    const steps = [
      [{ type: 'done', finishReason: 'tool_calls', toolCalls: [{ id: 'c1', name: 'get_bill_details', args: '{}' }], usage: u1 }],
      [{ type: 'text', text: 'ok' }, { type: 'done', finishReason: 'stop', toolCalls: [], usage: u2 }],
    ];
    let i = 0;
    svc.deepseekStream = async function* () { for (const e of steps[i++]) yield e; };

    const reported = [];
    await svc.chatStream({ message: 'hóa đơn nào sắp đến hạn', idaccount: 5, onChunk: () => {}, onDone: () => {}, onUsage: (u) => reported.push(u) });
    assert.strictEqual(reported.length, 2);
    assert.strictEqual(reported[0].costMicroUsd, usageToMicroUsd(u1, PRICES));
    assert.strictEqual(reported[1].costMicroUsd, usageToMicroUsd(u2, PRICES));
    assert.strictEqual(reported[0].completionTokens, 77);
  });
});
