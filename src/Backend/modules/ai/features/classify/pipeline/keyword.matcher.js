/**
 * F012 — Transaction Classifier — Tier 1: Keyword & Rule-Based Matcher
 * 
 * Tốc độ: 0 - 5ms | Độ chính xác: 100% | Chạy được cả trên SQLite Offline
 * So khớp trực tiếp chuỗi giao dịch với trường Category.Keyword của người dùng
 */

const { removeVietnameseTones, cleanVietnameseText } = require('../classify.preprocess');

/**
 * Tìm kiếm danh mục phù hợp dựa trên từ khóa trong CSDL của user
 * @param {{ clean: string, cleanNoTone: string, raw: string }} cleanInfo 
 * @param {Array<object>} categories - Danh sách category của user từ DB
 * @param {object} [context={}] - Context phụ (merchant, counterpart_name, amount)
 * @returns {object|null}
 */
function matchKeywords(cleanInfo, categories, context = {}) {
  if (!cleanInfo || !Array.isArray(categories) || categories.length === 0) {
    return null;
  }

  const { clean, cleanNoTone } = cleanInfo;
  const merchant = (context.merchant || '').toLowerCase();
  const merchantNoTone = removeVietnameseTones(merchant);

  // Gom toàn bộ chuỗi tìm kiếm
  const fullSearchText = `${clean} ${merchant}`.trim();
  const fullSearchNoTone = `${cleanNoTone} ${merchantNoTone}`.trim();

  let bestMatch = null;
  let maxKeywordLength = 0;

  for (const cat of categories) {
    if (!cat) continue;

    const catName = (cat.namecategory || '').toLowerCase();
    const catNameNoTone = removeVietnameseTones(catName);

    // 1. So khớp trực tiếp tên danh mục
    if (catName && (fullSearchText.includes(catName) || fullSearchNoTone.includes(catNameNoTone))) {
      if (catName.length > maxKeywordLength) {
        maxKeywordLength = catName.length;
        bestMatch = {
          category_id: cat.idcategory,
          category_name: cat.namecategory,
          category_icon: cat.icon || 'category',
          classify: cat.classify || 'Chi',
          confidence: 0.98,
          tier_used: 'tier1_keyword',
        };
      }
    }

    // 2. So khớp bộ từ khóa Category.Keyword (phân cách bởi dấu phẩy ,)
    if (cat.keyword && typeof cat.keyword === 'string') {
      const keywords = cat.keyword
        .split(/[,;]/)
        .map((k) => cleanVietnameseText(k))
        .filter(Boolean);

      for (const kw of keywords) {
        const kwNoTone = removeVietnameseTones(kw);

        // Kiểm tra từ khóa xuất hiện trong văn bản
        const isMatchedWithTone = kw.length >= 2 && fullSearchText.includes(kw);
        const isMatchedNoTone = kwNoTone.length >= 2 && fullSearchNoTone.includes(kwNoTone);

        if (isMatchedWithTone || isMatchedNoTone) {
          // Ưu tiên từ khóa dài và đặc thù hơn
          if (kw.length > maxKeywordLength) {
            maxKeywordLength = kw.length;
            bestMatch = {
              category_id: cat.idcategory,
              category_name: cat.namecategory,
              category_icon: cat.icon || 'category',
              classify: cat.classify || 'Chi',
              confidence: isMatchedWithTone ? 0.99 : 0.95,
              tier_used: 'tier1_keyword',
            };
          }
        }
      }
    }
  }

  return bestMatch;
}

module.exports = {
  matchKeywords,
};
