/**
 * Chuẩn hóa và tách từ tiếng Việt cho truy hồi từ vựng (BM25). Thuần JS, không thư viện ngoài.
 *
 * Âm tiết là đơn vị tách chính (tiếng Việt viết cách chữ theo âm tiết); cặp âm tiết liền kề (bigram) giữ nghĩa
 * từ ghép như "giảm trừ", "gia cảnh" mà không cần bộ tách từ ngoài. Mọi thứ bỏ dấu để câu hỏi gõ không dấu vẫn khớp.
 */

/**
 * Từ dừng (đã bỏ dấu). Cố ý KHÔNG đưa vào các từ bỏ dấu trùng với từ nội dung tài chính:
 * "the" (thẻ / thế), "vay" (vay / vậy), "chi" (chi tiêu / chị), "minh" (mình / minh bạch), "bao" (bao / bảo hiểm).
 */
const VI_STOPWORDS = new Set([
  'toi', 'ban', 'em', 'anh', 'ta', 'la', 'va', 'cua', 'cho', 'voi', 'nhung', 'cac', 'mot', 'nhu', 'nao', 'nay',
  'do', 'khi', 'de', 'trong', 'ma', 'thi', 'se', 'da', 'dang', 'co', 'khong', 'bi', 'duoc', 'muon', 'biet', 'hay',
  'nen', 'can', 'phai', 'ra', 'vao', 'len', 'o', 'tu', 'den', 'rat', 'qua', 'cung', 'nua', 'roi', 'sao', 'gi',
  'ai', 'dau', 'hom', 'cai', 'nhieu', 'it', 'sau', 'hoac', 'neu', 've', 'theo', 'giup', 'cach',
]);

/** Chữ thường, bỏ dấu (kể cả đ/Đ), thay mọi ký tự không phải chữ-số bằng khoảng trắng. */
function normalizeVi(str) {
  if (typeof str !== 'string' || !str) return '';
  return str
    .toLowerCase()
    .replace(/đ/g, 'd')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/**
 * @param {string} str
 * @param {{stopwords?: boolean, bigrams?: boolean}} [opts]
 * @returns {string[]} âm tiết (đã bỏ từ dừng), theo sau là các bigram `a_b`
 */
function tokenize(str, { stopwords = true, bigrams = true } = {}) {
  const norm = normalizeVi(str);
  if (!norm) return [];
  const unigrams = norm.split(' ').filter((t) => t && !(stopwords && VI_STOPWORDS.has(t)));
  if (!bigrams) return unigrams;
  const out = unigrams.slice();
  for (let i = 0; i < unigrams.length - 1; i++) out.push(`${unigrams[i]}_${unigrams[i + 1]}`);
  return out;
}

module.exports = { normalizeVi, tokenize, VI_STOPWORDS };
