const test = require('node:test');
const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
const { FeatureCollector, defaultFeatureCollector } = require('../../modules/aiops/feature.collector');

test('AIOps Feature Collector Suite', async (t) => {
  await t.test('1. getSample returns all 13 standard fields with expected types', () => {
    const collector = new FeatureCollector({ windowSeconds: 10 });
    const sample = collector.getSample();

    assert.ok(sample.timestamp, 'timestamp must be present');
    assert.strictEqual(typeof sample.timestamp, 'string');
    assert.strictEqual(typeof sample.requestsPerMin, 'number');
    assert.strictEqual(typeof sample.errorRate4xx, 'number');
    assert.strictEqual(typeof sample.errorRate5xx, 'number');
    assert.strictEqual(typeof sample.failedLogins, 'number');
    assert.strictEqual(typeof sample.tokenReuseAttacks, 'number');
    assert.strictEqual(typeof sample.malformedRequests, 'number');
    assert.strictEqual(typeof sample.eventLoopLagMs, 'number');
    assert.strictEqual(typeof sample.cpuPercent, 'number');
    assert.strictEqual(typeof sample.ramPercent, 'number');
    assert.strictEqual(typeof sample.dbPoolActive, 'number');
    assert.strictEqual(typeof sample.loadSheddingCount, 'number');
    assert.strictEqual(typeof sample.distinctIpsCount, 'number');

    assert.ok(sample.errorRate4xx >= 0 && sample.errorRate4xx <= 1, '4xx error rate must be normalized between 0 and 1');
    assert.ok(sample.errorRate5xx >= 0 && sample.errorRate5xx <= 1, '5xx error rate must be normalized between 0 and 1');
  });

  await t.test('2. Middleware correctly records requests, error rates and distinct IPs', () => {
    const collector = new FeatureCollector({ windowSeconds: 10 });
    const mw = collector.createMiddleware();

    // Mock request 1: normal 200 OK from IP 1.2.3.4
    const req1 = { ip: '1.2.3.4', headers: {}, method: 'GET', path: '/api/wallets' };
    const res1 = new EventEmitter();
    res1.statusCode = 200;
    let nextCalled1 = false;
    mw(req1, res1, () => { nextCalled1 = true; });
    res1.emit('finish');

    // Mock request 2: 404 from IP 1.2.3.4 (same IP)
    const req2 = { ip: '1.2.3.4', headers: {}, method: 'GET', path: '/api/notfound' };
    const res2 = new EventEmitter();
    res2.statusCode = 404;
    let nextCalled2 = false;
    mw(req2, res2, () => { nextCalled2 = true; });
    res2.emit('finish');

    // Mock request 3: 500 error from IP 5.6.7.8
    const req3 = { ip: '5.6.7.8', headers: {}, method: 'POST', path: '/api/transactions' };
    const res3 = new EventEmitter();
    res3.statusCode = 500;
    let nextCalled3 = false;
    mw(req3, res3, () => { nextCalled3 = true; });
    res3.emit('finish');

    assert.strictEqual(nextCalled1, true);
    assert.strictEqual(nextCalled2, true);
    assert.strictEqual(nextCalled3, true);

    const sample = collector.getSample();
    // 3 requests in 10s window => 3 * (60 / 10) = 18 requestsPerMin
    assert.strictEqual(sample.requestsPerMin, 18);
    // 1 out of 3 is 4xx => 0.33
    assert.strictEqual(Math.round(sample.errorRate4xx * 100) / 100, 0.33);
    // 1 out of 3 is 5xx => 0.33
    assert.strictEqual(Math.round(sample.errorRate5xx * 100) / 100, 0.33);
    // 2 distinct IPs (1.2.3.4 and 5.6.7.8)
    assert.strictEqual(sample.distinctIpsCount, 2);
  });

  await t.test('3. Security hooks record failed logins, token reuse attacks, and malformed requests', () => {
    const collector = new FeatureCollector({ windowSeconds: 10 });

    collector.recordFailedLogin();
    collector.recordFailedLogin();
    collector.recordTokenReuse();
    collector.recordMalformedRequest();

    const sample = collector.getSample();
    assert.strictEqual(sample.failedLogins, 2);
    assert.strictEqual(sample.tokenReuseAttacks, 1);
    assert.strictEqual(sample.malformedRequests, 1);
  });

  await t.test('4. Sampling resets window counters cleanly for subsequent windows', () => {
    const collector = new FeatureCollector({ windowSeconds: 10 });
    collector.recordFailedLogin();
    collector.recordTokenReuse();

    const firstSample = collector.getSample();
    assert.strictEqual(firstSample.failedLogins, 1);
    assert.strictEqual(firstSample.tokenReuseAttacks, 1);

    // Second sample without new events should be 0
    const secondSample = collector.getSample();
    assert.strictEqual(secondSample.failedLogins, 0);
    assert.strictEqual(secondSample.tokenReuseAttacks, 0);
    assert.strictEqual(secondSample.requestsPerMin, 0);
    assert.strictEqual(secondSample.distinctIpsCount, 0);
  });

  await t.test('5. Zero PII compliance: IP addresses are hashed in memory, no raw IPs exposed', () => {
    const collector = new FeatureCollector({ windowSeconds: 10 });
    const mw = collector.createMiddleware();

    const sensitiveIp = '113.161.45.12';
    const req = { ip: sensitiveIp, headers: {}, method: 'GET', path: '/api/health' };
    const res = new EventEmitter();
    res.statusCode = 200;
    mw(req, res, () => {});
    res.emit('finish');

    // Inspect internal IP set
    const internalHashes = Array.from(collector._ipHashes);
    assert.strictEqual(internalHashes.length, 1);
    assert.ok(!internalHashes[0].includes('113.161'), 'Raw IP must not be stored in memory');
    assert.strictEqual(internalHashes[0].length, 16, 'Should store truncated safe hash');
  });
});
