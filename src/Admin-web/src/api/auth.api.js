import axiosClient from './axios-client';

const authApi = {
  login: (credentials) => axiosClient.post('/auth/login', credentials),
  refreshToken: (refreshToken) => axiosClient.post('/auth/refresh', { refreshToken }),
  logout: () => axiosClient.post('/auth/logout'),
  getMe: () => axiosClient.get('/auth/me'),
};

export default authApi;
