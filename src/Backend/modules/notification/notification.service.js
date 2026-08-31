const eventBus = require('../../core/event-bus');
const { emitBankTransaction } = require('../../core/socket');
const logger = require('../../core/logger');

const notificationService = {
  /**
   * Khởi tạo các listener lắng nghe sự kiện từ EventBus
   * Tách biệt hoàn toàn xử lý thông báo khỏi Module Bank
   */
  async initNotificationListeners() {
    try {
      if (eventBus && typeof eventBus.subscribe === 'function') {
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
