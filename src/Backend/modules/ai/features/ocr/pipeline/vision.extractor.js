/**
 * F013 — Receipt & Bank Transfer OCR — Vision Extractor
 * Sử dụng Google Gemini 2.0 Flash Multimodal REST API (inlineData Base64)
 * Trích xuất dữ liệu có cấu trúc từ Hóa đơn (RECEIPT), Biên lai ngân hàng (BANK_TRANSFER) hoặc SMS Banking (SMS_BANKING).
 */

const axios = require('axios');
const logger = require('../../../../../core/logger');

class VisionExtractor {
  constructor() {
    this.geminiApiKey = process.env.GEMINI_API_KEY || null;
  }

  /**
   * Trích xuất thông tin tài chính từ hình ảnh
   * @param {string} imageBase64 - Chuỗi Base64 của ảnh (hoặc Data URL)
   * @param {string} [mimetype='image/jpeg'] - MIME type của ảnh
   * @param {object} [options={}] - Các tùy chọn bổ sung hoặc mock injection
   * @returns {Promise<object>} Dữ liệu trích xuất có cấu trúc
   */
  async extract(imageBase64, mimetype = 'image/jpeg', options = {}) {
    // 1. Hỗ trợ Mock Extraction cho Unit Test / TDD
    if (options._mockExtraction) {
      return options._mockExtraction;
    }

    if (!imageBase64) {
      throw Object.assign(new Error('Hình ảnh tải lên không được để trống'), {
        statusCode: 400,
        errorCode: 'IMAGE_EMPTY',
      });
    }

    // 2. Chuẩn hóa Base64 (bỏ tiền tố data:image/...;base64, nếu có)
    let cleanBase64 = imageBase64;
    let cleanMime = mimetype || 'image/jpeg';
    if (imageBase64.includes(';base64,')) {
      const parts = imageBase64.split(';base64,');
      cleanBase64 = parts[1];
      const matchMime = parts[0].match(/data:(.*?)$/);
      if (matchMime && matchMime[1]) {
        cleanMime = matchMime[1];
      }
    }

    const apiKey = process.env.GEMINI_API_KEY || this.geminiApiKey;
    if (!apiKey) {
      logger.warn('VisionExtractor: GEMINI_API_KEY is not configured');
      throw Object.assign(new Error('Chưa cấu hình GEMINI_API_KEY cho hệ thống OCR'), {
        statusCode: 500,
        errorCode: 'CONFIG_MISSING',
      });
    }

    // 3. Chuẩn bị Prompt bóc tách chuyên sâu theo chuẩn docs/AI/ORC.md
    const prompt = `Bạn là chuyên gia trích xuất tài chính và thị giác máy tính cao cấp (Financial Vision & OCR Expert).
Nhiệm vụ của bạn là phân tích hình ảnh được cung cấp (có thể là: Hóa đơn mua hàng siêu thị/nhà hàng, Biên lai chuyển khoản ngân hàng, hoặc Ảnh chụp màn hình SMS Banking).

Phân loại "document_type" vào 1 trong 3 nhóm:
- "RECEIPT": Hóa đơn mua bán hàng hóa, ăn uống, siêu thị, cửa hàng tiện lợi.
- "BANK_TRANSFER": Biên lai / ảnh chụp màn hình xác nhận chuyển khoản ngân hàng (Vietcombank, Techcombank, MBBank, Vietinbank, Momo, ZaloPay...).
- "SMS_BANKING": Tin nhắn SMS thông báo biến động số dư hoặc giao dịch từ ngân hàng.
- "UNKNOWN": Nếu ảnh hoàn toàn mờ, lóa sáng, ảnh phong cảnh, đồ vật không liên quan đến tài chính.

Quy tắc trích xuất bắt buộc:
1. Trả về định dạng JSON thuần túy (không dùng markdown codeblock, không ghi chú ngoài JSON).
2. Với "RECEIPT": Cố gắng bóc tách danh sách các mặt hàng ("items") gồm: name, quantity (số nguyên >= 1), unit_price, total_price.
3. Với "BANK_TRANSFER" hoặc "SMS_BANKING": Bắt buộc trích xuất mã giao dịch ("transaction_code" ví dụ FT..., MB..., mã GD ngân hàng) để phục vụ chống trùng.
4. "total_amount" hoặc "amount" phải là số nguyên (Number).
5. Nếu ảnh bị mờ hoặc không đọc được số tiền, trả về total_amount: 0 và document_type: "UNKNOWN".

Schema JSON yêu cầu:
{
  "document_type": "RECEIPT | BANK_TRANSFER | SMS_BANKING | UNKNOWN",
  "merchant_name": "string hoặc null",
  "merchant_address": "string hoặc null",
  "invoice_no": "string hoặc null",
  "transaction_date": "YYYY-MM-DDTHH:mm:ss.sssZ hoặc null",
  "total_amount": 0,
  "vat_amount": 0,
  "payment_method": "string hoặc null",
  "items": [
    {
      "name": "string",
      "quantity": 1,
      "unit_price": 0,
      "total_price": 0
    }
  ],
  "source_bank": "string hoặc null",
  "source_account": "string hoặc null",
  "destination_bank": "string hoặc null",
  "destination_account": "string hoặc null",
  "destination_name": "string hoặc null",
  "amount": 0,
  "transaction_code": "string hoặc null",
  "note": "string hoặc null",
  "raw_text": "Toàn bộ văn bản thô đọc được"
}`;

    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;
      const payload = {
        contents: [
          {
            role: 'user',
            parts: [
              {
                inlineData: {
                  mimeType: cleanMime,
                  data: cleanBase64,
                },
              },
              {
                text: prompt,
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 2048,
          responseMimeType: 'application/json',
        },
      };

      const res = await axios.post(url, payload, { timeout: 15000 });
      const rawText = res.data?.candidates?.[0]?.content?.parts?.[0]?.text;

      if (!rawText) {
        throw new Error('Gemini Multimodal response is empty');
      }

      const cleanedJson = rawText.replace(/```json|```/g, '').trim();
      const parsed = JSON.parse(cleanedJson);
      return parsed;
    } catch (error) {
      logger.error('VisionExtractor: Failed to extract receipt from image', { error: error.message });
      throw error;
    }
  }
}

module.exports = new VisionExtractor();
