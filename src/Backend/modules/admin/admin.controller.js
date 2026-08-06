const adminService = require('./admin.service');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const adminController = {
  async totalUsers(req, res) {
    try {
      const result = await adminService.getTotalUsers();
      return ResponseHandler.success(res, result, 'Thống kê tổng người dùng');
    } catch (error) {
      logger.error('Total users failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async totalCategories(req, res) {
    try {
      const result = await adminService.getTotalCategories();
      return ResponseHandler.success(res, result, 'Thống kê tổng danh mục');
    } catch (error) {
      logger.error('Total categories failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },
};

module.exports = adminController;
