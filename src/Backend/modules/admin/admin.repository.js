const { prisma } = require('../../config/db');

const adminRepository = {
  async countUsers() {
    return prisma.user.count();
  },

  async countCategories() {
    return prisma.category.count();
  },
};

module.exports = adminRepository;
