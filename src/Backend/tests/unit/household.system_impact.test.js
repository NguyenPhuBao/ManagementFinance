const test = require('node:test');
const assert = require('node:assert/strict');

test('Household Module — Tầng 2: System Impact, Security & DB Guard Suite (Rule 11)', async (t) => {
  const syncRepository = require('../../modules/sync/sync.repository');
  const syncService = require('../../modules/sync/sync.service');
  const householdService = require('../../modules/household/household.service');
  const { prisma } = require('../../config/db');

  // ── [1] Vá an ninh NOT_OWNER trong /sync/push ───────────────
  await t.test('1. [Tier 2] Chặn đứng người dùng sửa ví riêng của người khác (NOT_OWNER)', async () => {
    const origFindUnique = prisma.wallet.findUnique;
    // Giả lập ví cá nhân của tài khoản 10
    prisma.wallet.findUnique = async () => ({
      idwallet: 'wallet-user-10',
      idaccount: 10,
      idhousehold: null,
      name: 'Ví riêng Tuấn',
      update_at: new Date('2026-10-20T10:00:00Z'),
    });

    try {
      // Tài khoản 99 (hacker) cố tình đẩy bản ghi sửa ví của tài khoản 10
      await assert.rejects(
        async () => {
          await syncRepository.upsertWallet({
            idwallet: 'wallet-user-10',
            idaccount: 99,
            name: 'Ví bị hack',
            update_at: new Date('2026-10-25T10:00:00Z'),
          }, 99); // reqUserId = 99
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
      idbill: 'bill-user-10',
      idaccount: 10,
      name: 'Hóa đơn điện Tuấn',
      update_at: new Date('2026-10-20T10:00:00Z'),
    });

    try {
      await assert.rejects(
        async () => {
          await syncRepository.upsertBill({
            idbill: 'bill-user-10',
            idaccount: 99,
            name: 'Hóa đơn bị hack',
            update_at: new Date('2026-10-25T10:00:00Z'),
          }, 99); // reqUserId = 99
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
      idtran: 'tx-user-10',
      idaccount: 10,
      idhousehold: null,
      amount: 50000,
    });

    try {
      // Tài khoản 99 cố tình xóa giao dịch của tài khoản 10
      await assert.rejects(
        async () => {
          await syncRepository.softDelete('transaction', 'tx-user-10', 99); // reqUserId = 99
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

  // ── [2] Ma trận quyền Vai trò x Thực thể (HOUSEHOLD_ROLE_FORBIDDEN) ─
  await t.test('3. [Tier 2] Thành viên (Member) tạo ví chung của nhà -> Bị chặn với HOUSEHOLD_ROLE_FORBIDDEN', async () => {
    const origGetMember = householdService.getMemberRoleInHousehold;
    householdService.getMemberRoleInHousehold = async () => 'Member';

    try {
      await assert.rejects(
        async () => {
          await syncService.enforceHouseholdPermission({
            entity: 'wallet',
            operation: 'create',
            idaccount: 25,
            idhousehold: 1,
            userRole: 'Member',
          });
        },
        (err) => {
          assert.strictEqual(err.code, 'HOUSEHOLD_ROLE_FORBIDDEN');
          return true;
        }
      );
    } finally {
      householdService.getMemberRoleInHousehold = origGetMember;
    }
  });

  await t.test('4. [Tier 2] Thành viên sửa giao dịch do người khác ghi trong nhà -> Bị chặn với HOUSEHOLD_ROLE_FORBIDDEN', async () => {
    try {
      await assert.rejects(
        async () => {
          await syncService.enforceHouseholdPermission({
            entity: 'transaction',
            operation: 'update',
            idaccount: 25, // Người gọi sửa
            existingCreatorId: 10, // Người tạo ban đầu là tài khoản 10
            idhousehold: 1,
            userRole: 'Member',
          });
        },
        (err) => {
          assert.strictEqual(err.code, 'HOUSEHOLD_ROLE_FORBIDDEN');
          return true;
        }
      );
    } catch (e) {
      throw e;
    }
  });

  await t.test('5. [Tier 2] Chủ nhà (Owner) được phép sửa giao dịch thu/chi thường của thành viên', async () => {
    const isAllowed = syncService.enforceHouseholdPermission({
      entity: 'transaction',
      operation: 'update',
      idaccount: 10, // Chủ nhà
      existingCreatorId: 25, // Thành viên ghi
      idhousehold: 1,
      userRole: 'Owner',
    });
    assert.strictEqual(isAllowed, true);
  });

  // ── [3] Kiểm soát trạng thái ReadOnly khi hết hạn Premium ──
  await t.test('6. [Tier 2] Nhà ở trạng thái ReadOnly -> Mọi thao tác ghi mới bị từ chối với HOUSEHOLD_READ_ONLY', async () => {
    try {
      await assert.rejects(
        async () => {
          await syncService.enforceHouseholdPermission({
            entity: 'transaction',
            operation: 'create',
            idaccount: 10,
            idhousehold: 1,
            householdStatus: 'ReadOnly',
            userRole: 'Owner',
          });
        },
        (err) => {
          assert.strictEqual(err.code, 'HOUSEHOLD_READ_ONLY');
          return true;
        }
      );
    } catch (e) {
      throw e;
    }
  });

  // ── [4] Kiểm soát phạm vi tham chiếu (HOUSEHOLD_SCOPE_MISMATCH) ─
  await t.test('7. [Tier 2] Giao dịch riêng (idhousehold null) cố trỏ vào ví chung -> Chặn với HOUSEHOLD_SCOPE_MISMATCH', async () => {
    const origFindUnique = prisma.wallet.findUnique;
    prisma.wallet.findUnique = async () => ({
      idwallet: 'wallet-shared-1',
      idhousehold: 1, // Ví chung
    });

    try {
      await assert.rejects(
        async () => {
          await syncService.validateEntityScope({
            entity: 'transaction',
            idhousehold: null, // Giao dịch riêng
            idwallet: 'wallet-shared-1',
          });
        },
        (err) => {
          assert.strictEqual(err.code, 'HOUSEHOLD_SCOPE_MISMATCH');
          return true;
        }
      );
    } finally {
      prisma.wallet.findUnique = origFindUnique;
    }
  });

  // ── [5] Tự động nhân bản 13 danh mục mặc định cho nhà mới ──
  await t.test('8. [Tier 2] Tạo nhà mới tự động nhân bản 13 danh mục hệ thống thành danh mục của nhà', async () => {
    let clonedCount = 0;
    const origFindMany = prisma.category.findMany;
    const origCreateMany = prisma.category.createMany;

    // Giả lập 13 danh mục mặc định
    const mockDefaults = Array.from({ length: 13 }, (_, i) => ({
      idcategory: `cat-default-${i + 1}`,
      name_category: `Danh mục ${i + 1}`,
      classify: 'Chi',
      is_default: true,
      icon: 'icon',
      color: '#fff',
    }));

    prisma.category.findMany = async () => mockDefaults;
    prisma.category.createMany = async ({ data }) => {
      clonedCount = data.length;
      assert.strictEqual(data[0].idhousehold, 999);
      assert.strictEqual(data[0].is_default, false);
      assert.strictEqual(data[0].create_by, 10);
      return { count: data.length };
    };

    try {
      await householdService.cloneDefaultCategoriesForHousehold(999, 10, prisma);
      assert.strictEqual(clonedCount, 13);
    } finally {
      prisma.category.findMany = origFindMany;
      prisma.category.createMany = origCreateMany;
    }
  });
});
