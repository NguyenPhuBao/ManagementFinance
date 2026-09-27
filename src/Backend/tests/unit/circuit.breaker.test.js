/**
 * Unit Test — Circuit Breaker for LLM Service (TDD)
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const { CircuitBreaker, CircuitBreakerOpenError } = require('../../modules/ai/features/chatbot/resilience/circuit-breaker');

describe('CircuitBreaker — Bộ Ngắt Mạch Bảo Vệ Tích Hợp Gemini AI', () => {
  let cb;

  beforeEach(() => {
    cb = new CircuitBreaker({
      failureThreshold: 5,
      cooldownPeriodMs: 300, // 300ms cho unit test chạy nhanh
      windowMs: 1000,
    });
  });

  it('1. Trạng thái ban đầu là CLOSED và cho phép request thực thi thành công', async () => {
    assert.strictEqual(cb.state, 'CLOSED');
    const result = await cb.execute(async () => 'OK');
    assert.strictEqual(result, 'OK');
    assert.strictEqual(cb.state, 'CLOSED');
  });

  it('2. Chuyển sang OPEN khi gặp đủ 5 lỗi liên tiếp', async () => {
    const failingFn = async () => { throw new Error('Gemini API 503'); };

    for (let i = 0; i < 5; i++) {
      try {
        await cb.execute(failingFn);
      } catch (err) {
        // bỏ qua lỗi nghiệp vụ
      }
    }

    assert.strictEqual(cb.state, 'OPEN', 'Sau 5 lỗi phải chuyển sang OPEN');

    // Request thứ 6 bị ngắt ngay lập tức, không gọi function nữa
    let fnExecuted = false;
    await assert.rejects(
      async () => {
        await cb.execute(async () => {
          fnExecuted = true;
          return 'OK';
        });
      },
      CircuitBreakerOpenError
    );

    assert.strictEqual(fnExecuted, false, 'Khi OPEN, hàm bên trong không được thực thi');
  });

  it('3. Tự động chuyển HALF-OPEN sau thời gian cooldown và phục hồi CLOSED nếu thành công', async () => {
    const failingFn = async () => { throw new Error('API Error'); };
    for (let i = 0; i < 5; i++) {
      try { await cb.execute(failingFn); } catch (_) {}
    }
    assert.strictEqual(cb.state, 'OPEN');

    // Chờ 350ms (vượt qua cooldown 300ms)
    await new Promise(resolve => setTimeout(resolve, 350));

    // Thử request thành công
    const result = await cb.execute(async () => 'Recovered');
    assert.strictEqual(result, 'Recovered');
    assert.strictEqual(cb.state, 'CLOSED', 'Phải phục hồi về CLOSED sau khi HALF-OPEN thành công');
    assert.strictEqual(cb.failureCount, 0);
  });
});
