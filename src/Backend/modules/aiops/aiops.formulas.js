/**
 * Công thức AIOps (hàm thuần, không I/O).
 * Đặc tả: docs/AIOps/AIOPS_CONG_THUC.md
 *
 * Ký hiệu: A = ngưỡng chú ý, T = ngưỡng cảnh báo, T_nặng = mức nghiêm trọng;
 * RPM = số yêu cầu mỗi phút; cửa sổ = chu kỳ lấy mẫu 10 giây.
 */

const ESTIMATE_RPM_PER_USER = 2; // r: ước tính khởi đầu (đồng bộ định kỳ 15 phút + đẩy sau thao tác)
const MIN_HOUR_SAMPLES = 24; // ≥ 24 snapshot (5 phút/mẫu) cho một giờ ≈ 2 ngày dữ liệu
const MIN_RECENT_SAMPLES = 12;
const TRAFFIC_FLOOR_RPM = 300;
const U_MAX = 0.7; // mức sử dụng CPU mục tiêu (hàng đợi M/M/1: chờ ∝ ρ/(1−ρ))
const VN_OFFSET_HOURS = 7;

/** Ngưỡng chặn một IP (yêu cầu / 10 giây): cố định, không phụ thuộc quy mô N. */
function ipBurstPer10s() {
  const v = parseInt(process.env.AIOPS_IP_BURST_PER_10S, 10);
  return v > 0 ? v : 150;
}

const vnHourOf =(date) => (new Date(date).getUTCHours() + VN_OFFSET_HOURS) % 24;

/** Phân vị p (0..1), nội suy tuyến tính giữa hai hạng kề nhau. */
function percentile(values, p) {
  const s = values.filter((v) => Number.isFinite(v)).sort((a, b) => a - b);
  if (s.length === 0) return null;
  const rank = (s.length - 1) * p;
  const lo = Math.floor(rank);
  const hi = Math.ceil(rank);
  return Number((s[lo] + (s[hi] - s[lo]) * (rank - lo)).toFixed(4));
}

const median = (values) => percentile(values, 0.5);

/**
 * B3. Điểm liên tục của một tín hiệu x:
 *   0                                   x ≤ A
 *   70 × (x − A) / (T − A)              A < x < T
 *   70 + 30 × min(1, (x − T)/(T_nặng − T))   x ≥ T
 */
function rampScore(x, { attention, alert, severe }) {
  const v = Number(x) || 0;
  const T = Number(alert);
  let A = Number(attention);
  if (!(A < T)) A = T / 2;
  if (v >= T) {
    if (!(severe > T)) return 100;
    return Math.round(70 + 30 * Math.min(1, (v - T) / (severe - T)));
  }
  if (v <= A) return 0;
  // Dưới T thì tối đa 69: giữ bất biến "điểm ≥ 70 ⇔ x ≥ T" khi làm tròn.
  return Math.min(69, Math.round((70 * (v - A)) / (T - A)));
}

const positive = (v) => (v !== null && v !== undefined && Number(v) > 0 ? Number(v) : null);

/** Mốc A / T / T_nặng của từng tín hiệu; ngưỡng tuỳ chỉnh chỉ đặt T, A và T_nặng suy theo tỷ lệ. */
function signalMarks(custom = {}) {
  const failed = positive(custom.failedLogins) ?? 15;
  const malformed = positive(custom.malformed) ?? 8;
  const lag = positive(custom.lagMs) ?? 250;
  const cpu = positive(custom.cpuPercent) ?? 85;
  const ram = positive(custom.ramPercent) ?? 92;
  return {
    failedLogins: { attention: failed / 3, alert: failed, severe: failed * 2 },
    tokenReuse: { attention: 1, alert: 5, severe: 10 },
    malformed: { attention: 1, alert: malformed, severe: malformed * 2.5 },
    lagMs: { attention: lag * 0.4, alert: lag, severe: lag * 1.6 },
    cpuPercent: { attention: Math.max(0, cpu - 15), alert: cpu, severe: Math.min(100, cpu + 10) },
    ramPercent: { attention: Math.max(0, ram - 12), alert: ram, severe: Math.min(100, ram + 5) },
    error5xxRate: { attention: 0.02, alert: 0.1, severe: 0.25 },
  };
}

/** B2. Ngưỡng cảnh báo lưu lượng = max(3 × nền, 1,5 × P95, 300). */
function trafficAlertRpm(baselineRpm, p95Rpm) {
  return Math.round(Math.max(3 * (baselineRpm || 0), 1.5 * (p95Rpm || 0), TRAFFIC_FLOOR_RPM));
}

/**
 * B1. Đường nền 24 giờ từ snapshot (đã lọc 7 ngày ở nơi truy vấn).
 * Giờ h đủ ≥ 24 mẫu sạch → trung vị cùng giờ; không thì trung vị mẫu sạch 24h gần nhất (≥ 12 mẫu);
 * không thì ước tính N × r.
 */
function computeHourlyTrafficBaselines(snapshots = [], { targetConcurrency = 1000, now = Date.now() } = {}) {
  const clean = snapshots
    .filter((s) => s && !s.isAnomaly && Number.isFinite(Number(s.requestsPerMin)))
    .map((s) => ({ rpm: Number(s.requestsPerMin), at: new Date(s.recordedAt || s.timestamp) }))
    .filter((s) => !Number.isNaN(s.at.getTime()));

  const byHour = Array.from({ length: 24 }, () => []);
  for (const s of clean) byHour[vnHourOf(s.at)].push(s.rpm);

  const nowMs = new Date(now).getTime();
  const recent = clean.filter((s) => s.at.getTime() >= nowMs - 86400000 && s.at.getTime() <= nowMs).map((s) => s.rpm);
  const estimate = Math.max(100, Number(targetConcurrency) || 1000) * ESTIMATE_RPM_PER_USER;

  return byHour.map((values) => {
    if (values.length >= MIN_HOUR_SAMPLES) {
      return { baselineRpm: median(values), p95Rpm: percentile(values, 0.95), source: 'history', samples: values.length };
    }
    if (recent.length >= MIN_RECENT_SAMPLES) {
      return { baselineRpm: median(recent), p95Rpm: percentile(recent, 0.95), source: 'recent', samples: recent.length };
    }
    return { baselineRpm: estimate, p95Rpm: null, source: 'estimate', samples: 0 };
  });
}

/**
 * B5. Luật sử dụng: khớp C_i = C₀ + S × R_i (bình phương nhỏ nhất).
 * C_i: ms CPU tiến trình trong cửa sổ i; R_i: số yêu cầu hoàn tất.
 */
function fitUtilization(windows = [], { minWindows = 30, minBusyWindows = 10 } = {}) {
  const pts = windows.filter((w) => w && Number.isFinite(w.cpuMs) && Number.isFinite(w.completed));
  const n = pts.length;
  const busy = pts.filter((w) => w.completed > 0).length;
  const fail = (reason) => ({ ok: false, reason, windows: n, busyWindows: busy });
  if (n < minWindows) return fail('NOT_ENOUGH_WINDOWS');
  if (busy < minBusyWindows) return fail('NOT_ENOUGH_TRAFFIC');
  const R = pts.map((w) => w.completed);
  if (percentile(R, 0.9) < 2 * percentile(R, 0.1)) return fail('NO_SPREAD');
  const meanR = R.reduce((a, b) => a + b, 0) / n;
  const meanC = pts.reduce((a, w) => a + w.cpuMs, 0) / n;
  let sxx = 0;
  let sxy = 0;
  for (const w of pts) {
    sxx += (w.completed - meanR) ** 2;
    sxy += (w.completed - meanR) * (w.cpuMs - meanC);
  }
  if (sxx === 0) return fail('NO_SPREAD');
  const S = sxy / sxx;
  if (!(S > 0)) return fail('NON_POSITIVE_COST');
  return { ok: true, cpuMsPerRequest: S, backgroundCpuMs: meanC - S * meanR, windows: n, busyWindows: busy };
}

/** B5. X_max = (cửa sổ × min(1, Q) × U_max − C₀) / S; RPM_tối_đa = X_max quy ra mỗi phút. */
function estimateCapacity({ cpuMsPerRequest, backgroundCpuMs, quotaCores, windowMs = 10000, uMax = U_MAX }) {
  const effectiveCores = Math.min(1, Number(quotaCores) > 0 ? Number(quotaCores) : 1);
  const budgetMs = windowMs * effectiveCores * uMax;
  const maxRequestsPerWindow = Math.max(0, (budgetMs - Math.max(0, backgroundCpuMs)) / cpuMsPerRequest);
  return {
    effectiveCores,
    uMax,
    budgetMs,
    maxRequestsPerWindow,
    maxRpm: Math.floor(maxRequestsPerWindow * (60000 / windowMs)),
  };
}

/** Đánh giá: RPM_trần ≤ RPM_tối_đa → OPTIMAL; ≤ RPM_tối_đa / U_max → WARNING; còn lại OVER_CAPACITY. */
function assessCapacity(alertRpm, maxRpm, uMax = U_MAX) {
  if (maxRpm === null || maxRpm === undefined || !Number.isFinite(maxRpm)) return 'INSUFFICIENT_DATA';
  if (alertRpm <= maxRpm) return 'OPTIMAL';
  if (alertRpm <= maxRpm / uMax + 1e-9) return 'WARNING';
  return 'OVER_CAPACITY';
}

module.exports = {
  ESTIMATE_RPM_PER_USER,
  TRAFFIC_FLOOR_RPM,
  U_MAX,
  ipBurstPer10s,
  vnHourOf,
  percentile,
  median,
  rampScore,
  signalMarks,
  trafficAlertRpm,
  computeHourlyTrafficBaselines,
  fitUtilization,
  estimateCapacity,
  assessCapacity,
};
