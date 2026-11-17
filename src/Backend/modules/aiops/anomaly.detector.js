/**
 * AIOps Multi-Vector Anomaly Detector
 * 4 vectơ rủi ro: Xác thực (auth), Lưu lượng (traffic), Khai thác (exploit), Tài nguyên (resource).
 *
 * Công thức (đặc tả: docs/AIOps/AIOPS_CONG_THUC.md, hàm thuần ở aiops.formulas.js):
 * - Điểm mỗi tín hiệu tăng liên tục: 0 tại A → 70 tại T → 100 tại T_nặng (điểm ≥ 70 ⇔ vượt ngưỡng cảnh báo).
 * - Điểm vectơ = max điểm tín hiệu (tài nguyên cộng 10 × (k − 1) khi k chỉ số ≥ 70).
 * - Điểm tổng = min(100, max điểm vectơ + 8 × (m − 1)), m = số vectơ ≥ 70.
 * - Đường nền lưu lượng theo giờ lấy từ snapshot lịch sử (service nạp qua setTrafficBaselines);
 *   chưa có lịch sử thì ước tính N × 2 yêu cầu/phút.
 */

const F = require('./aiops.formulas');

const SCORE_BANDS = { elevated: 40, warning: 70, critical: 85 };
const MIN_REQUESTS_FOR_5XX = 10;

class AnomalyDetector {
  constructor(options = {}) {
    this.targetConcurrency = Math.max(100, Number(options.targetConcurrency || 1000));
    this.vectorConfig = {
      auth: true,
      traffic: true,
      exploit: true,
      resource: true,
      ...(options.vectorConfig || {}),
    };
    this._historyBaselines = null; // 24 phần tử từ computeHourlyTrafficBaselines, hoặc null
    this.hourlyBaselines = this._initializeBaselines();
    this.customThresholds = {
      authFailedLogins: null,
      authFailureThreshold: null,
      trafficRatio: null,
      trafficSpikeRps: null,
      exploitSamples: null,
      exploitLimit: null,
      resourceCpu: null,
      resourceCpuPercent: null,
      resourceRam: null,
      resourceMemoryPercent: null,
      resourceLag: null,
      eventLoopLagMs: null,
      ...(options.customThresholds || {}),
    };
  }

  setCustomThresholds(thresholds) {
    if (thresholds && typeof thresholds === 'object') {
      this.customThresholds = {
        ...this.customThresholds,
        ...thresholds,
      };
    }
    return { ...this.customThresholds };
  }

  getCustomThresholds() {
    return { ...this.customThresholds };
  }

  setVectorEnabled(vectorName, isEnabled) {
    if (['auth', 'traffic', 'exploit', 'resource'].includes(vectorName)) {
      this.vectorConfig[vectorName] = Boolean(isEnabled);
    }
    return { ...this.vectorConfig };
  }

  setVectorConfig(newConfig) {
    if (newConfig && typeof newConfig === 'object') {
      for (const v of ['auth', 'traffic', 'exploit', 'resource']) {
        if (newConfig[v] !== undefined) {
          this.vectorConfig[v] = Boolean(newConfig[v]);
        }
      }
    }
    return { ...this.vectorConfig };
  }

  _getVnHour() {
    return F.vnHourOf(new Date());
  }

  /** Đường nền 24 giờ: giờ có dữ liệu lịch sử thì giữ, giờ còn lại ước tính theo N. */
  _initializeBaselines() {
    const estimate = F.computeHourlyTrafficBaselines([], { targetConcurrency: this.targetConcurrency });
    const hist = this._historyBaselines;
    return estimate.map((est, h) => {
      const fromHistory = hist && hist[h] && hist[h].source !== 'estimate' ? hist[h] : est;
      return {
        requestsPerMin: fromHistory.baselineRpm,
        p95Rpm: fromHistory.p95Rpm,
        source: fromHistory.source,
        samples: fromHistory.samples,
      };
    });
  }

  /** Nạp đường nền tính từ snapshot (B1). */
  setTrafficBaselines(hours) {
    if (Array.isArray(hours) && hours.length === 24) {
      this._historyBaselines = hours;
      this.hourlyBaselines = this._initializeBaselines();
    }
    return this.hourlyBaselines;
  }

  /** Cập nhật quy mô N: chỉ ảnh hưởng các giờ chưa có lịch sử (ước tính N × 2). */
  setConcurrencyScale(scaleNumber) {
    this.targetConcurrency = Math.max(100, Number(scaleNumber || 1000));
    this.hourlyBaselines = this._initializeBaselines();
    return {
      targetConcurrency: this.targetConcurrency,
      indicators: this.getEffectiveThresholds(),
    };
  }

  getBaselineMetric(metric, hour = null) {
    const h = hour !== null ? hour : this._getVnHour();
    return this.hourlyBaselines[h]?.[metric] ?? 0;
  }

  _customMarks() {
    const c = this.customThresholds;
    return F.signalMarks({
      failedLogins: c.authFailureThreshold ?? c.authFailedLogins,
      malformed: c.exploitLimit ?? c.exploitSamples,
      lagMs: c.eventLoopLagMs ?? c.resourceLag,
      cpuPercent: c.resourceCpuPercent ?? c.resourceCpu,
      ramPercent: c.resourceMemoryPercent ?? c.resourceRam,
    });
  }

  _trafficMarks(hour) {
    const b = this.hourlyBaselines[hour] || {};
    const baselineRpm = Number(b.requestsPerMin) || 0;
    const c = this.customThresholds;
    let alertRpm = F.trafficAlertRpm(baselineRpm, b.p95Rpm);
    if (Number(c.trafficSpikeRps) > 0) {
      alertRpm = Math.round(Number(c.trafficSpikeRps) * 60);
    } else if (Number(c.trafficRatio) > 0) {
      alertRpm = Math.round(Number(c.trafficRatio) * baselineRpm);
    }
    return {
      baselineRpm,
      p95Rpm: b.p95Rpm ?? null,
      source: b.source || 'estimate',
      samples: b.samples || 0,
      // A = max(1,5 × nền, 0,5 × T): sàn tránh A ≈ 0 khi lịch sử toàn mẫu rỗi (nền ≈ 0)
      attentionRpm: Math.round(Math.max(1.5 * baselineRpm, 0.5 * alertRpm)),
      alertRpm,
      severeRpm: 2 * alertRpm,
    };
  }

  /** Mọi ngưỡng đang hiệu lực — đúng các con số evaluate() dùng (A1). */
  getEffectiveThresholds(hour = null) {
    const h = hour !== null ? hour : this._getVnHour();
    const m = this._customMarks();
    return {
      targetConcurrency: this.targetConcurrency,
      traffic: this._trafficMarks(h),
      auth: { failedLogins: m.failedLogins, tokenReuse: m.tokenReuse },
      exploit: { malformed: m.malformed },
      resource: {
        lagMs: m.lagMs,
        cpuPercent: m.cpuPercent,
        ramPercent: m.ramPercent,
        error5xxRate: m.error5xxRate,
        minRequestsFor5xx: MIN_REQUESTS_FOR_5XX,
      },
      ipBurstPer10s: F.ipBurstPer10s(),
      scoreBands: { ...SCORE_BANDS },
    };
  }

  /**
   * Đánh giá rủi ro đa vector (Multi-Vector Evaluation)
   */
  evaluate(sample) {
    const hour = this._getVnHour();
    const ind = this.getEffectiveThresholds(hour);
    const anomalies = [];

    // Số yêu cầu thật trong cửa sổ; mẫu cũ không có thì suy từ RPM (10 giây).
    const windowRequests = Number.isFinite(sample.requestCount)
      ? sample.requestCount
      : Math.max(0, Math.round(((sample.requestsPerMin || 0) / 60) * 10));

    // ─────────────────────────────────────────────────────────────
    // VECTOR 1: RỦI RO XÁC THỰC & DANH TÍNH (AUTH & IDENTITY)
    // ─────────────────────────────────────────────────────────────
    const suspects = sample.suspectActors || [];
    const systemActor = {
      type: 'SYSTEM_INTERNAL',
      identity: 'Hạ tầng máy chủ (Node.js & Database)',
      maskedIp: 'Hệ thống nội bộ (Loopback)',
      rawIp: '127.0.0.1',
      ipHash: 'system_core',
      userId: null,
      username: 'System Core Engine',
      role: 'System',
      userAgent: `Node.js runtime / PostgreSQL Pooler`,
      targetEndpoint: 'Background Event Loop & Connection Pool',
    };

    const failedMarks = ind.auth.failedLogins;
    const failedScore = F.rampScore(sample.failedLogins, failedMarks);
    const tokenMarks = ind.auth.tokenReuse;
    const tokenScore = F.rampScore(sample.tokenReuseAttacks, tokenMarks);
    const authScore = Math.max(failedScore, tokenScore);

    if (this.vectorConfig.auth && sample.failedLogins >= failedMarks.alert) {
      const authActor = suspects.find((s) => s.failedLogins > 0) || sample.topAuthActor || {
        type: 'IP_SOURCE',
        identity: '192.168.xxx.xxx',
        maskedIp: '192.168.xxx.xxx',
        rawIp: '192.168.1.105',
        ipHash: 'auth_multi_ip',
        userId: null,
        username: 'Khách vãng lai / Ẩn danh',
        role: 'Guest',
        userAgent: 'Automated Script / Botnet',
        targetEndpoint: '/api/auth/login',
      };
      anomalies.push({
        code: 'AUTH_BRUTE_FORCE',
        vector: 'auth',
        metric: 'failedLogins',
        current: sample.failedLogins,
        threshold: failedMarks.alert,
        baseline: 0,
        unit: 'lần thất bại/10s',
        severity: 'HIGH',
        actor: authActor,
        message: `Tần suất đăng nhập thất bại tăng vọt (${sample.failedLogins} lần/10s, ngưỡng an toàn: ${failedMarks.alert}) — Dấu hiệu dò quét mật khẩu (Brute-Force).`,
        rootCauseDiagnosis: `Phát hiện ${sample.failedLogins} lần đăng nhập sai dồn dập từ nguồn ${authActor.identity} sử dụng ${authActor.userAgent}.`,
        mitigationTaken: 'Hệ thống kích hoạt Rate Limiter và đưa IP vào Khiên Chắn Active Quarantine nếu vượt ngưỡng vi phạm.',
      });
    }

    // Tái sử dụng Refresh Token: 1-4 lần thường do nhiều tab / retry mạng; báo động từ 5 lần
    if (this.vectorConfig.auth && sample.tokenReuseAttacks >= tokenMarks.alert) {
      const tokenActor = suspects.find((s) => s.tokenReuse > 0) || {
        type: 'AUTHENTICATED_USER',
        identity: '192.168.xxx.xxx',
        maskedIp: '192.168.xxx.xxx',
        rawIp: '192.168.1.108',
        ipHash: 'token_reuse_hash',
        userId: null,
        username: 'Phiên làm việc bị thu hồi',
        role: 'User',
        userAgent: 'Web / Mobile Client',
        targetEndpoint: '/api/auth/refresh',
      };
      anomalies.push({
        code: 'TOKEN_HIJACKING_ATTACK',
        vector: 'auth',
        metric: 'tokenReuseAttacks',
        current: sample.tokenReuseAttacks,
        threshold: tokenMarks.alert,
        baseline: 0,
        unit: 'lần vi phạm',
        severity: 'HIGH',
        actor: tokenActor,
        message: `Phát hiện tái sử dụng Refresh Token đã bị thu hồi liên tục (${sample.tokenReuseAttacks} lần) — Dấu hiệu đánh cắp hoặc tái tạo phiên xác thực trái phép.`,
        rootCauseDiagnosis: `Token đã bị thu hồi nhưng vẫn tiếp tục được gửi lên từ nguồn ${tokenActor.identity}.`,
        mitigationTaken: 'Đã ngay lập tức thu hồi toàn bộ Token Family của tài khoản và ngắt phiên đăng nhập.',
      });
    }

    // ─────────────────────────────────────────────────────────────
    // VECTOR 2: RỦI RO LƯU LƯỢNG & TỪ CHỐI DỊCH VỤ (TRAFFIC & DOS)
    // ─────────────────────────────────────────────────────────────
    const tm = ind.traffic;
    const rawTrafficScore = F.rampScore(sample.requestsPerMin, {
      attention: tm.attentionRpm,
      alert: tm.alertRpm,
      severe: tm.severeRpm,
    });
    // B4: lưu lượng dồn từ ít nguồn (IP lớn nhất ≥ 50%), nhiều 4xx, hoặc có mẫu độc hại
    const topShare = sample.topTrafficActor && windowRequests > 0
      ? (sample.topTrafficActor.reqCount || 0) / windowRequests
      : 0;
    const isAttackIndicator =
      topShare >= 0.5 ||
      (sample.errorRate4xx || 0) >= 0.25 ||
      (sample.malformedRequests || 0) > 0;
    const trafficScore = isAttackIndicator ? rawTrafficScore : Math.min(40, rawTrafficScore);

    if (this.vectorConfig.traffic && isAttackIndicator && sample.requestsPerMin >= tm.alertRpm) {
      const trafficRatio = tm.baselineRpm > 0 ? sample.requestsPerMin / tm.baselineRpm : 0;
      const trafficActor = suspects.find((s) => s.reqCount >= 50) || sample.topTrafficActor || {
        type: 'IP_SOURCE',
        identity: '192.168.xxx.xxx',
        maskedIp: '192.168.xxx.xxx',
        rawIp: '192.168.1.1',
        ipHash: 'traffic_flood_hash',
        userId: null,
        username: 'Khách vãng lai / Ẩn danh',
        role: 'Guest',
        userAgent: 'DDoS Cluster / HTTP Flooder',
        targetEndpoint: '/api/*',
      };
      anomalies.push({
        code: 'TRAFFIC_ANOMALY_FLOOD',
        vector: 'traffic',
        metric: 'requestsPerMin',
        current: sample.requestsPerMin,
        baseline: tm.baselineRpm,
        threshold: tm.alertRpm,
        unit: 'req/phút',
        severity: 'HIGH',
        actor: trafficActor,
        message: `Lưu lượng tăng vọt bất thường (${sample.requestsPerMin} req/phút, gấp ${trafficRatio.toFixed(1)}x đường nền, ngưỡng: ${tm.alertRpm}) với dấu hiệu tấn công (${sample.distinctIpsCount} IPs) — Nghi vấn tấn công từ chối dịch vụ (DDoS/Scraping).`,
        rootCauseDiagnosis: `Lưu lượng tăng vọt gấp ${trafficRatio.toFixed(1)}x đường chuẩn trung vị (${sample.requestsPerMin} vs ${tm.baselineRpm} RPM).`,
        mitigationTaken: 'Hệ thống đã kích hoạt Token-Bucket Rate Limiter và Load Shedding cắt tải các request vượt ngưỡng.',
      });
    }

    // ─────────────────────────────────────────────────────────────
    // VECTOR 3: RỦI RO THĂM DÒ LỖ HỔNG & INJECTION (EXPLOITS & PROBES)
    // ─────────────────────────────────────────────────────────────
    const exploitMarks = ind.exploit.malformed;
    const exploitScore = F.rampScore(sample.malformedRequests, exploitMarks);

    if (this.vectorConfig.exploit && sample.malformedRequests >= exploitMarks.alert) {
      const exploitActor = suspects.find((s) => s.malformed > 0) || sample.topExploitActor || {
        type: 'IP_SOURCE',
        identity: '192.168.xxx.xxx',
        maskedIp: '192.168.xxx.xxx',
        rawIp: '192.168.1.112',
        ipHash: 'exploit_probe_hash',
        userId: null,
        username: 'Khách vãng lai / Ẩn danh',
        role: 'Guest',
        userAgent: 'Scanner / Vulnerability Probe (sqlmap/curl)',
        targetEndpoint: 'Injection URL Probes',
      };
      anomalies.push({
        code: 'MALICIOUS_REQUEST_PROBES',
        vector: 'exploit',
        metric: 'malformedRequests',
        current: sample.malformedRequests,
        threshold: exploitMarks.alert,
        baseline: 0,
        unit: 'mẫu độc hại',
        severity: 'HIGH',
        actor: exploitActor,
        message: `Phát hiện các mẫu request độc hại chứa cú pháp SQLi/Path Traversal/XSS (${sample.malformedRequests} mẫu, ngưỡng: ${exploitMarks.alert}) từ bên ngoài.`,
        rootCauseDiagnosis: `Phát hiện ${sample.malformedRequests} request mang payload nguy hiểm (../, ..%2f, UNION SELECT, <script>) từ nguồn ${exploitActor.identity}.`,
        mitigationTaken: 'Đã tự động ngắt kết nối và cô lập IP độc hại vào Khiên Chắn Active Quarantine 30 phút.',
      });
    }

    // ─────────────────────────────────────────────────────────────
    // VECTOR 4: SỨC KHỎE HẠ TẦNG & TÀI NGUYÊN (SYSTEM RESOURCES)
    // ─────────────────────────────────────────────────────────────
    const r = ind.resource;
    const lagScore = sample.warmingUp ? 0 : F.rampScore(sample.eventLoopLagMs, r.lagMs);
    if (lagScore >= 70 && this.vectorConfig.resource) {
      anomalies.push({
        code: 'EVENT_LOOP_FREEZE',
        vector: 'resource',
        metric: 'eventLoopLagMs',
        current: sample.eventLoopLagMs,
        threshold: r.lagMs.alert,
        baseline: 15,
        unit: 'ms lag',
        severity: lagScore >= 85 ? 'HIGH' : 'MEDIUM',
        actor: systemActor,
        message: `Event Loop bị trễ nghiêm trọng (p99 ${sample.eventLoopLagMs}ms, ngưỡng: ${r.lagMs.alert}ms) — Tiến trình Node.js đang bị nghẽn CPU hoặc I/O treo.`,
        rootCauseDiagnosis: `Độ trễ vòng lặp sự kiện (p99 trong cửa sổ) đạt ${sample.eventLoopLagMs}ms (ngưỡng an toàn < ${r.lagMs.alert}ms). Tiến trình đang chịu tải tính toán nặng hoặc I/O bị chặn.`,
        mitigationTaken: 'Load Shedding kích hoạt: Tự động trả HTTP 503 cho request khách vãng lai để giải tỏa CPU máy chủ.',
      });
    }

    const ramScore = F.rampScore(sample.ramPercent, r.ramPercent);
    if (ramScore >= 70 && this.vectorConfig.resource) {
      anomalies.push({
        code: 'MEMORY_EXHAUSTION',
        vector: 'resource',
        metric: 'ramPercent',
        current: sample.ramPercent,
        threshold: r.ramPercent.alert,
        baseline: 50,
        unit: '% RAM',
        severity: 'HIGH',
        actor: systemActor,
        message: `Bộ nhớ tiến trình đã chạm ${sample.ramPercent}% hạn mức (ngưỡng an toàn: ${r.ramPercent.alert}%) — Nguy cơ rò rỉ bộ nhớ (Memory Leak) hoặc sập tiến trình (OOM).`,
        rootCauseDiagnosis: `Bộ nhớ tiến trình đã vượt ngưỡng nguy hiểm (${sample.ramPercent}% >= ${r.ramPercent.alert}%). Cần giám sát rò rỉ bộ nhớ hoặc scale up tài nguyên.`,
        mitigationTaken: 'Cảnh báo tài nguyên hệ thống phát ra tới Quản trị viên để chuẩn bị mở rộng hạ tầng.',
      });
    }

    const cpuScore = F.rampScore(sample.cpuPercent, r.cpuPercent);
    if (cpuScore >= 70 && this.vectorConfig.resource) {
      anomalies.push({
        code: 'CPU_OVERLOAD_SURGE',
        vector: 'resource',
        metric: 'cpuPercent',
        current: sample.cpuPercent,
        threshold: r.cpuPercent.alert,
        baseline: 30,
        unit: '% CPU',
        severity: 'HIGH',
        actor: systemActor,
        message: `CPU máy chủ tiêu thụ chạm ${sample.cpuPercent}% (ngưỡng an toàn: ${r.cpuPercent.alert}%) — Nguy cơ nghẽn tải tính toán hệ thống.`,
        rootCauseDiagnosis: `CPU tiêu thụ chạm ${sample.cpuPercent}%, vượt ngưỡng an toàn ${r.cpuPercent.alert}%.`,
        mitigationTaken: 'Load Shedding kích hoạt: Giảm tải các tác vụ nền định kỳ.',
      });
    }

    const err5xxScore = windowRequests >= MIN_REQUESTS_FOR_5XX ? F.rampScore(sample.errorRate5xx, r.error5xxRate) : 0;
    if (err5xxScore >= 70 && this.vectorConfig.resource) {
      anomalies.push({
        code: 'SERVER_5XX_SURGE',
        vector: 'resource',
        metric: 'errorRate5xx',
        current: sample.errorRate5xx,
        threshold: r.error5xxRate.alert,
        baseline: 0.01,
        unit: '% lỗi',
        severity: 'HIGH',
        actor: systemActor,
        message: `Tỷ lệ lỗi máy chủ 5xx tăng bất thường (${Math.round(sample.errorRate5xx * 100)}% yêu cầu, ngưỡng: ${Math.round(r.error5xxRate.alert * 100)}%) — Dấu hiệu database hoặc service phụ thuộc tê liệt.`,
        rootCauseDiagnosis: `Tỷ lệ lỗi HTTP 5xx đạt ${Math.round(sample.errorRate5xx * 100)}% trên tổng ${windowRequests} requests.`,
        mitigationTaken: 'DB Bulkhead tự động bảo lưu 20% kết nối cho luồng Quản trị viên (Fast-Lane) để cứu hộ.',
      });
    }

    // Nhiều chỉ số tài nguyên cùng vượt ngưỡng: cộng 10 × (k − 1)
    const resourceIssuesCount = [lagScore, ramScore, cpuScore, err5xxScore].filter((s) => s >= 70).length;
    const compoundBonus = resourceIssuesCount >= 2 ? (resourceIssuesCount - 1) * 10 : 0;
    const resourceScore = Math.min(100, Math.max(lagScore, ramScore, cpuScore, err5xxScore) + compoundBonus);

    // ─────────────────────────────────────────────────────────────
    // TỔNG HỢP COMPOSITE THREAT SCORE THEO 4 VECTOR (Áp dụng Vector Config)
    // ─────────────────────────────────────────────────────────────
    const activeScores = [];
    if (this.vectorConfig.auth) activeScores.push(authScore);
    if (this.vectorConfig.traffic) activeScores.push(trafficScore);
    if (this.vectorConfig.exploit) activeScores.push(exploitScore);
    if (this.vectorConfig.resource) activeScores.push(resourceScore);

    const rawMax = activeScores.length > 0 ? Math.max(...activeScores) : 0;
    const highVectorsCount = activeScores.filter((s) => s >= SCORE_BANDS.warning).length;
    const corroborationBonus = highVectorsCount >= 2 ? (highVectorsCount - 1) * 8 : 0;

    const threatScore = Math.min(100, Math.max(0, Math.round(rawMax + corroborationBonus)));

    // ─────────────────────────────────────────────────────────────
    // CƠ CHẾ PHÒNG THỦ CÁ NHÂN HÓA THEO TỪNG VECTƠ (PER-VECTOR DEFENSE)
    // ─────────────────────────────────────────────────────────────
    const vectorDefenses = {
      auth: {
        score: Math.round(authScore),
        disabled: !this.vectorConfig.auth,
        status: !this.vectorConfig.auth ? 'NORMAL' : authScore >= 70 ? 'ALERT' : authScore >= 40 ? 'ELEVATED' : 'NORMAL',
        defenseAction: !this.vectorConfig.auth ? 'MONITOR' : authScore >= 70 ? 'QUARANTINE_IP' : 'MONITOR',
        actionLabel: !this.vectorConfig.auth
          ? 'Vectơ Xác thực đã bị tắt khỏi tính toán rủi ro (Chế độ giám sát thụ động)'
          : authScore >= 70
            ? 'Tự động kích hoạt tường lửa Active Quarantine cô lập IP Brute-Force/Token-hijacking tại Gateway (Không ảnh hưởng khách hàng khác)'
            : 'Giám sát xác thực bình thường',
      },
      traffic: {
        score: Math.round(trafficScore),
        disabled: !this.vectorConfig.traffic,
        status: !this.vectorConfig.traffic ? 'NORMAL' : trafficScore >= 70 ? 'ALERT' : trafficScore >= 40 ? 'ELEVATED' : 'NORMAL',
        defenseAction: !this.vectorConfig.traffic ? 'MONITOR' : trafficScore >= 70 ? 'ADAPTIVE_RATE_LIMIT' : 'MONITOR',
        actionLabel: !this.vectorConfig.traffic
          ? 'Vectơ Lưu lượng đã bị tắt khỏi tính toán rủi ro (Chế độ giám sát thụ động)'
          : trafficScore >= 70
            ? 'Kích hoạt bộ giới hạn tần suất thích ứng (Adaptive Rate-Limit) theo trần quy mô CCU, bảo vệ băng thông'
            : 'Lưu lượng trong giới hạn an toàn',
      },
      exploit: {
        score: Math.round(exploitScore),
        disabled: !this.vectorConfig.exploit,
        status: !this.vectorConfig.exploit ? 'NORMAL' : exploitScore >= 70 ? 'ALERT' : exploitScore >= 40 ? 'ELEVATED' : 'NORMAL',
        defenseAction: !this.vectorConfig.exploit ? 'MONITOR' : exploitScore >= 70 ? 'BLOCK_INJECTION_IP' : 'MONITOR',
        actionLabel: !this.vectorConfig.exploit
          ? 'Vectơ Khai thác đã bị tắt khỏi tính toán rủi ro (Chế độ giám sát thụ động)'
          : exploitScore >= 70
            ? 'Cắt kết nối HTTP 403 tức thì và đưa nguồn IP mang injection payload vào danh sách đen 30 phút'
            : 'Không phát hiện mẫu thăm dò lỗ hổng',
      },
      resource: {
        score: Math.round(resourceScore),
        disabled: !this.vectorConfig.resource,
        status: !this.vectorConfig.resource ? 'NORMAL' : resourceScore >= 85 ? 'CRITICAL' : resourceScore >= 70 ? 'WARNING' : resourceScore >= 40 ? 'ELEVATED' : 'NORMAL',
        defenseAction: !this.vectorConfig.resource ? 'MONITOR' : resourceScore >= 85 ? 'EMERGENCY_MAINTENANCE' : resourceScore >= 70 ? 'LOAD_SHEDDING' : 'MONITOR',
        actionLabel: !this.vectorConfig.resource
          ? 'Vectơ Tài nguyên đã bị tắt khỏi tính toán rủi ro (Chế độ giám sát thụ động)'
          : resourceScore >= 85
            ? '🚨 Nguy cơ sập dây chuyền hạ tầng (độ trễ, lỗi 5xx hoặc bộ nhớ vượt ngưỡng đồng thời): Đề xuất kích hoạt Bảo trì khẩn cấp để bảo vệ CSDL'
            : resourceScore >= 70
              ? 'Tự động kích hoạt Load Shedding (hạ tải nhẹ HTTP 503 cho request không ưu tiên, bảo vệ tiến trình lõi)'
              : 'Tài nguyên phần cứng ổn định',
      },
    };

    // QUY TẮC CỐT LÕI: Chỉ đề xuất EMERGENCY_MAINTENANCE khi HẠ TẦNG sập nghiêm trọng đa chỉ số VÀ Vector Resource đang BẬT
    const severeResourceCrisis = Boolean(this.vectorConfig.resource) && resourceScore >= 85 && (
      (lagScore >= 70 && err5xxScore >= 70) ||
      (lagScore >= 70 && ramScore >= 70) ||
      (ramScore >= 70 && err5xxScore >= 70)
    );

    let status = 'NORMAL';
    let recommendedAction = null;

    if (severeResourceCrisis) {
      status = 'CRITICAL';
      recommendedAction = 'EMERGENCY_MAINTENANCE';
    } else if (threatScore >= 85) {
      status = 'CRITICAL';
      if (this.vectorConfig.exploit && exploitScore >= 85) {
        recommendedAction = 'BLOCK_INJECTION_IP';
      } else if (this.vectorConfig.auth && authScore >= 85) {
        recommendedAction = 'QUARANTINE_IP';
      } else if (this.vectorConfig.traffic && trafficScore >= 85) {
        recommendedAction = 'ADAPTIVE_RATE_LIMIT';
      } else {
        recommendedAction = 'INVESTIGATE';
      }
    } else if (threatScore >= 70) {
      status = 'WARNING';
      if (this.vectorConfig.resource && resourceScore >= 70) {
        recommendedAction = 'LOAD_SHEDDING';
      } else if ((this.vectorConfig.auth && authScore >= 70) || (this.vectorConfig.exploit && exploitScore >= 70)) {
        recommendedAction = 'ACTIVE_QUARANTINE_ENGAGED';
      } else if (this.vectorConfig.traffic && trafficScore >= 70) {
        recommendedAction = 'ADAPTIVE_RATE_LIMIT';
      } else {
        recommendedAction = 'INVESTIGATE';
      }
    } else if (threatScore >= 40) {
      status = 'ELEVATED';
      recommendedAction = 'MONITOR';
    }

    const isAnomaly = anomalies.length > 0 || threatScore >= 70;

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
      vectorConfig: { ...this.vectorConfig },
      customThresholds: this.getCustomThresholds(),
      indicators: ind,
      targetConcurrency: this.targetConcurrency,
      isAnomaly,
      anomalies,
      recommendedAction,
      evaluatedAt: new Date().toISOString(),
    };
  }

  /**
   * Hiệu chuẩn: đặt quy mô N (nếu có) và ngưỡng tuỳ chỉnh. Không xoá đường nền đã nạp từ lịch sử.
   * Báo cáo năng lực do AIOpsService dựng (Luật sử dụng, B5).
   */
  calibrate(options = {}) {
    if (options.targetConcurrency) {
      this.setConcurrencyScale(options.targetConcurrency);
    }
    if (options.customThresholds && typeof options.customThresholds === 'object') {
      this.setCustomThresholds(options.customThresholds);
    }
    return this.getEffectiveThresholds();
  }
}

const defaultAnomalyDetector = new AnomalyDetector();

module.exports = {
  AnomalyDetector,
  defaultAnomalyDetector,
};
