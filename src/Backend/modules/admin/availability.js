/**
 * Độ khả dụng theo kỳ lịch (tháng / quý / năm, giờ Việt Nam).
 * Kế hoạch: docs/superpowers/plans/2026-11-15-bao-tri-ben-vung-va-do-kha-dung.md (mục 2.3)
 *
 *   Độ_khả_dụng = (Đo_được − Bảo_trì − Gián_đoạn) ÷ Đo_được × 100
 *
 *  - Đo_được: cửa sổ [max(đầu kỳ, phiên chạy đầu tiên), min(cuối kỳ, bây giờ)].
 *  - Bảo_trì: phiên COMPLETED / ONGOING của maintenance_history giao với cửa sổ (có trừ, vì bảo trì chặn khách hàng).
 *    Chia khẩn cấp (EMERGENCY) và có kế hoạch (SCHEDULED, ROUTINE, UPGRADE); chồng nhau thì tính cho khẩn cấp.
 *  - Gián_đoạn (ngoài dự kiến): khoảng không có phiên chạy nào, sau một phiên không đóng kịp (UNKNOWN / mất nhịp).
 *  - Dừng có chủ đích: khoảng không có phiên chạy, sau một phiên GRACEFUL. Báo riêng, không trừ.
 *  Hai loại khoảng trống trên đều trừ phần trùng bảo trì (không đếm hai lần).
 * Hàm thuần: không đọc CSDL, nhận dữ liệu và thời điểm `now` từ ngoài.
 */

const { STALE_MS } = require('../../core/resilience/server-session');

const ms = (v) => (v instanceof Date ? v.getTime() : new Date(v).getTime());

function union(list) {
  const sorted = list.filter(([s, e]) => e > s).sort((a, b) => a[0] - b[0]);
  const out = [];
  for (const [s, e] of sorted) {
    const last = out[out.length - 1];
    if (last && s <= last[1]) last[1] = Math.max(last[1], e);
    else out.push([s, e]);
  }
  return out;
}

function clip(list, ws, we) {
  return list.map(([s, e]) => [Math.max(s, ws), Math.min(e, we)]).filter(([s, e]) => e > s);
}

/** A − B, cả hai đã là hợp rời nhau đã sắp xếp. */
function subtract(a, b) {
  const out = [];
  for (const [s0, e0] of a) {
    let s = s0;
    for (const [bs, be] of b) {
      if (be <= s || bs >= e0) continue;
      if (bs > s) out.push([s, bs]);
      s = Math.max(s, be);
      if (s >= e0) break;
    }
    if (s < e0) out.push([s, e0]);
  }
  return out;
}

const total = (list) => list.reduce((acc, [s, e]) => acc + (e - s), 0);
const sec = (x) => Math.round(x / 1000);

function sessionEnd(row, nowMs) {
  if (row.ended_at) return { end: ms(row.ended_at), reason: row.end_reason || 'UNKNOWN' };
  const lastSeen = ms(row.last_seen_at || row.started_at);
  if (nowMs - lastSeen <= STALE_MS) return { end: nowMs, reason: null }; // còn sống
  return { end: lastSeen, reason: 'UNKNOWN' }; // mất nhịp: sập chưa được đóng
}

/**
 * @param {{periodStart: Date, periodEnd: Date, now: Date, sessions: object[], maintenances: object[]}} input
 */
function calcAvailability({ periodStart, periodEnd, now, sessions = [], maintenances = [] }) {
  const nowMs = ms(now);
  const trackingStart = sessions.length ? Math.min(...sessions.map((r) => ms(r.started_at))) : null;
  const empty = {
    percent: null, measuredSeconds: 0, coverageFrom: trackingStart !== null ? new Date(trackingStart).toISOString() : null,
    plannedMaintenanceSeconds: 0, emergencyMaintenanceSeconds: 0, unplannedSeconds: 0, plannedStopSeconds: 0, incidents: [],
  };
  if (trackingStart === null) return empty;
  const ws = Math.max(ms(periodStart), trackingStart);
  const we = Math.min(ms(periodEnd), nowMs);
  if (we <= ws) return empty;

  // Bảo trì
  const counted = maintenances.filter((m) => m.status === 'COMPLETED' || m.status === 'ONGOING');
  const maintRows = counted
    .map((m) => ({ row: m, iv: [ms(m.started_at), m.ended_at ? ms(m.ended_at) : nowMs] }))
    .map((x) => ({ ...x, iv: clip([x.iv], ws, we)[0] }))
    .filter((x) => x.iv);
  const maintAll = union(maintRows.map((x) => x.iv));
  const maintEmergency = union(maintRows.filter((x) => x.row.type === 'EMERGENCY').map((x) => x.iv));
  const emergencyMs = total(maintEmergency);
  const plannedMs = total(maintAll) - emergencyMs;

  // Khoảng trống giữa các phiên chạy
  const ends = sessions.map((r) => ({ start: ms(r.started_at), ...sessionEnd(r, nowMs) }));
  const covered = union(ends.map((x) => [x.start, x.end]));
  const gaps = subtract([[ws, we]], clip(covered, ws, we));
  const unplannedGaps = [];
  const stopGaps = [];
  for (const gap of gaps) {
    const before = ends.filter((x) => x.end <= gap[0]).sort((a, b) => b.end - a.end)[0];
    (before && before.reason === 'GRACEFUL' ? stopGaps : unplannedGaps).push(gap);
  }
  const unplanned = subtract(union(unplannedGaps), maintAll);
  const stops = subtract(union(stopGaps), maintAll);

  const measuredMs = we - ws;
  const downMs = total(maintAll) + total(unplanned);
  const raw = ((measuredMs - downMs) / measuredMs) * 100;

  const incidents = [
    ...maintRows.map(({ row, iv }) => ({
      kind: row.type === 'EMERGENCY' ? 'EMERGENCY' : 'PLANNED',
      start: new Date(iv[0]).toISOString(), end: new Date(iv[1]).toISOString(),
      durationSeconds: sec(iv[1] - iv[0]), reason: row.reason || null, ongoing: row.status === 'ONGOING',
    })),
    ...unplanned.map(([s, e]) => ({ kind: 'UNPLANNED', start: new Date(s).toISOString(), end: new Date(e).toISOString(), durationSeconds: sec(e - s) })),
    ...stops.map(([s, e]) => ({ kind: 'PLANNED_STOP', start: new Date(s).toISOString(), end: new Date(e).toISOString(), durationSeconds: sec(e - s) })),
  ].sort((a, b) => ms(b.start) - ms(a.start)).slice(0, 100);

  return {
    percent: Number(Math.min(100, Math.max(0, raw)).toFixed(2)),
    measuredSeconds: sec(measuredMs),
    coverageFrom: new Date(ws).toISOString(),
    plannedMaintenanceSeconds: sec(plannedMs),
    emergencyMaintenanceSeconds: sec(emergencyMs),
    unplannedSeconds: sec(total(unplanned)),
    plannedStopSeconds: sec(total(stops)),
    incidents,
  };
}

const pad = (n) => String(n).padStart(2, '0');
const vnDate = (y, m, d = 1) => new Date(`${y}-${pad(m)}-${pad(d)}T00:00:00+07:00`);
const nextMonth = (y, m) => (m === 12 ? [y + 1, 1] : [y, m + 1]);

function resolvePeriod({ period, year, month, quarter }) {
  if (period === 'month') {
    const [ny, nm] = nextMonth(year, month);
    return { period, year, month, label: `${pad(month)}/${year}`, periodStart: vnDate(year, month), periodEnd: vnDate(ny, nm) };
  }
  if (period === 'quarter') {
    const m0 = (quarter - 1) * 3 + 1;
    const [ny, nm] = m0 + 3 > 12 ? [year + 1, 1] : [year, m0 + 3];
    return { period, year, quarter, label: `Q${quarter}/${year}`, periodStart: vnDate(year, m0), periodEnd: vnDate(ny, nm) };
  }
  return { period: 'year', year, label: String(year), periodStart: vnDate(year, 1), periodEnd: vnDate(year + 1, 1) };
}

function buildBuckets(p) {
  const out = [];
  if (p.period === 'month') {
    const days = new Date(Date.UTC(p.year, p.month, 0)).getUTCDate();
    for (let d = 1; d <= days; d += 1) {
      const start = vnDate(p.year, p.month, d);
      const end = d === days ? p.periodEnd : vnDate(p.year, p.month, d + 1);
      out.push({ label: String(d), start, end });
    }
    return out;
  }
  const firstMonth = p.period === 'quarter' ? (p.quarter - 1) * 3 + 1 : 1;
  const count = p.period === 'quarter' ? 3 : 12;
  for (let i = 0; i < count; i += 1) {
    const m = firstMonth + i;
    const [ny, nm] = nextMonth(p.year, m);
    out.push({ label: String(m), start: vnDate(p.year, m), end: vnDate(ny, nm) });
  }
  return out;
}

function badRequest(message) {
  return Object.assign(new Error(message), { statusCode: 400, code: 'INVALID_PERIOD' });
}

function parsePeriodQuery(q = {}) {
  const int = (v) => (/^\d+$/.test(String(v ?? '')) ? Number(v) : NaN);
  const period = String(q.period || '');
  if (!['month', 'quarter', 'year'].includes(period)) throw badRequest('period phải là month, quarter hoặc year');
  const year = int(q.year);
  if (!(year >= 2000 && year <= 2100)) throw badRequest('year không hợp lệ');
  if (period === 'month') {
    const month = int(q.month);
    if (!(month >= 1 && month <= 12)) throw badRequest('month phải từ 1 tới 12');
    return { period, year, month };
  }
  if (period === 'quarter') {
    const quarter = int(q.quarter);
    if (!(quarter >= 1 && quarter <= 4)) throw badRequest('quarter phải từ 1 tới 4');
    return { period, year, quarter };
  }
  return { period, year };
}

module.exports = { calcAvailability, resolvePeriod, buildBuckets, parsePeriodQuery };
