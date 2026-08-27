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
        delete_at: null,
        account: { idrole: 2, delete_at: null },
      },
      select: {
        iduser: true,
        fullname: true,
        email: true,
        phone: true,
        address: true,
        country_code: true,
        create_at: true,
        account: {
          select: {
            username: true,
            status: true,
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
        account: {
          select: {
            username: true,
            status: true,
            idrole: true,
            role: { select: { rolename: true } },
          },
        },
      },
    });
  },

  async updateAccountStatus(iduser, newStatus) {
    return prisma.user.update({
      where: { iduser, account: { idrole: 2 } },
      data: {
        account: {
          update: { status: newStatus },
        },
      },
      select: {
        iduser: true,
        fullname: true,
        account: {
          select: { status: true },
        },
      },
    });
  },

  async getAllCategories() {
    return prisma.category.findMany({
      where: { delete_at: null },
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
    const crypto = require('crypto');
    return prisma.category.create({
      data: {
        idcategory: crypto.randomUUID(),
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
};

module.exports = adminRepository;
