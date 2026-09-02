/**
 * F012 — Transaction Classifier — Service
 * Điều phối phân loại đa tầng (Tier 1: Keyword -> Tier 2: NLP -> Tier 3: LLM Gemini Flash)
 * Hỗ trợ các kịch bản: Single, Batch (OCR), và Feedback tự học.
 */

const classifyRepository = require('./classify.repository');
const { preprocess } = require('./classify.preprocess');
const { matchKeywords } = require('./pipeline/keyword.matcher');
const { matchNLP } = require('./pipeline/nlp.matcher');
const llmClassifier = require('./pipeline/llm.classifier');
const logger = require('../../../../core/logger');

const classifyService = {
  /**
   * Phân loại một giao dịch đơn lẻ (Dùng cho Casso BankSync, SMS Banking, Nhập tay, Tổng hóa đơn)
   * @param {string} idaccount 
   * @param {object} params - { text, amount, merchant, source, counterpart_name }
   * @returns {Promise<object>} DTO phân loại chuẩn hóa
   */
  async classifySingle(idaccount, { text, amount = 0, merchant = '', source = 'Manual', counterpart_name = '' }) {
    if (!text || typeof text !== 'string') {
      text = merchant || '';
    }

    // 1. Lấy danh sách danh mục thuộc quyền sở hữu của user trong CSDL
    const categories = await classifyRepository.getUserCategories(idaccount);
    if (!categories || categories.length === 0) {
      return {
        category_id: null,
        category_name: 'Chưa phân loại',
        category_icon: 'help_outline',
        classify: 'Chi',
        confidence: 0.0,
        tier_used: 'fallback_no_categories',
        suggested_categories: [],
      };
    }

    // 2. Tiền xử lý văn bản theo chuẩn RAG
    const cleanInfo = preprocess(text);
    const context = { merchant, amount: Number(amount) || 0, source, counterpart_name };

    // ==========================================
    // 3. TẦNG 1: KEYWORD & RULE-BASED MATCHER (0 - 5ms)
    // ==========================================
    const tier1Result = matchKeywords(cleanInfo, categories, context);
    if (tier1Result && tier1Result.confidence >= 0.90) {
      return {
        ...tier1Result,
        suggested_categories: [
          {
            id: tier1Result.category_id,
            name: tier1Result.category_name,
            icon: tier1Result.category_icon,
            classify: tier1Result.classify,
          },
        ],
      };
    }

    // ==========================================
    // 4. TẦNG 2: LOCAL NLP / TOKEN SIMILARITY (5 - 15ms)
    // ==========================================
    const tier2Result = matchNLP(cleanInfo, categories, context);
    if (tier2Result && tier2Result.confidence >= 0.60) {
      return tier2Result;
    }

    // ==========================================
    // 5. TẦNG 3: FEW-SHOT LLM GEMINI FLASH (Khi T1/T2 không tự tin)
    // ==========================================
    try {
      const tier3Result = await llmClassifier.classifyWithLLM(text, categories, context);
      if (tier3Result && tier3Result.category_id) {
        return {
          ...tier3Result,
          suggested_categories: tier2Result ? tier2Result.suggested_categories : [],
        };
      }
    } catch (llmErr) {
      logger.warn('ClassifyService: Tier 3 LLM execution skipped or failed', { error: llmErr.message });
    }

    // ==========================================
    // 6. FALLBACK: Trả về kết quả Tier 2 (nếu có) hoặc danh mục mặc định
    // ==========================================
    if (tier2Result) {
      return tier2Result;
    }

    // Mặc định chọn danh mục "Khác" hoặc danh mục đầu tiên
    const defaultCat = categories.find((c) => c.namecategory.toLowerCase().includes('khác')) || categories[0];
    return {
      category_id: defaultCat.idcategory,
      category_name: defaultCat.namecategory,
      category_icon: defaultCat.icon || 'category',
      classify: defaultCat.classify || 'Chi',
      confidence: 0.35,
      tier_used: 'fallback_default',
      suggested_categories: categories.slice(0, 3).map((c) => ({
        id: c.idcategory,
        name: c.namecategory,
        icon: c.icon || 'category',
        classify: c.classify || 'Chi',
      })),
    };
  },

  /**
   * Phân loại danh sách nhiều món hàng hàng loạt (Dành cho Receipt OCR)
   * @param {string} idaccount 
   * @param {object} params - { items: Array<{ item_id, text, amount }>, merchant, source }
   * @returns {Promise<Array<object>>} Mảng các kết quả phân loại theo từng item_id
   */
  async classifyBatch(idaccount, { items = [], merchant = '', source = 'OCR' }) {
    if (!Array.isArray(items) || items.length === 0) {
      return [];
    }

    const categories = await classifyRepository.getUserCategories(idaccount);
    const results = [];

    for (const item of items) {
      const itemId = item.item_id || item.id || String(results.length + 1);
      const text = item.text || item.name || '';
      const amount = item.amount || item.total_price || 0;

      const cleanInfo = preprocess(text);
      const context = { merchant, amount: Number(amount) || 0, source };

      // Thử Tier 1
      let result = matchKeywords(cleanInfo, categories, context);

      // Thử Tier 2
      if (!result || result.confidence < 0.90) {
        const nlpRes = matchNLP(cleanInfo, categories, context);
        if (nlpRes && (!result || nlpRes.confidence > result.confidence)) {
          result = nlpRes;
        }
      }

      // Fallback mặc định cho item
      if (!result) {
        const defaultCat = categories.find((c) => c.namecategory.toLowerCase().includes('khác')) || categories[0];
        result = {
          category_id: defaultCat ? defaultCat.idcategory : null,
          category_name: defaultCat ? defaultCat.namecategory : 'Chưa phân loại',
          category_icon: defaultCat ? defaultCat.icon : 'category',
          classify: defaultCat ? defaultCat.classify : 'Chi',
          confidence: 0.35,
          tier_used: 'fallback_default',
        };
      }

      results.push({
        item_id: itemId,
        text,
        category_id: result.category_id,
        category_name: result.category_name,
        category_icon: result.category_icon,
        classify: result.classify,
        confidence: result.confidence,
        tier_used: result.tier_used,
      });
    }

    return results;
  },

  /**
   * Ghi nhận phản hồi của người dùng để hệ thống tự học (Self-Learning Feedback Loop)
   * @param {string} idaccount 
   * @param {object} params - { idcategory, keyword, rawText }
   * @returns {Promise<object>}
   */
  async recordFeedback(idaccount, { idcategory, keyword, rawText }) {
    if (!idcategory) {
      throw Object.assign(new Error('idcategory la bat buoc'), { statusCode: 400 });
    }

    // Trích xuất và chuẩn hóa từ khóa cần học
    let keywordToLearn = (keyword || '').trim();
    if (!keywordToLearn && rawText) {
      keywordToLearn = rawText;
    }
    const cleanInfo = preprocess(keywordToLearn);
    keywordToLearn = cleanInfo.clean;

    if (!keywordToLearn || keywordToLearn.length < 2) {
      throw Object.assign(new Error('Tu khoa hoc khong hop le'), { statusCode: 400 });
    }

    // Cập nhật vào DB
    const updatedCategory = await classifyRepository.appendCategoryKeyword(idcategory, keywordToLearn);

    logger.info('ClassifyService: Self-learning feedback recorded', {
      idaccount,
      idcategory,
      keyword: keywordToLearn,
    });

    return {
      success: true,
      category_id: updatedCategory.idcategory,
      keyword: keywordToLearn,
      all_keywords: updatedCategory.keyword,
    };
  },
};

module.exports = classifyService;
