const adminRepository = require('./admin.repository');

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
      idaccount: u.account.idaccount,
      fullname: u.fullname,
      email: u.email,
      phone: u.phone,
      address: u.address,
      country_code: u.country_code,
      username: u.account.username,
      status: u.account.status,
      type: u.account.type || 'Basic',
      created_at: u.create_at,
      updated_at: u.account.update_at || u.update_at,
    }));
  },

  async getUserDetail(iduser) {
    const u = await adminRepository.getUserById(iduser);
    if (!u) throw Object.assign(new Error('Không tìm thấy người dùng'), { statusCode: 404 });
    return {
      id: u.iduser,
      fullname: u.fullname,
      email: u.email,
      phone: u.phone,
      address: u.address,
      country_code: u.country_code,
      username: u.account.username,
      status: u.account.status,
      type: u.account.type || 'Basic',
      rolename: u.account.role.rolename,
      created_at: u.create_at,
      updated_at: u.account.update_at || u.update_at,
    };
  },

  async updateStatus(iduser) {
    const u = await adminRepository.getUserById(iduser);
    if (!u) throw Object.assign(new Error('Không tìm thấy người dùng'), { statusCode: 404 });

    const currentStatus = u.account.status;
    const newStatus = currentStatus === 'Active' ? 'Inactive' : 'Active';

    await adminRepository.updateAccountStatus(iduser, newStatus);
    const { invalidateAccountCache } = require('../../middleware/auth');
    invalidateAccountCache(u.account.idaccount);

    return {
      id: iduser,
      username: u.account.username,
      fullname: u.fullname,
      previousStatus: currentStatus,
      newStatus,
    };
  },

  async deleteUser(iduser) {
    const u = await adminRepository.getUserById(iduser);
    if (!u) {
      throw Object.assign(new Error('Không tìm thấy người dùng'), { statusCode: 404 });
    }

    if (u.account.idrole === 1) {
      throw Object.assign(new Error('Không thể xóa tài khoản Quản trị viên'), { statusCode: 403 });
    }

    const idaccount = u.account.idaccount;
    await adminRepository.softDeleteUser(iduser);

    // 1. Invalidate auth cache
    const { invalidateAccountCache } = require('../../middleware/auth');
    invalidateAccountCache(idaccount);

    // 2. Emit force logout via Socket.IO
    const { emitForceLogout } = require('../../core/socket');
    emitForceLogout(idaccount, 'ACCOUNT_DELETED', 'Tài khoản của bạn đã bị ngừng hoạt động hoặc xóa bởi quản trị viên.');

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
    return cats.map((c) => ({
      id: c.idcategory,
      name: c.name_category,
      classify: c.classify,
      is_default: c.is_default,
      is_group: c.is_group,
      idgroup: c.idgroup,
      keyword: c.keyword,
      icon: c.icon,
      created_by_id: c.create_by,
      created_by: c.account ? c.account.username : null,
      created_by_name: c.account?.User?.fullname || null,
      created_at: c.create_at,
      updated_at: c.update_at,
    }));
  },

  async addCategory(data, idaccount) {
    const trimmedName = (data.name || '').trim();
    if (!trimmedName) {
      throw Object.assign(new Error('Tên danh mục không được để trống'), { statusCode: 400 });
    }
    const isDefault = data.is_default === true || data.is_default === 'true';
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

    // 1. Nhóm 2: Check unique [Is_default & namecategory] (không được phép có 2 category hệ thống giống nhau)
    if (isDefault) {
      const existingDefault = await prisma.category.findFirst({
        where: {
          name_category: { equals: trimmedName, mode: 'insensitive' },
          is_default: true,
          delete_at: null,
        },
      });
      if (existingDefault) {
        throw Object.assign(new Error(`Danh mục hệ thống "${trimmedName}" đã tồn tại trong hệ thống. Không được phép tạo trùng tên.`), { statusCode: 400 });
      }
    } else if (idaccount) {
      // 2. Nhóm 1: Check unique [Idaccount & namecategory] (1 tài khoản không được có >1 category giống nhau)
      const existingUserCat = await prisma.category.findFirst({
        where: {
          create_by: Number(idaccount),
          name_category: { equals: trimmedName, mode: 'insensitive' },
          delete_at: null,
        },
      });
      if (existingUserCat) {
        throw Object.assign(new Error(`Tài khoản đã có danh mục "${trimmedName}". Không được phép tạo danh mục trùng tên.`), { statusCode: 400 });
      }
    }

    const result = await adminRepository.createCategory({
      name: trimmedName,
      classify: canonicalClassify,
      is_default: isDefault,
      keyword: data.keyword ? data.keyword.trim() : null,
      icon: data.icon,
      created_by: idaccount,
    });
    return { id: result.idcategory, name: result.name_category, classify: result.classify, keyword: result.keyword };
  },

  async updateCategory(idcategory, data, idaccount) {
    const trimmedName = (data.name || '').trim();
    if (!trimmedName) {
      throw Object.assign(new Error('Tên danh mục không được để trống'), { statusCode: 400 });
    }
    const isDefault = data.is_default === true || data.is_default === 'true';
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

    // Ràng buộc: Không cho phép chuyển đổi danh mục người dùng thành danh mục hệ thống
    if (!currentCat.is_default && isDefault) {
      throw Object.assign(new Error('Không cho phép chuyển đổi danh mục người dùng thành danh mục hệ thống. Chỉ có thể tạo mới danh mục hệ thống.'), { statusCode: 400 });
    }

    const targetIsDefault = data.is_default !== undefined ? isDefault : currentCat.is_default;
    const targetAccount = currentCat.create_by || (idaccount ? Number(idaccount) : null);

    // 1. Nhóm 2: Check unique [Is_default & namecategory] khi sửa (loại trừ chính idcategory đang sửa)
    if (targetIsDefault) {
      const existingDefault = await prisma.category.findFirst({
        where: {
          idcategory: { not: idcategory },
          name_category: { equals: trimmedName, mode: 'insensitive' },
          is_default: true,
          delete_at: null,
        },
      });
      if (existingDefault) {
        throw Object.assign(new Error(`Danh mục hệ thống "${trimmedName}" đã tồn tại trong hệ thống. Không được phép đổi tên trùng.`), { statusCode: 400 });
      }
    } else if (targetAccount) {
      // 2. Nhóm 1: Check unique [Idaccount & namecategory] khi sửa (loại trừ chính idcategory đang sửa)
      const existingUserCat = await prisma.category.findFirst({
        where: {
          idcategory: { not: idcategory },
          create_by: targetAccount,
          name_category: { equals: trimmedName, mode: 'insensitive' },
          delete_at: null,
        },
      });
      if (existingUserCat) {
        throw Object.assign(new Error(`Tài khoản đã có danh mục "${trimmedName}". Không được phép đổi tên trùng với danh mục đã có.`), { statusCode: 400 });
      }
    }

    const result = await adminRepository.updateCategory(idcategory, {
      name: trimmedName,
      classify: canonicalClassify,
      is_default: targetIsDefault,
      keyword: data.keyword !== undefined ? (data.keyword ? data.keyword.trim() : null) : undefined,
      icon: data.icon,
    });
    return { id: result.idcategory, name: result.name_category, classify: result.classify, keyword: result.keyword };
  },

  async deleteCategory(idcategory) {
    const { prisma } = require('../../config/db');
    const cat = await prisma.category.findUnique({ where: { idcategory } });
    if (!cat || cat.delete_at) {
      throw Object.assign(new Error('Không tìm thấy danh mục hoặc danh mục đã bị xóa'), { statusCode: 404 });
    }
    if (cat.is_default) {
      throw Object.assign(new Error('Không được phép xóa danh mục mặc định của hệ thống.'), { statusCode: 400 });
    }
    await adminRepository.deleteCategory(idcategory);
    return { id: idcategory };
  },

  async getLoginStats(params = 'today') {
    const { startDate, endDate, buckets, format, period: resolvedPeriod, label } = resolveFilterContext(params);
    const logs = await adminRepository.getLoginLogsByRange(startDate, endDate);

    const bucketMap = new Map();
    buckets.forEach((b) => bucketMap.set(b.key, b));

    for (const log of logs) {
      const d = new Date(log.time_req);
      let key;
      if (format === 'hour') {
        key = d.getHours().toString().padStart(2, '0');
      } else if (format === 'month') {
        const month = (d.getMonth() + 1).toString().padStart(2, '0');
        key = `${d.getFullYear()}-${month}`;
      } else {
        const day = d.getDate().toString().padStart(2, '0');
        const month = (d.getMonth() + 1).toString().padStart(2, '0');
        key = `${d.getFullYear()}-${month}-${day}`;
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
      const d = new Date(log.time_req);
      let key;
      if (format === 'hour') {
        key = d.getHours().toString().padStart(2, '0');
      } else if (format === 'month') {
        const month = (d.getMonth() + 1).toString().padStart(2, '0');
        key = `${d.getFullYear()}-${month}`;
      } else {
        const day = d.getDate().toString().padStart(2, '0');
        const month = (d.getMonth() + 1).toString().padStart(2, '0');
        key = `${d.getFullYear()}-${month}-${day}`;
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

module.exports = adminService;
