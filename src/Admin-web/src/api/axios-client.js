import axios from 'axios';
import { STORAGE_KEYS } from '../utils/constants';

export const baseURL = import.meta.env.VITE_API_BASE_URL || '/api';

const axiosClient = axios.create({
  baseURL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
    'x-client-platform': 'admin-web',
  },
});

// Request interceptor
axiosClient.interceptors.request.use(
  (config) => {
    config.headers['x-client-platform'] = 'admin-web';
    const isLocked = typeof localStorage !== 'undefined' && localStorage.getItem(STORAGE_KEYS.IS_LOCKED) === 'true';
    const isAuthUrl = config.url?.includes('/auth/login') || config.url?.includes('/auth/refresh');
    
    // Nếu màn hình đang khóa và không phải request đăng nhập/mở khóa thì hủy sớm để không spam backend
    if (isLocked && !isAuthUrl) {
      return Promise.reject(new axios.Cancel('Request cancelled: screen is locked'));
    }

    const token = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Một lượt làm mới token dùng chung cho mọi nơi gọi cùng lúc (API 401 và socket bị từ chối vì token hết hạn)
let refreshPromise = null;

/**
 * Đổi refresh token lấy access token mới, lưu vào trình duyệt và trả access token mới.
 * Gọi đồng thời nhiều lần chỉ gửi một yêu cầu /auth/refresh.
 */
export const refreshAccessToken = () => {
  if (refreshPromise) return refreshPromise;
  const refreshToken = localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN);
  if (!refreshToken) return Promise.reject(new Error('Missing refresh token'));

  // Dùng instance axios độc lập để tránh bị lặp vô hạn interceptor
  refreshPromise = axios
    .post(`${baseURL}/auth/refresh`, { refreshToken }, {
      headers: {
        'Content-Type': 'application/json',
        'x-client-platform': 'admin-web',
      },
    })
    .then((res) => {
      const data = res.data?.data || res.data;
      const newAccessToken = data?.accessToken;
      if (!newAccessToken) throw new Error('Refresh token did not return accessToken');
      localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, newAccessToken);
      if (data?.refreshToken) localStorage.setItem(STORAGE_KEYS.REFRESH_TOKEN, data.refreshToken);
      axiosClient.defaults.headers.common.Authorization = `Bearer ${newAccessToken}`;
      return newAccessToken;
    })
    .finally(() => {
      refreshPromise = null;
    });
  return refreshPromise;
};

const handleLogoutRedirect = () => {
  localStorage.removeItem(STORAGE_KEYS.ACCESS_TOKEN);
  localStorage.removeItem(STORAGE_KEYS.REFRESH_TOKEN);
  localStorage.removeItem(STORAGE_KEYS.USER);
  if (typeof window !== 'undefined' && window.location.pathname !== '/login') {
    window.location.href = '/login';
  }
};

// Response interceptor
axiosClient.interceptors.response.use(
  (response) => response.data,
  async (error) => {
    const originalRequest = error.config;

    // Không can thiệp nếu lỗi là từ API đăng nhập hoặc làm mới token (để trang Login tự hiển thị lỗi)
    const isAuthUrl = originalRequest?.url?.includes('/auth/login') || originalRequest?.url?.includes('/auth/refresh');

    // Các endpoint xác thực thứ cấp (mã PIN bảo mật, đổi PIN, đổi mật khẩu, cấp tài khoản admin)
    // Tuyệt đối KHÔNG chuyển hướng logout khi sai mã PIN/mật khẩu xác nhận để bảo toàn trạng thái làm việc
    const isSecurityVerificationUrl =
      originalRequest?.url?.includes('/verify-security-action') ||
      originalRequest?.url?.includes('/change-pin') ||
      originalRequest?.url?.includes('/change-password') ||
      originalRequest?.url?.includes('/create-admin');

    if (error.response?.status === 401 && !isAuthUrl) {
      if (isSecurityVerificationUrl) {
        return Promise.reject(error);
      }

      // 1. Nếu đang ở trạng thái Khóa Màn Hình An Toàn (isLocked === true):
      // Tuyệt đối KHÔNG chuyển hướng ra /login vì token tạm thời bị thu hồi, cần giữ nguyên giao diện để người dùng nhập mật khẩu mở khóa
      const isLocked = typeof localStorage !== 'undefined' && localStorage.getItem(STORAGE_KEYS.IS_LOCKED) === 'true';
      if (isLocked) {
        return Promise.reject(error);
      }

      const refreshToken = localStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN);

      // Nếu không có refresh token hoặc request này đã từng thử refresh rồi nhưng vẫn 401
      if (!refreshToken || originalRequest._retry) {
        handleLogoutRedirect();
        return Promise.reject(error);
      }

      originalRequest._retry = true;

      try {
        // Các request 401 đồng thời dùng chung một lượt làm mới
        const newAccessToken = await refreshAccessToken();
        originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
        return axiosClient(originalRequest);
      } catch (refreshErr) {
        handleLogoutRedirect();
        return Promise.reject(refreshErr);
      }
    }

    return Promise.reject(error);
  }
);

export default axiosClient;
