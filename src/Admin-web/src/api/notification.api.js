import axiosClient from './axios-client';

const notificationApi = {
  /**
   * Lấy danh sách cảnh báo hệ thống cho Admin
   * @param {Object} params - { page, limit, unreadOnly }
   */
  getAdminAlerts: (params = {}) => axiosClient.get('/notifications/admin', { params }),

  /**
   * Đánh dấu một cảnh báo admin là đã đọc
   * @param {string} id - Notification UUID
   */
  markAdminAlertAsRead: (id) => axiosClient.patch(`/notifications/admin/${id}/read`),

  /**
   * Admin phát thông báo tới tất cả người dùng
   * @param {Object} data - { title, message, level }
   */
  broadcastNotification: (data) => axiosClient.post('/notifications/broadcast', data),

  /**
   * Gửi thông báo broadcast tới toàn bộ user (alias tường minh hơn)
   * @param {{ title: string, message: string, level: 'info'|'warning'|'critical' }} data
   */
  broadcastToAll: (data) => axiosClient.post('/notifications/broadcast', data),
};

export default notificationApi;
