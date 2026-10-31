const test = require('node:test');
const assert = require('node:assert/strict');
const { isPremiumEffective } = require('../../utils/premium.util');
const paymentRepository = require('../../modules/payment/payment.repository');
const { prisma } = require('../../config/db');

// Task 55.A3: Premium không có hạn là dữ liệu hỏng, coi là Basic. Đường thật bốn nơi + job: KIEM-THU/chay_kiem_pr174.js.
test('isPremiumEffective', () => {
  const now = new Date('2026-11-01T00:00:00Z');
  assert.strictEqual(isPremiumEffective({ type: 'Premium', premium_expires_at: null }, now), false);
  assert.strictEqual(isPremiumEffective({ type: 'Premium', premium_expires_at: now }, now), false, 'đúng mốc là hết');
  assert.strictEqual(isPremiumEffective({ type: 'Premium', premium_expires_at: new Date('2026-11-02T00:00:00Z') }, now), true);
  assert.strictEqual(isPremiumEffective({ type: 'Basic', premium_expires_at: new Date('2026-11-02T00:00:00Z') }, now), false);
  assert.strictEqual(isPremiumEffective(null, now), false);
});

test('job hạ cấp quét cả hàng không có hạn', async () => {
  let where;
  const orig = prisma.account.findMany;
  prisma.account.findMany = async (a) => { where = a.where; return []; };
  try {
    await paymentRepository.downgradeExpiredPremiumAccounts(new Date());
    assert.ok(where.OR.some((d) => d.premium_expires_at === null));
  } finally {
    prisma.account.findMany = orig;
  }
});
