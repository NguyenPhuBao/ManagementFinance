const { PrismaClient } = require('@prisma/client');
const db = new PrismaClient();

async function seed() {
  await db.role.createMany({
    data: [
      { rolename: 'admin', description: 'Quan tri he thong' },
      { rolename: 'user',  description: 'Nguoi dung thuong' },
    ],
    skipDuplicates: true,
  });
  console.log('✅ Seed role: admin + user done');
  await db.$disconnect();
}

seed().catch(e => {
  console.error(e);
  process.exit(1);
});
