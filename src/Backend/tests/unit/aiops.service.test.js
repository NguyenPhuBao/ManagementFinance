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

  await t.test('6. getHistory() filters strictly on real recorded data without generating synthetic points', async () => {
    const collector = new FeatureCollector();
    const detector = new AnomalyDetector();
    const service = new AIOpsService({ collector, detector });

    const now = Date.now();
    // Tạo 3 mẫu thực tế: 1 mẫu vừa xong (5 phút trước), 1 mẫu 2 ngày trước, 1 mẫu 40 ngày trước
    service._history = [
      {
        timestamp: new Date(now - 5 * 60 * 1000).toISOString(),
        vectorScores: { auth: 10, traffic: 15, exploit: 0, resource: 20 },
        threatScore: 20,
      },
      {
        timestamp: new Date(now - 2 * 24 * 3600 * 1000).toISOString(),
        vectorScores: { auth: 12, traffic: 18, exploit: 5, resource: 25 },
        threatScore: 25,
      },
      {
        timestamp: new Date(now - 40 * 24 * 3600 * 1000).toISOString(),
        vectorScores: { auth: 8, traffic: 10, exploit: 0, resource: 15 },
        threatScore: 15,
      },
    ];

    // Realtime (10 phút qua): chỉ có 1 mẫu trong 5 phút trước
    const realtimeHist = service.getHistory({ range: 'realtime' });
    assert.strictEqual(realtimeHist.length, 1);

    // Day (24 giờ qua): chỉ có 1 mẫu trong 24 giờ qua
    const dayHist = service.getHistory({ range: 'day' });
    assert.strictEqual(dayHist.length, 1);

    // Month (30 ngày qua): có 2 mẫu (5 phút trước và 2 ngày trước), không có mẫu 40 ngày trước
    const monthHist = service.getHistory({ range: 'month' });
    assert.strictEqual(monthHist.length, 2);

    // Year (12 tháng qua): có cả 3 mẫu
    const yearHist = service.getHistory({ range: 'year' });
    assert.strictEqual(yearHist.length, 3);

    // Custom date range (Priority over range parameter)
    // Lọc chỉ từ 3 ngày trước đến 1 ngày trước -> chỉ có đúng 1 mẫu (2 ngày trước)
    const from = new Date(now - 3 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    const to = new Date(now - 1 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    const customHist = service.getHistory({ range: 'year', from, to });
    assert.strictEqual(customHist.length, 1);
    assert.strictEqual(customHist[0].threatScore, 25);

    // Lọc một khoảng thời gian trong quá khứ không có dữ liệu thật (năm ngoái) -> Trả về mảng rỗng []
    const emptyHist = service.getHistory({ from: '2024-01-01', to: '2024-06-01' });
    assert.strictEqual(emptyHist.length, 0);
  });
});
