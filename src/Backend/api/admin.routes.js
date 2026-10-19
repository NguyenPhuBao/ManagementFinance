const express = require('express');
const router = express.Router();
const adminController = require('../modules/admin/admin.controller');
const aiopsController = require('../modules/aiops/aiops.controller');
const paymentController = require('../modules/payment/payment.controller');
const { uploadRefundProof } = require('../middleware/upload.middleware');
const { authenticate } = require('../middleware/auth');
const authorize = require('../middleware/authorize');

// Tất cả admin routes yêu cầu đăng nhập + role admin
router.use(authenticate, authorize('admin'));

// AIOps Sentinel — Máy học phát hiện xâm nhập & bất thường thời gian thực
router.get('/aiops/status', aiopsController.getStatus);
router.get('/aiops/history', aiopsController.getHistory);
router.get('/aiops/vectors', aiopsController.getVectorConfig);
router.post('/aiops/vectors/toggle', aiopsController.toggleVector);
router.get('/aiops/incidents', aiopsController.getIncidents);
router.post('/aiops/incidents/clear', aiopsController.clearIncidents);
router.post('/aiops/calibrate', aiopsController.calibrate);
router.post('/aiops/scale', aiopsController.setScale);
router.get('/aiops/quarantine', aiopsController.getQuarantineList);
router.get('/aiops/quarantine/forensics', aiopsController.getQuarantineForensics);
router.post('/aiops/quarantine', aiopsController.quarantineActor);
router.delete('/aiops/quarantine/:hash', aiopsController.unblockQuarantine);
router.post('/aiops/quarantine/unblock-ip', aiopsController.unblockIp);
router.post('/aiops/quarantine/permanent-ip', aiopsController.permanentBanIp);
router.post('/aiops/quarantine/temporary-ip', aiopsController.temporaryBlockIp);
router.post('/aiops/quarantine/unblock-account', aiopsController.unblockAccount);
router.post('/aiops/quarantine/permanent-account', aiopsController.permanentBanAccount);
router.post('/aiops/quarantine/temporary-account', aiopsController.temporaryBlockAccount);

// Dashboard — thống kê
router.get('/totaluser', adminController.totalUsers);
router.get('/totalcategories', adminController.totalCategories);
router.get('/getusertotime', adminController.getUserToTime);
router.get('/login-stats', adminController.getLoginStats);
router.get('/request-stats', adminController.getRequestStats);

// Hệ thống & Cứu nạn khẩn cấp (Emergency Maintenance Switch & History)
router.get('/system/maintenance', adminController.getMaintenanceStatus);
router.post('/system/maintenance', adminController.setMaintenanceStatus);
router.delete('/system/maintenance/schedule', adminController.cancelScheduledMaintenance);
router.get('/system/maintenance/history', adminController.getMaintenanceHistory);
router.get('/system/health', adminController.getSystemHealth);
router.get('/audit-logs', adminController.getAuditLogs);
router.post('/verify-security-action', adminController.verifySecurityAction);

// Quản lý người dùng
router.get('/getuser', adminController.getUsers);
router.get('/getuser/:id', adminController.getUserDetail);
router.patch('/updatestatus/:id', adminController.updateStatus);
router.delete('/deleteuser/:id', adminController.deleteUser);
router.delete('/users/:id', adminController.deleteUser);

// Quản lý danh mục
router.get('/getcategory', adminController.getCategories);
router.post('/addcategory', adminController.addCategory);
router.put('/updatecategory/:id', adminController.updateCategory);
router.delete('/deletecategory/:id', adminController.deleteCategory);

// Phân quyền gói cước theo loại tài khoản (Dynamic Feature Permissions)
router.get('/permissions', adminController.getPermissions);
router.put('/permissions', adminController.updatePermissions);
router.post('/permissions/reset', adminController.resetPermissions);

// Quản lý & Theo dõi lịch sử thanh toán (Payment History & Orders)
router.get('/payments/orders', paymentController.getOrdersForAdmin);
router.get('/payments/stats', paymentController.getPaymentStatsForAdmin);
router.get('/payments/packages', paymentController.getPackageTypes);
router.get('/payments/orders/:id', paymentController.getOrderDetailForAdmin);
router.put(
  '/payments/orders/:id/refund',
  (req, res, next) => {
    uploadRefundProof.single('proofFile')(req, res, (err) => {
      if (err) {
        return res.status(400).json({ success: false, message: err.message });
      }
      next();
    });
  },
  paymentController.processRefund
);
router.get('/payments/payos-qr', paymentController.getPayosQr);
router.post('/payments/sample', paymentController.createSampleOrder);
router.delete('/payments/sample', paymentController.deleteSampleOrders);
router.post('/payments/simulate-webhook', paymentController.simulateWebhook);

module.exports = router;

