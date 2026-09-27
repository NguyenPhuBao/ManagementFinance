/**
 * Circuit Breaker Pattern for LLM Gemini Service
 * Bảo vệ hệ thống khỏi cascade failure khi dịch vụ AI bên ngoài gặp sự cố
 * Trạng thái: CLOSED (Bình thường) -> OPEN (Ngắt mạch) -> HALF-OPEN (Thử nghiệm)
 */

const logger = require('../../../../../core/logger');

class CircuitBreakerOpenError extends Error {
  constructor(message = 'Circuit breaker đang ở trạng thái OPEN. Dịch vụ AI tạm thời ngắt kết nối.') {
    super(message);
    this.name = 'CircuitBreakerOpenError';
    this.statusCode = 503;
  }
}

class CircuitBreaker {
  constructor({
    failureThreshold = 5,
    cooldownPeriodMs = 30 * 1000, // 30 giây
    windowMs = 60 * 1000,         // 60 giây cửa sổ trượt
  } = {}) {
    this.failureThreshold = failureThreshold;
    this.cooldownPeriodMs = cooldownPeriodMs;
    this.windowMs = windowMs;

    this.state = 'CLOSED';
    this.failureCount = 0;
    this.lastFailureTime = 0;
    this.openedAt = 0;
  }

  /**
   * Bao bọc và thực thi tác vụ với cơ chế ngắt mạch
   * @param {Function} fn 
   * @returns {Promise<any>}
   */
  async execute(fn) {
    const now = Date.now();

    // 1. Kiểm tra nếu đang OPEN
    if (this.state === 'OPEN') {
      if (now - this.openedAt >= this.cooldownPeriodMs) {
        logger.info('[CircuitBreaker] Hết thời gian cooldown — chuyển sang trạng thái HALF-OPEN để thăm dò.');
        this.state = 'HALF-OPEN';
      } else {
        const remainingCooldownSec = Math.ceil((this.cooldownPeriodMs - (now - this.openedAt)) / 1000);
        throw new CircuitBreakerOpenError(
          `Circuit breaker đang OPEN. Dịch vụ AI đang tạm ngưng bảo vệ hệ thống. Vui lòng thử lại sau ${remainingCooldownSec}s.`
        );
      }
    }

    // 2. Thực thi hàm được bảo vệ
    try {
      const result = await fn();

      // Nếu thành công trong trạng thái HALF-OPEN -> Phục hồi về CLOSED
      if (this.state === 'HALF-OPEN') {
        logger.info('[CircuitBreaker] Tác vụ thăm dò thành công — phục hồi mạch về CLOSED.');
        this.state = 'CLOSED';
        this.failureCount = 0;
        this.openedAt = 0;
      } else if (this.state === 'CLOSED') {
        // Nếu trong cửa sổ thời gian không còn lỗi -> reset bộ đếm lỗi
        if (now - this.lastFailureTime > this.windowMs) {
          this.failureCount = 0;
        }
      }

      return result;
    } catch (error) {
      this.handleFailure(error, now);
      throw error;
    }
  }

  /**
   * Xử lý khi tác vụ gặp lỗi
   * @param {Error} error 
   * @param {number} now 
   */
  handleFailure(error, now) {
    this.lastFailureTime = now;

    if (this.state === 'HALF-OPEN') {
      logger.warn('[CircuitBreaker] Tác vụ thăm dò thất bại — ngắt mạch quay lại OPEN ngay lập tức.');
      this.state = 'OPEN';
      this.openedAt = now;
      return;
    }

    if (this.state === 'CLOSED') {
      // Nếu lỗi trước đó đã quá cửa sổ thời gian windowMs thì reset về 1
      if (now - this.lastFailureTime > this.windowMs) {
        this.failureCount = 1;
      } else {
        this.failureCount++;
      }

      logger.warn(`[CircuitBreaker] Ghi nhận lỗi LLM (${this.failureCount}/${this.failureThreshold}): ${error.message}`);

      if (this.failureCount >= this.failureThreshold) {
        this.state = 'OPEN';
        this.openedAt = now;
        logger.error(`[CircuitBreaker] Đạt ngưỡng ${this.failureThreshold} lỗi liên tiếp — CHUYỂN MẠCH SANG OPEN trong ${this.cooldownPeriodMs / 1000}s!`);
      }
    }
  }
}

// Khởi tạo instance Circuit Breaker mặc định cho Gemini Chatbot
const geminiCircuitBreaker = new CircuitBreaker({
  failureThreshold: 5,
  cooldownPeriodMs: 30 * 1000,
  windowMs: 60 * 1000,
});

module.exports = {
  CircuitBreaker,
  CircuitBreakerOpenError,
  geminiCircuitBreaker,
};
