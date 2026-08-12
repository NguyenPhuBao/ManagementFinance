const { prisma } = require('../../config/db');

const syncRepository = {
  // ── Category ────────────────────────────────────────────

  async upsertCategory(data) {
    const existing = await prisma.category.findUnique({ where: { uuid: data.id } });
    if (!existing) {
      return prisma.category.create({
        data: {
          uuid: data.id,
          namecategory: data.namecategory || data.name,
          classify: data.classify || 'chi',
          is_default: data.is_default ?? false,
          created_by: data.idaccount,
        },
      });
    }
    // Chỉ user tạo mới được update category của mình, admin thì luôn được
    if (existing.is_default && existing.created_by !== data.idaccount) {
      throw new Error('Cannot modify system default category');
    }
    if (new Date(data.updated_at) > new Date(existing.updated_at)) {
      return prisma.category.update({
        where: { uuid: data.id },
        data: {
          namecategory: data.namecategory || data.name,
          classify: data.classify,
          is_default: data.is_default,
        },
      });
    }
    return null;
  },

  async getCategoryById(uuid) {
    return prisma.category.findUnique({ where: { uuid } });
  },

  async getCategoriesByAccount(idaccount, since) {
    return prisma.category.findMany({
      where: {
        OR: [
          { is_default: true },
          { created_by: idaccount },
        ],
        updated_at: since ? { gt: new Date(since) } : undefined,
      },
      select: {
        uuid: true,
        namecategory: true,
        classify: true,
        is_default: true,
        created_by: true,
        updated_at: true,
      },
      orderBy: { updated_at: 'asc' },
    });
  },

  async getCategoryByUuid(uuid) {
    return prisma.category.findUnique({ where: { uuid } });
  },

  // ── Wallet ──────────────────────────────────────────────

  async upsertWallet(data) {
    const existing = await prisma.wallet.findUnique({ where: { id: data.id } });
    if (!existing) {
      return prisma.wallet.create({ data });
    }
    if (new Date(data.updated_at) > new Date(existing.updated_at)) {
      return prisma.wallet.update({ where: { id: data.id }, data });
    }
    return null; // conflict — server version mới hơn
  },

  async getWalletsByAccount(idaccount, since) {
    return prisma.wallet.findMany({
      where: {
        idaccount,
        updated_at: since ? { gt: new Date(since) } : undefined,
      },
      orderBy: { updated_at: 'asc' },
    });
  },

  // ── Transaction ─────────────────────────────────────────

  async upsertTransaction(data) {
    const existing = await prisma.transaction.findUnique({ where: { id: data.id } });
    if (!existing) {
      return prisma.transaction.create({ data });
    }
    if (new Date(data.updated_at) > new Date(existing.updated_at)) {
      return prisma.transaction.update({ where: { id: data.id }, data });
    }
    return null;
  },

  async getTransactionsByAccount(idaccount, since) {
    return prisma.transaction.findMany({
      where: {
        idaccount,
        updated_at: since ? { gt: new Date(since) } : undefined,
      },
      orderBy: { updated_at: 'asc' },
    });
  },

  // ── Budget ──────────────────────────────────────────────

  async upsertBudget(data) {
    const existing = await prisma.budget.findUnique({ where: { id: data.id } });
    if (!existing) {
      return prisma.budget.create({ data });
    }
    if (new Date(data.updated_at) > new Date(existing.updated_at)) {
      return prisma.budget.update({ where: { id: data.id }, data });
    }
    return null;
  },

  async getBudgetsByAccount(idaccount, since) {
    return prisma.budget.findMany({
      where: {
        idaccount,
        updated_at: since ? { gt: new Date(since) } : undefined,
      },
      orderBy: { updated_at: 'asc' },
    });
  },

  // ── Bill ────────────────────────────────────────────────

  async upsertBill(data) {
    const existing = await prisma.bill.findUnique({ where: { id: data.id } });
    if (!existing) {
      return prisma.bill.create({ data });
    }
    if (new Date(data.updated_at) > new Date(existing.updated_at)) {
      return prisma.bill.update({ where: { id: data.id }, data });
    }
    return null;
  },

  async getBillsByAccount(idaccount, since) {
    return prisma.bill.findMany({
      where: {
        idaccount,
        updated_at: since ? { gt: new Date(since) } : undefined,
      },
      orderBy: { updated_at: 'asc' },
    });
  },

  // ── Goal ────────────────────────────────────────────────

  async upsertGoal(data) {
    const existing = await prisma.goal.findUnique({ where: { id: data.id } });
    if (!existing) {
      return prisma.goal.create({ data });
    }
    if (new Date(data.updated_at) > new Date(existing.updated_at)) {
      return prisma.goal.update({ where: { id: data.id }, data });
    }
    return null;
  },

  async getGoalsByAccount(idaccount, since) {
    return prisma.goal.findMany({
      where: {
        idaccount,
        updated_at: since ? { gt: new Date(since) } : undefined,
      },
      orderBy: { updated_at: 'asc' },
    });
  },

  // ── Lookup by ID (for conflict resolution) ──────────────

  async getWalletById(id) {
    return prisma.wallet.findUnique({ where: { id } });
  },

  async getTransactionById(id) {
    return prisma.transaction.findUnique({ where: { id } });
  },

  async getBudgetById(id) {
    return prisma.budget.findUnique({ where: { id } });
  },

  async getBillById(id) {
    return prisma.bill.findUnique({ where: { id } });
  },

  async getGoalById(id) {
    return prisma.goal.findUnique({ where: { id } });
  },

  // ── Count (for status endpoint) ─────────────────────────

  async countWallet(idaccount) {
    return prisma.wallet.count({ where: { idaccount } });
  },

  async countTransaction(idaccount) {
    return prisma.transaction.count({ where: { idaccount } });
  },

  async countBudget(idaccount) {
    return prisma.budget.count({ where: { idaccount } });
  },

  async countBill(idaccount) {
    return prisma.bill.count({ where: { idaccount } });
  },

  async countGoal(idaccount) {
    return prisma.goal.count({ where: { idaccount } });
  },

  async countCategory(idaccount) {
    return prisma.category.count({
      where: {
        OR: [
          { is_default: true },
          { created_by: idaccount },
        ],
      },
    });
  },

  // ── Soft delete utility ─────────────────────────────────

  async softDelete(entity, id) {
    // Category: hard delete (no is_deleted column), only user-created
    if (entity === 'category') {
      const cat = await prisma.category.findUnique({ where: { uuid: id } });
      if (!cat) return null;
      if (cat.is_default) throw new Error('Cannot delete system default category');
      await prisma.category.delete({ where: { uuid: id } });
      return { id, deleted: true };
    }

    const models = { wallet: prisma.wallet, transaction: prisma.transaction, budget: prisma.budget, bill: prisma.bill, goal: prisma.goal };
    const model = models[entity];
    if (!model) throw new Error(`Entity không hợp lệ: ${entity}`);

    const existing = await model.findUnique({ where: { id } });
    if (!existing) return null;

    return model.update({
      where: { id },
      data: { is_deleted: true, updated_at: new Date() },
    });
  },
};

module.exports = syncRepository;
