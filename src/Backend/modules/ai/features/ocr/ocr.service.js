/**
 * F013 — Receipt & Bank Transfer OCR — Service
 * 
 * Đảm nhiệm:
 * 1. Nhận diện hình ảnh và trích xuất dữ liệu qua VisionExtractor (Gemini Multimodal).
 * 2. Tự phục hồi dữ liệu thị giác (Self-Healing Logic): cộng dồn tiền món khi thiếu tổng tiền, fallback ngày giờ.
 * 3. Bắt lỗi HTTP 422 Unprocessable Entity khi ảnh mờ hoặc không đọc được.
 * 4. Gán nhãn Provider: 'ORC' (Hóa đơn), 'BankSync' (Biên lai ngân hàng), 'SMS' (Tin nhắn).
 * 5. Trích xuất mã giao dịch Bank_tran_id chống trùng.
 * 6. Chuyển giao dữ liệu sang Module AI Classify để phân loại 2 cấp độ.
 * 7. Phát sự kiện Realtime Notification (EventBus & Socket.io) và trả DTO chuẩn hóa cho Client-app.
 */

const visionExtractor = require('./pipeline/vision.extractor');
const dedupService = require('../dedup/dedup.service');
const classifyService = require('../classify/classify.service');
const eventBus = require('../../../../core/event-bus');
const logger = require('../../../../core/logger');

const ocrService = {
  /**
   * Xử lý trọn vẹn quy trình OCR từ ảnh tải lên
   * @param {string|number} idaccount - ID tài khoản người dùng
   * @param {object} params - { image_base64, mimetype, _mockExtraction, _mockUser, _mockWallets }
   * @returns {Promise<object>} DTO chuẩn hóa theo docs/AI/ORC.md
   */
  async processReceipt(idaccount, params = {}) {
    const { image_base64, mimetype = 'image/jpeg' } = params;

    // 1. Trích xuất dữ liệu thị giác máy tính
    const extraction = await visionExtractor.extract(image_base64, mimetype, params);

    // 2. Thuật toán Tự Phục Hồi Dữ Liệu Thị Giác (Self-Healing) & Kiểm Tra Tính Hợp Lệ
    const rawItems = Array.isArray(extraction.items) ? extraction.items : [];
    let totalAmount = Number(extraction.total_amount || extraction.amount || 0);

    // 2a. Nếu thiếu total_amount nhưng có danh sách items -> Tự động tính tổng tiền từ items
    if ((!totalAmount || totalAmount <= 0) && rawItems.length > 0) {
      totalAmount = rawItems.reduce((acc, item) => {
        const itemTotal = Number(item.total_price || (item.unit_price * item.quantity) || 0);
        return acc + itemTotal;
      }, 0);
      extraction.total_amount = totalAmount;
    }

    // 2b. Kiểm tra ngoại lệ ảnh mờ / không nhận diện được thông tin tài chính hợp lệ
    const hasValidMerchant = Boolean(extraction.merchant_name && extraction.merchant_name.trim());
    const hasValidTxCode = Boolean(extraction.transaction_code && extraction.transaction_code.trim());
    const hasItems = rawItems.length > 0;

    if (totalAmount <= 0 && !hasValidMerchant && !hasValidTxCode && !hasItems) {
      logger.warn('OCR Service: Image parse failed (blurry or non-financial content)', { idaccount });
      throw Object.assign(new Error('Không thể nhận diện thông tin hóa đơn. Ảnh có thể bị mờ hoặc thiếu thông tin.'), {
        statusCode: 422,
        errorCode: 'OCR_PARSE_FAILED',
        raw_text: extraction.raw_text || '',
      });
    }

    // 2c. Fallback ngày giao dịch nếu thiếu
    if (!extraction.transaction_date) {
      extraction.transaction_date = new Date().toISOString();
    }

    // 3. Phân loại Nguồn Tài Liệu & Gán Nhãn Provider, Bank_tran_id
    const docType = extraction.document_type || 'RECEIPT';
    let provider = 'ORC';
    let bankTranId = null;

    if (docType === 'BANK_TRANSFER') {
      provider = 'BankSync';
      bankTranId = extraction.transaction_code || null;
    } else if (docType === 'SMS_BANKING') {
      provider = 'SMS';
      bankTranId = extraction.transaction_code || null;
    } else {
      provider = 'ORC';
      bankTranId = extraction.invoice_no || null;
    }

    // 3.5. Bộ Khử Trùng Lặp CSDL (AI Deduplication Engine)
    // Chặn đứng xử lý NGAY LẬP TỨC nếu đã tồn tại giao dịch, TUYỆT ĐỐI KHÔNG gọi Classify AI
    const dupCheck = await dedupService.checkDuplicate(idaccount, extraction, provider, bankTranId, params);
    if (dupCheck && dupCheck.is_duplicate) {
      logger.warn('OCR Service: Duplicate transaction detected, stopping pipeline before classify', {
        idaccount,
        provider,
        bankTranId,
        reason: dupCheck.reason,
      });

      // Phát sự kiện realtime thông báo trùng lặp
      try {
        if (eventBus && typeof eventBus.publish === 'function') {
          eventBus.publish('ocr.duplicate', {
            idaccount: Number(idaccount),
            provider,
            bank_tran_id: bankTranId,
            reason: dupCheck.reason,
            existing_transaction: dupCheck.existing_transaction,
            timestamp: new Date().toISOString(),
          });
        }
      } catch (eventErr) {
        logger.warn('OCR Service: Failed to publish ocr.duplicate event', { error: eventErr.message });
      }

      // Ném lỗi HTTP 409 Conflict - DỪNG QUY TRÌNH NGAY LẬP TỨC!
      const dupError = new Error('Giao dịch này đã được ghi nhận trên hệ thống trước đó.');
      dupError.statusCode = 409;
      dupError.errorCode = 'TRANSACTION_ALREADY_EXISTS';
      dupError.data = {
        is_duplicate: true,
        reason: dupCheck.reason,
        provider,
        bank_tran_id: bankTranId,
        existing_transaction: dupCheck.existing_transaction,
      };
      throw dupError;
    }

    // 4. Chuyển giao dữ liệu sang Module AI Classify để phân loại 2 cấp độ (CHỈ KHI CHƯA TRÙNG)
    const classifiedResult = await classifyService.classifyExtractedReceipt(idaccount, extraction, params);


    // Gắn chính xác provider và bank_tran_id vào DTO phản hồi
    classifiedResult.provider = provider;
    classifiedResult.bank_tran_id = bankTranId;

    // 5. Kích hoạt Sự Kiện Thông Báo Realtime (Notification Event)
    try {
      if (eventBus && typeof eventBus.publish === 'function') {
        eventBus.publish('ocr.completed', {
          idaccount: Number(idaccount),
          provider,
          document_type: classifiedResult.document_type,
          detected_type: classifiedResult.detected_type,
          bank_tran_id: bankTranId,
          total_amount: totalAmount,
          amount: totalAmount,
          merchant_name: extraction.merchant_name || null,
          options: classifiedResult.options || null,
          option_single: classifiedResult.option_single || null,
          option_grouped: classifiedResult.option_grouped || null,
          invoice_info: classifiedResult.invoice_info || null,
          transfer_details: classifiedResult.transfer_details || null,
          transaction_info: classifiedResult.transaction_info || null,
          timestamp: new Date().toISOString(),
        });
      }
    } catch (eventErr) {

      logger.warn('OCR Service: Failed to publish ocr.completed event', { error: eventErr.message });
    }

    logger.info('OCR Service: Receipt processed and classified successfully', {
      idaccount,
      document_type: classifiedResult.document_type,
      detected_type: classifiedResult.detected_type,
      provider,
      bank_tran_id: bankTranId,
    });

    return classifiedResult;
  },
};

module.exports = ocrService;
