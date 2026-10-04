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
    // Đảm bảo kiểm thử độc lập không phụ thuộc tải phần cứng thực tế của OS
    collector._getRamPercent = () => 50;
    collector._getCpuPercent = () => 10;
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

    // Simulate brute-force attack (relaxed threshold >= 25)
    for (let i = 0; i < 30; i++) {
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

  await t.test('5. toggleVector() toggles vector in detector, persists to repository and emits admin.vector_config_changed', async () => {
    const collector = new FeatureCollector();
    const detector = new AnomalyDetector();
    let emittedEvent = null;
    let emittedData = null;

    const mockIo = {
      to: (room) => ({
        emit: (event, data) => {
          emittedEvent = event;
          emittedData = data;
        },
      }),
    };

    const savedSettings = new Map();
    const mockRepo = {
      getSetting: async (key) => savedSettings.get(key) || null,
      setSetting: async (key, val) => {
        savedSettings.set(key, val);
        return true;
      },
    };

    const service = new AIOpsService({ collector, detector, io: mockIo, repository: mockRepo });

    // Toggle exploit to false
    const res = await service.toggleVector('exploit', false);
    assert.strictEqual(res.success, true);
    assert.strictEqual(res.vector, 'exploit');
    assert.strictEqual(res.enabled, false);
    assert.strictEqual(detector.vectorConfig.exploit, false);
    assert.strictEqual(emittedEvent, 'admin.vector_config_changed');
    assert.strictEqual(emittedData.exploit, false);
    assert.ok(savedSettings.has('vector_toggles'));

    // Toggle back to true
    await service.toggleVector('exploit', true);
    assert.strictEqual(detector.vectorConfig.exploit, true);
  });

  await t.test('6. getHistory() supports ranges: realtime, day, month, year, and custom date range with strict priority', async () => {
    const collector = new FeatureCollector();
    const detector = new AnomalyDetector();
    const service = new AIOpsService({ collector, detector });

    // Default / realtime
    const realtimeHist = await service.getHistory({ range: 'realtime' });
    assert.ok(Array.isArray(realtimeHist));

    // Day range: 24 points
    const dayHist = await service.getHistory({ range: 'day' });
    assert.strictEqual(dayHist.length, 24);
    assert.ok(dayHist[0].timestamp);
    assert.ok(dayHist[0].vectorScores);

    // Month range: 30 points
    const monthHist = await service.getHistory({ range: 'month' });
    assert.strictEqual(monthHist.length, 30);

    // Year range: 12 points
    const yearHist = await service.getHistory({ range: 'year' });
    assert.strictEqual(yearHist.length, 12);

    // Custom date range (Priority over range parameter)
    const from = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString();
    const to = new Date().toISOString();
    const customHist = await service.getHistory({ range: 'year', from, to });
    assert.ok(Array.isArray(customHist));
    assert.ok(customHist.length >= 7);
  });
});
