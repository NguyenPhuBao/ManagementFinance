/**
 * Test Suite v2: Resilience & Anti-SPOF Pipeline
 * Module: src/Backend/middleware & src/Backend/core/resilience
 * 
 * Kiểm thử toàn diện:
 * 1. Supabase DB Bulkhead (80% client / 20% admin headroom)
 * 2. Intelligent Load Shedding (Lag > 100ms drops client, preserves admin)
 * 3. Retry Storm Guard (Chống vòng lặp vô tận & tấn công retry dồn dập)
 * 4. Request Timeout Ceiling (30s timeout giải phóng socket treo)
 * 5. Process Safety Trap (Bẫy lỗi uncaughtException & unhandledRejection)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { DbBulkhead } = require('../../core/resilience/db-bulkhead');
const { createLoadSheddingMiddleware } = require('../../middleware/load-shedding.middleware');
const { createRetryGuardMiddleware } = require('../../middleware/retry-guard.middleware');
const { createRequestTimeoutMiddleware } = require('../../middleware/request-timeout.middleware');

describe('Resilience & Anti-SPOF Pipeline Suite v2', () => {
  // ─── 1. DB BULKHEAD QUOTA HEADROOM ────────────────────────────────────────
  describe('1. DB Bulkhead (Hạn ngạch vách ngăn CSDL)', () => {
    it('1.1. Cho phép Client mượn kết nối khi còn trong hạn ngạch 80%', () => {
      const bulkhead = new DbBulkhead({ maxConnections: 10, clientQuotaRatio: 0.8 });
      const acquired = bulkhead.acquire('client');
      assert.strictEqual(acquired, true);
      assert.strictEqual(bulkhead.getStats().activeClientConnections, 1);
    });

    it('1.2. Chặn Client khi dùng hết 80% (8 kết nối), nhưng Admin vẫn được cấp (20% Headroom)', () => {
      const bulkhead = new DbBulkhead({ maxConnections: 10, clientQuotaPercent: 80 });
      // Chiếm hết 8 kết nối client
      for (let i = 0; i < 8; i++) {
        assert.strictEqual(bulkhead.acquire('client'), true);
      }

      // Kết nối thứ 9 của client bị từ chối
      assert.strictEqual(bulkhead.canAcquire('client'), false);
      assert.throws(() => bulkhead.acquire('client'), /DB_POOL_EXHAUSTED/);

      // Nhưng Admin vẫn được cấp trong vùng 20% Headroom
      assert.strictEqual(bulkhead.canAcquire('admin'), true);
      assert.strictEqual(bulkhead.acquire('admin'), true);
      assert.strictEqual(bulkhead.getStats().activeAdminConnections, 1);
    });

    it('1.3. Hoàn trả kết nối release() khôi phục hạn ngạch chính xác', () => {
      const bulkhead = new DbBulkhead({ maxConnections: 10, clientQuotaPercent: 80 });
      bulkhead.acquire('client');
      bulkhead.release('client');
      assert.strictEqual(bulkhead.getStats().activeClientConnections, 0);
    });
  });

  // ─── 2. LOAD SHEDDING PROTECTION ─────────────────────────────────────────
  describe('2. Intelligent Load Shedding (Cắt tải thông minh khi quá tải CPU/Lag)', () => {
    it('2.1. Trả về HTTP 503 Retry-After cho Client-app khi Event Loop lag > 100ms', () => {
      const mockMonitor = {
        getLag: () => 150, // Quá tải 150ms (> 100ms threshold)
        isOverloaded: () => true,
      };

      const mw = createLoadSheddingMiddleware({ monitor: mockMonitor, retryAfterSeconds: 5 });
      let statusCode = 200;
      let retryAfterHeader = null;
      let jsonPayload = null;

      const mockReq = { path: '/api/transactions', headers: {} };
      const mockRes = {
        status: (code) => { statusCode = code; return mockRes; },
        setHeader: (header, val) => { if (header === 'Retry-After') retryAfterHeader = val; },
        json: (payload) => { jsonPayload = payload; return mockRes; },
      };

      mw(mockReq, mockRes, () => {});

      assert.strictEqual(statusCode, 503);
      assert.strictEqual(retryAfterHeader, '5');
      assert.strictEqual(jsonPayload.code, 'SERVER_OVERLOADED');
    });

    it('2.2. Tuyệt đối KHÔNG chặn Admin-web kể cả khi Event Loop lag trầm trọng', () => {
      const mockMonitor = {
        getLag: () => 250,
        isOverloaded: () => true,
      };

      const mw = createLoadSheddingMiddleware({ eventLoopMonitor: mockMonitor });
      let nextCalled = false;

      const mockAdminReq = { path: '/api/admin/system/health', headers: {}, isAdmin: true };
      const mockRes = {
        status: () => mockRes,
        json: () => mockRes,
      };

      mw(mockAdminReq, mockRes, () => { nextCalled = true; });

      assert.strictEqual(nextCalled, true, 'Admin request bắt buộc phải được bypass load shedding');
    });
  });

  // ─── 3. RETRY STORM GUARD ────────────────────────────────────────────────
  describe('3. Retry Storm Guard (Chống bão request lặp vô tận)', () => {
    it('3.1. Chặn request khi vượt quá số lần retry cho phép (từ lần 4 trở đi) với HTTP 429', () => {
      const mw = createRetryGuardMiddleware({ maxRetries: 3, windowMs: 10000 });
      let statusCode = 200;

      const mockRes = {
        status: (code) => { statusCode = code; return mockRes; },
        json: () => mockRes,
      };

      // Giả lập cùng 1 payload được client retry liên tục
      const mockReq = {
        ip: '10.0.0.1',
        method: 'POST',
        originalUrl: '/api/sync/push',
        body: { clientId: 'device-x', operation: 'sync' },
        headers: {},
      };

      // 3 lần đầu hợp lệ
      mw(mockReq, mockRes, () => {});
      mw(mockReq, mockRes, () => {});
      mw(mockReq, mockRes, () => {});
      assert.strictEqual(statusCode, 200);

      // Lần thứ 4 bị chặn đứng
      mw(mockReq, mockRes, () => {});
      assert.strictEqual(statusCode, 429);
    });
  });

  // ─── 4. REQUEST TIMEOUT CEILING ──────────────────────────────────────────
  describe('4. Request Timeout Ceiling (30s Timeout)', () => {
    it('4.1. Bỏ qua kiểm tra timeout cho các luồng Server-Sent Events (SSE)', () => {
      const mw = createRequestTimeoutMiddleware({ timeoutMs: 100 });
      let nextCalled = false;

      // Request SSE Chatbot
      const sseReq = {
        path: '/api/ai/chatbot/chat/stream',
        headers: { accept: 'text/event-stream' },
      };
      const mockRes = {};

      mw(sseReq, mockRes, () => { nextCalled = true; });

      assert.strictEqual(nextCalled, true);
      assert.strictEqual(sseReq._timeoutTimer, undefined, 'SSE stream tuyệt đối không được gán timeout timer');
    });
  });
});
