const test = require('node:test');
const assert = require('node:assert/strict');
const F = require('../../modules/aiops/aiops.formulas');

// Kế hoạch: docs/superpowers/plans/2026-11-17-aiops-cong-thuc-va-do-luong.md (phần B)
test('AIOps formulas (B1–B5)', async (t) => {
  await t.test('B3. rampScore: 0 tại A, tuyến tính tới 70 tại T, 100 tại T_nặng', () => {
    const m = { attention: 5, alert: 15, severe: 30 };
    assert.strictEqual(F.rampScore(0, m), 0);
    assert.strictEqual(F.rampScore(5, m), 0);
    assert.strictEqual(F.rampScore(10, m), 35);
    assert.ok(F.rampScore(14.99, m) < 70);
    assert.strictEqual(F.rampScore(15, m), 70);
    assert.strictEqual(F.rampScore(22.5, m), 85);
    assert.strictEqual(F.rampScore(30, m), 100);
    assert.strictEqual(F.rampScore(1000, m), 100);
  });

  await t.test('B3. rampScore: A ≥ T thì A = T/2 (không chia cho 0)', () => {
    const s = F.rampScore(4, { attention: 10, alert: 8, severe: 16 });
    assert.strictEqual(s, Math.round((70 * (4 - 4)) / 4));
    assert.strictEqual(F.rampScore(8, { attention: 10, alert: 8, severe: 16 }), 70);
  });

  await t.test('median / percentile', () => {
    assert.strictEqual(F.median([5, 1, 3]), 3);
    assert.strictEqual(F.median([1, 2, 3, 4]), 2.5);
    assert.strictEqual(F.median([]), null);
    assert.strictEqual(F.percentile([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 0.95), 9.55);
  });

  await t.test('B2. trafficAlertRpm = max(3 × nền, 1,5 × P95, 300)', () => {
    assert.strictEqual(F.trafficAlertRpm(50, 60), 300);
    assert.strictEqual(F.trafficAlertRpm(1000, 1200), 3000);
    assert.strictEqual(F.trafficAlertRpm(1000, 2400), 3600);
  });

  const vnHourDate = (dayOffset, vnHour, minute = 0) => {
    // Thời điểm có giờ VN = vnHour, lùi dayOffset ngày so với mốc cố định.
    const base = Date.UTC(2026, 10, 10, (vnHour - 7 + 24) % 24, minute);
    return new Date(base - dayOffset * 86400000);
  };

  await t.test('B1. Đường nền theo giờ: trung vị snapshot sạch cùng giờ VN, bỏ mẫu bất thường', () => {
    const snaps = [];
    for (let d = 0; d < 3; d++) {
      for (let k = 0; k < 10; k++) {
        snaps.push({ requestsPerMin: 100 + k, isAnomaly: false, recordedAt: vnHourDate(d, 9, k * 5) });
      }
    }
    snaps.push({ requestsPerMin: 99999, isAnomaly: true, recordedAt: vnHourDate(0, 9, 1) });
    const hours = F.computeHourlyTrafficBaselines(snaps, { targetConcurrency: 100 });
    assert.strictEqual(hours.length, 24);
    assert.strictEqual(hours[9].source, 'history');
    assert.strictEqual(hours[9].samples, 30);
    assert.strictEqual(hours[9].baselineRpm, 104.5);
    assert.ok(hours[9].p95Rpm >= 108 && hours[9].p95Rpm <= 109);
  });

  await t.test('B1. Thiếu mẫu cho giờ h: dùng trung vị 24h gần nhất; vẫn thiếu: ước tính N × 2', () => {
    const now = vnHourDate(0, 23, 59);
    const snaps = [];
    for (let k = 0; k < 12; k++) snaps.push({ requestsPerMin: 40, isAnomaly: false, recordedAt: vnHourDate(0, 14, k) });
    const hours = F.computeHourlyTrafficBaselines(snaps, { targetConcurrency: 100, now });
    assert.strictEqual(hours[14].source, 'recent');
    assert.strictEqual(hours[3].source, 'recent');
    assert.strictEqual(hours[3].baselineRpm, 40);

    const none = F.computeHourlyTrafficBaselines([], { targetConcurrency: 300 });
    assert.strictEqual(none[0].source, 'estimate');
    assert.strictEqual(none[0].baselineRpm, 600);
    assert.strictEqual(none[0].p95Rpm, null);
  });

  await t.test('B5. fitUtilization: khớp C = C₀ + S × R bằng bình phương nhỏ nhất', () => {
    const windows = [];
    for (let i = 0; i < 40; i++) {
      const completed = i % 10;
      windows.push({ cpuMs: 50 + 4 * completed, completed });
    }
    const fit = F.fitUtilization(windows);
    assert.strictEqual(fit.ok, true);
    assert.ok(Math.abs(fit.cpuMsPerRequest - 4) < 1e-9);
    assert.ok(Math.abs(fit.backgroundCpuMs - 50) < 1e-9);
    assert.strictEqual(fit.windows, 40);
  });

  await t.test('B5. fitUtilization: thiếu dữ liệu / không có độ trải / S ≤ 0 thì ok = false', () => {
    assert.strictEqual(F.fitUtilization([{ cpuMs: 10, completed: 1 }]).ok, false);
    const flat = Array.from({ length: 40 }, () => ({ cpuMs: 30, completed: 5 }));
    assert.strictEqual(F.fitUtilization(flat).ok, false);
    const negative = Array.from({ length: 40 }, (_, i) => ({ cpuMs: 100 - (i % 10), completed: i % 10 }));
    assert.strictEqual(F.fitUtilization(negative).ok, false);
    const fewBusy = Array.from({ length: 40 }, (_, i) => ({ cpuMs: i < 5 ? 40 : 10, completed: i < 5 ? 3 : 0 }));
    assert.strictEqual(F.fitUtilization(fewBusy).ok, false);
  });

  await t.test('B5. estimateCapacity: X_max = (10000 × min(1,Q) × 0,7 − C₀) / S; RPM_max = 6 × X_max', () => {
    const cap = F.estimateCapacity({ cpuMsPerRequest: 4, backgroundCpuMs: 50, quotaCores: 0.5 });
    assert.strictEqual(cap.effectiveCores, 0.5);
    assert.strictEqual(cap.maxRequestsPerWindow, (10000 * 0.5 * 0.7 - 50) / 4);
    assert.strictEqual(cap.maxRpm, Math.floor(6 * ((10000 * 0.5 * 0.7 - 50) / 4)));
    const host = F.estimateCapacity({ cpuMsPerRequest: 4, backgroundCpuMs: 50, quotaCores: 8 });
    assert.strictEqual(host.effectiveCores, 1, 'Node một tiến trình dùng tối đa 1 nhân');
  });

  await t.test('B5. assessCapacity: ≤ max → OPTIMAL; ≤ max/0,7 → WARNING; còn lại OVER_CAPACITY', () => {
    assert.strictEqual(F.assessCapacity(700, 700), 'OPTIMAL');
    assert.strictEqual(F.assessCapacity(1000, 700), 'WARNING');
    assert.strictEqual(F.assessCapacity(1001, 700), 'OVER_CAPACITY');
    assert.strictEqual(F.assessCapacity(500, null), 'INSUFFICIENT_DATA');
  });

  await t.test('Mốc tín hiệu: ngưỡng tuỳ chỉnh T suy ra A và T_nặng theo tỷ lệ', () => {
    const m = F.signalMarks({ failedLogins: 30, lagMs: 500, cpuPercent: 80, ramPercent: 90, malformed: 10 });
    assert.deepStrictEqual(m.failedLogins, { attention: 10, alert: 30, severe: 60 });
    assert.deepStrictEqual(m.lagMs, { attention: 200, alert: 500, severe: 800 });
    assert.deepStrictEqual(m.cpuPercent, { attention: 65, alert: 80, severe: 90 });
    assert.deepStrictEqual(m.ramPercent, { attention: 78, alert: 90, severe: 95 });
    assert.deepStrictEqual(m.malformed, { attention: 1, alert: 10, severe: 25 });
    const d = F.signalMarks({});
    assert.deepStrictEqual(d.failedLogins, { attention: 5, alert: 15, severe: 30 });
    assert.deepStrictEqual(d.tokenReuse, { attention: 1, alert: 5, severe: 10 });
    assert.deepStrictEqual(d.lagMs, { attention: 100, alert: 250, severe: 400 });
    assert.deepStrictEqual(d.cpuPercent, { attention: 70, alert: 85, severe: 95 });
    assert.deepStrictEqual(d.ramPercent, { attention: 80, alert: 92, severe: 97 });
    assert.deepStrictEqual(d.error5xxRate, { attention: 0.02, alert: 0.1, severe: 0.25 });
  });
});
