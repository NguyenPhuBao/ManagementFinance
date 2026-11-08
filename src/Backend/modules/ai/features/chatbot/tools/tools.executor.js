/**
 * On-Demand Financial Tools Executor
 * Thực thi các câu lệnh truy vấn CSDL Prisma scoped idaccount
 * Lọc PII trước khi trả về cho LLM
 */

const { performance } = require('perf_hooks');
const { prisma } = require('../../../../../config/db');
const PIIMasker = require('../privacy/pii.masker');
const logger = require('../../../../../core/logger');
const { decrypt, isEncrypted } = require('../../../../../utils/crypto.util');
const { normalizeFlow } = require('./flow.normalizer');
const { KNOWLEDGE_TOOL_NAME } = require('./financial.tools');
const LexicalKnowledgeSearch = require('../rag/lexical.search');

const KNOWLEDGE_TOP_K = 3;
const TRUNCATED_MARK = '…[đã cắt bớt]';
const KNOWLEDGE_NOT_FOUND_NOTE = 'Kho kiến thức chưa có nội dung này. Nói rõ với người dùng; không tự nêu con số hay điều luật cụ thể.';

/**
 * Giải mã ghi chú mã hoá at-rest. Giải mã hỏng thì trả '' — tuyệt đối không để bản mã `enc:…` đi tiếp
 * (không có giá trị với LLM và vi phạm quy tắc không trả bản mã ra ngoài).
 */
function readNote(note, txId) {
  if (!note) return '';
  const text = String(note);
  if (!isEncrypted(text)) return text;
  try {
    const plain = decrypt(text, { table: 'transaction', id: txId });
    return plain && !isEncrypted(plain) ? plain : '';
  } catch (err) {
    logger.warn('[Chatbot Tools] Không giải mã được ghi chú giao dịch', { txId, code: err?.code });
    return '';
  }
}

class ToolsExecutor {
  constructor({ knowledgeSearch } = {}) {
    this.piiMasker = new PIIMasker();
    this.knowledgeSearch = knowledgeSearch || new LexicalKnowledgeSearch();
    /** Chẩn đoán lần tra gần nhất {method, chunkIds, timings} cho đo đạc NCKH; không gửi cho LLM. */
    this.lastRetrieval = null;
  }

  /**
   * Tra kho tri thức tĩnh. Vừa `maxResultChars` bằng cách bỏ nguyên đoạn xếp sau: cắt giữa đoạn có thể làm mất số liệu
   * và làm hỏng JSON mà mô hình đọc. Đoạn đứng đầu luôn được giữ.
   * Truy hồi lai (có `searchHybrid`) trả Promise; truy hồi từ vựng trả kết quả đồng bộ như bản đối chứng.
   */
  searchKnowledge({ query } = {}, opts = {}) {
    const ks = this.knowledgeSearch;
    if (typeof ks.searchHybrid === 'function') {
      return ks.searchHybrid(query, KNOWLEDGE_TOP_K).then((hits) => this._knowledgeResult(hits, opts, ks.lastTimings));
    }
    const t0 = performance.now();
    const hits = ks.search(query, KNOWLEDGE_TOP_K);
    const took = Math.round((performance.now() - t0) * 1000) / 1000;
    return this._knowledgeResult(hits, opts, { method: 'lexical', bm25Ms: took, totalMs: took });
  }

  _knowledgeResult(hits, { maxResultChars } = {}, timings = {}) {
    this.lastRetrieval = { method: timings?.method || 'lexical', chunkIds: hits.map((h) => h.chunkId), timings: timings || {} };
    if (hits.length === 0) return { found: false, results: [], note: KNOWLEDGE_NOT_FOUND_NOTE };

    const lengthOf = (items) => JSON.stringify({ found: true, results: items }).length;

    const results = [];
    for (const hit of hits) {
      const item = { chunkId: hit.chunkId, title: hit.title, citation: hit.attribution, content: hit.content };
      if (maxResultChars && lengthOf([...results, item]) > maxResultChars) {
        if (results.length > 0) break;
        // Đoạn đầu tự nó dài hơn trần: rút ngắn nội dung tại đây để JSON vẫn đọc được, không để tầng trên cắt giữa JSON.
        const room = Math.max(0, maxResultChars - lengthOf([{ ...item, content: TRUNCATED_MARK }]));
        item.content = `${item.content.slice(0, room)}${TRUNCATED_MARK}`;
      }
      results.push(item);
    }
    return { found: true, results };
  }

  /**
   * Giả lập tiến độ tích lũy mục tiêu. Thiếu số tiền đóng góp thì chưa tính được số tháng: trả `null` kèm ghi chú, tuyệt
   * đối không trả 0 vì mô hình sẽ hiểu là mục tiêu đã xong.
   * @param {object} goal
   * @param {number} monthlyContribution
   * @param {string} [userName]
   * @returns {object}
   */
  simulateGoalProgress(goal, monthlyContribution, userName) {
    if (!goal) return { error: 'Không có mục tiêu để giả lập' };

    const target = Number(goal.target_amount || 0);
    const current = Number(goal.current_amount || 0);
    const remaining = Math.max(0, target - current);
    const monthly = Number(monthlyContribution);
    const hasMonthly = Number.isFinite(monthly) && monthly > 0;

    let monthsNeeded = 0;
    if (remaining > 0) monthsNeeded = hasMonthly ? Math.ceil(remaining / monthly) : null;

    return {
      goalName: this.piiMasker.maskPII(goal.name, { userName }),
      targetAmount: target,
      currentAmount: current,
      remainingAmount: remaining,
      monthlyContribution: hasMonthly ? monthly : null,
      monthsNeeded,
      ...(monthsNeeded === null ? { note: 'Chưa biết số tiền đóng góp mỗi tháng nên chưa tính được số tháng; hãy hỏi người dùng.' } : {}),
    };
  }

  /**
   * Tính chênh lệch chi tiêu giữa 2 kỳ
   * @param {number} period1Expenses
   * @param {number} period2Expenses
   * @returns {object}
   */
  calculatePeriodDifference(period1Expenses, period2Expenses) {
    const p1 = Math.abs(Number(period1Expenses || 0));
    const p2 = Math.abs(Number(period2Expenses || 0));
    const diff = p1 - p2;
    let percentStr = '0%';
    if (p2 > 0) {
      const pct = Math.round((diff / p2) * 100);
      percentStr = pct > 0 ? `+${pct}%` : `${pct}%`;
    } else if (p1 > 0) {
      percentStr = '+100%';
    }

    return {
      period1Amount: p1,
      period2Amount: p2,
      difference: diff,
      percentageChange: percentStr,
      trend: diff > 0 ? 'increased' : (diff < 0 ? 'decreased' : 'stable'),
    };
  }

  /**
   * Lọc và làm mờ danh sách giao dịch
   * @param {Array<object>} txList
   * @param {string} [userName]
   * @returns {Array<object>}
   */
  sanitizeTransactionList(txList, userName) {
    if (!Array.isArray(txList)) return [];

    return txList.map(tx => {
      const { direction, amount } = normalizeFlow({
        amount: tx.amount,
        type: tx.type,
        classify: tx.category?.classify,
      });
      return {
        id: tx.idtran,
        direction,
        amount,
        category: this.piiMasker.maskPII(tx.category?.name_category || tx.category?.namecategory || 'Khác', { userName }),
        note: this.piiMasker.maskPII(readNote(tx.note, tx.idtran), { userName }),
        date: tx.date_transaction || tx.date,
      };
    });
  }

  /**
   * Điều phối thực thi công cụ theo tên
   * @param {string} name
   * @param {object} args
   * @param {number} idaccount
   * @returns {Promise<object>}
   */
  async executeTool(name, args = {}, idaccount, options = {}) {
    logger.info(`[Chatbot Tool Exec] Name: ${name}, idaccount: ${idaccount}`);

    try {
      switch (name) {
        case KNOWLEDGE_TOOL_NAME:
          return await this.searchKnowledge(args, options);
        case 'get_category_transactions':
          return await this.getCategoryTransactions(args, idaccount, options.userName);
        case 'compare_spending_periods':
          return await this.compareSpendingPeriods(args, idaccount);
        case 'get_bill_details':
          return await this.getBillDetails(args, idaccount, options.userName);
        case 'get_goal_simulation':
          return await this.getGoalSimulation(args, idaccount, options.userName);
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
  async getCategoryTransactions({ categoryName, limit = 5, sortBy = 'amount_desc' }, idaccount, userName) {
    const take = Math.min(Math.max(1, Number(limit) || 5), 10);
    // `amount` mang dấu (chi là số ÂM): khoản chi lớn nhất = số âm nhất = sắp TĂNG theo amount.
    const orderBy = sortBy === 'date_desc'
      ? { date_transaction: 'desc' }
      : { amount: 'asc' };

    const transactions = await prisma.transaction.findMany({
      where: {
        idaccount,
        deleted_at: null,
        type: 'Transaction',
        amount: { lt: 0 },
        category: {
          classify: 'Chi',
          name_category: {
            contains: categoryName || '',
            mode: 'insensitive',
          },
        },
      },
      include: {
        category: { select: { name_category: true, classify: true } },
      },
      orderBy,
      take,
    });

    return {
      category: categoryName,
      count: transactions.length,
      transactions: this.sanitizeTransactionList(transactions, userName),
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

    const whereBase = { idaccount, deleted_at: null, type: 'Transaction' };

    if (categoryName) {
      whereBase.category = {
        classify: 'Chi',
        name_category: { contains: categoryName, mode: 'insensitive' },
      };
    } else {
      // Khoản tiền ra không có danh mục vẫn là chi tiêu, bỏ qua sẽ làm tổng chi thấp hơn thực tế.
      whereBase.OR = [{ category: { classify: 'Chi' } }, { idcategory: null, amount: { lt: 0 } }];
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

    const sumP1 = txP1.reduce((sum, t) => sum + Math.abs(Number(t.amount || 0)), 0);
    const sumP2 = txP2.reduce((sum, t) => sum + Math.abs(Number(t.amount || 0)), 0);

    return this.calculatePeriodDifference(sumP1, sumP2);
  }

  /**
   * Chi tiết các hóa đơn sắp đến hạn
   */
  async getBillDetails({ status = 'Pending', daysAhead = 14 }, idaccount, userName) {
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
        name: this.piiMasker.maskPII(b.name, { userName }),
        amount: Number(b.amount || 0),
        dueDate: b.due_date,
        status: b.pay_status,
        category: this.piiMasker.maskPII(b.category?.name_category || b.category?.namecategory || 'Khác', { userName }),
      })),
    };
  }

  /**
   * Giả lập tiến độ tiết kiệm mục tiêu
   */
  async getGoalSimulation({ goalName, monthlyContribution }, idaccount, userName) {
    if (typeof goalName !== 'string' || !goalName.trim()) {
      return { error: 'Cần tên mục tiêu; hãy hỏi người dùng muốn xem mục tiêu nào.' };
    }

    const goal = await prisma.goal.findFirst({
      where: {
        idaccount,
        delete_at: null,
        name: { contains: goalName.trim(), mode: 'insensitive' },
      },
    });

    if (!goal) {
      return { error: `Không tìm thấy mục tiêu nào có tên tương tự "${goalName}"` };
    }

    return this.simulateGoalProgress(goal, monthlyContribution, userName);
  }
}

module.exports = ToolsExecutor;
