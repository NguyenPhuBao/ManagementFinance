/**
 * Unit Test — Hoàn lượt hỏi trong ngày khi lỗi do hệ thống (PO chốt 2026-11-08).
 *
 * Quy tắc: lượt bị trừ ở middleware trước khi gọi AI. Nếu hệ thống không trả được câu trả lời (dịch vụ AI lỗi / rơi
 * về máy, lỗi ngoại lệ, bận hoặc quá tải AI_STREAM_BUSY) thì trả lại lượt đó. Người dùng tự huỷ giữa chừng thì KHÔNG
 * hoàn (thao tác của người dùng, chi phí đã phát sinh). Ngân sách tháng không đổi: vẫn chỉ cộng chi phí thật.
 * Tầng 2: bộ đếm thật (UsageQuota) đổi thật — lượt kế tiếp được cho qua hoặc bị chặn.
 */

const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert');

const { UsageQuota } = require('../../modules/ai/features/chatbot/limits/usage-quota');
const { createDailyQuotaMiddleware } = require('../../modules/ai/features/chatbot/limits/quota.middleware');
const { StreamGuard } = require('../../modules/ai/features/chatbot/limits/stream-guard');
const chatbotController = require('../../modules/ai/features/chatbot/chatbot.controller');

const NOON_VN = () => new Date('2026-11-08T05:00:00Z'); // 12:00 giờ VN
const tick = () => new Promise((r) => setImmediate(r));

function fakeRes() {
  return {
    statusCode: 200, headers: {}, written: [], ended: false, body: undefined, listeners: {},
    setHeader(k, v) { this.headers[k] = v; },
    flushHeaders() {},
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; this.ended = true; return this; },
    write(s) { this.written.push(s); return true; },
    end() { this.ended = true; },
    on(ev, fn) { this.listeners[ev] = fn; },
    get writableEnded() { return this.ended; },
  };
}
function fakeReq(over = {}) {
  const listeners = {};
  return { user: { idaccount: 5, type: 'Premium' }, body: { message: 'Tháng này tôi chi bao nhiêu?' }, on(ev, fn) { listeners[ev] = fn; }, _listeners: listeners, ...over };
}
const repoWith = (daily) => ({ getPermissionsByAccountType: async () => ({ scopes: { ai_assistant: { daily_prompts: daily } } }) });

/** Hạn mức 1 lượt/ngày: dễ thấy lượt có được hoàn hay không. */
function mkQuota(now = NOON_VN) {
  const quota = new UsageQuota({ redis: null, now });
  const mw = createDailyQuotaMiddleware({ quota, permissionRepository: repoWith(1), getLimits: () => ({ dailyPromptsDefault: 1 }) });
  const pass = async (req = fakeReq()) => { const res = fakeRes(); let n = false; await mw(req, res, () => { n = true; }); return { req, res, n }; };
  return { quota, pass };
}

describe('UsageQuota.refund — trả lại lượt', () => {
  it('1. Hoàn sau khi trừ thì lượt kế tiếp được cho qua', async () => {
    const q = new UsageQuota({ redis: null, now: NOON_VN });
    const r = await q.consume(1, 1);
    await q.refund(r);
    assert.strictEqual((await q.consume(1, 1)).allowed, true);
    assert.strictEqual((await q.consume(1, 1)).allowed, false);
  });

  it('2. Không bao giờ xuống dưới 0', async () => {
    const q = new UsageQuota({ redis: null, now: NOON_VN });
    const r = await q.consume(1, 1);
    await q.refund(r);
    await q.refund(r);
    assert.strictEqual((await q.consume(1, 1)).used, 1);
  });

  it('3. Hoàn vào đúng ngày đã trừ: trừ lúc 23:59, lỗi sau 0 giờ thì KHÔNG giảm lượt của ngày mới', async () => {
    let t = new Date('2026-11-08T16:59:00Z'); // 23:59 ngày 8 giờ VN
    const q = new UsageQuota({ redis: null, now: () => t });
    const yesterday = await q.consume(1, 1);
    t = new Date('2026-11-08T17:01:00Z'); // 00:01 ngày 9
    assert.strictEqual((await q.consume(1, 1)).allowed, true);
    await q.refund(yesterday);
    assert.strictEqual((await q.consume(1, 1)).allowed, false);
  });

  it('4. Redis: DECR đúng khoá đã INCR; âm thì đưa về 0', async () => {
    const store = new Map();
    const calls = [];
    const redis = {
      status: 'ready',
      incr: async (k) => { const v = (store.get(k) || 0) + 1; store.set(k, v); return v; },
      decr: async (k) => { calls.push(['decr', k]); const v = (store.get(k) || 0) - 1; store.set(k, v); return v; },
      incrby: async (k, n) => { const v = (store.get(k) || 0) + n; store.set(k, v); return v; },
      expire: async () => {},
    };
    const q = new UsageQuota({ redis, now: NOON_VN });
    const r = await q.consume(9, 3);
    await q.refund(r);
    assert.deepStrictEqual(calls, [['decr', 'ai:quota:9:20261108']]);
    assert.strictEqual(store.get('ai:quota:9:20261108'), 0);
    await q.refund(r);
    assert.strictEqual(store.get('ai:quota:9:20261108'), 0);
  });
});

describe('createDailyQuotaMiddleware — gắn hàm hoàn lượt', () => {
  it('1. Lượt được cho qua có req.aiQuotaRefund; gọi hai lần chỉ hoàn một lượt', async () => {
    const { pass } = mkQuota();
    const first = await pass();
    assert.strictEqual(typeof first.req.aiQuotaRefund, 'function');
    await first.req.aiQuotaRefund();
    await first.req.aiQuotaRefund();
    assert.strictEqual((await pass()).n, true);
    assert.strictEqual((await pass()).n, false, 'gọi hoàn hai lần không được tặng thêm lượt');
  });

  it('2. Lượt bị chặn 429 thì không có hàm hoàn', async () => {
    const { pass } = mkQuota();
    await pass();
    const blocked = await pass();
    assert.strictEqual(blocked.res.statusCode, 429);
    assert.strictEqual(blocked.req.aiQuotaRefund, undefined);
  });
});

describe('ChatbotController — hoàn lượt khi lỗi do hệ thống', () => {
  const original = { service: chatbotController.chatbotService, guard: chatbotController.streamGuard, budget: chatbotController.getBudget };
  afterEach(() => {
    chatbotController.chatbotService = original.service;
    chatbotController.streamGuard = original.guard;
    chatbotController.getBudget = original.budget;
  });
  function useService(impl) {
    chatbotController.chatbotService = { chatStream: async (p) => impl(p) };
    chatbotController.streamGuard = new StreamGuard({ perUser: 1, global: 5 });
    chatbotController.getBudget = () => ({ add: async () => {} });
  }
  const streamOnce = async (pass, handler = 'handleChatStream') => {
    const { req, n } = await pass();
    assert.ok(n, 'middleware phải cho qua lượt đầu');
    const res = fakeRes();
    await chatbotController[handler](req, res);
    await tick();
    return { req, res };
  };

  it('1. SSE: dịch vụ rơi về máy (fallback) thì hoàn lượt', async () => {
    const { pass } = mkQuota();
    useService((p) => p.onDone({ fallback: true, reason: 'x' }));
    await streamOnce(pass);
    assert.strictEqual((await pass()).n, true);
  });

  it('2. SSE: dịch vụ ném lỗi thì hoàn lượt', async () => {
    const { pass } = mkQuota();
    useService(() => { throw new Error('boom'); });
    await streamOnce(pass);
    assert.strictEqual((await pass()).n, true);
  });

  it('3. SSE: trả lời thành công thì KHÔNG hoàn', async () => {
    const { pass } = mkQuota();
    useService((p) => { p.onChunk('ok'); p.onDone({ responseTimeMs: 1 }); });
    await streamOnce(pass);
    assert.strictEqual((await pass()).n, false);
  });

  it('4. SSE: người dùng tự huỷ giữa chừng thì KHÔNG hoàn, kể cả khi dịch vụ báo dự phòng sau đó', async () => {
    const { pass } = mkQuota();
    let reqRef;
    useService((p) => { reqRef._listeners.close(); p.onDone({ fallback: true, reason: 'aborted' }); });
    const { req } = await pass();
    reqRef = req;
    await chatbotController.handleChatStream(req, fakeRes());
    await tick();
    assert.strictEqual((await pass()).n, false);
  });

  it('5. SSE: bị từ chối vì đang bận (AI_STREAM_BUSY) thì hoàn lượt', async () => {
    const { pass } = mkQuota();
    useService(() => {});
    chatbotController.streamGuard = { acquire: () => null };
    const { res } = await streamOnce(pass);
    assert.strictEqual(res.body.code, 'AI_STREAM_BUSY');
    assert.strictEqual((await pass()).n, true);
  });

  it('6. /chat: dịch vụ rơi về máy thì 503 và hoàn lượt', async () => {
    const { pass } = mkQuota();
    useService((p) => p.onDone({ fallback: true, reason: 'x' }));
    const { res } = await streamOnce(pass, 'handleChatNonStream');
    assert.strictEqual(res.statusCode, 503);
    assert.strictEqual((await pass()).n, true);
  });

  it('7. /chat: thành công thì KHÔNG hoàn', async () => {
    const { pass } = mkQuota();
    useService((p) => { p.onChunk('ok'); p.onDone({}); });
    const { res } = await streamOnce(pass, 'handleChatNonStream');
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual((await pass()).n, false);
  });

  it('8. /chat: dịch vụ ném lỗi thì 500 và hoàn lượt', async () => {
    const { pass } = mkQuota();
    useService(() => { throw new Error('boom'); });
    const { res } = await streamOnce(pass, 'handleChatNonStream');
    assert.strictEqual(res.statusCode, 500);
    assert.strictEqual((await pass()).n, true);
  });
});
