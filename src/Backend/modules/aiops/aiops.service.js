const { defaultFeatureCollector } = require('./feature.collector');
const { defaultAnomalyDetector } = require('./anomaly.detector');
const { defaultAIOpsIncidentRepository } = require('./aiops.repository');
const logger = require('../../core/logger');
const { stripRawIp } = require('../../utils/ip-protection.util');
const v8 = require('v8');
const F = require('./aiops.formulas');
const { getRuntimeHardwareSpecs } = require('../../core/resilience/runtime-environment');

const MAX_CAPACITY_WINDOWS = 360; // ~1 giờ cửa sổ 10 giây cho ước lượng năng lực (B5)
const BASELINE_REFRESH_MS = 60 * 60 * 1000; // tính lại đường nền mỗi giờ (B1)
const BASELINE_LOOKBACK_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * AIOps Coordinator Service
 * Điều phối chu trình lấy mẫu định kỳ 10s, chạy đánh giá máy học, lưu trữ bộ đệm 60 mẫu lịch sử
 * và phát sự kiện cảnh báo qua Socket.io & Email khi phát hiện nguy cơ cao.
 */
class AIOpsService {
  constructor(options = {}) {
    this.collector = options.collector || defaultFeatureCollector;
    this.detector = options.detector || defaultAnomalyDetector;
    this.repository = options.repository || defaultAIOpsIncidentRepository;
    this.maxHistory = options.maxHistory || 1000;
    this.samplingIntervalMs = options.samplingIntervalMs || 10000;
    this.io = options.io || null;
    this.specsProvider = options.specsProvider || getRuntimeHardwareSpecs;
    this._capacityWindows = [];
    this._baselineTimer = null;

    this._history = [];
    this._currentStatus = {
      threatScore: 0,
      status: 'NORMAL',
      isAnomaly: false,
      anomalies: [],
      recommendedAction: null,
      lastEvaluatedAt: null,
    };
    this._timer = null;
    this._snapshotTimer = null;
    this._snapshotIntervalMs = options.snapshotIntervalMs || (5 * 60 * 1000); // 5 phút / snapshot
    this._lastAlertTime = 0;
  }

  getIO() {
    if (this.io) return this.io;
    try {
      const { getIO } = require('../../core/socket');
      if (typeof getIO === 'function') {
        return getIO();
      }
    } catch (_) {}
    return null;
  }

  async loadPersistedSettings() {
    try {
      if (this.repository && typeof this.repository.getSetting === 'function') {
        const saved = await this.repository.getSetting('target_concurrency', '1000');
        const num = parseInt(saved, 10);
        if (num >= 100 && num <= 50000) {
          const scaleInfo = this.detector.setConcurrencyScale(num);
          if (this._currentStatus) {
            this._currentStatus.targetConcurrency = scaleInfo.targetConcurrency;
          }
          if (this.collector && typeof this.collector.setTargetConcurrency === 'function') {
            this.collector.setTargetConcurrency(scaleInfo.targetConcurrency);
          }
          logger.info(`[AIOps] Đã nạp thành công quy mô người dùng lưu cứng từ CSDL: ${num} CCU`);
        }
      }

      // Nạp trạng thái Vector Toggles từ CSDL
      if (this.repository && typeof this.repository.getSetting === 'function') {
        const savedVectors = await this.repository.getSetting('vector_toggles', null);
        if (savedVectors) {
          try {
            const parsed = typeof savedVectors === 'string' ? JSON.parse(savedVectors) : savedVectors;
            this.detector.setVectorConfig(parsed);
            if (this._currentStatus) {
              this._currentStatus.vectorConfig = { ...this.detector.vectorConfig };
            }
            logger.info('[AIOps] Đã nạp thành công cấu hình vector toggles lưu cứng từ CSDL:', parsed);
          } catch (_) {}
        }
      }

      // Nạp cấu hình ngưỡng an toàn tùy chỉnh (Custom Vector Thresholds) từ CSDL
      if (this.repository && typeof this.repository.getSetting === 'function') {
        const savedThresholds = await this.repository.getSetting('custom_vector_thresholds', null);
        if (savedThresholds) {
          try {
            const parsed = typeof savedThresholds === 'string' ? JSON.parse(savedThresholds) : savedThresholds;
            this.detector.setCustomThresholds(parsed);
            if (this._currentStatus) {
              this._currentStatus.customThresholds = { ...this.detector.getCustomThresholds() };
            }
            logger.info('[AIOps] Đã nạp thành công cấu hình custom_vector_thresholds lưu cứng từ CSDL:', parsed);
          } catch (_) {}
        }
      }
    } catch (err) {
      logger.warn('[AIOps] Lỗi nạp cài đặt lưu cứng từ CSDL (dùng mặc định)', { error: err.message });
    }
  }

  start() {
    if (this._timer) return;
    if (this.repository && typeof this.repository.initTable === 'function') {
      this.repository.initTable()
        .then(() => this.loadPersistedSettings())
        .then(() => this.refreshTrafficBaselines())
        .catch((err) => {
          logger.warn('[AIOps] Không thể khởi tạo bảng CSDL khi start', { error: err.message });
        });
    }
    this._timer = setInterval(() => {
      this.tick().catch((err) => {
        logger.error('[AIOps] Error during sampling tick', { error: err.message });
      });
    }, this.samplingIntervalMs);

    if (this._timer.unref) {
      this._timer.unref(); // Không chặn quá trình shutdown tiến trình
    }

    // Khởi động bộ ghi metric snapshot định kỳ 5 phút vào PostgreSQL
    this._snapshotTimer = setInterval(() => {
      this.captureMetricSnapshot().catch((err) => {
        logger.warn('[AIOps] Lỗi captureMetricSnapshot định kỳ', { error: err.message });
      });
    }, this._snapshotIntervalMs);

    if (this._snapshotTimer.unref) {
      this._snapshotTimer.unref();
    }

    this._baselineTimer = setInterval(() => {
      this.refreshTrafficBaselines().catch(() => {});
    }, BASELINE_REFRESH_MS);
    if (this._baselineTimer.unref) {
      this._baselineTimer.unref();
    }

    logger.info('[AIOps] Sentinel engine started (10s sample, 5m snapshot)');
  }

  stop() {
    if (this._timer) {
      clearInterval(this._timer);
      this._timer = null;
    }
    if (this._snapshotTimer) {
      clearInterval(this._snapshotTimer);
      this._snapshotTimer = null;
    }
    if (this._baselineTimer) {
      clearInterval(this._baselineTimer);
      this._baselineTimer = null;
    }
    logger.info('[AIOps] Sentinel engine stopped');
  }

  async captureMetricSnapshot() {
    if (!this.repository || typeof this.repository.saveMetricSnapshot !== 'function') return null;
    try {
      const sample = this._peekSample();
      const vs = this._currentStatus?.vectorScores || {};
      const snapshot = await this.repository.saveMetricSnapshot({
        threatScore: this._currentStatus?.threatScore || 0,
        authScore: vs.auth || 0,
        trafficScore: vs.traffic || 0,
        exploitScore: vs.exploit || 0,
        resourceScore: vs.resource || 0,
        requestsPerMin: sample?.requestsPerMin || 0,
        cpuPercent: sample?.cpuPercent || 0,
        ramPercent: sample?.ramPercent || 0,
        eventLoopLagMs: sample?.eventLoopLagMs || 0,
        isAnomaly: Boolean(this._currentStatus?.isAnomaly),
        recordedAt: new Date(),
      });
      return snapshot;
    } catch (err) {
      logger.warn('[AIOps] Lỗi captureMetricSnapshot', { error: err.message });
      return null;
    }
  }

  async tick() {
    const sample = this.collector.getSample();
    const evaluation = this.detector.evaluate(sample);
    this._recordCapacityWindow(sample);

    this._currentStatus = {
      threatScore: evaluation.threatScore,
      status: evaluation.status,
      vectorScores: evaluation.vectorScores,
      vectorDefenses: evaluation.vectorDefenses,
      targetConcurrency: evaluation.targetConcurrency,
      isAnomaly: evaluation.isAnomaly,
      anomalies: evaluation.anomalies,
      recommendedAction: evaluation.recommendedAction,
      lastEvaluatedAt: evaluation.evaluatedAt,
      indicators: evaluation.indicators,
      sample,
    };

    // Đẩy vào ring buffer lịch sử phục vụ vẽ biểu đồ (tối đa 60 mẫu)
    this._history.push({
      timestamp: sample.timestamp,
      threatScore: evaluation.threatScore,
      status: evaluation.status,
      vectorScores: evaluation.vectorScores,
      vectorDefenses: evaluation.vectorDefenses,
      isAnomaly: evaluation.isAnomaly,
      anomalies: evaluation.anomalies,
      requestsPerMin: sample.requestsPerMin,
      errorRate4xx: sample.errorRate4xx,
      errorRate5xx: sample.errorRate5xx,
      eventLoopLagMs: sample.eventLoopLagMs,
      cpuPercent: sample.cpuPercent,
      ramPercent: sample.ramPercent,
      dbPoolActive: sample.dbPoolActive,
      loadSheddingCount: sample.loadSheddingCount,
      failedLogins: sample.failedLogins,
      tokenReuseAttacks: sample.tokenReuseAttacks,
      malformedRequests: sample.malformedRequests,
      distinctIpsCount: sample.distinctIpsCount,
    });

    if (this._history.length > this.maxHistory) {
      this._history.shift();
    }

    await this._persistAndEmitAnomalies(evaluation.anomalies);

    // Báo động thời gian thực khi Threat Score >= 70
    if (evaluation.threatScore >= 70) {
      this._dispatchAlert(evaluation, sample);
    }

    return this._currentStatus;
  }

  async _persistAndEmitAnomalies(anomalies) {
    const io = this.getIO();
    for (const anomaly of anomalies || []) {
      try {
        const savedIncident = await this.repository.upsertIncident(anomaly);
        if (io && savedIncident) {
          io.to('admin_room').emit('admin.anomaly_detected', stripRawIp(savedIncident));
        }
      } catch (err) {
        logger.warn('[AIOps] Lỗi lưu anomaly vào CSDL', { error: err.message });
      }
    }

    try {
      const mitigated = await this.repository.autoMitigateStaleIncidents(60);
      if (io && mitigated && mitigated.length > 0) {
        for (const m of mitigated) {
          io.to('admin_room').emit('admin.anomaly_detected', stripRawIp(m));
        }
      }
    } catch (_) {}
  }

  _dispatchAlert(evaluation, sample) {
    const io = this.getIO();
    const alertPayload = {
      threatScore: evaluation.threatScore,
      status: evaluation.status,
      vectorScores: evaluation.vectorScores,
      vectorDefenses: evaluation.vectorDefenses,
      anomalies: evaluation.anomalies,
      recommendedAction: evaluation.recommendedAction,
      indicators: evaluation.indicators,
      sample,
      timestamp: evaluation.evaluatedAt,
    };

    if (io) {
      try {
        io.to('admin_room').emit('admin.security_alert', stripRawIp(alertPayload));
      } catch (err) {
        logger.error('[AIOps] Failed to emit socket alert', { error: err.message });
      }
    }

    logger.warn(`[AIOps Alert] Threat Score: ${evaluation.threatScore} | Status: ${evaluation.status}`, {
      anomaliesCount: evaluation.anomalies.length,
      action: evaluation.recommendedAction,
    });

    // Chỉ gửi thông báo khẩn cấp (Email tới Admin) khi có nguy cơ sập hạ tầng (EMERGENCY_MAINTENANCE) và cách tối thiểu 5 phút
    const now = Date.now();
    if (evaluation.recommendedAction === 'EMERGENCY_MAINTENANCE' && now - this._lastAlertTime > 5 * 60 * 1000) {
      this._lastAlertTime = now;
      this._sendEmergencyNotification(evaluation);
    }
  }

  _sendEmergencyNotification(evaluation) {
    try {
      const emailService = require('../../core/email.service');
      const config = require('../../config');
      const adminEmail = process.env.ADMIN_ALERT_EMAIL || (config && config.mail && config.mail.from);
      if (adminEmail && typeof emailService.sendMail === 'function') {
        const anomalyList = evaluation.anomalies.map((a) => `- [${a.severity}] ${a.message}`).join('\n');
        emailService.sendMail({
          to: adminEmail,
          subject: `🚨 [AIOps CẢNH BÁO NGUY CẤP] Threat Score ${evaluation.threatScore}/100`,
          text: `Hệ thống AIOps Sentinel phát hiện nguy cơ an ninh / sự cố nghiêm trọng:\n\n${anomalyList}\n\nHành động khuyến nghị: ${evaluation.recommendedAction}\nVui lòng truy cập trang Quản trị Admin để kiểm tra và xử lý khẩn cấp.`,
        }).catch((e) => logger.error('[AIOps] Error sending alert email', { error: e.message }));
      }
    } catch (_) {}
  }

  async setConcurrencyScale(scaleNumber, persistToDb = true) {
    const scaleInfo = this.detector.setConcurrencyScale(scaleNumber);
    if (this._currentStatus) {
      this._currentStatus.targetConcurrency = scaleInfo.targetConcurrency;
    }
    if (this.collector && typeof this.collector.setTargetConcurrency === 'function') {
      this.collector.setTargetConcurrency(scaleInfo.targetConcurrency);
    }
    if (persistToDb && this.repository && typeof this.repository.setSetting === 'function') {
      try {
        await this.repository.setSetting('target_concurrency', String(scaleInfo.targetConcurrency));
      } catch (err) {
        logger.error('[AIOps] Lỗi lưu cứng quy mô người dùng vào CSDL', { error: err.message });
      }
    }
    logger.info(`[AIOps] Cập nhật và lưu cứng quy mô người dùng: ${scaleInfo.targetConcurrency} users (Đường nền: ${scaleInfo.indicators.traffic.baselineRpm} RPM, ${scaleInfo.indicators.traffic.source})`);
    return {
      success: true,
      ...scaleInfo,
      message: `Đã cập nhật và lưu cứng quy mô hệ thống lên ${scaleInfo.targetConcurrency} người dùng thành công!`,
    };
  }

  async toggleVector(vectorName, isEnabled, persistToDb = true) {
    const updated = this.detector.setVectorEnabled(vectorName, isEnabled);
    
    // Tái đánh giá tức thì với mẫu hiện tại để cập nhật ngay Threat Score và Trạng thái
    const currentSample = this._peekSample();
    if (currentSample) {
      const evaluation = this.detector.evaluate(currentSample);
      this._currentStatus = {
        ...this._currentStatus,
        threatScore: evaluation.threatScore,
        status: evaluation.status,
        vectorScores: evaluation.vectorScores,
        vectorDefenses: evaluation.vectorDefenses,
        targetConcurrency: evaluation.targetConcurrency,
        isAnomaly: evaluation.isAnomaly,
        anomalies: evaluation.anomalies,
        recommendedAction: evaluation.recommendedAction,
        vectorConfig: { ...updated },
        lastEvaluatedAt: evaluation.evaluatedAt,
        sample: currentSample,
      };

      if (this._history && this._history.length > 0) {
        const lastEntry = this._history[this._history.length - 1];
        lastEntry.threatScore = evaluation.threatScore;
        lastEntry.status = evaluation.status;
        lastEntry.vectorScores = evaluation.vectorScores;
        lastEntry.vectorDefenses = evaluation.vectorDefenses;
        lastEntry.isAnomaly = evaluation.isAnomaly;
        lastEntry.anomalies = evaluation.anomalies;
      }
    } else if (this._currentStatus) {
      this._currentStatus.vectorConfig = { ...updated };
    }

    if (persistToDb && this.repository && typeof this.repository.setSetting === 'function') {
      try {
        await this.repository.setSetting('vector_toggles', JSON.stringify(updated));
      } catch (err) {
        logger.error('[AIOps] Lỗi lưu cấu hình vector_toggles vào CSDL', { error: err.message });
      }
    }
    const io = this.getIO();
    if (io) {
      try {
        io.to('admin_room').emit('admin.vector_config_changed', updated);
      } catch (_) {}
    }
    logger.info(`[AIOps] Vector [${vectorName}] đã được chuyển sang trạng thái: ${isEnabled ? 'BẬT' : 'TẮT'}`);
    return {
      success: true,
      vector: vectorName,
      enabled: isEnabled,
      vectorConfig: updated,
      currentStatus: this._currentStatus,
      message: `Đã ${isEnabled ? 'bật' : 'tắt'} tính rủi ro cho vector ${vectorName} thành công.`,
    };
  }

  getVectorConfig() {
    return { ...this.detector.vectorConfig };
  }

  getStatus() {
    const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
    const sample = this._peekSample();
    return {
      ...this._currentStatus,
      sample,
      targetConcurrency: this.detector.targetConcurrency,
      vectorScores: this._currentStatus?.vectorScores || { auth: 0, traffic: 0, exploit: 0, resource: 0 },
      vectorConfig: { ...this.detector.vectorConfig },
      customThresholds: this.detector.getCustomThresholds(),
      indicators: this.detector.getEffectiveThresholds(),
      quarantinedCount: defaultAIOpsQuarantine.getQuarantinedList().length,
      recentIncidents: (this.repository?._inMemoryFallback || []).slice(0, 10),
    };
  }

  async getHistory(options = {}) {
    if (!options.range && !options.from && !options.to && !options.aggregate) {
      return [...this._history];
    }
    const { range = '10m', from, to } = options;

    let startTime = 0;
    let endTime = Date.now();
    let bucketWidthMs = 10000; // 10s mặc định
    let shouldFetchDbSnapshots = false;

    // QUY TẮC CỐT LÕI CỦA PO: Ưu tiên bộ lọc khoảng thời gian tùy biến (from & to)
    if (from && to) {
      const parsedFrom = new Date(from);
      startTime = parsedFrom.getTime();

      const parsedTo = new Date(to);
      if (typeof to === 'string' && to.length === 10) {
        parsedTo.setHours(23, 59, 59, 999);
      } else if (typeof to === 'string' && to.length === 7) {
        const [y, m] = to.split('-').map(Number);
        const lastDay = new Date(y, m, 0).getDate();
        parsedTo.setFullYear(y, m - 1, lastDay);
        parsedTo.setHours(23, 59, 59, 999);
      } else if (typeof to === 'string' && to.length === 4) {
        const y = Number(to);
        parsedTo.setFullYear(y, 11, 31);
        parsedTo.setHours(23, 59, 59, 999);
      }
      endTime = parsedTo.getTime();

      const diffMs = Math.max(1000, endTime - startTime);
      if (diffMs <= 15 * 60 * 1000) {
        bucketWidthMs = 10000; // 10s
      } else if (diffMs <= 90 * 60 * 1000) {
        bucketWidthMs = 60000; // 1 phút
      } else if (diffMs <= 36 * 3600 * 1000) {
        bucketWidthMs = 30 * 60 * 1000; // 30 phút
        shouldFetchDbSnapshots = true;
      } else if (diffMs <= 10 * 24 * 3600 * 1000) {
        bucketWidthMs = 4 * 3600 * 1000; // 4 giờ
        shouldFetchDbSnapshots = true;
      } else {
        bucketWidthMs = 12 * 3600 * 1000; // 12 giờ
        shouldFetchDbSnapshots = true;
      }
    } else if (range === '1h') {
      // 1 giờ qua: 60 mẫu dàn trải trong 60 phút (1p/mẫu, lấy max 1p)
      startTime = Date.now() - 60 * 60 * 1000;
      bucketWidthMs = 60000;
    } else if (range === '24h' || range === 'day') {
      // 24 giờ qua: 48 mẫu dàn trải trong 24 giờ (30p/mẫu, lấy max 30p)
      startTime = Date.now() - 24 * 3600 * 1000;
      bucketWidthMs = 30 * 60 * 1000;
      shouldFetchDbSnapshots = true;
    } else if (range === '7d') {
      // 7 ngày qua: 4 giờ lấy 1 mẫu, 6 mẫu/ngày, tổng 48 mẫu (lấy max 4 giờ)
      startTime = Date.now() - 7 * 24 * 3600 * 1000;
      bucketWidthMs = 4 * 3600 * 1000;
      shouldFetchDbSnapshots = true;
    } else if (range === '30d' || range === 'month') {
      // 1 tháng qua: mỗi ngày 2 mẫu (12 giờ/mẫu, lấy max 12 giờ)
      startTime = Date.now() - 30 * 24 * 3600 * 1000;
      bucketWidthMs = 12 * 3600 * 1000;
      shouldFetchDbSnapshots = true;
    } else if (range === 'year') {
      startTime = Date.now() - 365 * 24 * 3600 * 1000;
      bucketWidthMs = 24 * 3600 * 1000;
      shouldFetchDbSnapshots = true;
    } else {
      // '10m' hoặc 'realtime' (10 phút qua: 60 mẫu, 10s/mẫu, lấy max 10s)
      startTime = Date.now() - 10 * 60 * 1000;
      bucketWidthMs = 10000;
    }

    // NGUYÊN TẮC TRUNG THỰC DỮ LIỆU CỦA PO:
    // Tuyệt đối không sinh dữ liệu giả lập hay nội suy điểm nhân tạo.
    // Kết hợp mẫu từ bộ nhớ RAM và các snapshot thực tế được lưu vào PostgreSQL
    const combinedSamples = [];
    const seenTimestamps = new Set();

    // 1. Lấy các mẫu đo trực tiếp trong RAM:
    for (const item of this._history || []) {
      if (!item || !item.timestamp) continue;
      const t = new Date(item.timestamp).getTime();
      if (!isNaN(t) && t >= startTime && t <= endTime) {
        combinedSamples.push(item);
        seenTimestamps.add(item.timestamp);
      }
    }

    // 2. Lấy thêm các snapshot định kỳ từ PostgreSQL nếu truy vấn dải thời gian dài (24h, 7d, 30d):
    if (shouldFetchDbSnapshots && this.repository && typeof this.repository.getMetricSnapshots === 'function') {
      try {
        const dbSnapshots = await this.repository.getMetricSnapshots(new Date(startTime), new Date(endTime));
        for (const snap of dbSnapshots || []) {
          if (!snap || !snap.timestamp || seenTimestamps.has(snap.timestamp)) continue;
          combinedSamples.push({
            timestamp: snap.timestamp,
            threatScore: snap.threatScore,
            status: snap.threatScore >= 80 ? 'CRITICAL' : snap.threatScore >= 60 ? 'WARNING' : 'NORMAL',
            vectorScores: {
              auth: snap.authScore,
              traffic: snap.trafficScore,
              exploit: snap.exploitScore,
              resource: snap.resourceScore,
            },
            requestsPerMin: snap.requestsPerMin,
            cpuPercent: snap.cpuPercent,
            ramPercent: snap.ramPercent,
            isAnomaly: snap.isAnomaly,
          });
          seenTimestamps.add(snap.timestamp);
        }
      } catch (err) {
        logger.warn('[AIOps] Lỗi truy vấn metric snapshots từ CSDL', { error: err.message });
      }
    }

    if (combinedSamples.length === 0) {
      return [];
    }

    // Gom nhóm mẫu theo từng bucket thời gian và lấy giá trị MAX đo được
    const bucketMap = new Map();
    for (const s of combinedSamples) {
      const t = new Date(s.timestamp).getTime();
      const bIndex = Math.floor((t - startTime) / bucketWidthMs);
      if (!bucketMap.has(bIndex)) {
        bucketMap.set(bIndex, []);
      }
      bucketMap.get(bIndex).push(s);
    }

    const aggregated = [];
    const sortedBucketIndices = Array.from(bucketMap.keys()).sort((a, b) => a - b);

    for (const bIdx of sortedBucketIndices) {
      const items = bucketMap.get(bIdx);
      if (!items || items.length === 0) continue;

      let maxAuth = 0;
      let maxTraffic = 0;
      let maxExploit = 0;
      let maxResource = 0;
      let maxThreat = 0;
      let maxRpm = 0;
      let maxCpu = 0;
      let maxRam = 0;
      let latestTime = items[0].timestamp;

      for (const it of items) {
        const vs = it.vectorScores || {};
        const authVal = vs.auth !== undefined ? vs.auth : (it.failedLogins ? Math.min(100, it.failedLogins * 10) : 0);
        const trafficVal = vs.traffic !== undefined ? vs.traffic : (it.requestsPerMin ? Math.min(100, Math.round(it.requestsPerMin / 30)) : 0);
        const exploitVal = vs.exploit !== undefined ? vs.exploit : (it.malformedRequests ? Math.min(100, it.malformedRequests * 25) : 0);
        const resourceVal = vs.resource !== undefined ? vs.resource : (it.cpuPercent || it.ramPercent ? Math.max(it.cpuPercent || 0, it.ramPercent || 0) : 0);
        const threatVal = it.threatScore ?? Math.max(authVal, trafficVal, exploitVal, resourceVal);

        if (authVal > maxAuth) maxAuth = authVal;
        if (trafficVal > maxTraffic) maxTraffic = trafficVal;
        if (exploitVal > maxExploit) maxExploit = exploitVal;
        if (resourceVal > maxResource) maxResource = resourceVal;
        if (threatVal > maxThreat) maxThreat = threatVal;
        if ((it.requestsPerMin || 0) > maxRpm) maxRpm = it.requestsPerMin || 0;
        if ((it.cpuPercent || 0) > maxCpu) maxCpu = it.cpuPercent || 0;
        if ((it.ramPercent || 0) > maxRam) maxRam = it.ramPercent || 0;
        latestTime = it.timestamp;
      }

      aggregated.push({
        timestamp: latestTime,
        threatScore: maxThreat,
        status: maxThreat >= 80 ? 'CRITICAL' : maxThreat >= 60 ? 'WARNING' : 'NORMAL',
        vectorScores: {
          auth: maxAuth,
          traffic: maxTraffic,
          exploit: maxExploit,
          resource: maxResource,
        },
        requestsPerMin: maxRpm,
        cpuPercent: maxCpu,
        ramPercent: maxRam,
        isAnomaly: items.some((it) => it.isAnomaly),
      });
    }

    return aggregated;
  }

  /** Mẫu để đọc trạng thái: mẫu đã chốt gần nhất, chưa có thì xem cửa sổ đang chạy (không xoá bộ đếm). */
  _peekSample() {
    if (this._currentStatus?.sample) return this._currentStatus.sample;
    if (this.collector && typeof this.collector.peekSample === 'function') return this.collector.peekSample();
    return null;
  }

  /** B5: lưu (thời gian CPU, số yêu cầu hoàn tất) của cửa sổ; bỏ cửa sổ đang khởi động. */
  _recordCapacityWindow(sample) {
    if (!sample || sample.warmingUp) return;
    if (!Number.isFinite(sample.cpuMs) || !Number.isFinite(sample.completedCount)) return;
    this._capacityWindows.push({ cpuMs: sample.cpuMs, completed: sample.completedCount });
    if (this._capacityWindows.length > MAX_CAPACITY_WINDOWS) this._capacityWindows.shift();
  }

  /** B1: tính lại đường nền 24 giờ từ snapshot 7 ngày gần nhất. */
  async refreshTrafficBaselines() {
    if (!this.repository || typeof this.repository.getMetricSnapshots !== 'function') return null;
    try {
      const now = Date.now();
      const snapshots = await this.repository.getMetricSnapshots(new Date(now - BASELINE_LOOKBACK_MS), new Date(now));
      const hours = F.computeHourlyTrafficBaselines(snapshots || [], { targetConcurrency: this.detector.targetConcurrency, now });
      this.detector.setTrafficBaselines(hours);
      return hours;
    } catch (err) {
      logger.warn('[AIOps] Không tính được đường nền lưu lượng từ snapshot', { error: err.message });
      return null;
    }
  }

  /** B5: báo cáo năng lực theo Luật sử dụng (U = X × S). */
  buildCapacityReport() {
    const specs = this.specsProvider() || {};
    const quotaCores = specs.cpuQuotaHard ? Number(specs.cpuCores) : 1;
    const ind = this.detector.getEffectiveThresholds();
    const alertRpm = ind.traffic.alertRpm;
    const fit = F.fitUtilization(this._capacityWindows);

    let capacity;
    if (fit.ok) {
      const est = F.estimateCapacity({ cpuMsPerRequest: fit.cpuMsPerRequest, backgroundCpuMs: fit.backgroundCpuMs, quotaCores });
      capacity = {
        status: F.assessCapacity(alertRpm, est.maxRpm),
        cpuMsPerRequest: fit.cpuMsPerRequest,
        backgroundCpuMs: fit.backgroundCpuMs,
        windows: fit.windows,
        busyWindows: fit.busyWindows,
        uMax: est.uMax,
        maxRpm: est.maxRpm,
        alertRpm,
        estimatedMaxUsers: Math.floor(est.maxRpm / F.ESTIMATE_RPM_PER_USER),
        reason: null,
      };
    } else {
      capacity = {
        status: 'INSUFFICIENT_DATA',
        cpuMsPerRequest: null,
        backgroundCpuMs: null,
        windows: fit.windows,
        busyWindows: fit.busyWindows,
        uMax: F.U_MAX,
        maxRpm: null,
        alertRpm,
        estimatedMaxUsers: null,
        reason: fit.reason,
      };
    }

    const mem = process.memoryUsage();
    const heap = v8.getHeapStatistics();
    const toMb = (b) => Math.round(b / 1024 / 1024);
    const ramLimitMb = specs.ramTotalMb || null;
    const memory = {
      rssMb: toMb(mem.rss),
      ramLimitMb,
      rssPercent: ramLimitMb ? Math.round((toMb(mem.rss) / ramLimitMb) * 100) : null,
      heapUsedMb: toMb(heap.used_heap_size),
      heapLimitMb: toMb(heap.heap_size_limit),
      heapPercent: heap.heap_size_limit > 0 ? Math.round((heap.used_heap_size / heap.heap_size_limit) * 100) : null,
    };

    let database = null;
    try {
      const { defaultDbBulkhead } = require('../../core/resilience/db-bulkhead');
      const st = defaultDbBulkhead.getStats();
      database = {
        activeConnections: (st.activeClientConnections || 0) + (st.activeAdminConnections || 0),
        maxConnections: st.maxConnections || null,
      };
    } catch (_) {}

    const recommendation = {
      OPTIMAL: 'Năng lực CPU ước tính đáp ứng ngưỡng cảnh báo lưu lượng hiện tại.',
      WARNING: 'Ngưỡng cảnh báo lưu lượng vượt mức sử dụng CPU mục tiêu 70%; độ trễ sẽ tăng khi tải chạm ngưỡng.',
      OVER_CAPACITY: 'Ngưỡng cảnh báo lưu lượng vượt năng lực CPU ước tính; cần tăng hạn mức CPU hoặc giảm chi phí xử lý mỗi yêu cầu.',
      INSUFFICIENT_DATA: 'Chưa đủ dữ liệu đo để ước lượng năng lực (cần ≥ 30 cửa sổ 10 giây, ≥ 10 cửa sổ có yêu cầu và lưu lượng có độ trải).',
    }[capacity.status];

    return {
      targetConcurrency: this.detector.targetConcurrency,
      serverSpecs: {
        cpuCores: specs.cpuCores ?? null,
        cpuQuotaHard: Boolean(specs.cpuQuotaHard),
        cpuSource: specs.source || null,
        effectiveCores: Math.min(1, quotaCores > 0 ? quotaCores : 1),
        totalRamMb: ramLimitMb,
        platform: process.platform,
        arch: process.arch,
      },
      trafficBaseline: { baselineRpm: ind.traffic.baselineRpm, alertRpm, source: ind.traffic.source },
      capacity,
      memory,
      database,
      capacityAssessment: {
        status: capacity.status,
        isOverCapacity: capacity.status === 'OVER_CAPACITY',
        isNearLimit: capacity.status === 'WARNING',
        recommendation,
      },
      calibratedAt: new Date().toISOString(),
    };
  }

  /**
   * Hiệu chuẩn: đặt quy mô N / ngưỡng tuỳ chỉnh (chỉ các khoá được gửi), lưu vào aiops_setting,
   * rồi dựng báo cáo năng lực. Không chốt cửa sổ đo, không xoá đường nền.
   */
  async calibrate(options = {}) {
    const allowed = Object.keys(this.detector.getCustomThresholds());
    const custom = options.customThresholds && typeof options.customThresholds === 'object'
      ? Object.fromEntries(Object.entries(options.customThresholds).filter(([k, v]) => allowed.includes(k) && Number(v) > 0).map(([k, v]) => [k, Number(v)]))
      : null;
    const target = Number(options.targetConcurrency) >= 100 ? Number(options.targetConcurrency) : null;
    const reset = options.resetThresholds === true;

    // "Về mặc định": xoá mọi ngưỡng tuỳ chỉnh trước, rồi mới gộp ngưỡng gửi kèm (nếu có).
    if (reset) {
      this.detector.setCustomThresholds(Object.fromEntries(allowed.map((k) => [k, null])));
    }
    this.detector.calibrate({ targetConcurrency: target, customThresholds: custom });
    if (target && this.collector && typeof this.collector.setTargetConcurrency === 'function') {
      this.collector.setTargetConcurrency(this.detector.targetConcurrency);
    }

    const save = async (key, value) => {
      if (!this.repository || typeof this.repository.setSetting !== 'function') return;
      try {
        await this.repository.setSetting(key, value);
      } catch (err) {
        logger.error(`[AIOps] Lỗi lưu ${key} vào CSDL`, { error: err.message });
      }
    };
    if (reset || (custom && Object.keys(custom).length > 0)) {
      await save('custom_vector_thresholds', JSON.stringify(this.detector.getCustomThresholds()));
    }
    if (target) {
      await save('target_concurrency', String(this.detector.targetConcurrency));
    }

    const report = this.buildCapacityReport();
    if (report.capacity.cpuMsPerRequest !== null) {
      await save('capacity_estimate', JSON.stringify({
        cpuMsPerRequest: report.capacity.cpuMsPerRequest,
        backgroundCpuMs: report.capacity.backgroundCpuMs,
        windows: report.capacity.windows,
        calibratedAt: report.calibratedAt,
      }));
    }

    const sample = this._peekSample();
    if (sample) {
      const evalResult = this.detector.evaluate(sample);
      this._currentStatus = {
        ...this._currentStatus,
        threatScore: evalResult.threatScore,
        status: evalResult.status,
        vectorScores: evalResult.vectorScores,
        vectorDefenses: evalResult.vectorDefenses,
        isAnomaly: evalResult.isAnomaly,
        anomalies: evalResult.anomalies,
        recommendedAction: evalResult.recommendedAction,
        lastEvaluatedAt: evalResult.evaluatedAt,
        indicators: evalResult.indicators,
        sample,
        targetConcurrency: this.detector.targetConcurrency,
        customThresholds: this.detector.getCustomThresholds(),
      };
    }

    logger.info(`[AIOps] Hiệu chuẩn: năng lực ${report.capacity.status}, RPM tối đa ${report.capacity.maxRpm ?? 'chưa đủ dữ liệu'}`);
    return {
      success: true,
      message: 'Đã hiệu chuẩn và lưu ngưỡng; báo cáo năng lực tính theo Luật sử dụng trên số đo thật.',
      data: report,
      status: this._currentStatus,
    };
  }
}

const defaultAIOpsService = new AIOpsService();

module.exports = {
  AIOpsService,
  defaultAIOpsService,
};
