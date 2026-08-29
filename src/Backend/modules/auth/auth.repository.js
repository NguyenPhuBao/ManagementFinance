const { prisma } = require('../../config/db');

const authRepository = {
  async findAccountByUsername(username) {
    return prisma.account.findUnique({
      where: { username },
      include: {
        role: { select: { idrole: true, rolename: true } },
        User:   { select: { iduser: true, fullname: true, email: true } },
      },
    });
  },

  async findAccountByEmail(email) {
    // CSDL mới: Account.Email là unique — tìm trực tiếp trên account
    return prisma.account.findUnique({
      where: { email },
      include: {
        role: { select: { idrole: true, rolename: true } },
        User: { select: { iduser: true, fullname: true, email: true } },
      },
    });
  },

  async findAccountByUsernameOrEmail(identifier) {
    return prisma.account.findFirst({
      where: {
        OR: [
          { username: identifier },
          { email: identifier },
        ],
      },
      include: {
        role: { select: { idrole: true, rolename: true } },
        User: { select: { iduser: true, fullname: true, email: true } },
      },
    });
  },

  async createAccountWithUser(data) {
    return prisma.$transaction(async (tx) => {
      const account = await tx.account.create({
        data: {
          username: data.username,
          email: data.email, // CSDL mới: Account bắt buộc có email (đồng bộ User.email)
          password: data.hashedPassword,
          status: 'Active',
          type: 'Basic', // CSDL mới: loại tài khoản mặc định
          idrole: 2,
        },
      });
      const user = await tx.user.create({
        data: {
          fullname: data.fullname,
          email: data.email,
          phone: data.phone || null,
          idaccount: account.idaccount,
        },
      });
      return {
        ...account,
        role: { idrole: 2, rolename: 'user' },
        User: { iduser: user.iduser, fullname: user.fullname, email: user.email },
      };
    });
  },

  async createOtp(email, idaccount, codeHash, purpose, expiresAt) {
    // CSDL mới: OTP có Idaccount FK (nullable đối với mục đích 'register')
    return prisma.otp_code.create({
      data: { 
        email, 
        idaccount: idaccount || null, 
        code_hash: codeHash, 
        purpose, 
        expires_at: expiresAt, 
        is_used: false 
      },
    });
  },

  async findValidOtp(idaccount, codeHash, purpose) {
    // Tra theo idaccount + purpose (cho reset_password, change_email)
    return prisma.otp_code.findFirst({
      where: {
        idaccount,
        code_hash: codeHash,
        purpose,
        is_used: false,
        expires_at: { gt: new Date() },
      },
      orderBy: { created_at: 'desc' },
    });
  },

  async findValidOtpByEmail(email, codeHash, purpose) {
    // Tra theo email + purpose (cho register khi chưa có idaccount)
    return prisma.otp_code.findFirst({
      where: {
        email,
        code_hash: codeHash,
        purpose,
        is_used: false,
        expires_at: { gt: new Date() },
      },
      orderBy: { created_at: 'desc' },
    });
  },

  async markOtpUsed(idOtp) {
    return prisma.otp_code.update({
      where: { id_otp: idOtp },
      data: { is_used: true },
    });
  },

  async findAccountById(idaccount) {
    return prisma.account.findUnique({
      where: { idaccount },
      include: {
        role: { select: { idrole: true, rolename: true } },
        User: true,
      },
    });
  },

  async updatePassword(idaccount, hashedPassword) {
    return prisma.account.update({
      where: { idaccount },
      data: { password: hashedPassword, update_at: new Date() },
    });
  },

  async scheduleDeletion(idaccount) {
    const scheduledAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // +30 days
    // CSDL mới: dùng Delete_at thay scheduled_delete_at
    return prisma.account.update({
      where: { idaccount },
      data: {
        status: 'PendingDelete',
        delete_at: scheduledAt,
        update_at: new Date(),
      },
    });
  },

  async cancelDeletion(idaccount) {
    return prisma.account.update({
      where: { idaccount },
      data: {
        status: 'Active',
        delete_at: null,
        update_at: new Date(),
      },
    });
  },

  async getProfile(idaccount) {
    return prisma.user.findUnique({
      where: { idaccount },
    });
  },

  async updateProfile(idaccount, data) {
    // CSDL mới: location → country_code
    return prisma.user.update({
      where: { idaccount },
      data: { ...data, update_at: new Date() },
    });
  },

  async updateEmail(idaccount, newEmail) {
    // CSDL mới: User.Email phải đồng bộ Account.Email → cập nhật CẢ 2 bảng trong 1 transaction
    return prisma.$transaction([
      prisma.user.update({
        where: { idaccount },
        data: { email: newEmail, update_at: new Date() },
      }),
      prisma.account.update({
        where: { idaccount },
        data: { email: newEmail, update_at: new Date() },
      }),
    ]);
  },

  async createAuditLog(data) {
    return prisma.auditlog.create({
      data: {
        idaccount: data.idaccount,
        request: (data.request || '').substring(0, 200),
        req_status: data.req_status || 'Pass',
        reason: data.reason ? String(data.reason).substring(0, 200) : null,
        time_req: data.time_req || new Date(),
        time_res: data.time_res || new Date(),
      },
    });
  },

  async getRecentAuditLogs({ page = 1, limit = 5, sort = 'desc' } = {}) {
    const total = await prisma.auditlog.count();
    const parsedLimit = parseInt(limit, 10) || 5;
    const totalPages = Math.max(1, Math.ceil(total / parsedLimit));
    const parsedPage = Math.max(1, Math.min(parseInt(page, 10) || 1, totalPages));

    const skip = (parsedPage - 1) * parsedLimit;

    const items = await prisma.auditlog.findMany({
      skip,
      take: parsedLimit,
      orderBy: { time_req: sort === 'asc' ? 'asc' : 'desc' },
      include: {
        account: {
          select: {
            idaccount: true,
            username: true,
            User: {
              select: {
                fullname: true,
              },
            },
          },
        },
      },
    });

    return {
      total,
      page: parsedPage,
      limit: parsedLimit,
      totalPages,
      items,
    };
  },

  async findAccountByUsernameOrEmail(identifier) {
    if (!identifier) return null;
    return prisma.account.findFirst({
      where: {
        OR: [{ username: identifier }, { email: identifier }],
      },
      include: {
        User: { select: { fullname: true } },
      },
    });
  },
};

module.exports = authRepository;

