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
      const now = new Date();
      const month = parseInt(req.query.month, 10) || now.getMonth() + 1;
      const year = parseInt(req.query.year, 10) || now.getFullYear();
      const result = await adminService.getUserToTime(month, year);
      return ResponseHandler.success(res, result, 'Thống kê người dùng theo tháng');
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
      const { name, classify, is_default } = req.body;
      if (!name || !classify) return ResponseHandler.badRequest(res, 'Thiếu tên hoặc loại danh mục');
      const result = await adminService.addCategory({ name, classify, is_default }, req.user.idaccount);
      return ResponseHandler.created(res, result, 'Thêm danh mục thành công');
    } catch (error) {
      logger.error('addCategory failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async updateCategory(req, res) {
    try {
      const uuid = req.params.id;
      if (!uuid || typeof uuid !== 'string' || uuid.length < 32) {
        return ResponseHandler.badRequest(res, 'UUID danh mục không hợp lệ');
      }
      const { name, classify, is_default } = req.body;
      if (!name || !classify) return ResponseHandler.badRequest(res, 'Thiếu tên hoặc loại danh mục');
      const result = await adminService.updateCategory(uuid, { name, classify, is_default });
      return ResponseHandler.success(res, result, 'Cập nhật danh mục thành công');
    } catch (error) {
      logger.error('updateCategory failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  async deleteCategory(req, res) {
    try {
      const uuid = req.params.id;
      if (!uuid || typeof uuid !== 'string' || uuid.length < 32) {
        return ResponseHandler.badRequest(res, 'UUID danh mục không hợp lệ');
      }
      const result = await adminService.deleteCategory(uuid);
      return ResponseHandler.success(res, result, 'Xóa danh mục thành công');
    } catch (error) {
      logger.error('deleteCategory failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },
};

module.exports = adminController;
