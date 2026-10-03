import axiosClient from './axios-client';
import axios from 'axios';
import { STORAGE_KEYS } from '../utils/constants';

// Helper gọi AIOps API kèm fallback sang Local Proxy nếu Cloud Render trả về 404 (do chưa deploy)
async function callAIOps(method, path, data = null) {
  try {
    if (method === 'get') return await axiosClient.get(path);
    if (method === 'post') return await axiosClient.post(path, data);
    if (method === 'delete') return await axiosClient.delete(path);
  } catch (err) {
    // Nếu gặp 404 từ Cloud và đang chạy trên trình duyệt localhost
    if (err?.response?.status === 404 && typeof window !== 'undefined' && window.location.hostname === 'localhost') {
      try {
        const token = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
        const headers = {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        };
        const localUrl = `/api${path}`;
        const fallbackRes = await axios({
          method,
          url: localUrl,
          data,
          headers,
          timeout: 10000,
        });
        return fallbackRes.data?.data || fallbackRes.data;
      } catch (fallbackErr) {
        throw fallbackErr;
      }
    }
    throw err;
  }
}

const aiopsApi = {
  getStatus: () => callAIOps('get', '/admin/aiops/status'),
  getHistory: () => callAIOps('get', '/admin/aiops/history'),
  calibrate: (data = {}) => callAIOps('post', '/admin/aiops/calibrate', data),
  getQuarantineList: () => callAIOps('get', '/admin/aiops/quarantine'),
  unblockQuarantine: (hash) => callAIOps('delete', `/admin/aiops/quarantine/${hash}`),
};

export default aiopsApi;
