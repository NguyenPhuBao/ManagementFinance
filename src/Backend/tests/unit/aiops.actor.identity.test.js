/**
 * Test Suite: AIOps Actor Identity, Role Classification & Localhost Quarantine Shield
 * Module: src/Backend/modules/aiops
 * 
 * Kiểm thử 2 Tầng:
 * 1. Khóa Chống Tự Phong Tỏa (Localhost & Loopback Shield Protection):
 *    - Tuyệt đối từ chối phong tỏa 127.0.0.1, ::1, localhost, 0.0.0.0 trong mọi môi trường (kể cả production).
 *    - quarantineActor qua hash hoặc rawIp từ chối phong tỏa IP loopback.
 *    - isProtectedIp() nhận diện chính xác các IP thuộc danh sách bất khả xâm phạm.
 * 2. Bóc Tách Danh Tính & Phân Quyền Sớm (Early Token Identification):
 *    - Request có Authorization Bearer Token hợp lệ của Admin: gán username, userId, role = 'Admin'.
 *    - Request có Authorization Bearer Token hợp lệ của User: gán username, userId, role = 'User'.
 *    - Request không có Token: gán role = 'Guest', username = 'Khách vãng lai / Ẩn danh'.
 * 3. System Internal Resource Anomaly Actor:
 *    - Sự cố MEMORY_EXHAUSTION, EVENT_LOOP_FREEZE gán actor là System Internal với role = 'System'.
 * 4. Repository Serialization & Flat Mapping:
 *    - Lưu và ánh xạ đầy đủ actor_role, username, user_id, actor_identity ở cả cấp lồng nhau và cấp phẳng.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const EventEmitter = require('node:events');
const config = require('../../config');

const { AIOpsQuarantine, hashIp } = require('../../modules/aiops/aiops.quarantine');
const { FeatureCollector } = require('../../modules/aiops/feature.collector');
const { AnomalyDetector } = require('../../modules/aiops/anomaly.detector');
const { AIOpsIncidentRepository } = require('../../modules/aiops/aiops.repository');

describe('AIOps Actor Identity & Localhost Quarantine Shield Suite', () => {
  const jwtSecret = (config.jwt && config.jwt.accessSecret) || 'test-secret';

  // ─── 1. LOCALHOST & LOOPBACK QUARANTINE SHIELD ──────────────────────────────
  describe('1. Khóa Chống Tự Phong Tỏa (Localhost & Loopback Shield Protection)', () => {
    it('1.1. Từ chối phong tỏa 127.0.0.1, ::1, localhost kể cả khi không ở môi trường development', () => {
      const quarantine = new AIOpsQuarantine();
      
      const resIpv4 = quarantine.quarantine('127.0.0.1', 'Nghi vấn tấn công');
      assert.strictEqual(resIpv4, null, 'quarantine(127.0.0.1) phải trả về null');

      const resIpv6 = quarantine.quarantine('::1', 'Nghi vấn tấn công');
      assert.strictEqual(resIpv6, null, 'quarantine(::1) phải trả về null');

      const resLocalhost = quarantine.quarantine('localhost', 'Nghi vấn');
      assert.strictEqual(resLocalhost, null, 'quarantine(localhost) phải trả về null');

      assert.strictEqual(quarantine.getQuarantinedList().length, 0, 'Danh sách cách ly phải hoàn toàn trống');
    });

    it('1.2. quarantineActor qua rawIp hoặc ipHash từ chối cô lập các IP loopback/nội bộ', () => {
      const quarantine = new AIOpsQuarantine();
      
      const resRaw = quarantine.quarantineActor({ rawIp: '127.0.0.1' });
      assert.strictEqual(resRaw, null, 'quarantineActor rawIp 127.0.0.1 phải bị từ chối');

      const loopbackHash = hashIp('127.0.0.1');
      const resHash = quarantine.quarantineActor({ ipHash: loopbackHash });
      assert.strictEqual(resHash, null, 'quarantineActor qua hash của 127.0.0.1 phải bị từ chối');

      const resSystemHash = quarantine.quarantineActor({ ipHash: 'system_core' });
      assert.strictEqual(resSystemHash, null, 'quarantineActor system_core phải bị từ chối');
    });

    it('1.3. isProtectedIp nhận diện chính xác các địa chỉ nội bộ và hệ thống', () => {
      const quarantine = new AIOpsQuarantine();
      assert.strictEqual(quarantine.isProtectedIp('127.0.0.1'), true);
      assert.strictEqual(quarantine.isProtectedIp('::1'), true);
      assert.strictEqual(quarantine.isProtectedIp('localhost'), true);
      assert.strictEqual(quarantine.isProtectedIp('0.0.0.0'), true);
      assert.strictEqual(quarantine.isProtectedIp('system_core'), true);
      assert.strictEqual(quarantine.isProtectedIp('113.161.22.45'), false);
    });
  });

  // ─── 2. EARLY TOKEN IDENTIFICATION & PHÂN QUYỀN ─────────────────────────────
  describe('2. Bóc Tách Danh Tính & Phân Quyền Sớm (Early Token Identification)', () => {
    it('2.1. Request có Bearer Token của Admin được bóc tách sớm username, userId, role = Admin', () => {
      const collector = new FeatureCollector({ windowSeconds: 10 });
      const mw = collector.createMiddleware();

      const adminToken = jwt.sign(
        { idaccount: 1, username: 'superadmin', idrole: 1, rolename: 'Admin' },
        jwtSecret
      );

      const req = {
        ip: '113.161.12.34',
        headers: {
          authorization: `Bearer ${adminToken}`,
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        method: 'POST',
        originalUrl: '/api/admin/settings',
      };
      const res = new EventEmitter();
      res.statusCode = 200;

      let nextCalled = false;
      mw(req, res, () => { nextCalled = true; });
      res.emit('finish');

      assert.strictEqual(nextCalled, true);

      // Lấy sample
      const sample = collector.getSample();
      assert.strictEqual(sample.requestsPerMin > 0, true);
      
      // Giả lập tiếp nếu IP này có request lỗi dồn dập (ví dụ failed logins hoặc burst)
      collector.recordFailedLogin();
      // Cho req vào lại để kiểm tra suspectActors
      const reqFail = {
        ip: '113.161.12.34',
        headers: {
          authorization: `Bearer ${adminToken}`,
          'user-agent': 'Mozilla/5.0',
        },
        originalUrl: '/api/auth/login',
      };
      const resFail = new EventEmitter();
      resFail.statusCode = 401;
      mw(reqFail, resFail, () => {});
      resFail.emit('finish');

      const sample2 = collector.getSample();
      assert.ok(sample2.suspectActors.length > 0, 'Phải có suspect actor');
      const actor = sample2.suspectActors[0];
      assert.strictEqual(actor.userId, 1);
      assert.strictEqual(actor.username, 'superadmin');
      assert.strictEqual(actor.role, 'Admin');
    });

    it('2.2. Request có Bearer Token của Khách hàng (User) được gán role = User', () => {
      const collector = new FeatureCollector({ windowSeconds: 10 });
      const mw = collector.createMiddleware();

      const userToken = jwt.sign(
        { idaccount: 42, username: 'nguyenvan_a', idrole: 2, rolename: 'User' },
        jwtSecret
      );

      const req = {
        ip: '14.232.10.20',
        headers: {
          authorization: `Bearer ${userToken}`,
          'user-agent': 'Mobile-App/2.1',
        },
        originalUrl: '/api/transactions',
      };
      const res = new EventEmitter();
      res.statusCode = 400;

      collector.recordMalformedRequest();
      mw(req, res, () => {});
      res.emit('finish');

      const sample = collector.getSample();
      assert.ok(sample.suspectActors.length > 0);
      const actor = sample.suspectActors[0];
      assert.strictEqual(actor.userId, 42);
      assert.strictEqual(actor.username, 'nguyenvan_a');
      assert.strictEqual(actor.role, 'User');
    });

    it('2.3. Request không có Token được gán role = Guest và nhãn Khách vãng lai / Ẩn danh', () => {
      const collector = new FeatureCollector({ windowSeconds: 10 });
      const mw = collector.createMiddleware();

      const req = {
        ip: '27.72.55.88',
        headers: {},
        originalUrl: '/api/auth/login',
      };
      const res = new EventEmitter();
      res.statusCode = 401;

      collector.recordFailedLogin();
      mw(req, res, () => {});
      res.emit('finish');

      const sample = collector.getSample();
      const actor = sample.suspectActors[0];
      assert.strictEqual(actor.userId, null);
      assert.strictEqual(actor.role, 'Guest');
      assert.strictEqual(actor.username, 'Khách vãng lai / Ẩn danh');
    });
  });

  // ─── 3. SYSTEM INTERNAL RESOURCE ANOMALY ACTOR ─────────────────────────────
  describe('3. Nhận diện Đúng Nguồn Gốc Sự Cố Tài Nguyên (System Internal)', () => {
    it('3.1. Sự cố MEMORY_EXHAUSTION gán actor là System Internal với role = System', () => {
      const detector = new AnomalyDetector();
      const sample = {
        timestamp: new Date().toISOString(),
        requestsPerMin: 50,
        errorRate4xx: 0,
        errorRate5xx: 0,
        failedLogins: 0,
        tokenReuseAttacks: 0,
        malformedRequests: 0,
        eventLoopLagMs: 10,
        cpuPercent: 30,
        ramPercent: 95, // Vượt 92%
        dbPoolActive: 2,
        loadSheddingCount: 0,
        distinctIpsCount: 1,
        suspectActors: [],
      };

      const result = detector.evaluate(sample);
      const ramAnomaly = result.anomalies.find((a) => a.code === 'MEMORY_EXHAUSTION');
      assert.ok(ramAnomaly, 'Phải có sự cố MEMORY_EXHAUSTION');
      assert.strictEqual(ramAnomaly.actor.type, 'SYSTEM_INTERNAL');
      assert.strictEqual(ramAnomaly.actor.role, 'System');
      assert.strictEqual(ramAnomaly.actor.username, 'System Core Engine');
      assert.strictEqual(ramAnomaly.actor.identity, 'Hạ tầng máy chủ (Node.js & Database)');
    });
  });

  // ─── 4. REPOSITORY SERIALIZATION & FLAT MAPPING ────────────────────────────
  describe('4. Lưu Trữ và Ánh Xạ Phẳng Thông Tin Actor trong Repository', () => {
    it('4.1. _mapRow trả về cả object lồng nhau và các trường phẳng (role, username, userId, actorIdentity)', () => {
      const repo = new AIOpsIncidentRepository({ pool: null });

      const mockDbRow = {
        id: 'inc_test_100',
        code: 'MEMORY_EXHAUSTION',
        vector: 'resource',
        severity: 'HIGH',
        message: 'RAM vượt 92%',
        status: 'ACTIVE',
        actor_type: 'SYSTEM_INTERNAL',
        actor_identity: 'Hạ tầng máy chủ (Node.js & Database)',
        actor_hash: 'system_core',
        user_id: null,
        username: 'System Core Engine',
        actor_role: 'System',
        user_agent: 'Node.js runtime',
        target_endpoint: 'Background Event Loop',
        metric_current: '95',
        metric_baseline: '50',
        metric_unit: '% RAM',
        mitigation_taken: 'Cảnh báo quản trị viên',
        root_cause_diagnosis: 'Bộ nhớ vượt ngưỡng',
        hits: 1,
        first_detected_at: new Date(),
        last_seen_at: new Date(),
        mitigated_at: null,
      };

      const mapped = repo._mapRow(mockDbRow);
      
      // Kiểm tra object lồng nhau
      assert.strictEqual(mapped.actor.type, 'SYSTEM_INTERNAL');
      assert.strictEqual(mapped.actor.role, 'System');
      assert.strictEqual(mapped.actor.username, 'System Core Engine');
      assert.strictEqual(mapped.actor.identity, 'Hạ tầng máy chủ (Node.js & Database)');

      // Kiểm tra các trường phẳng thuận tiện cho Frontend
      assert.strictEqual(mapped.actorIdentity, 'Hạ tầng máy chủ (Node.js & Database)');
      assert.strictEqual(mapped.actor_identity, 'Hạ tầng máy chủ (Node.js & Database)');
      assert.strictEqual(mapped.actorHash, 'system_core');
      assert.strictEqual(mapped.actor_hash, 'system_core');
      assert.strictEqual(mapped.username, 'System Core Engine');
      assert.strictEqual(mapped.role, 'System');
      assert.strictEqual(mapped.actor_role, 'System');
      assert.strictEqual(mapped.userId, null);
    });
  });
});
