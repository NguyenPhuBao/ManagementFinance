/**
 * Test Suite v2: AIOps Sentinel Multi-Vector & Active Quarantine Shield
 * Module: src/Backend/modules/aiops
 * 
 * Kiểm thử toàn diện:
 * 1. 4-Vector Risk Decomposition (Auth, Traffic, Exploit, Resource)
 * 2. Adaptive Baseline & Anti-Poisoning Protection (Threat Score < 70)
 * 3. Dynamic Concurrency Scaling (100 -> 50,000 CCU)
 * 4. Active Quarantine Shield (Auto HTTP 403, Zero Raw IP, Admin Fast-Lane Bypass)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { AnomalyDetector } = require('../../modules/aiops/anomaly.detector');
const { AIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
const { FeatureCollector } = require('../../modules/aiops/feature.collector');

describe('AIOps Sentinel Multi-Vector & Quarantine Suite v2', () => {
  // ─── 1. MULTI-VECTOR RISK DECOMPOSITION ──────────────────────────────────
  describe('1. Phân rã 4 Vector Rủi Ro Độc Lập', () => {
    it('1.1. Trả về đúng 4 điểm vector riêng biệt và danh mục tấn công tương ứng', () => {
      const detector = new AnomalyDetector();
      const sample = {
        timestamp: new Date().toISOString(),
        requestsPerMin: 120,
        errorRate4xx: 0.02,
        errorRate5xx: 0.00,
        failedLogins: 20, // Tấn công Brute-force mạnh
        tokenReuseAttacks: 2, // Tấn công cướp quyền Token
        malformedRequests: 0,
        eventLoopLagMs: 8,
        cpuPercent: 25,
        ramPercent: 45,
        dbPoolActive: 5,
        loadSheddingCount: 0,
        distinctIpsCount: 15,
      };

      const result = detector.evaluate(sample);

      assert.ok(result.vectorScores, 'Phải có trường vectorScores');
      assert.strictEqual(typeof result.vectorScores.auth, 'number');
      assert.strictEqual(typeof result.vectorScores.traffic, 'number');
      assert.strictEqual(typeof result.vectorScores.exploit, 'number');
      assert.strictEqual(typeof result.vectorScores.resource, 'number');

      // Vector Auth phải ghi nhận điểm cao vượt trội so với các vector khác
      assert.ok(result.vectorScores.auth >= 60, 'Vector Auth phải tăng cao do bị brute-force và token reuse');
      assert.ok(result.vectorScores.traffic < 40, 'Vector Traffic phải thấp vì lưu lượng bình thường');
      assert.ok(result.vectorScores.resource < 40, 'Vector Resource phải thấp vì RAM/CPU ổn định');
    });

    it('1.2. Cá nhân hóa phòng thủ theo từng vector (Per-Vector Defense)', () => {
      const detector = new AnomalyDetector();
      // Giả lập tấn công Exploit (SQLi, Malformed payload)
      const exploitSample = {
        timestamp: new Date().toISOString(),
        requestsPerMin: 60,
        errorRate4xx: 0.45,
        errorRate5xx: 0.10,
        failedLogins: 0,
        tokenReuseAttacks: 0,
        malformedRequests: 25, // Thăm dò khai thác lỗ hổng
        eventLoopLagMs: 10,
        cpuPercent: 20,
        ramPercent: 40,
        dbPoolActive: 3,
        loadSheddingCount: 0,
        distinctIpsCount: 10,
      };

      const result = detector.evaluate(exploitSample);
      assert.ok(result.vectorScores.exploit > 50, 'Vector Exploit phải báo động');
      assert.ok(result.vectorDefenses, 'Phải có cấu hình phòng thủ theo vector');
      assert.ok(result.vectorDefenses.exploit, 'Vector Exploit phải có hành động phòng thủ riêng biệt');
      assert.notStrictEqual(result.recommendedAction, 'EMERGENCY_MAINTENANCE', 'Không được bật bảo trì toàn hệ thống khi chỉ bị tấn công đơn lẻ 1 vector');
    });
  });

  // ─── 2. DYNAMIC CONCURRENCY SCALING ──────────────────────────────────────
  describe('2. Dynamic Concurrency Scaling (Thích ứng theo quy mô CCU)', () => {
    it('2.1. setConcurrencyScale(5000) tự động nâng baseline mà không báo động giả', () => {
      const detector = new AnomalyDetector();
      detector.setConcurrencyScale(5000);

      // Lưu lượng 4000 req/min là hoàn toàn bình thường ở quy mô 5000 CCU
      const busySample = {
        timestamp: new Date().toISOString(),
        requestsPerMin: 4000,
        errorRate4xx: 0.01,
        errorRate5xx: 0.00,
        failedLogins: 2,
        tokenReuseAttacks: 0,
        malformedRequests: 0,
        eventLoopLagMs: 20,
        cpuPercent: 55,
        ramPercent: 65,
        dbPoolActive: 8,
        loadSheddingCount: 0,
        distinctIpsCount: 3000,
      };

      const result = detector.evaluate(busySample);
      assert.strictEqual(result.status, 'NORMAL');
      assert.ok(result.threatScore < 50, 'Không được báo động nhầm khi lưu lượng tăng trưởng hữu cơ trong hạn mức CCU');
    });

    it('2.2. Chặn ngưỡng CCU tối thiểu không được dưới 100', () => {
      const detector = new AnomalyDetector();
      detector.setConcurrencyScale(50); // Dưới 100 -> Kẹp về 100
      assert.strictEqual(detector.targetConcurrency, 100);

      detector.setConcurrencyScale(20000);
      assert.strictEqual(detector.targetConcurrency, 20000);
    });
  });

  // ─── 3. ACTIVE QUARANTINE SHIELD ─────────────────────────────────────────
  describe('3. Khiên Chắn Cách Ly Chủ Động (Active Quarantine)', () => {
    it('3.1. Chặn đứng IP bị cách ly với mã HTTP 403 và trả về lý do an ninh', () => {
      const quarantine = new AIOpsQuarantine({ defaultTtlMinutes: 15 });
      quarantine.quarantine('198.51.100.42', 'DDoS Attack Flood');

      const mw = quarantine.createMiddleware();
      let statusCode = 200;
      let jsonPayload = null;

      const mockReq = { ip: '198.51.100.42', headers: {} };
      const mockRes = {
        status: (code) => { statusCode = code; return mockRes; },
        json: (payload) => { jsonPayload = payload; return mockRes; },
      };

      mw(mockReq, mockRes, () => {});

      assert.strictEqual(statusCode, 403);
      assert.strictEqual(jsonPayload.code, 'AIOPS_QUARANTINED');
      assert.ok(jsonPayload.message.includes('phong tỏa'));
    });

    it('3.2. Tuyệt đối KHÔNG chặn Admin kể cả khi phát sinh từ cùng IP bị cách ly', () => {
      const quarantine = new AIOpsQuarantine({ defaultTtlMinutes: 15 });
      quarantine.quarantine('198.51.100.42', 'Attack source');

      const mw = quarantine.createMiddleware();
      let nextCalled = false;

      // Request có cờ req.isAdmin = true từ admin-priority middleware
      const mockAdminReq = { ip: '198.51.100.42', headers: {}, isAdmin: true };
      const mockRes = {
        status: () => mockRes,
        json: () => mockRes,
      };

      mw(mockAdminReq, mockRes, () => { nextCalled = true; });

      assert.strictEqual(nextCalled, true, 'Admin request bắt buộc phải được thông suốt (Bypass Quarantine)');
    });

    it('3.3. Tuân thủ Zero Raw IP: getQuarantinedList trả về IP đã che mờ (Masked)', () => {
      const quarantine = new AIOpsQuarantine();
      quarantine.quarantine('203.162.10.88', 'Scan port probe');

      const list = quarantine.getQuarantinedList();
      assert.strictEqual(list.length, 1);
      assert.strictEqual(list[0].maskedIp, '203.162.xx.xx', 'IP thô phải được che mờ thành 203.162.xx.xx');
      assert.ok(list[0].hash, 'Phải có hash SHA-256 ẩn danh');
    });
  });
});
