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

const os = require('os');

class AnomalyDetector {
  constructor(options = {}) {
    this.alpha = options.alpha || 0.15; // Hệ số suy giảm EWMA
    this.targetConcurrency = Math.max(100, Number(options.targetConcurrency || 1000));
    this.vectorConfig = {
      auth: true,
      traffic: true,
      exploit: true,
      resource: true,
      ...(options.vectorConfig || {}),
    };
    this.hourlyBaselines = this._initializeBaselines();
    this.customThresholds = {
      authFailedLogins: null,
      trafficRatio: null,
      exploitSamples: null,
      resourceCpu: null,
      resourceRam: null,
      resourceLag: null,
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
   * Tính toán các thông số đường chuẩn thực tế (Real-Server Hardware Baselines)
   * dựa trên số nhân CPU thật, tổng RAM vật lý của server, và quy mô người dùng N.
   */
  calculateServerHardwareBaseline(targetConcurrency = null, currentSample = null) {
    const N = Math.max(100, Number(targetConcurrency || this.targetConcurrency || 1000));
    const cpus = os.cpus() || [];
    const cpuCores = Math.max(1, cpus.length || 1);
    const totalMemMb = Math.max(512, Math.round(os.totalmem() / 1024 / 1024));
    const freeMemMb = Math.round(os.freemem() / 1024 / 1024);

    let idleRssMb = 120;
    try {
      if (typeof process.memoryUsage === 'function') {
        idleRssMb = Math.max(80, Math.round(process.memoryUsage().rss / 1024 / 1024));
      }
    } catch (_) {}

    // 1. Lưu lượng lý thuyết:
    const baseRpm = N * 10;
    const rps = baseRpm / 60;

    // 2. CPU thực tế kết hợp tải thực đo:
    const idleCpuPct = 3;
    const addedCpuPct = (rps * 1.8 * 100) / (cpuCores * 1000);
    const theoCpuDay = Math.min(95, Math.max(5, Math.round(idleCpuPct + addedCpuPct)));
    const theoCpuNight = Math.min(90, Math.max(3, Math.round(idleCpuPct + addedCpuPct * 0.25)));

    // 3. RAM thực tế kết hợp tải thực đo:
    const addedRamDayMb = Math.round(N * 0.5);
    const expectedRamDayMb = idleRssMb + addedRamDayMb;
    const theoRamDay = Math.min(98, Math.max(10, Math.round((expectedRamDayMb / totalMemMb) * 100)));
    const expectedRamNightMb = idleRssMb + Math.round(addedRamDayMb * 0.25);
    const theoRamNight = Math.min(95, Math.max(8, Math.round((expectedRamNightMb / totalMemMb) * 100)));

    // 4. Event Loop Lag:
    const theoLagDay = Math.max(3, Math.round(4 + Math.max(0, (theoCpuDay - 60) * 0.3)));
    const theoLagNight = 3;

    // 5. Kết hợp chỉ số đo lường thực tế (Live System Sample) nếu có:
    const liveCpu = currentSample && typeof currentSample.cpuPercent === 'number' ? currentSample.cpuPercent : null;
    const liveRam = currentSample && typeof currentSample.ramPercent === 'number' ? currentSample.ramPercent : null;
    const liveLag = currentSample && typeof currentSample.eventLoopLagMs === 'number' ? currentSample.eventLoopLagMs : null;
    const liveRpm = currentSample && typeof currentSample.requestsPerMin === 'number' ? currentSample.requestsPerMin : null;

    const expectedCpuDay = liveCpu !== null ? Math.min(95, Math.max(5, Math.round(0.6 * liveCpu + 0.4 * theoCpuDay))) : theoCpuDay;
    const expectedCpuNight = liveCpu !== null ? Math.min(90, Math.max(3, Math.round(0.4 * liveCpu + 0.6 * theoCpuNight))) : theoCpuNight;
    const expectedRamDay = liveRam !== null ? Math.min(98, Math.max(10, Math.round(0.6 * liveRam + 0.4 * theoRamDay))) : theoRamDay;
    const expectedRamNight = liveRam !== null ? Math.min(95, Math.max(8, Math.round(0.4 * liveRam + 0.6 * theoRamNight))) : theoRamNight;
    const expectedLagDay = liveLag !== null ? Math.max(2, Math.round(0.6 * liveLag + 0.4 * theoLagDay)) : theoLagDay;
    const expectedLagNight = liveLag !== null ? Math.max(2, Math.round(0.4 * liveLag + 0.6 * theoLagNight)) : theoLagNight;
    const effectiveRpm = liveRpm && liveRpm > 0 ? Math.round(0.4 * liveRpm + 0.6 * baseRpm) : baseRpm;

    // 6. Đánh giá khả năng chịu tải (Capacity Assessment):
    const isOverCapacity = expectedCpuDay >= 85 || expectedRamDay >= 85;
    const isNearLimit = expectedCpuDay >= 70 || expectedRamDay >= 70;
    const capacityStatus = isOverCapacity ? 'OVER_CAPACITY' : (isNearLimit ? 'WARNING' : 'OPTIMAL');
    let recommendation = 'Hạ tầng máy chủ hoàn toàn đáp ứng trơn tru quy mô mục tiêu.';
    if (isOverCapacity) {
      recommendation = `CẢNH BÁO: Với ${N.toLocaleString('vi-VN')} người dùng, máy chủ ${cpuCores} cores / ${(totalMemMb / 1024).toFixed(1)}GB RAM sẽ bị quá tải (dự kiến CPU ~${expectedCpuDay}%, RAM ~${expectedRamDay}%). Khuyến nghị mở rộng số nhân CPU hoặc tăng RAM!`;
    } else if (isNearLimit) {
      recommendation = `LƯU Ý: Quy mô ${N.toLocaleString('vi-VN')} người dùng tiệm cận ngưỡng cảnh báo của máy chủ (${expectedCpuDay}% CPU, ${expectedRamDay}% RAM).`;
    }

    return {
      targetConcurrency: N,
      serverSpecs: {
        cpuCores,
        totalRamMb: totalMemMb,
        freeRamMb: freeMemMb,
        platform: process.platform,
        arch: process.arch,
      },
      liveMetricsSample: currentSample ? {
        measuredCpu: liveCpu,
        measuredRam: liveRam,
        measuredLag: liveLag,
        measuredRpm: liveRpm,
      } : null,
      calculatedMetrics: {
        baselineRpm: effectiveRpm,
        safePeakRpm: effectiveRpm * 3,
        expectedCpuPercent: expectedCpuDay,
        expectedRamPercent: expectedRamDay,
        expectedEventLoopLagMs: expectedLagDay,
      },
      nightMetrics: {
        baselineRpm: Math.round(effectiveRpm * 0.25),
        expectedCpuPercent: expectedCpuNight,
        expectedRamPercent: expectedRamNight,
        expectedEventLoopLagMs: expectedLagNight,
      },
      capacityAssessment: {
        status: capacityStatus,
        isOverCapacity,
        isNearLimit,
        recommendation,
      },
      calibratedAt: new Date().toISOString(),
    };
  }

  /**
   * Khởi tạo đường chuẩn 24 giờ dựa trên phần cứng server thật và quy mô người dùng mục tiêu
   */
  _initializeBaselines(currentSample = null) {
    const hwBaseline = this.calculateServerHardwareBaseline(this.targetConcurrency, currentSample);
    const baselines = [];
    for (let h = 0; h < 24; h++) {
      const isNight = h >= 0 && h <= 6;
      const m = isNight ? hwBaseline.nightMetrics : hwBaseline.calculatedMetrics;
      baselines.push({
        requestsPerMin: m.baselineRpm,
        errorRate4xx: 0.02,
        errorRate5xx: 0.00,
        eventLoopLagMs: m.expectedEventLoopLagMs,
        cpuPercent: m.expectedCpuPercent,
        ramPercent: m.expectedRamPercent,
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
  evaluate(sample, shouldUpdateBaseline = true) {
    const hour = this._getVnHour();
    const baseline = this.hourlyBaselines[hour];
    const anomalies = [];
    const N = this.targetConcurrency;

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

    let authScore = 0;
    // Ngưỡng phát hiện Brute-Force động theo quy mô hoặc cấu hình tùy chỉnh của Admin:
    const bruteForceThreshold =
      this.customThresholds.authFailedLogins !== null &&
      this.customThresholds.authFailedLogins !== undefined &&
      Number(this.customThresholds.authFailedLogins) > 0
        ? Number(this.customThresholds.authFailedLogins)
        : Math.max(15, Math.round(15 + 10 * Math.log10(N / 100)));

    if (this.vectorConfig.auth && sample.failedLogins >= bruteForceThreshold) {
      const isSevere = sample.failedLogins >= bruteForceThreshold * 2;
      authScore = isSevere ? 85 : 70;
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
        threshold: bruteForceThreshold,
        baseline: 0,
        unit: 'lần thất bại/10s',
        severity: 'HIGH',
        actor: authActor,
        message: `Tần suất đăng nhập thất bại tăng vọt (${sample.failedLogins} lần/10s, ngưỡng an toàn: ${bruteForceThreshold}) — Dấu hiệu dò quét mật khẩu (Brute-Force).`,
        rootCauseDiagnosis: `Phát hiện ${sample.failedLogins} lần đăng nhập sai dồn dập từ nguồn ${authActor.identity} sử dụng ${authActor.userAgent}.`,
        mitigationTaken: 'Hệ thống kích hoạt Rate Limiter và đưa IP vào Khiên Chắn Active Quarantine nếu vượt ngưỡng vi phạm.',
      });
    } else if (sample.failedLogins >= bruteForceThreshold) {
      // Vẫn đo lường điểm số độc lập khi vector bị tắt (chỉ quan sát)
      const isSevere = sample.failedLogins >= bruteForceThreshold * 2;
      authScore = isSevere ? 85 : 70;
    } else if (sample.failedLogins > 0) {
      // 1-24 lần: lỗi người dùng thông thường, chỉ tính điểm nhẹ (tối đa 15 điểm), tuyệt đối không báo động
      authScore = Math.min(15, Math.round((sample.failedLogins / bruteForceThreshold) * 15));
    }

    // Tái sử dụng Refresh Token: Chỉ báo động khi lặp lại >= 5 lần
    // (1-4 lần: thường do mở nhiều tab trình duyệt hoặc retry mạng, không phải tấn công)
    if (this.vectorConfig.auth && sample.tokenReuseAttacks >= 5) {
      const isSevere = sample.tokenReuseAttacks >= 10;
      authScore = Math.max(authScore, isSevere ? 80 : 70);
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
        threshold: 5,
        baseline: 0,
        unit: 'lần vi phạm',
        severity: 'HIGH',
        actor: tokenActor,
        message: `Phát hiện tái sử dụng Refresh Token đã bị thu hồi liên tục (${sample.tokenReuseAttacks} lần) — Dấu hiệu đánh cắp hoặc tái tạo phiên xác thực trái phép.`,
        rootCauseDiagnosis: `Token đã bị thu hồi nhưng vẫn tiếp tục được gửi lên từ nguồn ${tokenActor.identity}.`,
        mitigationTaken: 'Đã ngay lập tức thu hồi toàn bộ Token Family của tài khoản và ngắt phiên đăng nhập.',
      });
    } else if (sample.tokenReuseAttacks >= 5) {
      // Vẫn đo lường điểm số độc lập khi vector bị tắt (chỉ quan sát)
      const isSevere = sample.tokenReuseAttacks >= 10;
      authScore = Math.max(authScore, isSevere ? 80 : 70);
    } else if (sample.tokenReuseAttacks > 0) {
      // 1-4 lần vi phạm đơn lẻ: chỉ ghi nhận điểm nhẹ từ 10 - 25, không gắn cờ bất thường
      authScore = Math.max(authScore, Math.min(25, sample.tokenReuseAttacks * 6));
    }

    // ─────────────────────────────────────────────────────────────
    // VECTOR 2: RỦI RO LƯU LƯỢNG & TỪ CHỐI DỊCH VỤ (TRAFFIC & DOS)
    // ─────────────────────────────────────────────────────────────
    let trafficScore = 0;
    const expectedRpm = Math.max(100, baseline.requestsPerMin);
    const trafficRatio = sample.requestsPerMin / expectedRpm;
    const sampleWindowRequests = Math.max(1, Math.round((sample.requestsPerMin / 60) * 10));
    const ipEntropy = sample.distinctIpsCount / sampleWindowRequests;
    const effectiveTrafficRatio =
      this.customThresholds.trafficRatio !== null &&
      this.customThresholds.trafficRatio !== undefined &&
      Number(this.customThresholds.trafficRatio) > 0
        ? Number(this.customThresholds.trafficRatio)
        : 3.5;

    // Chỉ xem xét rủi ro lưu lượng khi RPM đạt tối thiểu 300 req/phút VÀ gấp effectiveTrafficRatio lần baseline
    if (sample.requestsPerMin >= 300 && trafficRatio >= effectiveTrafficRatio) {
      // Phân biệt: DDoS (ít IP nguồn, tỷ lệ lỗi cao) vs Organic Traffic Peak (nhiều IP thật)
      const isDdosIndicator =
        sample.distinctIpsCount <= 3 ||
        ipEntropy < 0.05 ||
        sample.errorRate4xx >= 0.25 ||
        sample.errorRate5xx >= 0.05 ||
        sample.malformedRequests > 0;

      if (isDdosIndicator) {
        trafficScore = Math.min(100, Math.round(50 + (trafficRatio - effectiveTrafficRatio) * 15));
        if (this.vectorConfig.traffic) {
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
            baseline: baseline.requestsPerMin,
            threshold: Math.round(expectedRpm * effectiveTrafficRatio),
            unit: 'req/phút',
            severity: 'HIGH',
            actor: trafficActor,
            message: `Lưu lượng tăng vọt bất thường (${sample.requestsPerMin} req/phút, gấp ${trafficRatio.toFixed(1)}x) với dấu hiệu phân tán IP thấp (${sample.distinctIpsCount} IPs) — Nghi vấn tấn công từ chối dịch vụ (DDoS/Scraping).`,
            rootCauseDiagnosis: `Lưu lượng tăng vọt gấp ${trafficRatio.toFixed(1)}x đường chuẩn trung bình (${sample.requestsPerMin} vs ${baseline.requestsPerMin} RPM).`,
            mitigationTaken: 'Hệ thống đã kích hoạt Token-Bucket Rate Limiter và Load Shedding cắt tải các request vượt ngưỡng.',
          });
        }
      } else {
        // Tăng trưởng tự nhiên lành mạnh từ người dùng thật (Flash Sale / Giờ cao điểm)
        trafficScore = Math.min(25, Math.round(10 + (trafficRatio - effectiveTrafficRatio) * 5));
      }
    } else {
      trafficScore = Math.min(15, Math.round(trafficRatio * 4));
    }

    // ─────────────────────────────────────────────────────────────
    // VECTOR 3: RỦI RO THĂM DÒ LỖ HỔNG & INJECTION (EXPLOITS & PROBES)
    // ─────────────────────────────────────────────────────────────
    let exploitScore = 0;
    const exploitThreshold =
      this.customThresholds.exploitSamples !== null &&
      this.customThresholds.exploitSamples !== undefined &&
      Number(this.customThresholds.exploitSamples) > 0
        ? Number(this.customThresholds.exploitSamples)
        : 8;

    if (sample.malformedRequests >= exploitThreshold) {
      const isSevere = sample.malformedRequests >= exploitThreshold * 2.5;
      exploitScore = isSevere ? 80 : 70;
      if (this.vectorConfig.exploit) {
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
          threshold: exploitThreshold,
          baseline: 0,
          unit: 'mẫu độc hại',
          severity: 'HIGH',
          actor: exploitActor,
          message: `Phát hiện các mẫu request độc hại chứa cú pháp SQLi/Path Traversal/XSS (${sample.malformedRequests} mẫu, ngưỡng: ${exploitThreshold}) từ bên ngoài.`,
          rootCauseDiagnosis: `Phát hiện ${sample.malformedRequests} request mang payload nguy hiểm (../, ..%2f, UNION SELECT, <script>) từ nguồn ${exploitActor.identity}.`,
          mitigationTaken: 'Đã tự động ngắt kết nối và cô lập IP độc hại vào Khiên Chắn Active Quarantine 30 phút.',
        });
      }
    } else if (sample.malformedRequests > 0) {
      exploitScore = Math.min(25, Math.round((sample.malformedRequests / exploitThreshold) * 25));
    }

    // ─────────────────────────────────────────────────────────────
    // VECTOR 4: SỨC KHỎE HẠ TẦNG & TÀI NGUYÊN (SYSTEM RESOURCES)
    // ─────────────────────────────────────────────────────────────
    const lagThreshold =
      this.customThresholds.resourceLag !== null &&
      this.customThresholds.resourceLag !== undefined &&
      Number(this.customThresholds.resourceLag) > 0
        ? Number(this.customThresholds.resourceLag)
        : 250;
    const ramThreshold =
      this.customThresholds.resourceRam !== null &&
      this.customThresholds.resourceRam !== undefined &&
      Number(this.customThresholds.resourceRam) > 0
        ? Number(this.customThresholds.resourceRam)
        : 92;
    const cpuThreshold =
      this.customThresholds.resourceCpu !== null &&
      this.customThresholds.resourceCpu !== undefined &&
      Number(this.customThresholds.resourceCpu) > 0
        ? Number(this.customThresholds.resourceCpu)
        : 85;

    let lagScore = 0;
    if (sample.eventLoopLagMs >= lagThreshold) {
      const isSevereLag = sample.eventLoopLagMs >= lagThreshold * 1.6;
      lagScore = isSevereLag ? 80 : 50;
      if (this.vectorConfig.resource) {
        anomalies.push({
          code: 'EVENT_LOOP_FREEZE',
          vector: 'resource',
          metric: 'eventLoopLagMs',
          current: sample.eventLoopLagMs,
          threshold: lagThreshold,
          baseline: 15,
          unit: 'ms lag',
          severity: isSevereLag ? 'HIGH' : 'MEDIUM',
          actor: systemActor,
          message: `Event Loop bị trễ nghiêm trọng (${sample.eventLoopLagMs}ms lag, ngưỡng: ${lagThreshold}ms) — Tiến trình Node.js đang bị nghẽn CPU hoặc I/O treo.`,
          rootCauseDiagnosis: `Độ trễ Event Loop đạt ${sample.eventLoopLagMs}ms (ngưỡng an toàn < ${lagThreshold}ms). Tiến trình đang chịu tải tính toán nặng hoặc I/O bị chặn.`,
          mitigationTaken: 'Load Shedding kích hoạt: Tự động trả HTTP 503 cho request khách vãng lai để giải tỏa CPU máy chủ.',
        });
      }
    } else if (sample.eventLoopLagMs >= 100) {
      lagScore = Math.min(25, Math.round((sample.eventLoopLagMs / lagThreshold) * 25));
    }

    let ramScore = 0;
    if (sample.ramPercent >= ramThreshold) {
      ramScore = 75;
      if (this.vectorConfig.resource) {
        anomalies.push({
          code: 'MEMORY_EXHAUSTION',
          vector: 'resource',
          metric: 'ramPercent',
          current: sample.ramPercent,
          threshold: ramThreshold,
          baseline: 50,
          unit: '% RAM',
          severity: 'HIGH',
          actor: systemActor,
          message: `Bộ nhớ RAM tiêu thụ đã chạm ${sample.ramPercent}% (ngưỡng an toàn: ${ramThreshold}%) — Nguy cơ rò rỉ bộ nhớ (Memory Leak) hoặc sập tiến trình (OOM).`,
          rootCauseDiagnosis: `Bộ nhớ RAM đã vượt ngưỡng nguy hiểm (${sample.ramPercent}% >= ${ramThreshold}%). Cần giám sát rò rỉ bộ nhớ hoặc scale up tài nguyên.`,
          mitigationTaken: 'Cảnh báo tài nguyên hệ thống phát ra tới Quản trị viên để chuẩn bị mở rộng hạ tầng.',
        });
      }
    } else if (sample.ramPercent >= 80) {
      ramScore = Math.min(25, Math.round((sample.ramPercent - 80) * 2));
    }

    let cpuScore = 0;
    if (sample.cpuPercent >= cpuThreshold) {
      cpuScore = 75;
      if (this.vectorConfig.resource) {
        anomalies.push({
          code: 'CPU_OVERLOAD_SURGE',
          vector: 'resource',
          metric: 'cpuPercent',
          current: sample.cpuPercent,
          threshold: cpuThreshold,
          baseline: 30,
          unit: '% CPU',
          severity: 'HIGH',
          actor: systemActor,
          message: `CPU máy chủ tiêu thụ chạm ${sample.cpuPercent}% (ngưỡng an toàn: ${cpuThreshold}%) — Nguy cơ nghẽn tải tính toán hệ thống.`,
          rootCauseDiagnosis: `CPU tiêu thụ chạm ${sample.cpuPercent}%, vượt ngưỡng an toàn ${cpuThreshold}%.`,
          mitigationTaken: 'Load Shedding kích hoạt: Giảm tải các tác vụ nền định kỳ.',
        });
      }
    } else if (sample.cpuPercent >= 70) {
      cpuScore = Math.min(25, Math.round((sample.cpuPercent - 70) * 1.5));
    }

    let err5xxScore = 0;
    const minRequestsFor5xx = 10;
    if (sampleWindowRequests >= minRequestsFor5xx && sample.errorRate5xx >= 0.25) {
      err5xxScore = 70;
      if (this.vectorConfig.resource) {
        anomalies.push({
          code: 'SERVER_5XX_SURGE',
          vector: 'resource',
          metric: 'errorRate5xx',
          current: sample.errorRate5xx,
          threshold: 0.25,
          baseline: 0.01,
          unit: '% lỗi',
          severity: 'HIGH',
          actor: systemActor,
          message: `Tỷ lệ lỗi máy chủ 5xx tăng bất thường (${Math.round(sample.errorRate5xx * 100)}% yêu cầu) — Dấu hiệu database hoặc service phụ thuộc tê liệt.`,
          rootCauseDiagnosis: `Tỷ lệ lỗi HTTP 500 đạt ${Math.round(sample.errorRate5xx * 100)}% trên tổng ${sampleWindowRequests} requests.`,
          mitigationTaken: 'DB Bulkhead tự động bảo lưu 20% kết nối cho luồng Quản trị viên (Fast-Lane) để cứu hộ.',
        });
      }
    } else if (sample.errorRate5xx > 0 && sampleWindowRequests >= minRequestsFor5xx) {
      err5xxScore = Math.min(20, Math.round(sample.errorRate5xx * 60));
    }

    // Compound resource exhaustion: Nếu có từ 2 chỉ số phần cứng bị nguy hiểm cùng lúc
    const resourceIssuesCount = [lagScore >= 70, ramScore >= 70, cpuScore >= 70, err5xxScore >= 70].filter(Boolean).length;
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
    const highVectorsCount = activeScores.filter((s) => s >= 65).length;
    const corroborationBonus = highVectorsCount >= 2 ? (highVectorsCount - 1) * 8 : 0;

    // Hệ số đe dọa lấy theo giá trị thực tế được tính toán (không kẹp tối thiểu 5)
    let threatScore = Math.min(100, Math.max(0, Math.round(rawMax + corroborationBonus)));

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
            ? '🚨 Nguy cơ sập dây chuyền hạ tầng (Lag > 400ms & 5xx > 25% / OOM): Đề xuất kích hoạt Bảo trì khẩn cấp để bảo vệ CSDL'
            : resourceScore >= 70
              ? 'Tự động kích hoạt Load Shedding (hạ tải nhẹ HTTP 503 cho request không ưu tiên, bảo vệ tiến trình lõi)'
              : 'Tài nguyên phần cứng ổn định',
      },
    };

    // Xác định phân cấp trạng thái và hành động tổng thể
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

    // Cơ chế Anti-Poisoning: Chỉ cập nhật baseline khi hệ thống hoạt động bình thường, an toàn
    if (shouldUpdateBaseline && threatScore < 70) {
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
      vectorConfig: { ...this.vectorConfig },
      customThresholds: this.getCustomThresholds(),
      targetConcurrency: this.targetConcurrency,
      isAnomaly,
      anomalies,
      recommendedAction,
      evaluatedAt: new Date().toISOString(),
    };
  }

  calibrate(options = {}) {
    // 1. Tự động tính toán lại đường chuẩn 24h dựa trên phần cứng server thật, tải thực tế và N
    const target = options.targetConcurrency || (typeof options === 'number' ? options : this.targetConcurrency);
    this.targetConcurrency = Math.max(100, Number(target || 1000));
    const currentSample = options.currentSample || null;
    const report = this.calculateServerHardwareBaseline(this.targetConcurrency, currentSample);
    this.hourlyBaselines = this._initializeBaselines(currentSample);

    // 2. Nhận cấu hình ngưỡng an toàn tùy chỉnh (Custom Thresholds) cho 4 Vector nếu Admin cung cấp
    if (options.customThresholds && typeof options.customThresholds === 'object') {
      this.setCustomThresholds(options.customThresholds);
    }
    report.customThresholds = this.getCustomThresholds();

    // 3. Nếu có customBaselines truyền vào từng giờ, merge vào
    if (options.customBaselines) {
      const hour = this._getVnHour();
      if (this.hourlyBaselines[hour]) {
        Object.assign(this.hourlyBaselines[hour], options.customBaselines);
      }
    } else if (typeof options === 'object' && !options.targetConcurrency && !options.customThresholds) {
      const hour = this._getVnHour();
      if (this.hourlyBaselines[hour]) {
        Object.assign(this.hourlyBaselines[hour], options);
      }
    }

    return report;
  }
}

const defaultAnomalyDetector = new AnomalyDetector();

module.exports = {
  AnomalyDetector,
  defaultAnomalyDetector,
};
