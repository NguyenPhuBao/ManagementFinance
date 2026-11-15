/**
 * Đọc dữ liệu (server_session, maintenance_history) và tính độ khả dụng theo kỳ.
 * Bảng server_session chưa có (migration 52 chưa áp) → trả "chưa có dữ liệu", không ném lỗi.
 */

const logger = require('../../core/logger');
const { calcAvailability, resolvePeriod, buildBuckets, parsePeriodQuery } = require('./availability');

const MISSING_TABLE = '42P01';

function vnYearMonth(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit' })
    .formatToParts(date);
  return { year: Number(parts.find((p) => p.type === 'year').value), month: Number(parts.find((p) => p.type === 'month').value) };
}

async function loadData(pool, periodStart, periodEnd, now) {
  const ws = periodStart.toISOString();
  const we = periodEnd.toISOString();
  // Phiên giao với kỳ, cộng phiên kết thúc gần nhất trước kỳ (để phân loại khoảng trống đầu kỳ).
  const sessions = (await pool.query(
    `(SELECT "started_at", "last_seen_at", "ended_at", "end_reason" FROM "server_session"
       WHERE "started_at" < $2 AND ("ended_at" IS NULL OR "ended_at" >= $1))
     UNION ALL
     (SELECT "started_at", "last_seen_at", "ended_at", "end_reason" FROM "server_session"
       WHERE "ended_at" < $1 ORDER BY "ended_at" DESC LIMIT 1)`,
    [ws, we]
  )).rows;
  const maintenances = (await pool.query(
    `SELECT "type", "reason", "status", "started_at", "ended_at" FROM "maintenance_history"
     WHERE "status" IN ('COMPLETED', 'ONGOING') AND "started_at" < $2 AND COALESCE("ended_at", $3::timestamptz) > $1`,
    [ws, we, now.toISOString()]
  )).rows;
  const first = (await pool.query(
    `SELECT EXTRACT(YEAR FROM MIN("started_at") AT TIME ZONE 'Asia/Ho_Chi_Minh')::int AS y FROM "server_session"`
  )).rows[0];
  return { sessions, maintenances, firstYear: first && first.y ? first.y : null };
}

function yearsFrom(firstYear, now) {
  const cur = vnYearMonth(now).year;
  const from = firstYear && firstYear <= cur ? firstYear : cur;
  const out = [];
  for (let y = cur; y >= from; y -= 1) out.push(y);
  return out;
}

/**
 * @param {object} query { period, year, month?, quarter? } (chuỗi từ querystring)
 * @param {{pool?: object, now?: Date}} deps
 */
async function getAvailability(query, { pool = require('../../config/db').pool, now = new Date() } = {}) {
  const p = resolvePeriod(parsePeriodQuery(query));
  let data = { sessions: [], maintenances: [], firstYear: null };
  let trackingAvailable = true;
  try {
    data = await loadData(pool, p.periodStart, p.periodEnd, now);
  } catch (err) {
    if (err.code !== MISSING_TABLE) throw err;
    trackingAvailable = false;
    logger.warn('[Availability] Chưa có bảng server_session (migration 52 chưa áp)');
  }
  const calc = (start, end) => calcAvailability({ periodStart: start, periodEnd: end, now, sessions: data.sessions, maintenances: data.maintenances });
  const whole = calc(p.periodStart, p.periodEnd);
  return {
    period: p.period, year: p.year, month: p.month || null, quarter: p.quarter || null, label: p.label,
    periodStart: p.periodStart.toISOString(), periodEnd: p.periodEnd.toISOString(),
    trackingAvailable,
    ...whole,
    buckets: buildBuckets(p).map((b) => ({ label: b.label, start: b.start.toISOString(), end: b.end.toISOString(), percent: calc(b.start, b.end).percent })),
    availableYears: yearsFrom(data.firstYear, now),
  };
}

// Độ khả dụng tháng hiện tại cho thẻ dashboard / luồng metrics 3 giây: lưu đệm 60 giây,
// tính lại ngay khi trạng thái bảo trì đổi (khoá đệm gồm active + activatedAt).
const CACHE_MS = 60 * 1000;
let cache = { at: 0, key: null, value: null, pending: null };

async function getCurrentMonthAvailability({ maintenanceKey = '', now = new Date(), pool } = {}) {
  if (cache.value && cache.key === maintenanceKey && now.getTime() - cache.at < CACHE_MS) return cache.value;
  if (cache.pending) return cache.pending;
  const { year, month } = vnYearMonth(now);
  cache.pending = getAvailability({ period: 'month', year: String(year), month: String(month) }, { now, ...(pool ? { pool } : {}) })
    .then((r) => {
      const value = { period: 'month', year, month, label: r.label, percent: r.percent, coverageFrom: r.coverageFrom,
        downtimeSeconds: r.plannedMaintenanceSeconds + r.emergencyMaintenanceSeconds + r.unplannedSeconds };
      cache = { at: now.getTime(), key: maintenanceKey, value, pending: null };
      return value;
    })
    .catch((err) => {
      logger.warn('[Availability] Không tính được độ khả dụng tháng hiện tại', { error: err.message });
      cache.pending = null;
      return { period: 'month', year, month, label: null, percent: null, coverageFrom: null, downtimeSeconds: 0 };
    });
  return cache.pending;
}

function resetAvailabilityCache() {
  cache = { at: 0, key: null, value: null, pending: null };
}

module.exports = { getAvailability, getCurrentMonthAvailability, resetAvailabilityCache, vnYearMonth };
