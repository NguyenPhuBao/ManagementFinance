const { prisma } = require('../../config/db');

const householdRepository = {
  async createHousehold({ name, ownerIdaccount, maxMembers = 6, maxSharedWallets = 10, contributionDueDay = 5 }, tx = prisma) {
    return tx.household.create({
      data: {
        name,
        owner_idaccount: ownerIdaccount,
        max_members: maxMembers,
        max_shared_wallets: maxSharedWallets,
        contribution_due_day: contributionDueDay,
        status: 'Active',
      },
    });
  },

  async addMember({ idhousehold, idaccount, role }, tx = prisma) {
    return tx.household_member.create({
      data: {
        idhousehold,
        idaccount,
        role,
      },
    });
  },

  async findHouseholdById(idhousehold) {
    if (!idhousehold) return null;
    return prisma.household.findFirst({
      where: {
        idhousehold: Number(idhousehold),
        delete_at: null,
      },
    });
  },

  async findHouseholdAnyStatus(idhousehold) {
    if (!idhousehold) return null;
    return prisma.household.findFirst({
      where: {
        idhousehold: Number(idhousehold),
      },
    });
  },

  async findMember(idhousehold, idaccount) {
    if (!idhousehold || !idaccount) return null;
    return prisma.household_member.findFirst({
      where: {
        idhousehold: Number(idhousehold),
        idaccount: Number(idaccount),
        left_at: null,
      },
      include: {
        household: true,
      },
    });
  },

  async findFormerMember(idhousehold, idaccount) {
    if (!idhousehold || !idaccount) return null;
    return prisma.household_member.findFirst({
      where: {
        idhousehold: Number(idhousehold),
        idaccount: Number(idaccount),
      },
    });
  },

  async findActiveMemberByAccount(idaccount) {
    return prisma.household_member.findFirst({
      where: {
        idaccount: Number(idaccount),
        left_at: null,
      },
      include: {
        household: true,
        account: {
          select: {
            idaccount: true,
            username: true,
            email: true,
            User: {
              select: { fullname: true },
            },
          },
        },
      },
    });
  },

  async findActiveMembersByHousehold(idhousehold) {
    return prisma.household_member.findMany({
      where: {
        idhousehold: Number(idhousehold),
        left_at: null,
      },
      include: {
        account: {
          select: {
            idaccount: true,
            username: true,
            email: true,
            User: {
              select: { fullname: true },
            },
          },
        },
      },
      orderBy: { joined_at: 'asc' },
    });
  },

  async findFormerMembersByHousehold(idhousehold) {
    return prisma.household_member.findMany({
      where: {
        idhousehold: Number(idhousehold),
        left_at: { not: null },
      },
      include: {
        account: {
          select: {
            idaccount: true,
            username: true,
            User: {
              select: { fullname: true },
            },
          },
        },
      },
      orderBy: { left_at: 'desc' },
    });
  },

  async findInviteByCode(code) {
    return prisma.household_invite.findUnique({
      where: { code: String(code).trim().toUpperCase() },
      include: {
        household: true,
        creator: {
          select: {
            idaccount: true,
            username: true,
            User: { select: { fullname: true } },
          },
        },
      },
    });
  },

  async createInvite({ code, idhousehold, role, created_by, email = null, invitee_idaccount = null, expires_at }) {
    return prisma.household_invite.create({
      data: {
        code: String(code).trim().toUpperCase(),
        idhousehold,
        role,
        created_by,
        email: email ? String(email).trim().toLowerCase() : null,
        invitee_idaccount,
        expires_at: new Date(expires_at),
      },
    });
  },

  async revokeActiveEmailInvitesForHousehold(idhousehold, email) {
    return prisma.household_invite.updateMany({
      where: {
        idhousehold,
        email: String(email).trim().toLowerCase(),
        used_at: null,
        revoked_at: null,
        declined_at: null,
      },
      data: { revoked_at: new Date() },
    });
  },

  async findInvitesByHousehold(idhousehold) {
    const sevenDaysAgo = new Date(Date.now() - 7 * 86400 * 1000);
    return prisma.household_invite.findMany({
      where: {
        idhousehold: Number(idhousehold),
        OR: [
          // Mã còn hiệu lực
          {
            used_at: null,
            revoked_at: null,
            declined_at: null,
            expires_at: { gt: new Date() },
          },
          // Lời mời email đã từ chối hoặc hết hạn trong 7 ngày gần nhất
          {
            email: { not: null },
            create_at: { gte: sevenDaysAgo },
          },
        ],
      },
      orderBy: { create_at: 'desc' },
    });
  },

  async revokeInvite(code) {
    return prisma.household_invite.update({
      where: { code: String(code).trim().toUpperCase() },
      data: { revoked_at: new Date() },
    });
  },

  async markInviteUsed(code, used_by) {
    return prisma.household_invite.update({
      where: { code: String(code).trim().toUpperCase() },
      data: {
        used_by: Number(used_by),
        used_at: new Date(),
      },
    });
  },

  async markInviteDeclined(code) {
    return prisma.household_invite.update({
      where: { code: String(code).trim().toUpperCase() },
      data: { declined_at: new Date() },
    });
  },

  async updateMemberRole(idhousehold, idaccount, role) {
    return prisma.household_member.updateMany({
      where: {
        idhousehold: Number(idhousehold),
        idaccount: Number(idaccount),
        left_at: null,
      },
      data: { role },
    });
  },

  async transferOwner(idhousehold, currentOwnerId, newOwnerId) {
    return prisma.$transaction([
      prisma.household.update({
        where: { idhousehold: Number(idhousehold) },
        data: {
          owner_idaccount: Number(newOwnerId),
          update_at: new Date(),
        },
      }),
      prisma.household_member.updateMany({
        where: {
          idhousehold: Number(idhousehold),
          idaccount: Number(currentOwnerId),
          left_at: null,
        },
        data: { role: 'Member' },
      }),
      prisma.household_member.updateMany({
        where: {
          idhousehold: Number(idhousehold),
          idaccount: Number(newOwnerId),
          left_at: null,
        },
        data: { role: 'Owner' },
      }),
    ]);
  },

  async removeMember(idhousehold, idaccount) {
    return prisma.household_member.updateMany({
      where: {
        idhousehold: Number(idhousehold),
        idaccount: Number(idaccount),
        left_at: null,
      },
      data: { left_at: new Date() },
    });
  },

  async dissolveHousehold(idhousehold) {
    const now = new Date();
    const hhId = Number(idhousehold);
    return prisma.$transaction([
      prisma.household.update({
        where: { idhousehold: hhId },
        data: {
          status: 'Dissolved',
          delete_at: now,
          update_at: now,
        },
      }),
      prisma.household_member.updateMany({
        where: {
          idhousehold: hhId,
          left_at: null,
        },
        data: { left_at: now },
      }),
      // Task 57.6: Thu hồi tất cả mã mời chưa sử dụng của gia đình
      prisma.household_invite.updateMany({
        where: {
          idhousehold: hhId,
          used_at: null,
          revoked_at: null,
          declined_at: null,
        },
        data: { revoked_at: now },
      }),
      // Task 57.6: Xóa mềm toàn bộ dữ liệu chung ở 5 bảng thực thể
      prisma.wallet.updateMany({
        where: { idhousehold: hhId, delete_at: null },
        data: { delete_at: now, update_at: now },
      }),
      prisma.transaction.updateMany({
        where: { idhousehold: hhId, delete_at: null },
        data: { delete_at: now, update_at: now },
      }),
      prisma.budget.updateMany({
        where: { idhousehold: hhId, delete_at: null },
        data: { delete_at: now, update_at: now },
      }),
      prisma.goal.updateMany({
        where: { idhousehold: hhId, delete_at: null },
        data: { delete_at: now, update_at: now },
      }),
      prisma.category.updateMany({
        where: { idhousehold: hhId, delete_at: null },
        data: { delete_at: now, update_at: now },
      }),
    ]);
  },

  async countActiveMembers(idhousehold) {
    return prisma.household_member.count({
      where: {
        idhousehold: Number(idhousehold),
        left_at: null,
      },
    });
  },

  async countActiveInvites(idhousehold) {
    return prisma.household_invite.count({
      where: {
        idhousehold: Number(idhousehold),
        used_at: null,
        revoked_at: null,
        declined_at: null,
        expires_at: { gt: new Date() },
      },
    });
  },

  async countEmailInvitesIn24h(idhousehold) {
    const since24h = new Date(Date.now() - 24 * 3600 * 1000);
    return prisma.household_invite.count({
      where: {
        idhousehold: Number(idhousehold),
        email: { not: null },
        create_at: { gte: since24h },
      },
    });
  },

  async countEmailInvitesIn1h(idhousehold) {
    const since1h = new Date(Date.now() - 3600 * 1000);
    return prisma.household_invite.count({
      where: {
        idhousehold: Number(idhousehold),
        email: { not: null },
        create_at: { gte: since1h },
      },
    });
  },

  async findPendingInvitationsForEmail(email, idaccount) {
    const normalizedEmail = email ? String(email).trim().toLowerCase() : '';
    const now = new Date();

    return prisma.household_invite.findMany({
      where: {
        OR: [
          { email: normalizedEmail },
          idaccount ? { invitee_idaccount: Number(idaccount) } : undefined,
        ].filter(Boolean),
        used_at: null,
        revoked_at: null,
        declined_at: null,
        expires_at: { gt: now },
        household: {
          status: 'Active',
          delete_at: null,
        },
      },
      include: {
        household: true,
        creator: {
          select: {
            idaccount: true,
            username: true,
            User: { select: { fullname: true } },
          },
        },
      },
      orderBy: { create_at: 'desc' },
    });
  },

  async updateHouseholdStatus(idhousehold, status) {
    return prisma.household.update({
      where: { idhousehold: Number(idhousehold) },
      data: {
        status,
        update_at: new Date(),
      },
    });
  },
};

module.exports = householdRepository;
