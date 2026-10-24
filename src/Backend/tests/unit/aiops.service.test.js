const test = require('node:test');
const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
const { AIOpsService } = require('../../modules/aiops/aiops.service');
const { FeatureCollector } = require('../../modules/aiops/feature.collector');
const { AnomalyDetector } = require('../../modules/aiops/anomaly.detector');

test('AIOps Service Suite', async (t) => {
  await t.test('1. Service initializes with empty history and healthy default status', async () => {
    const collector = new FeatureCollector();
    const detector = new AnomalyDetector();
    const service = new AIOpsService({ collector, detector, maxHistory: 60 });

    const status = service.getStatus();
    assert.strictEqual(status.status, 'NORMAL');
    assert.strictEqual(status.threatScore, 0);
    assert.deepStrictEqual(await service.getHistory(), []);
  });

  await t.test('2. tick() collects sample, evaluates, and stores in history ring buffer', async () => {
    const collector = new FeatureCollector();
    // Đảm bảo kiểm thử độc lập không phụ thuộc tải phần cứng thực tế của OS
    collector._getRamPercent = () => 50;
    collector._getCpuPercent = () => 10;
    collector._getEventLoopLag = () => 5;
    collector._getHardwareMetrics = () => ({
      cpu: { cores: 16, percent: 10 },
      ram: { totalMb: 8000, freeMb: 4000, usedMb: 4000, percent: 50, rssMb: 150 },
    });
    const detector = new AnomalyDetector();
    const mockRepo = {
      upsertIncident: async (anomaly) => ({ id: 'mock_inc', ...anomaly }),
      autoMitigateStaleIncidents: async () => [],
      getSetting: async () => null,
      setSetting: async () => true,
    };
    const service = new AIOpsService({ collector, detector, maxHistory: 3, repository: mockRepo });

    // Tick 1
    const res1 = await service.tick();
    assert.strictEqual(res1.status, 'NORMAL');
    assert.strictEqual((await service.getHistory()).length, 1);

    // Tick 2
    await service.tick();
    // Tick 3
    await service.tick();
    assert.strictEqual((await service.getHistory()).length, 3);

    // Tick 4: Buffer exceeds maxHistory (3) -> oldest dropped
    await service.tick();
    assert.strictEqual((await service.getHistory()).length, 3);
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

    const mockRepo = {
      upsertIncident: async (anomaly) => ({ id: 'mock_inc', ...anomaly }),
      autoMitigateStaleIncidents: async () => [],
      getSetting: async () => null,
      setSetting: async () => true,
    };
    const service = new AIOpsService({ collector, detector, io: mockIo, repository: mockRepo });

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

  await t.test('4. calibrate() resets or updates baseline settings', async () => {
    const collector = new FeatureCollector();
    const detector = new AnomalyDetector();
    const service = new AIOpsService({ collector, detector });

    const result = await service.calibrate({ requestsPerMin: 200 });
    assert.strictEqual(result.success, true);
    assert.strictEqual(detector.getBaselineMetric('requestsPerMin'), 200);
  });

  await t.test('4b. calibrate() calculates real server hardware baselines and capacity assessment for N users', async () => {
    const collector = new FeatureCollector();
    const detector = new AnomalyDetector({ targetConcurrency: 500 });
    const service = new AIOpsService({ collector, detector });

    const result = await service.calibrate({ targetConcurrency: 2000 });
    assert.strictEqual(result.success, true);
    assert.ok(result.data, 'Phải trả về data report');
    assert.strictEqual(result.data.targetConcurrency, 2000);
    assert.ok(result.data.serverSpecs.cpuCores >= 1, 'Phải nhận diện số nhân CPU');
    assert.ok(result.data.serverSpecs.totalRamMb >= 512, 'Phải nhận diện tổng RAM');
    assert.strictEqual(result.data.calculatedMetrics.baselineRpm, 20000);
    assert.strictEqual(result.data.calculatedMetrics.safePeakRpm, 60000);
    assert.ok(result.data.calculatedMetrics.expectedCpuPercent >= 5);
    assert.ok(result.data.calculatedMetrics.expectedRamPercent >= 10);
    assert.ok(result.data.capacityAssessment.status, 'Phải có trạng thái đánh giá năng lực');
    assert.ok(result.data.capacityAssessment.recommendation, 'Phải có khuyến nghị thực tế');
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
    const service = new AIOpsService({
      collector,
      detector,
      repository: { getMetricSnapshots: async () => [] },
    });

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
    const realtimeHist = await service.getHistory({ range: 'realtime' });
    assert.strictEqual(realtimeHist.length, 1);

    // Day (24 giờ qua): chỉ có 1 mẫu trong 24 giờ qua
    const dayHist = await service.getHistory({ range: 'day' });
    assert.strictEqual(dayHist.length, 1);

    // Month (30 ngày qua): có 2 mẫu (5 phút trước và 2 ngày trước), không có mẫu 40 ngày trước
    const monthHist = await service.getHistory({ range: 'month' });
    assert.strictEqual(monthHist.length, 2);

    // Year (12 tháng qua): có cả 3 mẫu
    const yearHist = await service.getHistory({ range: 'year' });
    assert.strictEqual(yearHist.length, 3);

    // Custom date range (Priority over range parameter)
    // Lọc chỉ từ 3 ngày trước đến 1 ngày trước -> chỉ có đúng 1 mẫu (2 ngày trước)
    const from = new Date(now - 3 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    const to = new Date(now - 1 * 24 * 3600 * 1000).toISOString().slice(0, 10);
    const customHist = await service.getHistory({ range: 'year', from, to });
    assert.strictEqual(customHist.length, 1);
    assert.strictEqual(customHist[0].threatScore, 25);

    // Lọc một khoảng thời gian trong quá khứ không có dữ liệu thật (năm ngoái) -> Trả về mảng rỗng []
    const emptyHist = await service.getHistory({ from: '2024-01-01', to: '2024-06-01' });
    assert.strictEqual(emptyHist.length, 0);
  });

  await t.test('7. getHistory() supports 5 timeframe presets (10m, 1h, 24h, 7d, 30d) with max aggregation per bucket', async () => {
    const service = new AIOpsService();
    const now = Date.now();

    // Giả lập 3 mẫu trong cùng 1 phút qua với các giá trị khác nhau
    service._history = [
      {
        timestamp: new Date(now - 40 * 1000).toISOString(),
        vectorScores: { auth: 10, traffic: 80, exploit: 5, resource: 20 },
        threatScore: 80,
      },
      {
        timestamp: new Date(now - 20 * 1000).toISOString(),
        vectorScores: { auth: 40, traffic: 30, exploit: 15, resource: 60 },
        threatScore: 60,
      },
      {
        timestamp: new Date(now - 5 * 1000).toISOString(),
        vectorScores: { auth: 5, traffic: 20, exploit: 0, resource: 10 },
        threatScore: 20,
      },
    ];

    // Khung 1h qua: các mẫu trong 1 phút này phải được gom và lấy MAX:
    // auth: 40 (từ mẫu 2), traffic: 80 (từ mẫu 1), exploit: 15 (từ mẫu 2), resource: 60 (từ mẫu 2), threatScore: 80 (từ mẫu 1)
    const hist1h = await service.getHistory({ range: '1h' });
    assert.ok(hist1h.length >= 1);
    const bucket = hist1h[hist1h.length - 1];
    assert.strictEqual(bucket.vectorScores.auth, 40);
    assert.strictEqual(bucket.vectorScores.traffic, 80);
    assert.strictEqual(bucket.vectorScores.exploit, 15);
    assert.strictEqual(bucket.vectorScores.resource, 60);
    assert.strictEqual(bucket.threatScore, 80);

    // Kiểm tra các presets 10m, 24h, 7d, 30d đều hoạt động
    const hist10m = await service.getHistory({ range: '10m' });
    assert.ok(Array.isArray(hist10m));
    const hist24h = await service.getHistory({ range: '24h' });
    assert.ok(Array.isArray(hist24h));
    const hist7d = await service.getHistory({ range: '7d' });
    assert.ok(Array.isArray(hist7d));
    const hist30d = await service.getHistory({ range: '30d' });
    assert.ok(Array.isArray(hist30d));
  });
});

