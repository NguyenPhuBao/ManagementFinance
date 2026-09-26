/**
 * Unit Test — On-Demand Financial Tools Executor (TDD Phase 2)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const ToolsExecutor = require('../../modules/ai/features/chatbot/tools/tools.executor');
const { financialToolsDeclarations } = require('../../modules/ai/features/chatbot/tools/financial.tools');

describe('FinancialToolsDeclarations — Khai Báo JSON Schema Chuẩn Gemini SDK', () => {
  it('1. Đủ 4 công cụ đào sâu theo chuẩn Function Calling', () => {
    assert.ok(Array.isArray(financialToolsDeclarations), 'Phải là mảng declarations');
    assert.strictEqual(financialToolsDeclarations.length, 4, 'Phải có 4 tools');

    const toolNames = financialToolsDeclarations.map(t => t.name);
    assert.ok(toolNames.includes('get_category_transactions'));
    assert.ok(toolNames.includes('compare_spending_periods'));
    assert.ok(toolNames.includes('get_bill_details'));
    assert.ok(toolNames.includes('get_goal_simulation'));
  });

  it('2. Các tool có parameters đúng định dạng schema', () => {
    for (const tool of financialToolsDeclarations) {
      assert.ok(tool.name, 'Tool phải có name');
      assert.ok(tool.description, 'Tool phải có description');
      assert.ok(tool.parameters, 'Tool phải có parameters');
      assert.strictEqual(tool.parameters.type, 'OBJECT');
    }
  });
});

describe('ToolsExecutor — Logic Xử Lý & Ràng Buộc An Toàn Dữ Liệu', () => {
  const executor = new ToolsExecutor();

  it('1. get_goal_simulation: Giả lập đúng số tháng hoàn thành mục tiêu', async () => {
    const mockGoal = {
      name: 'Mua xe máy',
      target_amount: 50000000,
      current_amount: 20000000,
      status_complete: 'False',
    };

    const simulation = executor.simulateGoalProgress(mockGoal, 5000000);
    // Còn thiếu 30tr, mỗi tháng góp 5tr => cần 6 tháng
    assert.strictEqual(simulation.remainingAmount, 30000000);
    assert.strictEqual(simulation.monthsNeeded, 6);
  });

  it('2. compare_spending_periods: Tính đúng chênh lệch và % tăng giảm', () => {
    const period1Expenses = 15000000; // Kỳ gần đây
    const period2Expenses = 10000000; // Kỳ trước đó

    const diff = executor.calculatePeriodDifference(period1Expenses, period2Expenses);
    assert.strictEqual(diff.difference, 5000000);
    assert.strictEqual(diff.percentageChange, '+50%');
    assert.strictEqual(diff.trend, 'increased');
  });

  it('3. Che PII ghi chú khi trả về danh sách giao dịch', () => {
    const rawTxList = [
      { idtran: 't1', amount: 500000, note: 'Chuyển tiền STK 19034567890123 mua hàng', category: { namecategory: 'Mua sắm' } },
      { idtran: 't2', amount: 200000, note: 'Gặp bạn số đt 0988776655 cà phê', category: { namecategory: 'Ăn uống' } },
    ];

    const sanitizedList = executor.sanitizeTransactionList(rawTxList);
    assert.ok(!sanitizedList[0].note.includes('0123456789'), 'Phải che STK');
    assert.ok(sanitizedList[0].note.includes('[STK]'));
    assert.ok(!sanitizedList[1].note.includes('0988776655'), 'Phải che SĐT');
    assert.ok(sanitizedList[1].note.includes('[SĐT]'));
  });
});
