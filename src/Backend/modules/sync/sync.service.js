const syncRepository = require('./sync.repository');
const { VALID_ENTITIES, validateOperation } = require('./sync.validation');
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
// Create/Update: category (10) -> wallet (20) -> goal (30) -> bill (31) -> budget (32) -> transaction (40)
// Delete: transaction (60) -> budget (68) -> bill (69) -> goal (70) -> wallet (80) -> category (90)
const ENTITY_PRIORITY = {
  category: 10,
  wallet: 20,
  goal: 30,
  bill: 31,
  budget: 32,
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
   * Kiểm tra quyền thao tác thực thể gia đình (Ma trận Vai trò x Thực thể)
   */
  enforceHouseholdPermission({ entity, operation, idaccount, existingCreatorId, idhousehold, householdStatus, userRole }) {
    if (householdStatus === 'ReadOnly' || householdStatus === 'Inactive') {
      throw Object.assign(new Error('Nhà đang ở trạng thái ReadOnly, không thể ghi dữ liệu'), {
        code: 'HOUSEHOLD_READ_ONLY',
      });
    }

    if (userRole === 'Member') {
      if (['wallet', 'budget', 'category'].includes(entity) && ['create', 'update', 'delete'].includes(operation)) {
        throw Object.assign(new Error(`Thành viên không có quyền ${operation} ${entity} chung của nhà`), {
          code: 'HOUSEHOLD_ROLE_FORBIDDEN',
        });
      }

      if (entity === 'transaction') {
        if (operation === 'update' || operation === 'delete') {
          if (existingCreatorId !== undefined && existingCreatorId !== null && Number(existingCreatorId) !== Number(idaccount)) {
            throw Object.assign(new Error('Thành viên chỉ được sửa/xóa giao dịch do chính mình ghi'), {
              code: 'HOUSEHOLD_ROLE_FORBIDDEN',
            });
          }
        }
      }
    }

    return true;
  },

  /**
   * Kiểm tra phạm vi dữ liệu (Tránh giao dịch riêng trỏ vào ví chung hoặc ngược lại)
   */
  async validateEntityScope(payload) {
    if (payload.idwallet) {
      const { prisma } = require('../../config/db');
      const wallet = await prisma.wallet.findUnique({ where: { idwallet: payload.idwallet } });
      if (wallet) {
        const walletHh = wallet.idhousehold ?? wallet.Idhousehold ?? null;
        const payloadHh = payload.idhousehold ?? payload.Idhousehold ?? null;
        if (Number(walletHh || 0) !== Number(payloadHh || 0)) {
          throw Object.assign(new Error('Phạm vi không khớp: giao dịch và ví phải cùng thuộc cá nhân hoặc cùng thuộc một nhà'), {
            code: 'HOUSEHOLD_SCOPE_MISMATCH',
          });
        }
      }
    }
    return true;
  },

  /**
   * POST /api/sync/push — Xử lý batch operations từ client
   */
  async processPush(idaccount, operations) {
    const results = new Array(operations.length);
    let synced = 0;
    let conflicts = 0;
    let errors = 0;

    // Thu thập các giao dịch đang bị xoá trong cùng lô để không tự chặn chốt trả hai lần (Bẫy thứ tự trong lô)
    const dangXoaTrongLo = new Set(
      operations
        .filter((o) => o?.entity === 'transaction' && o?.operation === 'delete')
        .map((o) => o.payload?.id || o.payload?.idtran)
        .filter(Boolean),
    );

    // Sắp xếp operations theo thứ tự phụ thuộc (FK dependency)
    const indexedOps = operations.map((op, idx) => ({ op, idx }));
    indexedOps.sort((a, b) => getOperationWeight(a.op) - getOperationWeight(b.op));

    for (const { op, idx } of indexedOps) {
      try {
        const { localId, entity, operation, payload } = op;

        // 1. Kiểm tra tính hợp lệ của từng thao tác (Operation-level validation)
        const opValidation = validateOperation(op);
        if (!opValidation.valid) {
          results[idx] = {
            localId: op.localId || 'unknown',
            status: 'error',
            code: 'CONSTRAINT_VIOLATION',
            message: opValidation.errors.join('; '),
          };
          errors++;
          continue;
        }

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

        // 2. Kiểm tra Scope & Quyền gia đình nếu có
        await syncService.validateEntityScope(payload);

        let targetHhId = payload.idhousehold ?? payload.idHousehold ?? null;
        let existingRecord = null;
        if (payload.id) {
          existingRecord = await syncRepository[`get${entity.charAt(0).toUpperCase() + entity.slice(1)}ById`]?.(payload.id);
          if (!targetHhId && existingRecord) {
            targetHhId = existingRecord.idhousehold ?? existingRecord.Idhousehold ?? null;
          }
        }

        if (targetHhId) {
          let userRole = null;
          let householdStatus = 'Active';
          try {
            const householdRepository = require('../household/household.repository');
            const membership = await householdRepository.findMember(targetHhId, idaccount);
            const house = membership?.household || await householdRepository.findHouseholdById(targetHhId);
            userRole = membership?.role || null;
            householdStatus = house?.status || 'Active';
          } catch {
            // Fallback
          }

          const existingCreatorId = existingRecord ? (existingRecord.idaccount ?? existingRecord.create_by ?? null) : null;

          syncService.enforceHouseholdPermission({
            entity,
            operation,
            idaccount,
            existingCreatorId,
            idhousehold: targetHhId,
            householdStatus,
            userRole,
          });
        }

        // Handle delete — idempotent: không tìm thấy nghĩa là ĐÃ ở trạng thái mong muốn
        if (operation === 'delete') {
          const deleted = await syncRepository.softDelete(entity, payload.id, idaccount);
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

        const result = entity === 'transaction'
          ? await syncRepository.upsertTransaction(payload, dangXoaTrongLo, idaccount)
          : await upsertFn(payload, idaccount);

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

        if (err.code === 'NOT_OWNER') {
          code = 'NOT_OWNER';
          friendlyMessage = err.message || 'Bản ghi không thuộc quyền sở hữu của bạn';
        } else if (err.code === 'HOUSEHOLD_ROLE_FORBIDDEN') {
          code = 'HOUSEHOLD_ROLE_FORBIDDEN';
          friendlyMessage = err.message || 'Bạn không có quyền thực hiện thao tác này trong gia đình';
        } else if (err.code === 'HOUSEHOLD_READ_ONLY') {
          code = 'HOUSEHOLD_READ_ONLY';
          friendlyMessage = err.message || 'Gia đình đang ở trạng thái ReadOnly, không thể ghi dữ liệu';
        } else if (err.code === 'HOUSEHOLD_SCOPE_MISMATCH') {
          code = 'HOUSEHOLD_SCOPE_MISMATCH';
          friendlyMessage = err.message || 'Phạm vi dữ liệu cá nhân và gia đình không khớp';
        } else if (err.code === 'BILL_PERIOD_ALREADY_PAID' || /BILL_PERIOD_ALREADY_PAID/i.test(rawMsg)) {
          code = 'BILL_PERIOD_ALREADY_PAID';
          friendlyMessage = err.message || 'Kỳ hoá đơn này đã được thanh toán ở một kỳ trùng';
        } else if (err.code === 'BILL_ALREADY_PAID' || /BILL_ALREADY_PAID/i.test(rawMsg)) {
          code = 'BILL_ALREADY_PAID';
          friendlyMessage = err.message || 'Hóa đơn đã được thanh toán, không thể thay đổi trạng thái';
        } else if (/fk_\w+_account/i.test(rawMsg) || /Foreign key.*account/i.test(rawMsg)) {
          code = 'ACCOUNT_NOT_FOUND';
          friendlyMessage = 'Tài khoản không tồn tại trong hệ thống';
        } else if (sqlState === '23505' || prismaCode === 'P2002') {
          code = 'UNIQUE_VIOLATION';
          const isWallet = op.entity === 'wallet' || err?.meta?.modelName === 'wallet';
          if (/uq_category|category.*name/i.test(rawMsg) || /category/i.test(constraintMatch || '')) {
            code = 'CATEGORY_NAME_DUPLICATE';
            friendlyMessage = 'Tên danh mục đã tồn tại trong tài khoản này';
          } else if (
            /uq_wallet_name|uq_wallet_account_name|wallet.*name/i.test(rawMsg) ||
            /uq_wallet_name|uq_wallet_account_name/i.test(constraintMatch || '') ||
            (isWallet && (err?.meta?.target?.includes('Name') || /name/i.test(rawMsg)))
          ) {
            code = 'WALLET_NAME_DUPLICATE';
            friendlyMessage = 'Tên ví đã tồn tại trong tài khoản này';
          } else if (
            /uq_wallet_default|wallet.*default/i.test(rawMsg) ||
            /uq_wallet_default/i.test(constraintMatch || '') ||
            (isWallet && (err?.meta?.target?.includes('Is_default') || /default/i.test(rawMsg)))
          ) {
            code = 'WALLET_DEFAULT_DUPLICATE';
            friendlyMessage = 'Tài khoản đã có một ví mặc định';
          } else {
            friendlyMessage = 'Dữ liệu bị trùng lặp khóa duy nhất';
          }
        } else if (sqlState === '23503' || prismaCode === 'P2003') {
          code = 'FOREIGN_KEY_VIOLATION';
          friendlyMessage = 'Tham chiếu dữ liệu không tồn tại (vi phạm khóa ngoại)';
        } else if (sqlState === '23514') {
          code = 'CONSTRAINT_VIOLATION';
          friendlyMessage = 'Dữ liệu vi phạm ràng buộc kiểm tra của cơ sở dữ liệu';
        } else if (sqlState === '22001' || prismaCode === 'P2000' || /value too long for type/i.test(rawMsg)) {
          code = 'CONSTRAINT_VIOLATION';
          friendlyMessage = 'Dữ liệu dài hơn độ rộng cho phép của cơ sở dữ liệu';
        } else if (sqlState === '23502' || prismaCode === 'P2011' || prismaCode === 'P2012'
                   || err?.name === 'PrismaClientValidationError') {
          code = 'CONSTRAINT_VIOLATION';
          friendlyMessage = 'Dữ liệu thiếu trường bắt buộc hoặc sai kiểu';
        } else if (/cannot delete system default category/i.test(rawMsg)) {
          code = 'FORBIDDEN_SYSTEM_DEFAULT';
          friendlyMessage = 'Không thể xóa danh mục mặc định của hệ thống';
        }

        results[idx] = {
          localId: op.localId,
          status: 'error',
          code,
          constraint: constraintMatch || err?.meta?.column_name || undefined,
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

    // Phát realtime socket cho các nhà có liên quan
    try {
      const affectedHouseholds = new Set(
        operations
          .map((o) => o?.payload?.idhousehold || o?.payload?.idHousehold)
          .filter(Boolean)
      );
      const { getIO } = require('../../core/socket');
      const io = getIO ? getIO() : null;
      if (io && affectedHouseholds.size > 0) {
        for (const hhId of affectedHouseholds) {
          io.to(`household_${hhId}`).emit('household.changed', {
            idhousehold: Number(hhId),
            eventType: 'SYNC_COMPLETED',
            timestamp: new Date().toISOString(),
          });
        }
      }
    } catch {
      // Socket error ignored
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

    // Tra cứu active household của user (nếu có)
    let activeHouseholdId = null;
    try {
      const householdRepository = require('../household/household.repository');
      const membership = await householdRepository.findActiveMemberByAccount(idaccount);
      if (membership && membership.household && !membership.household.delete_at) {
        activeHouseholdId = membership.idhousehold;
      }
    } catch {
      // Fallback null
    }

    const data = {};
    let totalRecords = 0;
    const maxSince = {};

    for (const entity of targetEntities) {
      const pullFn = syncRepository[PULL_MAP[entity]];
      if (!pullFn) continue;

      const records = await pullFn(idaccount, since, activeHouseholdId);
      const key = ENTITY_KEYS[entity];
      data[key] = records;
      totalRecords += records.length;

      // Track max server_update_at per entity for client checkpoint (ưu tiên server_update_at, fallback update_at)
      if (records.length > 0) {
        const lastRecord = records[records.length - 1];
        maxSince[entity] = lastRecord.server_update_at || lastRecord.update_at;
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

