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
router.get('/getusertotime', adminController.getUserToTime);

// Quản lý người dùng
router.get('/getuser', adminController.getUsers);
router.get('/getuser/:id', adminController.getUserDetail);
router.patch('/updatestatus/:id', adminController.updateStatus);

// Quản lý danh mục
router.get('/getcategory', adminController.getCategories);
router.post('/addcategory', adminController.addCategory);
router.put('/updatecategory/:id', adminController.updateCategory);
router.delete('/deletecategory/:id', adminController.deleteCategory);

module.exports = router;
