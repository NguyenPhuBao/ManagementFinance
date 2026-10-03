/**
 * AIOps Hybrid Anomaly Detector
 * Kết hợp 2 tầng máy học trực tuyến (Online Learning):
 * - Tier 1: EWMA Dynamic Baseline theo 24 giờ múi giờ Việt Nam GMT+7.
 * - Tier 2: Multivariate Correlation Threat Scorer (Phân biệt Organic Spike vs DDoS/Brute-Force/Memory Leak).
 * Cơ chế Anti-Poisoning: Chỉ học dữ liệu sạch khi Threat Score < 70.
 */
class AnomalyDetector {
  constructor(options = {}) {
    this.alpha = options.alpha || 0.15; // Hệ số suy giảm EWMA
    this.hourlyBaselines = this._initializeBaselines();
  }

  _getVnHour() {
    const now = new Date();
    return (now.getUTCHours() + 7) % 24;
  }

  _initializeBaselines() {
    const baselines = [];
    for (let h = 0; h < 24; h++) {
      // Giờ thấp điểm (đêm: 0-6h) vs giờ cao điểm (ngày: 7-23h)
      const isNight = h >= 0 && h <= 6;
      baselines.push({
        requestsPerMin: isNight ? 30 : 120,
        errorRate4xx: 0.02,
        errorRate5xx: 0.00,
        eventLoopLagMs: 5,
        cpuPercent: isNight ? 10 : 25,
        ramPercent: 45,
      });
    }
    return baselines;
  }

  getBaselineMetric(metric, hour = null) {
    const h = hour !== null ? hour : this._getVnHour();
    return this.hourlyBaselines[h]?.[metric] ?? 0;
  }

  _updateBaseline(sample, hour) {
    const b = this.hourlyBaselines[hour];
    if (!b) return;

    const ewma = (current, previous) => {
      return Number((this.alpha * current + (1 - this.alpha) * previous).toFixed(2));
    };

    b.requestsPerMin = Math.round(ewma(sample.requestsPerMin, b.requestsPerMin));
    b.errorRate4xx = ewma(sample.errorRate4xx, b.errorRate4xx);
    b.errorRate5xx = ewma(sample.errorRate5xx, b.errorRate5xx);
    b.eventLoopLagMs = Math.round(ewma(sample.eventLoopLagMs, b.eventLoopLagMs));
    b.cpuPercent = Math.round(ewma(sample.cpuPercent, b.cpuPercent));
    b.ramPercent = Math.round(ewma(sample.ramPercent, b.ramPercent));
  }

  evaluate(sample) {
    const hour = this._getVnHour();
    const baseline = this.hourlyBaselines[hour];
    const anomalies = [];
    let threatScore = 5; // Base ambient background score

    // 1. Phân tích tấn công dò mật khẩu (Brute-Force Authentication)
    if (sample.failedLogins >= 5) {
      const isSevere = sample.failedLogins >= 10;
      threatScore += isSevere ? 70 : 45;
      anomalies.push({
        code: 'AUTH_BRUTE_FORCE',
        metric: 'failedLogins',
        current: sample.failedLogins,
        baseline: 0,
        severity: 'HIGH',
        message: `Phát hiện tần suất đăng nhập thất bại tăng vọt (${sample.failedLogins} lần/10s) — Dấu hiệu dò vét mật khẩu (Brute-Force).`,
      });
    }

    // 2. Phân tích tấn công chiếm đoạt Token (Token Hijacking / Replay Attack)
    if (sample.tokenReuseAttacks >= 1) {
      const isMultiple = sample.tokenReuseAttacks >= 2;
      threatScore += isMultiple ? 75 : 65;
      anomalies.push({
        code: 'TOKEN_HIJACKING_ATTACK',
        metric: 'tokenReuseAttacks',
        current: sample.tokenReuseAttacks,
        baseline: 0,
        severity: 'HIGH',
        message: `Phát hiện tái sử dụng Refresh Token đã bị thu hồi (${sample.tokenReuseAttacks} lần) — Dấu hiệu đánh cắp hoặc tái tạo phiên xác thực trái phép.`,
      });
    }

    // 3. Phân tích tấn công rà quét mã độc & Injection
    if (sample.malformedRequests >= 3) {
      threatScore += 35;
      anomalies.push({
        code: 'MALICIOUS_REQUEST_PROBES',
        metric: 'malformedRequests',
        current: sample.malformedRequests,
        baseline: 0,
        severity: 'HIGH',
        message: `Phát hiện các mẫu request độc hại chứa cú pháp SQLi/Path Traversal (${sample.malformedRequests} mẫu) từ bên ngoài.`,
      });
    }

    // 4. Phân loại lưu lượng đột biến: Organic Peak (Người dùng thật) vs DDoS Flood (Tấn công)
    const trafficRatio = sample.requestsPerMin / Math.max(1, baseline.requestsPerMin);
    if (trafficRatio >= 2.5) {
      // Điều kiện phân biệt:
      // - DDoS: ít IP nguồn, tỷ lệ 4xx/5xx tăng cao, hoặc kèm request độc hại
      const isDdosIndicator =
        sample.distinctIpsCount <= 3 ||
        sample.errorRate4xx >= 0.25 ||
        sample.errorRate5xx >= 0.05 ||
        sample.malformedRequests > 0;

      if (isDdosIndicator) {
        threatScore += 45;
        anomalies.push({
          code: 'TRAFFIC_ANOMALY_FLOOD',
          metric: 'requestsPerMin',
          current: sample.requestsPerMin,
          baseline: baseline.requestsPerMin,
          severity: 'HIGH',
          message: `Lưu lượng truy cập tăng vọt bất thường (${sample.requestsPerMin} req/phút) với dấu hiệu phân tán IP thấp hoặc tỷ lệ phản hồi lỗi cao — Nghi vấn tấn công từ chối dịch vụ (DDoS/Scraping).`,
        });
      } else {
        // Tăng trưởng tự nhiên lành mạnh (Organic Traffic Burst)
        threatScore += 10;
      }
    }

    // 5. Phân tích sức khỏe tiến trình & Cạn kiệt tài nguyên (Event Loop & Memory Leak)
    if (sample.eventLoopLagMs >= 120) {
      threatScore += sample.eventLoopLagMs >= 300 ? 40 : 25;
      anomalies.push({
        code: 'EVENT_LOOP_FREEZE',
        metric: 'eventLoopLagMs',
        current: sample.eventLoopLagMs,
        baseline: baseline.eventLoopLagMs,
        severity: sample.eventLoopLagMs >= 300 ? 'HIGH' : 'MEDIUM',
        message: `Event Loop bị trễ nghiêm trọng (${sample.eventLoopLagMs}ms lag) — Khả năng tiến trình Node.js đang bị chặn bởi tính toán nặng hoặc I/O treo.`,
      });
    }

    if (sample.ramPercent >= 90) {
      threatScore += 35;
      anomalies.push({
        code: 'MEMORY_EXHAUSTION',
        metric: 'ramPercent',
        current: sample.ramPercent,
        baseline: baseline.ramPercent,
        severity: 'HIGH',
        message: `Bộ nhớ RAM tiêu thụ đã chạm ${sample.ramPercent}% — Nguy cơ rò rỉ bộ nhớ (Memory Leak) hoặc sắp sập tiến trình (OOM).`,
      });
    }

    if (sample.errorRate5xx >= 0.15) {
      threatScore += 30;
      anomalies.push({
        code: 'SERVER_5XX_SURGE',
        metric: 'errorRate5xx',
        current: sample.errorRate5xx,
        baseline: baseline.errorRate5xx,
        severity: 'HIGH',
        message: `Tỷ lệ lỗi máy chủ 5xx tăng bất thường (${Math.round(sample.errorRate5xx * 100)}% yêu cầu) — Dấu hiệu database hoặc service phụ thuộc tê liệt.`,
      });
    }

    // Giới hạn Threat Score trong thang điểm 0 - 100
    threatScore = Math.min(100, Math.max(0, threatScore));

    // Xác định phân cấp trạng thái và hành động khuyến nghị
    let status = 'NORMAL';
    let recommendedAction = null;

    if (threatScore >= 85) {
      status = 'CRITICAL';
      recommendedAction = 'EMERGENCY_MAINTENANCE';
    } else if (threatScore >= 70) {
      status = 'WARNING';
      recommendedAction = 'INVESTIGATE';
    }

    const isAnomaly = anomalies.length > 0 || threatScore >= 70;

    // Cơ chế Anti-Poisoning: Chỉ cập nhật baseline khi hệ thống hoạt động bình thường, an toàn
    if (threatScore < 70) {
      this._updateBaseline(sample, hour);
    }

    return {
      threatScore,
      status,
      isAnomaly,
      anomalies,
      recommendedAction,
      evaluatedAt: new Date().toISOString(),
    };
  }

  calibrate(customBaselines = {}) {
    const hour = this._getVnHour();
    if (this.hourlyBaselines[hour]) {
      Object.assign(this.hourlyBaselines[hour], customBaselines);
    }
  }
}

const defaultAnomalyDetector = new AnomalyDetector();

module.exports = {
  AnomalyDetector,
  defaultAnomalyDetector,
};
