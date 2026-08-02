const authService = require('./auth.service');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const authController = {
  async register(req, res) {
    try {
      const result = await authService.register(req.body, req);
      return ResponseHandler.created(res, result, 'Dang ky thanh cong');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.warn('Register failed', { username: req.body.username, error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },
  async login(req, res, next) {
    try {
      const { username, password } = req.body;
      const result = await authService.login(username, password, req);
      return ResponseHandler.success(res, result, 'Đăng nhập thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.warn('Login failed', { username: req.body.username, error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async refresh(req, res) {
    try {
      const { refreshToken } = req.body;
      const result = await authService.refresh(refreshToken, req);
      return ResponseHandler.success(res, result, 'Token đã được làm mới');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.warn('Refresh failed', { error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async me(req, res) {
    return ResponseHandler.success(res, {
      idaccount: req.user.idaccount,
      username: req.user.username,
      idrole: req.user.idrole,
      rolename: req.user.rolename,
    }, 'Token hợp lệ');
  },

  async logout(req, res) {
    try {
      const count = await authService.revokeAllTokens(req.user.idaccount);
      logger.info('User logged out', { idaccount: req.user.idaccount, tokensRevoked: count });
      return ResponseHandler.success(res, { tokensRevoked: count }, 'Đăng xuất thành công');
    } catch (error) {
      return ResponseHandler.error(res, error.message);
    }
  },
};

module.exports = authController;
