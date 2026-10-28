const express = require('express');
const router = express.Router();
const householdController = require('../modules/household/household.controller');
const { authenticate } = require('../middleware/auth');

// Tất cả household routes yêu cầu xác thực JWT Bearer
router.use(authenticate);

// 1. Quản lý Nhà
router.post('/', householdController.createHousehold);
router.get('/me', householdController.getMyHousehold);
router.post('/leave', householdController.leaveHousehold);
router.post('/dissolve', householdController.dissolveHousehold);

// 2. Mời đích danh qua Email (Đặt trước /invites/:code)
router.post('/invites/email', householdController.createEmailInvite);
router.get('/invitations', householdController.getMyInvitations);
router.post('/invitations/:code/accept', householdController.acceptEmailInvite);
router.post('/invitations/:code/decline', householdController.declineEmailInvite);

// 3. Quản lý Mã mời 8 ký tự
router.post('/invites', householdController.createInviteCode);
router.get('/invites', householdController.getHouseholdInvites);
router.delete('/invites/:code', householdController.revokeInvite);
router.get('/invites/:code', householdController.previewInvite);
router.post('/join', householdController.joinByCode);

// 4. Quản lý Thành viên
router.patch('/members/:idaccount', householdController.updateMemberRole);
router.post('/transfer-owner', householdController.transferOwner);
router.delete('/members/:idaccount', householdController.removeMember);

module.exports = router;
