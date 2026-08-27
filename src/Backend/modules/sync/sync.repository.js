const { prisma } = require('../../config/db');

// Map field client → DB theo CSDL mới
// Category: idcategory (PK uuid), name_category, create_by, is_group, idgroup, keyword, delete_at
// Wallet: idwallet, include_in_total, status, id_bank_casso, update_at
// Transaction: idtran, create_at, update_at, bank_tran_id, wallet_transfer
// Budget: idbudget, total_amount, spent, remaining, percent_spent, over_spending, over_amount, time_recurrence
// Bill: idbill, idwallet, idcategory, pay_status, time_recurrence
// Goal: idgoal, idwallet, status_complete

// Chuyển đổi tên cột khi client gửi (camelCase → snake_case DB)
function mapEntityFields(entity, data) {
  const m = { ...data };
  switch (entity) {
    case 'wallet':
      if (m.id) { m.idwallet = m.id; delete m.id; }
      if (m.isDefault !== undefined) { m.is_default = m.isDefault; delete m.isDefault; }
      if (m.includeInTotal !== undefined) { m.include_in_total = m.includeInTotal; delete m.includeInTotal; }
      if (m.idBankCasso !== undefined) { m.id_bank_casso = m.idBankCasso; delete m.idBankCasso; }
      if (m.updatedAt !== undefined) { m.update_at = new Date(m.updatedAt); delete m.updatedAt; }
      if (m.isDeleted !== undefined) { m.delete_at = m.isDeleted ? new Date() : null; delete m.isDeleted; }
      break;
    case 'transaction':
      if (m.id) { m.idtran = m.id; delete m.id; }
      if (m.categoryId !== undefined) { m.idcategory = m.categoryId; delete m.categoryId; }
      if (m.walletId !== undefined) { m.idwallet = m.walletId; delete m.walletId; }
      if (m.walletTransfer !== undefined) { m.wallet_transfer = m.walletTransfer; delete m.walletTransfer; }
      if (m.bankTranId !== undefined) { m.bank_tran_id = m.bankTranId; delete m.bankTranId; }
      if (m.createdAt !== undefined) { m.create_at = new Date(m.createdAt); delete m.createdAt; }
      if (m.updatedAt !== undefined) { m.update_at = new Date(m.updatedAt); delete m.updatedAt; }
      if (m.isDeleted !== undefined) { m.delete_at = m.isDeleted ? new Date() : null; delete m.isDeleted; }
      break;
    case 'budget':
      if (m.id) { m.idbudget = m.id; delete m.id; }
      if (m.categoryId !== undefined) { m.idcategory = m.categoryId; delete m.categoryId; }
      if (m.totalAmount !== undefined) { m.total_amount = m.totalAmount; delete m.totalAmount; }
      if (m.percentSpent !== undefined) { m.percent_spent = m.percentSpent; delete m.percentSpent; }
      if (m.overSpending !== undefined) { m.over_spending = m.overSpending; delete m.overSpending; }
      if (m.overAmount !== undefined) { m.over_amount = m.overAmount; delete m.overAmount; }
      if (m.timeRecurrence !== undefined) { m.time_recurrence = m.timeRecurrence; delete m.timeRecurrence; }
      if (m.updatedAt !== undefined) { m.update_at = new Date(m.updatedAt); delete m.updatedAt; }
      if (m.isDeleted !== undefined) { m.delete_at = m.isDeleted ? new Date() : null; delete m.isDeleted; }
      break;
    case 'bill':
      if (m.id) { m.idbill = m.id; delete m.id; }
      if (m.walletId !== undefined) { m.idwallet = m.walletId; delete m.walletId; }
      if (m.categoryId !== undefined) { m.idcategory = m.categoryId; delete m.categoryId; }
      if (m.dueDate !== undefined) { m.due_date = new Date(m.dueDate); delete m.dueDate; }
      if (m.payStatus !== undefined) { m.pay_status = m.payStatus; delete m.payStatus; }
      if (m.timeRecurrence !== undefined) { m.time_recurrence = m.timeRecurrence; delete m.timeRecurrence; }
      if (m.updatedAt !== undefined) { m.update_at = new Date(m.updatedAt); delete m.updatedAt; }
      if (m.isDeleted !== undefined) { m.delete_at = m.isDeleted ? new Date() : null; delete m.isDeleted; }
      break;
    case 'goal':
      if (m.id) { m.idgoal = m.id; delete m.id; }
      if (m.walletId !== undefined) { m.idwallet = m.walletId; delete m.walletId; }
      if (m.targetAmount !== undefined) { m.target_amount = m.targetAmount; delete m.targetAmount; }
      if (m.currentAmount !== undefined) { m.current_amount = m.currentAmount; delete m.currentAmount; }
      if (m.targetDate !== undefined) { m.target_date = new Date(m.targetDate); delete m.targetDate; }
      if (m.statusComplete !== undefined) { m.status_complete = m.statusComplete; delete m.statusComplete; }
      if (m.updatedAt !== undefined) { m.update_at = new Date(m.updatedAt); delete m.updatedAt; }
      if (m.isDeleted !== undefined) { m.delete_at = m.isDeleted ? new Date() : null; delete m.isDeleted; }
      break;
    case 'category':
      if (m.id) { m.idcategory = m.id; delete m.id; }
      if (m.idaccount !== undefined) { m.create_by = m.idaccount; delete m.idaccount; }
      if (m.createdBy !== undefined) { m.create_by = m.createdBy; delete m.createdBy; }
      if (m.nameCategory !== undefined) { m.name_category = m.nameCategory; delete m.nameCategory; }
      if (m.isGroup !== undefined) { m.is_group = m.isGroup; delete m.isGroup; }
      if (m.isDefault !== undefined) { m.is_default = m.isDefault; delete m.isDefault; }
      if (m.parentId !== undefined) { m.idgroup = m.parentId; delete m.parentId; }
      if (m.updatedAt !== undefined) { m.update_at = new Date(m.updatedAt); delete m.updatedAt; }
      if (m.isDeleted !== undefined) { m.delete_at = m.isDeleted ? new Date() : null; delete m.isDeleted; }
      break;
  }
  return m;
}

const syncRepository = {
  // ── Category ────────────────────────────────────────────
  // CSDL mới: PK = idcategory (uuid). Hỗ trợ group (is_group) + con (idgroup)

  async upsertCategory(data) {
    const mapped = mapEntityFields('category', data);
    const existing = await prisma.category.findUnique({ where: { idcategory: mapped.idcategory } });
    if (!existing) {
      // Danh mục default toàn cục do admin quản lý — nếu client gửi category default thì gán create_by admin
      return prisma.category.create({
        data: {
          idcategory: mapped.idcategory,
          create_by: mapped.create_by ?? 1,
          name_category: mapped.name_category || mapped.name || 'Chưa đặt tên',
          classify: mapped.classify || 'Chi',
          is_default: mapped.is_default ?? false,
          is_group: mapped.is_group ?? false,
          idgroup: mapped.idgroup || null,
          keyword: mapped.keyword || null,
          icon: mapped.icon || null,
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    // Chỉ user tạo mới được update category của mình, system category không được sửa bởi user thường
    if (existing.is_default && existing.create_by !== mapped.create_by) {
      throw new Error('Cannot modify system default category');
    }
    if (!existing.is_default && mapped.create_by && existing.create_by !== mapped.create_by) {
      throw new Error('Cannot modify category belonging to another user');
    }
    if (new Date(mapped.update_at) > new Date(existing.update_at)) {
      return prisma.category.update({
        where: { idcategory: existing.idcategory },
        data: {
          name_category: mapped.name_category || mapped.name || existing.name_category,
          classify: mapped.classify || existing.classify,
          is_group: mapped.is_group ?? existing.is_group,
          idgroup: mapped.idgroup !== undefined ? mapped.idgroup : existing.idgroup,
          keyword: mapped.keyword !== undefined ? mapped.keyword : existing.keyword,
          icon: mapped.icon !== undefined ? mapped.icon : existing.icon,
          delete_at: mapped.delete_at !== undefined ? mapped.delete_at : existing.delete_at,
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    return null;
  },

  async getCategoryById(idcategory) {
    return prisma.category.findUnique({ where: { idcategory } });
  },

  async getCategoriesByAccount(idaccount, since) {
    return prisma.category.findMany({
      where: {
        OR: [
          { is_default: true },
          { create_by: idaccount },
        ],
        update_at: since ? { gt: new Date(since) } : undefined,
      },
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
        delete_at: true,
        update_at: true,
      },
      orderBy: { update_at: 'asc' },
    });
  },

  // ── Wallet ──────────────────────────────────────────────

  async upsertWallet(data) {
    const mapped = mapEntityFields('wallet', data);
    const existing = await prisma.wallet.findUnique({ where: { idwallet: mapped.idwallet } });
    if (!existing) {
      return prisma.wallet.create({
        data: {
          idwallet: mapped.idwallet,
          idaccount: mapped.idaccount,
          name: mapped.name || 'Ví mới',
          type: mapped.type || 'Cash',
          balance: mapped.balance ?? 0,
          currency: mapped.currency || 'VND',
          status: mapped.status || 'Active',
          include_in_total: mapped.include_in_total ?? true,
          is_default: mapped.is_default ?? false,
          id_bank_casso: mapped.id_bank_casso || null,
          icon: mapped.icon || 'wallet',
          color: mapped.color || '#4CAF50',
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    if (new Date(mapped.update_at) > new Date(existing.update_at)) {
      return prisma.wallet.update({
        where: { idwallet: existing.idwallet },
        data: {
          name: mapped.name ?? existing.name,
          type: mapped.type ?? existing.type,
          balance: mapped.balance ?? existing.balance,
          currency: mapped.currency ?? existing.currency,
          status: mapped.status ?? existing.status,
          include_in_total: mapped.include_in_total ?? existing.include_in_total,
          is_default: mapped.is_default ?? existing.is_default,
          id_bank_casso: mapped.id_bank_casso !== undefined ? mapped.id_bank_casso : existing.id_bank_casso,
          icon: mapped.icon ?? existing.icon,
          color: mapped.color ?? existing.color,
          delete_at: mapped.delete_at !== undefined ? mapped.delete_at : existing.delete_at,
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    return null; // conflict — server version mới hơn
  },

  async getWalletsByAccount(idaccount, since) {
    return prisma.wallet.findMany({
      where: {
        idaccount,
        update_at: since ? { gt: new Date(since) } : undefined,
      },
      orderBy: { update_at: 'asc' },
    });
  },

  // ── Transaction ─────────────────────────────────────────

  async upsertTransaction(data) {
    const mapped = mapEntityFields('transaction', data);
    const existing = await prisma.transaction.findUnique({ where: { idtran: mapped.idtran } });
    if (!existing) {
      return prisma.transaction.create({
        data: {
          idtran: mapped.idtran,
          idaccount: mapped.idaccount,
          idwallet: mapped.idwallet,
          idcategory: mapped.idcategory || null,
          amount: mapped.amount ?? 0,
          type: mapped.type || 'Transaction',
          provider: mapped.provider || 'Manual',
          note: mapped.note || '',
          images: mapped.images || null,
          create_at: mapped.create_at || new Date(),
          update_at: mapped.update_at || new Date(),
          wallet_transfer: mapped.wallet_transfer || null,
          bank_tran_id: mapped.bank_tran_id || null,
        },
      });
    }
    if (new Date(mapped.update_at) > new Date(existing.update_at)) {
      return prisma.transaction.update({
        where: { idtran: existing.idtran },
        data: {
          idcategory: mapped.idcategory !== undefined ? mapped.idcategory : existing.idcategory,
          amount: mapped.amount ?? existing.amount,
          type: mapped.type ?? existing.type,
          provider: mapped.provider ?? existing.provider,
          note: mapped.note ?? existing.note,
          images: mapped.images !== undefined ? mapped.images : existing.images,
          wallet_transfer: mapped.wallet_transfer !== undefined ? mapped.wallet_transfer : existing.wallet_transfer,
          delete_at: mapped.delete_at !== undefined ? mapped.delete_at : existing.delete_at,
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    return null;
  },

  async getTransactionsByAccount(idaccount, since) {
    return prisma.transaction.findMany({
      where: {
        idaccount,
        update_at: since ? { gt: new Date(since) } : undefined,
      },
      orderBy: { update_at: 'asc' },
    });
  },

  // ── Budget ──────────────────────────────────────────────

  async upsertBudget(data) {
    const mapped = mapEntityFields('budget', data);
    const existing = await prisma.budget.findUnique({ where: { idbudget: mapped.idbudget } });
    if (!existing) {
      return prisma.budget.create({
        data: {
          idbudget: mapped.idbudget,
          idaccount: mapped.idaccount,
          idcategory: mapped.idcategory || null,
          total_amount: mapped.total_amount ?? 0,
          spent: mapped.spent ?? 0,
          remaining: mapped.remaining ?? null,
          percent_spent: mapped.percent_spent ?? 0,
          over_spending: mapped.over_spending || 'Over',
          over_amount: mapped.over_amount ?? null,
          start: mapped.start || new Date(),
          end: mapped.end || null,
          recurrence: mapped.recurrence ?? false,
          time_recurrence: mapped.time_recurrence || 'Month',
          note: mapped.note || null,
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    if (new Date(mapped.update_at) > new Date(existing.update_at)) {
      return prisma.budget.update({
        where: { idbudget: existing.idbudget },
        data: {
          idcategory: mapped.idcategory !== undefined ? mapped.idcategory : existing.idcategory,
          total_amount: mapped.total_amount ?? existing.total_amount,
          spent: mapped.spent ?? existing.spent,
          remaining: mapped.remaining !== undefined ? mapped.remaining : existing.remaining,
          percent_spent: mapped.percent_spent ?? existing.percent_spent,
          over_spending: mapped.over_spending ?? existing.over_spending,
          over_amount: mapped.over_amount !== undefined ? mapped.over_amount : existing.over_amount,
          start: mapped.start ?? existing.start,
          end: mapped.end !== undefined ? mapped.end : existing.end,
          recurrence: mapped.recurrence ?? existing.recurrence,
          time_recurrence: mapped.time_recurrence ?? existing.time_recurrence,
          note: mapped.note !== undefined ? mapped.note : existing.note,
          delete_at: mapped.delete_at !== undefined ? mapped.delete_at : existing.delete_at,
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    return null;
  },

  async getBudgetsByAccount(idaccount, since) {
    return prisma.budget.findMany({
      where: {
        idaccount,
        update_at: since ? { gt: new Date(since) } : undefined,
      },
      orderBy: { update_at: 'asc' },
    });
  },

  // ── Bill ────────────────────────────────────────────────

  async upsertBill(data) {
    const mapped = mapEntityFields('bill', data);
    const existing = await prisma.bill.findUnique({ where: { idbill: mapped.idbill } });
    if (!existing) {
      return prisma.bill.create({
        data: {
          idbill: mapped.idbill,
          idaccount: mapped.idaccount,
          idwallet: mapped.idwallet,
          idcategory: mapped.idcategory,
          name: mapped.name || 'Hóa đơn',
          amount: mapped.amount ?? 0,
          due_date: mapped.due_date || new Date(),
          pay_status: mapped.pay_status ?? false,
          recurrence: mapped.recurrence ?? false,
          time_recurrence: mapped.time_recurrence || 'Month',
          icon: mapped.icon || 'receipt',
          color: mapped.color || '#4CAF50',
          note: mapped.note || null,
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    if (new Date(mapped.update_at) > new Date(existing.update_at)) {
      return prisma.bill.update({
        where: { idbill: existing.idbill },
        data: {
          name: mapped.name ?? existing.name,
          amount: mapped.amount ?? existing.amount,
          due_date: mapped.due_date ?? existing.due_date,
          pay_status: mapped.pay_status ?? existing.pay_status,
          recurrence: mapped.recurrence ?? existing.recurrence,
          time_recurrence: mapped.time_recurrence ?? existing.time_recurrence,
          icon: mapped.icon ?? existing.icon,
          color: mapped.color ?? existing.color,
          note: mapped.note !== undefined ? mapped.note : existing.note,
          delete_at: mapped.delete_at !== undefined ? mapped.delete_at : existing.delete_at,
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    return null;
  },

  async getBillsByAccount(idaccount, since) {
    return prisma.bill.findMany({
      where: {
        idaccount,
        update_at: since ? { gt: new Date(since) } : undefined,
      },
      orderBy: { update_at: 'asc' },
    });
  },

  // ── Goal ────────────────────────────────────────────────

  async upsertGoal(data) {
    const mapped = mapEntityFields('goal', data);
    const existing = await prisma.goal.findUnique({ where: { idgoal: mapped.idgoal } });
    if (!existing) {
      return prisma.goal.create({
        data: {
          idgoal: mapped.idgoal,
          idaccount: mapped.idaccount,
          idwallet: mapped.idwallet || null,
          name: mapped.name || 'Mục tiêu',
          target_amount: mapped.target_amount ?? 0,
          current_amount: mapped.current_amount ?? 0,
          target_date: mapped.target_date || new Date(),
          status_complete: mapped.status_complete ?? false,
          icon: mapped.icon || 'flag',
          color: mapped.color || '#4CAF50',
          note: mapped.note || null,
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    if (new Date(mapped.update_at) > new Date(existing.update_at)) {
      return prisma.goal.update({
        where: { idgoal: existing.idgoal },
        data: {
          idwallet: mapped.idwallet !== undefined ? mapped.idwallet : existing.idwallet,
          name: mapped.name ?? existing.name,
          target_amount: mapped.target_amount ?? existing.target_amount,
          current_amount: mapped.current_amount ?? existing.current_amount,
          target_date: mapped.target_date ?? existing.target_date,
          status_complete: mapped.status_complete ?? existing.status_complete,
          icon: mapped.icon ?? existing.icon,
          color: mapped.color ?? existing.color,
          note: mapped.note !== undefined ? mapped.note : existing.note,
          delete_at: mapped.delete_at !== undefined ? mapped.delete_at : existing.delete_at,
          update_at: mapped.update_at || new Date(),
        },
      });
    }
    return null;
  },

  async getGoalsByAccount(idaccount, since) {
    return prisma.goal.findMany({
      where: {
        idaccount,
        update_at: since ? { gt: new Date(since) } : undefined,
      },
      orderBy: { update_at: 'asc' },
    });
  },

  // ── Lookup by ID (for conflict resolution) ──────────────

  async getWalletById(id) {
    return prisma.wallet.findUnique({ where: { idwallet: id } });
  },

  async getTransactionById(id) {
    return prisma.transaction.findUnique({ where: { idtran: id } });
  },

  async getBudgetById(id) {
    return prisma.budget.findUnique({ where: { idbudget: id } });
  },

  async getBillById(id) {
    return prisma.bill.findUnique({ where: { idbill: id } });
  },

  async getGoalById(id) {
    return prisma.goal.findUnique({ where: { idgoal: id } });
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
          { create_by: idaccount },
        ],
      },
    });
  },

  // ── Soft delete utility ─────────────────────────────────
  // CSDL mới: xóa mềm qua Delete_at (category default không xóa được)

  async softDelete(entity, id) {
    if (entity === 'category') {
      const cat = await prisma.category.findUnique({ where: { idcategory: id } });
      if (!cat) return null;
      if (cat.is_default) throw new Error('Cannot delete system default category');
      // Xóa mềm group: gỡ con về chưa nhóm, rồi đánh dấu group xóa
      if (cat.is_group) {
        await prisma.category.updateMany({
          where: { idgroup: id },
          data: { idgroup: null, update_at: new Date() },
        });
      }
      await prisma.category.update({
        where: { idcategory: id },
        data: { delete_at: new Date(), update_at: new Date() },
      });
      return { id, deleted: true };
    }

    const models = {
      wallet: { model: prisma.wallet, pk: 'idwallet' },
      transaction: { model: prisma.transaction, pk: 'idtran' },
      budget: { model: prisma.budget, pk: 'idbudget' },
      bill: { model: prisma.bill, pk: 'idbill' },
      goal: { model: prisma.goal, pk: 'idgoal' },
    };
    const def = models[entity];
    if (!def) throw new Error(`Entity không hợp lệ: ${entity}`);

    const existing = await def.model.findUnique({ where: { [def.pk]: id } });
    if (!existing) return null;

    return def.model.update({
      where: { [def.pk]: id },
      data: { delete_at: new Date(), update_at: new Date() },
    });
  },
};

module.exports = syncRepository;
