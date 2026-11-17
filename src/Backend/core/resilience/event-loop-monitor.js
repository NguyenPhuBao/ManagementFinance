/**
 * Event Loop Lag Monitor
 * - getLag(): độ trễ tức thời của tick gần nhất (load shedding dùng).
 * - getWindowLag() / peekWindowLag(): p99 và max trong cửa sổ đo của AIOps,
 *   đo bằng perf_hooks.monitorEventLoopDelay (histogram); getWindowLag() reset histogram.
 */
const { monitorEventLoopDelay } = require('perf_hooks');

const NS_PER_MS = 1_000_000;
const RESOLUTION_MS = 20; // giá trị histogram gồm cả chu kỳ đo → trừ ra để còn phần trễ thật
const round1 = (ms) => Math.round(ms * 10) / 10;

class EventLoopMonitor {
  constructor(options = {}) {
    this.intervalMs = options.intervalMs || 500;
    this.thresholdMs = options.thresholdMs || 250; // Ngưỡng quá tải: 250ms (tránh giật cục cold-start/GC)
    this.currentLag = 0;
    this.running = false;
    this.timer = null;
    this.histogram = null;
  }

  start() {
    if (this.running) return;
    this.running = true;

    try {
      this.histogram = monitorEventLoopDelay({ resolution: RESOLUTION_MS });
      this.histogram.enable();
    } catch (_) {
      this.histogram = null;
    }

    let lastCheck = process.hrtime.bigint();

    this.timer = setInterval(() => {
      const now = process.hrtime.bigint();
      const deltaNs = Number(now - lastCheck);
      lastCheck = now;

      // Độ trễ vượt mức mong muốn của interval (chuyển đổi từ nanoseconds sang milliseconds)
      const expectedNs = this.intervalMs * NS_PER_MS;
      const lagNs = Math.max(0, deltaNs - expectedNs);
      this.currentLag = round1(lagNs / NS_PER_MS);
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
    if (this.histogram) {
      this.histogram.disable();
      this.histogram = null;
    }
    this.running = false;
  }

  getLag() {
    return this.currentLag;
  }

  /** p99 và max (ms) trong cửa sổ hiện tại, không reset. */
  peekWindowLag() {
    const h = this.histogram;
    if (!h || !h.count) return { p99Ms: 0, maxMs: 0 };
    const lag = (ns) => round1(Math.max(0, ns / NS_PER_MS - RESOLUTION_MS));
    return { p99Ms: lag(h.percentile(99)), maxMs: lag(h.max) };
  }

  /** p99 và max (ms) trong cửa sổ hiện tại, rồi reset để bắt đầu cửa sổ mới. */
  getWindowLag() {
    const out = this.peekWindowLag();
    if (this.histogram) this.histogram.reset();
    return out;
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
