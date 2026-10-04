const test = require('node:test');
const assert = require('node:assert/strict');
const { AnomalyDetector } = require('../../modules/aiops/anomaly.detector');

test('AIOps Hybrid Anomaly Detector Suite', async (t) => {
  await t.test('1. Baseline normal condition returns NORMAL status and low Threat Score', () => {
    const detector = new AnomalyDetector();
    const sample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 120,
      errorRate4xx: 0.01,
      errorRate5xx: 0,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 0,
      eventLoopLagMs: 5,
      cpuPercent: 15,
      ramPercent: 40,
      dbPoolActive: 2,
      loadSheddingCount: 0,
      distinctIpsCount: 20,
    };

    const result = detector.evaluate(sample);

    assert.strictEqual(result.status, 'NORMAL');
    assert.strictEqual(result.isAnomaly, false);
    assert.ok(result.threatScore < 30, `Threat score should be low: ${result.threatScore}`);
    assert.strictEqual(result.anomalies.length, 0);
    assert.strictEqual(result.recommendedAction, null);
  });

  await t.test('2. Brute-force login attack triggers WARNING or CRITICAL with AUTH_BRUTE_FORCE code', () => {
    const detector = new AnomalyDetector();
    const sample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 60,
      errorRate4xx: 0.5,
      errorRate5xx: 0,
      failedLogins: 30, // Exceeds relaxed brute-force threshold (>= 25)
      tokenReuseAttacks: 0,
      malformedRequests: 0,
      eventLoopLagMs: 8,
      cpuPercent: 20,
      ramPercent: 45,
      dbPoolActive: 2,
      loadSheddingCount: 0,
      distinctIpsCount: 1,
    };

    const result = detector.evaluate(sample);

    assert.strictEqual(result.isAnomaly, true);
    assert.ok(result.threatScore >= 70, `Threat score must be >= 70 for brute force attack: ${result.threatScore}`);
    const bruteAnomaly = result.anomalies.find((a) => a.code === 'AUTH_BRUTE_FORCE');
    assert.ok(bruteAnomaly, 'Must contain AUTH_BRUTE_FORCE anomaly');
    assert.strictEqual(bruteAnomaly.severity, 'HIGH');
  });

  await t.test('3. Token reuse attack triggers CRITICAL with TOKEN_HIJACKING_ATTACK code', () => {
    const detector = new AnomalyDetector();
    const sample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 50,
      errorRate4xx: 0.1,
      errorRate5xx: 0,
      failedLogins: 1,
      tokenReuseAttacks: 6, // Exceeds relaxed token reuse threshold (>= 5)
      malformedRequests: 0,
      eventLoopLagMs: 5,
      cpuPercent: 18,
      ramPercent: 40,
      dbPoolActive: 2,
      loadSheddingCount: 0,
      distinctIpsCount: 5,
    };

    const result = detector.evaluate(sample);

    assert.strictEqual(result.isAnomaly, true);
    const tokenAnomaly = result.anomalies.find((a) => a.code === 'TOKEN_HIJACKING_ATTACK');
    assert.ok(tokenAnomaly, 'Must contain TOKEN_HIJACKING_ATTACK anomaly');
    assert.ok(result.threatScore >= 70, 'Threat score must reflect critical security alert');
  });

  await t.test('4. Differentiates Organic Traffic Burst (Safe) vs DDoS Flood (Threat)', () => {
    const detector = new AnomalyDetector();

    // Case A: Organic traffic spike (Flash Sale / Morning peak)
    // 600 req/min, 0% 5xx, low 4xx, 100 distinct IPs, 0 failed logins
    const organicSample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 600,
      errorRate4xx: 0.02,
      errorRate5xx: 0,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 0,
      eventLoopLagMs: 25,
      cpuPercent: 45,
      ramPercent: 55,
      dbPoolActive: 6,
      loadSheddingCount: 0,
      distinctIpsCount: 120, // Wide diversity of IPs
    };

    const organicResult = detector.evaluate(organicSample);
    assert.strictEqual(organicResult.status, 'NORMAL', 'Organic high traffic with healthy responses should remain NORMAL');
    assert.ok(organicResult.threatScore < 50, `Organic spike threat score must stay < 50: ${organicResult.threatScore}`);

    // Case B: DDoS / Scraping Attack
    // 600 req/min, high error rate, only 2 IPs, malformed requests, severe resource drain
    const ddosSample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 600,
      errorRate4xx: 0.45,
      errorRate5xx: 0.30,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 12,
      eventLoopLagMs: 450,
      cpuPercent: 88,
      ramPercent: 95,
      dbPoolActive: 10,
      loadSheddingCount: 5,
      distinctIpsCount: 2, // Low IP entropy, single origin flood
    };

    const ddosResult = detector.evaluate(ddosSample);
    assert.strictEqual(ddosResult.status, 'CRITICAL', 'DDoS flood with malformed requests must be CRITICAL');
    assert.ok(ddosResult.threatScore >= 85, `DDoS threat score must be >= 85: ${ddosResult.threatScore}`);
    assert.strictEqual(ddosResult.recommendedAction, 'EMERGENCY_MAINTENANCE');
  });

  await t.test('5. Detects Severe System Exhaustion (RAM leak & Event Loop freeze)', () => {
    const detector = new AnomalyDetector();
    const exhaustedSample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 80,
      errorRate4xx: 0.02,
      errorRate5xx: 0.4,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 0,
      eventLoopLagMs: 450, // Massive event loop lag
      cpuPercent: 95,
      ramPercent: 96,     // RAM exhaustion
      dbPoolActive: 10,
      loadSheddingCount: 20,
      distinctIpsCount: 10,
    };

    const result = detector.evaluate(exhaustedSample);
    assert.strictEqual(result.isAnomaly, true);
    assert.strictEqual(result.status, 'CRITICAL');
    assert.strictEqual(result.recommendedAction, 'EMERGENCY_MAINTENANCE');
    const lagAnomaly = result.anomalies.find((a) => a.code === 'EVENT_LOOP_FREEZE' || a.code === 'MEMORY_EXHAUSTION');
    assert.ok(lagAnomaly, 'Must capture system degradation anomaly');
  });

  await t.test('6. Anti-Poisoning: Baseline only updates when Threat Score < 70', () => {
    const detector = new AnomalyDetector();
    const initialBaselineReq = detector.getBaselineMetric('requestsPerMin');

    // Attack sample (Threat Score >= 85)
    const attackSample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 2000,
      errorRate4xx: 0.6,
      errorRate5xx: 0.2,
      failedLogins: 50,
      tokenReuseAttacks: 10,
      malformedRequests: 30,
      eventLoopLagMs: 300,
      cpuPercent: 99,
      ramPercent: 90,
      dbPoolActive: 10,
      loadSheddingCount: 50,
      distinctIpsCount: 1,
    };

    detector.evaluate(attackSample);
    const afterAttackBaseline = detector.getBaselineMetric('requestsPerMin');

    // Baseline should NOT be influenced by attack data
    assert.strictEqual(afterAttackBaseline, initialBaselineReq, 'Baseline must not learn from attack data');
  });

  await t.test('7. Multi-Vector Decomposition: Returns 4 separate vector scores with proper categories', () => {
    const detector = new AnomalyDetector({ targetConcurrency: 1000 });
    const sample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 120,
      errorRate4xx: 0.01,
      errorRate5xx: 0,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 10, // Exploit probe exceeding relaxed threshold (>= 8)
      eventLoopLagMs: 10,
      cpuPercent: 20,
      ramPercent: 40,
      dbPoolActive: 2,
      loadSheddingCount: 0,
      distinctIpsCount: 15,
    };

    const result = detector.evaluate(sample);

    assert.ok(result.vectorScores, 'Result must include vectorScores');
    assert.strictEqual(typeof result.vectorScores.auth, 'number');
    assert.strictEqual(typeof result.vectorScores.traffic, 'number');
    assert.strictEqual(typeof result.vectorScores.exploit, 'number');
    assert.strictEqual(typeof result.vectorScores.resource, 'number');
    assert.strictEqual(result.targetConcurrency, 1000);

    // Exploit score should be high while auth/traffic/resource stay low
    assert.ok(result.vectorScores.exploit >= 50, `Exploit score must be elevated: ${result.vectorScores.exploit}`);
    assert.ok(result.vectorScores.auth === 0, `Auth score must be 0: ${result.vectorScores.auth}`);
  });

  await t.test('8. Dynamic Concurrency Scaling: setConcurrencyScale(2000) dynamically adjusts baseline capacity', () => {
    const detector = new AnomalyDetector({ targetConcurrency: 1000 });
    assert.strictEqual(detector.targetConcurrency, 1000);

    const scaleResult = detector.setConcurrencyScale(2000);
    assert.strictEqual(detector.targetConcurrency, 2000);
    assert.strictEqual(scaleResult.expectedBaselineRPM, 20000);
    assert.strictEqual(scaleResult.peakCeilingRPM, 50000);

    // A sample of 15,000 RPM at 2000 users should be well within normal baseline (< 2.5x)
    const highTrafficSample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 15000,
      errorRate4xx: 0.01,
      errorRate5xx: 0,
      failedLogins: 5,
      tokenReuseAttacks: 0,
      malformedRequests: 0,
      eventLoopLagMs: 15,
      cpuPercent: 35,
      ramPercent: 50,
      dbPoolActive: 5,
      loadSheddingCount: 0,
      distinctIpsCount: 800,
    };

    const evalResult = detector.evaluate(highTrafficSample);
    assert.strictEqual(evalResult.status, 'NORMAL', '15,000 RPM for 2000 users must stay NORMAL');
    assert.ok(evalResult.threatScore < 50, `Threat score should stay low: ${evalResult.threatScore}`);
  });

  await t.test('9. Per-Vector Defense: Personalizes defense actions per vector without triggering broad EMERGENCY_MAINTENANCE', () => {
    const detector = new AnomalyDetector({ targetConcurrency: 1000 });

    // Attack on Auth only (Brute-Force)
    const authAttackSample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 100,
      errorRate4xx: 0.1,
      errorRate5xx: 0,
      failedLogins: 30, // Exceeds relaxed brute-force threshold (>= 25)
      tokenReuseAttacks: 0,
      malformedRequests: 0,
      eventLoopLagMs: 5,
      cpuPercent: 15,
      ramPercent: 40,
      dbPoolActive: 2,
      loadSheddingCount: 0,
      distinctIpsCount: 1,
    };

    const authResult = detector.evaluate(authAttackSample);
    assert.ok(authResult.vectorDefenses, 'Must return vectorDefenses');
    assert.strictEqual(authResult.vectorDefenses.auth.defenseAction, 'QUARANTINE_IP');
    assert.strictEqual(authResult.vectorDefenses.resource.defenseAction, 'MONITOR');
    // Critical: Auth attack must NEVER recommend emergency maintenance for entire platform
    assert.notStrictEqual(authResult.recommendedAction, 'EMERGENCY_MAINTENANCE');
    assert.strictEqual(authResult.recommendedAction, 'ACTIVE_QUARANTINE_ENGAGED');

    // Attack on Exploit only (SQL Injection probes)
    const exploitSample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 100,
      errorRate4xx: 0.1,
      errorRate5xx: 0,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 8,
      eventLoopLagMs: 5,
      cpuPercent: 15,
      ramPercent: 40,
      dbPoolActive: 2,
      loadSheddingCount: 0,
      distinctIpsCount: 1,
    };

    const exploitResult = detector.evaluate(exploitSample);
    assert.strictEqual(exploitResult.vectorDefenses.exploit.defenseAction, 'BLOCK_INJECTION_IP');
    assert.notStrictEqual(exploitResult.recommendedAction, 'EMERGENCY_MAINTENANCE');
  });

  await t.test('10. Vector Toggles: When a vector is toggled OFF, it is still measured in vectorScores, but completely excluded from Threat Score and Defense triggers', () => {
    const detector = new AnomalyDetector({ targetConcurrency: 1000 });
    
    // Tắt Vector Exploit
    detector.setVectorEnabled('exploit', false);
    assert.strictEqual(detector.vectorConfig.exploit, false);

    // Mẫu chứa 10 SQLi probes (bình thường sẽ cho Exploit ~70 điểm và Threat Score >= 70)
    const exploitSample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 100,
      errorRate4xx: 0.1,
      errorRate5xx: 0,
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 10,
      eventLoopLagMs: 5,
      cpuPercent: 15,
      ramPercent: 40,
      dbPoolActive: 2,
      loadSheddingCount: 0,
      distinctIpsCount: 1,
    };

    const result = detector.evaluate(exploitSample);

    // Vẫn đo lường điểm vector độc lập
    assert.ok(result.vectorScores.exploit >= 70, `Exploit score must still be measured: ${result.vectorScores.exploit}`);
    assert.strictEqual(result.vectorDefenses.exploit.disabled, true);
    assert.strictEqual(result.vectorDefenses.exploit.defenseAction, 'MONITOR');

    // NHƯNG Threat Score không bị ảnh hưởng bởi Exploit (ở mức thấp bình thường theo 3 vector còn lại)
    assert.ok(result.threatScore < 40, `Threat score must exclude disabled exploit vector: ${result.threatScore}`);
    assert.strictEqual(result.status, 'NORMAL');
  });

  await t.test('11. Vector Toggles: Toggling Resource vector OFF prevents EMERGENCY_MAINTENANCE during severe resource crisis', () => {
    const detector = new AnomalyDetector({ targetConcurrency: 1000 });
    
    // Tắt Vector Resource
    detector.setVectorEnabled('resource', false);

    const crisisSample = {
      timestamp: new Date().toISOString(),
      requestsPerMin: 200,
      errorRate4xx: 0.05,
      errorRate5xx: 0.40, // 5xx nặng
      failedLogins: 0,
      tokenReuseAttacks: 0,
      malformedRequests: 0,
      eventLoopLagMs: 450, // Lag nặng
      cpuPercent: 95,
      ramPercent: 96,     // RAM cạn kiệt
      dbPoolActive: 10,
      loadSheddingCount: 20,
      distinctIpsCount: 10,
    };

    const result = detector.evaluate(crisisSample);

    // Điểm resource vẫn đo được mức cao (>= 85)
    assert.ok(result.vectorScores.resource >= 85, `Resource score must still be measured: ${result.vectorScores.resource}`);
    assert.strictEqual(result.vectorDefenses.resource.disabled, true);
    
    // Nhưng vì Resource bị TẮT, không được kích hoạt EMERGENCY_MAINTENANCE vào Threat Score tổng thể
    assert.notStrictEqual(result.recommendedAction, 'EMERGENCY_MAINTENANCE');
    assert.ok(result.threatScore < 50, `Threat score must ignore disabled resource vector: ${result.threatScore}`);
  });
});
