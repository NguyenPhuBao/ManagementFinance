/**
 * Unit Test — Lớp biên của Chatbot AI: validation, middleware hạn mức ngày, controller SSE.
 * Tầng 2 (tác động thật): request quá cỡ bị cắt trước khi tới dịch vụ; vượt hạn mức → 429 + mã; câu ngoài
 * phạm vi KHÔNG chạm dịch vụ LLM; hết chỗ luồng → 429; dự phòng SSE không gửi chữ.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');

const { validateChatRequest } = require('../../modules/ai/features/chatbot/chatbot.validation');
const { createDailyQuotaMiddleware } = require('../../modules/ai/features/chatbot/limits/quota.middleware');
const { UsageQuota } = require('../../modules/ai/features/chatbot/limits/usage-quota');
const { StreamGuard } = require('../../modules/ai/features/chatbot/limits/stream-guard');
const chatbotController = require('../../modules/ai/features/chatbot/chatbot.controller');

function fakeRes() {
  const res = {
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
  return res;
}
function fakeReq(over = {}) {
  const listeners = {};
  return { user: { idaccount: 5, type: 'Premium' }, body: {}, on(ev, fn) { listeners[ev] = fn; }, _listeners: listeners, ...over };
}

describe('validateChatRequest — làm sạch trước khi tới dịch vụ', () => {
  it('1. Lịch sử khổng lồ bị cắt về giới hạn (không chuyển nguyên xuống dịch vụ)', () => {
    const req = fakeReq({ body: { message: 'chi bao nhiêu', history: Array.from({ length: 500 }, (_, i) => ({ role: i % 2 ? 'model' : 'user', text: 'x'.repeat(1_000_000) })) } });
    let nexted = false;
    validateChatRequest(req, fakeRes(), () => { nexted = true; });
    assert.ok(nexted);
    assert.ok(req.body.history.length <= 6);
    assert.ok(req.body.history.every((h) => h.text.length <= 1000));
  });

  it('2. Nhận trường conversationHistory cũ và chuẩn hoá về history', () => {
    const req = fakeReq({ body: { message: 'hi', conversationHistory: [{ role: 'user', content: 'a' }] } });
    validateChatRequest(req, fakeRes(), () => {});
    assert.deepStrictEqual(req.body.history, [{ role: 'user', text: 'a' }]);
  });

  it('3. Tin nhắn quá dài hoặc rỗng bị 400', () => {
    for (const message of ['', 'x'.repeat(2001)]) {
      const res = fakeRes();
      let nexted = false;
      validateChatRequest(fakeReq({ body: { message } }), res, () => { nexted = true; });
      assert.strictEqual(nexted, false);
      assert.strictEqual(res.statusCode, 400);
    }
  });
});

describe('createDailyQuotaMiddleware — hạn mức theo gói', () => {
  const repoWith = (daily) => ({ getPermissionsByAccountType: async () => ({ scopes: { ai_assistant: { daily_prompts: daily } } }) });
  const mk = (daily, limitDefault = 20) => createDailyQuotaMiddleware({
    quota: new UsageQuota({ redis: null, now: () => new Date('2026-11-07T03:00:00Z') }),
    permissionRepository: repoWith(daily),
    getLimits: () => ({ dailyPromptsDefault: limitDefault }),
  });

  it('1. Vượt hạn mức trong ma trận quyền thì 429 AI_DAILY_LIMIT kèm Retry-After', async () => {
    const mw = mk(2);
    const run = async () => { const res = fakeRes(); let n = false; await mw(fakeReq(), res, () => { n = true; }); return { res, n }; };
    assert.strictEqual((await run()).n, true);
    assert.strictEqual((await run()).n, true);
    const third = await run();
    assert.strictEqual(third.n, false);
    assert.strictEqual(third.res.statusCode, 429);
    assert.strictEqual(third.res.body.code, 'AI_DAILY_LIMIT');
    assert.ok(Number(third.res.headers['Retry-After']) > 0);
  });

  it('2. daily_prompts = null (không giới hạn trong ma trận) thì dùng mặc định của hệ thống, KHÔNG mở toang', async () => {
    const mw = mk(null, 1);
    const run = async () => { const res = fakeRes(); let n = false; await mw(fakeReq(), res, () => { n = true; }); return { res, n }; };
    assert.strictEqual((await run()).n, true);
    assert.strictEqual((await run()).res.statusCode, 429);
  });

  it('3. Quản trị viên không bị tính hạn mức', async () => {
    const mw = mk(1);
    for (let i = 0; i < 5; i++) {
      let n = false;
      await mw(fakeReq({ user: { idaccount: 1, idrole: 1 } }), fakeRes(), () => { n = true; });
      assert.ok(n);
    }
  });

  it('4. Gói lấy từ req.effectiveAccountType khi có (do requireFeature đặt)', async () => {
    let seen;
    const mw = createDailyQuotaMiddleware({
      quota: new UsageQuota({ redis: null }),
      permissionRepository: { getPermissionsByAccountType: async (t) => { seen = t; return { scopes: {} }; } },
      getLimits: () => ({ dailyPromptsDefault: 5 }),
    });
    await mw(fakeReq({ effectiveAccountType: 'Basic', user: { idaccount: 3, type: 'Premium' } }), fakeRes(), () => {});
    assert.strictEqual(seen, 'Basic');
  });

  it('5. Lỗi nội bộ thì chặn 503 (không mở toang)', async () => {
    const mw = createDailyQuotaMiddleware({
      quota: { consume: async () => { throw new Error('x'); } },
      permissionRepository: repoWith(5),
      getLimits: () => ({ dailyPromptsDefault: 5 }),
    });
    const res = fakeRes();
    let n = false;
    await mw(fakeReq(), res, () => { n = true; });
    assert.strictEqual(n, false);
    assert.strictEqual(res.statusCode, 503);
  });
});

describe('ChatbotController.handleChatStream — SSE', () => {
  function setup(serviceImpl) {
    const calls = [];
    chatbotController.chatbotService = { chatStream: async (p) => { calls.push(p); return serviceImpl ? serviceImpl(p) : p.onDone({ responseTimeMs: 1 }); } };
    chatbotController.streamGuard = new StreamGuard({ perUser: 1, global: 5 });
    return calls;
  }
  const events = (res) => res.written.filter((w) => w.startsWith('event:')).map((w) => w.split('\n')[0].slice(7));

  it('1. Câu ngoài phạm vi: trả lời từ chối cố định bằng delta + done, KHÔNG gọi dịch vụ LLM', async () => {
    const calls = setup();
    const res = fakeRes();
    await chatbotController.handleChatStream(fakeReq({ body: { message: 'Viết code Python giúp tôi' } }), res);
    assert.strictEqual(calls.length, 0);
    assert.deepStrictEqual(events(res), ['delta', 'done']);
    assert.ok(res.ended);
    assert.ok(res.written.join('').includes('trợ lý tài chính'));
  });

  it('2. Câu hợp lệ: gọi dịch vụ đúng tài khoản', async () => {
    const calls = setup();
    const res = fakeRes();
    await chatbotController.handleChatStream(fakeReq({ body: { message: 'Tháng này tôi chi bao nhiêu?', history: [] } }), res);
    assert.strictEqual(calls.length, 1);
    assert.strictEqual(calls[0].idaccount, 5);
  });

  it('3. Đang có một luồng của cùng người dùng thì luồng thứ hai bị 429 AI_STREAM_BUSY', async () => {
    setup(() => new Promise(() => {})); // luồng 1 treo
    const res1 = fakeRes();
    chatbotController.handleChatStream(fakeReq({ body: { message: 'chi tiêu tháng này' } }), res1);
    await new Promise((r) => setImmediate(r));
    const res2 = fakeRes();
    await chatbotController.handleChatStream(fakeReq({ body: { message: 'chi tiêu tháng này' } }), res2);
    assert.strictEqual(res2.statusCode, 429);
    assert.strictEqual(res2.body.code, 'AI_STREAM_BUSY');
  });

  it('4. Xong luồng thì nhả chỗ: người dùng hỏi tiếp được', async () => {
    setup();
    await chatbotController.handleChatStream(fakeReq({ body: { message: 'chi tiêu tháng này' } }), fakeRes());
    const res = fakeRes();
    await chatbotController.handleChatStream(fakeReq({ body: { message: 'ngân sách của tôi' } }), res);
    assert.notStrictEqual(res.statusCode, 429);
  });

  it('5. Lỗi bất ngờ ở dịch vụ vẫn nhả chỗ và gửi event error', async () => {
    setup(() => { throw new Error('boom'); });
    const res = fakeRes();
    await chatbotController.handleChatStream(fakeReq({ body: { message: 'chi tiêu tháng này' } }), res);
    assert.ok(events(res).includes('error'));
    const res2 = fakeRes();
    await chatbotController.handleChatStream(fakeReq({ body: { message: 'chi tiêu tháng này' } }), res2);
    assert.notStrictEqual(res2.statusCode, 429);
  });
});
