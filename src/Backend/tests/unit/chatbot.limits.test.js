/**
 * Unit Test — Giới hạn chi phí & độ dài của Chatbot AI (R&D, vá lỗ hổng chi phí)
 * Phủ: cấu hình giới hạn, làm sạch lịch sử, bộ đếm hạn mức ngày, giới hạn luồng đồng thời.
 */

const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

const { getChatbotLimits } = require('../../modules/ai/features/chatbot/limits/chatbot.limits');
const { sanitizeHistory } = require('../../modules/ai/features/chatbot/limits/request-sanitizer');
const { UsageQuota } = require('../../modules/ai/features/chatbot/limits/usage-quota');
const { StreamGuard } = require('../../modules/ai/features/chatbot/limits/stream-guard');

describe('getChatbotLimits — cấu hình tập trung', () => {
  const saved = {};
  const keys = ['AI_MAX_HISTORY_ITEM_CHARS', 'AI_DAILY_PROMPTS_DEFAULT', 'AI_MAX_OUTPUT_TOKENS'];
  beforeEach(() => keys.forEach((k) => { saved[k] = process.env[k]; delete process.env[k]; }));
  afterEach(() => keys.forEach((k) => { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }));

  it('1. Có mặc định hữu hạn cho mọi giới hạn', () => {
    const l = getChatbotLimits();
    for (const k of ['maxMessageChars', 'maxHistoryItems', 'maxHistoryItemChars', 'maxOutputTokens',
      'maxToolCallsPerRound', 'maxToolRounds', 'dailyPromptsDefault', 'maxStreamsPerUser', 'maxStreamsGlobal', 'llmTimeoutMs']) {
      assert.ok(Number.isFinite(l[k]) && l[k] > 0, `${k} phải là số dương hữu hạn`);
    }
  });

  it('2. Biến môi trường ghi đè được, giá trị hỏng thì dùng mặc định', () => {
    process.env.AI_DAILY_PROMPTS_DEFAULT = '33';
    process.env.AI_MAX_OUTPUT_TOKENS = 'abc';
    const l = getChatbotLimits();
    assert.strictEqual(l.dailyPromptsDefault, 33);
    assert.ok(l.maxOutputTokens > 0 && l.maxOutputTokens !== 33);
  });
});

describe('sanitizeHistory — chặn lịch sử phình to', () => {
  const limits = { maxHistoryItems: 6, maxHistoryItemChars: 1000 };

  it('1. Không phải mảng → mảng rỗng', () => {
    assert.deepStrictEqual(sanitizeHistory(undefined, limits), []);
    assert.deepStrictEqual(sanitizeHistory('x', limits), []);
  });

  it('2. Cắt mỗi tin về tối đa maxHistoryItemChars', () => {
    const out = sanitizeHistory([{ role: 'user', text: 'a'.repeat(5_000_000) }], limits);
    assert.strictEqual(out.length, 1);
    assert.strictEqual(out[0].text.length, 1000);
  });

  it('3. Chỉ giữ maxHistoryItems tin cuối', () => {
    const h = Array.from({ length: 50 }, (_, i) => ({ role: i % 2 ? 'model' : 'user', text: `t${i}` }));
    const out = sanitizeHistory(h, limits);
    assert.strictEqual(out.length, 6);
    assert.strictEqual(out[out.length - 1].text, 't49');
  });

  it('4. Bỏ phần tử sai: không phải object, role lạ, chữ rỗng hoặc không phải chuỗi', () => {
    const out = sanitizeHistory([null, 5, { role: 'system', text: 'x' }, { role: 'user', text: '   ' }, { role: 'user', text: 123 }, { role: 'user', text: 'ok' }], limits);
    assert.deepStrictEqual(out, [{ role: 'user', text: 'ok' }]);
  });

  it('5. Chấp nhận trường content và role assistant, chuẩn hoá về model', () => {
    const out = sanitizeHistory([{ role: 'assistant', content: 'xin chào' }], limits);
    assert.deepStrictEqual(out, [{ role: 'model', text: 'xin chào' }]);
  });
});

describe('UsageQuota — hạn mức lời nhắc theo ngày', () => {
  it('1. Cho qua tới đúng hạn mức rồi chặn', async () => {
    const q = new UsageQuota({ redis: null, now: () => new Date('2026-11-07T03:00:00Z') });
    for (let i = 1; i <= 3; i++) {
      const r = await q.consume(7, 3);
      assert.strictEqual(r.allowed, true);
      assert.strictEqual(r.used, i);
    }
    const blocked = await q.consume(7, 3);
    assert.strictEqual(blocked.allowed, false);
    assert.ok(blocked.retryAfterSeconds > 0 && blocked.retryAfterSeconds <= 86400);
  });

  it('2. Tách theo người dùng', async () => {
    const q = new UsageQuota({ redis: null, now: () => new Date('2026-11-07T03:00:00Z') });
    await q.consume(1, 1);
    const other = await q.consume(2, 1);
    assert.strictEqual(other.allowed, true);
  });

  it('3. Sang ngày mới (giờ Việt Nam) thì bộ đếm về 0', async () => {
    let t = new Date('2026-11-07T16:00:00Z'); // 23:00 ngày 7 theo giờ VN
    const q = new UsageQuota({ redis: null, now: () => t });
    await q.consume(1, 1);
    assert.strictEqual((await q.consume(1, 1)).allowed, false);
    t = new Date('2026-11-07T17:30:00Z'); // 00:30 ngày 8 theo giờ VN
    assert.strictEqual((await q.consume(1, 1)).allowed, true);
  });

  it('4. Redis sẵn sàng thì dùng INCR và đặt hạn khóa ở lần đầu', async () => {
    const calls = [];
    let n = 0;
    const redis = {
      status: 'ready',
      incr: async (k) => { calls.push(['incr', k]); return ++n; },
      expire: async (k, s) => { calls.push(['expire', k, s]); },
    };
    const q = new UsageQuota({ redis, now: () => new Date('2026-11-07T03:00:00Z') });
    const r = await q.consume(9, 5);
    assert.strictEqual(r.allowed, true);
    assert.ok(calls.some((c) => c[0] === 'incr' && c[1].includes(':9:20261107')));
    assert.ok(calls.some((c) => c[0] === 'expire'));
  });

  it('5. Redis lỗi thì rơi về bộ đếm trong bộ nhớ, KHÔNG mở toang', async () => {
    const redis = { status: 'ready', incr: async () => { throw new Error('boom'); }, expire: async () => {} };
    const q = new UsageQuota({ redis, now: () => new Date('2026-11-07T03:00:00Z') });
    assert.strictEqual((await q.consume(1, 1)).allowed, true);
    assert.strictEqual((await q.consume(1, 1)).allowed, false);
  });
});

describe('StreamGuard — giới hạn luồng SSE đồng thời', () => {
  it('1. Mỗi người dùng tối đa perUser luồng', () => {
    const g = new StreamGuard({ perUser: 1, global: 10 });
    const r1 = g.acquire(1);
    assert.ok(typeof r1 === 'function');
    assert.strictEqual(g.acquire(1), null);
    r1();
    assert.ok(typeof g.acquire(1) === 'function');
  });

  it('2. Trần toàn hệ thống', () => {
    const g = new StreamGuard({ perUser: 5, global: 2 });
    assert.ok(g.acquire(1));
    assert.ok(g.acquire(2));
    assert.strictEqual(g.acquire(3), null);
  });

  it('3. Nhả slot hai lần chỉ tính một lần', () => {
    const g = new StreamGuard({ perUser: 1, global: 1 });
    const release = g.acquire(1);
    release();
    release();
    assert.ok(g.acquire(2));
    assert.strictEqual(g.acquire(3), null);
  });
});
