/**
 * On-Demand Financial Tools Executor
 * Thực thi các câu lệnh truy vấn CSDL Prisma scoped idaccount
 * Lọc PII trước khi trả về cho Gemini
 */

const { prisma } = require('../../../../../config/db');
const PIIMasker = require('../privacy/pii.masker');
const logger = require('../../../../../core/logger');

class ToolsExecutor {
  constructor() {
    this.piiMasker = new PIIMasker();
  }

  /**
   * Giả lập tiến độ tích lũy mục tiêu
   * @param {object} goal 
   * @param {number} monthlyContribution 
   * @returns {object}
   */
  simulateGoalProgress(goal, monthlyContribution) {
    if (!goal || !monthlyContribution || monthlyContribution <= 0) {
      return { remainingAmount: 0, monthsNeeded: 0 };
    }

    const target = Number(goal.target_amount || 0);
    const current = Number(goal.current_amount || 0);
    const remaining = Math.max(0, target - current);
    const months = remaining > 0 ? Math.ceil(remaining / monthlyContribution) : 0;

    return {
      goalName: goal.name,
      targetAmount: target,
      currentAmount: current,
      remainingAmount: remaining,
      monthlyContribution,
      monthsNeeded: months,
    };
  }

  /**
   * Tính chênh lệch chi tiêu giữa 2 kỳ
   * @param {number} period1Expenses 
   * @param {number} period2Expenses 
   * @returns {object}
   */
  calculatePeriodDifference(period1Expenses, period2Expenses) {
    const diff = period1Expenses - period2Expenses;
    let percentStr = '0%';
    if (period2Expenses > 0) {
      const pct = Math.round((diff / period2Expenses) * 100);
      percentStr = pct > 0 ? `+${pct}%` : `${pct}%`;
    } else if (period1Expenses > 0) {
      percentStr = '+100%';
    }

    return {
      period1Amount: period1Expenses,
      period2Amount: period2Expenses,
      difference: diff,
      percentageChange: percentStr,
      trend: diff > 0 ? 'increased' : (diff < 0 ? 'decreased' : 'stable'),
    };
  }

  /**
   * Lọc và làm mờ danh sách giao dịch
   * @param {Array<object>} txList 
   * @returns {Array<object>}
   */
  sanitizeTransactionList(txList) {
    if (!Array.isArray(txList)) return [];

    return txList.map(tx => ({
      id: tx.idtran,
      amount: Number(tx.amount || 0),
      category: tx.category?.name_category || tx.category?.namecategory || 'Khác',
      note: this.piiMasker.maskPII(tx.note || ''),
      date: tx.date_transaction || tx.date,
    }));
  }

  /**
   * Điều phối thực thi công cụ theo tên
   * @param {string} name 
   * @param {object} args 
   * @param {number} idaccount 
   * @returns {Promise<object>}
   */
  async executeTool(name, args = {}, idaccount) {
    logger.info(`[Chatbot Tool Exec] Name: ${name}, idaccount: ${idaccount}`);

    try {
      switch (name) {
        case 'get_category_transactions':
          return await this.getCategoryTransactions(args, idaccount);
        case 'compare_spending_periods':
          return await this.compareSpendingPeriods(args, idaccount);
        case 'get_bill_details':
          return await this.getBillDetails(args, idaccount);
        case 'get_goal_simulation':
          return await this.getGoalSimulation(args, idaccount);
        default:
          return { error: `Công cụ không xác định: ${name}` };
      }
    } catch (error) {
      logger.error(`Error executing tool ${name}:`, error);
      return { error: `Lỗi khi thực thi công cụ: ${error.message}` };
    }
  }

  /**
   * Lấy danh sách giao dịch theo danh mục
   */
  async getCategoryTransactions({ categoryName, limit = 5, sortBy = 'amount_desc' }, idaccount) {
    const take = Math.min(Math.max(1, Number(limit) || 5), 10);
    const orderBy = sortBy === 'date_desc' 
      ? { date_transaction: 'desc' } 
      : { amount: 'desc' };

    const transactions = await prisma.transaction.findMany({
      where: {
        idaccount,
        deleted_at: null,
        type: 'Transaction',
        category: {
          name_category: {
            contains: categoryName || '',
            mode: 'insensitive',
          },
        },
      },
      include: {
        category: { select: { name_category: true } },
      },
      orderBy,
      take,
    });

    return {
      category: categoryName,
      count: transactions.length,
      transactions: this.sanitizeTransactionList(transactions),
    };
  }

  /**
   * So sánh chi tiêu giữa hai khoảng thời gian
   */
  async compareSpendingPeriods({ categoryName, daysAgo1 = 30, daysAgo2 = 30 }, idaccount) {
    const now = new Date();
    const d1 = Number(daysAgo1) || 30;
    const d2 = Number(daysAgo2) || 30;

    const p1Start = new Date(now.getTime() - d1 * 24 * 60 * 60 * 1000);
    const p2Start = new Date(p1Start.getTime() - d2 * 24 * 60 * 60 * 1000);

    const whereBase = {
      idaccount,
      deleted_at: null,
      type: 'Transaction',
      category: { classify: 'Chi' },
    };

    if (categoryName) {
      whereBase.category = {
        classify: 'Chi',
        name_category: { contains: categoryName, mode: 'insensitive' },
      };
    }

    const txP1 = await prisma.transaction.findMany({
      where: {
        ...whereBase,
        date_transaction: { gte: p1Start, lte: now },
      },
      select: { amount: true },
    });

    const txP2 = await prisma.transaction.findMany({
      where: {
        ...whereBase,
        date_transaction: { gte: p2Start, lt: p1Start },
      },
      select: { amount: true },
    });

    const sumP1 = txP1.reduce((sum, t) => sum + Number(t.amount || 0), 0);
    const sumP2 = txP2.reduce((sum, t) => sum + Number(t.amount || 0), 0);

    return this.calculatePeriodDifference(sumP1, sumP2);
  }

  /**
   * Chi tiết các hóa đơn sắp đến hạn
   */
  async getBillDetails({ status = 'Pending', daysAhead = 14 }, idaccount) {
    const now = new Date();
    const ahead = Number(daysAhead) || 14;
    const maxDate = new Date(now.getTime() + ahead * 24 * 60 * 60 * 1000);

    const where = {
      idaccount,
      delete_at: null,
      due_date: { lte: maxDate, gte: now },
    };

    if (status !== 'All') {
      where.pay_status = { in: ['Pending', 'Unpaid'] };
    }

    const bills = await prisma.bill.findMany({
      where,
      include: {
        category: { select: { name_category: true } },
      },
      orderBy: { due_date: 'asc' },
      take: 10,
    });

    return {
      upcomingCount: bills.length,
      bills: bills.map(b => ({
        id: b.idbill,
        name: this.piiMasker.maskPII(b.name),
        amount: Number(b.amount || 0),
        dueDate: b.due_date,
        status: b.pay_status,
        category: b.category?.name_category || b.category?.namecategory || 'Khác',
      })),
    };
  }

  /**
   * Giả lập tiến độ tiết kiệm mục tiêu
   */
  async getGoalSimulation({ goalName, monthlyContribution }, idaccount) {
    const goal = await prisma.goal.findFirst({
      where: {
        idaccount,
        delete_at: null,
        name: { contains: goalName || '', mode: 'insensitive' },
      },
    });

    if (!goal) {
      return { error: `Không tìm thấy mục tiêu nào có tên tương tự "${goalName}"` };
    }

    return this.simulateGoalProgress(goal, Number(monthlyContribution) || 0);
  }
}

module.exports = ToolsExecutor;
