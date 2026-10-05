const test = require('node:test');
const assert = require('node:assert/strict');
const schedulerService = require('../../core/scheduler.service');
const paymentRepository = require('../../modules/payment/payment.repository');

test('Daily Premium Expiration Scheduler Suite', async (t) => {
  await t.test('1. runDailyPremiumExpirationTask phát cảnh báo trước 3 ngày cho tài khoản sắp hết hạn', async () => {
    const expiringDate = new Date(Date.now() + 2 * 86400000);
    const origExpiring = paymentRepository.findExpiringPremiumAccounts;
    paymentRepository.findExpiringPremiumAccounts = async () => [
      {
        idaccount: 101,
        username: 'expiring_user',
        email: 'expiring@example.com',
        premium_expires_at: expiringDate,
      },
    ];

    const origDowngrade = paymentRepository.downgradeExpiredPremiumAccounts;
    paymentRepository.downgradeExpiredPremiumAccounts = async () => [];

    const eventBus = require('../../core/event-bus');
    let capturedEvent = null;
    const origPublish = eventBus.publish;
    eventBus.publish = (eventName, payload) => {
      if (eventName === 'payment.expiring_soon') {
        capturedEvent = payload;
      }
    };

    try {
      const result = await schedulerService.runDailyPremiumExpirationTask();
      assert.ok(result, 'Task phải trả về kết quả thống kê');
      assert.strictEqual(result.warnedCount, 1);
      assert.ok(capturedEvent, 'Phải phát sự kiện payment.expiring_soon');
      assert.strictEqual(capturedEvent.idaccount, 101);
      assert.strictEqual(capturedEvent.daysRemaining, 2);
    } finally {
      paymentRepository.findExpiringPremiumAccounts = origExpiring;
      paymentRepository.downgradeExpiredPremiumAccounts = origDowngrade;
      eventBus.publish = origPublish;
    }
  });

  await t.test('2. runDailyPremiumExpirationTask hạ cấp tài khoản quá hạn về Basic và phát sự kiện payment.expired', async () => {
    const origExpiring = paymentRepository.findExpiringPremiumAccounts;
    paymentRepository.findExpiringPremiumAccounts = async () => [];

    const origDowngrade = paymentRepository.downgradeExpiredPremiumAccounts;
    paymentRepository.downgradeExpiredPremiumAccounts = async () => [
      {
        idaccount: 202,
        username: 'expired_user',
        email: 'expired@example.com',
      },
    ];

    const eventBus = require('../../core/event-bus');
    let capturedExpiredEvent = null;
    const origPublish = eventBus.publish;
    eventBus.publish = (eventName, payload) => {
      if (eventName === 'payment.expired') {
        capturedExpiredEvent = payload;
      }
    };

    try {
      const result = await schedulerService.runDailyPremiumExpirationTask();
      assert.strictEqual(result.downgradedCount, 1);
      assert.ok(capturedExpiredEvent, 'Phải phát sự kiện payment.expired');
      assert.strictEqual(capturedExpiredEvent.idaccount, 202);
    } finally {
      paymentRepository.findExpiringPremiumAccounts = origExpiring;
      paymentRepository.downgradeExpiredPremiumAccounts = origDowngrade;
      eventBus.publish = origPublish;
    }
  });
});
