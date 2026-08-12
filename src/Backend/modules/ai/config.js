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
    defaultProvider: 'openai',
    maxTokens: { advice: 300, budget: 300, chatbot: 500 },
    temperature: { advice: 0.7, budget: 0.5, chatbot: 0.8 },
  },
};
