const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');

test('Payment API Controller & Routes Suite', async (t) => {
  const paymentService = require('../../modules/payment/payment.service');
  const paymentController = require('../../modules/payment/payment.controller');

  await t.test('1. createOrder controller trả về HTTP 201 kèm dữ liệu đơn hàng', async () => {
    const origCreate = paymentService.createPremiumOrder;
    paymentService.createPremiumOrder = async (idaccount, data) => ({
      orderId: 'uuid-123',
      orderCode: 987654,
      amount: 49000,
      checkoutUrl: 'https://pay.payos.vn/web/mock',
    });

    const req = {
      user: { idaccount: 15 },
      body: { packageType: 'PREMIUM_1_MONTH' },
    };

    let statusCode = null;
    let jsonBody = null;
    const res = {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        jsonBody = data;
        return this;
      },
    };

    try {
      await paymentController.createOrder(req, res, (err) => {
        if (err) throw err;
      });

      assert.strictEqual(statusCode, 201);
      assert.strictEqual(jsonBody.success, true);
      assert.strictEqual(jsonBody.data.orderCode, 987654);
      assert.strictEqual(jsonBody.data.checkoutUrl, 'https://pay.payos.vn/web/mock');
    } finally {
      paymentService.createPremiumOrder = origCreate;
    }
  });

  await t.test('2. handleWebhook controller trả về HTTP 200 khi webhook thành công', async () => {
    const origWebhook = paymentService.handlePayOSWebhook;
    paymentService.handlePayOSWebhook = async () => ({
      success: true,
      message: 'Kích hoạt gói Premium thành công',
    });

    const req = {
      body: { code: '00', data: { orderCode: 987654 }, signature: 'mock-sig' },
    };

    let statusCode = null;
    let jsonBody = null;
    const res = {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        jsonBody = data;
        return this;
      },
    };

    try {
      await paymentController.handleWebhook(req, res, (err) => {
        if (err) throw err;
      });

      assert.strictEqual(statusCode, 200);
      assert.strictEqual(jsonBody.success, true);
    } finally {
      paymentService.handlePayOSWebhook = origWebhook;
    }
  });

  await t.test('3. getSubscriptionInfo controller trả về thông tin subscription của user', async () => {
    const origSub = paymentService.getSubscriptionInfo;
    paymentService.getSubscriptionInfo = async (idaccount) => ({
      accountType: 'Premium',
      premiumExpiresAt: '2026-11-05T00:00:00.000Z',
      daysRemaining: 30,
      isExpired: false,
    });

    const req = {
      user: { idaccount: 15 },
    };

    let statusCode = null;
    let jsonBody = null;
    const res = {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        jsonBody = data;
        return this;
      },
    };

    try {
      await paymentController.getSubscriptionInfo(req, res, (err) => {
        if (err) throw err;
      });

      assert.strictEqual(statusCode, 200);
      assert.strictEqual(jsonBody.data.accountType, 'Premium');
      assert.strictEqual(jsonBody.data.daysRemaining, 30);
    } finally {
      paymentService.getSubscriptionInfo = origSub;
    }
  });
});
