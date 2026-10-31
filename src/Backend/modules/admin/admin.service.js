const adminRepository = require('./admin.repository');
const permissionRepository = require('../payment/permission.repository');
const os = require('os');
const { defaultEventLoopMonitor } = require('../../core/resilience/event-loop-monitor');
const { defaultDbBulkhead } = require('../../core/resilience/db-bulkhead');
const { defaultMaintenanceManager } = require('../../core/resilience/maintenance.manager');
const { maskEmail, maskPhone, maskAddress } = require('../../utils/masking.util');
const { validateReasonInactive } = require('../../utils/content-filter.util');

function normalizeCategoryName(name) {
  if (!name || typeof name !== 'string') return '';
  return name.normalize('NFC').trim().replace(/\s+/g, ' ').toLowerCase();
}

/**
 * Thời điểm server khởi động — ghi nhận 1 lần khi module được load.
 * Bền vững trong suốt vòng đời process (dev lẫn production).
 */
const SERVER_START_TIME = new Date();

/**
 * Chuyển số giây thành chuỗi mô tả thân thiện.
 * Ví dụ: 90061 → "1 ngày 1 giờ 1 phút"
 * @param {number} totalSeconds
 * @returns {string}
 */
function formatUptimeDuration(totalSeconds) {
  const days = Math.floor(totalSeconds / 86400);
  const hours = Math.floor((totalSeconds % 86400) / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);

  const parts = [];
  if (days > 0) parts.push(`${days} ngày`);
  if (hours > 0) parts.push(`${hours} giờ`);
  if (minutes > 0) parts.push(`${minutes} phút`);
  if (parts.length === 0) parts.push('Vừa khởi động');
  return parts.join(' ');
}

/**
 * Tính % uptime theo chuẩn SLA 30 ngày (Chuẩn SLA Công nghiệp được PO phê duyệt):
 * - Khấu trừ toàn bộ thời gian hệ thống bảo trì (cả Khẩn cấp EMERGENCY lẫn Theo lịch SCHEDULED).
/**
 * Tính toán tỷ lệ Uptime hệ thống thực tế theo chỉ đạo PO:
 * - Tổng thời gian: Tính từ lúc máy chủ bắt đầu chạy (SERVER_START_TIME) đến thời điểm hiện tại.
 * - Thời gian chạy thực tế = Tổng thời gian - Thời gian bảo trì.
 * - Tỷ lệ % Uptime = (Thời gian chạy thực tế / Tổng thời gian) * 100.
 * - Tự động cập nhật lại liên tục kể cả khi đang trong phiên bảo trì.
 * @param {number} uptimeSeconds - Số giây tiến trình process nodejs hoặc tổng thời gian
 * @returns {Promise<{ uptimePercent: number, uptimeSeconds: number, totalSeconds: number, rawUptimeSeconds: number, downtimeSeconds: number, emergencyDowntimeSec: number, startedAt: string }>}
 */
async function calcUptimePercent(uptimeSeconds = 0) {
  // Tổng thời gian từ lúc bắt đầu chạy
  const totalElapsedSec = typeof uptimeSeconds === 'number' && uptimeSeconds > 0
    ? Math.floor(uptimeSeconds)
    : Math.max(1, Math.floor((Date.now() - SERVER_START_TIME.getTime()) / 1000));

  let totalDowntimeSec = 0;

  try {
    const { defaultMaintenanceRepository } = require('./maintenance.repository');
    if (defaultMaintenanceRepository) {
      const sinceDate = SERVER_START_TIME;
      if (typeof defaultMaintenanceRepository.getTotalMaintenanceDowntimeSeconds === 'function') {
        totalDowntimeSec = await defaultMaintenanceRepository.getTotalMaintenanceDowntimeSeconds(sinceDate);
      } else if (typeof defaultMaintenanceRepository.getEmergencyDowntimeSeconds === 'function') {
        totalDowntimeSec = await defaultMaintenanceRepository.getEmergencyDowntimeSeconds(sinceDate);
      }
    }
  } catch (_) {}

  // Nếu hiện tại hệ thống đang trong phiên bảo trì chưa kết thúc (active = true), cộng thêm thời gian đang diễn ra
  try {
    if (defaultMaintenanceManager && typeof defaultMaintenanceManager.isMaintenanceActive === 'function' && defaultMaintenanceManager.isMaintenanceActive()) {
      if (defaultMaintenanceManager.activatedAt) {
        const ongoingSec = Math.max(0, Math.floor((Date.now() - new Date(defaultMaintenanceManager.activatedAt).getTime()) / 1000));
        totalDowntimeSec += ongoingSec;
      }
    } else if (defaultMaintenanceManager && defaultMaintenanceManager.getStatus) {
      const status = defaultMaintenanceManager.getStatus();
      if (status && status.active && status.activatedAt) {
        const ongoingSec = Math.max(0, Math.floor((Date.now() - new Date(status.activatedAt).getTime()) / 1000));
        totalDowntimeSec += ongoingSec;
      }
    }
  } catch (_) {}

  // Khấu trừ an toàn: Downtime không được vượt quá Tổng thời gian
  const safeDowntime = Math.max(0, Math.min(totalDowntimeSec, totalElapsedSec));
  // Thời gian chạy thực tế của hệ thống
  const runningSec = Math.max(0, totalElapsedSec - safeDowntime);

  // Tỷ lệ % Uptime thực tế = (Thời gian chạy thực tế / Tổng thời gian) * 100
  const rawPercent = totalElapsedSec > 0 ? (runningSec / totalElapsedSec) * 100 : 100;
  const percent = parseFloat(Math.min(100, Math.max(0, rawPercent)).toFixed(2));

  return {
    uptimePercent: percent,
    uptimeSeconds: runningSec,
    totalSeconds: totalElapsedSec,
    rawUptimeSeconds: totalElapsedSec,
    downtimeSeconds: safeDowntime,
    emergencyDowntimeSec: safeDowntime,
    startedAt: SERVER_START_TIME.toISOString(),
  };
}

function calcGrowth(current, previous) {
  if (current === 0) return 0;
  if (previous === 0) return 100;
  return parseFloat(((current / previous) * 100).toFixed(2));
}

/**
 * Lấy các thành phần thời gian theo múi giờ Việt Nam (Asia/Ho_Chi_Minh)
 * @param {Date|string|number} dateInput 
 * @returns {{ year: string, month: string, day: string, hour: string, minute: string }}
 */
function getVnTimeParts(dateInput) {
  const d = new Date(dateInput);
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  const parts = formatter.formatToParts(d);
  const obj = {};
  for (const p of parts) {
    obj[p.type] = p.value;
  }
  if (obj.hour === '24') obj.hour = '00';
  return obj;
}

const adminService = {
  async getTotalUsers() {
    const total = await adminRepository.countUsers();
    return { total };
  },

  async getTotalCategories() {
    const total = await adminRepository.countCategories();
    return { total };
  },

  async getUserToTime(params) {
    const { startDate, endDate, prevStartDate, prevEndDate, period, label } = resolveFilterContext(params);

    const currentCount = await adminRepository.countUsersByRange(startDate, endDate);
    const previousCount = await adminRepository.countUsersByRange(prevStartDate, prevEndDate);
    const growth = calcGrowth(currentCount, previousCount);

    return {
      period,
      label,
      current: currentCount,
      previous: previousCount,
      growth,
    };
  },

  async getUsers() {
    const users = await adminRepository.getAllUsers();
    return users.map((u) => ({
      id: u.iduser,
      idaccount: u.account ? u.account.idaccount : null,
      fullname: u.fullname,
      email: maskEmail(u.email),
      phone: maskPhone(u.phone, { table: 'user', id: u.iduser, field: 'phone' }),
      address: maskAddress(u.address, { table: 'user', id: u.iduser, field: 'address' }),
      country_code: u.country_code,
      username: u.account ? u.account.username : null,
      status: u.account ? u.account.status : (u.delete_at ? 'Deleted' : 'Active'),
      type: u.account ? (u.account.type || 'Basic') : 'Basic',
      reason_inactive: u.account ? u.account.reason_inactive : null,
      countdown: u.account ? u.account.countdown : null,
      delete_at: u.account ? u.account.delete_at : u.delete_at,
      created_at: u.create_at,
      updated_at: u.account ? (u.account.update_at || u.update_at) : u.update_at,
    }));
  },

  async getUserDetail(iduser) {
    const u = await adminRepository.getUserById(iduser);
    if (!u) throw Object.assign(new Error('Không tìm thấy người dùng'), { statusCode: 404 });
    return {
      id: u.iduser,
      idaccount: u.account.idaccount,
      fullname: u.fullname,
      email: maskEmail(u.email),
      phone: maskPhone(u.phone, { table: 'user', id: u.iduser, field: 'phone' }),
      address: maskAddress(u.address, { table: 'user', id: u.iduser, field: 'address' }),
      country_code: u.country_code,
      username: u.account.username,
      status: u.account.status,
      type: u.account.type || 'Basic',
      rolename: u.account.role.rolename,
      reason_inactive: u.account.reason_inactive || null,
      countdown: u.account.countdown ?? null,
      delete_at: u.account.delete_at || u.delete_at,
      created_at: u.create_at,
      updated_at: u.account.update_at || u.update_at,
    };
  },

  async updateStatus(iduser, data = {}) {
    const u = await adminRepository.getUserById(iduser);
    if (!u) throw Object.assign(new Error('Không tìm thấy người dùng'), { statusCode: 404 });

    const currentStatus = u.account.status;
    if (currentStatus === 'PendingDelete') {
      throw Object.assign(
        new Error('Tài khoản đang trong trạng thái Chờ xóa (PendingDelete) do người dùng yêu cầu, quản trị viên không thể thay đổi trạng thái!'),
        { statusCode: 400 }
      );
    }
    if (currentStatus === 'Deleted') {
      throw Object.assign(
        new Error('Tài khoản đã bị xóa khỏi hệ thống, không thể thay đổi trạng thái!'),
        { statusCode: 400 }
      );
    }

    const targetStatus = data.status || (currentStatus === 'Active' ? 'Inactive' : 'Active');

    if (targetStatus === 'Inactive') {
      const reason = (data.reason_inactive || data.reason || '').trim();
      const validation = validateReasonInactive(reason);
      if (!validation.valid) {
        throw Object.assign(new Error(validation.error), { statusCode: 400 });
      }

      await adminRepository.updateAccountStatus(iduser, 'Inactive', reason);
      const { invalidateAccountCache } = require('../../middleware/auth');
      invalidateAccountCache(u.account.idaccount);

      // Phát sự kiện cưỡng chế đăng xuất qua Socket.IO kèm lý do
      const { emitForceLogout, emitUserStatusChanged } = require('../../core/socket');
      emitForceLogout(u.account.idaccount, 'ACCOUNT_INACTIVE', `Tài khoản của bạn đã bị vô hiệu hóa. Lý do: ${reason}`);

      try {
        emitUserStatusChanged({
          iduser,
          idaccount: u.account.idaccount,
          username: u.account.username,
          status: 'inactive',
          reason_inactive: reason,
        });
      } catch (_) {}

      return {
        id: iduser,
        username: u.account.username,
        fullname: u.fullname,
        previousStatus: currentStatus,
        newStatus: 'Inactive',
        reason_inactive: reason,
      };
    } else {
      // Re-activate tài khoản
      await adminRepository.updateAccountStatus(iduser, 'Active', null);
      const { invalidateAccountCache } = require('../../middleware/auth');
      invalidateAccountCache(u.account.idaccount);

      try {
        const { emitUserStatusChanged } = require('../../core/socket');
        emitUserStatusChanged({
          iduser,
          idaccount: u.account.idaccount,
          username: u.account.username,
          status: 'active',
          reason_inactive: null,
        });
      } catch (_) {}

      return {
        id: iduser,
        username: u.account.username,
        fullname: u.fullname,
        previousStatus: currentStatus,
        newStatus: 'Active',
        reason_inactive: null,
      };
    }
  },

  async deleteUser(iduser) {
    const u = await adminRepository.getUserById(iduser);
    if (!u) {
      throw Object.assign(new Error('Không tìm thấy người dùng'), { statusCode: 404 });
    }

    if (u.account.idrole === 1) {
      throw Object.assign(new Error('Không thể xóa tài khoản Quản trị viên'), { statusCode: 403 });
    }

    if (u.account.status === 'PendingDelete') {
      throw Object.assign(
        new Error('Tài khoản đang trong trạng thái Chờ xóa (PendingDelete) do người dùng yêu cầu, quản trị viên không thể thao tác xóa!'),
        { statusCode: 400 }
      );
    }
    if (u.account.status === 'Deleted' || u.account.delete_at) {
      throw Object.assign(
        new Error('Tài khoản đã bị xóa khỏi hệ thống trước đó!'),
        { statusCode: 400 }
      );
    }

    const idaccount = u.account.idaccount;
    await adminRepository.softDeleteUser(iduser);

    // 1. Invalidate auth cache
    const { invalidateAccountCache } = require('../../middleware/auth');
    invalidateAccountCache(idaccount);

    // 2. Emit force logout via Socket.IO
    const { emitForceLogout, emitUserStatusChanged } = require('../../core/socket');
    emitForceLogout(idaccount, 'ACCOUNT_DELETED', 'Tài khoản của bạn đã bị ngừng hoạt động hoặc xóa bởi quản trị viên.');

    try {
      emitUserStatusChanged({
        iduser,
        idaccount,
        username: u.account.username,
        status: 'deleted',
      });
    } catch (_) {}

    return {
      message: 'Người dùng đã được xóa mềm thành công',
      iduser,
      idaccount,
      username: u.account.username,
      fullname: u.fullname,
    };
  },

  async getCategories(filters = {}) {
    const cats = await adminRepository.getAllCategories(filters);
    return cats.map((c) => {
      // Cơ chế phòng vệ chiều sâu (Defense-in-Depth):
      // Nếu vì bất kỳ lý do nào danh mục người dùng lọt vào, mặt nạ hóa 100% bằng ***
      const isUserCat = c.is_default === false;
      return {
        id: c.idcategory,
        name: isUserCat ? '***' : c.name_category,
        classify: c.classify,
        is_default: c.is_default,
        is_group: c.is_group,
        idgroup: c.idgroup,
        keyword: isUserCat ? '***' : c.keyword,
        icon: isUserCat ? null : c.icon,
        created_by_id: isUserCat ? null : c.create_by,
        created_by: isUserCat ? '***' : (c.is_default ? 'Hệ thống' : 'Người dùng'),
        created_by_name: isUserCat ? '***' : (c.is_default ? 'Hệ thống' : (c.account?.User?.fullname || null)),
        is_user_category: isUserCat,
        status: c.delete_at ? 'deleted' : 'active',
        delete_at: c.delete_at || null,
        created_at: c.create_at,
        updated_at: c.update_at,
      };
    });
  },

  async addCategory(data, idaccount) {
    const trimmedName = (data.name || '').trim();
    if (!trimmedName) {
      throw Object.assign(new Error('Tên danh mục không được để trống'), { statusCode: 400 });
    }
    // Admin chỉ được phép tạo danh mục mặc định của hệ thống
    const validClassifies = ['Thu', 'Chi', 'Vay/nợ', 'Vay/no', 'Vay', 'no'];
    if (!validClassifies.includes(data.classify)) {
      throw Object.assign(new Error(`Loại danh mục '${data.classify}' không hợp lệ. Phải là Thu, Chi, hoặc Vay/no`), { statusCode: 400 });
    }
    // Normalize debt variants to canonical 'Vay/no'
    let canonicalClassify = data.classify;
    if (['Vay/nợ', 'Vay', 'no'].includes(canonicalClassify)) {
      canonicalClassify = 'Vay/no';
    }

    const { prisma } = require('../../config/db');
    const normalizedInput = normalizeCategoryName(trimmedName);

    // 1. Check unique tên danh mục hệ thống đang active (KHÔNG phân biệt classify)
    const activeDefaults = await prisma.category.findMany({
      where: {
        is_default: true,
        delete_at: null,
      },
      select: {
        idcategory: true,
        name_category: true,
        classify: true,
      },
    });

    const duplicateActive = activeDefaults.find(
      (c) => normalizeCategoryName(c.name_category) === normalizedInput
    );
    if (duplicateActive) {
      throw Object.assign(
        new Error(`Danh mục hệ thống "${duplicateActive.name_category}" đã tồn tại và đang hoạt động trong hệ thống. Vui lòng chọn tên khác.`),
        { statusCode: 409 }
      );
    }

    // 2. Nếu phát hiện cặp [Tên danh mục + Loại danh mục] đã bị xóa mềm: tiến hành mở lại (restore) và bảo toàn mọi dữ liệu hiện có
    const softDeletedCandidates = await prisma.category.findMany({
      where: {
        classify: canonicalClassify,
        is_default: true,
        delete_at: { not: null },
      },
      orderBy: { delete_at: 'desc' },
    });

    const softDeleted = softDeletedCandidates.find(
      (c) => normalizeCategoryName(c.name_category) === normalizedInput
    );

    if (softDeleted) {
      // ⚠️ BẢO TOÀN DỮ LIỆU: Nếu data.keyword không truyền hoặc để rỗng, BẮT BUỘC giữ nguyên softDeleted.keyword!
      const resolvedKeyword = (data.keyword && data.keyword.trim())
        ? data.keyword.trim()
        : softDeleted.keyword;

      try {
        const restored = await prisma.category.update({
          where: { idcategory: softDeleted.idcategory },
          data: {
            name_category: trimmedName,
            classify: canonicalClassify,
            keyword: resolvedKeyword,
            icon: data.icon || softDeleted.icon,
            delete_at: null,
            update_at: new Date(),
            server_update_at: new Date(),
          },
        });
        const resultData = { id: restored.idcategory, name: restored.name_category, classify: restored.classify, keyword: restored.keyword };
        try {
          const { emitCategoryUpdated } = require('../../core/socket');
          emitCategoryUpdated({ action: 'create', category: resultData });
        } catch (_) {}
        return resultData;
      } catch (err) {
        if (err.code === 'P2002') {
          throw Object.assign(
            new Error(`Danh mục hệ thống "${trimmedName}" đã tồn tại trong hệ thống. Vui lòng chọn tên khác.`),
            { statusCode: 409 }
          );
        }
        throw err;
      }
    }

    // 3. Tạo mới danh mục hệ thống hoàn toàn
    try {
      const result = await adminRepository.createCategory({
        name: trimmedName,
        classify: canonicalClassify,
        is_default: true,
        keyword: data.keyword ? data.keyword.trim() : null,
        icon: data.icon,
        created_by: idaccount ? Number(idaccount) : 1,
      });
      const createdData = { id: result.idcategory, name: result.name_category, classify: result.classify, keyword: result.keyword };
      try {
        const { emitCategoryUpdated } = require('../../core/socket');
        emitCategoryUpdated({ action: 'create', category: createdData });
      } catch (_) {}
      return createdData;
    } catch (err) {
      if (err.code === 'P2002') {
        throw Object.assign(
          new Error(`Danh mục hệ thống "${trimmedName}" đã tồn tại trong hệ thống. Vui lòng chọn tên khác.`),
          { statusCode: 409 }
        );
      }
      throw err;
    }
  },

  async updateCategory(idcategory, data, idaccount) {
    const trimmedName = (data.name || '').trim();
    if (!trimmedName) {
      throw Object.assign(new Error('Tên danh mục không được để trống'), { statusCode: 400 });
    }
    const validClassifies = ['Thu', 'Chi', 'Vay/nợ', 'Vay/no', 'Vay', 'no'];
    if (data.classify && !validClassifies.includes(data.classify)) {
      throw Object.assign(new Error(`Loại danh mục '${data.classify}' không hợp lệ. Phải là Thu, Chi, hoặc Vay/no`), { statusCode: 400 });
    }
    // Normalize debt variants to canonical 'Vay/no'
    let canonicalClassify = data.classify;
    if (canonicalClassify && ['Vay/nợ', 'Vay', 'no'].includes(canonicalClassify)) {
      canonicalClassify = 'Vay/no';
    }

    const { prisma } = require('../../config/db');

    // Lấy thông tin danh mục hiện tại để kiểm tra
    const currentCat = await prisma.category.findUnique({
      where: { idcategory },
    });
    if (!currentCat || currentCat.delete_at) {
      throw Object.assign(new Error('Không tìm thấy danh mục hoặc danh mục đã bị xóa'), { statusCode: 404 });
    }

    // Bảo vệ quyền riêng tư người dùng: Admin TUYỆT ĐỐI KHÔNG ĐƯỢC PHÉP sửa danh mục của người dùng
    if (!currentCat.is_default) {
      throw Object.assign(new Error('Vi phạm quyền riêng tư: Tuyệt đối cấm chỉnh sửa danh mục của người dùng.'), { statusCode: 403 });
    }

    const normalizedInput = normalizeCategoryName(trimmedName);

    // Check unique [Is_default & namecategory] khi sửa (loại trừ chính idcategory đang sửa)
    const activeDefaults = await prisma.category.findMany({
      where: {
        idcategory: { not: idcategory },
        is_default: true,
        delete_at: null,
      },
      select: {
        idcategory: true,
        name_category: true,
      },
    });

    const duplicateActive = activeDefaults.find(
      (c) => normalizeCategoryName(c.name_category) === normalizedInput
    );
    if (duplicateActive) {
      throw Object.assign(
        new Error(`Danh mục hệ thống "${duplicateActive.name_category}" đã tồn tại trong hệ thống. Không được phép đổi tên trùng.`),
        { statusCode: 409 }
      );
    }

    try {
      const result = await adminRepository.updateCategory(idcategory, {
        name: trimmedName,
        classify: canonicalClassify,
        is_default: true,
        keyword: data.keyword !== undefined ? (data.keyword ? data.keyword.trim() : null) : undefined,
        icon: data.icon,
      });
      const updatedData = { id: result.idcategory, name: result.name_category, classify: result.classify, keyword: result.keyword };
      try {
        const { emitCategoryUpdated } = require('../../core/socket');
        emitCategoryUpdated({ action: 'update', category: updatedData });
      } catch (_) {}
      return updatedData;
    } catch (err) {
      if (err.code === 'P2002') {
        throw Object.assign(
          new Error(`Danh mục hệ thống "${trimmedName}" đã tồn tại trong hệ thống. Không được phép đổi tên trùng.`),
          { statusCode: 409 }
        );
      }
      throw err;
    }
  },

  async deleteCategory(idcategory) {
    const { prisma } = require('../../config/db');
    const cat = await prisma.category.findUnique({ where: { idcategory } });
    if (!cat || cat.delete_at) {
      throw Object.assign(new Error('Không tìm thấy danh mục hoặc danh mục đã bị xóa'), { statusCode: 404 });
    }
    // Bảo vệ quyền riêng tư người dùng: Admin TUYỆT ĐỐI KHÔNG ĐƯỢC PHÉP xóa danh mục của người dùng
    if (!cat.is_default) {
      throw Object.assign(new Error('Vi phạm quyền riêng tư: Tuyệt đối cấm xóa danh mục của người dùng.'), { statusCode: 403 });
    }
    // Cho phép Admin xóa mềm danh mục hệ thống (Soft-delete: set delete_at = now())
    await adminRepository.deleteCategory(idcategory);
    try {
      const { emitCategoryUpdated } = require('../../core/socket');
      emitCategoryUpdated({ action: 'delete', idcategory });
    } catch (_) {}
    return { id: idcategory };
  },

  async restoreCategory(idcategory) {
    const { prisma } = require('../../config/db');
    const cat = await prisma.category.findUnique({ where: { idcategory } });
    if (!cat) {
      throw Object.assign(new Error('Không tìm thấy danh mục'), { statusCode: 404 });
    }
    // Bảo vệ quyền riêng tư người dùng: Admin TUYỆT ĐỐI KHÔNG ĐƯỢC PHÉP thao tác trên danh mục của người dùng
    if (!cat.is_default) {
      throw Object.assign(new Error('Vi phạm quyền riêng tư: Tuyệt đối cấm thao tác trên danh mục của người dùng.'), { statusCode: 403 });
    }

    // Nếu danh mục chưa bị xóa mềm thì trả về luôn
    if (!cat.delete_at) {
      return { id: cat.idcategory, name: cat.name_category, classify: cat.classify, keyword: cat.keyword };
    }

    const normalizedCatName = normalizeCategoryName(cat.name_category);

    // Kiểm tra xem đã có danh mục hệ thống SỐNG khác cùng tên chuẩn hóa hay chưa
    const activeDefaults = await prisma.category.findMany({
      where: {
        idcategory: { not: idcategory },
        is_default: true,
        delete_at: null,
      },
      select: {
        idcategory: true,
        name_category: true,
      },
    });

    const duplicateActive = activeDefaults.find(
      (c) => normalizeCategoryName(c.name_category) === normalizedCatName
    );
    if (duplicateActive) {
      throw Object.assign(
        new Error(`Đã có danh mục hệ thống "${duplicateActive.name_category}" đang hoạt động. Vui lòng đổi tên một trong hai trước khi khôi phục.`),
        { statusCode: 409 }
      );
    }

    try {
      const restored = await adminRepository.restoreCategory(idcategory);
      const resultData = { id: restored.idcategory, name: restored.name_category, classify: restored.classify, keyword: restored.keyword };
      try {
        const { emitCategoryUpdated } = require('../../core/socket');
        emitCategoryUpdated({ action: 'create', category: resultData });
      } catch (_) {}
      return resultData;
    } catch (err) {
      if (err.code === 'P2002') {
        throw Object.assign(
          new Error(`Đã có danh mục hệ thống "${cat.name_category}" đang hoạt động. Vui lòng đổi tên một trong hai trước khi khôi phục.`),
          { statusCode: 409 }
        );
      }
      throw err;
    }
  },

  async getLoginStats(params = 'today') {
    const { startDate, endDate, buckets, format, period: resolvedPeriod, label } = resolveFilterContext(params);
    const logs = await adminRepository.getLoginLogsByRange(startDate, endDate);

    const bucketMap = new Map();
    buckets.forEach((b) => bucketMap.set(b.key, b));

    for (const log of logs) {
      const vnParts = getVnTimeParts(log.time_req);
      let key;
      if (format === 'hour') {
        key = vnParts.hour;
      } else if (format === 'month') {
        key = `${vnParts.year}-${vnParts.month}`;
      } else {
        key = `${vnParts.year}-${vnParts.month}-${vnParts.day}`;
      }

      if (bucketMap.has(key)) {
        bucketMap.get(key).count += 1;
      }
    }

    const counts = buckets.map((b) => b.count);
    const total = counts.reduce((acc, c) => acc + c, 0);
    const max = counts.length > 0 ? Math.max(...counts) : 0;
    const avg = counts.length > 0 ? Math.round(total / counts.length) : 0;

    return {
      period: resolvedPeriod,
      format,
      label,
      summary: {
        total,
        max,
        avg,
      },
      timeline: buckets.map(({ key, label, count }) => ({ key, label, count })),
    };
  },

  async getRequestStats(params = 'today') {
    const { startDate, endDate, buckets, format, period: resolvedPeriod, label } = resolveFilterContext(params);
    const logs = await adminRepository.getRequestLogsByRange(startDate, endDate);

    const bucketMap = new Map();
    buckets.forEach((b) => bucketMap.set(b.key, b));

    for (const log of logs) {
      const vnParts = getVnTimeParts(log.time_req);
      let key;
      if (format === 'hour') {
        key = vnParts.hour;
      } else if (format === 'month') {
        key = `${vnParts.year}-${vnParts.month}`;
      } else {
        key = `${vnParts.year}-${vnParts.month}-${vnParts.day}`;
      }

      if (bucketMap.has(key)) {
        bucketMap.get(key).count += 1;
      }
    }

    const counts = buckets.map((b) => b.count);
    const total = counts.reduce((acc, c) => acc + c, 0);
    const max = counts.length > 0 ? Math.max(...counts) : 0;
    const avg = counts.length > 0 ? Math.round(total / counts.length) : 0;

    return {
      period: resolvedPeriod,
      format,
      label,
      summary: {
        total,
        max,
        avg,
      },
      timeline: buckets.map(({ key, label, count }) => ({ key, label, count })),
    };
  },

  async getSystemHealth() {
    let hwMetrics = null;
    try {
      const { defaultSystemHardwareMonitor } = require('../../core/resilience/system-hardware-monitor');
      if (defaultSystemHardwareMonitor && typeof defaultSystemHardwareMonitor.getMetrics === 'function') {
        hwMetrics = defaultSystemHardwareMonitor.getMetrics();
      }
    } catch (_) {}

    const cpus = os.cpus() || [];
    const cpuPercent = hwMetrics ? hwMetrics.cpu.percent : 0;
    const ramInfo = hwMetrics ? hwMetrics.ram : {
      totalMb: Math.round(os.totalmem() / 1024 / 1024),
      usedMb: Math.round((os.totalmem() - os.freemem()) / 1024 / 1024),
      freeMb: Math.round(os.freemem() / 1024 / 1024),
      percent: Math.round(((os.totalmem() - os.freemem()) / os.totalmem()) * 100),
      rssMb: Math.round(process.memoryUsage().rss / 1024 / 1024),
    };

    const dbStats = defaultDbBulkhead.getStats();
    const maintStatus = defaultMaintenanceManager.getStatus();
    const { getLoadSheddingCount } = require('../../middleware/load-shedding.middleware');

    const rawUptimeSeconds = Math.floor(process.uptime());
    const uptimeResult = await calcUptimePercent(rawUptimeSeconds);
    const uptimeSeconds = uptimeResult.uptimeSeconds;
    const totalSeconds = uptimeResult.totalSeconds;
    const uptimePercent = uptimeResult.uptimePercent;
    const downtimeSeconds = uptimeResult.downtimeSeconds;

    return {
      cpu: { cores: cpus.length, percent: cpuPercent },
      ram: {
        usedMb: ramInfo.usedMb,
        totalMb: ramInfo.totalMb,
        freeMb: ramInfo.freeMb,
        percent: ramInfo.percent,
        rssMb: ramInfo.rssMb,
      },
      eventLoop: {
        lagMs: defaultEventLoopMonitor.getLag(),
        overloaded: defaultEventLoopMonitor.isOverloaded(),
      },
      dbPool: {
        clientActive: dbStats.activeClientConnections,
        clientLimit: dbStats.clientLimit,
        adminActive: dbStats.activeAdminConnections,
        maxConnections: dbStats.maxConnections,
      },
      maintenance: {
        active: maintStatus.active,
        reason: maintStatus.reason,
        activatedBy: maintStatus.activatedBy,
        activatedAt: maintStatus.activatedAt,
      },
      loadShedding: { shedCount24h: typeof getLoadSheddingCount === 'function' ? getLoadSheddingCount() : 0 },
      uptime: {
        uptimeSeconds,
        totalSeconds,
        rawUptimeSeconds,
        uptimeFormatted: formatUptimeDuration(uptimeSeconds),
        totalFormatted: formatUptimeDuration(totalSeconds),
        startedAt: SERVER_START_TIME.toISOString(),
        uptimePercent,
        downtimeSeconds,
      },
      timestamp: new Date().toISOString(),
    };
  },

  async getAuditLogs(params = {}) {
    const limit = Math.min(parseInt(params.limit, 10) || 50, 200);
    const page = Math.max(parseInt(params.page, 10) || 1, 1);
    const result = await adminRepository.queryAuditLogs({ ...params, limit, page });
    return { ...result, page, limit };
  },

  /**
   * Lấy ma trận phân quyền tính năng theo loại tài khoản (Basic / Premium) - Đầy đủ 4 Trụ Cột
   */
  async getPermissionsMatrix() {
    const features = await permissionRepository.getAllFeatures();
    const rawPerms = await permissionRepository.getAllAccountPermissions();

    const permissions = {
      Basic: {},
      Premium: {},
    };

    for (const p of rawPerms) {
      if (!permissions[p.account_type]) {
        permissions[p.account_type] = {};
      }
      permissions[p.account_type][p.feature_id] = {
        is_enabled: Boolean(p.is_enabled),
        limit_value: p.limit_value !== undefined ? p.limit_value : null,
        scope_config: p.scope_config || {},
        downgrade_policy: p.downgrade_policy || 'BLOCK_CREATE',
      };
    }

    return { features, permissions };
  },

  /**
   * Cập nhật hàng loạt cấu hình phân quyền tính năng (Hỗ trợ đầy đủ 4 Trụ Cột)
   * @param {Array<{ account_type: string, feature_id: string, is_enabled: boolean, limit_value: number|null, scope_config?: object, downgrade_policy?: string }>} updates
   */
  async updatePermissionsMatrix(updates = [], adminUser = null) {
    if (!Array.isArray(updates) || updates.length === 0) {
      const err = new Error('Danh sách cập nhật không được rỗng');
      err.statusCode = 400;
      throw err;
    }

    const results = [];
    for (const item of updates) {
      const { account_type, feature_id, is_enabled, limit_value, scope_config, downgrade_policy } = item;
      if (!['Basic', 'Premium'].includes(account_type)) {
        const err = new Error(`Loại tài khoản không hợp lệ: ${account_type}`);
        err.statusCode = 400;
        throw err;
      }
      if (!feature_id) {
        const err = new Error('Thiếu mã tính năng (feature_id)');
        err.statusCode = 400;
        throw err;
      }

      const updated = await permissionRepository.updatePermission(account_type, feature_id, {
        is_enabled: is_enabled !== undefined ? Boolean(is_enabled) : true,
        limit_value: limit_value !== undefined && limit_value !== '' && limit_value !== null ? Number(limit_value) : null,
        scope_config: scope_config !== undefined ? scope_config : undefined,
        downgrade_policy: downgrade_policy !== undefined ? downgrade_policy : undefined,
      });
      results.push(updated);
    }

    // Xóa cache Redis phân quyền (nếu có)
    try {
      const { getRedisClient } = require('../../config/redis.resolver');
      const redis = typeof getRedisClient === 'function' ? getRedisClient() : null;
      if (redis) {
        await redis.del('permissions:Basic', 'permissions:Premium');
      }
    } catch (cacheErr) {
      // bỏ qua lỗi cache không ảnh hưởng kết quả chính
    }

    // Phát Socket.IO realtime thông báo phân quyền thay đổi tới toàn bộ client
    try {
      const { emitPermissionsUpdated } = require('../../core/socket');
      if (typeof emitPermissionsUpdated === 'function') {
        emitPermissionsUpdated(results);
      }
    } catch (socketErr) {
      logger.warn('[AdminService] Không thể phát socket permissions updated:', socketErr.message);
    }

    return { updatedCount: results.length, updates: results };
  },

  /**
   * Đặt lại toàn bộ phân quyền về chuẩn mặc định 4 Trụ Cột (SSOT 4_TRU_COT.md)
   */
  async resetPermissionsToDefault(adminUser = null) {
    const fs = require('fs');
    const path = require('path');
    const sqlPath = path.join(__dirname, '../../database/32_seed_permissions_4_pillars_data.sql');

    if (!fs.existsSync(sqlPath)) {
      const err = new Error('Không tìm thấy tệp SQL khôi phục mặc định');
      err.statusCode = 500;
      throw err;
    }

    const sqlContent = fs.readFileSync(sqlPath, 'utf8');
    const { pool } = require('../../config/db');
    await pool.query('BEGIN');
    try {
      await pool.query(sqlContent);
      await pool.query('COMMIT');
    } catch (dbErr) {
      await pool.query('ROLLBACK');
      throw dbErr;
    }

    // Xóa cache Redis
    try {
      const { getRedisClient } = require('../../config/redis.resolver');
      const redis = typeof getRedisClient === 'function' ? getRedisClient() : null;
      if (redis) {
        await redis.del('permissions:Basic', 'permissions:Premium');
      }
    } catch (cacheErr) {
      // ignore
    }

    // Phát socket thông báo toàn bộ ma trận mới
    const matrix = await this.getPermissionsMatrix();
    try {
      const { emitPermissionsUpdated } = require('../../core/socket');
      if (typeof emitPermissionsUpdated === 'function') {
        emitPermissionsUpdated({ reset: true, timestamp: new Date() });
      }
    } catch (socketErr) {
      logger.warn('[AdminService] Không thể phát socket permissions reset:', socketErr.message);
    }

    return { success: true, message: 'Đã khôi phục phân quyền về chuẩn mặc định 4 Trụ Cột', matrix };
  },

  /**
   * Xác thực mã PIN hoặc mật khẩu quản trị viên cho các hành động chí mạng (Re-authentication)
   */
  async verifySecurityAction({ pin, password, action, targetId } = {}, currentUser = null) {
    if (!pin && !password) {
      const err = new Error('Vui lòng cung cấp mã PIN bảo mật hoặc mật khẩu quản trị viên');
      err.statusCode = 400;
      throw err;
    }

    const bcrypt = require('bcryptjs');
    let isPinValid = false;
    let isPasswordValid = false;
    const account = currentUser?.idaccount ? await adminRepository.getAccountById(currentUser.idaccount) : null;

    if (pin && typeof pin === 'string') {
      const trimmedPin = pin.trim();
      if (account?.pin_hash) {
        isPinValid = await bcrypt.compare(trimmedPin, account.pin_hash);
      } else {
        const systemPin = process.env.ADMIN_SECURITY_PIN || '123456';
        isPinValid = trimmedPin === systemPin.trim();
      }
    }

    if (!isPinValid && password && account?.password) {
      isPasswordValid = await bcrypt.compare(password, account.password);
    }

    if (!isPinValid && !isPasswordValid) {
      const err = new Error('Mã PIN hoặc mật khẩu quản trị viên không chính xác!');
      err.statusCode = 400;
      throw err;
    }

    // Ghi nhận Audit Log xác thực an toàn với đầy đủ Request (API) và Action (Nghiệp vụ)
    try {
      const { prisma } = require('../../config/db');
      await prisma.auditlog.create({
        data: {
          idaccount: currentUser?.idaccount || 1,
          request: 'POST /api/admin/verify-security-action',
          action: `[SECURITY] Xác thực hành động chí mạng: ${action || 'CRITICAL_ACTION'} (Mục tiêu: ${targetId || 'N/A'})`,
          req_status: 'Pass',
          reason: `Phương thức: ${isPinValid ? 'Mã PIN cá nhân' : 'Mật khẩu'}`,
          time_req: new Date(),
          time_res: new Date(),
        },
      });
    } catch (_) {}

    return {
      verified: true,
      action: action || 'CRITICAL_ACTION',
      verifiedAt: new Date().toISOString(),
    };
  },

  /**
   * Đổi mã PIN bảo mật riêng của tài khoản Admin (Lưu cứng CSDL, mã hóa bcrypt)
  /**
   * Thiết lập mật khẩu mới và mã PIN bảo mật cho Admin đăng nhập lần đầu
   */
  async firstLoginSetup({ newPassword, confirmPassword, pin, confirmPin } = {}, currentUser) {
    if (!currentUser?.idaccount) {
      const err = new Error('Yêu cầu xác thực tài khoản quản trị viên');
      err.statusCode = 401;
      throw err;
    }

    if (!newPassword || newPassword.length < 6) {
      const err = new Error('Mật khẩu mới phải có tối thiểu 6 ký tự');
      err.statusCode = 400;
      throw err;
    }

    if (newPassword === '123456') {
      const err = new Error('Mật khẩu mới không được trùng với mật khẩu mặc định (123456)');
      err.statusCode = 400;
      throw err;
    }

    if (confirmPassword && confirmPassword !== newPassword) {
      const err = new Error('Xác nhận mật khẩu mới không khớp');
      err.statusCode = 400;
      throw err;
    }

    if (!pin || typeof pin !== 'string' || !/^\d{6}$/.test(pin.trim())) {
      const err = new Error('Mã PIN bảo mật phải bao gồm đúng 6 chữ số (0-9)');
      err.statusCode = 400;
      throw err;
    }

    if (pin.trim() === '123456') {
      const err = new Error('Mã PIN bảo mật không được là mã mặc định (123456)');
      err.statusCode = 400;
      throw err;
    }

    if (confirmPin && confirmPin.trim() !== pin.trim()) {
      const err = new Error('Xác nhận mã PIN không khớp');
      err.statusCode = 400;
      throw err;
    }

    const bcrypt = require('bcryptjs');
    const account = await adminRepository.getAccountById(currentUser.idaccount);
    if (!account) {
      const err = new Error('Không tìm thấy tài khoản quản trị');
      err.statusCode = 404;
      throw err;
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);
    const pinHash = await bcrypt.hash(pin.trim(), 10);

    const updated = await adminRepository.updateFirstLoginSetup(currentUser.idaccount, passwordHash, pinHash);

    // Ghi nhận Audit Log
    try {
      const { prisma } = require('../../config/db');
      await prisma.auditlog.create({
        data: {
          idaccount: currentUser.idaccount,
          request: 'POST /api/admin/first-login-setup',
          action: '[SECURITY] Admin hoàn tất thiết lập mật khẩu và mã PIN lần đầu',
          req_status: 'Pass',
          reason: 'Hoàn tất thiết lập tài khoản ban đầu',
          time_req: new Date(),
          time_res: new Date(),
        },
      });
    } catch (_) {}

    return {
      success: true,
      message: 'Thiết lập mật khẩu và mã PIN bảo mật thành công!',
      user: {
        idaccount: updated.idaccount,
        username: updated.username,
        email: updated.email,
        fullname: updated.User ? updated.User.fullname : '',
        idrole: updated.idrole,
        rolename: updated.role ? updated.role.rolename : 'Admin',
        is_first_login: false,
      },
    };
  },

  /**
   * Đổi mã PIN bảo mật riêng của tài khoản Admin (Yêu cầu mật khẩu và mã PIN cũ)
   */
  async changeAdminPin({ oldPin, newPin, confirmPin, password } = {}, currentUser) {
    if (!currentUser?.idaccount) {
      const err = new Error('Yêu cầu xác thực tài khoản quản trị viên');
      err.statusCode = 401;
      throw err;
    }

    if (!password) {
      const err = new Error('Vui lòng nhập mật khẩu tài khoản hiện tại');
      err.statusCode = 400;
      throw err;
    }

    if (!newPin || typeof newPin !== 'string' || !/^\d{6}$/.test(newPin.trim())) {
      const err = new Error('Mã PIN mới phải gồm đúng 6 chữ số (0-9)');
      err.statusCode = 400;
      throw err;
    }

    if (confirmPin && confirmPin.trim() !== newPin.trim()) {
      const err = new Error('Xác nhận mã PIN mới không khớp');
      err.statusCode = 400;
      throw err;
    }

    if (oldPin && newPin.trim() === oldPin.trim()) {
      const err = new Error('Mã PIN mới không được trùng với mã PIN hiện tại');
      err.statusCode = 400;
      throw err;
    }

    const bcrypt = require('bcryptjs');
    const account = await adminRepository.getAccountById(currentUser.idaccount);
    if (!account) {
      const err = new Error('Không tìm thấy tài khoản quản trị');
      err.statusCode = 404;
      throw err;
    }

    // 1. Kiểm tra mật khẩu hiện tại
    const isPasswordValid = await bcrypt.compare(password, account.password);
    if (!isPasswordValid) {
      const err = new Error('Mật khẩu tài khoản hiện tại không chính xác!');
      err.statusCode = 400;
      throw err;
    }

    // 2. Kiểm tra mã PIN cũ
    let isOldPinValid = false;
    if (account.pin_hash) {
      isOldPinValid = await bcrypt.compare(oldPin ? oldPin.trim() : '', account.pin_hash);
    } else {
      const systemPin = process.env.ADMIN_SECURITY_PIN || '123456';
      isOldPinValid = (oldPin ? oldPin.trim() : '') === systemPin.trim();
    }

    if (!isOldPinValid) {
      const err = new Error('Mã PIN hiện tại không chính xác!');
      err.statusCode = 400;
      throw err;
    }

    // Hash mã PIN mới bằng bcryptjs
    const saltRounds = 10;
    const newPinHash = await bcrypt.hash(newPin.trim(), saltRounds);
    await adminRepository.updateAccountPin(currentUser.idaccount, newPinHash);

    // Ghi nhận Audit Log
    try {
      const { prisma } = require('../../config/db');
      await prisma.auditlog.create({
        data: {
          idaccount: currentUser.idaccount,
          request: 'POST /api/admin/change-pin',
          action: 'Đổi mã PIN bảo mật quản trị viên',
          req_status: 'Pass',
          reason: 'Cập nhật mã PIN cá nhân thành công',
          time_req: new Date(),
          time_res: new Date(),
        },
      });
    } catch (_) {}

    return {
      success: true,
      message: 'Đổi mã PIN bảo mật quản trị viên thành công!',
    };
  },

  /**
   * Đổi mật khẩu tài khoản Admin (Yêu cầu mật khẩu hiện tại và mã PIN bảo mật hiện tại)
   */
  async changeAdminPassword({ oldPassword, oldPin, pin, newPassword, confirmPassword } = {}, currentUser) {
    if (!currentUser?.idaccount) {
      const err = new Error('Yêu cầu xác thực tài khoản quản trị viên');
      err.statusCode = 401;
      throw err;
    }

    if (!oldPassword) {
      const err = new Error('Vui lòng nhập mật khẩu hiện tại');
      err.statusCode = 400;
      throw err;
    }

    const securityPin = (pin || oldPin || '').toString().trim();
    if (!securityPin) {
      const err = new Error('Vui lòng nhập mã PIN bảo mật hiện tại');
      err.statusCode = 400;
      throw err;
    }

    if (!newPassword || newPassword.length < 6) {
      const err = new Error('Mật khẩu mới phải có tối thiểu 6 ký tự');
      err.statusCode = 400;
      throw err;
    }

    if (newPassword === oldPassword) {
      const err = new Error('Mật khẩu mới không được trùng với mật khẩu hiện tại');
      err.statusCode = 400;
      throw err;
    }

    if (confirmPassword && confirmPassword !== newPassword) {
      const err = new Error('Xác nhận mật khẩu mới không khớp');
      err.statusCode = 400;
      throw err;
    }

    const bcrypt = require('bcryptjs');
    const account = await adminRepository.getAccountById(currentUser.idaccount);
    if (!account) {
      const err = new Error('Không tìm thấy tài khoản quản trị');
      err.statusCode = 404;
      throw err;
    }

    // 1. Kiểm tra mật khẩu cũ
    const isPasswordValid = await bcrypt.compare(oldPassword, account.password);
    if (!isPasswordValid) {
      const err = new Error('Mật khẩu hiện tại không chính xác!');
      err.statusCode = 400;
      throw err;
    }

    // 2. Kiểm tra mã PIN bảo mật hiện tại
    let isPinValid = false;
    if (account.pin_hash) {
      isPinValid = await bcrypt.compare(securityPin, account.pin_hash);
    } else {
      const systemPin = process.env.ADMIN_SECURITY_PIN || '123456';
      isPinValid = securityPin === systemPin.trim();
    }

    if (!isPinValid) {
      const err = new Error('Mã PIN bảo mật hiện tại không chính xác!');
      err.statusCode = 400;
      throw err;
    }

    const newPasswordHash = await bcrypt.hash(newPassword, 10);
    await adminRepository.updateAccountPassword(currentUser.idaccount, newPasswordHash);

    // Ghi nhận Audit Log
    try {
      const { prisma } = require('../../config/db');
      await prisma.auditlog.create({
        data: {
          idaccount: currentUser.idaccount,
          request: 'POST /api/admin/change-password',
          action: 'Đổi mật khẩu quản trị viên',
          req_status: 'Pass',
          reason: 'Cập nhật mật khẩu tài khoản Admin thành công',
          time_req: new Date(),
          time_res: new Date(),
        },
      });
    } catch (_) {}

    return {
      success: true,
      message: 'Đổi mật khẩu quản trị viên thành công!',
    };
  },

  /**
   * Cấp tài khoản quản trị viên mới (Xác thực mã PIN của admin người cấp)
   */
  async createAdminAccount({ username, email, pin, fullName, phone, address, countryCode, fullname, country_code } = {}, currentUser) {
    if (!currentUser?.idaccount) {
      const err = new Error('Yêu cầu xác thực tài khoản quản trị viên');
      err.statusCode = 401;
      throw err;
    }

    const resolvedFullName = (fullName || fullname || '').trim();
    if (!resolvedFullName || resolvedFullName.length < 2) {
      const err = new Error('Họ và tên quản trị viên phải có tối thiểu 2 ký tự');
      err.statusCode = 400;
      throw err;
    }

    if (!username || typeof username !== 'string' || username.trim().length < 3) {
      const err = new Error('Tên đăng nhập admin phải có tối thiểu 3 ký tự');
      err.statusCode = 400;
      throw err;
    }

    if (!/^[a-zA-Z0-9_.-]+$/.test(username.trim())) {
      const err = new Error('Tên đăng nhập chỉ được chứa chữ cái, số, dấu chấm, gạch dưới hoặc gạch ngang (không dấu, không khoảng trắng)');
      err.statusCode = 400;
      throw err;
    }

    if (!email || typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      const err = new Error('Email không hợp lệ');
      err.statusCode = 400;
      throw err;
    }

    const cleanPhone = phone ? String(phone).trim().replace(/[\s.-]/g, '') : '';
    if (!cleanPhone || !/^\+?[0-9]{8,15}$/.test(cleanPhone)) {
      const err = new Error('Số điện thoại không đúng định dạng (từ 8 đến 15 chữ số)');
      err.statusCode = 400;
      throw err;
    }

    const resolvedCountryCode = (countryCode || country_code || '+84').toString().trim().slice(0, 4);
    const resolvedAddress = address && typeof address === 'string' ? address.trim() : null;

    if (!pin || typeof pin !== 'string') {
      const err = new Error('Vui lòng nhập mã PIN bảo mật để xác thực quyền cấp tài khoản');
      err.statusCode = 400;
      throw err;
    }

    const bcrypt = require('bcryptjs');
    const creatorAccount = await adminRepository.getAccountById(currentUser.idaccount);
    if (!creatorAccount) {
      const err = new Error('Không tìm thấy thông tin tài khoản quản trị viên đang thao tác');
      err.statusCode = 404;
      throw err;
    }

    // 1. Xác thực mã PIN của admin người cấp
    let isPinValid = false;
    if (creatorAccount.pin_hash) {
      isPinValid = await bcrypt.compare(pin.trim(), creatorAccount.pin_hash);
    } else {
      const systemPin = process.env.ADMIN_SECURITY_PIN || '123456';
      isPinValid = pin.trim() === systemPin.trim();
    }

    if (!isPinValid) {
      const err = new Error('Mã PIN bảo mật của bạn không chính xác!');
      err.statusCode = 400;
      throw err;
    }

    // 2. Kiểm tra trùng lặp username hoặc email
    const existing = await adminRepository.findAccountByUsernameOrEmail(username.trim(), email.trim());
    if (existing) {
      const isEmail = existing.email.toLowerCase() === email.trim().toLowerCase();
      const err = new Error(isEmail ? 'Email này đã tồn tại trong hệ thống!' : 'Tên đăng nhập này đã tồn tại trong hệ thống!');
      err.statusCode = 400;
      throw err;
    }

    // 3. Khởi tạo mật khẩu mặc định (123456) và mã PIN mặc định (123456)
    const defaultPasswordHash = await bcrypt.hash('123456', 10);
    const defaultPinHash = await bcrypt.hash('123456', 10);

    const newAdmin = await adminRepository.createAdminAccount({
      username: username.trim(),
      email: email.trim(),
      passwordHash: defaultPasswordHash,
      pinHash: defaultPinHash,
      createdByAdminId: currentUser.idaccount,
      fullName: resolvedFullName,
      phone: cleanPhone,
      address: resolvedAddress,
      countryCode: resolvedCountryCode,
    });

    // Ghi nhận Audit Log
    try {
      const { prisma } = require('../../config/db');
      await prisma.auditlog.create({
        data: {
          idaccount: currentUser.idaccount,
          request: 'POST /api/admin/create-admin',
          action: `[ADMIN_MGMT] Cấp tài khoản quản trị mới: ${newAdmin.username} (${newAdmin.fullname || resolvedFullName} - ${newAdmin.email})`,
          req_status: 'Pass',
          reason: `Người cấp: Admin #${currentUser.idaccount}`,
          time_req: new Date(),
          time_res: new Date(),
        },
      });
    } catch (_) {}

    return {
      success: true,
      message: `Cấp tài khoản quản trị "${newAdmin.username}" thành công với mật khẩu và mã PIN khởi đầu là 123456.`,
      data: newAdmin,
    };
  },
};

function resolveFilterContext(params) {
  const vnNow = getVnTimeParts(new Date());
  let period = 'today';
  let customType = null;
  let customDate = null;
  let customMonth = null;
  let customYear = null;

  if (typeof params === 'string') {
    period = params;
  } else if (params && typeof params === 'object') {
    period = params.period || 'today';
    customType = params.customType || null;
    customDate = params.date || params.customDate || null;
    customMonth = params.month ? parseInt(params.month, 10) : null;
    customYear = params.year ? parseInt(params.year, 10) : null;
  }

  // 1. Custom Date (YYYY-MM-DD or date:YYYY-MM-DD)
  if (customType === 'date' || (period && period.startsWith('date:')) || (customDate && !customMonth)) {
    const rawDate = (customDate || period.replace('date:', '')).trim();
    const dateMatch = rawDate.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if (dateMatch) {
      const y = dateMatch[1];
      const m = dateMatch[2].padStart(2, '0');
      const d = dateMatch[3].padStart(2, '0');
      const startDate = new Date(`${y}-${m}-${d}T00:00:00+07:00`);
      const endDate = new Date(`${y}-${m}-${d}T23:59:59.999+07:00`);
      const prevStartDate = new Date(startDate.getTime() - 24 * 60 * 60 * 1000);
      const prevEndDate = new Date(endDate.getTime() - 24 * 60 * 60 * 1000);

      const buckets = [];
      for (let h = 0; h < 24; h++) {
        const key = h.toString().padStart(2, '0');
        const label = `${key}:00`;
        buckets.push({ key, label, count: 0 });
      }

      return {
        startDate,
        endDate,
        prevStartDate,
        prevEndDate,
        buckets,
        format: 'hour',
        period: `date:${y}-${m}-${d}`,
        label: `${d}/${m}/${y}`,
      };
    }
  }

  // 2. Custom Month (MM/YYYY)
  if (customType === 'month' || (period && period.startsWith('month:')) || (customMonth && customYear)) {
    let m = customMonth;
    let y = customYear;
    if (period && period.startsWith('month:')) {
      const parts = period.replace('month:', '').split('-');
      y = parseInt(parts[0], 10);
      m = parseInt(parts[1], 10);
    }
    if (m && y) {
      const monthStr = m.toString().padStart(2, '0');
      const daysInMonth = new Date(y, m, 0).getDate();
      const startDate = new Date(`${y}-${monthStr}-01T00:00:00+07:00`);
      const endDate = new Date(`${y}-${monthStr}-${daysInMonth.toString().padStart(2, '0')}T23:59:59.999+07:00`);

      const prevY = m === 1 ? y - 1 : y;
      const prevM = m === 1 ? 12 : m - 1;
      const prevMonthStr = prevM.toString().padStart(2, '0');
      const prevDaysInMonth = new Date(prevY, prevM, 0).getDate();
      const prevStartDate = new Date(`${prevY}-${prevMonthStr}-01T00:00:00+07:00`);
      const prevEndDate = new Date(`${prevY}-${prevMonthStr}-${prevDaysInMonth.toString().padStart(2, '0')}T23:59:59.999+07:00`);

      const buckets = [];
      for (let d = 1; d <= daysInMonth; d++) {
        const dayStr = d.toString().padStart(2, '0');
        const key = `${y}-${monthStr}-${dayStr}`;
        const label = `${dayStr}/${monthStr}`;
        buckets.push({ key, label, count: 0 });
      }

      return {
        startDate,
        endDate,
        prevStartDate,
        prevEndDate,
        buckets,
        format: 'day',
        period: `month:${y}-${monthStr}`,
        label: `Tháng ${m}/${y}`,
      };
    }
  }

  // 3. Custom Year (YYYY)
  if (customType === 'year' || (period && period.startsWith('year:')) || (customYear && !customMonth)) {
    let y = customYear;
    if (period && period.startsWith('year:')) {
      y = parseInt(period.replace('year:', ''), 10);
    }
    if (y) {
      const startDate = new Date(`${y}-01-01T00:00:00+07:00`);
      const endDate = new Date(`${y}-12-31T23:59:59.999+07:00`);
      const prevStartDate = new Date(`${y - 1}-01-01T00:00:00+07:00`);
      const prevEndDate = new Date(`${y - 1}-12-31T23:59:59.999+07:00`);

      const buckets = [];
      for (let m = 1; m <= 12; m++) {
        const monthStr = m.toString().padStart(2, '0');
        const key = `${y}-${monthStr}`;
        const label = `Thg ${m}`;
        buckets.push({ key, label, count: 0 });
      }

      return {
        startDate,
        endDate,
        prevStartDate,
        prevEndDate,
        buckets,
        format: 'month',
        period: `year:${y}`,
        label: `Năm ${y}`,
      };
    }
  }

  // 4. Standard Quick Periods: 7days, 1month, 1year, today (default)
  const normalized = (period || 'today').toLowerCase();

  if (normalized === '7days' || normalized === '7d') {
    const todayEnd = new Date(`${vnNow.year}-${vnNow.month}-${vnNow.day}T23:59:59.999+07:00`);
    const todayStart = new Date(`${vnNow.year}-${vnNow.month}-${vnNow.day}T00:00:00+07:00`);
    const startDate = new Date(todayStart.getTime() - 6 * 24 * 60 * 60 * 1000);
    const endDate = todayEnd;

    const prevStartDate = new Date(startDate.getTime() - 7 * 24 * 60 * 60 * 1000);
    const prevEndDate = new Date(startDate.getTime() - 1);

    const buckets = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(startDate.getTime() + i * 24 * 60 * 60 * 1000);
      const parts = getVnTimeParts(d);
      const key = `${parts.year}-${parts.month}-${parts.day}`;
      const label = `${parts.day}/${parts.month}`;
      buckets.push({ key, label, count: 0 });
    }
    return { startDate, endDate, prevStartDate, prevEndDate, buckets, format: 'day', period: '7days', label: '7 ngày' };
  }

  if (normalized === '1year' || normalized === '1y' || normalized === '12months' || normalized === 'year') {
    const currentY = parseInt(vnNow.year, 10);
    const currentM = parseInt(vnNow.month, 10);

    const buckets = [];
    for (let i = 11; i >= 0; i--) {
      let targetM = currentM - i;
      let targetY = currentY;
      while (targetM <= 0) {
        targetM += 12;
        targetY -= 1;
      }
      const monthStr = targetM.toString().padStart(2, '0');
      const key = `${targetY}-${monthStr}`;
      const label = `Thg ${targetM}`;
      buckets.push({ key, label, count: 0 });
    }

    const firstBucket = buckets[0];
    const lastBucket = buckets[buckets.length - 1];
    const [firstY, firstM] = firstBucket.key.split('-');
    const [lastY, lastM] = lastBucket.key.split('-');
    const lastDays = new Date(parseInt(lastY, 10), parseInt(lastM, 10), 0).getDate();

    const startDate = new Date(`${firstY}-${firstM}-01T00:00:00+07:00`);
    const endDate = new Date(`${lastY}-${lastM}-${lastDays.toString().padStart(2, '0')}T23:59:59.999+07:00`);

    const prevStartDate = new Date(`${parseInt(firstY, 10) - 1}-${firstM}-01T00:00:00+07:00`);
    const prevEndDate = new Date(`${parseInt(lastY, 10) - 1}-${lastM}-${lastDays.toString().padStart(2, '0')}T23:59:59.999+07:00`);

    return { startDate, endDate, prevStartDate, prevEndDate, buckets, format: 'month', period: '1year', label: '1 năm' };
  }

  if (normalized === '1month' || normalized === '1m' || normalized === '30days') {
    const todayEnd = new Date(`${vnNow.year}-${vnNow.month}-${vnNow.day}T23:59:59.999+07:00`);
    const todayStart = new Date(`${vnNow.year}-${vnNow.month}-${vnNow.day}T00:00:00+07:00`);
    const startDate = new Date(todayStart.getTime() - 29 * 24 * 60 * 60 * 1000);
    const endDate = todayEnd;

    const prevStartDate = new Date(startDate.getTime() - 30 * 24 * 60 * 60 * 1000);
    const prevEndDate = new Date(startDate.getTime() - 1);

    const buckets = [];
    for (let i = 0; i < 30; i++) {
      const d = new Date(startDate.getTime() + i * 24 * 60 * 60 * 1000);
      const parts = getVnTimeParts(d);
      const key = `${parts.year}-${parts.month}-${parts.day}`;
      const label = `${parts.day}/${parts.month}`;
      buckets.push({ key, label, count: 0 });
    }
    return { startDate, endDate, prevStartDate, prevEndDate, buckets, format: 'day', period: '1month', label: '1 tháng' };
  }

  // Default: today (24 hours theo giờ Việt Nam)
  const startDate = new Date(`${vnNow.year}-${vnNow.month}-${vnNow.day}T00:00:00+07:00`);
  const endDate = new Date(`${vnNow.year}-${vnNow.month}-${vnNow.day}T23:59:59.999+07:00`);

  const prevStartDate = new Date(startDate.getTime() - 24 * 60 * 60 * 1000);
  const prevEndDate = new Date(endDate.getTime() - 24 * 60 * 60 * 1000);

  const buckets = [];
  for (let h = 0; h < 24; h++) {
    const key = h.toString().padStart(2, '0');
    const label = `${key}:00`;
    buckets.push({ key, label, count: 0 });
  }
  return { startDate, endDate, prevStartDate, prevEndDate, buckets, format: 'hour', period: 'today', label: 'Hôm nay' };
}

adminService.formatUptimeDuration = formatUptimeDuration;
adminService.calcUptimePercent = calcUptimePercent;

module.exports = adminService;
