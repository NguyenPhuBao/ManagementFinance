const test = require('node:test');
const assert = require('node:assert/strict');
const EventEmitter = require('node:events');
const { FeatureCollector } = require('../../modules/aiops/feature.collector');
const { EventLoopMonitor } = require('../../core/resilience/event-loop-monitor');
const { SystemHardwareMonitor } = require('../../core/resilience/system-hardware-monitor');
const { getRuntimeHardwareSpecs } = require('../../core/resilience/runtime-environment');
const quarantineModule = require('../../modules/aiops/aiops.quarantine');

// Đặc tả: docs/AIOps/AIOPS_CONG_THUC.md (A2–A5, dữ liệu cho B5)
const fakeLag = { getWindowLag: () => ({ p99Ms: 300, maxMs: 420 }), peekWindowLag: () => ({ p99Ms: 300, maxMs: 420 }) };

const hit = (mw, { ip = '9.9.9.9', path = '/api/wallets', status = 200 } = {}) => {
  const req = { ip, headers: {}, method: 'GET', path, originalUrl: path };
  const res = new EventEmitter();
  res.statusCode = status;
  mw(req, res, () => {});
  res.emit('finish');
};

test('AIOps đo lường', async (t) => {
  await t.test('A2. Ngưỡng chặn IP cố định 150, không phụ thuộc N; đổi được qua AIOPS_IP_BURST_PER_10S', () => {
    const c = new FeatureCollector({ eventLoopMonitor: fakeLag });
    c.setTargetConcurrency(100);
    assert.strictEqual(c._getBurstThreshold(), 150);
    c.setTargetConcurrency(50000);
    assert.strictEqual(c._getBurstThreshold(), 150);

    const q = quarantineModule.defaultAIOpsQuarantine;
    const original = q.quarantine;
    const calls = [];
    q.quarantine = (...args) => calls.push(args);
    process.env.AIOPS_IP_BURST_PER_10S = '80';
    try {
      assert.strictEqual(c._getBurstThreshold(), 80);
      const mw = c.createMiddleware();
      for (let i = 0; i < 80; i++) hit(mw, { ip: '203.0.113.7' });
      assert.strictEqual(calls.length, 0, 'Chưa vượt 80 thì chưa chặn');
      hit(mw, { ip: '203.0.113.7' });
      assert.strictEqual(calls.length, 1, 'Yêu cầu thứ 81 bị chặn');
    } finally {
      delete process.env.AIOPS_IP_BURST_PER_10S;
      q.quarantine = original;
    }
  });

  await t.test('A3. peekSample không xoá bộ đếm; getSample chốt cửa sổ', () => {
    const c = new FeatureCollector({ eventLoopMonitor: fakeLag });
    const mw = c.createMiddleware();
    for (let i = 0; i < 7; i++) hit(mw);
    assert.strictEqual(c.peekSample().requestCount, 7);
    for (let i = 0; i < 8; i++) hit(mw, { path: '/api/auth/login', status: 401 });
    const s = c.getSample();
    assert.strictEqual(s.requestCount, 15);
    assert.strictEqual(s.failedLogins, 8);
    assert.strictEqual(c.getSample().requestCount, 0);
  });

  await t.test('A3. RPM quy đổi theo số giây thực đã trôi của cửa sổ', () => {
    const c = new FeatureCollector({ eventLoopMonitor: fakeLag });
    c._windowStartedAt = Date.now() - 5000;
    const mw = c.createMiddleware();
    for (let i = 0; i < 10; i++) hit(mw);
    const s = c.getSample();
    assert.ok(s.windowSeconds >= 4.9 && s.windowSeconds <= 5.5, `windowSeconds=${s.windowSeconds}`);
    assert.ok(s.requestsPerMin >= 109 && s.requestsPerMin <= 120, `rpm=${s.requestsPerMin}`);
  });

  await t.test('B5. Mẫu có số yêu cầu hoàn tất và thời gian CPU của cửa sổ', () => {
    const c = new FeatureCollector({ eventLoopMonitor: fakeLag });
    const mw = c.createMiddleware();
    const req = { ip: '1.1.1.1', headers: {}, method: 'GET', path: '/x' };
    const pending = new EventEmitter();
    pending.statusCode = 200;
    mw(req, pending, () => {});
    hit(mw);
    hit(mw);
    const s = c.getSample();
    assert.strictEqual(s.requestCount, 3);
    assert.strictEqual(s.completedCount, 2, 'Chỉ đếm yêu cầu đã finish');
    assert.strictEqual(typeof s.cpuMs, 'number');
    assert.ok(s.cpuMs >= 0);
  });

  await t.test('A4. Độ trễ lấy p99/max trong cửa sổ; giai đoạn khởi động gắn cờ warmingUp, không gán cứng', () => {
    const ready = new FeatureCollector({ eventLoopMonitor: fakeLag, warmupMs: 0 });
    const s = ready.getSample();
    assert.strictEqual(s.eventLoopLagMs, 300);
    assert.strictEqual(s.eventLoopLagMaxMs, 420);
    assert.strictEqual(s.warmingUp, false);
    const warming = new FeatureCollector({ eventLoopMonitor: fakeLag, warmupMs: 60000 });
    const w = warming.getSample();
    assert.strictEqual(w.eventLoopLagMs, 300);
    assert.strictEqual(w.warmingUp, true);
  });

  await t.test('A4. EventLoopMonitor đo được lần nghẽn ngắn trong cửa sổ và reset sau khi chốt', async () => {
    const m = new EventLoopMonitor({ intervalMs: 500 });
    m.start();
    try {
      await new Promise((r) => setTimeout(r, 30));
      const until = Date.now() + 120;
      while (Date.now() < until) { /* chặn vòng lặp ~120ms */ }
      await new Promise((r) => setTimeout(r, 30));
      const peek = m.peekWindowLag();
      assert.ok(peek.maxMs >= 80, `maxMs=${peek.maxMs}`);
      const win = m.getWindowLag();
      assert.ok(win.maxMs >= 80);
      await new Promise((r) => setTimeout(r, 300));
      const idle = m.peekWindowLag();
      assert.ok(idle.maxMs < 80, 'Đã reset sau getWindowLag');
      assert.ok(idle.p99Ms < 20, `Vòng lặp rảnh không được báo trễ bằng chu kỳ đo: p99=${idle.p99Ms}`);
    } finally {
      m.stop();
    }
  });

  await t.test('A5. RAM = RSS tiến trình / hạn mức, không phụ thuộc RAM trống của máy', () => {
    const mon = new SystemHardwareMonitor({
      specsProvider: () => ({ isContainer: false, ramTotalMb: 8192, cpuCores: 8 }),
      memoryUsage: () => ({ rss: 512 * 1024 * 1024 }),
    });
    mon._sampleRam();
    assert.strictEqual(mon.currentRamPercent, 6);
    assert.strictEqual(mon.currentRamUsedMb, 512);
    assert.strictEqual(mon.currentRamTotalMb, 8192);
    assert.strictEqual(typeof mon.currentHostRamPercent, 'number');
  });

  await t.test('Hạn mức CPU cứng: cpu.max / cfs_quota / CLOUD_CPU_CORES là cứng; shares, weight, Render fallback, máy thật thì không', () => {
    const v2 = getRuntimeHardwareSpecs({
      env: { RENDER: 'true' }, isLinux: true,
      fileReader: (p) => (p.endsWith('cpu.max') ? '15000 100000' : p.endsWith('memory.max') ? '536870912' : null),
    });
    assert.strictEqual(v2.cpuQuotaHard, true);
    const shares = getRuntimeHardwareSpecs({
      env: { RENDER: 'true' }, isLinux: true,
      fileReader: (p) => (p.endsWith('cpu.shares') ? '154' : p.endsWith('cpu.cfs_quota_us') ? '-1' : null),
    });
    assert.strictEqual(shares.cpuQuotaHard, false);
    const renderGuess = getRuntimeHardwareSpecs({ env: { RENDER: 'true' }, isLinux: true, fileReader: () => null });
    assert.strictEqual(renderGuess.cpuQuotaHard, false);
    const envCfg = getRuntimeHardwareSpecs({ env: { CLOUD_CPU_CORES: '0.5', CLOUD_RAM_LIMIT_MB: '512' } });
    assert.strictEqual(envCfg.cpuQuotaHard, true);
    const host = getRuntimeHardwareSpecs({ env: {}, isLinux: false });
    assert.strictEqual(host.cpuQuotaHard, false);
  });
});
