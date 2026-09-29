/**
 * Unit Test — Request Timeout Middleware (TDD)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { createRequestTimeoutMiddleware } = require('../../middleware/request-timeout.middleware');

describe('Resilience — Request Timeout Middleware', () => {
  it('1. Bỏ qua kiểm tra timeout cho luồng Server-Sent Events (SSE)', (t, done) => {
    const middleware = createRequestTimeoutMiddleware({ timeoutMs: 100 });
    const req = {
      headers: { accept: 'text/event-stream' },
      path: '/api/ai/chatbot/stream',
    };
    const res = {};

    middleware(req, res, () => {
      assert.strictEqual(req._timeoutTimer, undefined, 'SSE stream không được gán timeout');
      done();
    });
  });

  it('2. Hủy timer khi request hoàn tất bình thường trước hạn', (t, done) => {
    const middleware = createRequestTimeoutMiddleware({ timeoutMs: 200 });
    const req = { headers: {}, path: '/api/categories' };

    let finishListener = null;
    const res = {
      headersSent: false,
      on: (event, cb) => {
        if (event === 'finish') finishListener = cb;
      },
    };

    middleware(req, res, () => {
      assert.ok(req._timeoutTimer, 'Timer phải được khởi tạo');
      // Giả lập response kết thúc
      finishListener();
      assert.strictEqual(req._timeoutCleared, true, 'Timer phải được dọn dẹp');
      done();
    });
  });

  it('3. Trả về HTTP 504 Gateway Timeout khi request bị treo quá thời hạn', (t, done) => {
    const middleware = createRequestTimeoutMiddleware({ timeoutMs: 50 });
    const req = {
      headers: {},
      path: '/api/slow-task',
      socket: { destroy: () => {} },
    };

    let statusCode = null;
    let responseBody = null;
    const res = {
      headersSent: false,
      status: (code) => {
        statusCode = code;
        return {
          json: (body) => {
            responseBody = body;
            assert.strictEqual(statusCode, 504);
            assert.strictEqual(responseBody.code, 'REQUEST_TIMEOUT');
            assert.strictEqual(responseBody.success, false);
            done();
          },
        };
      },
      on: () => {},
    };

    middleware(req, res, () => {
      // Giả lập controller bị treo không gọi res.send/res.json
    });
  });
});
