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

  async getUserToTime(req, res) {
    try {
      const result = await adminService.getUserToTime(req.query);
      return ResponseHandler.success(res, result, 'Thống kê người dùng theo thời gian');
    } catch (error) {
      logger.error('getUserToTime failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getUsers(req, res) {
    try {
      const result = await adminService.getUsers();
      return ResponseHandler.success(res, result, 'Danh sách người dùng');
    } catch (error) {
      logger.error('getUsers failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getUserDetail(req, res) {
    try {
      const iduser = parseInt(req.params.id, 10);
      if (isNaN(iduser)) return ResponseHandler.badRequest(res, 'ID người dùng không hợp lệ');
      const result = await adminService.getUserDetail(iduser);
      return ResponseHandler.success(res, result, 'Thông tin chi tiết người dùng');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('getUserDetail failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async updateStatus(req, res) {
    try {
      const iduser = parseInt(req.params.id, 10);
      if (isNaN(iduser)) return ResponseHandler.badRequest(res, 'ID người dùng không hợp lệ');
      const result = await adminService.updateStatus(iduser);
      logger.info('User status updated', { iduser, ...result });
      req.auditActionName = result.newStatus === 'Active' ? 'Mở khóa tài khoản' : 'Khóa tài khoản';
      return ResponseHandler.success(res, result, 'Cập nhật trạng thái thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.error('updateStatus failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async getCategories(req, res) {
    try {
      const result = await adminService.getCategories();
      return ResponseHandler.success(res, result, 'Danh sách danh mục');
    } catch (error) {
      logger.error('getCategories failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async addCategory(req, res) {
    try {
      const { name, classify, is_default, keyword, icon } = req.body;
      if (!name || !classify) return ResponseHandler.badRequest(res, 'Thiếu tên hoặc loại danh mục');
      const result = await adminService.addCategory({ name, classify, is_default, keyword, icon }, req.user.idaccount);
      return ResponseHandler.created(res, result, 'Thêm danh mục thành công');
    } catch (error) {
      logger.error('addCategory failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async updateCategory(req, res) {
    try {
      const id = req.params.id;
      if (!id || typeof id !== 'string' || id.length < 32) {
        return ResponseHandler.badRequest(res, 'ID danh mục không hợp lệ');
      }
      const { name, classify, is_default, keyword, icon } = req.body;
      if (!name || !classify) return ResponseHandler.badRequest(res, 'Thiếu tên hoặc loại danh mục');
      const result = await adminService.updateCategory(id, { name, classify, is_default, keyword, icon });
      return ResponseHandler.success(res, result, 'Cập nhật danh mục thành công');
    } catch (error) {
      logger.error('updateCategory failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async deleteCategory(req, res) {
    try {
      const id = req.params.id;
      if (!id || typeof id !== 'string' || id.length < 32) {
        return ResponseHandler.badRequest(res, 'ID danh mục không hợp lệ');
      }
      const result = await adminService.deleteCategory(id);
      return ResponseHandler.success(res, result, 'Xóa danh mục thành công');
    } catch (error) {
      logger.error('deleteCategory failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getLoginStats(req, res) {
    try {
      const result = await adminService.getLoginStats(req.query);
      return ResponseHandler.success(res, result, 'Thống kê tần suất đăng nhập');
    } catch (error) {
      logger.error('getLoginStats failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async getRequestStats(req, res) {
    try {
      const result = await adminService.getRequestStats(req.query);
      return ResponseHandler.success(res, result, 'Thống kê lưu lượng request');
    } catch (error) {
      logger.error('getRequestStats failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },
};

module.exports = adminController;
