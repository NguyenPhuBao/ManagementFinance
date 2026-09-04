const eventBus = require('../../core/event-bus');
const { emitBankTransaction, emitOcrCompleted, emitOcrDuplicate } = require('../../core/socket');
const logger = require('../../core/logger');


const notificationService = {
  /**
   * Khởi tạo các listener lắng nghe sự kiện từ EventBus
   * Tách biệt hoàn toàn xử lý thông báo khỏi Module Bank & Module OCR
   */
  async initNotificationListeners() {
    try {
      if (eventBus && typeof eventBus.subscribe === 'function') {
        // 1. Lắng nghe sự kiện biến động số dư ngân hàng
        await eventBus.subscribe('bank_transaction.pending', async (data) => {
          logger.info('[Notification Module] Received bank_transaction.pending event', {
            idtran: data.idtran,
            idaccount: data.idaccount,
            amount: data.amount,
          });
          
          // Phát thông báo Realtime Socket.io tới Client-app
          emitBankTransaction(data.idaccount, {
            idtran: data.idtran,
            amount: data.amount,
            bankName: data.bankName,
            accountNumber: data.accountNumber,
            description: data.description,
            date: data.date,
            title: 'Giao dịch mới từ Ngân hàng',
            message: `Bạn vừa có giao dịch ${data.amount > 0 ? '+' : ''}${data.amount}đ từ ${data.bankName || 'ngân hàng'}. Nhấn để duyệt và chọn danh mục.`,
            type: 'BankTransactionPending',
            createdAt: new Date().toISOString(),
          });
        });

        // 2. Lắng nghe sự kiện bóc tách và phân loại OCR hoàn tất
        await eventBus.subscribe('ocr.completed', async (data) => {
          logger.info('[Notification Module] Received ocr.completed event', {
            idaccount: data.idaccount,
            document_type: data.document_type,
            detected_type: data.detected_type,
          });

          // Phát thông báo Realtime Socket.io tới Client-app
          emitOcrCompleted(data.idaccount, {
            title: data.detected_type === 'Transfer'
              ? 'Biên lai chuyển tiền đã được bóc tách'
              : 'Hóa đơn đã được bóc tách thành công',
            message: data.detected_type === 'Transfer'
              ? `Biên lai chuyển tiền ${Number(data.amount || 0).toLocaleString('vi-VN')}đ đã sẵn sàng để xác nhận.`
              : `Hóa đơn ${data.merchant_name || ''} (${Number(data.total_amount || 0).toLocaleString('vi-VN')}đ) đã được bóc tách và phân loại.`,
            type: 'OcrCompleted',
            data: data,
            createdAt: new Date().toISOString(),
          });
        });

        // 3. Lắng nghe sự kiện giao dịch OCR bị trùng lặp
        await eventBus.subscribe('ocr.duplicate', async (data) => {
          logger.info('[Notification Module] Received ocr.duplicate event', {
            idaccount: data.idaccount,
            provider: data.provider,
            bank_tran_id: data.bank_tran_id,
            reason: data.reason,
          });

          // Phát thông báo Realtime Socket.io tới Client-app
          emitOcrDuplicate(data.idaccount, {
            title: 'Giao dịch đã tồn tại',
            message: 'Hình ảnh này trùng khớp với giao dịch đã được ghi nhận trên hệ thống trước đó.',
            type: 'OcrDuplicate',
            data: data,
            createdAt: new Date().toISOString(),
          });
        });

        logger.info('[Notification Module] Notification event listeners initialized successfully');

      }
    } catch (error) {
      logger.error('[Notification Module] Failed to initialize listeners', { error: error.message });
    }
  },

  /**
   * Phát thông báo thủ công tới 1 user
   */
  async notifyUser(idaccount, notification) {
    emitBankTransaction(idaccount, notification);
  },
};

module.exports = notificationService;
