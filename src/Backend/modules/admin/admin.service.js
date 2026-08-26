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
};

module.exports = adminService;
