const { randomUUID } = require('crypto');
const { prisma } = require('../../config/db');

const adminRepository = {
  async countUsers() {
    return prisma.user.count({
      where: {
        delete_at: null,
        account: { idrole: 2, delete_at: null },
      },
    });
  },

  async countCategories() {
    return prisma.category.count({
      where: { delete_at: null },
    });
  },

  async countUsersByRange(start, end) {
    return prisma.user.count({
      where: {
        delete_at: null,
        account: { idrole: 2, delete_at: null },
        create_at: {
          gte: start,
          lte: end,
        },
      },
    });
  },

  async getAllUsers() {
    return prisma.user.findMany({
      where: {
        account: { idrole: 2 },
      },
      select: {
        iduser: true,
        fullname: true,
        email: true,
        phone: true,
        address: true,
        country_code: true,
        create_at: true,
        update_at: true,
        delete_at: true,
        account: {
          select: {
            idaccount: true,
            username: true,
            status: true,
            type: true,
            reason_inactive: true,
            delete_at: true,
            update_at: true,
          },
        },
      },
      orderBy: { create_at: 'desc' },
    });
  },

  async getUserById(iduser) {
    return prisma.user.findUnique({
      where: { iduser, account: { idrole: 2 } },
      select: {
        iduser: true,
        fullname: true,
        email: true,
        phone: true,
        address: true,
        country_code: true,
        create_at: true,
        update_at: true,
        delete_at: true,
        account: {
          select: {
            idaccount: true,
            username: true,
            status: true,
            type: true,
            idrole: true,
            reason_inactive: true,
            delete_at: true,
            update_at: true,
            role: { select: { rolename: true } },
          },
        },
      },
    });
  },

  async updateAccountStatus(iduser, newStatus, reasonInactive = null) {
    return prisma.user.update({
      where: { iduser, account: { idrole: 2 } },
      data: {
        account: {
          update: {
            status: newStatus,
            reason_inactive: reasonInactive,
            update_at: new Date(),
          },
        },
        update_at: new Date(),
      },
      select: {
        iduser: true,
        fullname: true,
        account: {
          select: {
            username: true,
            status: true,
            type: true,
            reason_inactive: true,
          },
        },
      },
    });
  },

  async softDeleteUser(iduser) {
    const user = await prisma.user.findUnique({
      where: { iduser },
      select: {
        iduser: true,
        idaccount: true,
        account: { select: { idaccount: true, idrole: true, status: true, username: true } },
      },
    });
    if (!user) return null;

    const idaccount = user.idaccount;
    const now = new Date();

    return prisma.$transaction(async (tx) => {
      // 1. Soft delete account
      const updatedAccount = await tx.account.update({
        where: { idaccount },
        data: {
          status: 'Deleted',
          delete_at: now,
          update_at: now,
        },
      });

      // 2. Soft delete user
      const updatedUser = await tx.user.update({
        where: { iduser },
        data: {
          delete_at: now,
          update_at: now,
        },
      });

      // 3. Toàn bộ ví liên quan ngừng hoạt động (status = 'Inactive')
      await tx.wallet.updateMany({
        where: { idaccount, delete_at: null },
        data: {
          status: 'Inactive',
          update_at: now,
        },
      });

      // 4. Dữ liệu ngân hàng không bị xóa, ngắt kết nối (connect_status = 'Disconnected')
      await tx.bank_account.updateMany({
        where: { idaccount, delete_at: null },
        data: {
          connect_status: 'Disconnected',
          update_at: now,
        },
      });

      // 5. Thu hồi toàn bộ token ngay lập tức (status = true)
      await tx.refreshtoken.updateMany({
        where: { idaccount },
        data: {
          status: true,
          update_at: now,
        },
      });

      return {
        user: updatedUser,
        account: updatedAccount,
      };
    });
  },

  async getAllCategories(filters = {}) {
    const where = { delete_at: null };

    if (filters.created_by && filters.created_by !== 'all') {
      const createdByNum = Number(filters.created_by);
      if (!isNaN(createdByNum) && String(filters.created_by).trim() !== '') {
        where.create_by = createdByNum;
      } else {
        where.account = { username: { equals: String(filters.created_by).trim(), mode: 'insensitive' } };
      }
    }

    if (filters.keyword && typeof filters.keyword === 'string' && filters.keyword.trim()) {
      where.keyword = { contains: filters.keyword.trim(), mode: 'insensitive' };
    }

    if (filters.is_default !== undefined && filters.is_default !== 'all' && filters.is_default !== '') {
      where.is_default = filters.is_default === 'yes' || filters.is_default === 'true' || filters.is_default === true;
    }

    if (filters.classify && filters.classify !== 'all' && filters.classify !== '') {
      where.classify = filters.classify;
    }

    return prisma.category.findMany({
      where,
      select: {
        idcategory: true,
        create_by: true,
        name_category: true,
        classify: true,
        is_default: true,
        is_group: true,
        idgroup: true,
        keyword: true,
        icon: true,
        create_at: true,
        update_at: true,
        account: {
          select: {
            idaccount: true,
            username: true,
            User: { select: { fullname: true } },
          },
        },
      },
      orderBy: { create_at: 'desc' },
    });
  },

  async createCategory(data) {
    return prisma.category.create({
      data: {
        idcategory: randomUUID(),
        create_by: data.created_by,
        name_category: data.name,
        classify: data.classify,
        is_default: data.is_default || false,
        keyword: data.keyword || null,
        icon: data.icon || null,
        update_at: new Date(),
      },
    });
  },

  async updateCategory(idcategory, data) {
    return prisma.category.update({
      where: { idcategory },
      data: {
        name_category: data.name,
        classify: data.classify,
        is_default: data.is_default,
        keyword: data.keyword,
        icon: data.icon,
        update_at: new Date(),
      },
    });
  },

  async deleteCategory(idcategory) {
    // CSDL mới: xóa mềm (Delete_at) và unlink category con nếu là group
    const cat = await prisma.category.findUnique({ where: { idcategory } });
    if (cat && cat.is_group) {
      await prisma.category.updateMany({
        where: { idgroup: idcategory },
        data: { idgroup: null, update_at: new Date() },
      });
    }
    return prisma.category.update({
      where: { idcategory },
      data: { delete_at: new Date(), update_at: new Date() },
    });
  },

  async getLoginLogsByRange(startDate, endDate) {
    return prisma.auditlog.findMany({
      where: {
        request: { contains: 'Đăng nhập' },
        time_req: {
          gte: startDate,
          lte: endDate,
        },
      },
      select: {
        idlog: true,
        time_req: true,
        req_status: true,
      },
      orderBy: { time_req: 'asc' },
    });
  },

  async getRequestLogsByRange(startDate, endDate) {
    return prisma.auditlog.findMany({
      where: {
        time_req: {
          gte: startDate,
          lte: endDate,
        },
      },
      select: {
        idlog: true,
        time_req: true,
        req_status: true,
      },
      orderBy: { time_req: 'asc' },
    });
  },
};

module.exports = adminRepository;
