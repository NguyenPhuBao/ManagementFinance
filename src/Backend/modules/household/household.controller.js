const householdService = require('./household.service');
const ResponseHandler = require('../../core/response-handler');

const householdController = {
  // ── [1] POST /api/households ────────────────────────────────
  async createHousehold(req, res) {
    try {
      const { name } = req.body || {};
      if (!name || typeof name !== 'string' || name.trim() === '') {
        return res.status(400).json({
          success: false,
          statusCode: 400,
          code: 'INVALID_HOUSEHOLD_NAME',
          message: 'Tên nhà không được để trống',
        });
      }
      if (name.trim().length > 100) {
        return res.status(400).json({
          success: false,
          statusCode: 400,
          code: 'INVALID_HOUSEHOLD_NAME',
          message: 'Tên nhà tối đa 100 ký tự',
        });
      }

      const house = await householdService.createHousehold(req.user.idaccount, req.body);
      return res.status(201).json({
        success: true,
        statusCode: 201,
        message: 'Tạo gia đình thành công',
        data: house,
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [2] GET /api/households/me ──────────────────────────────
  async getMyHousehold(req, res) {
    try {
      const house = await householdService.getMyHousehold(req.user.idaccount);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        data: house || { household: null },
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [3] POST /api/households/invites ────────────────────────
  async createInviteCode(req, res) {
    try {
      const invite = await householdService.createInviteCode(req.user.idaccount, req.body || {});
      return res.status(201).json({
        success: true,
        statusCode: 201,
        message: 'Tạo mã mời thành công',
        data: invite,
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [4] GET /api/households/invites ─────────────────────────
  async getHouseholdInvites(req, res) {
    try {
      const invites = await householdService.getHouseholdInvites(req.user.idaccount);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        data: invites,
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [5] DELETE /api/households/invites/:code ────────────────
  async revokeInvite(req, res) {
    try {
      await householdService.revokeInvite(req.user.idaccount, req.params.code);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Hủy mã mời thành công',
        data: { revoked: true },
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [6] GET /api/households/invites/:code ───────────────────
  async previewInvite(req, res) {
    try {
      const preview = await householdService.previewInvite(req.user, req.params.code);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        data: preview,
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [7] POST /api/households/join ───────────────────────────
  async joinByCode(req, res) {
    try {
      const { code } = req.body || {};
      if (!code) {
        return res.status(400).json({
          success: false,
          statusCode: 400,
          code: 'INVALID_INVITE_CODE',
          message: 'Mã mời không được để trống',
        });
      }

      const house = await householdService.joinByCode(req.user.idaccount, code, req.user?.email);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Tham gia gia đình thành công',
        data: house,
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [8] PATCH /api/households/members/:idaccount ───────────
  async updateMemberRole(req, res) {
    try {
      const { role } = req.body || {};
      const targetId = Number(req.params.idaccount);
      const result = await householdService.updateMemberRole(req.user.idaccount, targetId, role);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Cập nhật vai trò thành viên thành công',
        data: result,
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [9] POST /api/households/transfer-owner ─────────────────
  async transferOwner(req, res) {
    try {
      const { idaccount } = req.body || {};
      if (!idaccount) {
        return res.status(400).json({
          success: false,
          statusCode: 400,
          code: 'INVALID_TARGET_USER',
          message: 'Vui lòng chỉ định thành viên nhận quyền Chủ nhà',
        });
      }

      const house = await householdService.transferOwner(req.user.idaccount, Number(idaccount));
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Chuyển giao quyền Chủ nhà thành công',
        data: house,
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [10] DELETE /api/households/members/:idaccount ──────────
  async removeMember(req, res) {
    try {
      const targetId = Number(req.params.idaccount);
      await householdService.removeMember(req.user.idaccount, targetId);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Đã mời thành viên ra khỏi gia đình',
        data: { removed: true },
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [11] POST /api/households/leave ─────────────────────────
  async leaveHousehold(req, res) {
    try {
      await householdService.leaveHousehold(req.user.idaccount);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Rời gia đình thành công',
        data: { household: null },
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [12] POST /api/households/dissolve ──────────────────────
  async dissolveHousehold(req, res) {
    try {
      await householdService.dissolveHousehold(req.user.idaccount);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Giải tán gia đình thành công',
        data: { dissolved: true },
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [13] POST /api/households/invites/email ─────────────────
  async createEmailInvite(req, res) {
    try {
      const { email, role } = req.body || {};
      if (!email || !String(email).includes('@')) {
        return res.status(400).json({
          success: false,
          statusCode: 400,
          code: 'INVALID_EMAIL',
          message: 'Địa chỉ email không đúng định dạng',
        });
      }

      const result = await householdService.createEmailInvite(req.user.idaccount, { email, role });
      return res.status(202).json({
        success: true,
        statusCode: 202,
        message: `Đã gửi lời mời tới ${email}`,
        data: result,
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [14] GET /api/households/invitations ────────────────────
  async getMyInvitations(req, res) {
    try {
      const invitations = await householdService.getMyInvitations(req.user.idaccount, req.user?.email);
      return res.status(200).json({
        success: true,
        statusCode: 200,
        data: invitations,
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [15] POST /api/households/invitations/:code/accept ──────
  async acceptEmailInvite(req, res) {
    try {
      const house = await householdService.acceptEmailInvite(
        req.user.idaccount,
        req.params.code,
        req.user?.email
      );
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Chấp nhận lời mời gia đình thành công',
        data: house,
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },

  // ── [16] POST /api/households/invitations/:code/decline ─────
  async declineEmailInvite(req, res) {
    try {
      await householdService.declineEmailInvite(
        req.user.idaccount,
        req.params.code,
        req.user?.email
      );
      return res.status(200).json({
        success: true,
        statusCode: 200,
        message: 'Đã từ chối lời mời gia đình',
        data: { declined: true },
      });
    } catch (err) {
      const statusCode = err.statusCode || 500;
      return res.status(statusCode).json({
        success: false,
        statusCode,
        code: err.code || 'HOUSEHOLD_ERROR',
        message: err.message,
      });
    }
  },
};

module.exports = householdController;
