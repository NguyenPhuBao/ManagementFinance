const axios = require('axios');
const logger = require('../../../core/logger');

const CASSO_API_URL = 'https://api.casso.vn/v2';
const getApiKey = () => process.env.CASSO_API_KEY;

const cassoClient = axios.create({
  baseURL: CASSO_API_URL,
});

// Thêm interceptor để luôn đính kèm API Key
cassoClient.interceptors.request.use((config) => {
  const apiKey = getApiKey();
  if (!apiKey) {
    logger.warn('CASSO_API_KEY is not configured in .env');
  } else {
    config.headers['Authorization'] = `Apikey ${apiKey}`;
  }
  return config;
});

const CassoAPI = {
  /**
   * Lấy danh sách tài khoản ngân hàng đã liên kết
   * @returns {Promise<Array>} Danh sách accounts
   */
  async getAccounts() {
    try {
      const response = await cassoClient.get('/accounts');
      if (response.data.error !== 0) {
        throw new Error(response.data.message || 'Casso API Error');
      }
      return response.data.data;
    } catch (error) {
      logger.error('Error fetching accounts from Casso:', error.message);
      throw error;
    }
  },

  /**
   * Lấy lịch sử giao dịch từ Casso
   * @param {string} fromDate - (YYYY-MM-DD)
   * @returns {Promise<Array>} Danh sách transactions
   */
  async getTransactions(fromDate) {
    try {
      const params = {};
      if (fromDate) params.fromDate = fromDate;
      const response = await cassoClient.get('/transactions', { params });
      if (response.data.error !== 0) {
        throw new Error(response.data.message || 'Casso API Error');
      }
      return response.data.data.records;
    } catch (error) {
      logger.error('Error fetching transactions from Casso:', error.message);
      throw error;
    }
  }
};

module.exports = CassoAPI;
