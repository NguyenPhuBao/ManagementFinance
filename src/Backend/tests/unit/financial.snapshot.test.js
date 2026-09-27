/**
 * Unit Test — Financial Snapshot Service & PII Masker (TDD Phase 1)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const FinancialSnapshotService = require('../../modules/ai/features/chatbot/snapshot/financial.snapshot.service');
const PIIMasker = require('../../modules/ai/features/chatbot/privacy/pii.masker');
const ToolsExecutor = require('../../modules/ai/features/chatbot/tools/tools.executor');

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

  it('2b. Phân bổ cơ cấu 50/30/20 khi khoản chi lưu số ÂM trong CSDL PostgreSQL', () => {
    // Trong PostgreSQL, giao dịch Chi lưu số âm (ví dụ: -10tr, -5tr)
    const negativeExpenses = [
      { amount: -10000000, category: { namecategory: 'Thuê nhà' } }, // Needs
      { amount: -5000000, category: { namecategory: 'Ăn uống' } },   // Needs
      { amount: -6000000, category: { namecategory: 'Mua sắm' } },   // Wants
      { amount: -4000000, category: { namecategory: 'Tiết kiệm' } }, // Savings
    ];

    const allocation = service.calculate50_30_20(negativeExpenses, 25000000);
    // Tỷ lệ % phải là số dương chuẩn xác
    assert.strictEqual(allocation.needs_percent, 60);
    assert.strictEqual(allocation.wants_percent, 24);
    assert.strictEqual(allocation.savings_percent, 16);
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

  it('5. Tính toán mẫu số ngày động (Dynamic Days Span) theo ngày giao dịch đầu tiên', () => {
    const now = new Date('2026-09-27T08:00:00Z');
    const ninetyDaysAgo = new Date('2026-06-29T08:00:00Z');

    // Trường hợp 1: Tài khoản mới 20 ngày tuổi (giao dịch đầu tiên cách 20 ngày)
    const firstTx20Days = new Date('2026-09-07T08:00:00Z');
    const days20 = service.calculateDynamicDaysSpan(now, ninetyDaysAgo, firstTx20Days);
    assert.strictEqual(days20, 20);

    // Trường hợp 2: Tài khoản rất mới (7 ngày tuổi) -> tối thiểu 14 ngày
    const firstTx7Days = new Date('2026-09-20T08:00:00Z');
    const days14 = service.calculateDynamicDaysSpan(now, ninetyDaysAgo, firstTx7Days);
    assert.strictEqual(days14, 14);

    // Trường hợp 3: Tài khoản lâu năm (> 90 ngày) -> tối đa 90 ngày
    const firstTx180Days = new Date('2026-03-01T08:00:00Z');
    const days90 = service.calculateDynamicDaysSpan(now, ninetyDaysAgo, firstTx180Days);
    assert.strictEqual(days90, 90);
  });

  it('6. Tính tỷ lệ Nợ trên Thu nhập (Debt-to-Income Ratio) từ các khoản chi trả nợ thực tế', () => {
    const expenses = [
      { amount: -5000000, category: { namecategory: 'Ăn uống' } },
      { amount: -3000000, category: { namecategory: 'Trả nợ ngân hàng' } },
      { amount: -2000000, category: { namecategory: 'Trả góp xe' } },
    ];
    const totalIncome = 25000000;

    const dti = service.calculateDebtToIncomeRatio(expenses, totalIncome);
    // (3tr + 2tr) / 25tr = 0.20
    assert.strictEqual(dti, 0.20);

    // Khi không có khoản chi nợ nào
    const noDebtExpenses = [{ amount: -5000000, category: { namecategory: 'Ăn uống' } }];
    assert.strictEqual(service.calculateDebtToIncomeRatio(noDebtExpenses, totalIncome), 0);

    // Khi thu nhập bằng 0
    assert.strictEqual(service.calculateDebtToIncomeRatio(expenses, 0), 0);
  });

  it('7. Phân bổ 50/30/20 nhận diện danh mục Di chuyển là Needs và xếp danh mục không khớp vào Wants', () => {
    const expenses = [
      { amount: -5000000, category: { namecategory: 'Ăn uống' } },   // Needs (5tr)
      { amount: -3000000, category: { namecategory: 'Di chuyển' } }, // Needs (3tr)
      { amount: -2000000, category: { namecategory: 'Chi khác' } },  // Wants (2tr)
    ];

    // Trường hợp 1: Không có thu nhập (mẫu số = tổng chi 10tr)
    const alloc = service.calculate50_30_20(expenses, 0);
    assert.strictEqual(alloc.needs_percent, 80); // (5tr + 3tr) / 10tr = 80%
    assert.strictEqual(alloc.wants_percent, 20); // 2tr / 10tr = 20%
    assert.strictEqual(alloc.savings_percent, 0);
    assert.strictEqual(alloc.needs_percent + alloc.wants_percent + alloc.savings_percent, 100);

    // Trường hợp 2: Có thu nhập 20 triệu
    const allocWithIncome = service.calculate50_30_20(expenses, 20000000);
    assert.strictEqual(allocWithIncome.needs_percent, 40); // 8tr / 20tr = 40%
    assert.strictEqual(allocWithIncome.wants_percent, 10); // 2tr / 20tr = 10%
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

  it('3. Che số điện thoại có dấu cách hoặc dấu gạch ngang (VD: 0912 345 678, 0987-654-321)', () => {
    const text = 'Liên hệ anh Ba qua số 0912 345 678 hoặc hotline 0987-654-321 nha';
    const masked = masker.maskPII(text);
    assert.ok(!masked.includes('0912 345 678'), 'Không được lộ số điện thoại có khoảng trắng');
    assert.ok(!masked.includes('0987-654-321'), 'Không được lộ số điện thoại có gạch ngang');
    assert.ok(masked.includes('[SĐT]'));
  });

  it('4. Che số CMND/CCCD (12 chữ số) và mã OTP/CVV', () => {
    const text = 'Số CCCD của tôi là 079201004567, mã OTP xác thực là 839201, vui lòng không chia sẻ';
    const masked = masker.maskPII(text);
    assert.ok(!masked.includes('079201004567'), 'Không được lộ CCCD 12 số');
    assert.ok(!masked.includes('839201'), 'Không được lộ mã OTP');
    assert.ok(masked.includes('[CCCD]') || masked.includes('[STK]') || masked.includes('[MÃ_BẢO_MẬT]'));
  });

  it('5. Che họ tên người dùng khi cung cấp userName trong ngữ cảnh', () => {
    const text = 'Khoản tiền thưởng dự án gửi cho Nguyễn Phú Bảo tháng này';
    const masked = masker.maskPII(text, { userName: 'Nguyễn Phú Bảo' });
    assert.ok(!masked.includes('Nguyễn Phú Bảo'), 'Không được lộ tên đầy đủ người dùng');
    assert.ok(masked.includes('[TÊN_NGƯỜI_DÙNG]'));
  });
});

describe('ToolsExecutor — Công Cụ Truy Vấn Tài Chính Bổ Sung', () => {
  const tools = new ToolsExecutor();

  it('1. So sánh chi tiêu 2 kỳ với số âm CSDL PostgreSQL', () => {
    // Kỳ 1: -5,000,000, Kỳ 2: -4,000,000 (chi tiêu tăng 1,000,000)
    const result = tools.calculatePeriodDifference(-5000000, -4000000);
    assert.strictEqual(result.period1Amount, 5000000);
    assert.strictEqual(result.period2Amount, 4000000);
    assert.strictEqual(result.difference, 1000000);
    assert.strictEqual(result.trend, 'increased');
    assert.strictEqual(result.percentageChange, '+25%');
  });

  it('2. So sánh chi tiêu khi chi tiêu giảm với số âm CSDL', () => {
    // Kỳ 1: -3,000,000, Kỳ 2: -4,000,000 (chi tiêu giảm 1,000,000)
    const result = tools.calculatePeriodDifference(-3000000, -4000000);
    assert.strictEqual(result.period1Amount, 3000000);
    assert.strictEqual(result.period2Amount, 4000000);
    assert.strictEqual(result.difference, -1000000);
    assert.strictEqual(result.trend, 'decreased');
    assert.strictEqual(result.percentageChange, '-25%');
  });
});

