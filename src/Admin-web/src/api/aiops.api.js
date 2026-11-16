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

// Mọi lệnh ghi AIOps gửi kèm PIN quản trị trong body (máy chủ kiểm): credentials = { pin }.
const withPin = (payload, credentials) => ({ ...(payload || {}), ...(credentials || {}) });

const aiopsApi = {
  getStatus: () => callAIOps('get', '/admin/aiops/status'),
  getHistory: (params = {}) => {
    const qs = new URLSearchParams();
    if (params.range) qs.append('range', params.range);
    if (params.from) qs.append('from', params.from);
    if (params.to) qs.append('to', params.to);
    const queryString = qs.toString();
    return callAIOps('get', `/admin/aiops/history${queryString ? `?${queryString}` : ''}`);
  },
  getVectorConfig: () => callAIOps('get', '/admin/aiops/vectors'),
  toggleVector: (vector, enabled, credentials) => callAIOps('post', '/admin/aiops/vectors/toggle', withPin({ vector, enabled }, credentials)),
  calibrate: (data = {}, credentials) => callAIOps('post', '/admin/aiops/calibrate', withPin(data, credentials)),
  getQuarantineList: () => callAIOps('get', '/admin/aiops/quarantine'),
  revealQuarantineIp: (hash, credentials) => axiosClient.post(`/admin/aiops/quarantine/${hash}/reveal-ip`, credentials),
  setScale: (concurrency, credentials) => callAIOps('post', '/admin/aiops/scale', withPin({ concurrency }, credentials)),
  getIncidents: (params = {}) => {
    const qs = new URLSearchParams();
    if (params.page) qs.append('page', params.page);
    if (params.limit) qs.append('limit', params.limit);
    if (params.vector && params.vector !== 'all') qs.append('vector', params.vector);
    if (params.status && params.status !== 'all') qs.append('status', params.status);
    if (params.search) qs.append('search', params.search);
    const queryString = qs.toString();
    return callAIOps('get', `/admin/aiops/incidents${queryString ? `?${queryString}` : ''}`);
  },
  quarantineActor: (payload, credentials) => callAIOps('post', '/admin/aiops/quarantine', withPin(payload, credentials)),
  temporaryBlockIp: (payload, credentials) => callAIOps('post', '/admin/aiops/quarantine/temporary-ip', withPin(payload, credentials)),
  unblockIp: (payload, credentials) => callAIOps('post', '/admin/aiops/quarantine/unblock-ip', withPin(payload, credentials)),
  // "Khóa thêm 4 giờ": IP chỉ có tạm khoá.
  extendIp: (payload, credentials) => callAIOps('post', '/admin/aiops/quarantine/extend-ip', withPin(payload, credentials)),
  temporaryBlockAccount: (payload, credentials) => callAIOps('post', '/admin/aiops/quarantine/temporary-account', withPin(payload, credentials)),
  unblockAccount: (payload, credentials) => callAIOps('post', '/admin/aiops/quarantine/unblock-account', withPin(payload, credentials)),
  permanentBanAccount: (payload, credentials) => callAIOps('post', '/admin/aiops/quarantine/permanent-account', withPin(payload, credentials)),
  getForensics: (params = {}) => {
    const qs = new URLSearchParams();
    if (params.ipHash) qs.append('ipHash', params.ipHash);
    if (params.username) qs.append('username', params.username);
    if (params.page) qs.append('page', params.page);
    if (params.limit) qs.append('limit', params.limit);
    const queryString = qs.toString();
    return callAIOps('get', `/admin/aiops/quarantine/forensics${queryString ? `?${queryString}` : ''}`);
  },
};

export default aiopsApi;
