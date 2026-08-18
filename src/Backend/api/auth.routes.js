const express = require('express');
const router = express.Router();
const authController = require('../modules/auth/auth.controller');
const validate = require('../middleware/validator');
const { authenticate } = require('../middleware/auth');
const { 
  loginSchema, refreshSchema, registerSchema,
  changePasswordSchema, forgotPasswordSchema, verifyOtpSchema, resetPasswordSchema,
  deleteAccountSchema, updateProfileSchema, requestEmailChangeSchema, confirmEmailChangeSchema
} = require('../modules/auth/auth.validation');

// POST /api/auth/register — public (dang ky user)
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

// === PROFILE MANAGEMENT ===
router.get('/profile', authenticate, authController.getProfile);
router.patch('/profile', authenticate, validate(updateProfileSchema), authController.updateProfile);
router.post('/profile/request-email-change', authenticate, validate(requestEmailChangeSchema), authController.requestEmailChange);
router.patch('/profile/confirm-email-change', authenticate, validate(confirmEmailChangeSchema), authController.confirmEmailChange);

module.exports = router;
