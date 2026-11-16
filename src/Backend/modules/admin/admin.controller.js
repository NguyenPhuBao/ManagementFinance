const adminService = require('./admin.service');
const deviceHistory = require('../auth/device-history.service');
const policyService = require('../policy/policy.service');
const preferenceService = require('./admin-preference.service');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

/** Kiểm PIN quản trị gửi kèm trong chính request thao tác (thiếu / sai → lỗi 400, khoá → 429). */
const requirePin = (req, action, targetId) =>
  adminService.verifySecurityAction({ pin: req.body?.pin, action, targetId: String(targetId ?? 'N/A') }, req.user);

/** Bỏ thông tin xác thực trước khi chuyển dữ liệu xuống service. */
const withoutPin = (body) => {
  const { pin, password, ...rest } = body || {};
  return rest;
};

const adminController = {
  async getUserDevices(req, res) {
    try {
      const iduser = parseInt(req.params.id, 10);
      if (isNaN(iduser)) return ResponseHandler.badRequest(res, 'ID người dùng không hợp lệ');
      const idaccount = await adminService.resolveAccountId(iduser);
      if (!idaccount) return ResponseHandler.notFound(res, 'Không tìm thấy người dùng');
      const devices = await deviceHistory.listDevicesForAdmin(idaccount, 10);
      return ResponseHandler.success(res, devices, 'Thiết bị đăng nhập của người dùng');
    } catch (error) {
      logger.error('getUserDevices failed', { error: error.message });
      return ResponseHandler.error(res, error.message, error.statusCode || 500);
    }
  },

  /** Cài đặt cá nhân của CHÍNH tài khoản đang đăng nhập (idaccount từ token, không nhận từ body). */
  async getMySettings(req, res) {
    try {
      const data = await preferenceService.get(req.user.idaccount);
      return ResponseHandler.success(res, data, 'Cài đặt của tài khoản');
    } catch (error) {
      logger.error('getMySettings failed', { error: error.message });
      return ResponseHandler.error(res, error.message, error.statusCode || 500);
    }
  },

  async updateMySettings(req, res) {
    try {
      const data = await preferenceService.update(req.user.idaccount, req.body);
      return ResponseHandler.success(res, data, 'Đã lưu cài đặt của tài khoản');
    } catch (error) {
      if (error.statusCode !== 400) logger.error('updateMySettings failed', { error: error.message });
      return ResponseHandler.error(res, error.message, error.statusCode || 500);
    }
  },

  async getPolicies(req, res) {
    try {
      const data = await policyService.listForAdmin();
      return ResponseHandler.success(res, data, 'Các phiên bản chính sách bảo mật');
    } catch (error) {
      logger.error('getPolicies failed', { error: error.message });
      return ResponseHandler.error(res, error.message, error.statusCode || 500);
    }
  },

  /** Thêm chính sách: `documentId` = phiên bản mới của chính sách có sẵn; không có thì `title` là chính sách mới. Tạo ở trạng thái Ngừng sử dụng. */
  async publishPolicy(req, res) {
    try {
      const { documentId, title, content, pin, password } = req.body || {};
      const draft = await policyService.publish({ documentId, title, content }, req.user?.idaccount);
      await adminService.verifySecurityAction({ pin, password, action: 'PUBLISH_POLICY', targetId: draft.title || String(draft.documentId) }, req.user);
      const created = await policyService.createVersion(draft);
      req.auditActionName = `Thêm chính sách ${policyService.label(created)} (Ngừng sử dụng)`;
      return ResponseHandler.success(res, policyService.toPublic(created), 'Đã thêm chính sách', 201);
    } catch (error) {
      if (!error.statusCode || error.statusCode >= 500) logger.error('publishPolicy failed', { error: error.message });
      return ResponseHandler.error(res, error.message, error.statusCode || 500, null, error.code || null);
    }
  },

  /** Ngừng / kích hoạt một phiên bản chính sách; bắt buộc PIN. */
  async setPolicyStatus(req, res) {
    try {
      const version = parseInt(req.params.id, 10);
      if (isNaN(version)) return ResponseHandler.badRequest(res, 'Mã chính sách không hợp lệ');
      const { status, pin, password } = req.body || {};
      policyService.assertStatus(status);
      await adminService.verifySecurityAction({ pin, password, action: 'CHANGE_POLICY_STATUS', targetId: String(version) }, req.user);
      const updated = await policyService.setStatus({ version, status, actorId: req.user?.idaccount });
      req.auditActionName = `${status === 'ACTIVE' ? 'Kích hoạt' : 'Ngừng'} chính sách ${policyService.label(updated)}`;
      return ResponseHandler.success(res, policyService.toPublic(updated), status === 'ACTIVE' ? 'Đã kích hoạt chính sách' : 'Đã ngừng chính sách');
    } catch (error) {
      if (!error.statusCode || error.statusCode >= 500) logger.error('setPolicyStatus failed', { error: error.message });
      return ResponseHandler.error(res, error.message, error.statusCode || 500, null, error.code || null);
    }
  },

  async getUserPolicy(req, res) {
    try {
      const iduser = parseInt(req.params.id, 10);
      if (isNaN(iduser)) return ResponseHandler.badRequest(res, 'ID người dùng không hợp lệ');
      const idaccount = await adminService.resolveAccountId(iduser);
      if (!idaccount) return ResponseHandler.notFound(res, 'Không tìm thấy người dùng');
      const data = await policyService.acceptancesForAccount(idaccount);
      return ResponseHandler.success(res, data, 'Lịch sử đồng ý chính sách');
    } catch (error) {
      logger.error('getUserPolicy failed', { error: error.message });
      return ResponseHandler.error(res, error.message, error.statusCode || 500);
    }
  },

  async getUserDataExports(req, res) {
    try {
      const iduser = parseInt(req.params.id, 10);
      if (isNaN(iduser)) return ResponseHandler.badRequest(res, 'Tham số không hợp lệ');
      const idaccount = await adminService.resolveAccountId(iduser);
      if (!idaccount) return ResponseHandler.notFound(res, 'Không tìm thấy người dùng');
      const { listForAdmin } = require('../account/data-export.service');
      return ResponseHandler.success(res, await listForAdmin(idaccount), 'Yêu cầu bản sao dữ liệu');
    } catch (error) {
      logger.error('getUserDataExports failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async revealDeviceIp(req, res) {
    try {
      const iduser = parseInt(req.params.id, 10);
      const { deviceId } = req.params;
      if (isNaN(iduser) || !deviceId) return ResponseHandler.badRequest(res, 'Tham số không hợp lệ');
      req.auditActionName = `Xem IP đầy đủ (người dùng #${iduser}, thiết bị #${deviceId})`;
      const idaccount = await adminService.resolveAccountId(iduser);
      if (!idaccount) return ResponseHandler.notFound(res, 'Không tìm thấy người dùng');
      const { pin, password } = req.body || {};
      await adminService.verifySecurityAction(
        { pin, password, action: 'REVEAL_IP', targetId: `user#${iduser}/device#${deviceId}` },
        req.user
      );
      const ip = await deviceHistory.revealDeviceIp(idaccount, deviceId);
      if (!ip) return ResponseHandler.notFound(res, 'IP đầy đủ không còn lưu (đã quá thời hạn lưu trữ) hoặc không tồn tại');
      res.set?.('Cache-Control', 'no-store');
      return ResponseHandler.success(res, { ip }, 'IP đầy đủ của thiết bị');
    } catch (error) {
      logger.warn('revealDeviceIp failed', { error: error.message });
      return ResponseHandler.error(res, error.message, error.statusCode || 500);
    }
  },

  async totalUsers(req, res) {
    try {
      const result = await adminService.getTotalUsers();
      return ResponseHandler.success(res, result, 'Thống kê tổng người dùng');
    } catch (error) {
      logger.error('Total users failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async totalCategories(req, res) {
    try {
      const result = await adminService.getTotalCategories();
      return ResponseHandler.success(res, result, 'Thống kê tổng danh mục');
    } catch (error) {
      logger.error('Total categories failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getUserToTime(req, res) {
    try {
      const result = await adminService.getUserToTime(req.query);
      return ResponseHandler.success(res, result, 'Thống kê người dùng theo thời gian');
    } catch (error) {
      logger.error('getUserToTime failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getUsers(req, res) {
    try {
      const result = await adminService.getUsers();
      return ResponseHandler.success(res, result, 'Danh sách người dùng');
    } catch (error) {
      logger.error('getUsers failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getUserDetail(req, res) {
    try {
      const iduser = parseInt(req.params.id, 10);
      if (isNaN(iduser)) return ResponseHandler.badRequest(res, 'ID người dùng không hợp lệ');
      const result = await adminService.getUserDetail(iduser);
      return ResponseHandler.success(res, result, 'Thông tin chi tiết người dùng');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('getUserDetail failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async updateStatus(req, res) {
    try {
      const iduser = parseInt(req.params.id, 10);
      if (isNaN(iduser)) return ResponseHandler.badRequest(res, 'ID người dùng không hợp lệ');
      const data = withoutPin(req.body);
      const action = data.status === 'Inactive' ? 'DEACTIVATE_USER' : data.status === 'Active' ? 'ACTIVATE_USER' : 'CHANGE_USER_STATUS';
      await requirePin(req, action, `user#${iduser}`);
      const result = await adminService.updateStatus(iduser, data);
      logger.info('User status updated', { iduser, ...result });
      req.auditActionName = result.newStatus === 'Active' ? 'Mở khóa tài khoản' : 'Khóa tài khoản';
      return ResponseHandler.success(res, result, 'Cập nhật trạng thái thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('updateStatus failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async deleteUser(req, res) {
    try {
      const iduser = parseInt(req.params.id, 10);
      if (isNaN(iduser)) return ResponseHandler.badRequest(res, 'ID người dùng không hợp lệ');
      await requirePin(req, 'DELETE_USER', `user#${iduser}`);
      const result = await adminService.deleteUser(iduser);
      logger.info('User soft deleted', { iduser, ...result });
      req.auditActionName = 'Xóa người dùng (xóa mềm)';
      return ResponseHandler.success(res, result, 'Xóa người dùng thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('deleteUser failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async getCategories(req, res) {
    try {
      const result = await adminService.getCategories(req.query);
      return ResponseHandler.success(res, result, 'Danh sách danh mục');
    } catch (error) {
      logger.error('getCategories failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async addCategory(req, res) {
    try {
      const { name, classify, is_default, keyword, icon } = req.body;
      if (!name || !classify) return ResponseHandler.badRequest(res, 'Thiếu tên hoặc loại danh mục');
      await requirePin(req, 'SYNC_CATEGORIES', `category:add:${name}`);
      const result = await adminService.addCategory({ name, classify, is_default, keyword, icon }, req.user?.idaccount);
      return ResponseHandler.created(res, result, 'Thêm danh mục thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('addCategory failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async updateCategory(req, res) {
    try {
      const id = req.params.id;
      if (!id || typeof id !== 'string' || id.length < 32) {
        return ResponseHandler.badRequest(res, 'ID danh mục không hợp lệ');
      }
      const { name, classify, is_default, keyword, icon } = req.body;
      if (!name || !classify) return ResponseHandler.badRequest(res, 'Thiếu tên hoặc loại danh mục');
      await requirePin(req, 'SYNC_CATEGORIES', `category:update:${id}`);
      const result = await adminService.updateCategory(id, { name, classify, is_default, keyword, icon }, req.user?.idaccount);
      return ResponseHandler.success(res, result, 'Cập nhật danh mục thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('updateCategory failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async deleteCategory(req, res) {
    try {
      const id = req.params.id;
      if (!id || typeof id !== 'string' || id.length < 32) {
        return ResponseHandler.badRequest(res, 'ID danh mục không hợp lệ');
      }
      await requirePin(req, 'SYNC_CATEGORIES', `category:delete:${id}`);
      const result = await adminService.deleteCategory(id);
      return ResponseHandler.success(res, result, 'Xóa danh mục thành công');
    } catch (error) {
      logger.error('deleteCategory failed', { error: error.message });
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async restoreCategory(req, res) {
    try {
      const id = req.params.id;
      if (!id || typeof id !== 'string' || id.length < 32) {
        return ResponseHandler.badRequest(res, 'ID danh mục không hợp lệ');
      }
      await requirePin(req, 'SYNC_CATEGORIES', `category:restore:${id}`);
      const result = await adminService.restoreCategory(id);
      return ResponseHandler.success(res, result, 'Khôi phục danh mục thành công');
    } catch (error) {
      logger.error('restoreCategory failed', { error: error.message });
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async getLoginStats(req, res) {
    try {
      const result = await adminService.getLoginStats(req.query);
      return ResponseHandler.success(res, result, 'Thống kê tần suất đăng nhập');
    } catch (error) {
      logger.error('getLoginStats failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getRequestStats(req, res) {
    try {
      const result = await adminService.getRequestStats(req.query);
      return ResponseHandler.success(res, result, 'Thống kê lưu lượng request');
    } catch (error) {
      logger.error('getRequestStats failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  getMaintenanceStatus(req, res) {
    const { defaultMaintenanceManager } = require('../../core/resilience/maintenance.manager');
    return ResponseHandler.success(res, defaultMaintenanceManager.getStatus(), 'Trạng thái bảo trì hệ thống');
  },

  async setMaintenanceStatus(req, res) {
    const { defaultMaintenanceManager } = require('../../core/resilience/maintenance.manager');
    const { active, reason, isEmergency, isUpgrade, type, scheduledAt, scheduledEndAt } = req.body || {};
    const adminUser = req.user?.username || req.user?.fullname || 'admin';

    try {
      const action = scheduledAt ? 'SCHEDULE_MAINTENANCE' : active ? 'EMERGENCY_MAINTENANCE' : 'STOP_MAINTENANCE';
      await requirePin(req, action, scheduledAt || 'SYSTEM');
    } catch (err) {
      return ResponseHandler.error(res, err.message, err.statusCode || 500);
    }

    // 1. Xử lý lên lịch bảo trì / nâng cấp trong tương lai
    if (scheduledAt) {
      try {
        const isUpgradeFlag = Boolean(isUpgrade || type === 'UPGRADE');
        const status = defaultMaintenanceManager.scheduleMaintenance({
          scheduledAt,
          scheduledEndAt,
          reason,
          isEmergency,
          isUpgrade: isUpgradeFlag,
          type: type || (isUpgradeFlag ? 'UPGRADE' : 'SCHEDULED'),
          createdBy: adminUser,
        });
        return ResponseHandler.success(res, status, isUpgradeFlag ? 'Đã lên lịch nâng cấp hệ thống thành công' : 'Đã lên lịch bảo trì hệ thống thành công');
      } catch (err) {
        return ResponseHandler.badRequest(res, err.message);
      }
    }

    // 2. Kích hoạt hoặc tắt bảo trì tức thì (mặc định luôn là bảo trì khẩn cấp nếu không phải nâng cấp)
    try {
      const isUpgradeFlag = Boolean(isUpgrade || type === 'UPGRADE');
      const emergencyFlag = isUpgradeFlag ? false : (isEmergency !== undefined ? Boolean(isEmergency) : true);
      const status = defaultMaintenanceManager.setMaintenance(active, reason, adminUser, {
        isEmergency: emergencyFlag,
        isUpgrade: isUpgradeFlag,
        type: type || (isUpgradeFlag ? 'UPGRADE' : (emergencyFlag ? 'EMERGENCY' : 'ROUTINE')),
      });
      const msg = active
        ? (isUpgradeFlag ? 'Đã kích hoạt chế độ nâng cấp hệ thống' : 'Đã kích hoạt chế độ bảo trì khẩn cấp')
        : 'Đã tắt chế độ bảo trì — Hệ thống hoạt động bình thường';
      return ResponseHandler.success(res, status, msg);
    } catch (err) {
      return ResponseHandler.badRequest(res, err.message);
    }
  },

  async cancelScheduledMaintenance(req, res) {
    const { defaultMaintenanceManager } = require('../../core/resilience/maintenance.manager');
    const { defaultMaintenanceRepository } = require('./maintenance.repository');
    const id = req.params?.id || req.body?.id || req.query?.id || null;

    try {
      await requirePin(req, 'CANCEL_MAINTENANCE', id ? `maintenance#${id}` : 'maintenance:all');
    } catch (err) {
      return ResponseHandler.error(res, err.message, err.statusCode || 500);
    }

    if (id) {
      try {
        const queryRes = await defaultMaintenanceRepository.getHistory({ limit: 100 });
        const record = (queryRes.data || []).find((x) => x.id === Number(id) || x.id === id);
        if (record && record.status === 'SCHEDULED' && record.started_at) {
          const hoursUntilStart = (new Date(record.started_at).getTime() - Date.now()) / (3600 * 1000);
          if (hoursUntilStart < 3) {
            return ResponseHandler.badRequest(res, 'Chỉ có thể hủy lịch bảo trì trước thời điểm bắt đầu ít nhất 3 tiếng!');
          }
        }
      } catch (_) {}
    }

    await defaultMaintenanceManager.cancelScheduledMaintenance(id);
    return ResponseHandler.success(res, defaultMaintenanceManager.getStatus(), 'Đã hủy lịch bảo trì hệ thống');
  },

  async getMaintenanceHistory(req, res) {
    const { defaultMaintenanceRepository } = require('./maintenance.repository');
    try {
      const result = await defaultMaintenanceRepository.getHistory(req.query);
      return ResponseHandler.success(res, result, 'Danh sách lịch sử bảo trì hệ thống');
    } catch (error) {
      logger.error('getMaintenanceHistory failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  /** Độ khả dụng theo kỳ: ?period=month&year=2026&month=11 | period=quarter&quarter=4 | period=year */
  async getAvailability(req, res) {
    try {
      const { getAvailability } = require('./availability.service');
      const result = await getAvailability(req.query || {});
      return ResponseHandler.success(res, result, 'Độ khả dụng hệ thống theo kỳ');
    } catch (error) {
      if (error.statusCode === 400) {
        return ResponseHandler.error(res, error.message, 400, null, error.code);
      }
      logger.error('getAvailability failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getSystemHealth(req, res) {
    try {
      const result = await adminService.getSystemHealth();
      return ResponseHandler.success(res, result, 'Trạng thái hệ thống');
    } catch (error) {
      logger.error('getSystemHealth failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getAuditLogs(req, res) {
    try {
      const result = await adminService.getAuditLogs(req.query);
      return ResponseHandler.success(res, result, 'Nhật ký hoạt động hệ thống');
    } catch (error) {
      logger.error('getAuditLogs failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getPermissions(req, res) {
    try {
      const result = await adminService.getPermissionsMatrix();
      return ResponseHandler.success(res, result, 'Ma trận phân quyền tính năng');
    } catch (error) {
      logger.error('getPermissions failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async updatePermissions(req, res) {
    try {
      const { updates } = req.body || {};
      await requirePin(req, 'UPDATE_PERMISSIONS', `permissions:${Array.isArray(updates) ? updates.length : 0}`);
      const result = await adminService.updatePermissionsMatrix(updates, req.user);
      return ResponseHandler.success(res, result, 'Cập nhật phân quyền tính năng thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('updatePermissions failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async resetPermissions(req, res) {
    try {
      await requirePin(req, 'RESET_PERMISSIONS', 'permissions:default');
      const result = await adminService.resetPermissionsToDefault(req.user);
      return ResponseHandler.success(res, result, 'Khôi phục phân quyền về mặc định thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('resetPermissions failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async verifySecurityAction(req, res) {
    try {
      const result = await adminService.verifySecurityAction(req.body, req.user);
      return ResponseHandler.success(res, result, 'Xác thực hành động bảo mật thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('verifySecurityAction failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async changeAdminPin(req, res) {
    try {
      const result = await adminService.changeAdminPin(req.body, req.user);
      return ResponseHandler.success(res, result, result.message);
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('changeAdminPin failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async firstLoginSetup(req, res) {
    try {
      const result = await adminService.firstLoginSetup(req.body, req.user);
      return ResponseHandler.success(res, result, result.message);
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('firstLoginSetup failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async changeAdminPassword(req, res) {
    try {
      const result = await adminService.changeAdminPassword(req.body, req.user);
      return ResponseHandler.success(res, result, result.message);
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('changeAdminPassword failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async createAdminAccount(req, res) {
    try {
      const result = await adminService.createAdminAccount(req.body, req.user);
      return ResponseHandler.created(res, result, result.message);
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('createAdminAccount failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },
};

module.exports = adminController;
