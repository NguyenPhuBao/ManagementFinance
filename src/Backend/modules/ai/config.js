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
  llm: {
    defaultProvider: 'gemini',
    defaultModel: process.env.GEMINI_MODEL || 'gemini-3.8-flash',
    maxTokens: { classify: 512, ocr: 2048, chatbot: 1024 },
    temperature: { classify: 0.1, ocr: 0.1, chatbot: 0.1 },
  },
};
