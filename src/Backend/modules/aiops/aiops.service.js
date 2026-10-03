const { defaultFeatureCollector } = require('./feature.collector');
const { defaultAnomalyDetector } = require('./anomaly.detector');
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

  start() {
    if (this._timer) return;
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

    // Nếu mức độ CRITICAL (threatScore >= 85) và cách lần gửi trước tối thiểu 5 phút
    const now = Date.now();
    if (evaluation.threatScore >= 85 && now - this._lastAlertTime > 5 * 60 * 1000) {
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

  getStatus() {
    return this._currentStatus;
  }

  getHistory() {
    return [...this._history];
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
