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

  /**
   * Tạo đơn thử nghiệm 2.000 ₫ (Backend quyết định số tiền, gắn với admin đang đăng nhập).
   * @param {{pin: string}} data mã PIN quản trị
   */
  createSampleOrder: ({ pin }) => axiosClient.post('/admin/payments/sample', { pin }),

  /** Hạn mức đơn thử hôm nay: { used, limit, amount } */
  getSampleQuota: () => axiosClient.get('/admin/payments/sample/quota'),

  /**
   * Ẩn các đơn thử nghiệm khỏi danh sách (đơn vẫn được lưu trong CSDL)
   */
  deleteSampleOrders: () => axiosClient.delete('/admin/payments/sample'),

  /**
   * Người dùng xác nhận hoặc từ chối kích hoạt gói khi chuyển thừa tiền
   * @param {object} data { orderCode, accept }
   */
  confirmUpgrade: ({ orderCode, accept }) =>
    axiosClient.post(`/admin/payments/orders/${orderCode}/confirm-upgrade`, { accept }),

  /**
   * Lấy danh sách các loại gói cước hiện có trong CSDL
   */
  getPackageTypes: () => axiosClient.get('/admin/payments/packages'),

  /**
   * Admin ghi nhận hoàn tiền thủ công (đã tự chuyển khoản trả khách).
   * @param {string} orderId
   * @param {FormData} data refunded_amount, refund_reason, bank_reference, refunded_at, pin, proofFile | refund_proof
   */
  processRefund: (orderId, data) => {
    const isFormData = typeof FormData !== 'undefined' && data instanceof FormData;
    return axiosClient.put(`/admin/payments/orders/${orderId}/refund`, data, {
      headers: isFormData ? { 'Content-Type': 'multipart/form-data' } : {},
    });
  },
};

export default paymentApi;
