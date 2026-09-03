/**
 * F012 — Transaction Classifier — Tier 3: Few-Shot LLM Reasoning (Gemini Flash / OpenAI)
 * 
 * Chuẩn RAG (Standard_RAG.md):
 * - Temperature: 0.1 (Strict Factuality / Anti-Hallucination)
 * - Strict Grounding: Chỉ chọn category_id từ danh sách danh mục của User
 * - Structured JSON Output
 */

const axios = require('axios');
const logger = require('../../../../../core/logger');

class LLMClassifier {
  constructor() {
    this.geminiApiKey = process.env.GEMINI_API_KEY || null;
    this.openaiApiKey = process.env.OPENAI_API_KEY || null;
  }

  /**
   * Sắp xếp danh mục theo chiến thuật Hình Chữ U (U-Shaped Context Ordering)
   * @param {Array<object>} categories 
   * @returns {Array<object>}
   */
  _reorderCategoriesUshape(categories) {
    if (!Array.isArray(categories) || categories.length <= 2) return categories;

    // Phân loại: Danh mục chi tiêu phổ biến lên đầu và cuối
    const commonNames = ['Ăn uống', 'Mua sắm', 'Di chuyển', 'Hóa đơn', 'Lương', 'Gia dụng'];
    const primary = [];
    const secondary = [];

    for (const cat of categories) {
      if (commonNames.some((name) => (cat.namecategory || '').includes(name))) {
        primary.push(cat);
      } else {
        secondary.push(cat);
      }
    }

    const half = Math.ceil(primary.length / 2);
    const firstHalf = primary.slice(0, half);
    const secondHalf = primary.slice(half);

    return [...firstHalf, ...secondary, ...secondHalf];
  }

  /**
   * Phân loại giao dịch bằng LLM khi Tầng 1 và Tầng 2 không đạt độ tự tin cao
   * @param {string} text - Văn bản giao dịch
   * @param {Array<object>} categories - Danh sách danh mục hợp lệ của user
   * @param {object} [context={}] 
   * @returns {Promise<object|null>}
   */
  async classifyWithLLM(text, categories, context = {}) {
    if (!text || !Array.isArray(categories) || categories.length === 0) {
      return null;
    }

    // 1. Kiểm tra API Key
    const apiKey = process.env.GEMINI_API_KEY || this.geminiApiKey;
    if (!apiKey) {
      logger.debug('LLM Classifier: No GEMINI_API_KEY configured. Skipping Tier 3.');
      return null;
    }

    // 2. Chuẩn bị Context theo U-Shape
    const orderedCats = this._reorderCategoriesUshape(categories);
    const categoryCatalog = orderedCats.map((c) => ({
      id: c.idcategory,
      name: c.namecategory,
      type: c.classify || 'Chi',
      keywords: c.keyword || '',
    }));

    const systemInstruction = `Bạn là chuyên gia AI phân loại tài chính cá nhân. Nhiệm vụ của bạn là đọc nội dung giao dịch và CHỈ ĐƯỢC CHỌN DUY NHẤT 1 danh mục phù hợp nhất từ danh sách danh mục được cung cấp dưới đây.

Quy tắc bắt buộc:
1. KHÔNG ĐƯỢC TỰ BỊA ĐẶT category_id ngoài danh sách.
2. Trả về đúng định dạng JSON thuần túy (không markdown, không giải thích dài dòng).
3. Nếu hoàn toàn không thể đoán được, trả về confidence < 0.5.

Danh mục hợp lệ của người dùng:
${JSON.stringify(categoryCatalog, null, 2)}`;

    const prompt = `Giao dịch cần phân loại:
- Nội dung: "${text}"
- Đơn vị bán/Merchant: "${context.merchant || 'Không có'}"
- Số tiền: ${context.amount || 0} VND

Trả về JSON Schema:
{
  "category_id": "string (UUID từ danh sách trên)",
  "category_name": "string",
  "classify": "Chi | Thu | Vay/no",
  "confidence": 0.85,
  "reason": "Giải thích ngắn gọn"
}`;

    try {
      // 3. Gọi Google Gemini REST API
      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;
      const payload = {
        contents: [
          {
            role: 'user',
            parts: [{ text: `${systemInstruction}\n\n${prompt}` }],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 256,
          responseMimeType: 'application/json',
        },
      };

      const res = await axios.post(url, payload, { timeout: 4000 });
      const rawResponse = res.data?.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!rawResponse) return null;

      const parsed = JSON.parse(rawResponse.replace(/```json|```/g, '').trim());
      if (parsed && parsed.category_id) {
        const matchedCat = categories.find((c) => c.idcategory === parsed.category_id);
        return {
          category_id: parsed.category_id,
          category_name: matchedCat ? matchedCat.namecategory : parsed.category_name,
          category_icon: matchedCat ? matchedCat.icon : 'category',
          classify: matchedCat ? matchedCat.classify : parsed.classify || 'Chi',
          confidence: Number(parsed.confidence) || 0.85,
          tier_used: 'tier3_llm',
        };
      }
    } catch (err) {
      logger.warn('LLM Classifier: Gemini call failed or timed out', { error: err.message });
      return null;
    }

    return null;
  }
}

module.exports = new LLMClassifier();
