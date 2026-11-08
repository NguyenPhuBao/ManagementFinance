/**
 * Unit Test — Trần chi phí mỗi lượt theo ngân sách còn lại (PO duyệt 2026-11-08).
 *   trần = min(trần cứng, max(sàn, hệ số × ngân sách còn lại ÷ (số ngày còn lại × số lượt mỗi ngày)))
 * Lượt phức tạp ăn vào ngân sách nên các lượt sau có trần thấp dần; sàn giữ cho lượt thường không bị cắt.
 */

const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

const { computeTurnCapMicroUsd } = require('../../modules/ai/features/chatbot/limits/turn-cap');
const { getChatbotLimits } = require('../../modules/ai/features/chatbot/limits/chatbot.limits');
const { UsageBudget } = require('../../modules/ai/features/chatbot/limits/usage-budget');
const { UsageQuota } = require('../../modules/ai/features/chatbot/limits/usage-quota');
const { createDailyQuotaMiddleware } = require('../../modules/ai/features/chatbot/limits/quota.middleware');
const ChatbotService = require('../../modules/ai/features/chatbot/chatbot.service');
const { CircuitBreaker } = require('../../modules/ai/features/chatbot/resilience/circuit-breaker');

const BASE = { monthlyBudgetMicroUsd: 400000, dailyPrompts: 20, factor: 1.5, floor: 2000, ceiling: 12000 };

describe('computeTurnCapMicroUsd — công thức', () => {
  it('1. Đầu tháng chưa tiêu: phần chia đều ×1,5 = 1.000 µ$ thấp hơn sàn nên lấy sàn 2.000', () => {
    assert.strictEqual(computeTurnCapMicroUsd({ ...BASE, spentMicroUsd: 0, daysLeft: 30 }), 2000);
  });

  it('2. Ngân sách còn dư nhiều so với số ngày còn lại: công thức có tác dụng (trên sàn, dưới trần cứng)', () => {
    // 300.000 ÷ (10 × 20) × 1,5 = 2.250
    assert.strictEqual(computeTurnCapMicroUsd({ ...BASE, spentMicroUsd: 100000, daysLeft: 10 }), 2250);
  });

  it('3. Tiêu nhiều thì trần giảm: cùng số ngày, chi tiêu cao hơn cho trần thấp hơn', () => {
    const a = computeTurnCapMicroUsd({ ...BASE, spentMicroUsd: 0, daysLeft: 5 });
    const b = computeTurnCapMicroUsd({ ...BASE, spentMicroUsd: 200000, daysLeft: 5 });
    assert.ok(b < a, `${b} phải nhỏ hơn ${a}`);
  });

  it('4. Ngày cuối tháng còn nguyên ngân sách: không vượt trần cứng', () => {
    assert.strictEqual(computeTurnCapMicroUsd({ ...BASE, spentMicroUsd: 0, daysLeft: 1 }), 12000);
  });

  it('5. Sắp hết ngân sách: vẫn giữ sàn để lượt thường trả lời trọn vẹn', () => {
    assert.strictEqual(computeTurnCapMicroUsd({ ...BASE, spentMicroUsd: 399000, daysLeft: 20 }), 2000);
  });

  it('6. Đầu vào bất thường không ném lỗi và không vượt trần cứng', () => {
    assert.strictEqual(computeTurnCapMicroUsd({ ...BASE, spentMicroUsd: 999999, daysLeft: 3 }), 2000);
    assert.strictEqual(computeTurnCapMicroUsd({ ...BASE, spentMicroUsd: 0, daysLeft: 0 }), 2000);
    assert.strictEqual(computeTurnCapMicroUsd({ ...BASE, spentMicroUsd: 0, daysLeft: 10, dailyPrompts: 0 }), 2000);
  });
});

describe('getChatbotLimits — tham số của trần động', () => {
  const keys = ['AI_TURN_COST_FACTOR', 'AI_MIN_TURN_COST_MICRO_USD'];
  const saved = {};
  beforeEach(() => keys.forEach((k) => { saved[k] = process.env[k]; delete process.env[k]; }));
  afterEach(() => keys.forEach((k) => { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }));

  it('1. Mặc định hệ số 1,5 và sàn 2.000 µ$; ghi đè được bằng biến môi trường', () => {
    assert.strictEqual(getChatbotLimits().turnCostFactor, 1.5);
    assert.strictEqual(getChatbotLimits().minTurnCostMicroUsd, 2000);
    process.env.AI_TURN_COST_FACTOR = '2';
    process.env.AI_MIN_TURN_COST_MICRO_USD = '3000';
    assert.strictEqual(getChatbotLimits().turnCostFactor, 2);
    assert.strictEqual(getChatbotLimits().minTurnCostMicroUsd, 3000);
  });
});

describe('UsageBudget.daysLeftInMonth — tính cả hôm nay, theo giờ Việt Nam', () => {
  const at = (s) => new UsageBudget({ redis: null, now: () => new Date(s) }).daysLeftInMonth();

  it('1. Ngày 8/11 còn 23 ngày (8 đến 30)', () => assert.strictEqual(at('2026-11-08T03:00:00Z'), 23));
  it('2. Ngày cuối tháng còn 1 ngày', () => assert.strictEqual(at('2026-11-30T03:00:00Z'), 1));
  it('3. 23:30 ngày 30/11 giờ UTC đã là 1/12 giờ VN: còn 31 ngày', () => assert.strictEqual(at('2026-11-30T23:30:00Z'), 31));
});

describe('Middleware gắn trần lượt vào req', () => {
  const fakeRes = () => ({ headers: {}, setHeader(k, v) { this.headers[k] = v; }, status(c) { this.statusCode = c; return this; }, json(b) { this.body = b; return this; } });
  const repo = { getPermissionsByAccountType: async () => ({ scopes: { ai_assistant: { daily_prompts: 20 } } }) };
  const NOW = () => new Date('2026-11-21T03:00:00Z'); // ngày 21/11: còn 10 ngày
  const limits = () => ({ dailyPromptsDefault: 20, monthlyBudgetMicroUsd: 400000, turnCostFactor: 1.5, minTurnCostMicroUsd: 2000, maxTurnCostMicroUsd: 12000 });
  const mk = (budget) => createDailyQuotaMiddleware({ quota: new UsageQuota({ redis: null, now: NOW }), budget, permissionRepository: repo, getLimits: limits });

  it('1. Trần tính từ chi tiêu thật của đúng người dùng', async () => {
    const budget = new UsageBudget({ redis: null, now: NOW });
    await budget.add(5, 100000);
    const req = { user: { idaccount: 5, type: 'Premium' } };
    let next = false;
    await mk(budget)(req, fakeRes(), () => { next = true; });
    assert.strictEqual(next, true);
    assert.strictEqual(req.aiTurnCostCapMicroUsd, 2250);
  });

  it('2. Quản trị viên không có trần động (dùng trần cứng của service)', async () => {
    const budget = new UsageBudget({ redis: null, now: NOW });
    const req = { user: { idaccount: 1, idrole: 1 } };
    await mk(budget)(req, fakeRes(), () => {});
    assert.strictEqual(req.aiTurnCostCapMicroUsd, undefined);
  });
});

describe('Controller chuyển trần lượt cho service ở cả hai cách phân phối', () => {
  const controller = require('../../modules/ai/features/chatbot/chatbot.controller');
  const { StreamGuard } = require('../../modules/ai/features/chatbot/limits/stream-guard');
  const sseRes = () => ({ written: [], ended: false, setHeader() {}, flushHeaders() {}, write(s) { this.written.push(s); return true; }, end() { this.ended = true; }, on() {}, get writableEnded() { return this.ended; } });
  const jsonRes = () => ({ status() { return this; }, json() { return this; }, setHeader() {}, on() {} });
  const req = () => ({ user: { idaccount: 5, type: 'Premium' }, body: { message: 'chi tiêu tháng này' }, on() {}, aiTurnCostCapMicroUsd: 2250 });

  beforeEach(() => {
    controller.getBudget = () => ({ add: async () => {} });
    controller.streamGuard = new StreamGuard({ perUser: 1, global: 5 });
  });

  it('1. Truyền dòng', async () => {
    let got;
    controller.chatbotService = { chatStream: async (p) => { got = p.turnCostCapMicroUsd; p.onDone({}); } };
    await controller.handleChatStream(req(), sseRes());
    assert.strictEqual(got, 2250);
  });

  it('2. Trả một lần', async () => {
    let got;
    controller.chatbotService = { chatStream: async (p) => { got = p.turnCostCapMicroUsd; p.onDone({}); } };
    await controller.handleChatNonStream(req(), jsonRes());
    assert.strictEqual(got, 2250);
  });
});

describe('ChatbotService dùng trần lượt được truyền vào', () => {
  const keys = ['CHATBOT_LLM_PROVIDER', 'DEEPSEEK_API_KEY', 'AI_MAX_TURN_COST_MICRO_USD'];
  const saved = {};
  beforeEach(() => {
    keys.forEach((k) => { saved[k] = process.env[k]; delete process.env[k]; });
    process.env.CHATBOT_LLM_PROVIDER = 'deepseek';
    process.env.DEEPSEEK_API_KEY = 'sk-test';
  });
  afterEach(() => keys.forEach((k) => { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }));

  // Mỗi vòng tốn 900 µ$ (3.000 token miss) và luôn xin gọi công cụ khi được phép.
  const USAGE = { prompt_tokens: 3000, prompt_cache_miss_tokens: 3000, prompt_cache_hit_tokens: 0, completion_tokens: 0 };
  function makeService() {
    const svc = new ChatbotService();
    svc.snapshotService = { generateSnapshot: async () => null };
    svc.toolsExecutor = { executeTool: async () => ({ ok: true }) };
    svc._getUserName = async () => '';
    svc.breaker = new CircuitBreaker({});
    svc._requests = [];
    svc.deepseekStream = async function* (args) {
      svc._requests.push(args);
      const n = svc._requests.length;
      if (args.tools) {
        yield { type: 'done', finishReason: 'tool_calls', toolCalls: [{ id: `c${n}`, name: 'get_bill_details', args: '{}' }], usage: USAGE };
      } else {
        yield { type: 'text', text: 'Trả lời.' };
        yield { type: 'done', finishReason: 'stop', toolCalls: [], usage: USAGE };
      }
    };
    return svc;
  }
  const run = (svc, over = {}) => svc.chatStream({ message: 'hóa đơn nào sắp đến hạn', idaccount: 5, onChunk: () => {}, onDone: () => {}, ...over });

  it('1. Trần 2.000: 900 → 1.800 còn được mở vòng, 2.700 thì thôi công cụ nhưng vẫn trả lời', async () => {
    const svc = makeService();
    await run(svc, { turnCostCapMicroUsd: 2000 });
    assert.strictEqual(svc._requests.length, 4);
    assert.strictEqual(svc._requests[3].tools, undefined);
  });

  it('2. Không truyền trần (quản trị viên, gọi nội bộ): dùng trần cứng, chỉ dừng vì hết số vòng', async () => {
    const svc = makeService();
    await run(svc);
    assert.strictEqual(svc._requests.length, 6);
    assert.strictEqual(svc._requests[5].tools, undefined);
  });
});
