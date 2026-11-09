/**
 * Middleware hạn mức lời nhắc Chatbot AI theo ngày.
 *
 * Hạn mức lấy từ ma trận quyền (`account_type_permission.scope_config.daily_prompts` của tính năng
 * `ai_assistant`). Ma trận để `null` (không giới hạn) KHÔNG có nghĩa là mở toang cho chatbot: khi đó dùng
 * mặc định của hệ thống (`AI_DAILY_PROMPTS_DEFAULT`). Quản trị viên không bị tính.
 *
 * Vượt hạn mức → 429 `AI_DAILY_LIMIT`. Client-app coi mọi trạng thái khác 200 là lỗi máy chủ và rơi về AI trên
 * máy, nên người dùng vẫn được trả lời (miễn phí cho hệ thống). Lỗi nội bộ → 503, không mở toang.
 * Lượt cho qua mang `req.aiQuotaRefund`: controller gọi khi lỗi do hệ thống để trả lại lượt (không hoàn khi người
 * dùng tự huỷ).
 */

const { getChatbotLimits } = require('./chatbot.limits');
const { UsageQuota } = require('./usage-quota');
const { UsageBudget } = require('./usage-budget');
const { computeTurnCapMicroUsd } = require('./turn-cap');
const { checkScope } = require('../scope/scope-guard');
const logger = require('../../../../../core/logger');

const FEATURE_ID = 'ai_assistant';

function isAdmin(user) {
  return user?.idrole === 1 || String(user?.rolename || '').toLowerCase() === 'admin';
}

function createDailyQuotaMiddleware({ quota, budget = null, permissionRepository, getLimits = getChatbotLimits }) {
  return async function dailyQuotaMiddleware(req, res, next) {
    try {
      if (isAdmin(req.user)) return next();

      // Câu tiêm lệnh bị chặn thẳng, không gọi LLM (xem controller): không tốn gì nên không trừ lượt. Câu bộ lọc chặn vì
      // lạc đề thì phải hỏi AI xác nhận (có tốn tiền) nên vẫn qua kiểm ngân sách và giữ chỗ một lượt; controller trả lại
      // lượt khi AI xác nhận KHÔNG thuộc phạm vi (PO duyệt 2026-11-09).
      if (req.body?.message && checkScope(req.body.message).code === 'INJECTION') return next();

      // Ngân sách chi phí tháng (tiền thật từ `usage`): trần cứng của thiệt hại theo người dùng. Kiểm TRƯỚC hạn mức
      // ngày để yêu cầu bị chặn vì hết ngân sách không bị tính thêm một lượt.
      let spent = null;
      if (budget) {
        spent = await budget.spent(req.user.idaccount);
        if (spent >= getLimits().monthlyBudgetMicroUsd) {
          res.setHeader('Retry-After', budget.secondsToNextMonth());
          return res.status(429).json({
            success: false,
            code: 'AI_MONTHLY_BUDGET',
            message: 'Bạn đã dùng hết hạn mức trợ lý AI của tháng này. Hạn mức sẽ làm mới vào đầu tháng sau.',
          });
        }
      }

      const accountType = req.effectiveAccountType || req.user?.type || 'Basic';
      const { scopes } = await permissionRepository.getPermissionsByAccountType(accountType);
      const configured = scopes?.[FEATURE_ID]?.daily_prompts;
      req.aiContextWindowDays = scopes?.[FEATURE_ID]?.context_window_days;
      const limit = Number.isFinite(configured) && configured >= 0 ? configured : getLimits().dailyPromptsDefault;

      const result = await quota.consume(req.user.idaccount, limit);
      res.setHeader('X-AI-Quota-Limit', limit);
      res.setHeader('X-AI-Quota-Remaining', Math.max(0, limit - result.used));

      if (!result.allowed) {
        res.setHeader('Retry-After', result.retryAfterSeconds);
        return res.status(429).json({
          success: false,
          code: 'AI_DAILY_LIMIT',
          message: `Bạn đã dùng hết ${limit} lượt hỏi trợ lý AI trong hôm nay. Hạn mức sẽ làm mới vào 0 giờ.`,
          limit,
        });
      }

      // Lỗi do hệ thống thì controller trả lại lượt này (PO chốt 2026-11-08); mỗi yêu cầu hoàn tối đa một lần.
      let refunded = false;
      req.aiQuotaRefund = async () => {
        if (refunded) return;
        refunded = true;
        await quota.refund(result);
      };

      if (budget) {
        const l = getLimits();
        req.aiTurnCostCapMicroUsd = computeTurnCapMicroUsd({
          spentMicroUsd: spent,
          monthlyBudgetMicroUsd: l.monthlyBudgetMicroUsd,
          daysLeft: budget.daysLeftInMonth(),
          dailyPrompts: limit,
          factor: l.turnCostFactor,
          floor: l.minTurnCostMicroUsd,
          ceiling: l.maxTurnCostMicroUsd,
        });
      }
      return next();
    } catch (err) {
      logger.error('[AI Quota] Lỗi kiểm tra hạn mức, chặn để bảo vệ chi phí:', err?.message);
      return res.status(503).json({ success: false, code: 'AI_QUOTA_UNAVAILABLE', message: 'Dịch vụ AI tạm thời chưa sẵn sàng' });
    }
  };
}

// Instance dùng thật: Redis có sẵn thì dùng, không thì bộ nhớ (xem UsageQuota / UsageBudget).
let defaults = null;
function getDefaults() {
  if (!defaults) {
    const { redis } = require('../../../../../config/redis');
    const permissionRepository = require('../../../../payment/permission.repository');
    const budget = new UsageBudget({ redis });
    defaults = {
      budget,
      middleware: createDailyQuotaMiddleware({ quota: new UsageQuota({ redis }), budget, permissionRepository }),
    };
  }
  return defaults;
}

function dailyQuotaMiddleware(req, res, next) {
  return getDefaults().middleware(req, res, next);
}

/** Ngân sách dùng chung để controller ghi chi phí thật của từng lượt. */
function getUsageBudget() {
  return getDefaults().budget;
}

module.exports = { createDailyQuotaMiddleware, dailyQuotaMiddleware, getUsageBudget, isAdmin };
