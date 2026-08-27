const authService = require('./auth.service');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const authController = {
  async sendRegisterOtp(req, res) {
    try {
      const result = await authService.sendRegisterOtp(req.body);
      return ResponseHandler.success(res, null, result.message);
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.warn('Send register OTP failed', { email: req.body.email, error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async verifyRegisterOtp(req, res) {
    try {
      const result = await authService.verifyRegisterOtp(req.body, req);
      return ResponseHandler.created(res, result, 'Đăng ký thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      logger.warn('Verify register OTP failed', { email: req.body.email, error: error.message });
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

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

  async changePassword(req, res) {
    try {
      const { currentPassword, newPassword } = req.body;
      await authService.changePassword(req.user.idaccount, currentPassword, newPassword);
      return ResponseHandler.success(res, null, 'Đổi mật khẩu thành công. Vui lòng đăng nhập lại.');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async forgotPassword(req, res) {
    try {
      const { email } = req.body;
      await authService.forgotPassword(email);
      return ResponseHandler.success(res, null, 'Nếu email tồn tại, hệ thống đã gửi mã OTP.');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async verifyOtp(req, res) {
    try {
      const { email, otp } = req.body;
      const resetToken = await authService.verifyOtp(email, otp);
      return ResponseHandler.success(res, { resetToken }, 'Xác thực OTP thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async resetPassword(req, res) {
    try {
      const { resetToken, newPassword } = req.body;
      await authService.resetPassword(resetToken, newPassword);
      return ResponseHandler.success(res, null, 'Đặt lại mật khẩu thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async deleteAccount(req, res) {
    try {
      const { password } = req.body;
      await authService.deleteAccount(req.user.idaccount, password);
      return ResponseHandler.success(res, null, 'Tài khoản của bạn sẽ bị xóa sau 30 ngày. Đăng nhập lại để hủy yêu cầu.');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async cancelDelete(req, res) {
    try {
      await authService.cancelDeletion(req.user.idaccount);
      return ResponseHandler.success(res, null, 'Yêu cầu xóa tài khoản đã được hủy thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async getProfile(req, res) {
    try {
      const profile = await authService.getProfile(req.user.idaccount);
      return ResponseHandler.success(res, profile, 'Lấy thông tin thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async updateProfile(req, res) {
    try {
      const updated = await authService.updateProfile(req.user.idaccount, req.body);
      return ResponseHandler.success(res, updated, 'Cập nhật thông tin thành công');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async requestEmailChange(req, res) {
    try {
      const { newEmail } = req.body;
      await authService.requestEmailChange(req.user.idaccount, newEmail);
      return ResponseHandler.success(res, null, 'Đã gửi mã OTP đến email mới');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },

  async confirmEmailChange(req, res) {
    try {
      const { newEmail, otp } = req.body;
      await authService.confirmEmailChange(req.user.idaccount, newEmail, otp);
      return ResponseHandler.success(res, null, 'Cập nhật email thành công. Vui lòng đăng nhập lại.');
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return ResponseHandler.error(res, error.message, statusCode);
    }
  },
};

module.exports = authController;
