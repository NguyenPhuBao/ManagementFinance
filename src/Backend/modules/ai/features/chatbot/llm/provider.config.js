/**
 * Chọn và cấu hình nhà cung cấp LLM CHỈ cho Chatbot AI.
 * Phân loại giao dịch và OCR vẫn dùng cấu hình Gemini riêng của chúng (biến `GEMINI_*`), không đi qua đây.
 *
 *   CHATBOT_LLM_PROVIDER = deepseek | gemini   (chỉ định rõ thì theo chỉ định)
 *   không chỉ định → có DEEPSEEK_API_KEY thì deepseek, ngược lại gemini (triển khai chưa kịp đặt khoá không bị vỡ)
 */

const { DEFAULT_BASE_URL } = require('./deepseek.provider');

const DEFAULT_DEEPSEEK_MODEL = 'deepseek-flash';

function resolveProvider(env = process.env) {
  const explicit = String(env.CHATBOT_LLM_PROVIDER || '').trim().toLowerCase();
  if (explicit === 'deepseek' || explicit === 'gemini') return explicit;
  return env.DEEPSEEK_API_KEY ? 'deepseek' : 'gemini';
}

function getDeepseekConfig(env = process.env) {
  return {
    apiKey: env.DEEPSEEK_API_KEY || null,
    model: env.DEEPSEEK_MODEL || DEFAULT_DEEPSEEK_MODEL,
    baseUrl: env.DEEPSEEK_BASE_URL || DEFAULT_BASE_URL,
  };
}

module.exports = { resolveProvider, getDeepseekConfig, DEFAULT_DEEPSEEK_MODEL };
