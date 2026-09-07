const syncRepository = require('./sync.repository');
const { VALID_ENTITIES } = require('./sync.validation');
const eventBus = require('../../core/event-bus');
const logger = require('../../core/logger');

// Map entity → repository upsert method
const UPSERT_MAP = {
  wallet: 'upsertWallet',
  transaction: 'upsertTransaction',
  budget: 'upsertBudget',
  bill: 'upsertBill',
  goal: 'upsertGoal',
  category: 'upsertCategory',
};

// Map entity → repository pull method
const PULL_MAP = {
  wallet: 'getWalletsByAccount',
  transaction: 'getTransactionsByAccount',
  budget: 'getBudgetsByAccount',
  bill: 'getBillsByAccount',
  goal: 'getGoalsByAccount',
  category: 'getCategoriesByAccount',
};

// Plural key names for response
const ENTITY_KEYS = {
  wallet: 'wallets',
  transaction: 'transactions',
  budget: 'budgets',
  bill: 'bills',
  goal: 'goals',
  category: 'categories',
};

const ENTITY_PK_MAP = {
  wallet: 'idwallet',
  transaction: 'idtran',
  budget: 'idbudget',
  bill: 'idbill',
  goal: 'idgoal',
  category: 'idcategory',
};

// Dependency order to avoid Foreign Key violations:
// Create/Update: category (10) -> wallet (20) -> budget/bill/goal (30) -> transaction (40)
// Delete: transaction (60) -> budget/bill/goal (70) -> wallet (80) -> category (90)
const ENTITY_PRIORITY = {
  category: 10,
  wallet: 20,
  budget: 30,
  bill: 30,
  goal: 30,
  transaction: 40,
};

function getOperationWeight(op) {
  const entityWeight = ENTITY_PRIORITY[op.entity] || 50;
  if (op.operation === 'delete') {
    return 100 - entityWeight;
  }
  return entityWeight;
}

const syncService = {
  /**
   * POST /api/sync/push — Xử lý batch operations từ client
   */
  async processPush(idaccount, operations) {
    const results = new Array(operations.length);
    let synced = 0;
    let conflicts = 0;
    let errors = 0;

    // Sắp xếp operations theo thứ tự phụ thuộc (FK dependency)
    const indexedOps = operations.map((op, idx) => ({ op, idx }));
    indexedOps.sort((a, b) => getOperationWeight(a.op) - getOperationWeight(b.op));

    for (const { op, idx } of indexedOps) {
      try {
        const { localId, entity, operation, payload } = op;

        // Ownership check (type-safe comparison)
        if (payload.idaccount !== undefined && payload.idaccount !== null && Number(payload.idaccount) !== Number(idaccount)) {
          results[idx] = {
            localId,
            status: 'error',
            message: 'Ownership mismatch: payload.idaccount does not match token',
          };
          errors++;
          continue;
        }

        // Normalize payload fields
        payload.idaccount = Number(payload.idaccount ?? idaccount);
        if (!payload.id) {
          const pkField = ENTITY_PK_MAP[entity];
          if (pkField && payload[pkField]) {
            payload.id = payload[pkField];
          }
        }

        // Canonical classify alignment for category: normalize all debt variants to 'Vay/no'
        if (entity === 'category' && payload.classify) {
          const c = String(payload.classify).trim();
          if (['Vay/nợ', 'Vay', 'no', 'vay_no', 'vay_nợ', 'Vay/ng'].includes(c)) {
            payload.classify = 'Vay/no';
          }
        }

        // Handle delete — idempotent: không tìm thấy nghĩa là ĐÃ ở trạng thái mong muốn
        if (operation === 'delete') {
          const deleted = await syncRepository.softDelete(entity, payload.id);
          results[idx] = {
            localId,
            status: 'synced',
            message: deleted ? undefined : 'Already absent',
          };
          synced++;
          continue;
        }

        // Handle create/update (upsert with LWW)
        const upsertFn = syncRepository[UPSERT_MAP[entity]];
        if (!upsertFn) {
          results[idx] = { localId, status: 'error', code: 'UNKNOWN_ENTITY', message: `Unknown entity: ${entity}` };
          errors++;
          continue;
        }

        const result = await upsertFn(payload);

        if (result === null) {
          // Conflict — server version mới hơn
          const serverRecord = await syncRepository[`get${entity.charAt(0).toUpperCase() + entity.slice(1)}ById`]?.(payload.id);
          results[idx] = {
            localId,
            status: 'conflict',
            message: 'Server version is newer',
            serverRecord: serverRecord || null,
          };
          conflicts++;
        } else {
          results[idx] = { localId, status: 'synced' };
          synced++;
        }
      } catch (err) {
        logger.error('Sync push operation failed', { localId: op.localId, error: err.message });
        
        const rawMsg = String(err?.message || '');
        const prismaCode = err?.code ?? null;
        const sqlState = rawMsg.match(/code:\s*"(\d{5})"/)?.[1] ?? null;
        const constraintMatch = rawMsg.match(/constraint\s*\\?"([\w.]+)\\?"/i)?.[1] ?? null;

        let code = 'DB_ERROR';
        let friendlyMessage = 'Dữ liệu không hợp lệ hoặc vi phạm ràng buộc cơ sở dữ liệu';

        if (/fk_\w+_account/i.test(rawMsg) || /Foreign key.*account/i.test(rawMsg)) {
          code = 'ACCOUNT_NOT_FOUND';
          friendlyMessage = 'Tài khoản không tồn tại trong hệ thống';
        } else if (sqlState === '23505' || prismaCode === 'P2002') {
          code = 'UNIQUE_VIOLATION';
          if (/uq_category|category.*name/i.test(rawMsg) || /category/i.test(constraintMatch || '')) {
            code = 'CATEGORY_NAME_DUPLICATE';
            friendlyMessage = 'Tên danh mục đã tồn tại trong tài khoản này';
          } else {
            friendlyMessage = 'Dữ liệu bị trùng lặp khóa duy nhất';
          }
        } else if (sqlState === '23503' || prismaCode === 'P2003') {
          code = 'FOREIGN_KEY_VIOLATION';
          friendlyMessage = 'Tham chiếu dữ liệu không tồn tại (vi phạm khóa ngoại)';
        } else if (sqlState === '23514') {
          code = 'CONSTRAINT_VIOLATION';
          friendlyMessage = 'Dữ liệu vi phạm ràng buộc kiểm tra của cơ sở dữ liệu';
        } else if (/cannot delete system default category/i.test(rawMsg)) {
          code = 'FORBIDDEN_SYSTEM_DEFAULT';
          friendlyMessage = 'Không thể xóa danh mục mặc định của hệ thống';
        }

        results[idx] = {
          localId: op.localId,
          status: 'error',
          code,
          constraint: constraintMatch || undefined,
          message: friendlyMessage,
        };
        errors++;
      }
    }

    // Emit sync event
    const summary = { total: operations.length, synced, conflicts, errors };
    try {
      await eventBus.publish('sync.completed', { idaccount, summary, timestamp: new Date().toISOString() });
    } catch {
      // Event bus failure không ảnh hưởng response
    }

    return { results, summary };
  },

  /**
   * GET /api/sync/pull — Trả data mới cho client
   */
  async processPull(idaccount, since, entities) {
    const targetEntities = entities && entities.length > 0
      ? entities.filter(e => VALID_ENTITIES.includes(e))
      : VALID_ENTITIES;

    const data = {};
    let totalRecords = 0;
    const maxSince = {};

    for (const entity of targetEntities) {
      const pullFn = syncRepository[PULL_MAP[entity]];
      if (!pullFn) continue;

      const records = await pullFn(idaccount, since);
      const key = ENTITY_KEYS[entity];
      data[key] = records;
      totalRecords += records.length;

      // Track max update_at per entity for client checkpoint (CSDL mới: update_at)
      if (records.length > 0) {
        maxSince[entity] = records[records.length - 1].update_at;
      }
    }

    return {
      pulledAt: new Date().toISOString(),
      hasMore: totalRecords >= 500, // heuristic: nếu đủ 500 record, có thể còn nữa
      maxSince,
      data,
    };
  },

  /**
   * GET /api/sync/status — Trạng thái sync
   */
  async getStatus(idaccount) {
    const status = {};

    for (const entity of VALID_ENTITIES) {
      const pullFn = syncRepository[PULL_MAP[entity]];
      if (!pullFn) continue;

      // Count total records (không filter since)
      const count = await syncRepository[`count${entity.charAt(0).toUpperCase() + entity.slice(1)}`]?.(idaccount);
      const key = ENTITY_KEYS[entity];
      status[key] = { count: count ?? 0 };
    }

    return {
      idaccount,
      lastSyncAt: new Date().toISOString(),
      entities: status,
    };
  },

  /**
   * GET /api/sync/default-categories — Lấy danh sách danh mục template hệ thống
   */
  async getDefaultCategories() {
    const { prisma } = require('../../config/db');
    const categories = await prisma.category.findMany({
      where: {
        is_default: true,
        delete_at: null,
      },
      select: {
        idcategory: true,
        name_category: true,
        classify: true,
        is_default: true,
        is_group: true,
        idgroup: true,
        keyword: true,
        icon: true,
        create_at: true,
        update_at: true,
      },
      orderBy: { create_at: 'asc' },
    });
    return categories.map((c) => ({
      id: c.idcategory,
      name: c.name_category,
      classify: c.classify,
      is_default: c.is_default,
      is_group: c.is_group,
      idgroup: c.idgroup,
      keyword: c.keyword,
      icon: c.icon,
      created_at: c.create_at,
      updated_at: c.update_at,
    }));
  },
};

module.exports = syncService;

