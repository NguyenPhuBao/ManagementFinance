/**
 * Unit Test — Redis Token Bucket Limiter (TDD)
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const { TokenBucketLimiter } = require('../../modules/ai/features/chatbot/rate-limiter/redis-token-bucket');

describe('TokenBucketLimiter — Thuật Toán Giới Hạn Tần Suất 15 req/phút', () => {
  let limiter;

  beforeEach(() => {
    // Khởi tạo limiter không có redis (dùng in-memory fallback) để test độc lập
    limiter = new TokenBucketLimiter({
      capacity: 15,
      refillRatePerMinute: 15,
      redisClient: null,
    });
  });

  it('1. Cho phép request đầu tiên và tiêu thụ 1 token', async () => {
    const result = await limiter.consume('user_1');
    assert.strictEqual(result.allowed, true);
    assert.strictEqual(result.remaining, 14);
  });

  it('2. Cho phép tối đa 15 requests và chặn request thứ 16', async () => {
    for (let i = 0; i < 15; i++) {
      const res = await limiter.consume('user_limit');
      assert.strictEqual(res.allowed, true, `Request ${i + 1} phải được phép`);
    }

    const blocked = await limiter.consume('user_limit');
    assert.strictEqual(blocked.allowed, false, 'Request thứ 16 phải bị chặn');
    assert.strictEqual(blocked.remaining, 0);
    assert.ok(blocked.retryAfterSeconds > 0, 'Phải có thời gian chờ thử lại');
  });

  it('3. Token được hồi phục dần theo thời gian (Token Refill)', async () => {
    // Dùng limiter cấu hình tốc độ nhanh hơn để test: 60 tokens/phút = 1 token/giây
    const fastLimiter = new TokenBucketLimiter({
      capacity: 2,
      refillRatePerMinute: 120, // 2 token/giây
      redisClient: null,
    });

    await fastLimiter.consume('user_refill');
    await fastLimiter.consume('user_refill');
    const blocked = await fastLimiter.consume('user_refill');
    assert.strictEqual(blocked.allowed, false);

    // Chờ 600ms (đủ để hồi ít nhất 1 token)
    await new Promise(resolve => setTimeout(resolve, 600));

    const retry = await fastLimiter.consume('user_refill');
    assert.strictEqual(retry.allowed, true, 'Sau thời gian chờ phải hồi token');
  });

  it('4. Phân tách hạn ngạch giữa các user khác nhau', async () => {
    for (let i = 0; i < 15; i++) {
      await limiter.consume('user_A');
    }
    const blockA = await limiter.consume('user_A');
    assert.strictEqual(blockA.allowed, false);

    const allowB = await limiter.consume('user_B');
    assert.strictEqual(allowB.allowed, true);
  });
});
