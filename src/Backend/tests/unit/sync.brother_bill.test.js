const test = require('node:test');
const assert = require('node:assert/strict');
const syncRepository = require('../../modules/sync/sync.repository');
const syncService = require('../../modules/sync/sync.service');
const { prisma } = require('../../config/db');

test('Sync — Chặn trả tiền hai lần cho cùng một kỳ hóa đơn (Mục 41 CAN-LAM)', async (t) => {
  const origFindUniqueTran = prisma.transaction.findUnique;
  const origFindFirstTran = prisma.transaction.findFirst;
  const origFindUniqueBill = prisma.bill.findUnique;
  const origCreateTran = prisma.transaction.create;

  t.afterEach(() => {
    prisma.transaction.findUnique = origFindUniqueTran;
    prisma.transaction.findFirst = origFindFirstTran;
    prisma.bill.findUnique = origFindUniqueBill;
    prisma.transaction.create = origCreateTran;
  });

  await t.test('1. [Tier 2] Hai kỳ anh em C1, C2 (cùng previous_bill_id + due_date): C1 đã trả -> đẩy khoản chi cho C2 bị chặn với BILL_PERIOD_ALREADY_PAID', async () => {
    prisma.transaction.findUnique = async () => null; // Giao dịch mới chưa tồn tại

    // Khi kiểm tra cùng idbill -> không có khoản chi trùng
    // Khi kiểm tra kỳ anh em -> tìm thấy giao dịch T1 đã trả cho C1
    prisma.bill.findUnique = async ({ where }) => {
      if (where.idbill === 'bill-c2') {
        return {
          idbill: 'bill-c2',
          previous_bill_id: 'bill-parent-P',
          due_date: new Date('2026-10-15T00:00:00.000Z'),
        };
      }
      return null;
    };

    let findFirstCallCount = 0;
    prisma.transaction.findFirst = async (args) => {
      findFirstCallCount++;
      if (findFirstCallCount === 1) {
        // Lần 1: Kiểm tra cùng idbill
        assert.strictEqual(args.where.idbill, 'bill-c2');
        return null;
      }
      if (findFirstCallCount === 2) {
        // Lần 2: Kiểm tra kỳ anh em
        assert.strictEqual(args.where.idbill.not, 'bill-c2');
        assert.strictEqual(args.where.bill.previous_bill_id, 'bill-parent-P');
        assert.deepStrictEqual(args.where.bill.due_date, new Date('2026-10-15T00:00:00.000Z'));
        assert.strictEqual(args.where.bill.delete_at, null);
        return { idtran: 'tran-t1-for-c1' };
      }
      return null;
    };

    await assert.rejects(
      async () => {
        await syncRepository.upsertTransaction({
          idtran: 'tran-t2-for-c2',
          idaccount: 10,
          idwallet: 'wallet-01',
          idbill: 'bill-c2',
          amount: 100000,
        });
      },
      (err) => {
        assert.strictEqual(err.code, 'BILL_PERIOD_ALREADY_PAID');
        assert.match(err.message, /Kỳ hoá đơn này đã được thanh toán ở một kỳ trùng/);
        return true;
      }
    );
  });

  await t.test('2. [Tier 2] Cùng Idbill đã thanh toán -> ném BILL_ALREADY_PAID (mã lỗi cũ bảo toàn)', async () => {
    prisma.transaction.findUnique = async () => null;

    prisma.transaction.findFirst = async (args) => {
      // Lần 1: Kiểm tra cùng idbill -> thấy ngay khoản chi khác
      return { idtran: 'existing-tran-for-same-bill' };
    };

    await assert.rejects(
      async () => {
        await syncRepository.upsertTransaction({
          idtran: 'tran-duplicate',
          idaccount: 10,
          idwallet: 'wallet-01',
          idbill: 'bill-c1',
          amount: 100000,
        });
      },
      (err) => {
        assert.strictEqual(err.code, 'BILL_ALREADY_PAID');
        return true;
      }
    );
  });

  await t.test('3. [Tier 2] Kỳ gốc (previous_bill_id = NULL) -> Bỏ qua kiểm tra kỳ anh em, tạo thành công', async () => {
    prisma.transaction.findUnique = async () => null;
    prisma.transaction.findFirst = async () => null; // Không có giao dịch trùng
    prisma.bill.findUnique = async () => ({
      idbill: 'bill-root',
      previous_bill_id: null,
      due_date: new Date('2026-10-15T00:00:00.000Z'),
    });

    let createdRecord = null;
    prisma.transaction.create = async ({ data }) => {
      createdRecord = data;
      return data;
    };

    const res = await syncRepository.upsertTransaction({
      idtran: 'tran-root-01',
      idaccount: 10,
      idwallet: 'wallet-01',
      idbill: 'bill-root',
      amount: 100000,
    });

    assert.ok(createdRecord);
    assert.strictEqual(createdRecord.idtran, 'tran-root-01');
  });

  await t.test('4. [Tier 2] dangXoaTrongLo: Khoản chi của kỳ anh em nằm trong dangXoaTrongLo -> Cho phép tạo', async () => {
    prisma.transaction.findUnique = async () => null;
    prisma.bill.findUnique = async () => ({
      idbill: 'bill-c2',
      previous_bill_id: 'bill-parent-P',
      due_date: new Date('2026-10-15T00:00:00.000Z'),
    });

    let receivedNotIn = null;
    prisma.transaction.findFirst = async (args) => {
      receivedNotIn = args.where.idtran.notIn;
      return null; // Không còn khoản chi nào khác ngoài dangXoaTrongLo
    };

    prisma.transaction.create = async ({ data }) => data;

    const dangXoa = new Set(['tran-t1-being-deleted']);
    await syncRepository.upsertTransaction(
      {
        idtran: 'tran-t2-for-c2',
        idaccount: 10,
        idwallet: 'wallet-01',
        idbill: 'bill-c2',
        amount: 100000,
      },
      dangXoa
    );

    assert.ok(receivedNotIn.includes('tran-t1-being-deleted'));
  });

  await t.test('5. [Tier 1] sync.service ánh xạ BILL_PERIOD_ALREADY_PAID vào results đúng chuẩn hợp đồng Client', async () => {
    const origUpsert = syncRepository.upsertTransaction;
    try {
      syncRepository.upsertTransaction = async () => {
        throw Object.assign(new Error('Kỳ hoá đơn này đã được thanh toán ở một kỳ trùng'), {
          code: 'BILL_PERIOD_ALREADY_PAID',
        });
      };

      const result = await syncService.processPush(10, [
        {
          localId: 'loc-01',
          entity: 'transaction',
          operation: 'create',
          payload: {
            idtran: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
            idaccount: 10,
            idwallet: 'b1b2c3d4-e5f6-7890-abcd-ef1234567890',
            idbill: 'c1b2c3d4-e5f6-7890-abcd-ef1234567890',
            amount: 100000,
            update_at: new Date().toISOString(),
          },
        },
      ]);

      assert.strictEqual(result.results.length, 1);
      assert.strictEqual(result.results[0].status, 'error');
      assert.strictEqual(result.results[0].code, 'BILL_PERIOD_ALREADY_PAID');
      assert.strictEqual(result.results[0].message, 'Kỳ hoá đơn này đã được thanh toán ở một kỳ trùng');
    } finally {
      syncRepository.upsertTransaction = origUpsert;
    }
  });
});
