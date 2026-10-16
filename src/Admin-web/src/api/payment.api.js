import axiosClient from './axios-client';

const paymentApi = {
  /**
   * Lấy danh sách đơn hàng cho Admin kèm bộ lọc và phân trang
   * @param {object} params { page, limit, search, status, packageType, fromDate, toDate }
   */
  getOrders: (params = {}) => axiosClient.get('/admin/payments/orders', { params }),

  /**
   * Lấy thống kê KPI doanh thu và số lượng đơn hàng
   * @param {object} params { fromDate, toDate }
   */
  getStats: (params = {}) => axiosClient.get('/admin/payments/stats', { params }),

  /**
   * Lấy chi tiết đơn hàng kèm đối soát webhook giao dịch ngân hàng
   * @param {string} orderId
   */
  getOrderDetail: (orderId) => axiosClient.get(`/admin/payments/orders/${orderId}`),

  /**
   * Lấy thông tin mã QR trực tiếp từ kênh thanh toán PayOS
   * @param {object} params
   */
  getPayosQr: (params = {}) => axiosClient.get('/admin/payments/payos-qr', { params }),

  /**
   * Tạo đơn hàng mẫu thử nghiệm kèm mã QR
   * @param {object} data
   */
  createSampleOrder: (data = {}) => axiosClient.post('/admin/payments/sample', data),

  /**
   * Xóa tất cả các đơn hàng mẫu thử nghiệm
   */
  deleteSampleOrders: () => axiosClient.delete('/admin/payments/sample'),

  /**
   * Người dùng xác nhận hoặc từ chối kích hoạt gói khi chuyển thừa tiền
   * @param {object} data { orderCode, accept }
   */
  confirmUpgrade: (data) => axiosClient.post('/payment/confirm-upgrade', data),

  /**
   * Lấy danh sách các loại gói cước hiện có trong CSDL
   */
  getPackageTypes: () => axiosClient.get('/admin/payments/packages'),

  /**
   * Admin xử lý hoàn tiền cho khách hàng kèm upload minh chứng
   * @param {string} orderId
   * @param {object|FormData} data { refundedAmount, refundProof, refundReason, refundedAt, proofFile }
   */
  processRefund: (orderId, data) => {
    const isFormData = typeof FormData !== 'undefined' && data instanceof FormData;
    return axiosClient.put(`/admin/payments/orders/${orderId}/refund`, data, {
      headers: isFormData ? { 'Content-Type': 'multipart/form-data' } : {},
    });
  },

  /**
   * Admin giả lập Webhook cho chế độ Sandbox Roleplay
   * @param {object} data { orderCode, simulateType }
   */
  simulateWebhook: (data) => axiosClient.post('/admin/payments/simulate-webhook', data),
};

export default paymentApi;
