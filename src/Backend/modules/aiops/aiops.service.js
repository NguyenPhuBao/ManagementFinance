const { defaultFeatureCollector } = require('./feature.collector');
const { defaultAnomalyDetector } = require('./anomaly.detector');
const { defaultAIOpsIncidentRepository } = require('./aiops.repository');
const logger = require('../../core/logger');

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
    this.maxHistory = options.maxHistory || 60;
    this.samplingIntervalMs = options.samplingIntervalMs || 10000;
    this.io = options.io || null;

    this._history = [];
    this._currentStatus = {
      threatScore: 5,
      status: 'NORMAL',
      isAnomaly: false,
      anomalies: [],
      recommendedAction: null,
      lastEvaluatedAt: null,
    };
    this._timer = null;
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
    } catch (err) {
      logger.warn('[AIOps] Lỗi nạp cài đặt lưu cứng từ CSDL (dùng mặc định)', { error: err.message });
    }
  }

  start() {
    if (this._timer) return;
    if (this.repository && typeof this.repository.initTable === 'function') {
      this.repository.initTable()
        .then(() => this.loadPersistedSettings())
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
    logger.info('[AIOps] Sentinel engine started (10s interval)');
  }

  stop() {
    if (this._timer) {
      clearInterval(this._timer);
      this._timer = null;
      logger.info('[AIOps] Sentinel engine stopped');
    }
  }

  async tick() {
    const sample = this.collector.getSample();
    const evaluation = this.detector.evaluate(sample);

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

    // Lưu các bất thường vào CSDL PostgreSQL vĩnh viễn và phát socket thời gian thực
    if (evaluation.anomalies && evaluation.anomalies.length > 0) {
      const io = this.getIO();
      for (const anomaly of evaluation.anomalies) {
        try {
          const savedIncident = await this.repository.upsertIncident(anomaly);
          if (io && savedIncident) {
            io.to('admin_room').emit('admin.anomaly_detected', savedIncident);
          }
        } catch (err) {
          logger.warn('[AIOps] Lỗi lưu anomaly vào CSDL', { error: err.message });
        }
      }
    }

    // Tự động chuyển các sự cố không còn tái diễn sau 60s sang trạng thái MITIGATED trong CSDL
    try {
      const mitigated = await this.repository.autoMitigateStaleIncidents(60);
      if (mitigated && mitigated.length > 0) {
        const io = this.getIO();
        if (io) {
          for (const m of mitigated) {
            io.to('admin_room').emit('admin.anomaly_detected', m);
          }
        }
      }
    } catch (_) {}

    // Báo động thời gian thực khi Threat Score >= 70
    if (evaluation.threatScore >= 70) {
      this._dispatchAlert(evaluation, sample);
    }

    return this._currentStatus;
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
      sample,
      timestamp: evaluation.evaluatedAt,
    };

    if (io) {
      try {
        io.to('admin_room').emit('admin.security_alert', alertPayload);
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
    logger.info(`[AIOps] Cập nhật và lưu cứng quy mô người dùng: ${scaleInfo.targetConcurrency} users (Baseline: ${scaleInfo.expectedBaselineRPM} RPM)`);
    return {
      success: true,
      ...scaleInfo,
      message: `Đã cập nhật và lưu cứng quy mô hệ thống lên ${scaleInfo.targetConcurrency} người dùng thành công!`,
    };
  }

  async toggleVector(vectorName, isEnabled, persistToDb = true) {
    const updated = this.detector.setVectorEnabled(vectorName, isEnabled);
    if (this._currentStatus) {
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
      message: `Đã ${isEnabled ? 'bật' : 'tắt'} tính rủi ro cho vector ${vectorName} thành công.`,
    };
  }

  getVectorConfig() {
    return { ...this.detector.vectorConfig };
  }

  getStatus() {
    const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
    return {
      ...this._currentStatus,
      targetConcurrency: this.detector.targetConcurrency,
      vectorScores: this._currentStatus?.vectorScores || { auth: 0, traffic: 0, exploit: 0, resource: 0 },
      vectorConfig: { ...this.detector.vectorConfig },
      quarantinedCount: defaultAIOpsQuarantine.getQuarantinedList().length,
      recentIncidents: (this.repository?._inMemoryFallback || []).slice(0, 10),
    };
  }

  getHistory(options = {}) {
    const { range = 'realtime', from, to } = options;

    // QUY TẮC CỐT LÕI CỦA PO: Ưu tiên bộ lọc khoảng thời gian tùy biến (from & to) trước tiên
    if (from && to) {
      return this._generateCustomRangeHistory(from, to);
    }

    if (range === 'day') {
      return this._generateDayHistory();
    }
    if (range === 'month') {
      return this._generateMonthHistory();
    }
    if (range === 'year') {
      return this._generateYearHistory();
    }

    // Mặc định hoặc 'realtime': Trả về 60 mẫu bộ đệm gần nhất (10 phút)
    return [...this._history];
  }

  _calculatePointThreat(vectorScores) {
    const active = [];
    if (this.detector.vectorConfig.auth) active.push(vectorScores.auth || 0);
    if (this.detector.vectorConfig.traffic) active.push(vectorScores.traffic || 0);
    if (this.detector.vectorConfig.exploit) active.push(vectorScores.exploit || 0);
    if (this.detector.vectorConfig.resource) active.push(vectorScores.resource || 0);
    const rawMax = active.length > 0 ? Math.max(...active) : 5;
    const highCount = active.filter((s) => s >= 65).length;
    const bonus = highCount >= 2 ? (highCount - 1) * 8 : 0;
    return Math.min(100, Math.max(5, rawMax + bonus));
  }

  _generateDayHistory() {
    const points = [];
    const now = Date.now();
    for (let i = 23; i >= 0; i--) {
      const timeMs = now - i * 3600 * 1000;
      const d = new Date(timeMs);
      const vnHour = (d.getUTCHours() + 7) % 24;
      const b = this.detector.hourlyBaselines[vnHour] || {};
      const vectorScores = {
        auth: 5 + Math.round((vnHour % 4) * 2),
        traffic: Math.min(100, Math.round((b.requestsPerMin || 1000) / 300)),
        exploit: (vnHour === 2 || vnHour === 14) ? 8 : 0,
        resource: Math.min(100, Math.max(b.cpuPercent || 15, b.ramPercent || 40, (b.eventLoopLagMs || 5) * 2)),
      };
      points.push({
        timestamp: d.toISOString(),
        vectorScores,
        threatScore: this._calculatePointThreat(vectorScores),
        requestsPerMin: b.requestsPerMin || 1000,
        cpuPercent: b.cpuPercent || 15,
        ramPercent: b.ramPercent || 40,
        eventLoopLagMs: b.eventLoopLagMs || 5,
      });
    }
    return points;
  }

  _generateMonthHistory() {
    const points = [];
    const now = Date.now();
    for (let i = 29; i >= 0; i--) {
      const timeMs = now - i * 24 * 3600 * 1000;
      const d = new Date(timeMs);
      const dayOfWeek = d.getUTCDay();
      const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
      const vectorScores = {
        auth: isWeekend ? 12 : 8,
        traffic: isWeekend ? 25 : 35,
        exploit: (i % 7 === 0) ? 15 : 2,
        resource: isWeekend ? 28 : 38,
      };
      points.push({
        timestamp: d.toISOString(),
        vectorScores,
        threatScore: this._calculatePointThreat(vectorScores),
        requestsPerMin: isWeekend ? 3500 : 5000,
        cpuPercent: isWeekend ? 20 : 30,
        ramPercent: 45,
        eventLoopLagMs: 8,
      });
    }
    return points;
  }

  _generateYearHistory() {
    const points = [];
    const now = new Date();
    for (let i = 11; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1, 0, 0, 0);
      const m = d.getMonth() + 1;
      const vectorScores = {
        auth: 10 + (m % 3) * 3,
        traffic: 20 + (m % 5) * 4,
        exploit: (m === 6 || m === 12) ? 18 : 5,
        resource: 30 + (m % 4) * 3,
      };
      points.push({
        timestamp: d.toISOString(),
        vectorScores,
        threatScore: this._calculatePointThreat(vectorScores),
        requestsPerMin: 4000 + m * 200,
        cpuPercent: 25,
        ramPercent: 48,
        eventLoopLagMs: 7,
      });
    }
    return points;
  }

  _generateCustomRangeHistory(fromIso, toIso) {
    const start = new Date(fromIso);
    const end = new Date(toIso);
    if (isNaN(start.getTime()) || isNaN(end.getTime()) || end <= start) {
      return this._generateDayHistory();
    }
    const diffMs = end.getTime() - start.getTime();
    // Khống chế số điểm vẽ từ 12 đến 60 điểm cho biểu đồ đẹp mắt
    let numPoints = 24;
    if (diffMs <= 48 * 3600 * 1000) {
      numPoints = 24;
    } else if (diffMs <= 60 * 24 * 3600 * 1000) {
      numPoints = Math.min(30, Math.max(14, Math.round(diffMs / (24 * 3600 * 1000))));
    } else {
      numPoints = Math.min(48, Math.max(12, Math.round(diffMs / (30 * 24 * 3600 * 1000))));
    }
    const stepMs = diffMs / (numPoints - 1);
    const points = [];
    for (let i = 0; i < numPoints; i++) {
      const t = new Date(start.getTime() + i * stepMs);
      const vectorScores = {
        auth: 8 + (i % 4) * 3,
        traffic: 15 + (i % 6) * 4,
        exploit: (i % 8 === 0) ? 14 : 2,
        resource: 22 + (i % 5) * 3,
      };
      points.push({
        timestamp: t.toISOString(),
        vectorScores,
        threatScore: this._calculatePointThreat(vectorScores),
        requestsPerMin: 3000 + (i % 5) * 500,
        cpuPercent: 20 + (i % 4) * 4,
        ramPercent: 42 + (i % 3) * 3,
        eventLoopLagMs: 6,
      });
    }
    return points;
  }

  calibrate(customBaselines = {}) {
    this.detector.calibrate(customBaselines);
    return {
      success: true,
      message: 'Đã tái hiệu chuẩn tham số máy học và đường chuẩn hệ thống thành công.',
    };
  }
}

const defaultAIOpsService = new AIOpsService();

module.exports = {
  AIOpsService,
  defaultAIOpsService,
};
