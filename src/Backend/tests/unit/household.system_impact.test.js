const test = require('node:test');
const assert = require('node:assert/strict');

test('Household Module — Tầng 2: System Impact, Security & 17-Case Verification Suite (Rule 11)', async (t) => {
  const syncRepository = require('../../modules/sync/sync.repository');
  const syncService = require('../../modules/sync/sync.service');
  const householdService = require('../../modules/household/household.service');
  const householdRepository = require('../../modules/household/household.repository');
  const { requireFeature } = require('../../middleware/feature-permission.middleware');
  const { prisma } = require('../../config/db');

  // ── [1] Vá an ninh NOT_OWNER trong /sync/push ───────────────
  await t.test('1. [Tier 2] Chặn đứng người dùng sửa ví riêng của người khác (NOT_OWNER)', async () => {
    const origFindUnique = prisma.wallet.findUnique;
    prisma.wallet.findUnique = async () => ({
      idwallet: '11111111-1111-4111-8111-111111111110',
      idaccount: 10,
      idhousehold: null,
      name: 'Ví riêng Tuấn',
      update_at: new Date('2026-10-20T10:00:00Z'),
    });

    try {
      await assert.rejects(
        async () => {
          await syncRepository.upsertWallet({
            idwallet: '11111111-1111-4111-8111-111111111110',
            idaccount: 99,
            name: 'Ví bị hack',
            update_at: new Date('2026-10-25T10:00:00Z'),
          }, 99);
        },
        (err) => {
          assert.strictEqual(err.code, 'NOT_OWNER');
          return true;
        }
      );
    } finally {
      prisma.wallet.findUnique = origFindUnique;
    }
  });

  await t.test('1b. [Tier 2] Chặn đứng người dùng sửa hóa đơn riêng của người khác (NOT_OWNER)', async () => {
    const origFindUnique = prisma.bill.findUnique;
    prisma.bill.findUnique = async () => ({
      idbill: '11111111-1111-4111-8111-111111111119',
      idaccount: 10,
      name: 'Hóa đơn điện Tuấn',
      update_at: new Date('2026-10-20T10:00:00Z'),
    });

    try {
      await assert.rejects(
        async () => {
          await syncRepository.upsertBill({
            idbill: '11111111-1111-4111-8111-111111111119',
            idaccount: 99,
            name: 'Hóa đơn bị hack',
            update_at: new Date('2026-10-25T10:00:00Z'),
          }, 99);
        },
        (err) => {
          assert.strictEqual(err.code, 'NOT_OWNER');
          return true;
        }
      );
    } finally {
      prisma.bill.findUnique = origFindUnique;
    }
  });

  await t.test('2. [Tier 2] Chặn đứng người dùng xóa mềm bản ghi riêng của người khác (NOT_OWNER)', async () => {
    const origFindUnique = prisma.transaction.findUnique;
    prisma.transaction.findUnique = async () => ({
      idtran: '44444444-4444-4444-8444-111111111110',
      idaccount: 10,
      idhousehold: null,
      amount: 50000,
    });

    try {
      await assert.rejects(
        async () => {
          await syncRepository.softDelete('transaction', '44444444-4444-4444-8444-111111111110', 99);
        },
        (err) => {
          assert.strictEqual(err.code, 'NOT_OWNER');
          return true;
        }
      );
    } finally {
      prisma.transaction.findUnique = origFindUnique;
    }
  });

  // ── [2] 17 Ca Kiểm Thử Toàn Diện Qua syncService.processPush (Đơn 56 / 50) ──
  const ID_A = 10;
  const ID_B = 20;
  const ID_C = 30;
  const ID_D = 40;

  const W_ID = '11111111-1111-4111-8111-111111111111';
  const W2_ID = '11111111-1111-4111-8111-222222222222';
  const W_PRIV_ID = '11111111-1111-4111-8111-333333333333';
  const G_ID = '22222222-2222-4222-8222-111111111111';
  const K_ID = '33333333-3333-4333-8333-111111111111';
  const CAT_SYS_ID = '33333333-3333-4333-8333-999999999999';
  const T_B_ID = '44444444-4444-4444-8444-111111111111';
  const T_A_ID = '44444444-4444-4444-8444-222222222222';
  const NEW_T_ID = '44444444-4444-4444-8444-333333333333';
  const NEW_W_ID = '11111111-1111-4111-8111-444444444444';
  const NEW_G_ID = '22222222-2222-4222-8222-444444444444';
  const NEW_B_ID = '55555555-5555-4555-8555-444444444444';

  const origFindMember = householdRepository.findMember;
  const origFindHouseholdAnyStatus = householdRepository.findHouseholdAnyStatus;
  const origFindFormerMember = householdRepository.findFormerMember;
  const origAccountFindUnique = prisma.account.findUnique;
  const origWalletFindUnique = prisma.wallet.findUnique;
  const origGoalFindUnique = prisma.goal.findUnique;
  const origCategoryFindUnique = prisma.category.findUnique;
  const origTransactionFindUnique = prisma.transaction.findUnique;
  const origUpsertWallet = syncRepository.upsertWallet;
  const origUpsertTransaction = syncRepository.upsertTransaction;
  const origUpsertCategory = syncRepository.upsertCategory;
  const origUpsertBudget = syncRepository.upsertBudget;
  const origUpsertGoal = syncRepository.upsertGoal;

  function setup17CasesMock(overrides = {}) {
    householdRepository.findHouseholdAnyStatus = async (idhh) => {
      if (overrides.houseStatus) {
        return { idhousehold: Number(idhh), name: 'Nhà H', owner_idaccount: 10, status: overrides.houseStatus };
      }
      if (Number(idhh) === 1) return { idhousehold: 1, name: 'Nhà H', owner_idaccount: 10, status: 'Active' };
      if (Number(idhh) === 2) return { idhousehold: 2, name: 'Nhà Đã Giải Tán', owner_idaccount: 10, status: 'Dissolved' };
      return null;
    };

    householdRepository.findMember = async (idhh, idacc) => {
      if (overrides.noMember) return null;
      if (Number(idhh) === 1) {
        if (Number(idacc) === 10) return { idhousehold: 1, idaccount: 10, role: 'Owner', left_at: null };
        if (Number(idacc) === 20) return { idhousehold: 1, idaccount: 20, role: 'Member', left_at: null };
        if (Number(idacc) === 30) return { idhousehold: 1, idaccount: 30, role: 'Viewer', left_at: null };
      }
      return null;
    };

    householdRepository.findFormerMember = async (idhh, idacc) => {
      if (Number(idhh) === 2 && Number(idacc) === 20) {
        return { idhousehold: 2, idaccount: 20, role: 'Member', left_at: new Date() };
      }
      return null;
    };

    prisma.account.findUnique = async ({ where }) => {
      if (overrides.ownerNotPremium && Number(where.idaccount) === 10) {
        return { idaccount: 10, type: 'Basic', premium_expires_at: null };
      }
      return { idaccount: Number(where.idaccount), type: 'Premium', premium_expires_at: new Date('2030-01-01') };
    };

    prisma.wallet.findUnique = async ({ where }) => {
      const id = where.idwallet;
      if (id === W_ID) return { idwallet: W_ID, idaccount: 10, idhousehold: 1, update_at: new Date() };
      if (id === W2_ID) return { idwallet: W2_ID, idaccount: 10, idhousehold: 1, update_at: new Date() };
      if (id === W_PRIV_ID) return { idwallet: W_PRIV_ID, idaccount: 20, idhousehold: null, update_at: new Date() };
      return null;
    };

    prisma.goal.findUnique = async ({ where }) => {
      if (where.idgoal === G_ID) return { idgoal: G_ID, idaccount: 10, idhousehold: 1 };
      return null;
    };

    prisma.category.findUnique = async ({ where }) => {
      if (where.idcategory === K_ID) {
        return { idcategory: K_ID, name_category: 'Ăn uống nhà', create_by: 10, idhousehold: 1, is_default: false, update_at: new Date('2026-01-01') };
      }
      if (where.idcategory === CAT_SYS_ID) {
        return { idcategory: CAT_SYS_ID, name_category: 'Lương', is_default: true, update_at: new Date('2026-01-01') };
      }
      return null;
    };

    prisma.transaction.findUnique = async ({ where }) => {
      if (where.idtran === T_B_ID) {
        return { idtran: T_B_ID, idhousehold: 1, idaccount: 20, idwallet: W_ID, update_at: new Date('2026-01-01') };
      }
      if (where.idtran === T_A_ID) {
        return { idtran: T_A_ID, idhousehold: 1, idaccount: 10, idwallet: W_ID, update_at: new Date('2026-01-01') };
      }
      return null;
    };

    syncRepository.getWalletById = async (id) => prisma.wallet.findUnique({ where: { idwallet: id } });
    syncRepository.getTransactionById = async (id) => prisma.transaction.findUnique({ where: { idtran: id } });
    syncRepository.getCategoryById = async (id) => prisma.category.findUnique({ where: { idcategory: id } });
    syncRepository.getGoalById = async (id) => prisma.goal.findUnique({ where: { idgoal: id } });
    syncRepository.getBudgetById = async () => null;

    syncRepository.upsertWallet = async () => ({ status: 'synced' });
    syncRepository.upsertTransaction = async () => ({ status: 'synced' });
    syncRepository.upsertCategory = async () => ({ status: 'synced' });
    syncRepository.upsertBudget = async () => ({ status: 'synced' });
    syncRepository.upsertGoal = async () => ({ status: 'synced' });
  }

  function restore17CasesMock() {
    householdRepository.findMember = origFindMember;
    householdRepository.findHouseholdAnyStatus = origFindHouseholdAnyStatus;
    householdRepository.findFormerMember = origFindFormerMember;
    prisma.account.findUnique = origAccountFindUnique;
    prisma.wallet.findUnique = origWalletFindUnique;
    prisma.goal.findUnique = origGoalFindUnique;
    prisma.category.findUnique = origCategoryFindUnique;
    prisma.transaction.findUnique = origTransactionFindUnique;
    syncRepository.upsertWallet = origUpsertWallet;
    syncRepository.upsertTransaction = origUpsertTransaction;
    syncRepository.upsertCategory = origUpsertCategory;
    syncRepository.upsertBudget = origUpsertBudget;
    syncRepository.upsertGoal = origUpsertGoal;
  }

  await t.test('Ca 1. [processPush] D (ngoài nhà) sửa ví chung W -> Nhận HOUSEHOLD_NOT_MEMBER', async () => {
    setup17CasesMock();
    try {
      const res = await syncService.processPush(40, [
        { localId: 'c1', entity: 'wallet', operation: 'update', payload: { id: W_ID, name: 'Hack W' } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_NOT_MEMBER');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 2. [processPush] D (ngoài nhà) tạo giao dịch mang idhousehold = 1 -> Nhận HOUSEHOLD_NOT_MEMBER', async () => {
    setup17CasesMock();
    try {
      const res = await syncService.processPush(40, [
        { localId: 'c2', entity: 'transaction', operation: 'create', payload: { id: NEW_T_ID, idhousehold: 1, walletId: W_ID, amount: 50000, type: 'Transaction' } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_NOT_MEMBER');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 3. [processPush] C (Viewer) tạo giao dịch vào ví chung W -> Nhận HOUSEHOLD_READ_ONLY', async () => {
    setup17CasesMock();
    try {
      const res = await syncService.processPush(30, [
        { localId: 'c3', entity: 'transaction', operation: 'create', payload: { id: NEW_T_ID, idhousehold: 1, walletId: W_ID, amount: 50000, type: 'Transaction' } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_READ_ONLY');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 4. [processPush] Nhà ở trạng thái ReadOnly, A (Owner) tạo giao dịch -> Nhận HOUSEHOLD_READ_ONLY', async () => {
    setup17CasesMock({ houseStatus: 'ReadOnly' });
    try {
      const res = await syncService.processPush(10, [
        { localId: 'c4', entity: 'transaction', operation: 'create', payload: { id: NEW_T_ID, idhousehold: 1, walletId: W_ID, amount: 50000, type: 'Transaction' } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_READ_ONLY');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 5. [processPush] Nhà đã giải tán (Dissolved), B (từng ở) sửa giao dịch T -> Nhận HOUSEHOLD_CLOSED', async () => {
    setup17CasesMock();
    syncRepository.getTransactionById = async () => ({
      idtran: T_B_ID,
      idhousehold: 2, // Nhà 2 Dissolved
      idaccount: 20,
      idwallet: W_ID,
      update_at: new Date('2026-01-01'),
    });
    try {
      const res = await syncService.processPush(20, [
        { localId: 'c5', entity: 'transaction', operation: 'update', payload: { id: T_B_ID, amount: 60000 } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_CLOSED');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 6. [processPush] B tạo giao dịch riêng trỏ vào ví chung W -> Nhận HOUSEHOLD_SCOPE_MISMATCH', async () => {
    setup17CasesMock();
    try {
      const res = await syncService.processPush(20, [
        { localId: 'c6', entity: 'transaction', operation: 'create', payload: { id: NEW_T_ID, walletId: W_ID, amount: 20000, type: 'Transaction' } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_SCOPE_MISMATCH');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 7. [processPush] B tạo giao dịch riêng trỏ vào mục tiêu chung G -> Nhận HOUSEHOLD_SCOPE_MISMATCH', async () => {
    setup17CasesMock();
    try {
      const res = await syncService.processPush(20, [
        { localId: 'c7', entity: 'transaction', operation: 'create', payload: { id: NEW_T_ID, walletId: W_PRIV_ID, idgoal: G_ID, amount: 20000, type: 'Transaction' } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_SCOPE_MISMATCH');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 8. [processPush] B sửa giao dịch chung T, payload idhousehold: null -> Nhận HOUSEHOLD_SCOPE_MISMATCH', async () => {
    setup17CasesMock();
    try {
      const res = await syncService.processPush(20, [
        { localId: 'c8', entity: 'transaction', operation: 'update', payload: { id: T_B_ID, idhousehold: null, amount: 25000 } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_SCOPE_MISMATCH');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 9. [processPush] B (Member) tạo ví chung / mục tiêu chung / ngân sách chung -> Nhận HOUSEHOLD_ROLE_FORBIDDEN (3 ca)', async () => {
    setup17CasesMock();
    try {
      const resWallet = await syncService.processPush(20, [
        { localId: 'c9-w', entity: 'wallet', operation: 'create', payload: { id: NEW_W_ID, idhousehold: 1, name: 'Ví quỹ B' } },
      ]);
      assert.strictEqual(resWallet.results[0].code, 'HOUSEHOLD_ROLE_FORBIDDEN');

      const resGoal = await syncService.processPush(20, [
        { localId: 'c9-g', entity: 'goal', operation: 'create', payload: { id: NEW_G_ID, idhousehold: 1, name: 'Mục tiêu B' } },
      ]);
      assert.strictEqual(resGoal.results[0].code, 'HOUSEHOLD_ROLE_FORBIDDEN');

      const resBudget = await syncService.processPush(20, [
        { localId: 'c9-b', entity: 'budget', operation: 'create', payload: { id: NEW_B_ID, idhousehold: 1, total_amount: 1000000 } },
      ]);
      assert.strictEqual(resBudget.results[0].code, 'HOUSEHOLD_ROLE_FORBIDDEN');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 10. [processPush] B (Member) sửa giao dịch T_A của A -> Nhận HOUSEHOLD_ROLE_FORBIDDEN', async () => {
    setup17CasesMock();
    try {
      const res = await syncService.processPush(20, [
        { localId: 'c10', entity: 'transaction', operation: 'update', payload: { id: T_A_ID, amount: 99999 } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_ROLE_FORBIDDEN');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 11. [processPush] B (Member) tạo Transfer giữa hai ví chung -> Nhận HOUSEHOLD_ROLE_FORBIDDEN', async () => {
    setup17CasesMock();
    try {
      const res = await syncService.processPush(20, [
        { localId: 'c11', entity: 'transaction', operation: 'create', payload: { id: NEW_T_ID, idhousehold: 1, walletId: W_ID, idwallet_transfer: W2_ID, type: 'Transfer', amount: 50000 } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_ROLE_FORBIDDEN');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 12. [processPush] B (Member) sửa danh mục K của nhà -> Hợp lệ synced (không lỗi DB_ERROR)', async () => {
    setup17CasesMock();
    try {
      const res = await syncService.processPush(20, [
        { localId: 'c12', entity: 'category', operation: 'update', payload: { id: K_ID, name_category: 'Ăn uống cập nhật' } },
      ]);
      assert.strictEqual(res.results[0].status, 'synced');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 13. [processPush] A (Owner) sửa giao dịch T của B -> Hợp lệ synced, quyền sở hữu bảo toàn', async () => {
    setup17CasesMock();
    try {
      const res = await syncService.processPush(10, [
        { localId: 'c13', entity: 'transaction', operation: 'update', payload: { id: T_B_ID, amount: 77777 } },
      ]);
      assert.strictEqual(res.results[0].status, 'synced');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 14. [processPush] Người dùng cố tình sửa danh mục mặc định hệ thống -> Nhận FORBIDDEN_SYSTEM_DEFAULT', async () => {
    setup17CasesMock();
    syncRepository.upsertCategory = origUpsertCategory;
    try {
      const res = await syncService.processPush(10, [
        { localId: 'c14', entity: 'category', operation: 'update', payload: { id: CAT_SYS_ID, name_category: 'Lương sửa' } },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'FORBIDDEN_SYSTEM_DEFAULT');
    } finally {
      restore17CasesMock();
    }
  });

  await t.test('Ca 15. [requireFeature] Tài khoản Basic gọi tạo nhà -> Trả về HTTP 403 FEATURE_DISABLED', async () => {
    const middleware = requireFeature('household');
    let statusCode = 200;
    let jsonBody = null;
    const req = { user: { idaccount: 99, type: 'Basic' } };
    const res = {
      status(c) { statusCode = c; return this; },
      json(data) { jsonBody = data; return this; },
    };
    let nextCalled = false;
    const next = () => { nextCalled = true; };

    const origFindUnique = prisma.account.findUnique;
    prisma.account.findUnique = async () => ({
      idaccount: 99,
      type: 'Basic',
      premium_expires_at: null,
    });

    try {
      await middleware(req, res, next);
      assert.strictEqual(statusCode, 403);
      assert.strictEqual(jsonBody.code, 'FEATURE_DISABLED');
      assert.strictEqual(jsonBody.featureId, 'household');
      assert.strictEqual(nextCalled, false);
    } finally {
      prisma.account.findUnique = origFindUnique;
    }
  });

  await t.test('Ca 16. [processPush] A (Owner) tạo ví chung khi đã đạt giới hạn 10 ví -> Nhận HOUSEHOLD_WALLET_LIMIT', async () => {
    setup17CasesMock();
    const origCount = prisma.wallet.count;
    prisma.wallet.count = async (args) => {
      if (args?.where?.idhousehold) return 10;
      return 0;
    };

    try {
      const res = await syncService.processPush(ID_A, [
        {
          localId: 'w-11',
          entity: 'wallet',
          operation: 'create',
          payload: {
            id: '11111111-1111-4111-8111-111111111199',
            name: 'Ví thứ 11',
            type: 'Cash',
            balance: 0,
            idhousehold: 1,
            currency: 'VND',
            isDefault: false,
          },
        },
      ]);
      assert.strictEqual(res.results[0].status, 'error');
      assert.strictEqual(res.results[0].code, 'HOUSEHOLD_WALLET_LIMIT');
    } finally {
      prisma.wallet.count = origCount;
    }
  });

  await t.test('Ca 17. [updateHouseholdStatusByOwner] Cập nhật ReadOnly khi chủ hết hạn Premium và Active khi gia hạn', async () => {
    const origFindUnique = prisma.account.findUnique;
    const origFindMany = prisma.household.findMany;
    const origUpdate = prisma.household.update;

    let houseStatus = 'Active';
    const emittedEvents = [];
    const origEmit = householdService.emitHouseholdChanged;
    householdService.emitHouseholdChanged = (idhh, eventType, payload) => {
      emittedEvents.push({ idhh, eventType, payload });
    };

    try {
      // Chủ hết hạn
      prisma.account.findUnique = async () => ({
        idaccount: ID_A,
        type: 'Basic',
        premium_expires_at: new Date(Date.now() - 86400000),
        status: 'Active',
      });
      prisma.household.findMany = async () => [
        { idhousehold: 1, status: houseStatus },
      ];
      prisma.household.update = async ({ data }) => {
        houseStatus = data.status;
        return { idhousehold: 1, status: houseStatus };
      };

      await householdService.updateHouseholdStatusByOwner(ID_A);
      assert.strictEqual(houseStatus, 'ReadOnly');
      assert.ok(emittedEvents.some(e => e.eventType === 'STATUS_CHANGED' && e.payload.status === 'ReadOnly'));

      // Chủ gia hạn Premium
      prisma.account.findUnique = async () => ({
        idaccount: ID_A,
        type: 'Premium',
        premium_expires_at: new Date(Date.now() + 30 * 86400000),
        status: 'Active',
      });
      await householdService.updateHouseholdStatusByOwner(ID_A);
      assert.strictEqual(houseStatus, 'Active');
      assert.ok(emittedEvents.some(e => e.eventType === 'STATUS_CHANGED' && e.payload.status === 'Active'));
    } finally {
      prisma.account.findUnique = origFindUnique;
      prisma.household.findMany = origFindMany;
      prisma.household.update = origUpdate;
      householdService.emitHouseholdChanged = origEmit;
    }
  });

  await t.test('Ca 18. [cloneDefaultCategoriesForHousehold] Bảo toàn tính phân cấp idgroup và copy keyword', async () => {
    const parentId = '00000000-0000-4000-8000-000000000001';
    const childId = '00000000-0000-4000-8000-000000000002';
    const mockDefaultCats = [
      {
        idcategory: parentId,
        name_category: 'Ăn uống',
        classify: 'EXPENSE',
        is_default: true,
        is_group: true,
        idgroup: null,
        keyword: 'ăn, cafe, nhậu',
        icon: 'food',
        color: '#FF5722',
      },
      {
        idcategory: childId,
        name_category: 'Cà phê',
        classify: 'EXPENSE',
        is_default: true,
        is_group: false,
        idgroup: parentId,
        keyword: 'cà phê, highlands',
        icon: 'coffee',
        color: '#795548',
      },
    ];

    let insertedClones = [];
    const mockClient = {
      category: {
        findMany: async () => mockDefaultCats,
        createMany: async ({ data }) => {
          insertedClones = data;
          return { count: data.length };
        },
      },
    };

    const result = await householdService.cloneDefaultCategoriesForHousehold(99, ID_A, mockClient);
    assert.strictEqual(result.count, 2);
    assert.strictEqual(insertedClones.length, 2);

    const clonedParent = insertedClones.find(c => c.name_category === 'Ăn uống');
    const clonedChild = insertedClones.find(c => c.name_category === 'Cà phê');

    assert.ok(clonedParent);
    assert.ok(clonedChild);
    assert.strictEqual(clonedParent.idgroup, null);
    assert.strictEqual(clonedParent.keyword, 'ăn, cafe, nhậu');
    // Phân cấp: idgroup của child trỏ tới idcategory của parent mới
    assert.strictEqual(clonedChild.idgroup, clonedParent.idcategory);
    assert.strictEqual(clonedChild.keyword, 'cà phê, highlands');
  });

  await t.test('Ca 19. [emitHouseholdChanged] Phát tán đa kênh: Room nhà + Room cá nhân của các thành viên', async () => {
    const socketModule = require('../../core/socket');
    const origEmitToAccount = socketModule.emitToAccount;
    const origFindActiveMembers = householdRepository.findActiveMembersByHousehold;

    householdRepository.findActiveMembersByHousehold = async () => [
      { idaccount: ID_A, role: 'Owner' },
      { idaccount: ID_B, role: 'Member' },
      { idaccount: ID_C, role: 'Viewer' },
    ];

    const emittedToRooms = [];
    const emittedToAccounts = [];

    const mockIO = {
      to(room) {
        return {
          emit(evt, data) {
            emittedToRooms.push({ room, evt, data });
          },
        };
      },
    };

    socketModule._setMockIO(mockIO);
    socketModule.emitToAccount = (idaccount, event, data) => {
      emittedToAccounts.push({ idaccount, event, data });
    };

    try {
      await householdService.emitHouseholdChanged(1, 'TEST_EVENT', { msg: 'hello' }, [ID_D]);

      // Kênh room nhà
      assert.ok(emittedToRooms.some(r => r.room === 'household_1' && r.evt === 'household.changed'));
      // Kênh account cá nhân của thành viên A, B, C (active members) và D (extra recipient)
      const accountIds = emittedToAccounts.map(a => a.idaccount);
      assert.ok(accountIds.includes(ID_A));
      assert.ok(accountIds.includes(ID_B));
      assert.ok(accountIds.includes(ID_C));
      assert.ok(accountIds.includes(ID_D));
    } finally {
      socketModule._setMockIO(null);
      socketModule.emitToAccount = origEmitToAccount;
      householdRepository.findActiveMembersByHousehold = origFindActiveMembers;
    }
  });
});
