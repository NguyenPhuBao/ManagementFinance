const test = require('node:test');
const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
const { AIOpsService } = require('../../modules/aiops/aiops.service');
const { FeatureCollector } = require('../../modules/aiops/feature.collector');
const { AnomalyDetector } = require('../../modules/aiops/anomaly.detector');

test('AIOps Service Suite', async (t) => {
  await t.test('1. Service initializes with empty history and healthy default status', () => {
    const collector = new FeatureCollector();
    const detector = new AnomalyDetector();
    const service = new AIOpsService({ collector, detector, maxHistory: 60 });

    const status = service.getStatus();
    assert.strictEqual(status.status, 'NORMAL');
    assert.strictEqual(status.threatScore, 5);
    assert.deepStrictEqual(service.getHistory(), []);
  });

  await t.test('2. tick() collects sample, evaluates, and stores in history ring buffer', async () => {
    const collector = new FeatureCollector();
    const detector = new AnomalyDetector();
    const service = new AIOpsService({ collector, detector, maxHistory: 3 });

    // Tick 1
    const res1 = await service.tick();
    assert.strictEqual(res1.status, 'NORMAL');
    assert.strictEqual(service.getHistory().length, 1);

    // Tick 2
    await service.tick();
    // Tick 3
    await service.tick();
    assert.strictEqual(service.getHistory().length, 3);

    // Tick 4: Buffer exceeds maxHistory (3) -> oldest dropped
    await service.tick();
    assert.strictEqual(service.getHistory().length, 3);
  });

  await t.test('3. Emits Socket.io event admin.security_alert when Threat Score >= 70', async () => {
    const collector = new FeatureCollector();
    const detector = new AnomalyDetector();
    let emittedEvent = null;
    let emittedData = null;

    const mockIo = {
      to: (room) => {
        assert.strictEqual(room, 'admin_room');
        return {
          emit: (event, data) => {
            emittedEvent = event;
            emittedData = data;
          },
        };
      },
    };

    const service = new AIOpsService({ collector, detector, io: mockIo });

    // Simulate brute-force attack
    for (let i = 0; i < 15; i++) {
      collector.recordFailedLogin();
    }

    const result = await service.tick();
    assert.ok(result.threatScore >= 70);
    assert.strictEqual(emittedEvent, 'admin.security_alert');
    assert.ok(emittedData);
    assert.strictEqual(emittedData.threatScore, result.threatScore);
    assert.strictEqual(emittedData.status, result.status);
    assert.ok(emittedData.anomalies.length > 0);
  });

  await t.test('4. calibrate() resets or updates baseline settings', () => {
    const collector = new FeatureCollector();
    const detector = new AnomalyDetector();
    const service = new AIOpsService({ collector, detector });

    const result = service.calibrate({ requestsPerMin: 200 });
    assert.strictEqual(result.success, true);
    assert.strictEqual(detector.getBaselineMetric('requestsPerMin'), 200);
  });
});
