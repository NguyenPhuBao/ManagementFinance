const { defaultAIOpsService } = require('./aiops.service');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const aiopsController = {
  getStatus(req, res) {
    try {
      const clientIp = req.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || req.socket?.remoteAddress;
      const status = defaultAIOpsService.getStatus();
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const isClientProtected = defaultAIOpsQuarantine && typeof defaultAIOpsQuarantine.isProtectedIp === 'function'
        ? defaultAIOpsQuarantine.isProtectedIp(clientIp)
        : false;

      const enrichedStatus = {
        ...status,
        currentClientIp: clientIp || null,
        isClientProtected,
      };

      return ResponseHandler.success(res, enrichedStatus, 'Trạng thái AIOps Sentinel thời gian thực');
    } catch (error) {
      logger.error('[AIOpsController] getStatus failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getHistory(req, res) {
    try {
      const { range, from, to } = req.query;
      const history = await defaultAIOpsService.getHistory({ range, from, to });
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

  async calibrate(req, res) {
    try {
      const result = await defaultAIOpsService.calibrate(req.body);
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
      const { page, limit, vector, status, search, range, from, to } = req.query;
      const { defaultAIOpsIncidentRepository } = require('./aiops.repository');
      const result = await defaultAIOpsIncidentRepository.getIncidents({ page, limit, vector, status, search, range, from, to });
      return ResponseHandler.success(res, result, 'Danh sách sự cố bất thường từ CSDL');
    } catch (error) {
      logger.error('[AIOpsController] getIncidents failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async clearIncidents(req, res) {
    return ResponseHandler.error(res, 'Chức năng làm sạch nhật ký đã bị vô hiệu hóa để bảo đảm tính toàn vẹn và bất biến của CSDL an ninh', 403);
  },

  async unblockIp(req, res) {
    try {
      const { ipHash, ip } = req.body;
      const target = ipHash || ip;
      if (!target) {
        return ResponseHandler.error(res, 'Vui lòng cung cấp ipHash hoặc ip cần gỡ chặn', 400);
      }
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const count = await defaultAIOpsQuarantine.unblockIp(target, { unblockedBy: adminUser });
      req.auditActionName = `Gỡ chặn IP [${target}] (${count} liên kết)`;
      return ResponseHandler.success(res, { count, target }, 'Đã mở khóa IP thành công cho tất cả các bản ghi');
    } catch (error) {
      logger.error('[AIOpsController] unblockIp failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async permanentBanIp(req, res) {
    try {
      const { ipHash, ip } = req.body;
      const target = ipHash || ip;
      if (!target) {
        return ResponseHandler.error(res, 'Vui lòng cung cấp ipHash hoặc ip cần tạm khóa', 400);
      }
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      // Chuyển hóa sang tạm khóa 4 giờ theo chính sách mới của PO
      const count = await defaultAIOpsQuarantine.temporaryBlockIp(target, {
        durationMs: 4 * 60 * 60 * 1000,
        blockedBy: adminUser,
        reason: 'Admin tạm khóa IP 4 giờ (Chính sách không khóa vĩnh viễn IP mạng dùng chung CGNAT)'
      });
      req.auditActionName = `Tạm khóa IP [${target}] (4 giờ - Chính sách thay thế khóa vĩnh viễn)`;
      return ResponseHandler.success(res, { count, target, durationMs: 4 * 60 * 60 * 1000, status: 'TEMPORARY' }, 'Hệ thống đã tạm khóa IP trong 4 giờ (Chính sách an ninh không khóa vĩnh viễn IP để bảo vệ người dùng mạng dùng chung)');
    } catch (error) {
      logger.error('[AIOpsController] permanentBanIp failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async unblockAccount(req, res) {
    try {
      const { username, idaccount } = req.body;
      if (!username && !idaccount) {
        return ResponseHandler.error(res, 'Thiếu thông tin nhận diện tài khoản (username hoặc idaccount)', 400);
      }
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const target = username || idaccount;
      const count = await defaultAIOpsQuarantine.unblockAccount(target, { unblockedBy: adminUser });

      // Tác động thực tế CSDL (Tầng 2 System Impact): Kích hoạt lại tài khoản trong database
      try {
        const { prisma } = require('../../config/db');
        const where = {};
        if (username) where.username = String(username).trim();
        if (idaccount) where.idaccount = Number(idaccount);
        await prisma.account.updateMany({
          where,
          data: {
            status: 'Active',
            reason_inactive: null,
          },
        });
      } catch (dbErr) {
        logger.warn('[AIOpsController] Cập nhật DB khi mở khóa tài khoản gặp cảnh báo', { error: dbErr.message });
      }

      req.auditActionName = `Mở khóa tài khoản [${target}] (${count} liên kết)`;
      return ResponseHandler.success(res, { count, target }, 'Đã mở khóa tài khoản thành công cho tất cả các bản ghi');
    } catch (error) {
      logger.error('[AIOpsController] unblockAccount failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async permanentBanAccount(req, res) {
    try {
      const { username, idaccount } = req.body;
      if (!username && !idaccount) {
        return ResponseHandler.error(res, 'Thiếu thông tin nhận diện tài khoản (username hoặc idaccount)', 400);
      }
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const target = username || idaccount;
      const count = await defaultAIOpsQuarantine.permanentBanAccount(target, { bannedBy: adminUser });

      req.auditActionName = `Khóa vĩnh viễn tài khoản [${target}] (${count} liên kết)`;
      return ResponseHandler.success(res, { count, target }, 'Đã khóa vĩnh viễn tài khoản thành công cho tất cả các bản ghi');
    } catch (error) {
      logger.error('[AIOpsController] permanentBanAccount failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async temporaryBlockIp(req, res) {
    try {
      const { ipHash, ip, durationMinutes } = req.body;
      const target = ipHash || ip;
      if (!target) {
        return ResponseHandler.error(res, 'Vui lòng cung cấp ipHash hoặc ip cần tạm khóa', 400);
      }
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const durationMs = durationMinutes ? parseInt(durationMinutes, 10) * 60 * 1000 : 4 * 60 * 60 * 1000;
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const count = await defaultAIOpsQuarantine.temporaryBlockIp(target, { durationMs, blockedBy: adminUser });
      req.auditActionName = `Tạm khóa IP [${target}] (${Math.round(durationMs / 3600000)} giờ)`;
      return ResponseHandler.success(res, { count, target, durationMs }, `Đã tạm khóa IP thành công (${Math.round(durationMs / 3600000)} giờ)`);
    } catch (error) {
      logger.error('[AIOpsController] temporaryBlockIp failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async temporaryBlockAccount(req, res) {
    try {
      const { username, idaccount, durationMinutes } = req.body;
      if (!username && !idaccount) {
        return ResponseHandler.error(res, 'Thiếu thông tin nhận diện tài khoản (username hoặc idaccount)', 400);
      }
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const durationMs = durationMinutes ? parseInt(durationMinutes, 10) * 60 * 1000 : 4 * 60 * 60 * 1000;
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const target = username || idaccount;
      const count = await defaultAIOpsQuarantine.temporaryBlockAccount(target, { durationMs, blockedBy: adminUser });

      req.auditActionName = `Tạm khóa tài khoản [${target}] (${Math.round(durationMs / 3600000)} giờ)`;
      return ResponseHandler.success(res, { count, target, durationMs }, `Đã tạm khóa tài khoản thành công (${Math.round(durationMs / 3600000)} giờ)`);
    } catch (error) {
      logger.error('[AIOpsController] temporaryBlockAccount failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getQuarantineForensics(req, res) {
    try {
      const { ipHash, username, page, limit } = req.query;
      const { defaultAIOpsQuarantineRepository } = require('./aiops.quarantine.repository');
      const result = await defaultAIOpsQuarantineRepository.getForensicInvestigationLogs({
        ipHash,
        username,
        page,
        limit,
      });
      return ResponseHandler.success(res, result, 'Hồ sơ điều tra an ninh AIOps');
    } catch (error) {
      logger.error('[AIOpsController] getQuarantineForensics failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },
};

module.exports = aiopsController;
