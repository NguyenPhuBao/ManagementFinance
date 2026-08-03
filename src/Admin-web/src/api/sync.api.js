import axiosClient from './axios-client';

const syncApi = {
  getSyncStatus: () => axiosClient.get('/sync/status'),
  getSyncLogs: (params) => axiosClient.get('/sync/logs', { params }),
  triggerSync: () => axiosClient.post('/sync/trigger'),
};

export default syncApi;
