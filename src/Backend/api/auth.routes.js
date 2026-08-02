const express = require('express');
const router = express.Router();
const authController = require('../modules/auth/auth.controller');
const validate = require('../middleware/validator');
const { authenticate } = require('../middleware/auth');
const { loginSchema, refreshSchema, registerSchema } = require('../modules/auth/auth.validation');

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

module.exports = router;
