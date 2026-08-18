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
    return prisma.user.findFirst({
      where: { email },
      include: { account: { include: { role: { select: { idrole: true, rolename: true } } } } },
    });
  },

  async createAccountWithUser(data) {
    return prisma.$transaction(async (tx) => {
      const account = await tx.account.create({
        data: {
          username: data.username,
          password: data.hashedPassword,
          status: 'Active',
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

  async createOtp(email, codeHash, purpose, expiresAt) {
    return prisma.otp_code.create({
      data: { email, code_hash: codeHash, purpose, expires_at: expiresAt, is_used: false },
    });
  },

  async findValidOtp(email, codeHash, purpose) {
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

  async markOtpUsed(id) {
    return prisma.otp_code.update({
      where: { id },
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
      data: { password: hashedPassword, updated_at: new Date() },
    });
  },

  async softDeleteAccount(idaccount) {
    return prisma.account.update({
      where: { idaccount },
      data: { status: 'Deleted', updated_at: new Date() },
    });
  },

  async getProfile(idaccount) {
    return prisma.user.findUnique({
      where: { idaccount },
    });
  },

  async updateProfile(idaccount, data) {
    return prisma.user.update({
      where: { idaccount },
      data: { ...data, updated_at: new Date() },
    });
  },

  async updateEmail(idaccount, newEmail) {
    return prisma.user.update({
      where: { idaccount },
      data: { email: newEmail, updated_at: new Date() },
    });
  },
};

module.exports = authRepository;

