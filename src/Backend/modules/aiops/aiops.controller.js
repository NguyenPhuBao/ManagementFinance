const { defaultAIOpsService } = require('./aiops.service');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const aiopsController = {
  getStatus(req, res) {
    try {
      const status = defaultAIOpsService.getStatus();
      return ResponseHandler.success(res, status, 'Trạng thái AIOps Sentinel thời gian thực');
    } catch (error) {
      logger.error('[AIOpsController] getStatus failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  getHistory(req, res) {
    try {
      const { range, from, to } = req.query;
      const history = defaultAIOpsService.getHistory({ range, from, to });
      return ResponseHandler.success(res, history, 'Lịch sử chỉ số AIOps Sentinel');
    } catch (error) {
      logger.error('[AIOpsController] getHistory failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async toggleVector(req, res) {
    try {
      const { vector, enabled } = req.body;
      if (!vector || !['auth', 'traffic', 'exploit', 'resource'].includes(vector)) {
        return ResponseHandler.error(res, 'Vui lòng cung cấp tên vector hợp lệ (auth, traffic, exploit, resource)', 400);
      }
      const isEnabled = enabled !== undefined ? Boolean(enabled) : true;
      const result = await defaultAIOpsService.toggleVector(vector, isEnabled);
      req.auditActionName = `${isEnabled ? 'Bật' : 'Tắt'} tính rủi ro vector AIOps [${vector}]`;
      return ResponseHandler.success(res, result, result.message);
    } catch (error) {
      logger.error('[AIOpsController] toggleVector failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  getVectorConfig(req, res) {
    try {
      const config = defaultAIOpsService.getVectorConfig();
      return ResponseHandler.success(res, config, 'Cấu hình bật tắt 4 vector rủi ro');
    } catch (error) {
      logger.error('[AIOpsController] getVectorConfig failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  calibrate(req, res) {
    try {
      const result = defaultAIOpsService.calibrate(req.body);
      req.auditActionName = 'Tái hiệu chuẩn mô hình máy học AIOps';
      return ResponseHandler.success(res, result, 'Hiệu chuẩn thành công');
    } catch (error) {
      logger.error('[AIOpsController] calibrate failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  getQuarantineList(req, res) {
    try {
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const list = defaultAIOpsQuarantine.getQuarantinedList();
      return ResponseHandler.success(res, list, 'Danh sách nguồn IP đang bị cô lập');
    } catch (error) {
      logger.error('[AIOpsController] getQuarantineList failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  unblockQuarantine(req, res) {
    try {
      const { hash } = req.params;
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const unblocked = defaultAIOpsQuarantine.unblock(hash);
      if (!unblocked) {
        return ResponseHandler.notFound(res, 'Không tìm thấy nguồn IP tương ứng trong danh sách cô lập');
      }
      req.auditActionName = `Gỡ chặn IP cô lập (${hash})`;
      return ResponseHandler.success(res, { hash, unblocked: true }, 'Đã gỡ chặn nguồn IP thành công');
    } catch (error) {
      logger.error('[AIOpsController] unblockQuarantine failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  quarantineActor(req, res) {
    try {
      const { hash, ip, maskedIp, reason, durationMinutes } = req.body;
      if (!hash && !ip) {
        return ResponseHandler.error(res, 'Thiếu thông tin nhận diện đối tượng cần phong tỏa (IP hoặc Hash)', 400);
      }
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const durationMs = (parseInt(durationMinutes, 10) || 15) * 60 * 1000;
      const record = defaultAIOpsQuarantine.quarantineActor({
        rawIp: ip,
        ipHash: hash,
        maskedIp,
        reason: reason || 'Admin chủ động phong tỏa từ nhật ký RCA',
        durationMs,
      });
      if (!record) {
        return ResponseHandler.error(res, 'Không thể phong tỏa nguồn request này', 400);
      }
      req.auditActionName = `Phong tỏa IP thủ công (${record.maskedIp || hash})`;
      return ResponseHandler.success(res, record, `Đã phong tỏa nguồn IP ${record.maskedIp} thành công trong ${Math.round(durationMs / 60000)} phút`);
    } catch (error) {
      logger.error('[AIOpsController] quarantineActor failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async setScale(req, res) {
    try {
      const { concurrency } = req.body;
      const result = await defaultAIOpsService.setConcurrencyScale(concurrency);
      req.auditActionName = `Cập nhật quy mô tải AIOps (${result.targetConcurrency} users)`;
      return ResponseHandler.success(res, result, result.message);
    } catch (error) {
      logger.error('[AIOpsController] setScale failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getIncidents(req, res) {
    try {
      const { page, limit, vector, status, search } = req.query;
      const { defaultAIOpsIncidentRepository } = require('./aiops.repository');
      const result = await defaultAIOpsIncidentRepository.getIncidents({ page, limit, vector, status, search });
      return ResponseHandler.success(res, result, 'Danh sách sự cố bất thường từ CSDL');
    } catch (error) {
      logger.error('[AIOpsController] getIncidents failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async clearIncidents(req, res) {
    try {
      const { defaultAIOpsIncidentRepository } = require('./aiops.repository');
      await defaultAIOpsIncidentRepository.clearIncidents();
      req.auditActionName = 'Làm sạch nhật ký sự cố AIOps Sentinel';
      return ResponseHandler.success(res, { cleared: true }, 'Đã xóa toàn bộ nhật ký sự cố');
    } catch (error) {
      logger.error('[AIOpsController] clearIncidents failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },
};

module.exports = aiopsController;
