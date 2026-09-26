/**
 * PII Masker & Anonymizer Module
 * Tuân thủ Data_Security.md & Nghị định 13/2023/NĐ-CP
 */

const { maskTransactionDescription } = require('../../../../../utils/masking.util');

class PIIMasker {
  /**
   * Che giấu PII trong chuỗi văn bản (STK, SĐT, Email, Số thẻ)
   * @param {string} text 
   * @returns {string}
   */
  maskPII(text) {
    if (!text || typeof text !== 'string') return '';
    return maskTransactionDescription(text);
  }

  /**
   * Ẩn danh hóa toàn bộ bản chụp sức khỏe tài chính vĩ mô
   * Loại bỏ dữ liệu định danh (họ tên, sđt, email, tên tài khoản cụ thể)
   * @param {object} rawSnapshot 
   * @returns {object} Anonymized Financial Health Snapshot
   */
  anonymizeSnapshot(rawSnapshot) {
    if (!rawSnapshot || typeof rawSnapshot !== 'object') return {};

    return {
      period: rawSnapshot.period || 'Tháng hiện tại',
      financialHealthScore: rawSnapshot.healthScore || rawSnapshot.financialHealthScore || 0,
      budgetAllocation: rawSnapshot.budgetAllocation || {
        needs_essential: `${rawSnapshot.needs_percent || 0}%`,
        wants_lifestyle: `${rawSnapshot.wants_percent || 0}%`,
        savings_debt: `${rawSnapshot.savings_percent || 0}%`,
      },
      spendingInsights: {
        topExpenseCategories: Array.isArray(rawSnapshot.topExpenseCategories)
          ? rawSnapshot.topExpenseCategories.map(cat => ({
              category: this.maskPII(cat.category || cat.name || ''),
              percentage: Math.round(cat.percentage || 0),
              trendVsLastMonth: cat.trendVsLastMonth || '0%',
            }))
          : [],
        overBudgetAlerts: Array.isArray(rawSnapshot.overBudgetAlerts)
          ? rawSnapshot.overBudgetAlerts.map(alert => this.maskPII(alert))
          : [],
      },
      liquidityAndObligations: {
        emergencyFundMonths: Number(Number(rawSnapshot.emergencyFundMonths || 0).toFixed(1)),
        upcomingBillsIn7DaysCount: rawSnapshot.upcomingBillsIn7DaysCount || 0,
        hasHighInterestDebt: Boolean(rawSnapshot.hasHighInterestDebt),
        activeSavingsGoalsCount: rawSnapshot.activeSavingsGoalsCount || 0,
      },
    };
  }
}

module.exports = PIIMasker;
