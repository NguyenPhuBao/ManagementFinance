import axiosClient from './axios-client';

const adminApi = {
  // Dashboard
  getDashboardStats: (timeFilter) => axiosClient.get('/admin/dashboard', { params: { period: timeFilter } }),
  getRecentActivities: (params) => axiosClient.get('/admin/activities', { params }),
  getLoginStats: () => axiosClient.get('/admin/login-stats'),

  // Users
  getUsers: (params) => axiosClient.get('/admin/users', { params }),
  getUserById: (id) => axiosClient.get(`/admin/users/${id}`),
  updateUserStatus: (id, status) => axiosClient.patch(`/admin/users/${id}/status`, { status }),

  // Categories
  getCategories: (params) => axiosClient.get('/admin/categories', { params }),
  createCategory: (data) => axiosClient.post('/admin/categories', data),
  updateCategory: (id, data) => axiosClient.put(`/admin/categories/${id}`, data),
  deleteCategory: (id) => axiosClient.delete(`/admin/categories/${id}`),
  syncCategories: () => axiosClient.post('/admin/categories/sync'),

  // System
  getQueueStatus: () => axiosClient.get('/admin/queue/status'),
  getSystemConfig: () => axiosClient.get('/admin/config'),
  updateSystemConfig: (data) => axiosClient.put('/admin/config', data),
};

export default adminApi;
