/**
 * Giới hạn chatbot theo gói chỉnh bằng biến môi trường (Chủ dự án chốt 2026-11-16, cột Phạm vi ẩn khỏi Admin-web):
 * AI_DAILY_PROMPTS_BASIC / _PREMIUM, AI_CONTEXT_WINDOW_DAYS_BASIC / _PREMIUM.
 * Thứ tự: biến môi trường (nếu đặt) → số trong CSDL (scope_config) → mặc định trong mã.
 */
const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { createDailyQuotaMiddleware } = require('../../modules/ai/features/chatbot/limits/quota.middleware');
const { UsageQuota } = require('../../modules/ai/features/chatbot/limits/usage-quota');

const ENV_KEYS = ['AI_DAILY_PROMPTS_BASIC', 'AI_DAILY_PROMPTS_PREMIUM', 'AI_CONTEXT_WINDOW_DAYS_BASIC', 'AI_CONTEXT_WINDOW_DAYS_PREMIUM', 'AI_DAILY_PROMPTS_DEFAULT'];

const fakeRes = () => ({
  statusCode: 200, headers: {}, body: null,
  setHeader(k, v) { this.headers[k] = v; },
  status(c) { this.statusCode = c; return this; },
  json(b) { this.body = b; return this; },
});

const repo = (scope) => ({ getPermissionsByAccountType: async () => ({ scopes: { ai_assistant: scope } }) });

async function run({ type = 'Premium', scope }) {
  const mw = createDailyQuotaMiddleware({ quota: new UsageQuota({ redis: null }), permissionRepository: repo(scope) });
  const req = { user: { idaccount: 7, type }, effectiveAccountType: type, body: { message: 'Tháng này tôi chi bao nhiêu?' }, on() {} };
  const res = fakeRes();
  let passed = false;
  await mw(req, res, () => { passed = true; });
  return { req, res, passed };
}

describe('Giới hạn chatbot theo gói: biến môi trường thắng CSDL', () => {
  const saved = {};
  beforeEach(() => { for (const k of ENV_KEYS) { saved[k] = process.env[k]; delete process.env[k]; } });
  afterEach(() => { for (const k of ENV_KEYS) { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; } });

  it('không đặt biến → dùng số trong CSDL như trước', async () => {
    const { res, req, passed } = await run({ scope: { daily_prompts: 10, context_window_days: 60 } });
    assert.ok(passed);
    assert.equal(res.headers['X-AI-Quota-Limit'], 10);
    assert.equal(req.aiContextWindowDays, 60);
  });

  it('AI_DAILY_PROMPTS_PREMIUM và AI_CONTEXT_WINDOW_DAYS_PREMIUM thắng CSDL cho gói Premium', async () => {
    process.env.AI_DAILY_PROMPTS_PREMIUM = '3';
    process.env.AI_CONTEXT_WINDOW_DAYS_PREMIUM = '30';
    const { res, req } = await run({ scope: { daily_prompts: 10, context_window_days: 60 } });
    assert.equal(res.headers['X-AI-Quota-Limit'], 3);
    assert.equal(req.aiContextWindowDays, 30);
  });

  it('biến của Basic chỉ áp cho Basic, không đụng Premium', async () => {
    process.env.AI_DAILY_PROMPTS_BASIC = '2';
    process.env.AI_CONTEXT_WINDOW_DAYS_BASIC = '7';
    const basic = await run({ type: 'Basic', scope: { daily_prompts: 10, context_window_days: 60 } });
    assert.equal(basic.res.headers['X-AI-Quota-Limit'], 2);
    assert.equal(basic.req.aiContextWindowDays, 7);
    const premium = await run({ type: 'Premium', scope: { daily_prompts: 10, context_window_days: 60 } });
    assert.equal(premium.res.headers['X-AI-Quota-Limit'], 10);
    assert.equal(premium.req.aiContextWindowDays, 60);
  });

  it('biến = 0 được nhận (chặn hết lượt); giá trị hỏng thì bỏ qua, quay về CSDL', async () => {
    process.env.AI_DAILY_PROMPTS_PREMIUM = '0';
    const zero = await run({ scope: { daily_prompts: 10 } });
    assert.equal(zero.res.statusCode, 429);
    process.env.AI_DAILY_PROMPTS_PREMIUM = 'abc';
    const bad = await run({ scope: { daily_prompts: 10 } });
    assert.equal(bad.res.headers['X-AI-Quota-Limit'], 10);
  });
});
