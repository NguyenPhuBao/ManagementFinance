/**
 * Unit Test — Retry Guard: Chống vòng lặp gọi lại vô hạn / Retry Storm (TDD)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { createRetryGuardMiddleware } = require('../../middleware/retry-guard.middleware');

describe('Resilience — Retry Guard Middleware (Chống Vòng Lặp Vô Tận)', () => {
  it('1. Cho phép request hợp lệ trong hạn mức retry (lần 1 và 2)', (t, done) => {
    const middleware = createRetryGuardMiddleware({ maxRetries: 3, windowMs: 5000 });
    const req = {
      ip: '127.0.0.1',
      method: 'POST',
      originalUrl: '/api/transactions',
      headers: {},
      body: { amount: 50000 },
    };
    const res = {};

    middleware(req, res, () => {
      assert.strictEqual(req._retryAttempt, 1);
      done();
    });
  });

  it('2. Chặn request khi vượt quá số lần retry cho phép (lần 4 trở đi) với mã 429', (t, done) => {
    const middleware = createRetryGuardMiddleware({ maxRetries: 3, windowMs: 5000 });
    const req = {
      ip: '192.168.1.10',
      method: 'POST',
      originalUrl: '/api/sync/process',
      headers: {},
      body: { batchId: 'batch-99' },
    };

    // Giả lập 3 lần gọi liên tiếp
    middleware(req, {}, () => {});
    middleware(req, {}, () => {});
    middleware(req, {}, () => {});

    // Lần thứ 4 phải bị chặn
    let statusCode = null;
    let responseBody = null;
    const res = {
      status: (code) => {
        statusCode = code;
        return {
          json: (body) => {
            responseBody = body;
            assert.strictEqual(statusCode, 429);
            assert.strictEqual(responseBody.code, 'RETRY_LIMIT_EXCEEDED');
            assert.strictEqual(responseBody.success, false);
            assert.ok(responseBody.backoffSeconds > 0);
            done();
          },
        };
      },
    };

    middleware(req, res, () => {
      assert.fail('Không được phép next() khi đã vượt quá số lần retry');
    });
  });

  it('3. Chặn ngay nếu client gửi header x-retry-count vượt quá ngưỡng', (t, done) => {
    const middleware = createRetryGuardMiddleware({ maxRetries: 3, windowMs: 5000 });
    const req = {
      ip: '10.0.0.1',
      method: 'GET',
      originalUrl: '/api/categories',
      headers: { 'x-retry-count': '5' },
    };

    const res = {
      status: (code) => {
        assert.strictEqual(code, 429);
        return {
          json: (body) => {
            assert.strictEqual(body.code, 'RETRY_LIMIT_EXCEEDED');
            done();
          },
        };
      },
    };

    middleware(req, res, () => {
      assert.fail('Không được cho phép khi header x-retry-count đã là 5');
    });
  });
});
