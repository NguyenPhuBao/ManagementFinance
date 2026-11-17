const os = require('os');
const logger = require('../logger');
const { getRuntimeHardwareSpecs } = require('./runtime-environment');

/**
 * SystemHardwareMonitor
 * Đo lường mức tải CPU và dung lượng RAM thực tế của máy tính mà server đang chạy
 * Hỗ trợ nhận diện tự động môi trường Cloud Container (cgroups v1/v2, Quota) vs Bare-metal Host
 * Trong Container: Đo lường CPU % tiến trình dựa trên Quota phân bổ (chống sai lệch do các tenant khác trên host)
 * Trên Bare-metal: Đo lường Delta Ticks phần cứng toàn máy
 */
class SystemHardwareMonitor {
  constructor(options = {}) {
    this.intervalMs = options.intervalMs || 1000;
    this.prevCpus = null;
    this.prevCpuUsage = null;
    this.prevCpuTime = null;
    this.currentCpuPercent = 0;
    this.currentRamPercent = 0;
    this.currentRamUsedMb = 0;
    this.currentRamTotalMb = 0;
    this.currentRamFreeMb = 0;
    this.currentRamRssMb = 0;
    this.currentHostRamPercent = 0;
    this.specsProvider = options.specsProvider || getRuntimeHardwareSpecs;
    this.memoryUsage = options.memoryUsage || (() => process.memoryUsage());
    this.timer = null;
    this.running = false;
  }

  start() {
    if (this.running) return;
    this.running = true;

    // Lấy mẫu khởi tạo ban đầu
    try {
      this.prevCpus = os.cpus();
      this.prevCpuUsage = process.cpuUsage();
      this.prevCpuTime = Date.now();
      this._sampleRam();
    } catch (_) {}

    this.timer = setInterval(() => {
      this._sample();
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

  /**
   * RAM tiến trình = RSS / hạn mức bộ nhớ × 100.
   * Hạn mức = quota container nếu có, ngược lại = tổng RAM máy (specs.ramTotalMb).
   * RAM toàn máy giữ ở currentHostRamPercent để tham khảo, không dùng để chấm điểm.
   */
  _sampleRam() {
    try {
      const specs = this.specsProvider();
      const rssMb = Math.round(this.memoryUsage().rss / 1024 / 1024);
      const totalMb = specs.ramTotalMb || Math.round(os.totalmem() / 1024 / 1024);
      const usedMb = Math.min(totalMb, rssMb);
      this.currentRamRssMb = rssMb;
      this.currentRamTotalMb = totalMb;
      this.currentRamUsedMb = usedMb;
      this.currentRamFreeMb = Math.max(0, totalMb - usedMb);
      this.currentRamPercent = totalMb > 0 ? Math.min(100, Math.round((usedMb / totalMb) * 100)) : 0;
      const hostTotal = os.totalmem();
      this.currentHostRamPercent = hostTotal > 0 ? Math.round(((hostTotal - os.freemem()) / hostTotal) * 100) : 0;
    } catch (_) {}
  }

  _sample() {
    // 1. Đo RAM
    this._sampleRam();

    // 2. Đo CPU
    try {
      const specs = getRuntimeHardwareSpecs();

      if (specs.isContainer) {
        // Trong môi trường Container (Docker/Render/K8s/Cloud):
        // /proc/stat là của toàn bộ máy chủ vật lý dùng chung (shared host 8 cores chứa hàng chục container khác)
        // Đo CPU bằng process.cpuUsage() so với Quota cores phân bổ của container này
        const now = Date.now();
        const elapsedMs = Math.max(1, now - (this.prevCpuTime || (now - this.intervalMs)));

        if (this.prevCpuUsage) {
          const diff = process.cpuUsage(this.prevCpuUsage);
          const totalProcessMicros = diff.user + diff.system;
          const cores = specs.cpuCores > 0 ? specs.cpuCores : 1;
          const availableMicros = elapsedMs * 1000 * cores;

          if (availableMicros > 0) {
            const pct = Math.round((totalProcessMicros / availableMicros) * 100);
            this.currentCpuPercent = Math.max(0, Math.min(100, pct));
          }
        }

        this.prevCpuUsage = process.cpuUsage();
        this.prevCpuTime = now;
      } else {
        // Trên máy chủ vật lý riêng biệt hoặc máy phát triển cục bộ:
        // Đo lường tổng thể hệ điều hành theo Delta Ticks của tất cả CPU cores
        const currCpus = os.cpus();
        if (!this.prevCpus || !currCpus || this.prevCpus.length !== currCpus.length) {
          this.prevCpus = currCpus;
          return;
        }

        let totalDelta = 0;
        let idleDelta = 0;

        for (let i = 0; i < currCpus.length; i++) {
          const prevTimes = this.prevCpus[i].times;
          const currTimes = currCpus[i].times;

          const prevTotal = Object.values(prevTimes).reduce((a, b) => a + b, 0);
          const currTotal = Object.values(currTimes).reduce((a, b) => a + b, 0);

          totalDelta += (currTotal - prevTotal);
          idleDelta += (currTimes.idle - prevTimes.idle);
        }

        this.prevCpus = currCpus;

        if (totalDelta > 0) {
          const activeDelta = totalDelta - idleDelta;
          const pct = Math.round((activeDelta / totalDelta) * 100);
          this.currentCpuPercent = Math.max(0, Math.min(100, pct));
        }
      }
    } catch (_) {}
  }

  getCpuPercent() {
    return this.currentCpuPercent;
  }

  getRamPercent() {
    this._sampleRam();
    return this.currentRamPercent;
  }

  getRamUsedMb() {
    this._sampleRam();
    return this.currentRamUsedMb;
  }

  getRamTotalMb() {
    this._sampleRam();
    return this.currentRamTotalMb;
  }

  getRamFreeMb() {
    this._sampleRam();
    return this.currentRamFreeMb;
  }

  getRamRssMb() {
    this._sampleRam();
    return this.currentRamRssMb;
  }

  getMetrics() {
    this._sampleRam();
    const specs = getRuntimeHardwareSpecs();
    const cpus = os.cpus() || [];
    return {
      environment: {
        mode: specs.mode,
        provider: specs.provider,
        isContainer: specs.isContainer,
        source: specs.source,
      },
      cpu: {
        cores: specs.cpuCores || cpus.length || 1,
        model: cpus[0]?.model || 'Generic CPU',
        percent: this.currentCpuPercent,
      },
      ram: {
        totalMb: this.currentRamTotalMb,
        usedMb: this.currentRamUsedMb,
        freeMb: this.currentRamFreeMb,
        percent: this.currentRamPercent,
        rssMb: this.currentRamRssMb,
        hostPercent: this.currentHostRamPercent,
      },
      process: {
        uptimeSeconds: Math.floor(process.uptime()),
        memoryRssMb: Math.round(process.memoryUsage().rss / 1024 / 1024),
        heapUsedMb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
      },
    };
  }
}

const defaultSystemHardwareMonitor = new SystemHardwareMonitor();
defaultSystemHardwareMonitor.start();

module.exports = {
  SystemHardwareMonitor,
  defaultSystemHardwareMonitor,
};
