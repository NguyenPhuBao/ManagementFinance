/**
 * Unit Test — Bản chụp tài chính và số liệu chi tiêu, các điểm thấy khi kiểm trực tiếp với Supabase 2026-11-08:
 * khoản chi không danh mục bị bỏ sót; truy vấn tuần tự làm chậm chữ đầu; cấu hình context_window_days không có tác dụng;
 * bản chụp không được làm mới khi có giao dịch mới. Không chạm CSDL: Prisma được giả lập.
 */

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert');

const { prisma } = require('../../config/db');
const eventBus = require('../../core/event-bus');
const FinancialSnapshotService = require('../../modules/ai/features/chatbot/snapshot/financial.snapshot.service');
const ToolsExecutor = require('../../modules/ai/features/chatbot/tools/tools.executor');
const { createDailyQuotaMiddleware } = require('../../modules/ai/features/chatbot/limits/quota.middleware');
const { UsageQuota } = require('../../modules/ai/features/chatbot/limits/usage-quota');

const restores = [];
function stub(model, method, impl) {
  const original = prisma[model][method];
  prisma[model][method] = impl;
  restores.push(() => { prisma[model][method] = original; });
}
afterEach(() => { while (restores.length) restores.pop()(); });

function stubSnapshotQueries({ transactions = [], delayMs = 0, onCall = () => {} } = {}) {
  const wrap = (result) => async (args) => {
    onCall(args);
    if (delayMs) await new Promise((r) => setTimeout(r, delayMs));
    return result;
  };
  stub('transaction', 'findMany', wrap(transactions));
  stub('transaction', 'findFirst', wrap(null));
  stub('wallet', 'findMany', wrap([]));
  stub('budget', 'findMany', wrap([]));
  stub('bill', 'findMany', wrap([]));
  stub('goal', 'count', wrap(0));
}

const daysAgo = (n) => new Date(Date.now() - n * 864e5);

describe('Khoản chi không có danh mục vẫn là chi tiêu', () => {
  const rows = [
    { amount: -300, type: 'Transaction', date_transaction: daysAgo(2), category: { classify: 'Chi', name_category: 'Ăn uống' } },
    { amount: -100, type: 'Transaction', date_transaction: daysAgo(2), category: null },
    { amount: 900, type: 'Transaction', date_transaction: daysAgo(2), category: null },
    { amount: -500, type: 'Transfer', date_transaction: daysAgo(2), category: null },
  ];

  it('1. Bản chụp: tính khoản chi không danh mục, không tính khoản nhận và chuyển ví', async () => {
    stubSnapshotQueries({ transactions: rows });
    const snap = await new FinancialSnapshotService().generateSnapshot(5, { bypassCache: true });
    const cats = snap.spendingInsights.topExpenseCategories;
    assert.deepStrictEqual(cats.map((c) => [c.category, c.percentage]), [['Ăn uống', 75], ['Khác', 25]]);
  });

  it('2. So sánh chi tiêu không chỉ định danh mục: truy vấn gồm cả khoản âm không danh mục', async () => {
    const wheres = [];
    stub('transaction', 'findMany', async ({ where }) => { wheres.push(where); return [{ amount: -100 }, { amount: -300 }]; });
    const r = await new ToolsExecutor().compareSpendingPeriods({}, 5);
    assert.strictEqual(r.period1Amount, 400);
    for (const where of wheres) {
      assert.strictEqual(where.idaccount, 5);
      assert.strictEqual(where.deleted_at, null);
      assert.strictEqual(where.type, 'Transaction');
      assert.deepStrictEqual(where.OR, [{ category: { classify: 'Chi' } }, { idcategory: null, amount: { lt: 0 } }]);
    }
  });

  it('3. So sánh theo danh mục cụ thể: chỉ lọc danh mục đó', async () => {
    const wheres = [];
    stub('transaction', 'findMany', async ({ where }) => { wheres.push(where); return []; });
    await new ToolsExecutor().compareSpendingPeriods({ categoryName: 'Ăn' }, 5);
    assert.strictEqual(wheres[0].OR, undefined);
    assert.deepStrictEqual(wheres[0].category, { classify: 'Chi', name_category: { contains: 'Ăn', mode: 'insensitive' } });
  });
});

describe('Bản chụp không được làm chậm chữ đầu vì truy vấn tuần tự', () => {
  it('Các truy vấn chạy đồng thời', async () => {
    let running = 0;
    let peak = 0;
    const onCall = () => { running += 1; peak = Math.max(peak, running); setTimeout(() => { running -= 1; }, 15); };
    stubSnapshotQueries({ delayMs: 20, onCall });
    await new FinancialSnapshotService().generateSnapshot(5, { bypassCache: true });
    assert.ok(peak >= 6, `đồng thời tối đa ${peak}`);
  });
});

describe('context_window_days điều khiển cửa sổ của bản chụp', () => {
  async function windowUsed(options) {
    let gte;
    stubSnapshotQueries({ onCall: (args) => { if (args?.where?.date_transaction?.gte) gte = args.where.date_transaction.gte; } });
    await new FinancialSnapshotService().generateSnapshot(5, { bypassCache: true, ...options });
    return Math.round((Date.now() - gte.getTime()) / 864e5);
  }

  it('1. Dùng đúng số ngày được truyền', async () => {
    assert.strictEqual(await windowUsed({ windowDays: 30 }), 30);
  });

  it('2. Không truyền hoặc giá trị hỏng thì mặc định 90 ngày', async () => {
    for (const windowDays of [undefined, null, 0, -1, 'abc']) assert.strictEqual(await windowUsed({ windowDays }), 90, String(windowDays));
  });

  const fakeRes = () => ({ setHeader() {}, status(c) { this.statusCode = c; return this; }, json(b) { this.body = b; return this; } });

  it('3. Middleware đọc từ ma trận quyền', async () => {
    const repo = { getPermissionsByAccountType: async () => ({ scopes: { ai_assistant: { daily_prompts: 20, context_window_days: 45 } } }) };
    const mw = createDailyQuotaMiddleware({ quota: new UsageQuota({ redis: null }), budget: null, permissionRepository: repo, getLimits: () => ({ dailyPromptsDefault: 20 }) });
    const req = { user: { idaccount: 5, type: 'Premium' } };
    await mw(req, fakeRes(), () => {});
    assert.strictEqual(req.aiContextWindowDays, 45);
  });

  it('4. Controller chuyển cho service, service chuyển cho bản chụp', async () => {
    const controller = require('../../modules/ai/features/chatbot/chatbot.controller');
    const { StreamGuard } = require('../../modules/ai/features/chatbot/limits/stream-guard');
    const ChatbotService = require('../../modules/ai/features/chatbot/chatbot.service');
    controller.getBudget = () => ({ add: async () => {} });
    controller.streamGuard = new StreamGuard({ perUser: 2, global: 5 });
    const seen = [];
    const realService = controller.chatbotService;
    restores.push(() => { controller.chatbotService = realService; });
    controller.chatbotService = { chatStream: async (p) => { seen.push(p.contextWindowDays); p.onDone({}); } };
    const req = { user: { idaccount: 5, type: 'Premium' }, body: { message: 'chi tiêu' }, on() {}, aiContextWindowDays: 45 };
    const sse = { setHeader() {}, flushHeaders() {}, write() { return true; }, end() { this.writableEnded = true; }, on() {} };
    await controller.handleChatStream(req, sse);
    await controller.handleChatNonStream(req, { status() { return this; }, json() { return this; }, setHeader() {}, on() {} });
    assert.deepStrictEqual(seen, [45, 45]);

    const svc = new ChatbotService();
    const got = [];
    svc.snapshotService = { generateSnapshot: async (id, o) => { got.push(o.windowDays); return null; } };
    svc._getUserName = async () => '';
    const saved = [process.env.CHATBOT_LLM_PROVIDER, process.env.DEEPSEEK_API_KEY];
    process.env.CHATBOT_LLM_PROVIDER = 'deepseek';
    delete process.env.DEEPSEEK_API_KEY;
    await svc.chatStream({ message: 'x', idaccount: 5, contextWindowDays: 45, onDone: () => {} });
    process.env.CHATBOT_LLM_PROVIDER = saved[0];
    if (saved[1] !== undefined) process.env.DEEPSEEK_API_KEY = saved[1];
    assert.deepStrictEqual(got, [45]);
  });
});

describe('Câu lạc đề bị từ chối không trừ lượt hỏi', () => {
  const fakeRes = () => ({ setHeader() {}, status(c) { this.statusCode = c; return this; }, json(b) { this.body = b; return this; } });
  const repo = { getPermissionsByAccountType: async () => ({ scopes: { ai_assistant: { daily_prompts: 20 } } }) };

  it('Lớp quy tắc chặn được thì đi tiếp mà không tính lượt; câu hợp lệ vẫn tính', async () => {
    let consumed = 0;
    const quota = { consume: async () => { consumed += 1; return { allowed: true, used: consumed }; } };
    const mw = createDailyQuotaMiddleware({ quota, budget: null, permissionRepository: repo, getLimits: () => ({ dailyPromptsDefault: 20 }) });
    let next = 0;
    await mw({ user: { idaccount: 5, type: 'Premium' }, body: { message: 'Viết code Python sắp xếp mảng giúp tôi' } }, fakeRes(), () => { next += 1; });
    assert.strictEqual(next, 1);
    assert.strictEqual(consumed, 0);
    await mw({ user: { idaccount: 5, type: 'Premium' }, body: { message: 'Tháng này tôi chi bao nhiêu?' } }, fakeRes(), () => { next += 1; });
    assert.strictEqual(consumed, 1);
  });
});

describe('Bản chụp được làm mới khi có giao dịch mới', () => {
  it('Đồng bộ xong (sync.completed) thì xoá bộ đệm của đúng tài khoản; đã nối sẵn trong routes', async () => {
    const controller = require('../../modules/ai/features/chatbot/chatbot.controller');
    const service = controller.chatbotService.snapshotService;
    const calls = [];
    service.invalidateSnapshotCache = async (id) => { calls.push(id); };
    require('../../modules/ai/features/chatbot/chatbot.routes');
    await eventBus.publish('sync.completed', { idaccount: 7, summary: { synced: 1 } });
    assert.deepStrictEqual(calls, [7]);
  });
});
