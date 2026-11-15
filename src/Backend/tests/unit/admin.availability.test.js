/**
 * Độ khả dụng theo kỳ (kế hoạch 2026-11-15, mục 2.3; B10–B16; Q5, Q8).
 * Độ_khả_dụng = (Đo_được − Bảo_trì − Gián_đoạn) ÷ Đo_được × 100
 *  - Đo_được: [max(đầu kỳ, phiên đầu tiên), min(cuối kỳ, bây giờ)]
 *  - Bảo_trì: phiên COMPLETED/ONGOING giao với cửa sổ (Q8: có trừ); chia khẩn cấp / có kế hoạch
 *  - Gián_đoạn: khoảng trống sau phiên UNKNOWN (sập), trừ phần trùng bảo trì
 *  - Dừng có chủ đích: khoảng trống sau phiên GRACEFUL, báo riêng, không trừ (Q5)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { calcAvailability, resolvePeriod, buildBuckets, parsePeriodQuery } = require('../../modules/admin/availability');

const H = 3600 * 1000;
const D = 24 * H;
const t = (s) => new Date(s);
// Tháng 11/2026 theo giờ Việt Nam: 30 ngày
const NOV_START = t('2026-11-01T00:00:00+07:00');
const NOV_END = t('2026-12-01T00:00:00+07:00');

const sess = (start, end, reason = null, lastSeen = end) => ({
  started_at: start, ended_at: end, end_reason: reason, last_seen_at: lastSeen || start,
});
const maint = (start, end, type = 'SCHEDULED', status = 'COMPLETED') => ({
  started_at: start, ended_at: end, type, status, reason: 'x',
});

describe('calcAvailability', () => {
  it('B10. Chạy liên tục cả tháng, không sự kiện → 100%', () => {
    const r = calcAvailability({
      periodStart: NOV_START, periodEnd: NOV_END, now: NOV_END,
      sessions: [sess(t('2026-10-01T00:00:00Z'), null, null, NOV_END)], maintenances: [],
    });
    assert.equal(r.percent, 100);
    assert.equal(r.measuredSeconds, 30 * 24 * 3600);
    assert.equal(r.unplannedSeconds, 0);
  });

  it('B11. Bảo trì 1 giờ trong tháng 30 ngày đo đủ → 99,86%, ghi vào có kế hoạch', () => {
    const r = calcAvailability({
      periodStart: NOV_START, periodEnd: NOV_END, now: NOV_END,
      sessions: [sess(t('2026-10-01T00:00:00Z'), null, null, NOV_END)],
      maintenances: [maint(t('2026-11-10T01:00:00+07:00'), t('2026-11-10T02:00:00+07:00'), 'SCHEDULED')],
    });
    assert.equal(r.percent, 99.86);
    assert.equal(r.plannedMaintenanceSeconds, 3600);
    assert.equal(r.emergencyMaintenanceSeconds, 0);
  });

  it('B11b. Bảo trì khẩn cấp và nâng cấp chia đúng loại; CANCELLED / SCHEDULED không tính', () => {
    const r = calcAvailability({
      periodStart: NOV_START, periodEnd: NOV_END, now: NOV_END,
      sessions: [sess(t('2026-10-01T00:00:00Z'), null, null, NOV_END)],
      maintenances: [
        maint(t('2026-11-02T00:00:00+07:00'), t('2026-11-02T00:30:00+07:00'), 'EMERGENCY'),
        maint(t('2026-11-03T00:00:00+07:00'), t('2026-11-03T00:10:00+07:00'), 'UPGRADE'),
        maint(t('2026-11-04T00:00:00+07:00'), t('2026-11-04T05:00:00+07:00'), 'SCHEDULED', 'CANCELLED'),
        maint(t('2026-11-25T00:00:00+07:00'), t('2026-11-25T05:00:00+07:00'), 'SCHEDULED', 'SCHEDULED'),
      ],
    });
    assert.equal(r.emergencyMaintenanceSeconds, 1800);
    assert.equal(r.plannedMaintenanceSeconds, 600);
  });

  it('B12. Sập (phiên UNKNOWN) 2 giờ → tính gián đoạn, trừ vào %', () => {
    const crashAt = t('2026-11-15T10:00:00+07:00');
    const r = calcAvailability({
      periodStart: NOV_START, periodEnd: NOV_END, now: NOV_END,
      sessions: [
        sess(t('2026-10-01T00:00:00Z'), crashAt, 'UNKNOWN'),
        sess(new Date(crashAt.getTime() + 2 * H), null, null, NOV_END),
      ],
      maintenances: [],
    });
    assert.equal(r.unplannedSeconds, 7200);
    assert.equal(r.percent, Number(((30 * D - 2 * H) / (30 * D) * 100).toFixed(2)));
    assert.ok(r.incidents.some((i) => i.kind === 'UNPLANNED' && i.durationSeconds === 7200));
  });

  it('B13. Tắt có chủ đích (GRACEFUL) 1 giờ → vào dừng có chủ đích, % không đổi', () => {
    const stopAt = t('2026-11-15T10:00:00+07:00');
    const r = calcAvailability({
      periodStart: NOV_START, periodEnd: NOV_END, now: NOV_END,
      sessions: [
        sess(t('2026-10-01T00:00:00Z'), stopAt, 'GRACEFUL'),
        sess(new Date(stopAt.getTime() + H), null, null, NOV_END),
      ],
      maintenances: [],
    });
    assert.equal(r.plannedStopSeconds, 3600);
    assert.equal(r.unplannedSeconds, 0);
    assert.equal(r.percent, 100);
  });

  it('B14. Sập trùng một phần bảo trì → phần trùng chỉ tính một lần, ở bảo trì', () => {
    const crashAt = t('2026-11-15T10:00:00+07:00');
    const r = calcAvailability({
      periodStart: NOV_START, periodEnd: NOV_END, now: NOV_END,
      sessions: [
        sess(t('2026-10-01T00:00:00Z'), crashAt, 'UNKNOWN'),
        sess(new Date(crashAt.getTime() + 2 * H), null, null, NOV_END),
      ],
      // bảo trì từ 09:00 tới 11:00: trùng 1 giờ đầu của khoảng sập
      maintenances: [maint(t('2026-11-15T09:00:00+07:00'), t('2026-11-15T11:00:00+07:00'), 'EMERGENCY')],
    });
    assert.equal(r.emergencyMaintenanceSeconds, 7200);
    assert.equal(r.unplannedSeconds, 3600);
    assert.equal(r.percent, Number(((30 * D - 3 * H) / (30 * D) * 100).toFixed(2)));
  });

  it('B14b. Phiên còn mở nhưng mất nhịp (sập chưa được đóng) → từ nhịp cuối tới nay là gián đoạn', () => {
    const now = t('2026-11-20T00:00:00+07:00');
    const lastSeen = new Date(now.getTime() - 2 * H);
    const r = calcAvailability({
      periodStart: NOV_START, periodEnd: NOV_END, now,
      sessions: [sess(t('2026-10-01T00:00:00Z'), null, null, lastSeen)],
      maintenances: [],
    });
    assert.equal(r.unplannedSeconds, 7200);
  });

  it('B14c. Phiên hiện tại vừa ghi nhịp (trong ngưỡng 3 phút) không bị tính gián đoạn', () => {
    const now = t('2026-11-20T00:00:00+07:00');
    const r = calcAvailability({
      periodStart: NOV_START, periodEnd: NOV_END, now,
      sessions: [sess(t('2026-10-01T00:00:00Z'), null, null, new Date(now.getTime() - 50 * 1000))],
      maintenances: [],
    });
    assert.equal(r.unplannedSeconds, 0);
    assert.equal(r.percent, 100);
  });

  it('B15. Bắt đầu đo giữa kỳ, kỳ chưa hết → mẫu số chỉ phần đo được, có coverageFrom', () => {
    const first = t('2026-11-10T00:00:00+07:00');
    const now = t('2026-11-20T00:00:00+07:00');
    const r = calcAvailability({
      periodStart: NOV_START, periodEnd: NOV_END, now,
      sessions: [sess(first, null, null, now)], maintenances: [],
    });
    assert.equal(r.measuredSeconds, 10 * 24 * 3600);
    assert.equal(new Date(r.coverageFrom).getTime(), first.getTime());
    assert.equal(r.percent, 100);
  });

  it('B15b. Kỳ tương lai hoặc chưa có phiên nào → percent null', () => {
    const now = t('2026-11-20T00:00:00+07:00');
    const future = calcAvailability({
      periodStart: t('2027-01-01T00:00:00+07:00'), periodEnd: t('2027-02-01T00:00:00+07:00'), now,
      sessions: [sess(t('2026-10-01T00:00:00Z'), null, null, now)], maintenances: [],
    });
    assert.equal(future.percent, null);
    assert.equal(future.measuredSeconds, 0);
    const none = calcAvailability({ periodStart: NOV_START, periodEnd: NOV_END, now, sessions: [], maintenances: [] });
    assert.equal(none.percent, null);
  });
});

describe('Kỳ lịch theo giờ Việt Nam', () => {
  it('B16a. resolvePeriod tháng / quý / năm', () => {
    const m = resolvePeriod({ period: 'month', year: 2026, month: 11 });
    assert.equal(m.periodStart.toISOString(), '2026-10-31T17:00:00.000Z');
    assert.equal(m.periodEnd.toISOString(), '2026-11-30T17:00:00.000Z');
    const q = resolvePeriod({ period: 'quarter', year: 2026, quarter: 4 });
    assert.equal(q.periodStart.toISOString(), '2026-09-30T17:00:00.000Z');
    assert.equal(q.periodEnd.toISOString(), '2026-12-31T17:00:00.000Z');
    const y = resolvePeriod({ period: 'year', year: 2026 });
    assert.equal(y.periodStart.toISOString(), '2025-12-31T17:00:00.000Z');
    assert.equal(y.periodEnd.toISOString(), '2026-12-31T17:00:00.000Z');
  });

  it('B16b. buildBuckets: tháng theo ngày, quý và năm theo tháng', () => {
    assert.equal(buildBuckets(resolvePeriod({ period: 'month', year: 2026, month: 2 })).length, 28);
    assert.equal(buildBuckets(resolvePeriod({ period: 'month', year: 2026, month: 11 })).length, 30);
    const q = buildBuckets(resolvePeriod({ period: 'quarter', year: 2026, quarter: 4 }));
    assert.deepEqual(q.map((b) => b.label), ['10', '11', '12']);
    const y = buildBuckets(resolvePeriod({ period: 'year', year: 2026 }));
    assert.equal(y.length, 12);
    assert.equal(y[0].start.toISOString(), '2025-12-31T17:00:00.000Z');
  });

  it('B17a. parsePeriodQuery từ chối tham số sai', () => {
    const bad = [
      {}, { period: 'week', year: '2026' }, { period: 'month', year: '2026' }, { period: 'month', year: '2026', month: '13' },
      { period: 'quarter', year: '2026', quarter: '5' }, { period: 'year', year: 'abc' }, { period: 'year', year: '1999' },
    ];
    for (const q of bad) assert.throws(() => parsePeriodQuery(q), (e) => e.statusCode === 400, JSON.stringify(q));
    assert.deepEqual(parsePeriodQuery({ period: 'quarter', year: '2026', quarter: '4' }), { period: 'quarter', year: 2026, quarter: 4 });
  });
});
