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
};

module.exports = authRepository;
