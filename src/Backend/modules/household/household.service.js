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

/**
 * Task 57.2: Tra cứu email chuẩn hóa của tài khoản từ CSDL nếu JWT payload không có email
 */
async function getCallerEmail(idaccount, reqUser = null) {
  if (reqUser?.email && typeof reqUser.email === 'string' && reqUser.email.trim() !== '') {
    return reqUser.email.trim().toLowerCase();
  }
  if (!idaccount) return '';
  const account = await prisma.account.findUnique({
    where: { idaccount: Number(idaccount) },
    select: { email: true },
  });
  const email = account?.email || '';
  return email ? String(email).trim().toLowerCase() : '';
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
    await prisma.$transaction(async (tx) => {
      // Task 57.5: Bỏ nhận trần từ body người dùng; trần thành viên = 6, trần ví chung = 10, contributionDueDay = 5
      const house = await householdRepository.createHousehold(
        {
          name,
          ownerIdaccount: idaccount,
          maxMembers: 6,
          maxSharedWallets: 10,
          contributionDueDay: 5,
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

    // Task 57.1: Trả về Single State Shape chuẩn theo docs/Family/01 mục 4
    return householdService.getMyHousehold(idaccount);
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

      // Task 56.9: Ánh xạ UUID cha-con (idgroup) và sao chép keyword
      const idMap = new Map();
      for (const cat of defaultCats) {
        idMap.set(cat.idcategory, crypto.randomUUID());
      }

      const clones = defaultCats.map((cat) => ({
        idcategory: idMap.get(cat.idcategory),
        create_by: Number(ownerIdaccount),
        name_category: cat.name_category,
        classify: cat.classify,
        is_default: false,
        is_group: cat.is_group || false,
        idgroup: cat.idgroup ? (idMap.get(cat.idgroup) || null) : null,
        keyword: cat.keyword || null,
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

  // ── 3. Lấy thông tin nhà tôi (Single State Shape theo docs/Family/01 mục 4) ─
  async getMyHousehold(idaccount) {
    const membership = await householdRepository.findActiveMemberByAccount(idaccount);
    if (!membership || !membership.household || membership.household.delete_at) {
      return {
        household: null,
        myRole: null,
        members: [],
        formerMembers: [],
      };
    }

    const house = membership.household;
    const [activeMembers, formerMembers] = await Promise.all([
      householdRepository.findActiveMembersByHousehold(house.idhousehold),
      householdRepository.findFormerMembersByHousehold(house.idhousehold),
    ]);

    const mappedMembers = activeMembers.map((m) => ({
      idaccount: m.idaccount,
      displayName: m.account?.User?.fullname || m.account?.username || 'Thành viên',
      role: m.role,
      joinedAt: m.joined_at,
    }));

    const mappedFormer = formerMembers.map((m) => ({
      idaccount: m.idaccount,
      displayName: m.account?.User?.fullname || m.account?.username || 'Thành viên cũ',
      role: m.role,
      leftAt: m.left_at,
    }));

    return {
      household: {
        id: house.idhousehold,
        name: house.name,
        status: house.status,
        maxMembers: house.max_members,
        ownerId: house.owner_idaccount,
        createAt: house.create_at,
        maxSharedWallets: house.max_shared_wallets || 10,
        contributionDueDay: house.contribution_due_day || 5,
      },
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

  // ── 7. Xem trước thông tin nhà qua mã mời (Task 57.7) ──────────────────
  async previewInvite(callerUser, code) {
    const invite = await householdRepository.findInviteByCode(code);
    const now = new Date();

    if (!invite || invite.household?.delete_at || invite.household?.status === 'Dissolved') {
      throw createError('Mã mời không tồn tại hoặc nhà đã giải tán', 'HOUSEHOLD_INVITE_INVALID', 404);
    }

    if (invite.declined_at) {
      throw createError('Lời mời này đã bị từ chối', 'HOUSEHOLD_INVITE_DECLINED', 409);
    }

    if (invite.revoked_at || invite.used_at) {
      throw createError('Mã mời đã được sử dụng hoặc đã bị hủy', 'HOUSEHOLD_INVITE_USED', 409);
    }

    if (invite.expires_at <= now) {
      throw createError('Mã mời đã hết hạn', 'HOUSEHOLD_INVITE_EXPIRED', 410);
    }

    // Nếu là lời mời đích danh email -> chỉ đúng email đó mới được xem (Task 57.2)
    if (invite.email) {
      const callerEmail = await getCallerEmail(callerUser?.idaccount, callerUser);
      if (!callerEmail || callerEmail !== invite.email.toLowerCase()) {
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

  // ── 8. Tham gia nhà bằng mã mời 8 ký tự (Task 57.7 & 57.8 #3) ─────────────────────
  async joinByCode(idaccount, code, callerEmail = null) {
    const existingMembership = await householdRepository.findActiveMemberByAccount(idaccount);
    if (existingMembership) {
      throw createError('Bạn đang là thành viên của một gia đình khác', 'HOUSEHOLD_ALREADY_IN_ONE', 409);
    }

    const invite = await householdRepository.findInviteByCode(code);
    const now = new Date();

    if (!invite || invite.household?.delete_at || invite.household?.status === 'Dissolved') {
      throw createError('Mã mời không tồn tại hoặc nhà đã giải tán', 'HOUSEHOLD_INVITE_INVALID', 404);
    }

    if (invite.declined_at) {
      throw createError('Lời mời này đã bị từ chối', 'HOUSEHOLD_INVITE_DECLINED', 409);
    }

    if (invite.revoked_at || invite.used_at) {
      throw createError('Mã mời đã được sử dụng hoặc đã bị hủy', 'HOUSEHOLD_INVITE_USED', 409);
    }

    if (invite.expires_at <= now) {
      throw createError('Mã mời đã hết hạn', 'HOUSEHOLD_INVITE_EXPIRED', 410);
    }

    // Task 57.2: Kiểm tra email chính xác từ CSDL nếu có
    if (!callerEmail) {
      callerEmail = await getCallerEmail(idaccount);
    }

    if (invite.email) {
      if (!callerEmail || callerEmail.trim().toLowerCase() !== invite.email.toLowerCase()) {
        throw createError('Lời mời này được gửi đích danh cho tài khoản email khác', 'HOUSEHOLD_INVITE_WRONG_ACCOUNT', 403);
      }
    }

    const memberCount = await householdRepository.countActiveMembers(invite.idhousehold);
    if (memberCount >= invite.household.max_members) {
      throw createError('Nhà đã đủ số lượng thành viên tối đa', 'HOUSEHOLD_FULL', 409);
    }

    // Thêm thành viên và đánh dấu mã đã dùng (Task 57.8 #3: Atomic Update chống Race Condition)
    await prisma.$transaction(async (tx) => {
      const updateInviteResult = await tx.household_invite.updateMany({
        where: {
          code: invite.code,
          used_at: null,
          revoked_at: null,
          declined_at: null,
        },
        data: {
          used_by: Number(idaccount),
          used_at: now,
        },
      });

      if (updateInviteResult.count === 0) {
        throw createError('Mã mời đã được sử dụng hoặc đã bị hủy', 'HOUSEHOLD_INVITE_USED', 409);
      }

      await householdRepository.addMember(
        {
          idhousehold: invite.idhousehold,
          idaccount,
          role: invite.role,
        },
        tx
      );
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

    // Cập nhật trạng thái nhà dựa trên gói cước của chủ mới (Task 56.7)
    await householdService.updateHouseholdStatusByOwner(newOwnerId);
    await householdService.updateHouseholdStatusByOwner(currentOwnerId);

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
    }, [targetIdaccount]);

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

    householdService.emitHouseholdChanged(membership.idhousehold, 'MEMBER_LEFT', { idaccount }, [idaccount]);

    return true;
  },

  // ── 13. Giải tán nhà (Dissolve Household - Task 57.6 & 58.3) ───────────────────
  async dissolveHousehold(ownerIdaccount) {
    const membership = await householdRepository.findActiveMemberByAccount(ownerIdaccount);
    if (!membership || membership.role !== 'Owner') {
      throw createError('Chỉ Chủ nhà mới có quyền giải tán nhà', 'FORBIDDEN_NOT_OWNER', 403);
    }

    // Task 58.3: Lấy danh sách thành viên active TRƯỚC KHI gắn Left_at trong CSDL
    const activeMembers = await householdRepository.findActiveMembersByHousehold(membership.idhousehold);
    const memberAccountIds = activeMembers.map((m) => m.idaccount);

    await householdRepository.dissolveHousehold(membership.idhousehold);

    // Phát socket gửi tới room nhà và phòng riêng của từng thành viên
    householdService.emitHouseholdChanged(
      membership.idhousehold,
      'HOUSEHOLD_DISSOLVED',
      {
        idhousehold: membership.idhousehold,
        dissolvedBy: Number(ownerIdaccount),
      },
      memberAccountIds
    );

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
    // Task 57.8 #7: Giới hạn độ dài email tối đa 100 ký tự
    if (normalizedEmail.length > 100) {
      throw createError('Địa chỉ email không được vượt quá 100 ký tự', 'INVALID_EMAIL', 400);
    }

    const membership = await householdRepository.findActiveMemberByAccount(ownerIdaccount);
    if (!membership || membership.role !== 'Owner') {
      throw createError('Chỉ Chủ nhà mới có quyền gửi lời mời', 'FORBIDDEN_NOT_OWNER', 403);
    }

    if (membership.household.status !== 'Active') {
      throw createError('Nhà không ở trạng thái Active', 'HOUSEHOLD_NOT_ACTIVE', 400);
    }

    const expiresAt = new Date(Date.now() + 7 * 86400 * 1000); // 7 ngày

    // Task 57.8 #1: Kiểm tra alreadyMember TRƯỚC KHI kiểm tra trần thành viên HOUSEHOLD_FULL
    const existingActiveMembers = await householdRepository.findActiveMembersByHousehold(membership.idhousehold);
    const alreadyMember = existingActiveMembers.some(
      (m) => m.account?.email && m.account.email.toLowerCase() === normalizedEmail
    );

    // Nếu đã là thành viên: Vẫn trả 202 để bảo mật (anti-enumeration) nhưng không tạo invite
    if (alreadyMember) {
      return {
        sent: true,
        email: normalizedEmail,
        role,
        expiresAt: expiresAt.toISOString(),
      };
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

  // Gửi email bất đồng bộ (Graceful non-blocking - Task 57.3)
  async sendInviteEmailAsync({ toEmail, householdName, inviterName, role, code, expiresAt }) {
    try {
      const emailService = require('../../core/email.service');
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

      const html = `
        <div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:24px;border:1px solid #e0e0e0;border-radius:8px;">
          <h2 style="color:#1565C0;">FlowMoney — Lời Mời Gia Đình</h2>
          <p>Xin chào,</p>
          <p><strong>${inviterName}</strong> đã mời bạn tham gia vào tổ ấm <strong>"${householdName}"</strong> với vai trò <strong>${roleText}</strong>.</p>
          <div style="background-color:#e3f2fd;border-radius:8px;padding:16px;text-align:center;margin:20px 0;">
            <p style="margin:0 0 8px 0;font-size:13px;color:#555;">MÃ THAM GIA</p>
            <div style="font-size:32px;font-weight:bold;letter-spacing:6px;color:#1565C0;">
              ${code}
            </div>
            <p style="margin:8px 0 0 0;font-size:12px;color:#777;">Hạn dùng: ${formattedDate} (giờ Việt Nam)</p>
          </div>
          <p style="font-size:14px;color:#333;"><strong>Cách tham gia:</strong></p>
          <ol style="font-size:14px;color:#555;line-height:1.6;">
            <li>Mở ứng dụng FlowMoney trên điện thoại của bạn.</li>
            <li>Vào mục <strong>Nhà mình</strong> &rarr; Chọn <strong>Tham gia bằng mã</strong>.</li>
            <li>Nhập mã <strong>${code}</strong> và xác nhận.</li>
          </ol>
          <p style="font-size:12px;color:#888;">* Lưu ý: Nếu bạn chưa có tài khoản FlowMoney, hãy tải app và đăng ký bằng chính địa chỉ email này để được chấp nhận lời mời.</p>
          <hr style="border:none;border-top:1px solid #eee;margin:20px 0;" />
          <p style="color:#9e9e9e;font-size:11px;text-align:center;">Đây là email tự động từ hệ thống FlowMoney, vui lòng không trả lời thư này.</p>
        </div>
      `;

      if (emailService && typeof emailService.sendMail === 'function') {
        await emailService.sendMail({ to: toEmail, subject, text, html });
        logger.info(`[Household] Đã gửi thư mời email tới ${toEmail}`);
      }
    } catch (err) {
      logger.warn('[Household] Không thể gửi thư mời email (sẽ bỏ qua để không gián đoạn client)', {
        toEmail,
        error: err.message,
      });
    }
  },

  // ── 15. Lấy danh sách lời mời gửi tới tôi (Task 57.2 & 57.8 #6) ──────
  async getMyInvitations(idaccount, email) {
    let resolvedEmail = email;
    if (!resolvedEmail) {
      resolvedEmail = await householdService.getCallerEmail(idaccount);
    }
    const invites = await householdRepository.findPendingInvitationsForEmail(resolvedEmail, idaccount);

    return invites.map((inv) => ({
      code: inv.code,
      householdName: inv.household?.name || 'Gia đình',
      inviterName: inv.creator?.User?.fullname || inv.creator?.username || 'Chủ nhà',
      role: inv.role,
      memberCount: inv.household?.member_count || 1,
      maxMembers: inv.household?.max_members || 6,
      expiresAt: inv.expires_at.toISOString(),
    }));
  },

  // ── 16. Chấp nhận lời mời email (Task 57.1 & 57.2) ───────────
  async acceptEmailInvite(idaccount, code, callerEmail) {
    let resolvedEmail = callerEmail;
    if (!resolvedEmail) {
      resolvedEmail = await householdService.getCallerEmail(idaccount);
    }
    return householdService.joinByCode(idaccount, code, resolvedEmail);
  },

  // ── 17. Từ chối lời mời email (Task 57.2 & 57.7) ───────────────────
  async declineEmailInvite(idaccount, code, callerEmail) {
    const invite = await householdRepository.findInviteByCode(code);
    if (!invite || invite.household?.delete_at || invite.household?.status === 'Dissolved') {
      throw createError('Mã mời không tồn tại hoặc nhà đã giải tán', 'HOUSEHOLD_INVITE_INVALID', 404);
    }

    if (invite.declined_at) {
      throw createError('Lời mời này đã bị từ chối', 'HOUSEHOLD_INVITE_DECLINED', 409);
    }

    if (invite.revoked_at || invite.used_at) {
      throw createError('Mã mời đã được sử dụng hoặc đã bị hủy', 'HOUSEHOLD_INVITE_USED', 409);
    }

    if (invite.expires_at <= new Date()) {
      throw createError('Mã mời đã hết hạn', 'HOUSEHOLD_INVITE_EXPIRED', 410);
    }

    let resolvedEmail = callerEmail;
    if (!resolvedEmail) {
      resolvedEmail = await householdService.getCallerEmail(idaccount);
    }

    if (invite.email && resolvedEmail) {
      if (resolvedEmail.trim().toLowerCase() !== invite.email.toLowerCase()) {
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

  // ── Helper phát socket realtime cho nhà (Task 56.8: Phát tán đa kênh) ──
  async emitHouseholdChanged(idhousehold, eventType, payload, extraRecipients = []) {
    try {
      const { getIO, emitToAccount } = require('../../core/socket');
      const io = getIO ? getIO() : null;
      const data = {
        idhousehold: Number(idhousehold),
        eventType,
        payload,
        timestamp: new Date().toISOString(),
      };

      // Kênh 1: Room socket của nhà
      if (io) {
        io.to(`household_${idhousehold}`).emit('household.changed', data);
      }

      // Kênh 2: Room cá nhân (account_<idaccount>) của từng thành viên
      const activeMembers = await householdRepository.findActiveMembersByHousehold(idhousehold);
      const recipientIds = new Set((activeMembers || []).map((m) => Number(m.idaccount)));
      for (const extra of extraRecipients) {
        if (extra) recipientIds.add(Number(extra));
      }

      for (const accId of recipientIds) {
        emitToAccount(accId, 'household.changed', data);
      }
    } catch (err) {
      logger.warn('[Household] Không thể phát socket household.changed', { error: err.message, idhousehold });
    }
  },

  // ── Cập nhật trạng thái nhà theo gói Premium của Chủ nhà (Task 56.7) ────
  async updateHouseholdStatusByOwner(idaccount) {
    try {
      const ownerId = Number(idaccount);
      const owner = await prisma.account.findUnique({
        where: { idaccount: ownerId },
        select: {
          idaccount: true,
          type: true,
          premium_expires_at: true,
          status: true,
          delete_at: true,
        },
      });

      if (!owner || owner.delete_at || owner.status !== 'Active') {
        return;
      }

      const isPremium = owner.type === 'Premium' &&
        Boolean(owner.premium_expires_at) &&
        new Date(owner.premium_expires_at) > new Date();

      const targetStatus = isPremium ? 'Active' : 'ReadOnly';

      const ownedHouses = await prisma.household.findMany({
        where: {
          owner_idaccount: ownerId,
          delete_at: null,
          status: { not: 'Dissolved' },
        },
        select: {
          idhousehold: true,
          status: true,
        },
      });

      for (const house of ownedHouses) {
        if (house.status !== targetStatus) {
          await prisma.household.update({
            where: { idhousehold: house.idhousehold },
            data: {
              status: targetStatus,
              update_at: new Date(),
            },
          });
          logger.info(`[Household] Cập nhật trạng thái nhà ${house.idhousehold} sang ${targetStatus} do trạng thái Premium của chủ hộ ${ownerId}`);

          householdService.emitHouseholdChanged(house.idhousehold, 'STATUS_CHANGED', {
            status: targetStatus,
            reason: isPremium ? 'OWNER_PREMIUM_ACTIVE' : 'OWNER_PREMIUM_EXPIRED',
          });
        }
      }
    } catch (err) {
      logger.error('[Household] Lỗi khi cập nhật trạng thái nhà theo chủ hộ', { error: err.message, idaccount });
    }
  },
};

module.exports = householdService;
