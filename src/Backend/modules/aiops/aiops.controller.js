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
      const history = defaultAIOpsService.getHistory();
      return ResponseHandler.success(res, history, 'Lịch sử chỉ số AIOps Sentinel');
    } catch (error) {
      logger.error('[AIOpsController] getHistory failed', { error: error.message });
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
};

module.exports = aiopsController;
