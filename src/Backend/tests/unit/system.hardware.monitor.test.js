/**
 * Test: System Hardware Monitor (Tier 2: Real System Impact & Hardware Metrics Verification)
 * Đảm bảo chỉ số CPU & RAM đo trực tiếp từ phần cứng máy chủ thật, không gán cứng giá trị giả lập
 */
const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const os = require('os');
const {
  SystemHardwareMonitor,
  defaultSystemHardwareMonitor,
} = require('../../core/resilience/system-hardware-monitor');

describe('SystemHardwareMonitor - Real Hardware Measurement', () => {
  it('defaultSystemHardwareMonitor should return valid hardware metrics of the host machine', () => {
    const metrics = defaultSystemHardwareMonitor.getMetrics();

    assert.ok(metrics, 'Metrics object must exist');
    assert.ok(metrics.cpu, 'cpu metrics must exist');
    assert.ok(metrics.ram, 'ram metrics must exist');

    // CPU validation
    assert.strictEqual(typeof metrics.cpu.cores, 'number');
    assert.ok(metrics.cpu.cores >= 1, 'Server host must have at least 1 CPU core');
    assert.strictEqual(metrics.cpu.cores, os.cpus().length, 'Core count must match os.cpus().length');
    assert.strictEqual(typeof metrics.cpu.percent, 'number');
    assert.ok(metrics.cpu.percent >= 0 && metrics.cpu.percent <= 100, 'CPU percent must be between 0 and 100%');

    // RAM validation
    assert.strictEqual(typeof metrics.ram.totalMb, 'number');
    assert.ok(metrics.ram.totalMb > 512, 'Total RAM must be greater than 512 MB');
    assert.strictEqual(typeof metrics.ram.usedMb, 'number');
    assert.ok(metrics.ram.usedMb >= 0, 'Used RAM must be non-negative');
    assert.strictEqual(typeof metrics.ram.freeMb, 'number');
    assert.ok(metrics.ram.freeMb >= 0, 'Free RAM must be non-negative');
    assert.strictEqual(typeof metrics.ram.percent, 'number');
    assert.ok(metrics.ram.percent >= 0 && metrics.ram.percent <= 100, 'RAM percent must be between 0 and 100%');
    assert.strictEqual(typeof metrics.ram.rssMb, 'number');
    assert.ok(metrics.ram.rssMb > 0, 'Node.js RSS memory must be greater than 0');

    // Mathematical consistency check (total = used + free within 5MB rounding margin)
    const sum = metrics.ram.usedMb + metrics.ram.freeMb;
    const diff = Math.abs(sum - metrics.ram.totalMb);
    assert.ok(diff <= 5, `Used + Free (${sum}) must equal Total (${metrics.ram.totalMb}) within 5MB margin`);
  });

  it('getRamPercent should compute real RAM usage accurately from os.totalmem and os.freemem', () => {
    const totalMem = os.totalmem();
    const freeMem = os.freemem();
    const expectedPercent = Math.round(((totalMem - freeMem) / totalMem) * 100);

    const actualPercent = defaultSystemHardwareMonitor.getRamPercent();
    // Sai số tối đa 2% do chênh lệch thời điểm gọi hàm nano giây
    assert.ok(
      Math.abs(actualPercent - expectedPercent) <= 2,
      `Calculated RAM percent ${actualPercent}% must be close to host ${expectedPercent}%`
    );
  });

  it('SystemHardwareMonitor instance computes delta CPU ticks between samples', async () => {
    const monitor = new SystemHardwareMonitor({ sampleIntervalMs: 50 });
    monitor.start();

    // Lần đầu lấy metrics
    const m1 = monitor.getMetrics();
    assert.ok(m1.cpu.cores >= 1);

    // Chờ 120ms để monitor tick ít nhất 2 lần và tính delta CPU
    await new Promise((resolve) => setTimeout(resolve, 120));

    const m2 = monitor.getMetrics();
    assert.strictEqual(typeof m2.cpu.percent, 'number');
    assert.ok(m2.cpu.percent >= 0 && m2.cpu.percent <= 100);

    monitor.stop();
  });
});
