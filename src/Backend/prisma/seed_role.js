const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  await prisma.role.createMany({
    data: [
      { idrole: 1, rolename: 'admin', description: 'quản trị viên hệ thống' },
      { idrole: 2, rolename: 'user', description: 'người dùng' }
    ]
  });
  console.log('Roles created');
}
main().finally(() => prisma.$disconnect());
