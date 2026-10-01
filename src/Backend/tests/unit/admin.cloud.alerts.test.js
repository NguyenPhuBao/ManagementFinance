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
});
