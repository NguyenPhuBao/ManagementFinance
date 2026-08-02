const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function seed() {
  try {
    // 1. Kiem tra admin da ton tai chua
    const existing = await prisma.account.findUnique({ where: { username: 'admin' } });
    if (existing) {
      console.log('Tai khoan admin da ton tai:', existing.username);
      await prisma.$disconnect();
      return;
    }

    // 2. Hash mat khau
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('123456', salt);
    console.log('Password hashed:', hashedPassword.substring(0, 20) + '...');

    // 3. Tao account + User trong transaction
    const result = await prisma.$transaction(async (tx) => {
      const account = await tx.account.create({
        data: {
          username: 'admin',
          password: hashedPassword,
          status: 'Active',
          idrole: 1, // admin role
        },
      });
      console.log('Account created: id=' + account.idaccount + ', username=' + account.username);

      const user = await tx.user.create({
        data: {
          fullname: 'Administrator',
          email: 'admin@wealthcommand.com',
          phone: '0355281276',
          idaccount: account.idaccount,
        },
      });
      console.log('User created: id=' + user.iduser + ', name=' + user.fullname);

      return { account, user };
    });

    console.log('SUCCESS: Tai khoan admin-123456 da duoc tao');
    console.log(JSON.stringify({ username: result.account.username, status: result.account.status, role: 'admin' }));
  } catch (error) {
    console.error('FAILED:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

seed();
