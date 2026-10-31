/**
 * Test: Admin System Health
 * Kiểm tra hàm getSystemHealth trả đúng shape với tất cả 6 trường metric
 */
const { describe, it } = require('node:test');
const assert = require('node:assert');
const adminService = require('../../modules/admin/admin.service');

describe('getSystemHealth', () => {
  it('should return all health metric fields', async () => {
    const result = await adminService.getSystemHealth();
    assert.ok(result, 'Result should exist');
    assert.ok('cpu' in result, 'Should have cpu');
    assert.ok('ram' in result, 'Should have ram');
    assert.ok('eventLoop' in result, 'Should have eventLoop');
    assert.ok('dbPool' in result, 'Should have dbPool');
    assert.ok('maintenance' in result, 'Should have maintenance');
    assert.ok('loadShedding' in result, 'Should have loadShedding');
    assert.ok('uptime' in result, 'Should have uptime');
    assert.ok('timestamp' in result, 'Should have timestamp');
    assert.strictEqual(typeof result.ram.usedMb, 'number');
    assert.strictEqual(typeof result.eventLoop.lagMs, 'number');
    assert.strictEqual(typeof result.maintenance.active, 'boolean');
    assert.strictEqual(typeof result.uptime.uptimePercent, 'number');
    assert.ok(result.uptime.uptimePercent >= 0 && result.uptime.uptimePercent <= 100);
    assert.strictEqual(typeof result.uptime.uptimeFormatted, 'string');
  });

  it('cpu.percent should be between 0 and 100', async () => {
    const result = await adminService.getSystemHealth();
    assert.ok(result.cpu.percent >= 0, 'cpu.percent >= 0');
    assert.ok(result.cpu.percent <= 100, 'cpu.percent <= 100');
  });

  it('ram.percent should be between 0 and 100', async () => {
    const result = await adminService.getSystemHealth();
    assert.ok(result.ram.percent >= 0, 'ram.percent >= 0');
    assert.ok(result.ram.percent <= 100, 'ram.percent <= 100');
  });

  it('dbPool should have client and admin connection stats', async () => {
    const result = await adminService.getSystemHealth();
    assert.strictEqual(typeof result.dbPool.clientActive, 'number');
    assert.strictEqual(typeof result.dbPool.clientLimit, 'number');
    assert.strictEqual(typeof result.dbPool.adminActive, 'number');
    assert.strictEqual(typeof result.dbPool.maxConnections, 'number');
  });

  it('loadShedding.shedCount24h should be a non-negative number', async () => {
    const result = await adminService.getSystemHealth();
    assert.strictEqual(typeof result.loadShedding.shedCount24h, 'number');
    assert.ok(result.loadShedding.shedCount24h >= 0);
  });

  it('should return environment metadata and accurate cpu cores (Tier 2 System Impact)', async () => {
    const result = await adminService.getSystemHealth();
    assert.ok(result.environment, 'Should return environment metadata object');
    assert.strictEqual(typeof result.environment.mode, 'string');
    assert.strictEqual(typeof result.environment.isContainer, 'boolean');
    assert.strictEqual(typeof result.environment.provider, 'string');
    assert.strictEqual(typeof result.cpu.cores, 'number');
    assert.ok(result.cpu.cores > 0, 'cpu.cores must be a positive number');
  });
});
