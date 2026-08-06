const express = require('express');
const router = express.Router();
const adminController = require('../modules/admin/admin.controller');
const { authenticate } = require('../middleware/auth');
const authorize = require('../middleware/authorize');

// Tất cả admin routes yêu cầu đăng nhập + role admin
router.use(authenticate, authorize('admin'));

// Dashboard — thống kê
router.get('/totaluser', adminController.totalUsers);
router.get('/totalcategories', adminController.totalCategories);

module.exports = router;
