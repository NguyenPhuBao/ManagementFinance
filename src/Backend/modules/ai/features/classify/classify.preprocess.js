/**
 * F012 — Transaction Classifier — Preprocessing
 *
 * Chuẩn hóa text đầu vào trước khi predict:
 * 1. Lowercase
 * 2. Xóa dấu câu, ký tự đặc biệt
 * 3. Xóa stopwords tiếng Việt
 * 4. Tokenize (tách từ)
 * 5. Chuẩn hóa Unicode (NFC)
 *
 * @param {string} description — Mô tả giao dịch thô
 * @returns {string} — Text đã được làm sạch
 */
function preprocess(description) {
  // TODO: Implement preprocessing
  return description;
}

module.exports = { preprocess };
