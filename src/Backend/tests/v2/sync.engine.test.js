/**
 * Test Suite v2: Offline-First Synchronization Engine
 * Module: src/Backend/modules/sync
 * 
 * Kiểm thử toàn diện:
 * 1. Batch-level & Operation-level Validation
 * 2. Foreign Key Dependency Ordering (Bẫy thứ tự khóa ngoại trong lô)
 * 3. Last-Write-Wins (LWW) Conflict Resolution
 * 4. Delta Pull Sync & Default Categories
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { validateBatch, validateOperation } = require('../../modules/sync/sync.validation');
const syncService = require('../../modules/sync/sync.service');

describe('Sync Engine v2 — Validation, Dependency Ordering & Conflict Resolution', () => {
  const validUUID1 = 'a0000000-0000-0000-0000-000000000001';
  const validUUID2 = 'b0000000-0000-0000-0000-000000000002';
  const validUUID3 = 'c0000000-0000-0000-0000-000000000003';
  const validUUID4 = 'd0000000-0000-0000-0000-000000000004';
  const validISO = new Date().toISOString();

  // ─── 1. BATCH-LEVEL VALIDATION ───────────────────────────────────────────
  describe('1. Batch-Level Validation (validateBatch)', () => {
    it('1.1. Chấp nhận Batch hợp lệ đầy đủ clientId, pushedAt, operations', () => {
      const batch = {
        clientId: 'client-device-xyz',
        pushedAt: validISO,
        operations: [
          { localId: 'op-1', entity: 'wallet', operation: 'create', payload: { idwallet: validUUID1 } },
        ],
      };
      const res = validateBatch(batch);
      assert.strictEqual(res.valid, true);
      assert.strictEqual(res.errors.length, 0);
    });

    it('1.2. Từ chối batch thiếu clientId hoặc pushedAt không đúng chuẩn ISO', () => {
      const invalidBatch = {
        clientId: '',
        pushedAt: 'not-an-iso-date',
        operations: [{ localId: 'op-1' }],
      };
      const res = validateBatch(invalidBatch);
      assert.strictEqual(res.valid, false);
      assert.ok(res.errors.some(e => e.includes('clientId is required')));
      assert.ok(res.errors.some(e => e.includes('pushedAt must be a valid ISO')));
    });

    it('1.3. Từ chối batch rỗng hoặc vượt quá hạn mức 1000 operations', () => {
      const emptyBatch = { clientId: 'c1', pushedAt: validISO, operations: [] };
      assert.strictEqual(validateBatch(emptyBatch).valid, false);

      const hugeBatch = {
        clientId: 'c1',
        pushedAt: validISO,
        operations: new Array(1001).fill({ localId: 'op-x' }),
      };
      const hugeRes = validateBatch(hugeBatch);
      assert.strictEqual(hugeRes.valid, false);
      assert.ok(hugeRes.errors.some(e => e.includes('operations limit exceeded')));
    });
  });

  // ─── 2. OPERATION-LEVEL VALIDATION ───────────────────────────────────────
  describe('2. Operation-Level Validation (validateOperation)', () => {
    it('2.1. Xác thực hợp lệ cho cả 6 entities: wallet, transaction, budget, bill, goal, category', () => {
      const entities = ['wallet', 'transaction', 'budget', 'bill', 'goal', 'category'];
      const pkMap = {
        wallet: 'idwallet',
        transaction: 'idtran',
        budget: 'idbudget',
        bill: 'idbill',
        goal: 'idgoal',
        category: 'idcategory',
      };

      for (const entity of entities) {
        const op = {
          localId: `loc-${entity}`,
          entity,
          operation: 'create',
          payload: {
            [pkMap[entity]]: validUUID1,
            updatedAt: validISO,
          },
        };
        const res = validateOperation(op);
        assert.strictEqual(res.valid, true, `Entity ${entity} must be valid`);
      }
    });

    it('2.2. Bắt lỗi khi entity hoặc operation không nằm trong danh mục hỗ trợ', () => {
      const invalidOp = {
        localId: 'loc-err',
        entity: 'unknown_crypto_asset',
        operation: 'hack',
        payload: { id: validUUID1 },
      };
      const res = validateOperation(invalidOp);
      assert.strictEqual(res.valid, false);
      assert.ok(res.errors.some(e => e.includes('entity must be one of')));
      assert.ok(res.errors.some(e => e.includes('operation must be one of')));
    });

    it('2.3. Bắt lỗi khi Primary Key không đúng định dạng UUID v4 chuẩn', () => {
      const nonUuidOp = {
        localId: 'loc-wallet-non-uuid',
        entity: 'wallet',
        operation: 'create',
        payload: { idwallet: '123-not-a-uuid', updatedAt: validISO },
      };
      const res = validateOperation(nonUuidOp);
      assert.strictEqual(res.valid, false);
      assert.ok(res.errors.some(e => e.includes('valid UUID')));
    });
  });

  // ─── 3. FOREIGN KEY DEPENDENCY ORDERING ─────────────────────────────────
  describe('3. Foreign Key Dependency Ordering (Bẫy thứ tự khóa ngoại)', () => {
    it('3.1. Create/Update: Category (10) -> Wallet (20) -> Budget (30) -> Transaction (40)', async () => {
      const processedExecutionOrder = [];

      // Mock repository để theo dõi thứ tự xử lý thực tế
      const syncRepo = require('../../modules/sync/sync.repository');
      const origUpsertCategory = syncRepo.upsertCategory;
      const origUpsertWallet = syncRepo.upsertWallet;
      const origUpsertBudget = syncRepo.upsertBudget;
      const origUpsertTransaction = syncRepo.upsertTransaction;

      syncRepo.upsertCategory = async () => { processedExecutionOrder.push('category'); return { status: 'synced' }; };
      syncRepo.upsertWallet = async () => { processedExecutionOrder.push('wallet'); return { status: 'synced' }; };
      syncRepo.upsertBudget = async () => { processedExecutionOrder.push('budget'); return { status: 'synced' }; };
      syncRepo.upsertTransaction = async () => { processedExecutionOrder.push('transaction'); return { status: 'synced' }; };

      try {
        // Gửi lô với thứ tự xáo trộn: Transaction gửi đầu tiên, Category gửi cuối cùng
        const mixedOperations = [
          { localId: 'op-tx', entity: 'transaction', operation: 'create', payload: { idtran: validUUID1, updatedAt: validISO } },
          { localId: 'op-bg', entity: 'budget', operation: 'create', payload: { idbudget: validUUID2, updatedAt: validISO } },
          { localId: 'op-wl', entity: 'wallet', operation: 'create', payload: { idwallet: validUUID3, updatedAt: validISO } },
          { localId: 'op-cat', entity: 'category', operation: 'create', payload: { idcategory: validUUID4, updatedAt: validISO } },
        ];

        const { results, summary } = await syncService.processPush(1, mixedOperations);

        assert.strictEqual(summary.synced, 4);
        assert.deepStrictEqual(
          processedExecutionOrder,
          ['category', 'wallet', 'budget', 'transaction'],
          'Thứ tự thực thi bắt buộc phải là Category -> Wallet -> Budget -> Transaction để tránh Foreign Key Violation'
        );
      } finally {
        syncRepo.upsertCategory = origUpsertCategory;
        syncRepo.upsertWallet = origUpsertWallet;
        syncRepo.upsertBudget = origUpsertBudget;
        syncRepo.upsertTransaction = origUpsertTransaction;
      }
    });

    it('3.2. Delete: Transaction (60) xóa trước -> Budget (70) -> Wallet (80) -> Category (90)', async () => {
      const deleteExecutionOrder = [];
      const syncRepo = require('../../modules/sync/sync.repository');
      const origSoftDelete = syncRepo.softDelete;

      syncRepo.softDelete = async (entity) => {
        deleteExecutionOrder.push(entity);
        return true;
      };

      try {
        // Khi xóa: Category gửi trước nhưng phải bị đẩy lùi về sau cùng
        const mixedDeleteOps = [
          { localId: 'del-cat', entity: 'category', operation: 'delete', payload: { idcategory: validUUID1, updatedAt: validISO } },
          { localId: 'del-wl', entity: 'wallet', operation: 'delete', payload: { idwallet: validUUID2, updatedAt: validISO } },
          { localId: 'del-tx', entity: 'transaction', operation: 'delete', payload: { idtran: validUUID3, updatedAt: validISO } },
        ];

        await syncService.processPush(1, mixedDeleteOps);

        assert.deepStrictEqual(
          deleteExecutionOrder,
          ['transaction', 'wallet', 'category'],
          'Thao tác Delete bắt buộc phải xóa Transaction trước khi xóa Wallet và Category cha'
        );
      } finally {
        syncRepo.softDelete = origSoftDelete;
      }
    });
  });

  // ─── 4. LAST-WRITE-WINS (LWW) CONFLICT RESOLUTION ────────────────────────
  describe('4. Last-Write-Wins (LWW) Conflict Resolution', () => {
    it('4.1. Trả về status "conflict" kèm dữ liệu server khi client gửi updatedAt cũ hơn', async () => {
      const syncRepo = require('../../modules/sync/sync.repository');
      const origUpsertWallet = syncRepo.upsertWallet;
      const origGetWalletById = syncRepo.getWalletById;

      // Mock repository: upsert trả về null để báo conflict, getById trả về bản ghi server hiện hành
      syncRepo.upsertWallet = async () => null;
      syncRepo.getWalletById = async () => ({
        idwallet: validUUID1,
        name: 'Ví Tiền Mặt Server',
        balance: 5000000,
        update_at: new Date('2026-05-01T00:00:00Z'),
      });

      try {
        const clientOldOp = [
          { localId: 'op-conflict-1', entity: 'wallet', operation: 'update', payload: { idwallet: validUUID1, name: 'Ví Cũ Client', updatedAt: '2026-01-01T00:00:00.000Z' } },
        ];

        const { results, summary } = await syncService.processPush(1, clientOldOp);
        assert.strictEqual(summary.conflicts, 1);
        assert.strictEqual(results[0].status, 'conflict');
        assert.strictEqual(results[0].serverRecord.name, 'Ví Tiền Mặt Server');
      } finally {
        syncRepo.upsertWallet = origUpsertWallet;
        syncRepo.getWalletById = origGetWalletById;
      }
    });
  });

  // ─── 5. SERVER_UPDATE_AT DELTA PULL (MỤC 37 FIX) ────────────────────────
  describe('5. Delta Pull Sync với Server_update_at (Khắc phục bỏ sót bản ghi đẩy muộn)', () => {
    it('5.1. processPull tính maxSince dựa trên server_update_at lớn nhất của batch', async () => {
      const syncRepo = require('../../modules/sync/sync.repository');
      const origGetWallets = syncRepo.getWalletsByAccount;

      const serverTime1 = new Date('2026-10-05T07:45:00.000Z');
      const serverTime2 = new Date('2026-10-05T07:45:32.000Z');

      syncRepo.getWalletsByAccount = async (idaccount, since) => [
        { idwallet: validUUID1, name: 'Ví 1', update_at: new Date('2026-10-05T07:43:00.000Z'), server_update_at: serverTime1 },
        { idwallet: validUUID2, name: 'Ví 2', update_at: new Date('2026-10-05T07:43:30.000Z'), server_update_at: serverTime2 },
      ];

      try {
        const pullRes = await syncService.processPull(1, '2026-10-05T07:44:00.000Z', ['wallet']);
        assert.strictEqual(pullRes.data.wallets.length, 2);
        assert.strictEqual(pullRes.maxSince.wallet, serverTime2);
      } finally {
        syncRepo.getWalletsByAccount = origGetWallets;
      }
    });

    it('5.2. getWalletsByAccount lọc theo server_update_at thay vì update_at', async () => {
      const { prisma } = require('../../config/db');
      let capturedQuery = null;
      const origFindMany = prisma.wallet.findMany;
      prisma.wallet.findMany = async (args) => {
        capturedQuery = args;
        return [];
      };

      try {
        const syncRepo = require('../../modules/sync/sync.repository');
        await syncRepo.getWalletsByAccount(10, '2026-10-05T07:44:27.000Z');
        assert.ok(capturedQuery.where.server_update_at, 'Query phải lọc theo server_update_at');
        assert.strictEqual(capturedQuery.where.update_at, undefined, 'Query không được lọc theo update_at');
        assert.deepStrictEqual(capturedQuery.orderBy, { server_update_at: 'asc' });
      } finally {
        prisma.wallet.findMany = origFindMany;
      }
    });

    it('5.3. Đảm bảo mọi bản ghi đồng bộ gán server_update_at chuẩn thời gian UTC', async () => {
      const syncRepo = require('../../modules/sync/sync.repository');
      const { prisma } = require('../../config/db');
      let capturedCreate = null;
      const origCreate = prisma.wallet.create;
      prisma.wallet.create = async (args) => {
        capturedCreate = args;
        return { ...args.data, idwallet: validUUID1 };
      };

      try {
        const before = new Date();
        await syncRepo.upsertWallet({
          idwallet: validUUID1,
          idaccount: 1,
          name: 'Ví UTC Test',
          balance: 100000,
          updatedAt: '2026-10-07T12:00:00.000Z',
        });
        const after = new Date();

        assert.ok(capturedCreate, 'Phải thực hiện prisma.wallet.create');
        assert.ok(capturedCreate.data.server_update_at instanceof Date, 'server_update_at phải là Date object');
        const diffMs = Math.abs(capturedCreate.data.server_update_at.getTime() - before.getTime());
        assert.ok(diffMs < 5000, 'server_update_at phải là giờ hiện tại chuẩn UTC, không bị cộng dồn múi giờ');
      } finally {
        prisma.wallet.create = origCreate;
      }
    });
  });
});
