const test = require('node:test');
const assert = require('node:assert/strict');
const { prisma } = require('../../config/db');
const paymentRepository = require('../../modules/payment/payment.repository');
const paymentService = require('../../modules/payment/payment.service');
const paymentController = require('../../modules/payment/payment.controller');

test('Admin Payment Management & Reconciliation Suite', async (t) => {
  await t.test('1. Tầng 1: paymentController.getOrdersForAdmin trả về HTTP 200 kèm danh sách đơn hàng', async () => {
    const origGetOrders = paymentService.getOrdersForAdmin;
    paymentService.getOrdersForAdmin = async (options) => ({
      total: 2,
      page: 1,
      limit: 20,
      totalPages: 1,
      items: [
        {
          id: 'ord-1',
          order_code: 1001,
          package_type: 'PREMIUM_1_MONTH',
          amount: 49000,
          status: 'PAID',
          account: {
            username: 'user_a',
            email: 'a@example.com',
            User: { fullname: 'Nguyen Van A' },
          },
        },
      ],
    });

    const req = {
      query: { page: '1', limit: '20', search: 'user_a', status: 'PAID' },
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
      await paymentController.getOrdersForAdmin(req, res, (err) => {
        if (err) throw err;
      });

      assert.strictEqual(statusCode, 200);
      assert.strictEqual(jsonBody.success, true);
      assert.strictEqual(jsonBody.data.total, 2);
      assert.strictEqual(jsonBody.data.items.length, 1);
      assert.strictEqual(jsonBody.data.items[0].order_code, 1001);
      assert.strictEqual(jsonBody.data.items[0].account.username, 'user_a');
    } finally {
      paymentService.getOrdersForAdmin = origGetOrders;
    }
  });

  await t.test('2. Tầng 1: paymentController.getPaymentStatsForAdmin trả về chỉ số KPI doanh thu & đơn hàng', async () => {
    const origGetStats = paymentService.getPaymentStatsForAdmin;
    paymentService.getPaymentStatsForAdmin = async () => ({
      totalRevenue: 490000,
      totalOrders: 10,
      paidOrders: 8,
      pendingOrders: 1,
      cancelledOrders: 1,
      expiredOrders: 0,
      successRate: 80,
    });

    const req = { query: {} };
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
      await paymentController.getPaymentStatsForAdmin(req, res, (err) => {
        if (err) throw err;
      });

      assert.strictEqual(statusCode, 200);
      assert.strictEqual(jsonBody.success, true);
      assert.strictEqual(jsonBody.data.totalRevenue, 490000);
      assert.strictEqual(jsonBody.data.totalOrders, 10);
      assert.strictEqual(jsonBody.data.paidOrders, 8);
      assert.strictEqual(jsonBody.data.successRate, 80);
    } finally {
      paymentService.getPaymentStatsForAdmin = origGetStats;
    }
  });

  await t.test('3. Tầng 1: paymentController.getOrderDetailForAdmin trả về 404 khi không tìm thấy đơn', async () => {
    const origGetDetail = paymentService.getOrderDetailForAdmin;
    paymentService.getOrderDetailForAdmin = async (id) => {
      const err = new Error('Không tìm thấy đơn hàng');
      err.statusCode = 404;
      throw err;
    };

    const req = { params: { id: 'non-existent-id' } };
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
      await paymentController.getOrderDetailForAdmin(req, res, (err) => {
        if (err) throw err;
      });

      assert.strictEqual(statusCode, 404);
      assert.strictEqual(jsonBody.success, false);
    } finally {
      paymentService.getOrderDetailForAdmin = origGetDetail;
    }
  });

  await t.test('4. Tầng 2: paymentRepository.findOrdersForAdmin xây dựng truy vấn lọc và sanitize BigInt chuẩn xác', async () => {
    const origCount = prisma.payment_order.count;
    const origFindMany = prisma.payment_order.findMany;

    let capturedWhere = null;
    let capturedSkip = null;
    let capturedTake = null;

    prisma.payment_order.count = async ({ where }) => {
      capturedWhere = where;
      return 1;
    };

    prisma.payment_order.findMany = async ({ where, skip, take, orderBy }) => {
      capturedSkip = skip;
      capturedTake = take;
      return [
        {
          id: 'order-uuid-mock',
          idaccount: 10,
          order_code: BigInt(998877),
          package_type: 'PREMIUM_1_MONTH',
          amount: { toNumber: () => 49000 },
          currency: 'VND',
          status: 'PAID',
          created_at: new Date('2026-10-15T10:00:00.000Z'),
          account: {
            idaccount: 10,
            username: 'testuser',
            email: 'test@pfm.vn',
            type: 'Premium',
            status: 'Active',
            User: {
              fullname: 'Nguyen Test User',
            },
          },
        },
      ];
    };

    try {
      const result = await paymentRepository.findOrdersForAdmin({
        page: 2,
        limit: 10,
        search: 'testuser',
        status: 'PAID',
        packageType: 'PREMIUM_1_MONTH',
        fromDate: '2026-10-01',
        toDate: '2026-10-15',
      });

      assert.strictEqual(capturedSkip, 10);
      assert.strictEqual(capturedTake, 10);
      assert.strictEqual(capturedWhere.status, 'PAID');
      assert.strictEqual(capturedWhere.package_type, 'PREMIUM_1_MONTH');
      assert.ok(capturedWhere.created_at.gte instanceof Date);
      assert.ok(capturedWhere.created_at.lte instanceof Date);
      assert.ok(Array.isArray(capturedWhere.OR));

      assert.strictEqual(result.total, 1);
      assert.strictEqual(result.page, 2);
      assert.strictEqual(result.items.length, 1);
      // Kiểm tra sanitize BigInt thành Number
      assert.strictEqual(typeof result.items[0].order_code, 'number');
      assert.strictEqual(result.items[0].order_code, 998877);
      assert.strictEqual(result.items[0].amount, 49000);
      assert.strictEqual(result.items[0].account.User.fullname, 'Nguyen Test User');
    } finally {
      prisma.payment_order.count = origCount;
      prisma.payment_order.findMany = origFindMany;
    }
  });

  await t.test('5. Tầng 2: paymentRepository.getPaymentSummaryStats tính đúng tổng doanh thu và tỷ lệ thành công', async () => {
    const origCount = prisma.payment_order.count;
    const origAggregate = prisma.payment_order.aggregate;

    prisma.payment_order.count = async ({ where }) => {
      if (where.status === 'PAID') return 8;
      if (where.status === 'PENDING') return 1;
      if (where.status === 'CANCELLED') return 1;
      if (where.status === 'EXPIRED') return 0;
      return 10; // Tổng số đơn
    };

    prisma.payment_order.aggregate = async () => ({
      _sum: {
        amount: { toNumber: () => 392000 },
      },
    });

    try {
      const stats = await paymentRepository.getPaymentSummaryStats();
      assert.strictEqual(stats.totalOrders, 10);
      assert.strictEqual(stats.paidOrders, 8);
      assert.strictEqual(stats.pendingOrders, 1);
      assert.strictEqual(stats.cancelledOrders, 1);
      assert.strictEqual(stats.expiredOrders, 0);
      assert.strictEqual(stats.totalRevenue, 392000);
      assert.strictEqual(stats.successRate, 80);
    } finally {
      prisma.payment_order.count = origCount;
      prisma.payment_order.aggregate = origAggregate;
    }
  });

  await t.test('6. Tầng 2: paymentRepository.getOrderDetailForAdmin lấy chi tiết kèm giao dịch webhook đối soát', async () => {
    const origFindUnique = prisma.payment_order.findUnique;

    prisma.payment_order.findUnique = async ({ where }) => {
      if (where.id === 'order-123') {
        return {
          id: 'order-123',
          order_code: BigInt(888999),
          package_type: 'PREMIUM_1_MONTH',
          amount: { toNumber: () => 49000 },
          status: 'PAID',
          account: {
            idaccount: 20,
            username: 'vip_user',
            email: 'vip@pfm.vn',
            User: { fullname: 'VIP User' },
          },
          payment_transaction: [
            {
              id: 'tx-1',
              payos_transaction_id: 'payos-tx-999',
              amount: { toNumber: () => 49000 },
              bank_code: 'NCB',
              signature_verified: true,
              transaction_time: new Date('2026-10-15T12:00:00.000Z'),
            },
          ],
        };
      }
      return null;
    };

    try {
      const detail = await paymentRepository.getOrderDetailForAdmin('order-123');
      assert.ok(detail);
      assert.strictEqual(detail.id, 'order-123');
      assert.strictEqual(detail.order_code, 888999);
      assert.strictEqual(detail.payment_transaction.length, 1);
      assert.strictEqual(detail.payment_transaction[0].bank_code, 'NCB');
      assert.strictEqual(detail.payment_transaction[0].amount, 49000);

      const notFound = await paymentRepository.getOrderDetailForAdmin('unknown');
      assert.strictEqual(notFound, null);
    } finally {
      prisma.payment_order.findUnique = origFindUnique;
    }
  });

  await t.test('7. Tầng 2: paymentRepository.createSampleOrder sinh đơn mẫu, mã QR chuẩn VietQR và transaction', async () => {
    const origFindUnique = prisma.account.findUnique;
    const origFindFirst = prisma.account.findFirst;
    const origCreateOrder = prisma.payment_order.create;
    const origCreateTx = prisma.payment_transaction.create;

    prisma.account.findFirst = async () => ({ idaccount: 15, username: 'testuser' });
    let createdOrderData = null;
    let createdTxData = null;

    prisma.payment_order.create = async ({ data, include }) => {
      createdOrderData = data;
      return {
        ...data,
        amount: { toNumber: () => Number(data.amount) },
        account: {
          idaccount: data.idaccount,
          username: 'testuser',
          User: { fullname: 'Nguyen Test' },
        },
      };
    };

    prisma.payment_transaction.create = async ({ data }) => {
      createdTxData = data;
      return data;
    };

    try {
      const sample = await paymentRepository.createSampleOrder({
        simulateWebhook: true,
        packageType: 'PREMIUM_1_MONTH',
        amount: 49000,
      });

      assert.ok(sample);
      assert.strictEqual(sample.status, 'PAID');
      assert.strictEqual(sample.amount, 49000);
      assert.strictEqual(sample.qr_url, null); // Theo yêu cầu bảo vệ CSDL: Đơn đã thanh toán (PAID) phải xóa QR tránh chuyển khoản trùng
      assert.ok(createdTxData);
      assert.strictEqual(createdTxData.bank_code, 'MBBANK');
      assert.strictEqual(createdTxData.signature_verified, true);
    } finally {
      prisma.account.findUnique = origFindUnique;
      prisma.account.findFirst = origFindFirst;
      prisma.payment_order.create = origCreateOrder;
      prisma.payment_transaction.create = origCreateTx;
    }
  });

  await t.test('8. Tầng 1: paymentController.createSampleOrder trả về HTTP 201', async () => {
    const origSample = paymentService.createSampleOrder;
    paymentService.createSampleOrder = async () => ({
      id: 'sample-1',
      order_code: 998811,
      status: 'PAID',
      qr_url: 'https://img.vietqr.io/image/970422-0987654321-compact2.png',
    });

    const req = { body: { simulateWebhook: true } };
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
      await paymentController.createSampleOrder(req, res, (err) => {
        if (err) throw err;
      });

      assert.strictEqual(statusCode, 201);
      assert.strictEqual(jsonBody.success, true);
      assert.strictEqual(jsonBody.data.order_code, 998811);
    } finally {
      paymentService.createSampleOrder = origSample;
    }
  });

  await t.test('9. Tầng 2: paymentRepository.getOrCreatePayosQr sinh mã QR và link thanh toán trực tiếp từ kênh PayOS thật', async () => {
    const qrData = await paymentRepository.getOrCreatePayosQr({ amount: 49000, packageType: 'PREMIUM_1_MONTH' });
    assert.ok(qrData);
    assert.strictEqual(qrData.accountNumber, '2512070399999');
    assert.strictEqual(qrData.accountName, 'NGUYEN PHU BAO');
    assert.strictEqual(qrData.bin, '970422');
    assert.strictEqual(qrData.amount, 49000);
    assert.ok(qrData.qrUrl.includes('2512070399999'));
    assert.ok(qrData.checkoutUrl);
  });

  await t.test('10. Tầng 1: paymentController.getPayosQr trả về HTTP 200 kèm thông tin PayOS', async () => {
    const origGetPayosQr = paymentService.getOrCreatePayosQr;
    paymentService.getOrCreatePayosQr = async () => ({
      orderCode: 123456,
      amount: 49000,
      accountNumber: '2512070399999',
      accountName: 'NGUYEN PHU BAO',
      checkoutUrl: 'https://pay.payos.vn/web/123456',
      qrUrl: 'https://img.vietqr.io/image/970422-2512070399999-compact2.png',
    });

    const req = { query: { amount: '49000' } };
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
      await paymentController.getPayosQr(req, res, (err) => {
        if (err) throw err;
      });
      assert.strictEqual(statusCode, 200);
      assert.strictEqual(jsonBody.success, true);
      assert.strictEqual(jsonBody.data.accountNumber, '2512070399999');
    } finally {
      paymentService.getOrCreatePayosQr = origGetPayosQr;
    }
  });

  await t.test('11. Tầng 2: paymentRepository.findOrCreateOrderByCode tự động khởi tạo đơn đối soát nếu orderCode chưa tồn tại', async () => {
    const testOrderCode = 8899776655;
    const origFind = paymentRepository.findOrderByCode;
    const origCreate = prisma.payment_order.create;
    try {
      paymentRepository.findOrderByCode = async () => null;
      prisma.payment_order.create = async ({ data }) => ({
        id: data.id,
        idaccount: data.idaccount,
        order_code: data.order_code,
        package_type: data.package_type,
        amount: data.amount,
        status: data.status,
      });

      const order = await paymentRepository.findOrCreateOrderByCode(testOrderCode, 49000);
      assert.ok(order);
      assert.strictEqual(order.status, 'PENDING');
      assert.strictEqual(Number(order.order_code), testOrderCode);
    } finally {
      paymentRepository.findOrderByCode = origFind;
      prisma.payment_order.create = origCreate;
    }
  });

  await t.test('12. Tầng 2: findOrdersForAdmin với excludeTemplate: true lọc đúng where.is_template = false', async () => {
    const origFindMany = prisma.payment_order.findMany;
    const origCount = prisma.payment_order.count;
    let capturedWhere = null;
    try {
      prisma.payment_order.count = async ({ where }) => {
        capturedWhere = where;
        return 1;
      };
      prisma.payment_order.findMany = async () => [];

      await paymentRepository.findOrdersForAdmin({ excludeTemplate: true });
      assert.strictEqual(capturedWhere.is_template, false);
    } finally {
      prisma.payment_order.findMany = origFindMany;
      prisma.payment_order.count = origCount;
    }
  });

  await t.test('13. Tầng 1 & 2: getOrderDetailForAdmin trả về chi tiết đơn hàng đầy đủ', async () => {
    const testId = 'ord-detail-123';
    const origRepoDetail = paymentRepository.getOrderDetailForAdmin;
    try {
      paymentRepository.getOrderDetailForAdmin = async (id) => ({
        id,
        order_code: 752600277632,
        amount: 49000,
        status: 'PENDING',
        account: { username: 'test_admin' },
        payment_transaction: [],
      });

      const order = await paymentService.getOrderDetailForAdmin(testId);
      assert.ok(order);
      assert.strictEqual(order.id, testId);
      assert.strictEqual(order.order_code, 752600277632);
    } finally {
      paymentRepository.getOrderDetailForAdmin = origRepoDetail;
    }
  });

  await t.test('14. Tầng 1 & 2: getPackageTypes trả về danh sách gói cước (Basic, Premium)', async () => {
    const origPermFindMany = prisma.account_type_permission.findMany;
    try {
      prisma.account_type_permission.findMany = async () => [
        { account_type: 'Basic' },
        { account_type: 'Premium' },
      ];

      const packages = await paymentService.getPackageTypes();
      assert.ok(Array.isArray(packages));
      assert.strictEqual(packages.length, 2);
      assert.strictEqual(packages[0].id, 'Basic');
      assert.strictEqual(packages[1].id, 'Premium');
    } finally {
      prisma.account_type_permission.findMany = origPermFindMany;
    }
  });

  await t.test('15. Tầng 1 & 2: processRefund tiếp nhận file upload minh chứng và lưu đường dẫn /assets/Refunds', async () => {
    const origProcessOrderRefund = paymentService.processOrderRefund;
    let capturedData = null;
    try {
      paymentService.processOrderRefund = async (orderId, data) => {
        capturedData = { orderId, ...data };
        return { success: true, status: 'REFUNDED', ...data };
      };

      const req = {
        params: { id: 'ord-ref-999' },
        body: { refundedAmount: 20000, refundReason: 'Chuyển thiếu tiền' },
        file: { filename: 'refund-proof-123.png' },
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

      await paymentController.processRefund(req, res, (err) => {
        if (err) throw err;
      });

      assert.strictEqual(statusCode, 200);
      assert.strictEqual(jsonBody.success, true);
      assert.strictEqual(capturedData.orderId, 'ord-ref-999');
      assert.strictEqual(capturedData.refundProof, '/assets/Refunds/refund-proof-123.png');
    } finally {
      paymentService.processOrderRefund = origProcessOrderRefund;
    }
  });

  await t.test('16. Tầng 1 & 2: paymentRepository.autoExpirePendingOrders quét các đơn quá hạn, chuyển sang EXPIRED và xóa qr_url, checkout_url', async () => {
    const origUpdateMany = prisma.payment_order.updateMany;
    let capturedWhere = null;
    let capturedData = null;

    try {
      prisma.payment_order.updateMany = async (args) => {
        capturedWhere = args.where;
        capturedData = args.data;
        return { count: 3 };
      };

      const expiredCount = await paymentRepository.autoExpirePendingOrders();

      // Tầng 1: Đếm số lượng đơn hết hạn thành công
      assert.strictEqual(expiredCount, 3);

      // Tầng 2 (Tác động CSDL thực tế):
      // Đảm bảo chỉ quét các đơn PENDING có expired_at <= now
      assert.strictEqual(capturedWhere.status, 'PENDING');
      assert.ok(Array.isArray(capturedWhere.OR));

      // Đảm bảo cập nhật status thành EXPIRED và xóa vĩnh viễn qr_url, checkout_url
      assert.strictEqual(capturedData.status, 'EXPIRED');
      assert.strictEqual(capturedData.qr_url, null);
      assert.strictEqual(capturedData.checkout_url, null);
    } finally {
      prisma.payment_order.updateMany = origUpdateMany;
    }
  });

  await t.test('17. Tầng 1 & 2: paymentService.getOrderDetailForAdmin triệt tiêu QR khi đơn đã PAID hoặc EXPIRED; giữ QR khi PENDING còn hạn', async () => {
    const origGetDetail = paymentRepository.getOrderDetailForAdmin;

    try {
      // Case A: Đơn đã PAID -> Không còn QR, checkout_url = null
      paymentRepository.getOrderDetailForAdmin = async (id) => ({
        id,
        order_code: 1001,
        status: 'PAID',
        qr_url: null,
        checkout_url: null,
        amount: 49000,
      });

      const paidDetail = await paymentService.getOrderDetailForAdmin('ord-paid-1');
      assert.strictEqual(paidDetail.status, 'PAID');
      assert.strictEqual(paidDetail.qr_url, null);
      assert.strictEqual(paidDetail.checkout_url, null);

      // Case B: Đơn đã EXPIRED -> Không còn QR, checkout_url = null
      paymentRepository.getOrderDetailForAdmin = async (id) => ({
        id,
        order_code: 1002,
        status: 'EXPIRED',
        qr_url: null,
        checkout_url: null,
        amount: 49000,
      });

      const expiredDetail = await paymentService.getOrderDetailForAdmin('ord-exp-2');
      assert.strictEqual(expiredDetail.status, 'EXPIRED');
      assert.strictEqual(expiredDetail.qr_url, null);
      assert.strictEqual(expiredDetail.checkout_url, null);

      // Case C: Đơn PENDING còn hạn -> Bảo toàn QR để thanh toán
      paymentRepository.getOrderDetailForAdmin = async (id) => ({
        id,
        order_code: 1003,
        status: 'PENDING',
        qr_url: 'https://img.vietqr.io/image/970422-2512070399999-compact2.png',
        checkout_url: 'https://pay.payos.vn/web/test',
        amount: 49000,
        expired_at: new Date(Date.now() + 600000),
      });

      const pendingDetail = await paymentService.getOrderDetailForAdmin('ord-pending-3');
      assert.strictEqual(pendingDetail.status, 'PENDING');
      assert.ok(pendingDetail.qr_url.includes('vietqr.io'));
      assert.strictEqual(pendingDetail.checkout_url, 'https://pay.payos.vn/web/test');
    } finally {
      paymentRepository.getOrderDetailForAdmin = origGetDetail;
    }
  });

  await t.test('18. Tầng 1 & 2: paymentRepository.sanitizeOrderData tự động ép status=EXPIRED và xóa qr_url khi đơn PENDING đã quá hạn', async () => {
    // Đơn PENDING nhưng expired_at ở quá khứ
    const expiredRawOrder = {
      order_code: BigInt(8888),
      amount: { toNumber: () => 49000 },
      status: 'PENDING',
      expired_at: new Date(Date.now() - 60000),
      qr_url: 'https://img.vietqr.io/image/test.png',
      checkout_url: 'https://pay.payos.vn/test',
    };

    const sanitized = paymentRepository.sanitizeOrderData(expiredRawOrder);

    // Tầng 1: Chuyển đổi kiểu dữ liệu BigInt & Decimal thành Number
    assert.strictEqual(sanitized.order_code, 8888);
    assert.strictEqual(sanitized.amount, 49000);

    // Tầng 2: Tác động logic an toàn - chuyển EXPIRED và triệt tiêu QR
    assert.strictEqual(sanitized.status, 'EXPIRED');
    assert.strictEqual(sanitized.qr_url, null);
    assert.strictEqual(sanitized.checkout_url, null);
  });

  await t.test('19. Tầng 2: getPaymentSummaryStats mặc định LUÔN áp dụng where.is_template = false loại trừ đơn mẫu', async () => {
    const origCount = prisma.payment_order.count;
    const origAggregate = prisma.payment_order.aggregate;
    let capturedWhereCount = null;
    let capturedWhereAggregate = null;

    prisma.payment_order.count = async ({ where }) => {
      capturedWhereCount = where;
      return 5;
    };

    prisma.payment_order.aggregate = async ({ where }) => {
      capturedWhereAggregate = where;
      return {
        _sum: { amount: { toNumber: () => 245000 } },
      };
    };

    try {
      // Gọi getPaymentSummaryStats mà không truyền options gì cả
      const stats = await paymentRepository.getPaymentSummaryStats();

      // Xác minh System Impact: Query bắt buộc phải gán where.is_template = false
      assert.strictEqual(capturedWhereCount.is_template, false, 'Prisma count where phải lọc is_template = false');
      assert.strictEqual(capturedWhereAggregate.is_template, false, 'Prisma aggregate where phải lọc is_template = false');
      assert.strictEqual(stats.totalRevenue, 245000);
    } finally {
      prisma.payment_order.count = origCount;
      prisma.payment_order.aggregate = origAggregate;
    }
  });

  await t.test('20. Tầng 2: findOrdersByAccount chỉ lấy đơn thật của người dùng (where.is_template = false)', async () => {
    const origCount = prisma.payment_order.count;
    const origFindMany = prisma.payment_order.findMany;
    let capturedCountWhere = null;
    let capturedFindManyWhere = null;

    prisma.payment_order.count = async ({ where }) => {
      capturedCountWhere = where;
      return 2;
    };

    prisma.payment_order.findMany = async ({ where }) => {
      capturedFindManyWhere = where;
      return [
        {
          id: 'ord-real-1',
          idaccount: 10,
          order_code: BigInt(1001),
          amount: { toNumber: () => 49000 },
          status: 'PAID',
          is_template: false,
          created_at: new Date(),
        },
      ];
    };

    try {
      const res = await paymentRepository.findOrdersByAccount(10, { page: 1, limit: 10 });
      assert.strictEqual(capturedCountWhere.idaccount, 10);
      assert.strictEqual(capturedCountWhere.is_template, false, 'count phải lọc is_template = false');
      assert.strictEqual(capturedFindManyWhere.idaccount, 10);
      assert.strictEqual(capturedFindManyWhere.is_template, false, 'findMany phải lọc is_template = false');
      assert.strictEqual(res.items.length, 1);
      assert.strictEqual(res.items[0].is_template, false);
    } finally {
      prisma.payment_order.count = origCount;
      prisma.payment_order.findMany = origFindMany;
    }
  });

  await t.test('21. Tầng 2: handlePayOSWebhook với đơn mẫu cập nhật PAID nhưng TUYỆT ĐỐI KHÔNG gia hạn Premium', async () => {
    const origFindUnique = prisma.payment_order.findUnique;
    const origRecordTx = paymentRepository.recordTransaction;
    const origUpdateStatus = paymentRepository.updateOrderPaymentStatus;
    const origActivate = paymentRepository.activatePremiumSubscription;

    let recordedTx = false;
    let updatedStatus = false;
    let activatedPremium = false;

    // Giả lập đơn hàng mẫu is_template = true
    paymentRepository.findOrderByCode = async () => ({
      id: 'ord-sample-999',
      idaccount: 5,
      order_code: 999999,
      amount: 2000,
      status: 'PENDING',
      is_template: true,
      account: { type: 'Basic', premium_expires_at: null },
    });

    paymentRepository.recordTransaction = async () => {
      recordedTx = true;
      return { id: 'tx-sample-1' };
    };

    paymentRepository.updateOrderPaymentStatus = async ({ status }) => {
      if (status === 'PAID') updatedStatus = true;
      return { id: 'ord-sample-999', status: 'PAID' };
    };

    paymentRepository.activatePremiumSubscription = async () => {
      activatedPremium = true;
      return {};
    };

    const mockWebhookPayload = {
      code: '00',
      desc: 'success',
      data: {
        orderCode: 999999,
        amount: 2000,
        description: 'Test chuyen khoan mau 2000d',
        accountNumber: '0000',
        reference: 'REF-SAMPLE-999',
        transactionDateTime: new Date().toISOString(),
        currency: 'VND',
        paymentLinkId: 'plink-sample-999',
        code: '00',
        desc: 'success',
        counterAccountBankId: 'MB',
        counterAccountBankName: 'MB Bank',
        counterAccountName: 'NGUYEN PHU BAO',
        counterAccountNumber: '9999',
        virtualAccountName: 'FINANCE TEST',
        virtualAccountNumber: '8888',
      },
      signature: 'dummy_valid_sig',
    };

    const payosClient = require('../../modules/payment/payos.client');
    const origVerify = payosClient.verifyWebhookData;
    payosClient.verifyWebhookData = () => mockWebhookPayload.data;

    try {
      const res = await paymentService.handlePayOSWebhook(mockWebhookPayload);
      assert.strictEqual(res.success, true);
      assert.strictEqual(recordedTx, true, 'Phải ghi nhận transaction để đối soát');
      assert.strictEqual(updatedStatus, true, 'Phải cập nhật status đơn mẫu sang PAID');
      assert.strictEqual(activatedPremium, false, 'TUYỆT ĐỐI KHÔNG gia hạn Premium cho đơn mẫu');
    } finally {
      paymentRepository.recordTransaction = origRecordTx;
      paymentRepository.updateOrderPaymentStatus = origUpdateStatus;
      paymentRepository.activatePremiumSubscription = origActivate;
      payosClient.verifyWebhookData = origVerify;
    }
  });
});



