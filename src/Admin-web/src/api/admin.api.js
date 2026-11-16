import axiosClient from './axios-client';

const adminApi = {
  // Dashboard — thống kê
  getTotalUsers: () => axiosClient.get('/admin/totaluser'),
  getTotalCategories: () => axiosClient.get('/admin/totalcategories'),
  getUserToTime: (params) => axiosClient.get('/admin/getusertotime', { params: typeof params === 'object' ? params : { period: params } }),

  // Dashboard (các API khác sẽ bổ sung sau)
  getRecentActivities: (params) => axiosClient.get('/auth/recent-activities', { params }),
  getLoginStats: (params) => axiosClient.get('/admin/login-stats', { params }),
  getRequestStats: (params) => axiosClient.get('/admin/request-stats', { params }),

  // Users
  getUsers: () => axiosClient.get('/admin/getuser'),
  getUserById: (id) => axiosClient.get(`/admin/getuser/${id}`),
  getUserDevices: (id) => axiosClient.get(`/admin/getuser/${id}/devices`),
  revealDeviceIp: (id, deviceId, credentials) => axiosClient.post(`/admin/getuser/${id}/devices/${deviceId}/reveal-ip`, credentials),
  getUserPolicy: (id) => axiosClient.get(`/admin/getuser/${id}/policy`),
  getUserDataExports: (id) => axiosClient.get(`/admin/getuser/${id}/data-exports`),
  getDataIncidents: (params) => axiosClient.get('/admin/data-incidents', { params }),
  createDataIncident: (body) => axiosClient.post('/admin/data-incidents', body),
  updateDataIncident: (id, body) => axiosClient.patch(`/admin/data-incidents/${id}`, body),
  dataIncidentAction: (id, action, body) => axiosClient.post(`/admin/data-incidents/${id}/${action}`, body),
  getPolicies: () => axiosClient.get('/admin/policies'),
  publishPolicy: (data) => axiosClient.post('/admin/policies', data),
  /** Ngừng / kích hoạt một phiên bản chính sách: { status: 'ACTIVE' | 'INACTIVE', pin } */
  setPolicyStatus: (version, data) => axiosClient.patch(`/admin/policies/${version}/status`, data),
  // Các thao tác dưới đây bắt buộc PIN do máy chủ kiểm: gửi { pin } kèm dữ liệu.
  updateUserStatus: (id, data) => axiosClient.patch(`/admin/updatestatus/${id}`, data),
  deleteUser: (id, credentials = {}) => axiosClient.delete(`/admin/deleteuser/${id}`, { data: credentials }),

  // Categories
  getCategories: (params) => axiosClient.get('/admin/getcategory', { params }),
  createCategory: (data) => axiosClient.post('/admin/addcategory', data),
  updateCategory: (id, data) => axiosClient.put(`/admin/updatecategory/${id}`, data),
  deleteCategory: (id, credentials = {}) => axiosClient.delete(`/admin/deletecategory/${id}`, { data: credentials }),
  restoreCategory: (id, credentials = {}) => axiosClient.patch(`/admin/restorecategory/${id}`, credentials),

  // System Health & Maintenance
  getSystemHealth: () => axiosClient.get('/admin/system/health'),
  // Độ khả dụng theo kỳ: { period: 'month'|'quarter'|'year', year, month?, quarter? }
  getAvailability: (params) => axiosClient.get('/admin/system/availability', { params }),
  getMaintenanceStatus: () => axiosClient.get('/admin/system/maintenance'),
  setMaintenanceStatus: (data) => axiosClient.post('/admin/system/maintenance', data),
  cancelScheduledMaintenance: (id, credentials = {}) =>
    axiosClient.delete(id ? `/admin/system/maintenance/schedule/${id}` : '/admin/system/maintenance/schedule', { data: credentials }),
  getMaintenanceHistory: (params = {}) => axiosClient.get('/admin/system/maintenance/history', { params }),

  // Audit Logs
  getAuditLogs: (params = {}) => axiosClient.get('/admin/audit-logs', { params }),

  // Dynamic Feature Permissions
  getPermissions: () => axiosClient.get('/admin/permissions'),
  updatePermissions: (updates, credentials = {}) => axiosClient.put('/admin/permissions', { updates, ...credentials }),
  resetPermissionsDefault: (credentials = {}) => axiosClient.post('/admin/permissions/reset', credentials),

  // Security Action Re-authentication & PIN / Password / Admin Management
  verifySecurityAction: (data) => axiosClient.post('/admin/verify-security-action', data),
  // Cài đặt cá nhân của chính tài khoản đang đăng nhập (máy chủ lấy idaccount từ token)
  getMySettings: () => axiosClient.get('/admin/me/settings'),
  updateMySettings: (settings) => axiosClient.put('/admin/me/settings', settings),
  changePin: (data) => axiosClient.post('/admin/change-pin', data),
  changePassword: (data) => axiosClient.post('/admin/change-password', data),
  firstLoginSetup: (data) => axiosClient.post('/admin/first-login-setup', data),
  createAdmin: (data) => axiosClient.post('/admin/create-admin', data),
};

export default adminApi;
