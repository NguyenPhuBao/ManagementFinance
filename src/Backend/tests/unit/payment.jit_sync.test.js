const test = require('node:test');
const assert = require('node:assert/strict');

test('PayOS Just-in-Time Sync (JIT Sync) Suite', async (t) => {
  const paymentService = require('../../modules/payment/payment.service');
  const paymentRepository = require('../../modules/payment/payment.repository');
  const payosClient = require('../../modules/payment/payos.client');

  await t.test('Tier 1 & Tier 2: syncOrderWithPayOS() tự động chuyển CANCELLED và xóa QR khi PayOS báo đơn bị hủy', async () => {
    const dummyOrder = {
      id: 'order-uuid-1',
      order_code: 1351587162986,
      idaccount: 10,
      status: 'PENDING',
      amount: 49000,
      qr_url: 'https://img.vietqr.io/sample.png',
      checkout_url: 'https://pay.payos.vn/web/mock-cancel',
      expired_at: new Date(Date.now() + 6 * 60 * 1000),
    };

    let updatedDbData = null;
    let socketEmitted = [];

    const origUpdateOrderSyncStatus = paymentRepository.updateOrderSyncStatus;
    paymentRepository.updateOrderSyncStatus = async (orderId, data) => {
      updatedDbData = { orderId, ...data };
      return { ...dummyOrder, ...data };
    };

    payosClient.setPayOSClientMock({
      paymentRequests: {
        get: async (orderCode) => ({
          orderCode: Number(orderCode),
          status: 'CANCELLED',
          amount: 49000,
          cancellationReason: 'Khách hàng hủy thanh toán',
        }),
      },
    });

    try {
      const result = await paymentService.syncOrderWithPayOS(dummyOrder);

      // Tầng 1: Hiển thị & Thuộc tính phản hồi
      assert.strictEqual(result.status, 'CANCELLED', 'Trạng thái đơn hàng trả về phải là CANCELLED');
      assert.strictEqual(result.qr_url, null, 'qr_url phải bị xóa để tránh thanh toán lại');
      assert.strictEqual(result.checkout_url, null, 'checkout_url phải bị xóa');

      // Tầng 2: Tác động hệ thống thực tế & CSDL
      assert.ok(updatedDbData, 'Bắt buộc CSDL phải được cập nhật qua updateOrderSyncStatus');
      assert.strictEqual(updatedDbData.orderId, 'order-uuid-1');
      assert.strictEqual(updatedDbData.status, 'CANCELLED');
      assert.strictEqual(updatedDbData.qr_url, null);
      assert.strictEqual(updatedDbData.checkout_url, null);
    } finally {
      paymentRepository.updateOrderSyncStatus = origUpdateOrderSyncStatus;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('Tier 1 & Tier 2: syncOrderWithPayOS() an toàn khi PayOS ném lỗi Payment link not found (Graceful degradation)', async () => {
    const dummyOrder = {
      id: 'order-uuid-2',
      order_code: 999888777,
      idaccount: 10,
      status: 'PENDING',
      amount: 49000,
      qr_url: 'https://img.vietqr.io/sample.png',
      checkout_url: 'https://pay.payos.vn/web/mock-missing',
    };

    payosClient.setPayOSClientMock({
      paymentRequests: {
        get: async () => {
          const err = new Error('Payment link not found: Đơn hàng không tồn tại hoặc đã được xử lý');
          err.code = 301;
          throw err;
        },
      },
    });

    try {
      const result = await paymentService.syncOrderWithPayOS(dummyOrder);

      // Tầng 1: Đơn hàng không bị sập và giữ nguyên trạng thái PENDING an toàn
      assert.strictEqual(result.status, 'PENDING');
      assert.strictEqual(result.qr_url, 'https://img.vietqr.io/sample.png');
    } finally {
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('Tier 1 & Tier 2: syncOrderWithPayOS() tự động chuyển EXPIRED khi PayOS báo đơn hết hạn', async () => {
    const dummyOrder = {
      id: 'order-uuid-3',
      order_code: 333444555,
      idaccount: 10,
      status: 'PENDING',
      amount: 49000,
      qr_url: 'https://img.vietqr.io/sample.png',
    };

    let updatedDbData = null;
    const origUpdateOrderSyncStatus = paymentRepository.updateOrderSyncStatus;
    paymentRepository.updateOrderSyncStatus = async (orderId, data) => {
      updatedDbData = { orderId, ...data };
      return { ...dummyOrder, ...data };
    };

    payosClient.setPayOSClientMock({
      paymentRequests: {
        get: async () => ({
          status: 'EXPIRED',
        }),
      },
    });

    try {
      const result = await paymentService.syncOrderWithPayOS(dummyOrder);

      assert.strictEqual(result.status, 'EXPIRED');
      assert.strictEqual(result.qr_url, null);
      assert.strictEqual(updatedDbData.status, 'EXPIRED');
    } finally {
      paymentRepository.updateOrderSyncStatus = origUpdateOrderSyncStatus;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('Tier 1: Bỏ qua kiểm tra PayOS đối với đơn hàng không phải PENDING (Tiết kiệm latency & Quota)', async () => {
    let payosCalled = false;
    payosClient.setPayOSClientMock({
      paymentRequests: {
        get: async () => {
          payosCalled = true;
          return { status: 'PAID' };
        },
      },
    });

    try {
      const paidOrder = { id: 'paid-1', status: 'PAID', amount: 49000 };
      const result = await paymentService.syncOrderWithPayOS(paidOrder);

      assert.strictEqual(result.status, 'PAID');
      assert.strictEqual(payosCalled, false, 'Không được gọi PayOS nếu đơn đã ở trạng thái cuối');
    } finally {
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('Tier 1 & Tier 2: getOrderDetailForAdmin() kích hoạt JIT Sync và trả về dữ liệu đã đồng bộ', async () => {
    const dummyOrder = {
      id: 'admin-order-1',
      order_code: 888999,
      idaccount: 10,
      status: 'PENDING',
      amount: 49000,
      qr_url: 'https://img.vietqr.io/sample.png',
      checkout_url: 'https://pay.payos.vn/web/mock',
    };

    const origGetOrderDetail = paymentRepository.getOrderDetailForAdmin;
    const origUpdateOrderSyncStatus = paymentRepository.updateOrderSyncStatus;

    paymentRepository.getOrderDetailForAdmin = async (id) => ({ ...dummyOrder, id });
    paymentRepository.updateOrderSyncStatus = async (id, data) => ({ ...dummyOrder, id, ...data });

    payosClient.setPayOSClientMock({
      paymentRequests: {
        get: async () => ({
          status: 'CANCELLED',
        }),
      },
    });

    try {
      const detail = await paymentService.getOrderDetailForAdmin('admin-order-1');
      assert.strictEqual(detail.status, 'CANCELLED', 'Giao diện Admin phải nhận được trạng thái CANCELLED sau khi JIT Sync');
      assert.strictEqual(detail.qr_url, null, 'Mã QR trong chi tiết đơn hàng phải bị xóa');
    } finally {
      paymentRepository.getOrderDetailForAdmin = origGetOrderDetail;
      paymentRepository.updateOrderSyncStatus = origUpdateOrderSyncStatus;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('Tier 1 & Tier 2: getOrderStatus() kích hoạt JIT Sync cho Client-app', async () => {
    const dummyOrder = {
      id: 'client-order-1',
      order_code: 777666,
      idaccount: 15,
      status: 'PENDING',
      amount: 49000,
      qr_url: 'https://img.vietqr.io/sample.png',
      checkout_url: 'https://pay.payos.vn/web/mock',
    };

    const origFindOrderByCode = paymentRepository.findOrderByCode;
    const origUpdateOrderSyncStatus = paymentRepository.updateOrderSyncStatus;

    paymentRepository.findOrderByCode = async (code) => ({ ...dummyOrder, order_code: code });
    paymentRepository.updateOrderSyncStatus = async (id, data) => ({ ...dummyOrder, id, ...data });

    payosClient.setPayOSClientMock({
      paymentRequests: {
        get: async () => ({
          status: 'CANCELLED',
        }),
      },
    });

    try {
      const statusRes = await paymentService.getOrderStatus(777666, 15);
      assert.strictEqual(statusRes.status, 'CANCELLED', 'Client-app phải nhận trạng thái CANCELLED');
      assert.strictEqual(statusRes.qrUrl, null, 'qrUrl phải null');
    } finally {
      paymentRepository.findOrderByCode = origFindOrderByCode;
      paymentRepository.updateOrderSyncStatus = origUpdateOrderSyncStatus;
      payosClient.setPayOSClientMock(null);
    }
  });

  await t.test('Tier 2: Graceful Degradation - Không làm sập API khi PayOS bị timeout mạng', async () => {
    const dummyOrder = {
      id: 'network-order-1',
      order_code: 111222,
      idaccount: 10,
      status: 'PENDING',
      amount: 49000,
      qr_url: 'https://img.vietqr.io/sample.png',
    };

    payosClient.setPayOSClientMock({
      paymentRequests: {
        get: async () => {
          const netErr = new Error('connect ETIMEDOUT 103.20.144.1:443');
          netErr.code = 'ETIMEDOUT';
          throw netErr;
        },
      },
    });

    try {
      const result = await paymentService.syncOrderWithPayOS(dummyOrder);
      assert.strictEqual(result.status, 'PENDING', 'Khi mạng PayOS lỗi, phải giữ nguyên đơn mà không throw 500 error');
    } finally {
      payosClient.setPayOSClientMock(null);
    }
  });
});
