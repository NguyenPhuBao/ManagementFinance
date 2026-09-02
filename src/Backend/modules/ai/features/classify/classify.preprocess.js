/**
 * F012 — Transaction Classifier — Text Preprocessing
 * Chuẩn hóa văn bản tiếng Việt theo Chuẩn RAG (Standard_RAG.md):
 * 1. Chuẩn hóa Unicode (NFC)
 * 2. Lowercase & làm sạch ký tự điều khiển
 * 3. Loại bỏ nhiễu mã số ngân hàng rác
 * 4. Hỗ trợ tạo phiên bản không dấu để so khớp linh hoạt
 */

/**
 * Loại bỏ dấu tiếng Việt để so khớp không dấu
 * @param {string} str
 * @returns {string}
 */
function removeVietnameseTones(str) {
  if (!str || typeof str !== 'string') return '';
  str = str.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  str = str.replace(/[đĐ]/g, 'd');
  return str;
}

/**
 * Làm sạch và chuẩn hóa chuỗi giao dịch đầu vào
 * @param {string} text
 * @returns {string} Text sạch chuẩn hóa NFC
 */
function cleanVietnameseText(text) {
  if (!text || typeof text !== 'string') return '';

  // 1. Chuẩn hóa Unicode NFC
  let cleaned = text.normalize('NFC').trim();

  // 2. Chuyển chữ thường
  cleaned = cleaned.toLowerCase();

  // 3. Loại bỏ các mã số giao dịch rác ngân hàng phổ biến (nhưng giữ lại tên merchant/nội dung)
  // Ví dụ: FT26245981273910, ACSP/ 9l191181, 144878879528...
  cleaned = cleaned.replace(/\bft\d+\b/gi, ' ');
  cleaned = cleaned.replace(/\bacsp\/\s*\w+\b/gi, ' ');
  cleaned = cleaned.replace(/\b(ct|den|tu|gd|tk|sd)\b\s*[:|-]?/gi, ' ');

  // 4. Thay thế ký tự đặc biệt, dấu gạch dưới, gạch ngang thành khoảng trắng
  cleaned = cleaned.replace(/[_\-.,;:|/\\()[\]{}<>+=*&%$#@!~?`"']/g, ' ');

  // 5. Gộp khoảng trắng thừa
  cleaned = cleaned.replace(/\s+/g, ' ').trim();

  return cleaned;
}

/**
 * Preprocess wrapper dùng chung cho inference pipeline
 * @param {string} description
 * @returns {{ clean: string, cleanNoTone: string, raw: string }}
 */
function preprocess(description) {
  const raw = (description || '').trim();
  const clean = cleanVietnameseText(raw);
  const cleanNoTone = removeVietnameseTones(clean);

  return {
    raw,
    clean,
    cleanNoTone,
  };
}

module.exports = {
  cleanVietnameseText,
  removeVietnameseTones,
  preprocess,
};
