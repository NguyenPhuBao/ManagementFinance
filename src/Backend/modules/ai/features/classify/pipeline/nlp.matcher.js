/**
 * F012 — Transaction Classifier — Tier 2: Local NLP / Token Similarity Matcher
 * 
 * Tốc độ: 5 - 15ms | Chi phí: 0đ | Chạy trên Node.js Backend
 * Tính toán độ tương đồng từ vựng (N-gram & Token Overlap Similarity) giữa chuỗi giao dịch và cây danh mục của user
 */

const { removeVietnameseTones } = require('../classify.preprocess');

/**
 * Tách từ đơn giản cho tiếng Việt
 * @param {string} str 
 * @returns {Set<string>}
 */
function tokenizeToSet(str) {
  if (!str) return new Set();
  const words = str
    .toLowerCase()
    .split(/\s+/)
    .map((w) => w.trim())
    .filter((w) => w.length >= 2);
  return new Set(words);
}

/**
 * Tính toán chỉ số tương đồng Jaccard Similarity giữa 2 tập từ
 * @param {Set<string>} setA 
 * @param {Set<string>} setB 
 * @returns {number} 0.0 - 1.0
 */
function jaccardSimilarity(setA, setB) {
  if (setA.size === 0 || setB.size === 0) return 0;
  let intersectionCount = 0;
  for (const elem of setA) {
    if (setB.has(elem)) {
      intersectionCount++;
    }
  }
  const unionSize = setA.size + setB.size - intersectionCount;
  return unionSize > 0 ? intersectionCount / unionSize : 0;
}

/**
 * Phân loại ngữ nghĩa nhẹ dựa trên độ tương đồng từ vựng
 * @param {{ clean: string, cleanNoTone: string, raw: string }} cleanInfo 
 * @param {Array<object>} categories - Danh sách category của user từ DB
 * @param {object} [context={}] 
 * @returns {object|null}
 */
function matchNLP(cleanInfo, categories, context = {}) {
  if (!cleanInfo || !Array.isArray(categories) || categories.length === 0) {
    return null;
  }

  const { clean, cleanNoTone } = cleanInfo;
  const merchant = (context.merchant || '').toLowerCase();
  const counterpart = (context.counterpart_name || '').toLowerCase();

  const fullText = `${clean} ${merchant} ${counterpart}`.trim();
  const fullNoTone = `${cleanNoTone} ${removeVietnameseTones(merchant)} ${removeVietnameseTones(counterpart)}`.trim();

  const queryTokens = tokenizeToSet(fullText);
  const queryTokensNoTone = tokenizeToSet(fullNoTone);

  const scoredCategories = [];

  for (const cat of categories) {
    if (!cat) continue;

    const catName = (cat.namecategory_lower || cat.namecategory || '').toLowerCase();
    // Phân tách dấu phẩy ',' thành khoảng trắng để tokenize từ vựng
    const rawKeywords = cat.keyword_lower || cat.keyword || '';
    const catKeywords = rawKeywords.toLowerCase().replace(/,/g, ' ');
    const docText = `${catName} ${catKeywords}`.trim();
    const docNoTone = removeVietnameseTones(docText);

    const docTokens = tokenizeToSet(docText);
    const docTokensNoTone = tokenizeToSet(docNoTone);

    // Tính điểm tương đồng với cả 2 phiên bản có dấu và không dấu
    const simWithTone = jaccardSimilarity(queryTokens, docTokens);
    const simNoTone = jaccardSimilarity(queryTokensNoTone, docTokensNoTone);

    const score = Math.max(simWithTone, simNoTone);

    if (score > 0.05) {
      scoredCategories.push({
        cat,
        score,
      });
    }
  }

  if (scoredCategories.length === 0) {
    return null;
  }

  // Sắp xếp theo điểm tương đồng giảm dần
  scoredCategories.sort((a, b) => b.score - a.score);

  const top1 = scoredCategories[0];
  const confidence = Math.min(0.89, Math.max(0.50, Number((0.50 + top1.score * 0.40).toFixed(2))));

  // Tạo top 3 danh mục gợi ý phụ
  const suggestedCategories = scoredCategories.slice(0, 3).map((item) => ({
    id: item.cat.idcategory,
    name: item.cat.namecategory,
    icon: item.cat.icon || 'category',
    classify: item.cat.classify || 'Chi',
  }));

  return {
    category_id: top1.cat.idcategory,
    category_name: top1.cat.namecategory,
    category_icon: top1.cat.icon || 'category',
    classify: top1.cat.classify || 'Chi',
    confidence,
    tier_used: 'tier2_nlp',
    suggested_categories: suggestedCategories,
  };
}

module.exports = {
  matchNLP,
};
