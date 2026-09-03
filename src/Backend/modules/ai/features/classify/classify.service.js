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
const { typeDetector } = require('./pipeline/type.detector');
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

  /**
   * Phân loại giao dịch 2 cấp độ (Cấp 1: Type & Cấp 2: Category)
   * @param {string|number} idaccount 
   * @param {object} params
   * @returns {Promise<object>}
   */
  async classifyTransaction(idaccount, params = {}) {
    let userProfile = params._mockUser;
    let userWallets = params._mockWallets;
    let bankAccounts = params._mockBankAccounts;

    if (!userProfile || !userWallets) {
      const profileData = await classifyRepository.getUserProfileAndWallets(idaccount);
      userProfile = userProfile || profileData.user;
      userWallets = userWallets || profileData.wallets;
      bankAccounts = bankAccounts || profileData.bankAccounts;
    }

    // =========================================================================
    // CẤP ĐỘ 1: PHÂN LOẠI LOẠI GIAO DỊCH (Transaction vs Transfer)
    // =========================================================================
    const typeResult = typeDetector.detectType({
      items: params.items,
      destination_name: params.destination_name || params.counterpart_name,
      destination_account: params.destination_account,
      source_account: params.source_account,
      note: params.note || params.text,
      text: params.text,
      userProfile,
      userWallets,
      bankAccounts: bankAccounts || [],
    });

    // =========================================================================
    // CẤP ĐỘ 2: QUY TẮC DANH MỤC
    // - Nếu là Transfer -> HOÀN TOÀN BỎ QUA PHÂN LOẠI DANH MỤC (category_id = null)
    // - Nếu là Transaction -> Phân loại danh mục qua bộ 3 Tầng
    // =========================================================================
    if (typeResult.type === 'Transfer') {
      return {
        type: 'Transfer',
        confidence: typeResult.confidence,
        reason: typeResult.reason,
        category_id: null,
        category_name: null,
        category_icon: null,
        classify: null,
        tier_used: 'type_detector_transfer',
        suggested_categories: [],
        source_wallet_id: typeResult.source_wallet_id || null,
        destination_wallet_id: typeResult.destination_wallet_id || null,
        matched_user: typeResult.matched_user || false,
        amount: Number(params.amount) || 0,
        note: params.note || params.text || '',
      };
    }

    // Khi là Transaction: Kích hoạt phân loại danh mục Cấp 2
    const categoryResult = await this.classifySingle(idaccount, {
      text: params.text || params.note || params.merchant || '',
      amount: params.amount,
      merchant: params.merchant,
      source: params.source || 'Manual',
      counterpart_name: params.counterpart_name || params.destination_name || '',
    });

    return {
      type: 'Transaction',
      type_confidence: typeResult.confidence,
      type_reason: typeResult.reason,
      ...categoryResult,
      amount: Number(params.amount) || 0,
      note: params.note || params.text || '',
    };
  },

  /**
   * Phân loại toàn diện dữ liệu trích xuất từ Module Receipt OCR
   * @param {string|number} idaccount 
   * @param {object} extraction 
   * @param {object} options 
   * @returns {Promise<object>} DTO phân loại cho OCR
   */
  async classifyExtractedReceipt(idaccount, extraction = {}, options = {}) {
    const rawItems = extraction.items || [];
    const totalAmount = Number(extraction.total_amount || extraction.amount) || 0;

    // 1. Phân loại loại giao dịch 2 cấp độ
    const txClassification = await this.classifyTransaction(idaccount, {
      items: rawItems,
      destination_name: extraction.destination_name,
      destination_account: extraction.destination_account,
      source_account: extraction.source_account,
      note: extraction.note,
      text: extraction.merchant_name ? `${extraction.merchant_name}. ${rawItems.map((i) => i.name).join(', ')}` : extraction.note,
      amount: totalAmount,
      merchant: extraction.merchant_name,
      _mockUser: options._mockUser,
      _mockWallets: options._mockWallets,
    });

    // 2. Kịch bản Transfer: Trả về DTO chuyển tiền nội bộ (không phân loại danh mục)
    if (txClassification.type === 'Transfer') {
      return {
        document_type: extraction.document_type || 'BANK_TRANSFER',
        detected_type: 'Transfer',
        provider: extraction.document_type === 'SMS_BANKING' ? 'SMS' : 'BankSync',
        bank_tran_id: extraction.transaction_code || null,
        transfer_details: {
          amount: totalAmount,
          transaction_date: extraction.transaction_date || new Date(),
          bank_tran_id: extraction.transaction_code || null,
          source_bank: extraction.source_bank || null,
          source_account: extraction.source_account || null,
          source_wallet_id: txClassification.source_wallet_id || null,
          destination_bank: extraction.destination_bank || null,
          destination_account: extraction.destination_account || null,
          destination_name: extraction.destination_name || null,
          destination_wallet_id: txClassification.destination_wallet_id || null,
          note: extraction.note || '',
        },
        options: [
          {
            type: 'Transfer',
            title: 'Xác nhận Chuyển tiền nội bộ (Khuyên dùng)',
            description: 'Dịch chuyển tiền giữa 2 tài khoản của bạn — KHÔNG tính vào chi phí',
            provider: extraction.document_type === 'SMS_BANKING' ? 'SMS' : 'BankSync',
            bank_tran_id: extraction.transaction_code || null,
            from_wallet_id: txClassification.source_wallet_id || null,
            to_wallet_id: txClassification.destination_wallet_id || null,
            category_id: null,
            amount: totalAmount,
            note: extraction.note || '',
          },
          {
            type: 'Transaction',
            title: 'Chuyển thành Giao dịch Chi tiêu',
            description: 'Nếu đây thực chất là chi phí thanh toán cho bên khác',
            provider: extraction.document_type === 'SMS_BANKING' ? 'SMS' : 'BankSync',
            bank_tran_id: extraction.transaction_code || null,
            wallet_id: txClassification.source_wallet_id || null,
            category_id: null,
            category_name: 'Chi tiêu khác',
            amount: totalAmount,
            note: extraction.note || '',
          },
        ],
      };
    }

    // 3. Kịch bản Transaction (Hóa đơn hoặc thanh toán bên thứ 3)
    let optionGrouped = null;
    if (rawItems.length > 0) {
      // Phân loại từng món hàng
      const batchItems = rawItems.map((item, idx) => ({
        item_id: `item_${idx + 1}`,
        text: item.name,
        amount: item.total_price || item.unit_price || 0,
      }));

      const batchResults = await this.classifyBatch(idaccount, batchItems);

      // Gom nhóm theo category_id
      const groupMap = new Map();
      rawItems.forEach((item, idx) => {
        const classified = batchResults[idx] || {};
        const catId = classified.category_id || txClassification.category_id || 'unclassified';
        const catName = classified.category_name || txClassification.category_name || 'Khác';
        const catIcon = classified.category_icon || txClassification.category_icon || 'category';

        if (!groupMap.has(catId)) {
          groupMap.set(catId, {
            category_id: catId,
            category_name: catName,
            category_icon: catIcon,
            group_total: 0,
            note: `${extraction.merchant_name || 'Hóa đơn'}: ${item.name}`,
            items: [],
          });
        }

        const grp = groupMap.get(catId);
        const itemTotal = Number(item.total_price || (item.unit_price * item.quantity)) || 0;
        grp.group_total += itemTotal;
        grp.items.push({
          name: item.name,
          quantity: item.quantity || 1,
          unit_price: item.unit_price || itemTotal,
          total_price: itemTotal,
          category_id: catId,
          category_name: catName,
          category_icon: catIcon,
          note: item.name,
        });
      });

      const baseBankTranId = extraction.invoice_no || null;
      const groups = Array.from(groupMap.values()).map((grp, idx) => ({
        ...grp,
        provider: 'ORC',
        bank_tran_id: baseBankTranId ? `${baseBankTranId}_grp_${idx + 1}` : null,
      }));

      optionGrouped = {
        title: 'Ghi nhận chi tiết theo từng danh mục',
        total_amount: totalAmount,
        groups,
      };
    }


    // 3. Kịch bản Transaction
    // 3a. Nếu là Biên lai ngân hàng hoặc SMS thanh toán cho bên thứ 3 (Shopee, Grab, điện nước...)
    if (extraction.document_type === 'BANK_TRANSFER' || extraction.document_type === 'SMS_BANKING') {
      return {
        document_type: extraction.document_type,
        detected_type: 'Transaction',
        provider: extraction.document_type === 'SMS_BANKING' ? 'SMS' : 'BankSync',
        bank_tran_id: extraction.transaction_code || null,
        transaction_info: {
          amount: totalAmount,
          transaction_date: extraction.transaction_date || new Date(),
          bank_tran_id: extraction.transaction_code || null,
          source_bank: extraction.source_bank || null,
          source_account: extraction.source_account || null,
          source_wallet_id: txClassification.source_wallet_id || null,
          counterpart_name: extraction.destination_name || extraction.counterpart_name || null,
          counterpart_account: extraction.destination_account || null,
          note: extraction.note || '',
        },
        option_single: {
          title: 'Ghi nhận Chi tiêu',
          provider: extraction.document_type === 'SMS_BANKING' ? 'SMS' : 'BankSync',
          bank_tran_id: extraction.transaction_code || null,
          amount: totalAmount,
          wallet_id: txClassification.source_wallet_id || null,
          suggested_category_id: txClassification.category_id,
          suggested_category_name: txClassification.category_name,
          suggested_category_icon: txClassification.category_icon,
          note: extraction.note || (extraction.destination_name ? `Thanh toán ${extraction.destination_name}` : 'Chi tiêu'),
        },
      };
    }

    // 3b. Nếu là Hóa đơn mua sắm tiêu dùng (RECEIPT)
    return {
      document_type: extraction.document_type || 'RECEIPT',
      detected_type: 'Transaction',
      provider: 'ORC',
      bank_tran_id: extraction.invoice_no || null,
      invoice_info: {
        merchant_name: extraction.merchant_name || null,
        merchant_address: extraction.merchant_address || null,
        invoice_no: extraction.invoice_no || null,
        transaction_date: extraction.transaction_date || new Date(),
        total_amount: totalAmount,
        vat_amount: extraction.vat_amount || 0,
        payment_method: extraction.payment_method || null,
      },
      option_single: {
        title: 'Ghi nhận 1 giao dịch tổng',
        amount: totalAmount,
        suggested_category_id: txClassification.category_id,
        suggested_category_name: txClassification.category_name,
        suggested_category_icon: txClassification.category_icon,
        note: extraction.merchant_name
          ? `${extraction.merchant_name}: ${rawItems.map((i) => i.name).join(', ')}`
          : (extraction.note || 'Chi tiêu'),
      },
      ...(optionGrouped ? { option_grouped: optionGrouped } : {}),
    };
  },
};

module.exports = classifyService;
