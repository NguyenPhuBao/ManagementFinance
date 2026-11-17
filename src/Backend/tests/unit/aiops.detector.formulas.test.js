const test = require('node:test');
const assert = require('node:assert/strict');
const { AnomalyDetector } = require('../../modules/aiops/anomaly.detector');

// Đặc tả: docs/AIOps/AIOPS_CONG_THUC.md (A1, B1–B4)
const base = (over = {}) => ({
  timestamp: new Date().toISOString(),
  requestsPerMin: 60,
  requestCount: 10,
  errorRate4xx: 0,
  errorRate5xx: 0,
  failedLogins: 0,
  tokenReuseAttacks: 0,
  malformedRequests: 0,
  eventLoopLagMs: 5,
  cpuPercent: 10,
  ramPercent: 20,
  distinctIpsCount: 5,
  ...over,
});

const flatHours = (baselineRpm, p95Rpm) =>
  Array.from({ length: 24 }, () => ({ baselineRpm, p95Rpm, source: 'history', samples: 84 }));

test('AnomalyDetector — công thức mới', async (t) => {
  await t.test('A1. getEffectiveThresholds trả đúng ngưỡng evaluate dùng (mặc định N=1000)', () => {
    const d = new AnomalyDetector();
    const ind = d.getEffectiveThresholds();
    assert.strictEqual(ind.traffic.baselineRpm, 2000);
    assert.strictEqual(ind.traffic.alertRpm, 6000);
    assert.strictEqual(ind.traffic.source, 'estimate');
    assert.deepStrictEqual(ind.auth.failedLogins, { attention: 5, alert: 15, severe: 30 });
    assert.deepStrictEqual(ind.resource.lagMs, { attention: 100, alert: 250, severe: 400 });
    assert.strictEqual(ind.ipBurstPer10s, 150);
    assert.deepStrictEqual(ind.scoreBands, { elevated: 40, warning: 70, critical: 85 });
  });

  await t.test('B1/B2. Đường nền nạp từ lịch sử; ngưỡng = max(3×nền, 1,5×P95, 300); cảnh báo đúng tại biên', () => {
    const d = new AnomalyDetector();
    d.setTrafficBaselines(flatHours(100, 120));
    const ind = d.getEffectiveThresholds();
    assert.strictEqual(ind.traffic.baselineRpm, 100);
    assert.strictEqual(ind.traffic.alertRpm, 300);
    assert.strictEqual(ind.traffic.source, 'history');

    const below = d.evaluate(base({ requestsPerMin: 299, requestCount: 50, malformedRequests: 1 }));
    assert.ok(!below.anomalies.some((a) => a.code === 'TRAFFIC_ANOMALY_FLOOD'));
    assert.ok(below.vectorScores.traffic < 70);

    const at = d.evaluate(base({ requestsPerMin: 300, requestCount: 50, malformedRequests: 1 }));
    const flood = at.anomalies.find((a) => a.code === 'TRAFFIC_ANOMALY_FLOOD');
    assert.ok(flood, 'Phải ghi sự cố lưu lượng tại ngưỡng');
    assert.strictEqual(flood.threshold, 300);
    assert.ok(at.vectorScores.traffic >= 70);
  });

  await t.test('B3. Lưu lượng dưới mức chú ý cho 0 điểm (không cộng điểm sẵn)', () => {
    const d = new AnomalyDetector();
    d.setTrafficBaselines(flatHours(100, 120));
    const r = d.evaluate(base({ requestsPerMin: 150 }));
    assert.strictEqual(r.vectorScores.traffic, 0);
  });

  await t.test('B3. Đường nền ≈ 0 (lịch sử toàn mẫu rỗi): mức chú ý có sàn 0,5 × T, lưu lượng nhỏ không có điểm', () => {
    const d = new AnomalyDetector();
    d.setTrafficBaselines(flatHours(0, 0));
    const ind = d.getEffectiveThresholds();
    assert.strictEqual(ind.traffic.alertRpm, 300);
    assert.strictEqual(ind.traffic.attentionRpm, 150);
    assert.strictEqual(d.evaluate(base({ requestsPerMin: 120 })).vectorScores.traffic, 0);
  });

  await t.test('B4. Dấu hiệu tấn công theo thị phần IP lớn nhất ≥ 50%', () => {
    const d = new AnomalyDetector();
    d.setTrafficBaselines(flatHours(100, 120));
    const share = (n) => base({ requestsPerMin: 600, requestCount: 100, distinctIpsCount: 40, topTrafficActor: { identity: '1.2.xxx.xxx', reqCount: n } });
    assert.ok(d.evaluate(share(60)).anomalies.some((a) => a.code === 'TRAFFIC_ANOMALY_FLOOD'));
    const organic = d.evaluate(share(10));
    assert.ok(!organic.anomalies.some((a) => a.code === 'TRAFFIC_ANOMALY_FLOOD'));
    assert.ok(organic.vectorScores.traffic <= 40);
  });

  await t.test('B3. Đăng nhập sai: 14 lần không cảnh báo, 15 lần cảnh báo; không phụ thuộc N', () => {
    for (const n of [100, 50000]) {
      const d = new AnomalyDetector({ targetConcurrency: n });
      const r14 = d.evaluate(base({ failedLogins: 14 }));
      assert.ok(r14.vectorScores.auth < 70 && r14.vectorScores.auth > 0, `N=${n}: ${r14.vectorScores.auth}`);
      assert.ok(!r14.anomalies.some((a) => a.code === 'AUTH_BRUTE_FORCE'));
      const r15 = d.evaluate(base({ failedLogins: 15 }));
      assert.strictEqual(r15.vectorScores.auth, 70);
      assert.ok(r15.anomalies.some((a) => a.code === 'AUTH_BRUTE_FORCE'));
    }
  });

  await t.test('Ngưỡng tuỳ chỉnh: authFailureThreshold = 30 thì 29 chưa cảnh báo, 30 cảnh báo', () => {
    const d = new AnomalyDetector();
    d.setCustomThresholds({ authFailureThreshold: 30 });
    assert.strictEqual(d.getEffectiveThresholds().auth.failedLogins.alert, 30);
    assert.ok(!d.evaluate(base({ failedLogins: 29 })).anomalies.some((a) => a.code === 'AUTH_BRUTE_FORCE'));
    assert.ok(d.evaluate(base({ failedLogins: 30 })).anomalies.some((a) => a.code === 'AUTH_BRUTE_FORCE'));
  });

  await t.test('Ngưỡng tuỳ chỉnh trafficSpikeRps ghi đè: ngưỡng = rps × 60', () => {
    const d = new AnomalyDetector();
    d.setCustomThresholds({ trafficSpikeRps: 20 });
    assert.strictEqual(d.getEffectiveThresholds().traffic.alertRpm, 1200);
  });

  await t.test('B3. Lỗi 5xx: cảnh báo từ 10% khi đủ ≥ 10 yêu cầu', () => {
    const d = new AnomalyDetector();
    assert.ok(d.evaluate(base({ requestCount: 20, errorRate5xx: 0.1 })).anomalies.some((a) => a.code === 'SERVER_5XX_SURGE'));
    assert.ok(!d.evaluate(base({ requestCount: 20, errorRate5xx: 0.09 })).anomalies.some((a) => a.code === 'SERVER_5XX_SURGE'));
    assert.ok(!d.evaluate(base({ requestCount: 5, errorRate5xx: 0.6 })).anomalies.some((a) => a.code === 'SERVER_5XX_SURGE'));
  });

  await t.test('A4. Đang khởi động (warmingUp) thì bỏ qua độ trễ vòng lặp', () => {
    const d = new AnomalyDetector();
    const r = d.evaluate(base({ eventLoopLagMs: 1000, warmingUp: true }));
    assert.ok(!r.anomalies.some((a) => a.code === 'EVENT_LOOP_FREEZE'));
    assert.strictEqual(r.vectorScores.resource, 0);
  });

  await t.test('setConcurrencyScale chỉ đổi đường nền ước tính, giữ đường nền từ lịch sử', () => {
    const d = new AnomalyDetector();
    d.setTrafficBaselines(flatHours(100, 120));
    const res = d.setConcurrencyScale(5000);
    assert.strictEqual(res.targetConcurrency, 5000);
    assert.strictEqual(res.indicators.traffic.baselineRpm, 100);
    const fresh = new AnomalyDetector();
    assert.strictEqual(fresh.setConcurrencyScale(5000).indicators.traffic.baselineRpm, 10000);
  });

  await t.test('calibrate không xoá đường nền đã nạp từ lịch sử', () => {
    const d = new AnomalyDetector();
    d.setTrafficBaselines(flatHours(100, 120));
    d.calibrate({ targetConcurrency: 3000, customThresholds: { eventLoopLagMs: 300 } });
    const ind = d.getEffectiveThresholds();
    assert.strictEqual(ind.traffic.baselineRpm, 100);
    assert.strictEqual(ind.resource.lagMs.alert, 300);
    assert.strictEqual(d.targetConcurrency, 3000);
  });
});
