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

const syncService = {
  /**
   * POST /api/sync/push — Xử lý batch operations từ client
   */
  async processPush(idaccount, operations) {
    const results = [];
    let synced = 0;
    let conflicts = 0;
    let errors = 0;

    for (const op of operations) {
      try {
        const { localId, entity, operation, payload } = op;

        // Ownership check
        if (payload.idaccount !== idaccount) {
          results.push({
            localId,
            status: 'error',
            message: 'Ownership mismatch: payload.idaccount does not match token',
          });
          errors++;
          continue;
        }

        // Handle delete
        if (operation === 'delete') {
          const deleted = await syncRepository.softDelete(entity, payload.id);
          results.push({
            localId,
            status: deleted ? 'synced' : 'error',
            message: deleted ? undefined : 'Record not found',
          });
          if (deleted) synced++; else errors++;
          continue;
        }

        // Handle create/update (upsert with LWW)
        const upsertFn = syncRepository[UPSERT_MAP[entity]];
        if (!upsertFn) {
          results.push({ localId, status: 'error', message: `Unknown entity: ${entity}` });
          errors++;
          continue;
        }

        const result = await upsertFn(payload);

        if (result === null) {
          // Conflict — server version mới hơn
          const serverRecord = await syncRepository[`get${entity.charAt(0).toUpperCase() + entity.slice(1)}ById`]?.(payload.id);
          results.push({
            localId,
            status: 'conflict',
            message: 'Server version is newer',
            serverRecord: serverRecord || null,
          });
          conflicts++;
        } else {
          results.push({ localId, status: 'synced' });
          synced++;
        }
      } catch (err) {
        logger.error('Sync push operation failed', { localId: op.localId, error: err.message });
        results.push({
          localId: op.localId,
          status: 'error',
          message: err.message,
        });
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

      // Track max updated_at per entity for client checkpoint
      if (records.length > 0) {
        maxSince[entity] = records[records.length - 1].updated_at;
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
};

module.exports = syncService;
