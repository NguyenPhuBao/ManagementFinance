/**
 * AIOps Multi-Vector Anomaly Detector
 * Kết hợp 4 Vector Rủi ro chuyên biệt & Mô hình Co giãn Quy mô Người dùng (User Concurrency Scaling):
 * - Vector 1: Rủi ro Xác thực & Danh tính (Auth & Identity: Brute-force, Token Hijacking)
 * - Vector 2: Rủi ro Lưu lượng & Từ chối Dịch vụ (Traffic & Availability: Rate deviations, IP Entropy)
 * - Vector 3: Rủi ro Lỗ hổng & Injection (Exploits & Probes: SQLi, Path Traversal, XSS)
 * - Vector 4: Sức khỏe Phần cứng & Tài nguyên (System Resources: CPU, RAM, Event Loop Lag, 5xx)
 *
 * Điểm Threat Score được tổng hợp đa chiều theo nguyên lý Corroborated Vector Scaling:
 *   threatScore = max(rawMax, rawMax + corroborationBonus)
 *
 * Cơ chế Anti-Poisoning: Chỉ học dữ liệu sạch khi Threat Score < 70.
 */

class AnomalyDetector {
  constructor(options = {}) {
    this.alpha = options.alpha || 0.15; // Hệ số suy giảm EWMA
    this.targetConcurrency = Math.max(100, Number(options.targetConcurrency || 1000));
    this.hourlyBaselines = this._initializeBaselines();
  }

  _getVnHour() {
    const now = new Date();
    return (now.getUTCHours() + 7) % 24;
  }

  /**
   * Cập nhật quy mô người dùng đồng thời mục tiêu (User Concurrency Scale)
   * Tự động co giãn lại đường chuẩn lưu lượng kỳ vọng
   */
  setConcurrencyScale(scaleNumber) {
    this.targetConcurrency = Math.max(100, Number(scaleNumber || 1000));
    this.hourlyBaselines = this._initializeBaselines();
    return {
      targetConcurrency: this.targetConcurrency,
      expectedBaselineRPM: this.targetConcurrency * 10,
      peakCeilingRPM: this.targetConcurrency * 25,
    };
  }

  /**
   * Khởi tạo đường chuẩn 24 giờ dựa trên quy mô người dùng mục tiêu
   */
  _initializeBaselines() {
    const baselines = [];
    const baseRpm = this.targetConcurrency ? Math.round(this.targetConcurrency * 10) : 10000;
    for (let h = 0; h < 24; h++) {
      // Giờ thấp điểm (đêm: 0-6h: ~25% tải) vs giờ cao điểm (ngày: 7-23h: 100% tải)
      const isNight = h >= 0 && h <= 6;
      baselines.push({
        requestsPerMin: isNight ? Math.round(baseRpm * 0.25) : baseRpm,
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

  /**
   * Đánh giá rủi ro đa vector (Multi-Vector Evaluation)
   */
  evaluate(sample) {
    const hour = this._getVnHour();
    const baseline = this.hourlyBaselines[hour];
    const anomalies = [];
    const N = this.targetConcurrency;

    // ─────────────────────────────────────────────────────────────
    // VECTOR 1: RỦI RO XÁC THỰC & DANH TÍNH (AUTH & IDENTITY)
    // ─────────────────────────────────────────────────────────────
    let authScore = 0;
    // Ngưỡng phát hiện Brute-Force: tối thiểu 8 lần, hoặc 1.5% số lượng active users
    const bruteForceThreshold = Math.max(8, Math.round(N * 0.015));
    if (sample.failedLogins >= bruteForceThreshold) {
      const isSevere = sample.failedLogins >= bruteForceThreshold * 2;
      authScore = isSevere ? 80 : 70;
      anomalies.push({
        code: 'AUTH_BRUTE_FORCE',
        vector: 'auth',
        metric: 'failedLogins',
        current: sample.failedLogins,
        threshold: bruteForceThreshold,
        severity: 'HIGH',
        message: `Tần suất đăng nhập thất bại tăng vọt (${sample.failedLogins} lần/10s, ngưỡng an toàn: ${bruteForceThreshold}) — Dấu hiệu dò quét mật khẩu (Brute-Force).`,
      });
    } else if (sample.failedLogins > 0) {
      authScore = Math.min(25, Math.round((sample.failedLogins / bruteForceThreshold) * 25));
    }

    if (sample.tokenReuseAttacks >= 1) {
      const isMultiple = sample.tokenReuseAttacks >= 2;
      authScore = Math.max(authScore, isMultiple ? 85 : 75);
      anomalies.push({
        code: 'TOKEN_HIJACKING_ATTACK',
        vector: 'auth',
        metric: 'tokenReuseAttacks',
        current: sample.tokenReuseAttacks,
        severity: 'HIGH',
        message: `Phát hiện tái sử dụng Refresh Token đã bị thu hồi (${sample.tokenReuseAttacks} lần) — Dấu hiệu đánh cắp hoặc tái tạo phiên xác thực trái phép.`,
      });
    }

    // ─────────────────────────────────────────────────────────────
    // VECTOR 2: RỦI RO LƯU LƯỢNG & TỪ CHỐI DỊCH VỤ (TRAFFIC & DOS)
    // ─────────────────────────────────────────────────────────────
    let trafficScore = 0;
    const expectedRpm = Math.max(100, baseline.requestsPerMin);
    const trafficRatio = sample.requestsPerMin / expectedRpm;
    const sampleWindowRequests = Math.max(1, Math.round((sample.requestsPerMin / 60) * 10));
    const ipEntropy = sample.distinctIpsCount / sampleWindowRequests;

    if (trafficRatio >= 2.5) {
      // Phân biệt: DDoS (ít IP nguồn, tỷ lệ lỗi cao) vs Organic Traffic Peak (nhiều IP thật)
      const isDdosIndicator =
        sample.distinctIpsCount <= 3 ||
        ipEntropy < 0.05 ||
        sample.errorRate4xx >= 0.25 ||
        sample.errorRate5xx >= 0.05 ||
        sample.malformedRequests > 0;

      if (isDdosIndicator) {
        trafficScore = Math.min(100, Math.round(50 + (trafficRatio - 2.5) * 20));
        anomalies.push({
          code: 'TRAFFIC_ANOMALY_FLOOD',
          vector: 'traffic',
          metric: 'requestsPerMin',
          current: sample.requestsPerMin,
          baseline: baseline.requestsPerMin,
          severity: 'HIGH',
          message: `Lưu lượng tăng vọt bất thường (${sample.requestsPerMin} req/phút, gấp ${trafficRatio.toFixed(1)}x) với dấu hiệu phân tán IP thấp (${sample.distinctIpsCount} IPs) — Nghi vấn tấn công từ chối dịch vụ (DDoS/Scraping).`,
        });
      } else {
        // Tăng trưởng tự nhiên lành mạnh từ người dùng thật (Flash Sale / Giờ cao điểm)
        trafficScore = Math.min(25, Math.round(10 + (trafficRatio - 2.5) * 5));
      }
    } else {
      trafficScore = Math.min(15, Math.round(trafficRatio * 5));
    }

    // ─────────────────────────────────────────────────────────────
    // VECTOR 3: RỦI RO THĂM DÒ LỖ HỔNG & INJECTION (EXPLOITS & PROBES)
    // ─────────────────────────────────────────────────────────────
    let exploitScore = 0;
    if (sample.malformedRequests >= 3) {
      exploitScore = Math.min(100, Math.round(sample.malformedRequests * 12));
      anomalies.push({
        code: 'MALICIOUS_REQUEST_PROBES',
        vector: 'exploit',
        metric: 'malformedRequests',
        current: sample.malformedRequests,
        severity: 'HIGH',
        message: `Phát hiện các mẫu request độc hại chứa cú pháp SQLi/Path Traversal/XSS (${sample.malformedRequests} mẫu) từ bên ngoài.`,
      });
    } else if (sample.malformedRequests > 0) {
      exploitScore = sample.malformedRequests * 10;
    }

    // ─────────────────────────────────────────────────────────────
    // VECTOR 4: SỨC KHỎE HẠ TẦNG & TÀI NGUYÊN (SYSTEM RESOURCES)
    // ─────────────────────────────────────────────────────────────
    let lagScore = 0;
    if (sample.eventLoopLagMs >= 120) {
      const isSevereLag = sample.eventLoopLagMs >= 300;
      lagScore = isSevereLag ? 85 : 55;
      anomalies.push({
        code: 'EVENT_LOOP_FREEZE',
        vector: 'resource',
        metric: 'eventLoopLagMs',
        current: sample.eventLoopLagMs,
        severity: isSevereLag ? 'HIGH' : 'MEDIUM',
        message: `Event Loop bị trễ nghiêm trọng (${sample.eventLoopLagMs}ms lag) — Tiến trình Node.js đang bị nghẽn CPU hoặc I/O treo.`,
      });
    }

    let ramScore = 0;
    if (sample.ramPercent >= 90) {
      ramScore = 80;
      anomalies.push({
        code: 'MEMORY_EXHAUSTION',
        vector: 'resource',
        metric: 'ramPercent',
        current: sample.ramPercent,
        severity: 'HIGH',
        message: `Bộ nhớ RAM tiêu thụ đã chạm ${sample.ramPercent}% — Nguy cơ rò rỉ bộ nhớ (Memory Leak) hoặc sập tiến trình (OOM).`,
      });
    }

    let err5xxScore = 0;
    if (sample.errorRate5xx >= 0.15) {
      err5xxScore = 75;
      anomalies.push({
        code: 'SERVER_5XX_SURGE',
        vector: 'resource',
        metric: 'errorRate5xx',
        current: sample.errorRate5xx,
        severity: 'HIGH',
        message: `Tỷ lệ lỗi máy chủ 5xx tăng bất thường (${Math.round(sample.errorRate5xx * 100)}% yêu cầu) — Dấu hiệu database hoặc service phụ thuộc tê liệt.`,
      });
    }

    // Compound resource exhaustion: Nếu có từ 2 chỉ số phần cứng bị nguy hiểm cùng lúc
    const resourceIssuesCount = [lagScore >= 70, ramScore >= 70, err5xxScore >= 70].filter(Boolean).length;
    const compoundBonus = resourceIssuesCount >= 2 ? (resourceIssuesCount - 1) * 10 : 0;
    const resourceScore = Math.min(100, Math.max(lagScore, ramScore, err5xxScore) + compoundBonus);

    // ─────────────────────────────────────────────────────────────
    // TỔNG HỢP COMPOSITE THREAT SCORE THEO 4 VECTOR
    // ─────────────────────────────────────────────────────────────
    const rawMax = Math.max(authScore, trafficScore, exploitScore, resourceScore);
    const highVectorsCount = [authScore, trafficScore, exploitScore, resourceScore].filter((s) => s >= 60).length;
    const corroborationBonus = highVectorsCount >= 2 ? (highVectorsCount - 1) * 8 : 0;
    
    // Điểm nền môi trường tối thiểu là 5
    let threatScore = Math.min(100, Math.max(5, rawMax + corroborationBonus));

    // ─────────────────────────────────────────────────────────────
    // CƠ CHẾ PHÒNG THỦ CÁ NHÂN HÓA THEO TỪNG VECTƠ (PER-VECTOR DEFENSE)
    // ─────────────────────────────────────────────────────────────
    const vectorDefenses = {
      auth: {
        score: Math.round(authScore),
        status: authScore >= 70 ? 'ALERT' : authScore >= 30 ? 'ELEVATED' : 'NORMAL',
        defenseAction: authScore >= 70 ? 'QUARANTINE_IP' : 'MONITOR',
        actionLabel: authScore >= 70
          ? 'Tự động kích hoạt tường lửa Active Quarantine cô lập IP Brute-Force/Token-hijacking tại Gateway (Không ảnh hưởng khách hàng khác)'
          : 'Giám sát xác thực bình thường',
      },
      traffic: {
        score: Math.round(trafficScore),
        status: trafficScore >= 70 ? 'ALERT' : trafficScore >= 30 ? 'ELEVATED' : 'NORMAL',
        defenseAction: trafficScore >= 70 ? 'ADAPTIVE_RATE_LIMIT' : 'MONITOR',
        actionLabel: trafficScore >= 70
          ? 'Kích hoạt bộ giới hạn tần suất thích ứng (Adaptive Rate-Limit) theo trần quy mô CCU, bảo vệ băng thông'
          : 'Lưu lượng trong giới hạn an toàn',
      },
      exploit: {
        score: Math.round(exploitScore),
        status: exploitScore >= 70 ? 'ALERT' : exploitScore >= 30 ? 'ELEVATED' : 'NORMAL',
        defenseAction: exploitScore >= 70 ? 'BLOCK_INJECTION_IP' : 'MONITOR',
        actionLabel: exploitScore >= 70
          ? 'Cắt kết nối HTTP 403 tức thì và đưa nguồn IP mang injection payload vào danh sách đen 30 phút'
          : 'Không phát hiện mẫu thăm dò lỗ hổng',
      },
      resource: {
        score: Math.round(resourceScore),
        status: resourceScore >= 85 ? 'CRITICAL' : resourceScore >= 70 ? 'WARNING' : resourceScore >= 30 ? 'ELEVATED' : 'NORMAL',
        defenseAction: resourceScore >= 85 ? 'EMERGENCY_MAINTENANCE' : resourceScore >= 70 ? 'LOAD_SHEDDING' : 'MONITOR',
        actionLabel: resourceScore >= 85
          ? '🚨 Nguy cơ sập dây chuyền hạ tầng (Lag > 250ms & 5xx > 15% / OOM): Đề xuất kích hoạt Bảo trì khẩn cấp để bảo vệ CSDL'
          : resourceScore >= 70
          ? 'Tự động kích hoạt Load Shedding (hạ tải nhẹ HTTP 503 cho request không ưu tiên, bảo vệ tiến trình lõi)'
          : 'Tài nguyên phần cứng ổn định',
      },
    };

    // Xác định phân cấp trạng thái và hành động tổng thể
    // QUY TẮC CỐT LÕI: Chỉ đề xuất EMERGENCY_MAINTENANCE khi HẠ TẦNG (vector resource) sập nghiêm trọng (>= 85)
    // hoặc khi có tấn công DoS kết hợp gây lỗi máy chủ 5xx diện rộng!
    let status = 'NORMAL';
    let recommendedAction = null;

    if (resourceScore >= 85 || (resourceScore >= 70 && err5xxScore >= 70)) {
      status = 'CRITICAL';
      recommendedAction = 'EMERGENCY_MAINTENANCE';
    } else if (threatScore >= 85) {
      status = 'CRITICAL';
      recommendedAction = exploitScore >= 85 ? 'BLOCK_INJECTION_IP' : authScore >= 85 ? 'QUARANTINE_IP' : 'ADAPTIVE_RATE_LIMIT';
    } else if (threatScore >= 70) {
      status = 'WARNING';
      if (resourceScore >= 70) {
        recommendedAction = 'LOAD_SHEDDING';
      } else if (authScore >= 70 || exploitScore >= 70) {
        recommendedAction = 'ACTIVE_QUARANTINE_ENGAGED';
      } else if (trafficScore >= 70) {
        recommendedAction = 'ADAPTIVE_RATE_LIMIT';
      } else {
        recommendedAction = 'INVESTIGATE';
      }
    }

    const isAnomaly = anomalies.length > 0 || threatScore >= 70;

    // Cơ chế Anti-Poisoning: Chỉ cập nhật baseline khi hệ thống hoạt động bình thường, an toàn
    if (threatScore < 70) {
      this._updateBaseline(sample, hour);
    }

    return {
      threatScore,
      status,
      vectorScores: {
        auth: Math.round(authScore),
        traffic: Math.round(trafficScore),
        exploit: Math.round(exploitScore),
        resource: Math.round(resourceScore),
      },
      vectorDefenses,
      targetConcurrency: this.targetConcurrency,
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
