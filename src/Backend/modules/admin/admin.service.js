const adminRepository = require('./admin.repository');

function resolvePeriodRange(period) {
  const now = new Date();

  // End of today (23:59:59.999) — dùng làm currentEnd cho tất cả period
  const endOfToday = new Date(now);
  endOfToday.setHours(23, 59, 59, 999);

  let currentStart, currentEnd, previousStart, previousEnd;

  switch (period) {
    case '7days': {
      // Current: 7 ngày gần nhất
      currentStart = new Date(now);
      currentStart.setDate(currentStart.getDate() - 7);
      currentEnd = endOfToday;

      // Previous: 7 ngày trước đó (day 8 → 14)
      previousEnd = new Date(currentStart);
      previousEnd.setMilliseconds(previousEnd.getMilliseconds() - 1);
      previousStart = new Date(previousEnd);
      previousStart.setDate(previousStart.getDate() - 7);
      break;
    }
    case '30days': {
      // Current: 30 ngày gần nhất
      currentStart = new Date(now);
      currentStart.setDate(currentStart.getDate() - 30);
      currentEnd = endOfToday;

      // Previous: 30 ngày trước đó (day 31 → 60)
      previousEnd = new Date(currentStart);
      previousEnd.setMilliseconds(previousEnd.getMilliseconds() - 1);
      previousStart = new Date(previousEnd);
      previousStart.setDate(previousStart.getDate() - 30);
      break;
    }
    case 'today':
    default: {
      // Current: hôm nay (00:00 → 23:59:59.999)
      currentStart = new Date(now);
      currentStart.setHours(0, 0, 0, 0);
      currentEnd = endOfToday;

      // Previous: hôm qua (00:00 → 23:59:59.999)
      previousEnd = new Date(currentStart);
      previousEnd.setMilliseconds(previousEnd.getMilliseconds() - 1);
      previousStart = new Date(previousEnd);
      previousStart.setHours(0, 0, 0, 0);
      break;
    }
  }

  return { currentStart, currentEnd, previousStart, previousEnd };
}

function calcGrowth(current, previous) {
  if (current === 0) return 0;
  if (previous === 0) return 100;
  return parseFloat(((current / previous) * 100).toFixed(2));
}

function resolveMonthRange(month, year) {
  // Current month: day 1 → last day of month
  const currentStart = new Date(year, month - 1, 1);
  const currentEnd = new Date(year, month, 0);
  // Nếu là tháng hiện tại → end = hôm nay
  const now = new Date();
  if (year === now.getFullYear() && month === now.getMonth() + 1) {
    currentEnd.setDate(now.getDate());
  }
  currentEnd.setHours(23, 59, 59, 999);

  // Previous month: day 1 → last day
  const previousStart = new Date(year, month - 2, 1);
  const previousEnd = new Date(year, month - 1, 0);
  previousEnd.setHours(23, 59, 59, 999);

  return { currentStart, currentEnd, previousStart, previousEnd };
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

  async getUserToTime(month, year) {
    const { currentStart, currentEnd, previousStart, previousEnd } = resolveMonthRange(month, year);

    const currentCount = await adminRepository.countUsersByRange(currentStart, currentEnd);
    const previousCount = await adminRepository.countUsersByRange(previousStart, previousEnd);
    const growth = calcGrowth(currentCount, previousCount);

    return {
      month,
      year,
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
      created_at: u.create_at,
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
      rolename: u.account.role.rolename,
      created_at: u.create_at,
      updated_at: u.update_at,
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
    const result = await adminRepository.createCategory({
      name: data.name,
      classify: data.classify,
      is_default: data.is_default || false,
      keyword: data.keyword,
      icon: data.icon,
      created_by: idaccount,
    });
    return { id: result.idcategory, name: result.name_category, classify: result.classify };
  },

  async updateCategory(idcategory, data) {
    const result = await adminRepository.updateCategory(idcategory, {
      name: data.name,
      classify: data.classify,
      is_default: data.is_default,
      keyword: data.keyword,
      icon: data.icon,
    });
    return { id: result.idcategory, name: result.name_category, classify: result.classify };
  },

  async deleteCategory(idcategory) {
    await adminRepository.deleteCategory(idcategory);
    return { id: idcategory };
  },

  async getLoginStats(period = '1month') {
    const { startDate, endDate, buckets, format, period: resolvedPeriod } = generateBuckets(period);
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
      summary: {
        total,
        max,
        avg,
      },
      timeline: buckets.map(({ label, count }) => ({ label, count })),
    };
  },

  async getRequestStats(period = '1month') {
    const { startDate, endDate, buckets, format, period: resolvedPeriod } = generateBuckets(period);
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
      summary: {
        total,
        max,
        avg,
      },
      timeline: buckets.map(({ label, count }) => ({ label, count })),
    };
  },
};

function generateBuckets(period) {
  const now = new Date();
  const normalized = (period || '1month').toLowerCase();

  if (normalized === '7days' || normalized === '7d') {
    const buckets = [];
    const startDate = new Date(now);
    startDate.setDate(startDate.getDate() - 6);
    startDate.setHours(0, 0, 0, 0);

    const endDate = new Date(now);
    endDate.setHours(23, 59, 59, 999);

    for (let i = 0; i < 7; i++) {
      const d = new Date(startDate);
      d.setDate(d.getDate() + i);
      const day = d.getDate().toString().padStart(2, '0');
      const month = (d.getMonth() + 1).toString().padStart(2, '0');
      const key = `${d.getFullYear()}-${month}-${day}`;
      const label = `${day}/${month}`;
      buckets.push({ key, label, count: 0 });
    }
    return { startDate, endDate, buckets, format: 'day', period: '7days' };
  }

  if (normalized === '1year' || normalized === '1y' || normalized === '12months' || normalized === 'year') {
    const buckets = [];
    const startDate = new Date(now.getFullYear(), now.getMonth() - 11, 1, 0, 0, 0, 0);
    const endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);

    for (let i = 0; i < 12; i++) {
      const d = new Date(now.getFullYear(), now.getMonth() - 11 + i, 1);
      const month = (d.getMonth() + 1).toString().padStart(2, '0');
      const year = d.getFullYear();
      const key = `${year}-${month}`;
      const label = `Thg ${month}`;
      buckets.push({ key, label, count: 0 });
    }
    return { startDate, endDate, buckets, format: 'month', period: '1year' };
  }

  if (normalized === '24hours' || normalized === '24h' || normalized === 'hour' || normalized === 'today') {
    const buckets = [];
    const startDate = new Date(now);
    startDate.setHours(0, 0, 0, 0);
    const endDate = new Date(now);
    endDate.setHours(23, 59, 59, 999);

    for (let h = 0; h < 24; h++) {
      const key = h.toString().padStart(2, '0');
      const label = `${key}:00`;
      buckets.push({ key, label, count: 0 });
    }
    return { startDate, endDate, buckets, format: 'hour', period: '24hours' };
  }

  // Default: 1month (30 days)
  const buckets = [];
  const startDate = new Date(now);
  startDate.setDate(startDate.getDate() - 29);
  startDate.setHours(0, 0, 0, 0);

  const endDate = new Date(now);
  endDate.setHours(23, 59, 59, 999);

  for (let i = 0; i < 30; i++) {
    const d = new Date(startDate);
    d.setDate(d.getDate() + i);
    const day = d.getDate().toString().padStart(2, '0');
    const month = (d.getMonth() + 1).toString().padStart(2, '0');
    const key = `${d.getFullYear()}-${month}-${day}`;
    const label = `${day}/${month}`;
    buckets.push({ key, label, count: 0 });
  }
  return { startDate, endDate, buckets, format: 'day', period: '1month' };
}

module.exports = adminService;
