const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const acc = await prisma.account.count();
  const cat = await prisma.category.count();
  const bg = await prisma.budget.count();
  const bl = await prisma.bill.count();
  const gl = await prisma.goal.count();
  const tx = await prisma.transaction.count();
  console.log('✔ Supabase Database Connection Healthy!');
  console.log('Record counts:', { accounts: acc, categories: cat, budgets: bg, bills: bl, goals: gl, transactions: tx });
  await prisma.$disconnect();
}

main();
