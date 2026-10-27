const test = require('node:test');
const assert = require('node:assert/strict');
const syncRepository = require('../../modules/sync/sync.repository');

test('Sync mapEntityFields is_deleted Soft-delete Preservation Suite (2-Tier Test)', async (t) => {
  // mapEntityFields is not exported directly, but we can verify it via the upsert methods with mocked Prisma
  const { prisma } = require('../../config/db');

  const entities = ['wallet', 'category', 'budget', 'bill', 'goal'];

  for (const entity of entities) {
    await t.test(`Tier 2: [${entity}] Gửi is_deleted: false KHÔNG làm mất Delete_at của bản ghi đã xóa mềm`, async () => {
      const mockId = `test-${entity}-softdelete-1`;
      const existingDeletedAt = new Date('2026-10-20T10:00:00.000Z');
      
      let updateDataPassed = null;
      const modelName = entity === 'category' ? 'category' : entity;
      
      const origFindUnique = prisma[modelName].findUnique;
      const origUpdate = prisma[modelName].update;

      const mockExisting = {
        delete_at: existingDeletedAt,
        update_at: new Date('2026-10-20T09:00:00.000Z'),
      };
      if (entity === 'wallet') mockExisting.idwallet = mockId;
      if (entity === 'category') mockExisting.idcategory = mockId;
      if (entity === 'budget') mockExisting.idbudget = mockId;
      if (entity === 'bill') mockExisting.idbill = mockId;
      if (entity === 'goal') mockExisting.idgoal = mockId;

      prisma[modelName].findUnique = async () => mockExisting;
      prisma[modelName].update = async ({ data }) => {
        updateDataPassed = data;
        return { ...mockExisting, ...data };
      };

      try {
        const payload = {
          id: mockId,
          is_deleted: false,
          isDeleted: false,
          updatedAt: new Date().toISOString(),
        };

        if (entity === 'wallet') await syncRepository.upsertWallet(payload);
        if (entity === 'category') await syncRepository.upsertCategory(payload);
        if (entity === 'budget') await syncRepository.upsertBudget(payload);
        if (entity === 'bill') await syncRepository.upsertBill(payload);
        if (entity === 'goal') await syncRepository.upsertGoal(payload);

        // Tầng 2: Hệ thống và CSDL phải bảo toàn cờ xóa cũ
        assert.ok(updateDataPassed, `update cho ${entity} phải được gọi`);
        assert.strictEqual(
          updateDataPassed.delete_at,
          existingDeletedAt,
          `delete_at của ${entity} phải được bảo toàn giá trị cũ, tuyệt đối không được gán null làm sống lại bản ghi!`
        );
      } finally {
        prisma[modelName].findUnique = origFindUnique;
        prisma[modelName].update = origUpdate;
      }
    });

    await t.test(`Tier 2: [${entity}] Gửi is_deleted: true cập nhật delete_at thành ngày mới`, async () => {
      const mockId = `test-${entity}-softdelete-true`;
      
      let updateDataPassed = null;
      const modelName = entity === 'category' ? 'category' : entity;
      
      const origFindUnique = prisma[modelName].findUnique;
      const origUpdate = prisma[modelName].update;

      const mockExisting = {
        delete_at: null,
        update_at: new Date('2026-10-20T09:00:00.000Z'),
      };
      if (entity === 'wallet') mockExisting.idwallet = mockId;
      if (entity === 'category') mockExisting.idcategory = mockId;
      if (entity === 'budget') mockExisting.idbudget = mockId;
      if (entity === 'bill') mockExisting.idbill = mockId;
      if (entity === 'goal') mockExisting.idgoal = mockId;

      prisma[modelName].findUnique = async () => mockExisting;
      prisma[modelName].update = async ({ data }) => {
        updateDataPassed = data;
        return { ...mockExisting, ...data };
      };

      try {
        const payload = {
          id: mockId,
          is_deleted: true,
          updatedAt: new Date().toISOString(),
        };

        if (entity === 'wallet') await syncRepository.upsertWallet(payload);
        if (entity === 'category') await syncRepository.upsertCategory(payload);
        if (entity === 'budget') await syncRepository.upsertBudget(payload);
        if (entity === 'bill') await syncRepository.upsertBill(payload);
        if (entity === 'goal') await syncRepository.upsertGoal(payload);

        assert.ok(updateDataPassed, `update cho ${entity} phải được gọi`);
        assert.ok(updateDataPassed.delete_at instanceof Date, `delete_at của ${entity} phải là Date khi is_deleted: true`);
      } finally {
        prisma[modelName].findUnique = origFindUnique;
        prisma[modelName].update = origUpdate;
      }
    });
  }

  // Riêng Transaction dùng deleted_at
  await t.test('Tier 2: [transaction] Gửi is_deleted: false KHÔNG làm mất Deleted_at của giao dịch đã xóa', async () => {
    const mockId = 'test-tran-softdelete-1';
    const existingDeletedAt = new Date('2026-10-20T10:00:00.000Z');

    let updateDataPassed = null;
    const origFindUnique = prisma.transaction.findUnique;
    const origUpdate = prisma.transaction.update;

    const mockExisting = {
      idtran: mockId,
      deleted_at: existingDeletedAt,
      update_at: new Date('2026-10-20T09:00:00.000Z'),
    };

    prisma.transaction.findUnique = async () => mockExisting;
    prisma.transaction.update = async ({ data }) => {
      updateDataPassed = data;
      return { ...mockExisting, ...data };
    };

    try {
      const payload = {
        id: mockId,
        is_deleted: false,
        isDeleted: false,
        updatedAt: new Date().toISOString(),
      };

      await syncRepository.upsertTransaction(payload);

      assert.ok(updateDataPassed, 'update cho transaction phải được gọi');
      assert.strictEqual(
        updateDataPassed.deleted_at,
        existingDeletedAt,
        'deleted_at của giao dịch phải được bảo toàn giá trị cũ, không được gán null!'
      );
    } finally {
      prisma.transaction.findUnique = origFindUnique;
      prisma.transaction.update = origUpdate;
    }
  });
});
