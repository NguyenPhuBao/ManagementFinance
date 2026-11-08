/**
 * Chi phí thật của một lần gọi LLM, tính từ trường `usage` của nhà cung cấp.
 *
 *   chi phí (micro-USD) = miss × giá_miss + hit × giá_hit + out × giá_out      (giá tính theo USD / 1 triệu token)
 *
 * Vì 1 USD / 1 triệu token = 1 micro-USD / token nên không cần đổi đơn vị. Kết quả làm tròn LÊN.
 * Giá mặc định là giá GIỜ CAO ĐIỂM của `deepseek-flash` (bảo thủ: ngân sách không bao giờ bị đánh giá thấp);
 * giờ vắng bằng một nửa. Ghi đè bằng AI_PRICE_*_PER_M khi nhà cung cấp đổi giá hoặc đổi mô hình.
 */

const DEFAULT_PRICES = Object.freeze({ missPerM: 0.30, hitPerM: 0.006, outPerM: 1.20 });

function envPrice(name, fallback) {
  const v = Number(process.env[name]);
  return Number.isFinite(v) && v >= 0 && process.env[name] !== undefined && process.env[name] !== '' ? v : fallback;
}

function getPrices() {
  return {
    missPerM: envPrice('AI_PRICE_MISS_PER_M', DEFAULT_PRICES.missPerM),
    hitPerM: envPrice('AI_PRICE_HIT_PER_M', DEFAULT_PRICES.hitPerM),
    outPerM: envPrice('AI_PRICE_OUT_PER_M', DEFAULT_PRICES.outPerM),
  };
}

/** @returns {number} micro-USD (số nguyên, ≥ 0) */
function usageToMicroUsd(usage, prices = getPrices()) {
  if (!usage || typeof usage !== 'object') return 0;
  const prompt = Number(usage.prompt_tokens) || 0;
  const hit = Number(usage.prompt_cache_hit_tokens) || 0;
  const miss = usage.prompt_cache_miss_tokens !== undefined
    ? Number(usage.prompt_cache_miss_tokens) || 0
    : Math.max(0, prompt - hit);
  const out = Number(usage.completion_tokens) || 0;
  return Math.ceil(miss * prices.missPerM + hit * prices.hitPerM + out * prices.outPerM);
}

// Tiếng Việt khoảng 3 ký tự mỗi token với JSON hội thoại; ước lượng dư hơn thật một chút vẫn an toàn cho ngân sách.
const CHARS_PER_TOKEN = 3;

/**
 * Ước lượng chi phí khi không có `usage` (lượt bị huỷ, đứt giữa chừng, nhà cung cấp không gửi): coi cả prompt là không
 * trúng bộ đệm để ngân sách không bị đánh giá thấp.
 * @returns {number} micro-USD (số nguyên, ≥ 0)
 */
function estimateMicroUsd({ promptChars = 0, outputChars = 0 } = {}, prices = getPrices()) {
  const tokens = (chars) => Math.ceil(Math.max(0, Number(chars) || 0) / CHARS_PER_TOKEN);
  return Math.ceil(tokens(promptChars) * prices.missPerM + tokens(outputChars) * prices.outPerM);
}

module.exports = { usageToMicroUsd, estimateMicroUsd, getPrices, DEFAULT_PRICES };
