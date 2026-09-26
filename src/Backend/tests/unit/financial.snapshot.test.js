/**
 * Unit Test — Financial Snapshot Service & PII Masker (TDD Phase 1)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const FinancialSnapshotService = require('../../modules/ai/features/chatbot/snapshot/financial.snapshot.service');
const PIIMasker = require('../../modules/ai/features/chatbot/privacy/pii.masker');

describe('FinancialSnapshotService — Logic Nghiệp Vụ Sức Khỏe Tài Chính', () => {
  const service = new FinancialSnapshotService();

  it('1. Công thức thu nhập chuẩn: Loại trừ khoản vay, thu nợ và chuyển ví nội bộ', () => {
    const rawTransactions = [
      { idtran: '1', amount: 20000000, type: 'Transaction', category: { classify: 'Thu', namecategory: 'Lương' }, idwallet_transfer: null },
      { idtran: '2', amount: 5000000, type: 'Transaction', category: { classify: 'Thu', namecategory: 'Thu nợ' }, idwallet_transfer: null },
      { idtran: '3', amount: 10000000, type: 'Transaction', category: { classify: 'Thu', namecategory: 'Đi vay' }, idwallet_transfer: null },
      { idtran: '4', amount: 2000000, type: 'Transfer', category: null, idwallet_transfer: 'w2' },
      { idtran: '5', amount: 3000000, type: 'Transaction', category: { classify: 'Thu', namecategory: 'Thưởng dự án' }, idwallet_transfer: null },
    ];

    const validIncome = service.calculateValidIncome(rawTransactions);
    // Chỉ tính Lương (20tr) + Thưởng (3tr) = 23tr. Bỏ Thu nợ, Đi vay, Chuyển ví
    assert.strictEqual(validIncome, 23000000);
  });

  it('2. Phân bổ cơ cấu 50/30/20 từ chi tiêu', () => {
    const expenses = [
      { amount: 10000000, category: { namecategory: 'Thuê nhà' } }, // Needs
      { amount: 5000000, category: { namecategory: 'Ăn uống' } },   // Needs
      { amount: 6000000, category: { namecategory: 'Mua sắm' } },   // Wants
      { amount: 4000000, category: { namecategory: 'Tiết kiệm' } }, // Savings
    ];

    const allocation = service.calculate50_30_20(expenses, 25000000);
    assert.strictEqual(allocation.needs_percent, 60); // 15tr / 25tr = 60%
    assert.strictEqual(allocation.wants_percent, 24); // 6tr / 25tr = 24%
    assert.strictEqual(allocation.savings_percent, 16); // 4tr / 25tr = 16%
  });

  it('3. Tính số tháng Quỹ khẩn cấp (Emergency Fund Months)', () => {
    const wallets = [
      { balance: 30000000, include_in_total: true },
      { balance: 10000000, include_in_total: true },
      { balance: 50000000, include_in_total: false }, // không tính ví này
    ];
    const avgMonthlyExpense = 20000000;

    const months = service.calculateEmergencyFundMonths(wallets, avgMonthlyExpense);
    // (30tr + 10tr) / 20tr = 2.0 tháng
    assert.strictEqual(months, 2.0);
  });

  it('4. Tính Điểm Sức khỏe Tài chính FHS (Thang điểm 100)', () => {
    const score = service.calculateFinancialHealthScore({
      savingsRatio: 0.16,      // 16% tích lũy
      emergencyFundMonths: 2.0,// 2 tháng quỹ khẩn cấp
      debtToIncomeRatio: 0.10, // nợ 10%
      budgetAdherence: 0.90,   // tuân thủ 90% ngân sách
    });

    assert.ok(score >= 0 && score <= 100, 'FHS phải nằm trong khoảng 0-100');
    assert.strictEqual(typeof score, 'number');
    assert.ok(score >= 60 && score <= 85, `Điểm FHS hợp lý, thực tế: ${score}`);
  });
});

describe('PIIMasker — Che Giấu Thông Tin Cá Nhân & Làm Mờ Dữ Liệu', () => {
  const masker = new PIIMasker();

  it('1. Che số tài khoản, số điện thoại, số thẻ và email trong ghi chú', () => {
    const text = 'Chuyển tiền STK 19034567890123 ngân hàng TCB hoặc gọi 0912345678, email test@gmail.com';
    const masked = masker.maskPII(text);

    assert.ok(!masked.includes('19034567890123'), 'Không được lộ STK');
    assert.ok(!masked.includes('0912345678'), 'Không được lộ SĐT');
    assert.ok(!masked.includes('test@gmail.com'), 'Không được lộ email');
    assert.ok(masked.includes('[STK]') || masked.includes('[SĐT]') || masked.includes('[EMAIL]'));
  });

  it('2. Làm mờ bản chụp Snapshot vĩ mô (Anonymize Snapshot)', () => {
    const rawData = {
      user_fullname: 'Nguyễn Văn A',
      phone: '0987654321',
      total_balance: 45000000,
      emergencyFundMonths: 2.1,
      healthScore: 75,
      topExpenseCategories: [
        { category: 'Ăn uống', amount: 5000000, percentage: 35 },
      ]
    };

    const sanitized = masker.anonymizeSnapshot(rawData);
    assert.strictEqual(sanitized.user_fullname, undefined, 'Phải xóa họ tên');
    assert.strictEqual(sanitized.phone, undefined, 'Phải xóa SĐT');
    assert.strictEqual(sanitized.financialHealthScore, 75);
    assert.strictEqual(sanitized.liquidityAndObligations.emergencyFundMonths, 2.1);
  });
});
