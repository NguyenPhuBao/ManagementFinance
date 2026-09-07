/**
 * SePay Bank Hub Client SDK
 * Quản lý kết nối, xác thực và gọi REST API tới SePay Bank Hub
 * Hỗ trợ tự động cache Access Token in-memory để tối ưu hiệu năng
 */

const axios = require('axios');
const config = require('../../../config');
const logger = require('../../../core/logger');

class SepayClient {
  constructor() {
    this.apiUrl = config.sepay?.apiUrl || process.env.SEPAY_BANKHUB_API_URL || 'https://bankhub-api.sepay.vn';
    this.clientId = config.sepay?.clientId || process.env.SEPAY_CLIENT_ID;
    this.clientSecret = config.sepay?.clientSecret || process.env.SEPAY_CLIENT_SECRET;
    this.companyXid = config.sepay?.companyXid || process.env.SEPAY_COMPANY_XID || 'default_company_xid';

    // In-memory token cache
    this.cachedToken = null;
    this.tokenExpiresAt = 0;

    // Test hooks (dành cho mocking trong unit test)
    this._customTokenFetcher = null;
    this._customLinkTokenFetcher = null;
  }

  /**
   * Xóa cache token
   */
  clearTokenCache() {
    this.cachedToken = null;
    this.tokenExpiresAt = 0;
  }

  /**
   * Cung cấp mock fetcher (phục vụ test)
   */
  _setTokenFetcher(fetcher) {
    this._customTokenFetcher = fetcher;
  }

  _setLinkTokenFetcher(fetcher) {
    this._customLinkTokenFetcher = fetcher;
  }

  /**
   * Lấy Access Token từ SePay Bank Hub qua Basic Authentication
   * Tự động cache token trong RAM, chỉ xin cấp mới khi gần hết hạn
   */
  async getAccessToken() {
    const now = Date.now();
    // Nếu token còn hạn ít nhất 60 giây thì tái sử dụng
    if (this.cachedToken && this.tokenExpiresAt > now + 60000) {
      return this.cachedToken;
    }

    // Nếu có mock fetcher trong unit test
    if (this._customTokenFetcher) {
      const mockRes = await this._customTokenFetcher();
      this.cachedToken = mockRes.access_token;
      this.tokenExpiresAt = now + (mockRes.expires_in || 3600) * 1000;
      return this.cachedToken;
    }

    try {
      const credentials = Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64');
      const response = await axios.post(
        `${this.apiUrl}/v1/token`,
        {},
        {
          headers: {
            Authorization: `Basic ${credentials}`,
            'Content-Type': 'application/json',
          },
          timeout: 10000,
        }
      );

      const { access_token, expires_in } = response.data;
      this.cachedToken = access_token;
      this.tokenExpiresAt = now + (expires_in || 3600) * 1000;
      logger.info('SePay Access Token refreshed successfully', { expires_in });
      return this.cachedToken;
    } catch (error) {
      logger.error('Failed to get SePay access token:', {
        status: error.response?.status,
        data: error.response?.data,
        message: error.message,
      });
      throw new Error(`SePay Auth Failed: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Tạo Hosted Link Token để mở In-App WebView liên kết ngân hàng
   * @param {Object} params { idaccount, companyXid, customerName, customerEmail }
   */
  async createLinkToken({ idaccount, companyXid, customerName, customerEmail }) {
    const targetCompanyXid = companyXid || this.companyXid;
    const customerId = `account_${idaccount}`;

    const body = {
      company_xid: targetCompanyXid,
      customer_id: customerId,
      customer_name: customerName || `User ${idaccount}`,
      customer_email: customerEmail || `user_${idaccount}@flowmoney.io`,
    };

    if (this._customLinkTokenFetcher) {
      return this._customLinkTokenFetcher(body);
    }

    const token = await this.getAccessToken();
    try {
      const response = await axios.post(`${this.apiUrl}/v1/link-tokens`, body, {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        timeout: 10000,
      });
      return response.data; // { link_token, hosted_link_url }
    } catch (error) {
      logger.error('Failed to create SePay Link Token:', {
        customerId,
        status: error.response?.status,
        data: error.response?.data,
        message: error.message,
      });
      throw new Error(`SePay Link Token Error: ${error.response?.data?.message || error.message}`);
    }
  }

  /**
   * Lấy danh sách tài khoản ngân hàng đã liên kết của một khách hàng
   * @param {number|string} idaccount
   */
  async getBankAccounts(idaccount) {
    const token = await this.getAccessToken();
    const customerId = `account_${idaccount}`;
    try {
      const response = await axios.get(`${this.apiUrl}/v1/bank-accounts`, {
        params: { customer_id: customerId },
        headers: {
          Authorization: `Bearer ${token}`,
        },
        timeout: 10000,
      });
      return response.data?.data || response.data || [];
    } catch (error) {
      logger.error('Failed to fetch bank accounts from SePay:', {
        customerId,
        error: error.message,
      });
      throw error;
    }
  }
}

const sepayClient = new SepayClient();
module.exports = sepayClient;
