/**
 * Test: Admin Cloud Alerts
 * Kiểm tra hàm checkAndAlertCloudHealth export và trả đúng shape { ramAlert, errorRateAlert }
 */
const { describe, it, before } = require('node:test');
const assert = require('node:assert');

describe('checkAndAlertCloudHealth', () => {
  before(() => {
    process.env.NODE_ENV = 'test';
    const { NotificationStore } = require('../../modules/notification/notification.store');
    const notificationService = require('../../modules/notification/notification.service');
    notificationService.setStore(new NotificationStore({ redisClient: null }));
  });

  it('should export checkAndAlertCloudHealth as a function', () => {
    const ns = require('../../modules/notification/notification.service');
    assert.strictEqual(typeof ns.checkAndAlertCloudHealth, 'function');
  });

  it('should return { ramAlert: boolean, errorRateAlert: boolean }', async () => {
    const { prisma } = require('../../config/db');
    const origCount = prisma.auditlog.count;
    prisma.auditlog.count = async () => 0;

    try {
      const { checkAndAlertCloudHealth } = require('../../modules/notification/notification.service');
      const result = await checkAndAlertCloudHealth();
      assert.ok(result, 'Result should exist');
      assert.ok('ramAlert' in result, 'Should have ramAlert');
      assert.ok('errorRateAlert' in result, 'Should have errorRateAlert');
      assert.strictEqual(typeof result.ramAlert, 'boolean');
      assert.strictEqual(typeof result.errorRateAlert, 'boolean');
    } finally {
      prisma.auditlog.count = origCount;
    }
  });

  it('2-Tier Verification: should suppress RAM alert when AIOps resource vector is toggled OFF', async () => {
    const { defaultAIOpsService } = require('../../modules/aiops/aiops.service');
    const { checkAndAlertCloudHealth } = require('../../modules/notification/notification.service');
    const os = require('os');
    const origTotal = os.totalmem;
    const origFree = os.freemem;

    // Giả lập RAM 95%
    os.totalmem = () => 1000;
    os.freemem = () => 50;

    try {
      // 1. Tắt Vector Resource
      await defaultAIOpsService.toggleVector('resource', false, false);

      // Gọi kiểm tra sức khỏe
      const result = await checkAndAlertCloudHealth();
      // Tier 2 Impact Assertion: Alert phải bị triệt tiêu hoàn toàn khi Vector bị tắt
      assert.strictEqual(result.ramAlert, false, 'RAM alert must be suppressed when resource vector is OFF');
    } finally {
      // Khôi phục lại trạng thái bật
      await defaultAIOpsService.toggleVector('resource', true, false);
      os.totalmem = origTotal;
      os.freemem = origFree;
    }
  });
});
