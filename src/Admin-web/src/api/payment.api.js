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
};

export default paymentApi;
