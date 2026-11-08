/**
 * Unit Test — Chuẩn hoá chiều dòng tiền gửi cho LLM + giải mã ghi chú trong công cụ
 * Quy ước: dấu + là thu, dấu − là chi; Transfer không tính thu chi; Vay/no là nhóm riêng.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { normalizeFlow } = require('../../modules/ai/features/chatbot/tools/flow.normalizer');
const ToolsExecutor = require('../../modules/ai/features/chatbot/tools/tools.executor');
const { encrypt } = require('../../utils/crypto.util');

describe('normalizeFlow — quy ước dấu', () => {
  it('1. Dấu dương = income, dấu âm = expense, amount luôn dương', () => {
    assert.deepStrictEqual(normalizeFlow({ amount: 5000000, type: 'Transaction', classify: 'Thu' }), { direction: 'income', amount: 5000000 });
    assert.deepStrictEqual(normalizeFlow({ amount: -45000, type: 'Transaction', classify: 'Chi' }), { direction: 'expense', amount: 45000 });
  });

  it('2. Transfer là transfer, bất kể dấu', () => {
    assert.strictEqual(normalizeFlow({ amount: -1000000, type: 'Transfer', classify: 'Chi' }).direction, 'transfer');
    assert.strictEqual(normalizeFlow({ amount: 1000000, type: 'Transfer', classify: null }).direction, 'transfer');
  });

  it('3. Vay/no tách nhóm riêng theo chiều tiền', () => {
    assert.strictEqual(normalizeFlow({ amount: 2000000, type: 'Transaction', classify: 'Vay/no' }).direction, 'debt_in');
    assert.strictEqual(normalizeFlow({ amount: -2000000, type: 'Transaction', classify: 'Vay/no' }).direction, 'debt_out');
  });

  it('4. Nhận Decimal/chuỗi như số', () => {
    assert.strictEqual(normalizeFlow({ amount: '-120000.00', type: 'Transaction', classify: 'Chi' }).amount, 120000);
  });
});

describe('ToolsExecutor.sanitizeTransactionList — ghi chú mã hoá và chiều tiền', () => {
  const executor = new ToolsExecutor();

  it('1. Ghi chú mã hoá at-rest được giải mã rồi mới che PII, không lộ bản mã enc:', () => {
    const note = encrypt('chuyen khoan tra no 0912345678');
    assert.ok(note.startsWith('enc:'), 'giả định: ghi chú đã mã hoá');
    const [row] = executor.sanitizeTransactionList([
      { idtran: 't1', amount: -300000, type: 'Transaction', note, date_transaction: new Date('2026-11-01'), category: { name_category: 'Ăn uống', classify: 'Chi' } },
    ]);
    assert.ok(!row.note.includes('enc:'));
    assert.ok(!row.note.includes('0912345678'), 'số điện thoại phải được che');
    assert.ok(row.note.includes('tra no'));
  });

  it('2. Bản mã hỏng thì trả chuỗi rỗng, không trả enc:', () => {
    const [row] = executor.sanitizeTransactionList([
      { idtran: 't2', amount: -1, type: 'Transaction', note: 'enc:zz:zz:zz', category: { name_category: 'Khác', classify: 'Chi' } },
    ]);
    assert.strictEqual(row.note, '');
  });

  it('3. Mỗi dòng có direction và amount dương', () => {
    const rows = executor.sanitizeTransactionList([
      { idtran: 'a', amount: -50000, type: 'Transaction', note: '', category: { name_category: 'Cafe', classify: 'Chi' } },
      { idtran: 'b', amount: 9000000, type: 'Transaction', note: '', category: { name_category: 'Lương', classify: 'Thu' } },
      { idtran: 'c', amount: -700000, type: 'Transfer', note: '', category: null },
      { idtran: 'd', amount: 1500000, type: 'Transaction', note: '', category: { name_category: 'Đi vay', classify: 'Vay/no' } },
    ]);
    assert.deepStrictEqual(rows.map((r) => r.direction), ['expense', 'income', 'transfer', 'debt_in']);
    assert.ok(rows.every((r) => r.amount > 0));
  });
});
