/**
 * F012 — Transaction Classifier — Inference Engine
 *
 * Load fastText model + predict category.
 * Model được load 1 lần khi worker start (singleton).
 *
 * @param {string} cleanText — Text đã qua preprocessing
 * @returns {{ categoryId: number, categoryName: string, confidence: number }}
 */
class ClassifierInference {
  constructor() {
    this.model = null;
    this.labels = null;
  }

  async load(modelPath, labelsPath) {
    // TODO: Load model.bin + labels.json
  }

  predict(cleanText) {
    // TODO: Gọi fastText.predict() → map label → categoryId
    return { categoryId: null, categoryName: null, confidence: 0 };
  }
}

module.exports = new ClassifierInference();
