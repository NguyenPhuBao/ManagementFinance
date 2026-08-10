const { prisma } = require('../../config/db');

const adminRepository = {
  async countUsers() {
    return prisma.user.count({
      where: {
        account: { idrole: 2 },
      },
    });
  },

  async countCategories() {
    return prisma.category.count();
  },

  async countUsersByRange(start, end) {
    return prisma.user.count({
      where: {
        account: { idrole: 2 },
        created_at: {
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
        location: true,
        created_at: true,
        account: {
          select: {
            username: true,
            status: true,
          },
        },
      },
      orderBy: { created_at: 'desc' },
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
        location: true,
        created_at: true,
        updated_at: true,
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
      select: {
        idcategory: true,
        namecategory: true,
        classify: true,
        is_default: true,
        created_at: true,
        updated_at: true,
        account: {
          select: {
            idaccount: true,
            username: true,
            User: { select: { fullname: true } },
          },
        },
      },
      orderBy: { created_at: 'desc' },
    });
  },

  async createCategory(data) {
    return prisma.category.create({
      data: {
        namecategory: data.name,
        classify: data.classify,
        is_default: data.is_default || false,
        created_by: data.created_by,
      },
    });
  },

  async updateCategory(id, data) {
    return prisma.category.update({
      where: { idcategory: id },
      data: {
        namecategory: data.name,
        classify: data.classify,
        is_default: data.is_default,
      },
    });
  },

  async deleteCategory(id) {
    return prisma.category.delete({
      where: { idcategory: id },
    });
  },
};

module.exports = adminRepository;
