/**
 * Event Loop Lag Monitor
 * Theo dõi độ trễ của vòng lặp sự kiện Node.js thời gian thực
 */

class EventLoopMonitor {
  constructor(options = {}) {
    this.intervalMs = options.intervalMs || 500;
    this.thresholdMs = options.thresholdMs || 250; // Ngưỡng quá tải: 250ms (tránh giật cục cold-start/GC)
    this.currentLag = 0;
    this.running = false;
    this.timer = null;
  }

  start() {
    if (this.running) return;
    this.running = true;

    let lastCheck = process.hrtime.bigint();

    this.timer = setInterval(() => {
      const now = process.hrtime.bigint();
      const deltaNs = Number(now - lastCheck);
      lastCheck = now;

      // Độ trễ vượt mức mong muốn của interval (chuyển đổi từ nanoseconds sang milliseconds)
      const expectedNs = this.intervalMs * 1_000_000;
      const lagNs = Math.max(0, deltaNs - expectedNs);
      this.currentLag = Math.round((lagNs / 1_000_000) * 10) / 10;
    }, this.intervalMs);

    if (this.timer.unref) {
      this.timer.unref(); // Không block tiến trình khi shutdown
    }
  }

  stop() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
    this.running = false;
  }

  getLag() {
    return this.currentLag;
  }

  isOverloaded() {
    return this.currentLag > this.thresholdMs;
  }
}

const defaultEventLoopMonitor = new EventLoopMonitor();
// Khởi chạy monitor mặc định
defaultEventLoopMonitor.start();

module.exports = {
  EventLoopMonitor,
  defaultEventLoopMonitor,
};
