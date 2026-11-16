const { defaultAIOpsService } = require('./aiops.service');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');
const { getClientIp } = require('../../utils/ip-protection.util');

// Mọi thao tác ghi trên trang AIOps đòi PIN, máy chủ kiểm (mục 2.3 kế hoạch sửa trang AIOps).
async function requirePin(req, action, targetId) {
  const { pin, password } = req.body || {};
  const adminService = require('../admin/admin.service');
  await adminService.verifySecurityAction({ pin, password, action, targetId: String(targetId ?? 'N/A') }, req.user);
}

const withoutPin = (body = {}) => {
  const { pin: _pin, password: _password, ...rest } = body || {};
  return rest;
};

const fail = (res, error, fallbackLog) => {
  if (!error.statusCode) logger.error(fallbackLog, { error: error.message });
  return ResponseHandler.error(res, error.message, error.statusCode || 500, null, error.code || null);
};

// Không ai khoá được tài khoản quản trị gốc (Phần 3); admin không tự khoá tài khoản của chính mình (mục 2.4);
// khoá admin khác thì được.
async function rejectSelfLock(req, target) {
  const me = req.user;
  if (target === undefined || target === null || target === '') return;
  const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
  const acc = await defaultAIOpsQuarantine._resolveAccount(target);
  if (acc && require('../auth/root-admin').isRootAccount(acc)) {
    throw Object.assign(new Error('Không thể khóa tài khoản quản trị gốc'), { statusCode: 403, code: 'ROOT_ACCOUNT_PROTECTED' });
  }
  if (!me) return;
  const t = String(target).trim().toLowerCase();
  const self = t === String(me.username || '').toLowerCase() || t === String(me.idaccount)
    || (Boolean(acc) && Number(acc.idaccount) === Number(me.idaccount));
  if (self) {
    throw Object.assign(new Error('Không thể tự khóa tài khoản của chính mình'), { statusCode: 403, code: 'CANNOT_LOCK_SELF' });
  }
}

const aiopsController = {
  getStatus(req, res) {
    try {
      const clientIp = getClientIp(req);
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
      await requirePin(req, 'AIOPS_TOGGLE_VECTOR', vector);
      const result = await defaultAIOpsService.toggleVector(vector, isEnabled);
      req.auditActionName = `${isEnabled ? 'Bật' : 'Tắt'} tính rủi ro vector AIOps [${vector}]`;
      return ResponseHandler.success(res, result, result.message);
    } catch (error) {
      return fail(res, error, '[AIOpsController] toggleVector failed');
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
      await requirePin(req, 'AIOPS_CALIBRATE', req.body?.targetConcurrency);
      const result = await defaultAIOpsService.calibrate(withoutPin(req.body));
      req.auditActionName = 'Tái hiệu chuẩn mô hình máy học AIOps';
      return ResponseHandler.success(res, result, 'Hiệu chuẩn thành công');
    } catch (error) {
      return fail(res, error, '[AIOpsController] calibrate failed');
    }
  },

  async getQuarantineList(req, res) {
    try {
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const list = await defaultAIOpsQuarantine.listQuarantines();
      return ResponseHandler.success(res, list, 'Danh sách nguồn IP đang bị cô lập');
    } catch (error) {
      logger.error('[AIOpsController] getQuarantineList failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async revealQuarantineIp(req, res) {
    try {
      const { hash } = req.params;
      if (!hash) return ResponseHandler.badRequest(res, 'Tham số không hợp lệ');
      req.auditActionName = `Xem IP đầy đủ của nguồn bị cô lập (${hash.slice(0, 12)})`;
      const { pin, password } = req.body || {};
      const adminService = require('../admin/admin.service');
      await adminService.verifySecurityAction(
        { pin, password, action: 'REVEAL_IP', targetId: `aiops-ip#${hash}` },
        req.user
      );
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const ip = await defaultAIOpsQuarantine.revealFullIp(hash);
      if (!ip) return ResponseHandler.notFound(res, 'IP đầy đủ không còn lưu (đã quá thời hạn lưu trữ) hoặc không tồn tại');
      res.set?.('Cache-Control', 'no-store');
      return ResponseHandler.success(res, { ip }, 'IP đầy đủ của nguồn bị cô lập');
    } catch (error) {
      logger.warn('[AIOpsController] revealQuarantineIp failed', { error: error.message });
      return ResponseHandler.error(res, error.message, error.statusCode || 500);
    }
  },

  async quarantineActor(req, res) {
    try {
      const { hash, ip, maskedIp, reason, durationMinutes, username } = req.body;
      if (!hash && !ip) {
        return ResponseHandler.error(res, 'Thiếu thông tin nhận diện đối tượng cần phong tỏa (IP hoặc Hash)', 400);
      }
      await requirePin(req, 'AIOPS_QUARANTINE', maskedIp || hash || 'ip');
      if (username) await rejectSelfLock(req, username);
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const durationMs = (parseInt(durationMinutes, 10) || 15) * 60 * 1000;
      const record = await defaultAIOpsQuarantine.quarantineActor({
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
      const { ip: _fullIp, ...publicRecord } = record;
      return ResponseHandler.success(res, publicRecord, `Đã phong tỏa nguồn IP ${record.maskedIp} thành công trong ${Math.round(durationMs / 60000)} phút`);
    } catch (error) {
      return fail(res, error, '[AIOpsController] quarantineActor failed');
    }
  },

  async setScale(req, res) {
    try {
      const { concurrency } = req.body;
      await requirePin(req, 'AIOPS_SET_SCALE', concurrency);
      const result = await defaultAIOpsService.setConcurrencyScale(concurrency);
      req.auditActionName = `Cập nhật quy mô tải AIOps (${result.targetConcurrency} users)`;
      return ResponseHandler.success(res, result, result.message);
    } catch (error) {
      return fail(res, error, '[AIOpsController] setScale failed');
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

  async unblockIp(req, res) {
    try {
      const { ipHash, ip } = req.body;
      const target = ipHash || ip;
      if (!target) {
        return ResponseHandler.error(res, 'Vui lòng cung cấp ipHash hoặc ip cần gỡ chặn', 400);
      }
      await requirePin(req, 'AIOPS_UNBLOCK_IP', target);
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const count = await defaultAIOpsQuarantine.unblockIp(target, { unblockedBy: adminUser });
      req.auditActionName = `Gỡ chặn IP [${target}] (${count} liên kết)`;
      return ResponseHandler.success(res, { count, target }, 'Đã mở khóa IP thành công cho tất cả các bản ghi');
    } catch (error) {
      return fail(res, error, '[AIOpsController] unblockIp failed');
    }
  },

  // "Khóa thêm 4 giờ" cho IP. IP không có khoá vĩnh viễn.
  async extendIp(req, res) {
    try {
      const { ipHash, ip } = req.body;
      const target = ipHash || ip;
      if (!target) {
        return ResponseHandler.error(res, 'Vui lòng cung cấp ipHash hoặc ip cần khóa thêm', 400);
      }
      await requirePin(req, 'AIOPS_EXTEND_IP', target);
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const count = await defaultAIOpsQuarantine.extendIp(target, { blockedBy: adminUser });
      req.auditActionName = `Khóa thêm 4 giờ IP [${target}]`;
      return ResponseHandler.success(res, { count, target, durationMs: 4 * 60 * 60 * 1000, status: 'TEMPORARY' }, 'Đã khóa thêm IP 4 giờ');
    } catch (error) {
      return fail(res, error, '[AIOpsController] extendIp failed');
    }
  },

  // Route cũ /quarantine/permanent-ip: giữ để Admin-web bản cũ không vỡ trong lúc deploy lệch nhau.
  async permanentBanIp(req, res) {
    return aiopsController.extendIp(req, res);
  },

  async unblockAccount(req, res) {
    try {
      const { username, idaccount } = req.body;
      if (!username && !idaccount) {
        return ResponseHandler.error(res, 'Thiếu thông tin nhận diện tài khoản (username hoặc idaccount)', 400);
      }
      const target = username || idaccount;
      await requirePin(req, 'AIOPS_UNBLOCK_ACCOUNT', target);
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const count = await defaultAIOpsQuarantine.unblockAccount(target, { unblockedBy: adminUser });

      req.auditActionName = `Mở khóa tài khoản [${target}] (${count} liên kết)`;
      return ResponseHandler.success(res, { count, target }, 'Đã mở khóa tài khoản thành công cho tất cả các bản ghi');
    } catch (error) {
      return fail(res, error, '[AIOpsController] unblockAccount failed');
    }
  },

  async permanentBanAccount(req, res) {
    try {
      const { username, idaccount } = req.body;
      if (!username && !idaccount) {
        return ResponseHandler.error(res, 'Thiếu thông tin nhận diện tài khoản (username hoặc idaccount)', 400);
      }
      const target = username || idaccount;
      await requirePin(req, 'AIOPS_BAN_ACCOUNT', target);
      await rejectSelfLock(req, target);
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const count = await defaultAIOpsQuarantine.permanentBanAccount(target, { bannedBy: adminUser });

      req.auditActionName = `Khóa vĩnh viễn tài khoản [${target}] (${count} liên kết)`;
      return ResponseHandler.success(res, { count, target }, 'Đã khóa vĩnh viễn tài khoản thành công cho tất cả các bản ghi');
    } catch (error) {
      return fail(res, error, '[AIOpsController] permanentBanAccount failed');
    }
  },

  async temporaryBlockIp(req, res) {
    try {
      const { ipHash, ip, durationMinutes } = req.body;
      const target = ipHash || ip;
      if (!target) {
        return ResponseHandler.error(res, 'Vui lòng cung cấp ipHash hoặc ip cần tạm khóa', 400);
      }
      await requirePin(req, 'AIOPS_BLOCK_IP', target);
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const durationMs = durationMinutes ? parseInt(durationMinutes, 10) * 60 * 1000 : 4 * 60 * 60 * 1000;
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const count = await defaultAIOpsQuarantine.temporaryBlockIp(target, { durationMs, blockedBy: adminUser });
      req.auditActionName = `Tạm khóa IP [${target}] (${Math.round(durationMs / 3600000)} giờ)`;
      return ResponseHandler.success(res, { count, target, durationMs }, `Đã tạm khóa IP thành công (${Math.round(durationMs / 3600000)} giờ)`);
    } catch (error) {
      return fail(res, error, '[AIOpsController] temporaryBlockIp failed');
    }
  },

  async temporaryBlockAccount(req, res) {
    try {
      const { username, idaccount, durationMinutes } = req.body;
      if (!username && !idaccount) {
        return ResponseHandler.error(res, 'Thiếu thông tin nhận diện tài khoản (username hoặc idaccount)', 400);
      }
      const target = username || idaccount;
      await requirePin(req, 'AIOPS_BLOCK_ACCOUNT', target);
      await rejectSelfLock(req, target);
      const adminUser = req.user?.username || req.user?.email || 'Admin';
      const durationMs = durationMinutes ? parseInt(durationMinutes, 10) * 60 * 1000 : 4 * 60 * 60 * 1000;
      const { defaultAIOpsQuarantine } = require('./aiops.quarantine');
      const count = await defaultAIOpsQuarantine.temporaryBlockAccount(target, { durationMs, blockedBy: adminUser });

      req.auditActionName = `Tạm khóa tài khoản [${target}] (${Math.round(durationMs / 3600000)} giờ)`;
      return ResponseHandler.success(res, { count, target, durationMs }, `Đã tạm khóa tài khoản thành công (${Math.round(durationMs / 3600000)} giờ)`);
    } catch (error) {
      return fail(res, error, '[AIOpsController] temporaryBlockAccount failed');
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
