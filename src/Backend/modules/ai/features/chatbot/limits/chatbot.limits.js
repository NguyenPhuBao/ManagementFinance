/**
 * Chatbot AI — Cấu hình giới hạn chi phí & độ dài (nguồn DUY NHẤT).
 *
 * Mọi con số ở đây là GIÁ TRỊ TẠM THỜI: phải đo lại bằng trường `usage` của nhà cung cấp LLM đang dùng
 * rồi mới chốt (đừng áp giới hạn của mô hình cũ cho mô hình mới). Ghi đè bằng biến môi trường `AI_*`
 * mà không cần sửa mã. Giá trị hỏng (không phải số dương) thì dùng mặc định.
 */

function positiveNumber(envName, fallback) {
  const raw = Number(process.env[envName]);
  return Number.isFinite(raw) && raw > 0 ? raw : fallback;
}

function getChatbotLimits() {
  return Object.freeze({
    // — Mỗi yêu cầu —
    maxMessageChars: positiveNumber('AI_MAX_MESSAGE_CHARS', 1000),
    maxHistoryItems: positiveNumber('AI_MAX_HISTORY_ITEMS', 4),
    maxHistoryItemChars: positiveNumber('AI_MAX_HISTORY_ITEM_CHARS', 800),
    maxOutputTokens: positiveNumber('AI_MAX_OUTPUT_TOKENS', 1024),
    maxToolCallsPerRound: positiveNumber('AI_MAX_TOOL_CALLS_PER_ROUND', 5),
    // Gọi công cụ ĐA BƯỚC là mặc định: mô hình được gọi nối tiếp nhiều vòng cho tới khi đủ dữ liệu. Trần vòng chỉ là
    // lưới an toàn chống vòng lặp; thiệt hại thật bị chặn bởi `maxTurnCostMicroUsd` và ngân sách tháng. 1 = chế độ một bước.
    maxToolRounds: positiveNumber('AI_MAX_TOOL_ROUNDS', 5),
    // Trần CỨNG chi phí một lượt hỏi (micro-USD, 12000 = 0,012 USD ≈ 310đ). Vượt thì không cho gọi công cụ nữa nhưng vẫn
    // trả lời. Người dùng thường có trần động thấp hơn theo ngân sách còn lại (limits/turn-cap.js); quản trị viên dùng trần này.
    maxTurnCostMicroUsd: positiveNumber('AI_MAX_TURN_COST_MICRO_USD', 12000),
    turnCostFactor: positiveNumber('AI_TURN_COST_FACTOR', 1.5),
    minTurnCostMicroUsd: positiveNumber('AI_MIN_TURN_COST_MICRO_USD', 2000),
    maxToolResultChars: positiveNumber('AI_MAX_TOOL_RESULT_CHARS', 2500),
    llmTimeoutMs: positiveNumber('AI_LLM_TIMEOUT_MS', 60000),
    // — Mỗi người dùng / toàn hệ thống —
    dailyPromptsDefault: positiveNumber('AI_DAILY_PROMPTS_DEFAULT', 20),
    // Ngân sách chi phí AI mỗi người dùng mỗi tháng, micro-USD (800000 = 0.80 USD ≈ 42% giá Premium 49.000đ; PO nâng từ 0.40 ngày 2026-11-08).
    monthlyBudgetMicroUsd: positiveNumber('AI_MONTHLY_BUDGET_MICRO_USD', 800000),
    maxStreamsPerUser: positiveNumber('AI_MAX_STREAMS_PER_USER', 1),
    maxStreamsGlobal: positiveNumber('AI_MAX_STREAMS_GLOBAL', 30),
  });
}

module.exports = { getChatbotLimits };
