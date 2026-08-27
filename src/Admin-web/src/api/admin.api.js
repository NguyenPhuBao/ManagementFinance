import axiosClient from './axios-client';

const adminApi = {
  // Dashboard — thống kê
  getTotalUsers: () => axiosClient.get('/admin/totaluser'),
  getTotalCategories: () => axiosClient.get('/admin/totalcategories'),
  getUserToTime: (month, year) => axiosClient.get('/admin/getusertotime', { params: { month, year } }),

  // Dashboard (các API khác sẽ bổ sung sau)
  getDashboardStats: (timeFilter) => axiosClient.get('/admin/dashboard', { params: { period: timeFilter } }),
  getRecentActivities: (params) => axiosClient.get('/auth/recent-activities', { params }),
  getLoginStats: () => axiosClient.get('/admin/login-stats'),

  // Users
  getUsers: () => axiosClient.get('/admin/getuser'),
  getUserById: (id) => axiosClient.get(`/admin/getuser/${id}`),
  updateUserStatus: (id) => axiosClient.patch(`/admin/updatestatus/${id}`),

  // Categories
  getCategories: () => axiosClient.get('/admin/getcategory'),
  createCategory: (data) => axiosClient.post('/admin/addcategory', data),
  updateCategory: (id, data) => axiosClient.put(`/admin/updatecategory/${id}`, data),
  deleteCategory: (id) => axiosClient.delete(`/admin/deletecategory/${id}`),
  syncCategories: () => axiosClient.post('/admin/categories/sync'),

  // System
  getQueueStatus: () => axiosClient.get('/admin/queue/status'),
  getSystemConfig: () => axiosClient.get('/admin/config'),
  updateSystemConfig: (data) => axiosClient.put('/admin/config', data),
};

export default adminApi;
