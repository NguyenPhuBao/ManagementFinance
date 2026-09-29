/**
 * Unit Test — Event Loop Monitor & Load Shedding Middleware (TDD)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { createLoadSheddingMiddleware } = require('../../middleware/load-shedding.middleware');

describe('Resilience — Load Shedding & Event Loop Protection', () => {
  it('1. Cho phép request thông thường khi hệ thống không bị quá tải (lag bình thường)', (t, done) => {
    const mockMonitor = {
      isOverloaded: () => false,
      getLag: () => 5,
    };

    const middleware = createLoadSheddingMiddleware({ monitor: mockMonitor });
    const req = { path: '/api/transactions', headers: {} };
    const res = {};

    middleware(req, res, () => {
      done();
    });
  });

  it('2. Trả về HTTP 503 minh bạch kèm header Retry-After cho Client-app khi Event Loop quá tải (>100ms)', (t, done) => {
    const mockMonitor = {
      isOverloaded: () => true,
      getLag: () => 150,
    };

    const middleware = createLoadSheddingMiddleware({ monitor: mockMonitor, retryAfterSeconds: 5 });
    const req = { path: '/api/transactions', headers: {} };

    let setHeaders = {};
    let statusCode = null;
    let responseBody = null;

    const res = {
      setHeader: (name, val) => {
        setHeaders[name] = val;
      },
      status: (code) => {
        statusCode = code;
        return {
          json: (body) => {
            responseBody = body;
            assert.strictEqual(statusCode, 503);
            assert.strictEqual(setHeaders['Retry-After'], '5');
            assert.strictEqual(responseBody.code, 'SERVER_OVERLOADED');
            assert.strictEqual(responseBody.success, false);
            assert.ok(responseBody.message.includes('lượng truy cập lớn'));
            done();
          },
        };
      },
    };

    middleware(req, res, () => {
      assert.fail('Không được cho client-app đi qua khi hệ thống đang quá tải');
    });
  });

  it('3. Tuyệt đối KHÔNG chặn request của Admin-web kể cả khi hệ thống đang quá tải (Bypass Load Shedding)', (t, done) => {
    const mockMonitor = {
      isOverloaded: () => true,
      getLag: () => 200,
    };

    const middleware = createLoadSheddingMiddleware({ monitor: mockMonitor });
    
    // Request từ Admin
    const reqAdmin = {
      path: '/api/admin/dashboard',
      headers: {},
      isAdmin: true,
    };
    const res = {};

    middleware(reqAdmin, res, () => {
      // Đi qua thành công!
      done();
    });
  });
});
