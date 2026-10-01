/**
 * Financial Snapshot Service
 * Tính toán Bản chụp Sức khỏe Tài chính Vĩ mô (Chức năng 7 Lối A: Backend tự tính)
 * Phục vụ làm Context nạp vào Gemini Chatbot AI và hiển thị Dashboard Sức khỏe Tài chính
 */

const { prisma } = require('../../../../../config/db');
const { redis } = require('../../../../../config/redis');
const PIIMasker = require('../privacy/pii.masker');
const logger = require('../../../../../core/logger');

const SNAPSHOT_CACHE_TTL_SECONDS = 120; // TTL 120s (2 phút)

class FinancialSnapshotService {
  constructor() {
    this.piiMasker = new PIIMasker();
  }

  /**
   * Xóa bộ nhớ đệm Snapshot khi có phát sinh giao dịch mới
   * @param {number} idaccount 
   */
  async invalidateSnapshotCache(idaccount) {
    if (!idaccount) return;
    try {
      if (redis && redis.status === 'ready') {
        await redis.del(`cache:snapshot:${idaccount}`);
        logger.info(`[SnapshotCache] INVALIDATED for idaccount ${idaccount}`);
      }
    } catch (err) {
      logger.warn(`[SnapshotCache] Failed to invalidate cache: ${err.message}`);
    }
  }

  /**
   * Tính toán thu nhập hợp lệ từ danh sách giao dịch
   * Loại trừ các khoản: Đi vay, Thu nợ, Chuyển ví nội bộ (Transfer)
   * Chuẩn hóa theo nghiệp vụ thuNhapCua
   * @param {Array<object>} transactions 
   * @returns {number}
   */
  calculateValidIncome(transactions) {
    if (!Array.isArray(transactions) || transactions.length === 0) return 0;

    const excludedKeywords = ['vay', 'nợ', 'mượn', 'thu nợ', 'đi vay', 'vay nợ'];

    let total = 0;
    for (const tx of transactions) {
      // 1. Loại bỏ chuyển tiền nội bộ
      if (tx.type === 'Transfer' || tx.idwallet_transfer) continue;

      // 2. Chỉ xét loại Thu
      const isIncome = tx.category?.classify === 'Thu' || tx.type === 'Thu';
      if (!isIncome) continue;

      // 3. Loại trừ các khoản mang tính chất vay/nợ
      const catName = (tx.category?.name_category || tx.category?.namecategory || '').toLowerCase();
      const isDebtRelated = excludedKeywords.some(kw => catName.includes(kw));
      if (isDebtRelated) continue;

      total += Number(tx.amount || 0);
    }

    return total;
  }

  /**
   * Phân bổ chi tiêu theo cơ cấu 50/30/20 (Needs / Wants / Savings)
   * @param {Array<object>} expenses 
   * @param {number} totalIncome 
   * @returns {{ needs_percent: number, wants_percent: number, savings_percent: number }}
   */
  calculate50_30_20(expenses, totalIncome = 0) {
    if (!Array.isArray(expenses) || expenses.length === 0) {
      return { needs_percent: 0, wants_percent: 0, savings_percent: 0 };
    }

    const needsKeywords = [
      'ăn uống', 'thuê nhà', 'nhà cửa', 'tiện ích', 'đi lại', 'di chuyển', 'giao thông', 'xăng', 'hóa đơn',
      'y tế', 'thuốc', 'học phí', 'giáo dục', 'chợ', 'siêu thị', 'điện', 'nước', 'internet'
    ];

    const savingsKeywords = [
      'tiết kiệm', 'đầu tư', 'tích lũy', 'trả nợ', 'bảo hiểm', 'gửi tiết kiệm', 'đi vay', 'cho vay', 'vay', 'nợ'
    ];

    let needsAmount = 0;
    let savingsAmount = 0;
    let wantsAmount = 0;

    for (const item of expenses) {
      const amount = Math.abs(Number(item.amount || 0));
      const catName = (item.category?.name_category || item.category?.namecategory || '').toLowerCase();

      if (savingsKeywords.some(kw => catName.includes(kw))) {
        savingsAmount += amount;
      } else if (needsKeywords.some(kw => catName.includes(kw))) {
        needsAmount += amount;
      } else {
        wantsAmount += amount;
      }
    }

    const baseAmount = totalIncome > 0 ? totalIncome : (needsAmount + wantsAmount + savingsAmount);
    if (baseAmount <= 0) {
      return { needs_percent: 0, wants_percent: 0, savings_percent: 0 };
    }

    return {
      needs_percent: Math.round((needsAmount / baseAmount) * 100),
      wants_percent: Math.round((wantsAmount / baseAmount) * 100),
      savings_percent: Math.round((savingsAmount / baseAmount) * 100),
    };
  }

  /**
   * Tính toán mẫu số ngày động (Dynamic Days Span) theo ngày giao dịch sớm nhất
   * [max(now - 90d, firstTxDate), now), tối thiểu 14 ngày, tối đa 90 ngày
   * @param {Date} now
   * @param {Date} ninetyDaysAgo
   * @param {Date} firstTxDate
   * @returns {number}
   */
  calculateDynamicDaysSpan(now, ninetyDaysAgo, firstTxDate) {
    const effectiveStart = firstTxDate
      ? new Date(Math.max(ninetyDaysAgo.getTime(), new Date(firstTxDate).getTime()))
      : ninetyDaysAgo;
    const diffMs = now.getTime() - effectiveStart.getTime();
    const days = Math.round(diffMs / (1000 * 60 * 60 * 24));
    return Math.min(90, Math.max(14, days));
  }

  /**
   * Tính số tháng Quỹ khẩn cấp có thể duy trì (Emergency Fund Months)
   * @param {Array<object>} wallets 
   * @param {number} avgMonthlyExpense 
   * @returns {number}
   */
  calculateEmergencyFundMonths(wallets, avgMonthlyExpense) {
    if (!Array.isArray(wallets) || avgMonthlyExpense <= 0) return 0;

    const liquidBalance = wallets
      .filter(w => w.include_in_total !== false && w.status !== 'Inactive')
      .reduce((sum, w) => sum + Number(w.balance || 0), 0);

    return Number((liquidBalance / avgMonthlyExpense).toFixed(1));
  }

  /**
   * Tính Tỷ lệ Nợ trên Thu nhập (Debt-to-Income Ratio) từ chi tiêu thực tế
   * @param {Array<object>} expenses 
   * @param {number} totalIncome 
   * @returns {number}
   */
  calculateDebtToIncomeRatio(expenses, totalIncome = 0) {
    if (!Array.isArray(expenses) || expenses.length === 0 || totalIncome <= 0) {
      return 0;
    }

    const debtKeywords = ['trả nợ', 'nợ', 'vay', 'lãi', 'tiền lãi', 'trả góp'];
    const totalDebt = expenses.reduce((sum, item) => {
      const catName = (item.category?.name_category || item.category?.namecategory || '').toLowerCase();
      if (debtKeywords.some(kw => catName.includes(kw))) {
        return sum + Math.abs(Number(item.amount || 0));
      }
      return sum;
    }, 0);

    return Math.min(1, Number((totalDebt / totalIncome).toFixed(2)));
  }

  /**
   * Tính Điểm Sức khỏe Tài chính FHS (Financial Health Score, thang 100)
   * @param {object} params
   * @returns {number}
   */
  calculateFinancialHealthScore({
    savingsRatio = 0,
    emergencyFundMonths = 0,
    debtToIncomeRatio = 0,
    budgetAdherence = 1,
  }) {
    let score = 0;

    // 1. Tỷ lệ tiết kiệm (25 điểm) - chuẩn 20%
    if (savingsRatio >= 0.20) score += 25;
    else if (savingsRatio >= 0.10) score += 18;
    else if (savingsRatio > 0) score += 10;
    else score += 2;

    // 2. Quỹ khẩn cấp (25 điểm) - chuẩn 3-6 tháng
    if (emergencyFundMonths >= 6) score += 25;
    else if (emergencyFundMonths >= 3) score += 20;
    else if (emergencyFundMonths >= 1) score += 14;
    else if (emergencyFundMonths > 0) score += 8;
    else score += 2;

    // 3. Tỷ lệ nợ / thu nhập (25 điểm)
    if (debtToIncomeRatio === 0) score += 25;
    else if (debtToIncomeRatio <= 0.15) score += 20;
    else if (debtToIncomeRatio <= 0.35) score += 15;
    else if (debtToIncomeRatio <= 0.50) score += 8;
    else score += 2;

    // 4. Tuân thủ ngân sách (25 điểm)
    if (budgetAdherence >= 0.90) score += 25;
    else if (budgetAdherence >= 0.75) score += 18;
    else if (budgetAdherence >= 0.50) score += 10;
    else score += 4;

    return Math.min(100, Math.max(0, Math.round(score)));
  }

  /**
   * Sinh Bản chụp Sức khỏe Tài chính Ẩn danh hoàn chỉnh từ CSDL PostgreSQL (Scoped idaccount)
   * Có lưu đệm Redis TTL 120s
   * @param {number} idaccount 
   * @param {object} options
   * @param {boolean} options.bypassCache
   * @returns {Promise<object>}
   */
  async generateSnapshot(idaccount, { bypassCache = false } = {}) {
    const cacheKey = `cache:snapshot:${idaccount}`;

    // 1. Kiểm tra Cache Redis nếu không bypass
    if (!bypassCache && redis && redis.status === 'ready') {
      try {
        const cached = await redis.get(cacheKey);
        if (cached) {
          logger.info(`[SnapshotCache] HIT for idaccount ${idaccount}`);
          return JSON.parse(cached);
        }
      } catch (err) {
        logger.warn(`[SnapshotCache] Error reading cache: ${err.message}`);
      }
    }

    try {
      const now = new Date();
      const ninetyDaysAgo = new Date();
      ninetyDaysAgo.setDate(now.getDate() - 90);

      // 1. Lấy giao dịch trong cửa sổ cuộn 90 ngày
      const transactions = await prisma.transaction.findMany({
        where: {
          idaccount,
          deleted_at: null,
          date_transaction: { gte: ninetyDaysAgo },
        },
        include: {
          category: { select: { name_category: true, classify: true } },
        },
        orderBy: { date_transaction: 'desc' },
      });

      // 2. Lấy danh sách ví
      const wallets = await prisma.wallet.findMany({
        where: { idaccount, delete_at: null },
      });

      // 3. Lấy ngân sách còn hiệu lực tại thời điểm hiện tại
      const budgets = await prisma.budget.findMany({
        where: {
          idaccount,
          delete_at: null,
          start: { lte: now },
          OR: [
            { end: null },
            { end: { gte: now } },
          ],
        },
        include: { category: { select: { name_category: true } } },
      });

      // 4. Lấy hóa đơn sắp tới trong 7 ngày
      const sevenDaysLater = new Date();
      sevenDaysLater.setDate(now.getDate() + 7);

      const upcomingBills = await prisma.bill.findMany({
        where: {
          idaccount,
          delete_at: null,
          pay_status: { in: ['Pending', 'Unpaid'] },
          due_date: { lte: sevenDaysLater, gte: now },
        },
      });

      // 5. Lấy mục tiêu tích lũy đang chạy
      const activeGoalsCount = await prisma.goal.count({
        where: {
          idaccount,
          delete_at: null,
          status_complete: 'False',
        },
      });

      // Phân tách chi tiêu
      // allExpenses: Chi + Vay/no — dùng cho DTI và 50/30/20 (đúng với nghiệp vụ CSDL)
      // regularExpenses: chỉ Chi — dùng cho topExpenseCategories và avgMonthlyExpense
      const allExpenses = transactions.filter(
        t => t.type !== 'Transfer' &&
             (t.category?.classify === 'Chi' || t.category?.classify === 'Vay/no')
      );
      const regularExpenses = allExpenses.filter(t => t.category?.classify === 'Chi');

      const totalIncome = this.calculateValidIncome(transactions);
      const totalExpense = regularExpenses.reduce((sum, t) => sum + Math.abs(Number(t.amount || 0)), 0);

      // Chi tiêu trung bình tháng theo mẫu số động (Dynamic Days Span)
      const oldestTx = await prisma.transaction.findFirst({
        where: { idaccount, deleted_at: null },
        orderBy: { date_transaction: 'asc' },
        select: { date_transaction: true },
      });
      const firstTxDate = oldestTx?.date_transaction ? new Date(oldestTx.date_transaction) : ninetyDaysAgo;
      const daysSpan = this.calculateDynamicDaysSpan(now, ninetyDaysAgo, firstTxDate);
      const avgMonthlyExpense = totalExpense > 0 ? (totalExpense / daysSpan) * 30 : 0;

      // Phân bổ 50/30/20 — dùng allExpenses để khoản Vay/no được xét vào savings
      const allocation = this.calculate50_30_20(allExpenses, totalIncome);

      // Quỹ khẩn cấp
      const emergencyMonths = this.calculateEmergencyFundMonths(wallets, avgMonthlyExpense);

      // Nhóm chi tiêu theo kỳ 30 ngày để tính trendVsLastMonth thực tế
      // Dữ liệu 90 ngày đã load — không cần truy vấn thêm DB
      const thirtyDaysAgo = new Date(now);
      thirtyDaysAgo.setDate(now.getDate() - 30);
      const sixtyDaysAgo = new Date(now);
      sixtyDaysAgo.setDate(now.getDate() - 60);

      const currentByCategory = {};
      const lastByCategory = {};
      for (const exp of regularExpenses) {
        const catName = exp.category?.name_category || exp.category?.namecategory || 'Khác';
        const txDate = new Date(exp.date_transaction);
        const amount = Math.abs(Number(exp.amount || 0));
        if (txDate >= thirtyDaysAgo) {
          currentByCategory[catName] = (currentByCategory[catName] || 0) + amount;
        } else if (txDate >= sixtyDaysAgo) {
          lastByCategory[catName] = (lastByCategory[catName] || 0) + amount;
        }
      }

      // Top 3 danh mục chi tiêu lớn nhất (chỉ dùng regularExpenses — không lẫn khoản vay)
      const categoryMap = {};
      for (const exp of regularExpenses) {
        const catName = exp.category?.name_category || exp.category?.namecategory || 'Khác';
        categoryMap[catName] = (categoryMap[catName] || 0) + Math.abs(Number(exp.amount || 0));
      }
      const topExpenseCategories = Object.entries(categoryMap)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([name, amount]) => {
          const last = lastByCategory[name] || 0;
          const curr = currentByCategory[name] || 0;
          let trendVsLastMonth = '0%';
          if (last > 0) {
            const pct = Math.round(((curr - last) / last) * 100);
            trendVsLastMonth = pct >= 0 ? `+${pct}%` : `${pct}%`;
          } else if (curr > 0) {
            trendVsLastMonth = '+100%'; // tháng trước không có khoản này
          }
          return {
            category: name,
            percentage: totalExpense > 0 ? Math.round((amount / totalExpense) * 100) : 0,
            trendVsLastMonth,
          };
        });

      // Cảnh báo ngân sách (chỉ tối đa 1 cảnh báo cho mỗi danh mục)
      const overBudgetAlerts = [];
      const alertedCategories = new Set();
      for (const b of budgets) {
        const spent = Number(b.spent || 0);
        const total = Number(b.total_amount || 0);
        const catName = b.category?.name_category || b.category?.namecategory || 'Ngân sách chung';
        if (total > 0 && spent >= total * 0.9 && !alertedCategories.has(catName)) {
          alertedCategories.add(catName);
          const percent = Math.round((spent / total) * 100);
          overBudgetAlerts.push(`${catName} đã chạm ${percent}% hạn mức`);
        }
      }

      // Điểm sức khỏe tài chính
      const savingsRatio = totalIncome > 0 ? (allocation.savings_percent / 100) : 0;
      // allExpenses (Chi + Vay/no) → DTI đúng với thực tế CSDL
      const debtRatio = this.calculateDebtToIncomeRatio(allExpenses, totalIncome);
      const budgetAdherence = overBudgetAlerts.length === 0 ? 0.95 : 0.70;
      const healthScore = this.calculateFinancialHealthScore({
        savingsRatio,
        emergencyFundMonths: emergencyMonths,
        debtToIncomeRatio: debtRatio,
        budgetAdherence,
      });

      const rawSnapshot = {
        period: `Tháng ${now.getMonth() + 1}/${now.getFullYear()}`,
        healthScore,
        needs_percent: allocation.needs_percent,
        wants_percent: allocation.wants_percent,
        savings_percent: allocation.savings_percent,
        topExpenseCategories,
        overBudgetAlerts,
        emergencyFundMonths: emergencyMonths,
        upcomingBillsIn7DaysCount: upcomingBills.length,
        debtToIncomeRatio: debtRatio,
        activeSavingsGoalsCount: activeGoalsCount,
      };

      // Ẩn danh hóa 100% trước khi trả về
      const sanitizedSnapshot = this.piiMasker.anonymizeSnapshot(rawSnapshot);

      // Lưu Cache Redis với TTL 120s
      if (redis && redis.status === 'ready') {
        try {
          await redis.set(cacheKey, JSON.stringify(sanitizedSnapshot), 'EX', SNAPSHOT_CACHE_TTL_SECONDS);
          logger.info(`[SnapshotCache] SET for idaccount ${idaccount} TTL ${SNAPSHOT_CACHE_TTL_SECONDS}s`);
        } catch (err) {
          logger.warn(`[SnapshotCache] Error setting cache: ${err.message}`);
        }
      }

      return sanitizedSnapshot;
    } catch (error) {
      logger.error('[FinancialSnapshot] Không thể sinh snapshot thật do lỗi CSDL:', error);
      return null;
    }
  }
}

module.exports = FinancialSnapshotService;
