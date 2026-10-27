const crypto = require('crypto');
const householdRepository = require('./household.repository');
const { prisma } = require('../../config/db');
const logger = require('../../core/logger');

// Ký tự cho mã mời (bỏ các ký tự dễ nhầm lẫn như 0, O, 1, I)
const INVITE_CHARS = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

function generateRandomInviteCode(length = 8) {
  let code = '';
  const bytes = crypto.randomBytes(length);
  for (let i = 0; i < length; i++) {
    code += INVITE_CHARS[bytes[i] % INVITE_CHARS.length];
  }
  return code;
}

function createError(message, code, statusCode = 400) {
  const err = new Error(message);
  err.code = code;
  err.statusCode = statusCode;
  return err;
}

const householdService = {
  // ── 1. Tạo nhà ─────────────────────────────────────────────
  async createHousehold(idaccount, data) {
    const name = data?.name ? String(data.name).trim() : '';
    if (!name || name.length > 100) {
      throw createError('Tên nhà không được để trống và tối đa 100 ký tự', 'INVALID_HOUSEHOLD_NAME', 400);
    }

    // Kiểm tra tài khoản đã ở nhà nào chưa
    const existingMembership = await householdRepository.findActiveMemberByAccount(idaccount);
    if (existingMembership) {
      throw createError('Bạn đang là thành viên của một gia đình khác. Hãy rời nhà trước khi tạo mới.', 'HOUSEHOLD_ALREADY_IN_ONE', 409);
    }

    // Thực thi trong giao tác CSDL
    const created = await prisma.$transaction(async (tx) => {
      const house = await householdRepository.createHousehold(
        {
          name,
          ownerIdaccount: idaccount,
          maxMembers: data.maxMembers || 6,
          maxSharedWallets: data.maxSharedWallets || 10,
          contributionDueDay: data.contributionDueDay || 5,
        },
        tx
      );

      // Thêm Owner vào thành viên
      await householdRepository.addMember(
        {
          idhousehold: house.idhousehold,
          idaccount,
          role: 'Owner',
        },
        tx
      );

      // Clone 13 danh mục mặc định của hệ thống cho nhà
      await householdService.cloneDefaultCategoriesForHousehold(house.idhousehold, idaccount, tx);

      return house;
    });

    return {
      ...created,
      myRole: 'Owner',
    };
  },

  // ── 2. Nhân bản 13 Danh mục mặc định của hệ thống ───────────
  async cloneDefaultCategoriesForHousehold(idhousehold, ownerIdaccount, client = prisma) {
    try {
      const defaultCats = await client.category.findMany({
        where: {
          is_default: true,
          idhousehold: null,
          delete_at: null,
        },
      });

      if (!defaultCats || defaultCats.length === 0) {
        logger.warn('[Household] Không tìm thấy danh mục mặc định hệ thống để clone cho nhà', { idhousehold });
        return { count: 0 };
      }

      const clones = defaultCats.map((cat) => ({
        idcategory: crypto.randomUUID(),
        create_by: Number(ownerIdaccount),
        name_category: cat.name_category,
        classify: cat.classify,
        is_default: false,
        is_group: cat.is_group || false,
        icon: cat.icon || 'category',
        color: cat.color || '#4CAF50',
        idhousehold: Number(idhousehold),
        create_at: new Date(),
        update_at: new Date(),
        server_update_at: new Date(),
      }));

      await client.category.createMany({ data: clones });
      logger.info(`[Household] Đã nhân bản ${clones.length} danh mục mặc định cho nhà ${idhousehold}`);
      return { count: clones.length };
    } catch (err) {
      logger.error('[Household] Lỗi khi nhân bản danh mục mặc định cho nhà', { error: err.message, idhousehold });
      throw err;
    }
  },

  // ── 3. Lấy thông tin nhà tôi ────────────────────────────────
  async getMyHousehold(idaccount) {
    const membership = await householdRepository.findActiveMemberByAccount(idaccount);
    if (!membership || !membership.household || membership.household.delete_at) {
      return null;
    }

    const house = membership.household;
    const [activeMembers, formerMembers] = await Promise.all([
      householdRepository.findActiveMembersByHousehold(house.idhousehold),
      householdRepository.findFormerMembersByHousehold(house.idhousehold),
    ]);

    const mappedMembers = activeMembers.map((m) => ({
      idaccount: m.idaccount,
      username: m.account?.username,
      fullname: m.account?.User?.fullname || m.account?.username,
      role: m.role,
      joinedAt: m.joined_at,
    }));

    const mappedFormer = formerMembers.map((m) => ({
      idaccount: m.idaccount,
      username: m.account?.username,
      fullname: m.account?.User?.fullname || m.account?.username,
      role: m.role,
      leftAt: m.left_at,
    }));

    return {
      idhousehold: house.idhousehold,
      name: house.name,
      ownerIdaccount: house.owner_idaccount,
      status: house.status,
      maxMembers: house.max_members,
      maxSharedWallets: house.max_shared_wallets,
      contributionDueDay: house.contribution_due_day,
      createdAt: house.create_at,
      myRole: membership.role,
      members: mappedMembers,
      formerMembers: mappedFormer,
    };
  },

  // ── 4. Tạo mã mời 8 ký tự ──────────────────────────────────
  async createInviteCode(idaccount, { role = 'Member' }) {
    if (!['Member', 'Viewer'].includes(role)) {
      throw createError('Vai trò chỉ có thể là Member hoặc Viewer', 'INVALID_INVITE_ROLE', 400);
    }

    const membership = await householdRepository.findActiveMemberByAccount(idaccount);
    if (!membership || membership.role !== 'Owner') {
      throw createError('Chỉ Chủ nhà mới có quyền tạo mã mời', 'FORBIDDEN_NOT_OWNER', 403);
    }

    if (membership.household.status !== 'Active') {
      throw createError('Nhà không ở trạng thái Active', 'HOUSEHOLD_NOT_ACTIVE', 400);
    }

    // Kiểm tra trần thành viên
    const [activeMembersCount, activeInvitesCount] = await Promise.all([
      householdRepository.countActiveMembers(membership.idhousehold),
      householdRepository.countActiveInvites(membership.idhousehold),
    ]);

    if (activeMembersCount + activeInvitesCount >= membership.household.max_members) {
      throw createError('Nhà đã đủ số lượng thành viên tối đa (gồm cả các lời mời đang chờ)', 'HOUSEHOLD_FULL', 409);
    }

    const code = generateRandomInviteCode(8);
    const expiresAt = new Date(Date.now() + 48 * 3600 * 1000); // 48 giờ

    const invite = await householdRepository.createInvite({
      code,
      idhousehold: membership.idhousehold,
      role,
      created_by: idaccount,
      expires_at: expiresAt,
    });

    return {
      code: invite.code,
      role: invite.role,
      expiresAt: invite.expires_at.toISOString(),
    };
  },

  // ── 5. Lấy danh sách mã mời của nhà ────────────────────────
  async getHouseholdInvites(idaccount) {
    const membership = await householdRepository.findActiveMemberByAccount(idaccount);
    if (!membership || membership.role !== 'Owner') {
      throw createError('Chỉ Chủ nhà mới có quyền xem danh sách mã mời', 'FORBIDDEN_NOT_OWNER', 403);
    }

    const invites = await householdRepository.findInvitesByHousehold(membership.idhousehold);
    const now = new Date();

    return invites.map((inv) => {
      let status = 'Pending';
      if (inv.declined_at) status = 'Declined';
      else if (inv.revoked_at) status = 'Revoked';
      else if (inv.used_at) status = 'Used';
      else if (inv.expires_at <= now) status = 'Expired';

      return {
        code: inv.code,
        role: inv.role,
        email: inv.email,
        createAt: inv.create_at.toISOString(),
        expiresAt: inv.expires_at.toISOString(),
        status,
      };
    });
  },

  // ── 6. Hủy mã mời ──────────────────────────────────────────
  async revokeInvite(idaccount, code) {
    const invite = await householdRepository.findInviteByCode(code);
    if (!invite) {
      throw createError('Mã mời không tồn tại', 'HOUSEHOLD_INVITE_NOT_FOUND', 404);
    }

    const membership = await householdRepository.findActiveMemberByAccount(idaccount);
    if (!membership || membership.role !== 'Owner' || membership.idhousehold !== invite.idhousehold) {
      throw createError('Chỉ Chủ nhà mới có quyền hủy mã mời', 'FORBIDDEN_NOT_OWNER', 403);
    }

    await householdRepository.revokeInvite(code);
    return true;
  },

  // ── 7. Xem trước thông tin nhà qua mã mời ──────────────────
  async previewInvite(callerUser, code) {
    const invite = await householdRepository.findInviteByCode(code);
    const now = new Date();

    if (!invite || invite.household.delete_at || invite.household.status !== 'Active') {
      throw createError('Mã mời không tồn tại hoặc nhà đã giải tán', 'HOUSEHOLD_INVITE_INVALID', 404);
    }

    if (invite.revoked_at || invite.used_at || invite.declined_at) {
      throw createError('Mã mời đã được sử dụng hoặc đã bị hủy', 'HOUSEHOLD_INVITE_USED', 409);
    }

    if (invite.expires_at <= now) {
      throw createError('Mã mời đã hết hạn', 'HOUSEHOLD_INVITE_EXPIRED', 400);
    }

    // Nếu là lời mời đích danh email -> chỉ đúng email đó mới được xem
    if (invite.email) {
      const callerEmail = callerUser?.email ? String(callerUser.email).trim().toLowerCase() : '';
      if (callerEmail !== invite.email.toLowerCase()) {
        throw createError('Lời mời này được gửi đích danh cho tài khoản email khác', 'HOUSEHOLD_INVITE_WRONG_ACCOUNT', 403);
      }
    }

    const memberCount = await householdRepository.countActiveMembers(invite.idhousehold);
    const ownerName = invite.creator?.User?.fullname || invite.creator?.username || 'Chủ nhà';

    return {
      householdName: invite.household.name,
      ownerName,
      memberCount,
      maxMembers: invite.household.max_members,
      role: invite.role,
      expiresAt: invite.expires_at.toISOString(),
    };
  },

  // ── 8. Tham gia nhà bằng mã mời 8 ký tự ─────────────────────
  async joinByCode(idaccount, code, callerEmail = null) {
    const existingMembership = await householdRepository.findActiveMemberByAccount(idaccount);
    if (existingMembership) {
      throw createError('Bạn đang là thành viên của một gia đình khác', 'HOUSEHOLD_ALREADY_IN_ONE', 409);
    }

    const invite = await householdRepository.findInviteByCode(code);
    const now = new Date();

    if (!invite || invite.household.delete_at || invite.household.status !== 'Active') {
      throw createError('Mã mời không tồn tại hoặc nhà đã giải tán', 'HOUSEHOLD_INVITE_INVALID', 404);
    }

    if (invite.revoked_at || invite.used_at || invite.declined_at) {
      throw createError('Mã mời đã được sử dụng hoặc đã bị hủy', 'HOUSEHOLD_INVITE_USED', 409);
    }

    if (invite.expires_at <= now) {
      throw createError('Mã mời đã hết hạn', 'HOUSEHOLD_INVITE_EXPIRED', 400);
    }

    if (invite.email && callerEmail) {
      if (callerEmail.trim().toLowerCase() !== invite.email.toLowerCase()) {
        throw createError('Lời mời này được gửi đích danh cho tài khoản email khác', 'HOUSEHOLD_INVITE_WRONG_ACCOUNT', 403);
      }
    }

    const memberCount = await householdRepository.countActiveMembers(invite.idhousehold);
    if (memberCount >= invite.household.max_members) {
      throw createError('Nhà đã đủ số lượng thành viên tối đa', 'HOUSEHOLD_FULL', 409);
    }

    // Thêm thành viên và đánh dấu mã đã dùng
    await prisma.$transaction(async (tx) => {
      await householdRepository.addMember(
        {
          idhousehold: invite.idhousehold,
          idaccount,
          role: invite.role,
        },
        tx
      );
      await tx.household_invite.update({
        where: { code: invite.code },
        data: {
          used_by: Number(idaccount),
          used_at: now,
        },
      });
    });

    // Phát socket realtime
    householdService.emitHouseholdChanged(invite.idhousehold, 'MEMBER_JOINED', { idaccount, role: invite.role });

    return householdService.getMyHousehold(idaccount);
  },

  // ── 9. Cập nhật vai trò thành viên ─────────────────────────
  async updateMemberRole(ownerIdaccount, targetIdaccount, newRole) {
    if (!['Member', 'Viewer'].includes(newRole)) {
      throw createError('Vai trò chỉ có thể là Member hoặc Viewer', 'INVALID_MEMBER_ROLE', 400);
    }

    if (Number(ownerIdaccount) === Number(targetIdaccount)) {
      throw createError('Chủ nhà không thể tự đổi vai trò của chính mình', 'CANNOT_CHANGE_OWNER_ROLE', 400);
    }

    const ownerMembership = await householdRepository.findActiveMemberByAccount(ownerIdaccount);
    if (!ownerMembership || ownerMembership.role !== 'Owner') {
      throw createError('Chỉ Chủ nhà mới có quyền đổi vai trò thành viên', 'FORBIDDEN_NOT_OWNER', 403);
    }

    const targetMembership = await householdRepository.findActiveMemberByAccount(targetIdaccount);
    if (!targetMembership || targetMembership.idhousehold !== ownerMembership.idhousehold) {
      throw createError('Thành viên không thuộc nhà này', 'MEMBER_NOT_IN_HOUSEHOLD', 404);
    }

    await householdRepository.updateMemberRole(ownerMembership.idhousehold, targetIdaccount, newRole);

    householdService.emitHouseholdChanged(ownerMembership.idhousehold, 'ROLE_UPDATED', {
      idaccount: targetIdaccount,
      newRole,
    });

    return {
      targetIdaccount: Number(targetIdaccount),
      newRole,
    };
  },

  // ── 10. Chuyển quyền Chủ nhà (Transfer Owner) ──────────────
  async transferOwner(currentOwnerId, newOwnerId) {
    if (Number(currentOwnerId) === Number(newOwnerId)) {
      throw createError('Người nhận quyền Chủ nhà phải là thành viên khác', 'CANNOT_TRANSFER_TO_SELF', 400);
    }

    const ownerMembership = await householdRepository.findActiveMemberByAccount(currentOwnerId);
    if (!ownerMembership || ownerMembership.role !== 'Owner') {
      throw createError('Chỉ Chủ nhà mới có quyền chuyển giao nhà', 'FORBIDDEN_NOT_OWNER', 403);
    }

    const targetMembership = await householdRepository.findActiveMemberByAccount(newOwnerId);
    if (!targetMembership || targetMembership.idhousehold !== ownerMembership.idhousehold) {
      throw createError('Người được chọn không phải thành viên trong nhà', 'TARGET_NOT_IN_HOUSEHOLD', 404);
    }

    await householdRepository.transferOwner(ownerMembership.idhousehold, currentOwnerId, newOwnerId);

    householdService.emitHouseholdChanged(ownerMembership.idhousehold, 'OWNER_TRANSFERRED', {
      oldOwnerId: currentOwnerId,
      newOwnerId,
    });

    return householdService.getMyHousehold(currentOwnerId);
  },

  // ── 11. Mời thành viên ra khỏi nhà (Remove Member) ─────────
  async removeMember(ownerIdaccount, targetIdaccount) {
    if (Number(ownerIdaccount) === Number(targetIdaccount)) {
      throw createError('Chủ nhà không thể tự mời chính mình ra. Hãy giải tán hoặc chuyển chủ.', 'CANNOT_REMOVE_SELF', 400);
    }

    const ownerMembership = await householdRepository.findActiveMemberByAccount(ownerIdaccount);
    if (!ownerMembership || ownerMembership.role !== 'Owner') {
      throw createError('Chỉ Chủ nhà mới có quyền mời thành viên ra khỏi nhà', 'FORBIDDEN_NOT_OWNER', 403);
    }

    const targetMembership = await householdRepository.findActiveMemberByAccount(targetIdaccount);
    if (!targetMembership || targetMembership.idhousehold !== ownerMembership.idhousehold) {
      throw createError('Thành viên không thuộc nhà này', 'MEMBER_NOT_IN_HOUSEHOLD', 404);
    }

    await householdRepository.removeMember(ownerMembership.idhousehold, targetIdaccount);

    householdService.emitHouseholdChanged(ownerMembership.idhousehold, 'MEMBER_REMOVED', {
      idaccount: targetIdaccount,
    });

    return true;
  },

  // ── 12. Rời nhà (Leave Household) ──────────────────────────
  async leaveHousehold(idaccount) {
    const membership = await householdRepository.findActiveMemberByAccount(idaccount);
    if (!membership) {
      throw createError('Bạn không thuộc gia đình nào', 'NOT_IN_HOUSEHOLD', 404);
    }

    if (membership.role === 'Owner') {
      throw createError('Chủ nhà không thể tự rời nhà. Hãy chuyển quyền Chủ nhà hoặc giải tán nhà.', 'OWNER_CANNOT_LEAVE', 400);
    }

    await householdRepository.removeMember(membership.idhousehold, idaccount);

    householdService.emitHouseholdChanged(membership.idhousehold, 'MEMBER_LEFT', { idaccount });

    return true;
  },

  // ── 13. Giải tán nhà (Dissolve Household) ───────────────────
  async dissolveHousehold(ownerIdaccount) {
    const membership = await householdRepository.findActiveMemberByAccount(ownerIdaccount);
    if (!membership || membership.role !== 'Owner') {
      throw createError('Chỉ Chủ nhà mới có quyền giải tán nhà', 'FORBIDDEN_NOT_OWNER', 403);
    }

    await householdRepository.dissolveHousehold(membership.idhousehold);

    householdService.emitHouseholdChanged(membership.idhousehold, 'HOUSEHOLD_DISSOLVED', {
      idhousehold: membership.idhousehold,
    });

    return true;
  },

  // ── 14. Mời đích danh qua Email (POST /invites/email) ───────
  async createEmailInvite(ownerIdaccount, { email, role = 'Member' }) {
    if (!email || !String(email).includes('@')) {
      throw createError('Địa chỉ email không hợp lệ', 'INVALID_EMAIL', 400);
    }
    if (!['Member', 'Viewer'].includes(role)) {
      throw createError('Vai trò chỉ có thể là Member hoặc Viewer', 'INVALID_INVITE_ROLE', 400);
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const membership = await householdRepository.findActiveMemberByAccount(ownerIdaccount);
    if (!membership || membership.role !== 'Owner') {
      throw createError('Chỉ Chủ nhà mới có quyền gửi lời mời', 'FORBIDDEN_NOT_OWNER', 403);
    }

    if (membership.household.status !== 'Active') {
      throw createError('Nhà không ở trạng thái Active', 'HOUSEHOLD_NOT_ACTIVE', 400);
    }

    // Rate limit: 20 email / 24h & 5 email / 1h
    const [count24h, count1h] = await Promise.all([
      householdRepository.countEmailInvitesIn24h(membership.idhousehold),
      householdRepository.countEmailInvitesIn1h(membership.idhousehold),
    ]);

    if (count24h >= 20 || count1h >= 5) {
      throw createError('Đã vượt quá giới hạn gửi lời mời email (tối đa 20 thư/24h và 5 thư/giờ)', 'HOUSEHOLD_INVITE_RATE_LIMIT', 429);
    }

    // Kiểm tra trần thành viên
    const [activeMembersCount, activeInvitesCount] = await Promise.all([
      householdRepository.countActiveMembers(membership.idhousehold),
      householdRepository.countActiveInvites(membership.idhousehold),
    ]);

    if (activeMembersCount + activeInvitesCount >= membership.household.max_members) {
      throw createError('Nhà đã đủ số lượng thành viên tối đa (gồm cả các lời mời đang chờ)', 'HOUSEHOLD_FULL', 409);
    }

    // Kiểm tra xem email này có đang là thành viên của chính nhà này không
    const existingActiveMembers = await householdRepository.findActiveMembersByHousehold(membership.idhousehold);
    const alreadyMember = existingActiveMembers.some(
      (m) => m.account?.email && m.account.email.toLowerCase() === normalizedEmail
    );

    const expiresAt = new Date(Date.now() + 7 * 86400 * 1000); // 7 ngày

    // Nếu đã là thành viên: Vẫn trả 202 để bảo mật (anti-enumeration) nhưng không tạo invite
    if (alreadyMember) {
      return {
        sent: true,
        email: normalizedEmail,
        role,
        expiresAt: expiresAt.toISOString(),
      };
    }

    // Hủy lời mời email cũ còn hiệu lực cho email này ở nhà này
    await householdRepository.revokeActiveEmailInvitesForHousehold(membership.idhousehold, normalizedEmail);

    // Tìm xem tài khoản đã đăng ký tài khoản chưa
    const existingAccount = await prisma.account.findUnique({
      where: { email: normalizedEmail },
      select: { idaccount: true },
    });

    const code = generateRandomInviteCode(8);
    const invite = await householdRepository.createInvite({
      code,
      idhousehold: membership.idhousehold,
      role,
      created_by: ownerIdaccount,
      email: normalizedEmail,
      invitee_idaccount: existingAccount ? existingAccount.idaccount : null,
      expires_at: expiresAt,
    });

    // Phát sự kiện Socket.io đích danh tới tài khoản nếu đã có
    if (existingAccount) {
      try {
        const { emitToAccount } = require('../../core/socket');
        emitToAccount(existingAccount.idaccount, 'household.invited', {
          code: invite.code,
          householdName: membership.household.name,
          role: invite.role,
        });
      } catch (err) {
        logger.warn('[Household] Không thể phát socket household.invited', { error: err.message });
      }
    }

    // Gửi email qua Brevo / Resend / Nodemailer (non-blocking)
    householdService.sendInviteEmailAsync({
      toEmail: normalizedEmail,
      householdName: membership.household.name,
      inviterName: membership.account?.User?.fullname || membership.account?.username || 'Chủ nhà',
      role,
      code: invite.code,
      expiresAt,
    });

    return {
      sent: true,
      email: normalizedEmail,
      role: invite.role,
      expiresAt: invite.expires_at.toISOString(),
    };
  },

  // Gửi email bất đồng bộ (Graceful non-blocking)
  async sendInviteEmailAsync({ toEmail, householdName, inviterName, role, code, expiresAt }) {
    try {
      const { sendMail } = require('../../core/mail.service');
      const formattedDate = new Date(expiresAt).toLocaleDateString('vi-VN', {
        timeZone: 'Asia/Ho_Chi_Minh',
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });

      const subject = `Lời mời vào nhà "${householdName}" trên FlowMoney`;
      const roleText = role === 'Member' ? 'Thành viên' : 'Chỉ xem';
      const text = `${inviterName} mời bạn vào nhà "${householdName}" trên FlowMoney với vai ${roleText}.\n\nMã mời: ${code} — dùng được tới ${formattedDate} (giờ Việt Nam).\n\nCách tham gia: mở FlowMoney -> Nhà mình -> Tham gia bằng mã, nhập mã trên. Nếu chưa có tài khoản, hãy đăng ký bằng chính email này.`;

      if (typeof sendMail === 'function') {
        await sendMail({ to: toEmail, subject, text });
        logger.info(`[Household] Đã gửi thư mời email tới ${toEmail}`);
      }
    } catch (err) {
      logger.warn('[Household] Không thể gửi thư mời email (sẽ bỏ qua để không gián đoạn client)', {
        toEmail,
        error: err.message,
      });
    }
  },

  // ── 15. Lấy danh sách lời mời gửi tới tôi ──────────────────
  async getMyInvitations(idaccount, email) {
    const invites = await householdRepository.findPendingInvitationsForEmail(email, idaccount);

    return invites.map((inv) => ({
      code: inv.code,
      householdName: inv.household.name,
      inviterName: inv.creator?.User?.fullname || inv.creator?.username || 'Chủ nhà',
      role: inv.role,
      expiresAt: inv.expires_at.toISOString(),
    }));
  },

  // ── 16. Chấp nhận lời mời email ───────────────────────────
  async acceptEmailInvite(idaccount, code, callerEmail) {
    return householdService.joinByCode(idaccount, code, callerEmail);
  },

  // ── 17. Từ chối lời mời email ─────────────────────────────
  async declineEmailInvite(idaccount, code, callerEmail) {
    const invite = await householdRepository.findInviteByCode(code);
    if (!invite || invite.declined_at || invite.used_at || invite.revoked_at) {
      throw createError('Mã mời không tồn tại hoặc đã xử lý', 'HOUSEHOLD_INVITE_INVALID', 404);
    }

    if (invite.email && callerEmail) {
      if (callerEmail.trim().toLowerCase() !== invite.email.toLowerCase()) {
        throw createError('Lời mời này được gửi đích danh cho tài khoản email khác', 'HOUSEHOLD_INVITE_WRONG_ACCOUNT', 403);
      }
    }

    await householdRepository.markInviteDeclined(code);

    // Báo socket tới Chủ nhà
    householdService.emitHouseholdChanged(invite.idhousehold, 'INVITE_DECLINED', { code });

    return true;
  },

  // ── Helper kiểm tra vai trò thành viên ──────────────────────
  async getMemberRoleInHousehold(idhousehold, idaccount) {
    const member = await prisma.household_member.findFirst({
      where: {
        idhousehold: Number(idhousehold),
        idaccount: Number(idaccount),
        left_at: null,
      },
      select: { role: true },
    });
    return member ? member.role : null;
  },

  // ── Helper phát socket realtime cho nhà ────────────────────
  emitHouseholdChanged(idhousehold, eventType, payload) {
    try {
      const { getIO } = require('../../core/socket');
      const io = getIO ? getIO() : null;
      if (io) {
        io.to(`household_${idhousehold}`).emit('household.changed', {
          idhousehold,
          eventType,
          payload,
          timestamp: new Date().toISOString(),
        });
      }
    } catch (err) {
      logger.warn('[Household] Không thể phát socket household.changed', { error: err.message, idhousehold });
    }
  },
};

module.exports = householdService;
