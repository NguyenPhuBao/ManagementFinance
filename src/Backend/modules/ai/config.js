/**
 * AI Module — Shared Config
 * Model paths, confidence thresholds, hyperparameters.
 */

module.exports = {
  classify: {
    modelPath: `${__dirname}/features/classify/pipeline/model.v1.bin`,
    labelsPath: `${__dirname}/features/classify/pipeline/labels.json`,
    confidenceThreshold: 0.3,
    fallbackCategoryId: null, // Nếu confidence < threshold, giữ nguyên (chưa phân loại)
  },
  ocr: {
    tesseractLang: 'vie+eng',
    tesseractPSM: 3, // Fully automatic page segmentation
  },
  // Phần này chỉ mô tả phân loại giao dịch và OCR (vẫn dùng Gemini). Chatbot AI có cấu hình RIÊNG, không đọc ở đây:
  //   nhà cung cấp & mô hình: features/chatbot/llm/provider.config.js (CHATBOT_LLM_PROVIDER, DEEPSEEK_*)
  //   giới hạn token / độ dài / hạn mức: features/chatbot/limits/chatbot.limits.js (AI_*)
  llm: {
    defaultProvider: 'gemini',
    defaultModel: process.env.GEMINI_MODEL || 'gemini-3.8-flash',
    maxTokens: { classify: 512, ocr: 2048 },
    temperature: { classify: 0.1, ocr: 0.1 },
  },
};
