const os = require('os');
const logger = require('../logger');
const { getRuntimeHardwareSpecs } = require('./runtime-environment');

/**
 * SystemHardwareMonitor
 * Đo lường mức tải CPU và dung lượng RAM thực tế của máy tính mà server đang chạy
 * Hỗ trợ nhận diện tự động môi trường Cloud Container (cgroups v1/v2, Quota) vs Bare-metal Host
 * Sử dụng kỹ thuật Delta Ticks đo lường thời gian thực (Real-time CPU Usage)
 */
class SystemHardwareMonitor {
  constructor(options = {}) {
    this.intervalMs = options.intervalMs || 1000;
    this.prevCpus = null;
    this.currentCpuPercent = 0;
    this.currentRamPercent = 0;
    this.currentRamUsedMb = 0;
    this.currentRamTotalMb = 0;
    this.currentRamFreeMb = 0;
    this.currentRamRssMb = 0;
    this.timer = null;
    this.running = false;
  }

  start() {
    if (this.running) return;
    this.running = true;

    // Lấy mẫu khởi tạo ban đầu
    try {
      this.prevCpus = os.cpus();
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

  _sampleRam() {
    try {
      const specs = getRuntimeHardwareSpecs();
      const rssMb = Math.round(process.memoryUsage().rss / 1024 / 1024);
      this.currentRamRssMb = rssMb;

      if (specs.isContainer) {
        // Trong môi trường Cloud Container: Đo lường dựa trên RAM Quota của Container
        const totalMb = specs.ramTotalMb;
        const usedMb = Math.min(totalMb, rssMb);
        const freeMb = Math.max(0, totalMb - usedMb);
        this.currentRamTotalMb = totalMb;
        this.currentRamUsedMb = usedMb;
        this.currentRamFreeMb = freeMb;
        this.currentRamPercent = totalMb > 0 ? Math.min(100, Math.round((usedMb / totalMb) * 100)) : 0;
      } else {
        // Trong môi trường Local Workstation hoặc Bare-metal Host vật lý
        const total = os.totalmem();
        const free = os.freemem();
        const used = Math.max(0, total - free);
        this.currentRamTotalMb = Math.round(total / 1024 / 1024);
        this.currentRamFreeMb = Math.round(free / 1024 / 1024);
        this.currentRamUsedMb = Math.round(used / 1024 / 1024);
        this.currentRamPercent = total > 0 ? Math.round((used / total) * 100) : 0;
      }
    } catch (_) {}
  }

  _sample() {
    // 1. Đo RAM
    this._sampleRam();

    // 2. Đo CPU theo Delta Ticks tức thời
    try {
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
