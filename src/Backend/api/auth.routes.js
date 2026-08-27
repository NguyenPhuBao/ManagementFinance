const express = require('express');
const router = express.Router();
const authController = require('../modules/auth/auth.controller');
const validate = require('../middleware/validator');
const { authenticate } = require('../middleware/auth');
const { 
  loginSchema, refreshSchema, registerSchema,
  sendRegisterOtpSchema, verifyRegisterOtpSchema,
  changePasswordSchema, forgotPasswordSchema, verifyOtpSchema, resetPasswordSchema,
  deleteAccountSchema, updateProfileSchema, requestEmailChangeSchema, confirmEmailChangeSchema
} = require('../modules/auth/auth.validation');

// === REGISTER OTP FLOW (MỚI) ===
// POST /api/auth/register/send-otp — Gửi mã OTP xác thực đăng ký về email
router.post('/register/send-otp', validate(sendRegisterOtpSchema), authController.sendRegisterOtp);

// POST /api/auth/register/verify-otp — Xác thực OTP, tạo tài khoản và trả token đăng nhập
router.post('/register/verify-otp', validate(verifyRegisterOtpSchema), authController.verifyRegisterOtp);

// POST /api/auth/register — DEPRECATED (Giữ tương thích ngược)
router.post('/register', validate(registerSchema), authController.register);

// POST /api/auth/login — public
router.post('/login', validate(loginSchema), authController.login);

// POST /api/auth/refresh — public
router.post('/refresh', validate(refreshSchema), authController.refresh);

// GET /api/auth/me — yeu cau token JWT
router.get('/me', authenticate, authController.me);

// POST /api/auth/logout — yeu cau token JWT, revoke tat ca token
router.post('/logout', authenticate, authController.logout);

// === PASSWORD MANAGEMENT ===
router.patch('/change-password', authenticate, validate(changePasswordSchema), authController.changePassword);
router.post('/forgot-password', validate(forgotPasswordSchema), authController.forgotPassword);
router.post('/verify-otp', validate(verifyOtpSchema), authController.verifyOtp);
router.post('/reset-password', validate(resetPasswordSchema), authController.resetPassword);

// === ACCOUNT MANAGEMENT ===
router.delete('/account', authenticate, validate(deleteAccountSchema), authController.deleteAccount);
router.post('/cancel-delete', authenticate, authController.cancelDelete);

// === PROFILE MANAGEMENT ===
router.get('/profile', authenticate, authController.getProfile);
router.patch('/profile', authenticate, validate(updateProfileSchema), authController.updateProfile);
router.post('/profile/request-email-change', authenticate, validate(requestEmailChangeSchema), authController.requestEmailChange);
router.patch('/profile/confirm-email-change', authenticate, validate(confirmEmailChangeSchema), authController.confirmEmailChange);

// === AUDIT LOG & RECENT ACTIVITIES ===
const authorize = require('../middleware/authorize');
router.get('/recent-activities', authenticate, authorize('admin'), authController.getRecentActivities);

module.exports = router;
