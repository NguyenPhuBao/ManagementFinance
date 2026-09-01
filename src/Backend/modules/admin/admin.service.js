const adminRepository = require('./admin.repository');

function calcGrowth(current, previous) {
  if (current === 0) return 0;
  if (previous === 0) return 100;
  return parseFloat(((current / previous) * 100).toFixed(2));
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
    return {
      id: iduser,
      username: u.account.username,
      fullname: u.fullname,
      previousStatus: currentStatus,
      newStatus,
    };
  },

  async getCategories() {
    const cats = await adminRepository.getAllCategories();
    return cats.map((c) => ({
      id: c.idcategory,
      name: c.name_category,
      classify: c.classify,
      is_default: c.is_default,
      is_group: c.is_group,
      idgroup: c.idgroup,
      keyword: c.keyword,
      icon: c.icon,
      created_by: c.account ? c.account.username : null,
      created_by_name: c.account?.User?.fullname || null,
      created_at: c.create_at,
      updated_at: c.update_at,
    }));
  },

  async addCategory(data, idaccount) {
    const trimmedName = (data.name || '').trim();
    const isDefault = data.is_default === true || data.is_default === 'true';
    const validClassifies = ['Thu', 'Chi', 'Vay/nợ', 'Vay/no', 'Vay', 'no'];
    if (!validClassifies.includes(data.classify)) {
      throw Object.assign(new Error(`Loại danh mục '${data.classify}' không hợp lệ. Phải là Thu, Chi, hoặc Vay/nợ`), { statusCode: 400 });
    }
    const { prisma } = require('../../config/db');

    // Chỉ kiểm tra trùng lặp với danh mục mặc định hệ thống (is_default === true)
    if (isDefault) {
      const existing = await prisma.category.findFirst({
        where: {
          name_category: { equals: trimmedName, mode: 'insensitive' },
          classify: data.classify,
          is_default: true,
          delete_at: null,
        },
      });
      if (existing) {
        throw Object.assign(new Error(`Danh mục mặc định "${trimmedName}" (${data.classify}) đã tồn tại trong hệ thống`), { statusCode: 400 });
      }
    }

    const result = await adminRepository.createCategory({
      name: trimmedName,
      classify: data.classify,
      is_default: isDefault,
      keyword: data.keyword,
      icon: data.icon,
      created_by: idaccount,
    });
    return { id: result.idcategory, name: result.name_category, classify: result.classify };
  },

  async updateCategory(idcategory, data) {
    const trimmedName = (data.name || '').trim();
    const isDefault = data.is_default === true || data.is_default === 'true';
    const validClassifies = ['Thu', 'Chi', 'Vay/nợ', 'Vay/no', 'Vay', 'no'];
    if (data.classify && !validClassifies.includes(data.classify)) {
      throw Object.assign(new Error(`Loại danh mục '${data.classify}' không hợp lệ. Phải là Thu, Chi, hoặc Vay/nợ`), { statusCode: 400 });
    }
    const { prisma } = require('../../config/db');

    // Chỉ kiểm tra trùng lặp với danh mục mặc định hệ thống (is_default === true)
    if (isDefault) {
      const existing = await prisma.category.findFirst({
        where: {
          idcategory: { not: idcategory },
          name_category: { equals: trimmedName, mode: 'insensitive' },
          classify: data.classify,
          is_default: true,
          delete_at: null,
        },
      });
      if (existing) {
        throw Object.assign(new Error(`Danh mục mặc định "${trimmedName}" (${data.classify}) đã tồn tại trong hệ thống`), { statusCode: 400 });
      }
    }

    const result = await adminRepository.updateCategory(idcategory, {
      name: trimmedName,
      classify: data.classify,
      is_default: isDefault,
      keyword: data.keyword,
      icon: data.icon,
    });
    return { id: result.idcategory, name: result.name_category, classify: result.classify };
  },

  async deleteCategory(idcategory) {
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
  const now = new Date();
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

  // 1. Custom Date (DD/MM/YYYY or YYYY-MM-DD)
  if (customType === 'date' || (period && period.startsWith('date:')) || (customDate && !customMonth)) {
    const rawDate = customDate || period.replace('date:', '');
    const targetDate = new Date(rawDate);
    if (!isNaN(targetDate.getTime())) {
      const startDate = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 0, 0, 0, 0);
      const endDate = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 23, 59, 59, 999);
      const prevStartDate = new Date(startDate);
      prevStartDate.setDate(prevStartDate.getDate() - 1);
      const prevEndDate = new Date(endDate);
      prevEndDate.setDate(prevEndDate.getDate() - 1);

      const buckets = [];
      for (let h = 0; h < 24; h++) {
        const key = h.toString().padStart(2, '0');
        const label = `${key}:00`;
        buckets.push({ key, label, count: 0 });
      }

      const dayStr = startDate.getDate().toString().padStart(2, '0');
      const monthStr = (startDate.getMonth() + 1).toString().padStart(2, '0');
      return {
        startDate,
        endDate,
        prevStartDate,
        prevEndDate,
        buckets,
        format: 'hour',
        period: `date:${startDate.getFullYear()}-${monthStr}-${dayStr}`,
        label: `${dayStr}/${monthStr}/${startDate.getFullYear()}`,
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
      const startDate = new Date(y, m - 1, 1, 0, 0, 0, 0);
      const daysInMonth = new Date(y, m, 0).getDate();
      const endDate = new Date(y, m - 1, daysInMonth, 23, 59, 59, 999);
      const prevStartDate = new Date(y, m - 2, 1, 0, 0, 0, 0);
      const prevDaysInMonth = new Date(y, m - 1, 0).getDate();
      const prevEndDate = new Date(y, m - 2, prevDaysInMonth, 23, 59, 59, 999);

      const buckets = [];
      const monthStr = m.toString().padStart(2, '0');
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
      const startDate = new Date(y, 0, 1, 0, 0, 0, 0);
      const endDate = new Date(y, 11, 31, 23, 59, 59, 999);
      const prevStartDate = new Date(y - 1, 0, 1, 0, 0, 0, 0);
      const prevEndDate = new Date(y - 1, 11, 31, 23, 59, 59, 999);

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
    const startDate = new Date(now);
    startDate.setDate(startDate.getDate() - 6);
    startDate.setHours(0, 0, 0, 0);
    const endDate = new Date(now);
    endDate.setHours(23, 59, 59, 999);

    const prevStartDate = new Date(startDate);
    prevStartDate.setDate(prevStartDate.getDate() - 7);
    const prevEndDate = new Date(startDate);
    prevEndDate.setMilliseconds(prevEndDate.getMilliseconds() - 1);

    const buckets = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(startDate);
      d.setDate(d.getDate() + i);
      const day = d.getDate().toString().padStart(2, '0');
      const month = (d.getMonth() + 1).toString().padStart(2, '0');
      const key = `${d.getFullYear()}-${month}-${day}`;
      const label = `${day}/${month}`;
      buckets.push({ key, label, count: 0 });
    }
    return { startDate, endDate, prevStartDate, prevEndDate, buckets, format: 'day', period: '7days', label: '7 ngày' };
  }

  if (normalized === '1year' || normalized === '1y' || normalized === '12months' || normalized === 'year') {
    const startDate = new Date(now.getFullYear(), now.getMonth() - 11, 1, 0, 0, 0, 0);
    const endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

    const prevStartDate = new Date(now.getFullYear() - 1, now.getMonth() - 11, 1, 0, 0, 0, 0);
    const prevEndDate = new Date(now.getFullYear() - 1, now.getMonth() + 1, 0, 23, 59, 59, 999);

    const buckets = [];
    for (let i = 0; i < 12; i++) {
      const d = new Date(now.getFullYear(), now.getMonth() - 11 + i, 1);
      const month = (d.getMonth() + 1).toString().padStart(2, '0');
      const year = d.getFullYear();
      const key = `${year}-${month}`;
      const label = `Thg ${month}`;
      buckets.push({ key, label, count: 0 });
    }
    return { startDate, endDate, prevStartDate, prevEndDate, buckets, format: 'month', period: '1year', label: '1 năm' };
  }

  if (normalized === '1month' || normalized === '1m' || normalized === '30days') {
    const startDate = new Date(now);
    startDate.setDate(startDate.getDate() - 29);
    startDate.setHours(0, 0, 0, 0);
    const endDate = new Date(now);
    endDate.setHours(23, 59, 59, 999);

    const prevStartDate = new Date(startDate);
    prevStartDate.setDate(prevStartDate.getDate() - 30);
    const prevEndDate = new Date(startDate);
    prevEndDate.setMilliseconds(prevEndDate.getMilliseconds() - 1);

    const buckets = [];
    for (let i = 0; i < 30; i++) {
      const d = new Date(startDate);
      d.setDate(d.getDate() + i);
      const day = d.getDate().toString().padStart(2, '0');
      const month = (d.getMonth() + 1).toString().padStart(2, '0');
      const key = `${d.getFullYear()}-${month}-${day}`;
      const label = `${day}/${month}`;
      buckets.push({ key, label, count: 0 });
    }
    return { startDate, endDate, prevStartDate, prevEndDate, buckets, format: 'day', period: '1month', label: '1 tháng' };
  }

  // Default: today (24 hours)
  const startDate = new Date(now);
  startDate.setHours(0, 0, 0, 0);
  const endDate = new Date(now);
  endDate.setHours(23, 59, 59, 999);

  const prevStartDate = new Date(startDate);
  prevStartDate.setDate(prevStartDate.getDate() - 1);
  const prevEndDate = new Date(endDate);
  prevEndDate.setDate(prevEndDate.getDate() - 1);

  const buckets = [];
  for (let h = 0; h < 24; h++) {
    const key = h.toString().padStart(2, '0');
    const label = `${key}:00`;
    buckets.push({ key, label, count: 0 });
  }
  return { startDate, endDate, prevStartDate, prevEndDate, buckets, format: 'hour', period: 'today', label: 'Hôm nay' };
}

module.exports = adminService;
