const { prisma } = require('../../config/db');

const syncRepository = {
  // ── Category ────────────────────────────────────────────

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

  // ── Soft delete utility ─────────────────────────────────

  async softDelete(entity, id) {
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
