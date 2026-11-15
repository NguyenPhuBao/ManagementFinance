/**
 * "Chạy liên tục" và độ khả dụng trên health / luồng metrics (kế hoạch 2026-11-15, mục 2.4; B17b, B18; Q3, Q9).
 *  - Chạy liên tục = Bây giờ − Lúc tiến trình khởi động, KHÔNG trừ bảo trì.
 *  - Khoá cũ giữ tạm với nghĩa mới: uptimeFormatted = chạy liên tục; uptimePercent = độ khả dụng tháng hiện tại.
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const adminService = require('../../modules/admin/admin.service');
const adminController = require('../../modules/admin/admin.controller');
const { defaultMaintenanceManager } = require('../../core/resilience/maintenance.manager');

describe('Chạy liên tục (Q3)', () => {
  it('B18. Đang bảo trì 1 giờ: runningSeconds vẫn bằng process.uptime(), không bị trừ', async () => {
    const saved = { active: defaultMaintenanceManager.active, activatedAt: defaultMaintenanceManager.activatedAt, uptime: process.uptime };
    defaultMaintenanceManager.active = true;
    defaultMaintenanceManager.activatedAt = new Date(Date.now() - 3600 * 1000).toISOString();
    process.uptime = () => 7200; // tiến trình đã chạy 2 giờ, trong đó 1 giờ gần nhất đang bảo trì
    try {
      const info = await adminService.buildUptimeInfo();
      assert.strictEqual(info.runningSeconds, 7200, 'không trừ 3600 giây bảo trì');
      assert.strictEqual(info.runningFormatted, '2 giờ');
      assert.ok(Math.abs(new Date(info.startedAt).getTime() - (Date.now() - 7200 * 1000)) < 2000);
    } finally {
      defaultMaintenanceManager.active = saved.active;
      defaultMaintenanceManager.activatedAt = saved.activatedAt;
      process.uptime = saved.uptime;
    }
  });

  it('Chạy dưới 1 phút ghi "dưới 1 phút" (đọc liền với "Chạy liên tục …")', async () => {
    const saved = process.uptime;
    process.uptime = () => 30;
    try {
      assert.strictEqual((await adminService.buildUptimeInfo()).runningFormatted, 'dưới 1 phút');
    } finally {
      process.uptime = saved;
    }
  });

  it('Khoá cũ giữ tạm với nghĩa mới (Q9)', async () => {
    const info = await adminService.buildUptimeInfo();
    assert.strictEqual(info.uptimeFormatted, info.runningFormatted);
    assert.strictEqual(info.uptimeSeconds, info.runningSeconds);
    assert.strictEqual(info.uptimePercent, info.availability.percent);
    assert.ok('downtimeSeconds' in info);
    assert.strictEqual(info.availability.period, 'month');
  });

  it('getSystemHealth trả uptime mới (có runningSeconds, availability)', async () => {
    const health = await adminService.getSystemHealth();
    assert.ok('runningSeconds' in health.uptime);
    assert.ok('availability' in health.uptime);
  });
});

describe('API độ khả dụng (B17b)', () => {
  const router = require('../../api/admin.routes');
  const keys = router.stack.filter((l) => l.route)
    .flatMap((l) => Object.keys(l.route.methods).map((m) => `${m.toUpperCase()} ${l.route.path}`));

  it('Có GET /system/availability, nằm sau lớp authenticate + authorize("admin") của router', () => {
    assert.ok(keys.includes('GET /system/availability'));
    const routeIdx = router.stack.findIndex((l) => l.route && l.route.path === '/system/availability');
    const guardIdx = router.stack.findIndex((l) => !l.route && l.name === 'authenticate');
    assert.ok(guardIdx >= 0 && guardIdx < routeIdx);
  });

  it('Tham số sai → 400 INVALID_PERIOD', async () => {
    let status = null;
    let body = null;
    const res = { status(c) { status = c; return this; }, json(b) { body = b; return this; } };
    await adminController.getAvailability({ query: { period: 'month', year: '2026', month: '13' } }, res);
    assert.strictEqual(status, 400);
    assert.match(JSON.stringify(body), /INVALID_PERIOD|month/);
  });
});
