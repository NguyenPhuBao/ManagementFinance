const test = require('node:test');
const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
const { FeatureCollector } = require('../../modules/aiops/feature.collector');
const { AnomalyDetector } = require('../../modules/aiops/anomaly.detector');
const { AIOpsService } = require('../../modules/aiops/aiops.service');
const F = require('../../modules/aiops/aiops.formulas');

// Đặc tả: docs/AIOps/AIOPS_CONG_THUC.md (A1, A3, B1, B5, phương án (a) lưu ngưỡng)
const fakeLag = { getWindowLag: () => ({ p99Ms: 2, maxMs: 3 }), peekWindowLag: () => ({ p99Ms: 2, maxMs: 3 }) };

const makeRepo = (snapshots = []) => {
  const settings = new Map();
  return {
    settings,
    async getSetting(key, def = null) { return settings.has(key) ? settings.get(key) : def; },
    async setSetting(key, value) { settings.set(key, value); return true; },
    async getMetricSnapshots() { return snapshots; },
    async upsertIncident(a) { return a; },
    async autoMitigateStaleIncidents() { return []; },
    async saveMetricSnapshot(s) { return s; },
  };
};

const hardSpecs = () => ({ cpuCores: 0.5, cpuQuotaHard: true, ramTotalMb: 512, source: 'cgroup_v2', isContainer: true });

const makeService = (over = {}) => {
  const collector = over.collector || new FeatureCollector({ eventLoopMonitor: fakeLag, warmupMs: 0 });
  const detector = over.detector || new AnomalyDetector();
  const repository = over.repository || makeRepo();
  return { collector, detector, repository, service: new AIOpsService({ collector, detector, repository, specsProvider: hardSpecs, io: { to: () => ({ emit() {} }) } }) };
};

const hit = (mw) => {
  const res = new EventEmitter();
  res.statusCode = 200;
  mw({ ip: '8.8.4.4', headers: {}, method: 'GET', path: '/api/x' }, res, () => {});
  res.emit('finish');
};

test('AIOpsService — chỉ số, hiệu chuẩn, đường nền', async (t) => {
  await t.test('A1/A3. getStatus có indicators và không xoá cửa sổ đo', async () => {
    const { service, collector } = makeService();
    const mw = collector.createMiddleware();
    for (let i = 0; i < 4; i++) hit(mw);
    const st = service.getStatus();
    assert.ok(st.indicators && st.indicators.traffic && st.indicators.auth, 'Phải có indicators');
    assert.strictEqual(st.indicators.ipBurstPer10s, 150);
    hit(mw);
    const after = await service.tick();
    assert.strictEqual(after.sample.requestCount, 5, 'getStatus không được làm mất yêu cầu của cửa sổ');
    assert.ok(after.indicators, 'tick() gắn indicators vào trạng thái');
  });

  await t.test('setConcurrencyScale trả indicators (không còn N×10 / N×25)', async () => {
    const { service } = makeService();
    const res = await service.setConcurrencyScale(500, false);
    assert.strictEqual(res.indicators.traffic.baselineRpm, 1000);
    assert.strictEqual(res.expectedBaselineRPM, undefined);
    assert.strictEqual(res.peakCeilingRPM, undefined);
  });

  await t.test('B5. tick() lưu (cpuMs, completed) cho ước lượng năng lực; bỏ qua khi đang khởi động', async () => {
    const samples = [
      { cpuMs: 30, completedCount: 3, warmingUp: false },
      { cpuMs: 99, completedCount: 9, warmingUp: true },
    ];
    let i = 0;
    const collector = { getSample: () => ({ requestsPerMin: 0, requestCount: 0, failedLogins: 0, tokenReuseAttacks: 0, malformedRequests: 0, eventLoopLagMs: 0, cpuPercent: 0, ramPercent: 0, errorRate5xx: 0, ...samples[i++] }), peekSample: () => ({}) };
    const { service } = makeService({ collector });
    await service.tick();
    await service.tick();
    assert.deepStrictEqual(service._capacityWindows, [{ cpuMs: 30, completed: 3 }]);
  });

  await t.test('B5. calibrate: chưa đủ dữ liệu thì INSUFFICIENT_DATA, không đưa con số; không xoá cửa sổ đo', async () => {
    const { service, collector } = makeService();
    const mw = collector.createMiddleware();
    hit(mw);
    const result = await service.calibrate({ targetConcurrency: 1000 });
    assert.strictEqual(result.success, true);
    assert.strictEqual(result.data.capacity.status, 'INSUFFICIENT_DATA');
    assert.strictEqual(result.data.capacity.maxRpm, null);
    assert.strictEqual(result.data.serverSpecs.cpuQuotaHard, true);
    assert.strictEqual(result.data.serverSpecs.effectiveCores, 0.5);
    assert.strictEqual(typeof result.data.memory.heapUsedMb, 'number');
    assert.strictEqual(typeof result.data.memory.heapLimitMb, 'number');
    assert.strictEqual(collector.peekSample().requestCount, 1, 'calibrate không được chốt cửa sổ');
  });

  await t.test('B5. calibrate: đủ dữ liệu thì RPM_tối_đa theo Luật sử dụng và lưu kết quả', async () => {
    const { service, repository, detector } = makeService();
    service._capacityWindows = Array.from({ length: 60 }, (_, k) => ({ cpuMs: 50 + 4 * (k % 10), completed: k % 10 }));
    const result = await service.calibrate({});
    const cap = result.data.capacity;
    const expected = F.estimateCapacity({ cpuMsPerRequest: 4, backgroundCpuMs: 50, quotaCores: 0.5 });
    assert.ok(Math.abs(cap.cpuMsPerRequest - 4) < 1e-6);
    assert.strictEqual(cap.maxRpm, expected.maxRpm);
    const alertRpm = detector.getEffectiveThresholds().traffic.alertRpm;
    assert.strictEqual(cap.alertRpm, alertRpm);
    assert.strictEqual(cap.status, F.assessCapacity(alertRpm, expected.maxRpm));
    assert.strictEqual(cap.estimatedMaxUsers, Math.floor(expected.maxRpm / F.ESTIMATE_RPM_PER_USER));
    const saved = JSON.parse(repository.settings.get('capacity_estimate'));
    assert.ok(Math.abs(saved.cpuMsPerRequest - 4) < 1e-6);
  });

  await t.test('Phương án (a): calibrate lưu ngưỡng tuỳ chỉnh; khởi động lại nạp lại được', async () => {
    const repository = makeRepo();
    const { service } = makeService({ repository });
    await service.calibrate({ customThresholds: { eventLoopLagMs: 300 } });
    assert.deepStrictEqual(JSON.parse(repository.settings.get('custom_vector_thresholds')).eventLoopLagMs, 300);

    const second = makeService({ repository });
    await second.service.loadPersistedSettings();
    assert.strictEqual(second.detector.getEffectiveThresholds().resource.lagMs.alert, 300);
  });

  await t.test('Ô trống không ghi đè: calibrate chỉ gộp các khoá được gửi', async () => {
    const { service, detector } = makeService();
    await service.calibrate({ customThresholds: { eventLoopLagMs: 300 } });
    await service.calibrate({ customThresholds: { resourceCpuPercent: 80 } });
    const ind = detector.getEffectiveThresholds();
    assert.strictEqual(ind.resource.lagMs.alert, 300);
    assert.strictEqual(ind.resource.cpuPercent.alert, 80);
    assert.strictEqual(ind.resource.ramPercent.alert, 92);
  });

  await t.test('Về mặc định: resetThresholds xoá mọi ngưỡng tuỳ chỉnh, lưu lại; khởi động lại vẫn là mặc định', async () => {
    const repository = makeRepo();
    const { service, detector } = makeService({ repository });
    await service.calibrate({ customThresholds: { eventLoopLagMs: 300, trafficSpikeRps: 50, authFailureThreshold: 30 } });
    assert.strictEqual(detector.getEffectiveThresholds().resource.lagMs.alert, 300);

    const res = await service.calibrate({ resetThresholds: true });
    const ind = detector.getEffectiveThresholds();
    assert.strictEqual(ind.resource.lagMs.alert, 250);
    assert.strictEqual(ind.auth.failedLogins.alert, 15);
    assert.strictEqual(ind.traffic.alertRpm, 6000, 'Bỏ trafficSpikeRps → về công thức max(3 × nền, …)');
    assert.strictEqual(res.status.indicators.resource.lagMs.alert, 250);
    const saved = JSON.parse(repository.settings.get('custom_vector_thresholds'));
    assert.ok(Object.values(saved).every((v) => v === null), 'Trạng thái lưu không còn ngưỡng tuỳ chỉnh');

    const second = makeService({ repository });
    await second.service.loadPersistedSettings();
    assert.strictEqual(second.detector.getEffectiveThresholds().resource.lagMs.alert, 250);
  });

  await t.test('B1. refreshTrafficBaselines nạp đường nền từ snapshot sạch', async () => {
    const snaps = [];
    const now = Date.now();
    for (let k = 0; k < 7 * 288; k++) {
      snaps.push({ requestsPerMin: 120, isAnomaly: false, recordedAt: new Date(now - k * 300000) });
    }
    const { service, detector } = makeService({ repository: makeRepo(snaps) });
    await service.refreshTrafficBaselines();
    const ind = detector.getEffectiveThresholds();
    assert.strictEqual(ind.traffic.source, 'history');
    assert.strictEqual(ind.traffic.baselineRpm, 120);
    assert.strictEqual(ind.traffic.alertRpm, 360);
  });
});
