/**
 * F013 — Receipt & Bank Transfer OCR — Controller
 * Tiếp nhận HTTP Request từ Client-app
 */

const ocrService = require('./ocr.service');
const logger = require('../../../../core/logger');

const ocrController = {
  /**
   * POST /api/ai/ocr/parse
   * Bóc tách và phân loại hóa đơn / biên lai từ ảnh
   */
  async handleParseReceipt(req, res, next) {
    try {
      const idaccount = req.user?.idaccount || req.user?.userId;
      if (!idaccount) {
        return res.status(401).json({ success: false, message: 'Chưa xác thực người dùng' });
      }

      const { image_base64, mimetype, _mockExtraction, _mockUser, _mockWallets } = req.body;

      if (!image_base64 && !_mockExtraction) {
        return res.status(400).json({
          success: false,
          error_code: 'IMAGE_REQUIRED',
          message: 'Vui lòng cung cấp ảnh hóa đơn dạng Base64 (image_base64)',
        });
      }

      const result = await ocrService.processReceipt(idaccount, {
        image_base64,
        mimetype,
        _mockExtraction,
        _mockUser,
        _mockWallets,
      });

      return res.status(200).json({
        success: true,
        message: result.detected_type === 'Transfer'
          ? 'Bóc tách biên lai chuyển tiền nội bộ thành công'
          : 'Bóc tách và phân loại hóa đơn thành công',
        data: result,
      });
    } catch (error) {
      if (error.statusCode === 409) {
        return res.status(409).json({
          success: false,
          error_code: error.errorCode || 'TRANSACTION_ALREADY_EXISTS',
          message: error.message || 'Giao dịch này đã được ghi nhận trên hệ thống trước đó.',
          data: error.data || null,
        });
      }

      if (error.statusCode === 422) {
        return res.status(422).json({
          success: false,
          error_code: error.errorCode || 'OCR_PARSE_FAILED',
          message: error.message || 'Không thể nhận diện thông tin hóa đơn. Ảnh có thể bị mờ hoặc thiếu thông tin.',
          raw_text: error.raw_text || '',
        });
      }

      logger.error('OCR Controller: handleParseReceipt failed', { error: error.message });
      next(error);

    }
  },
};

module.exports = ocrController;
