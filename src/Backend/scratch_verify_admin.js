const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function checkAdmin() {
  try {
    const adminAccount = await prisma.account.findFirst({ where: { role: { rolename: 'admin' } } });
    if (!adminAccount) {
      console.log('FAIL: Không tìm thấy tài khoản admin');
      return;
    }
    
    const isValid = await bcrypt.compare('Sa12phubao$', adminAccount.password);
    if (isValid) {
      console.log('SUCCESS: Tài khoản admin đã tồn tại và mật khẩu chính xác là Sa12phubao$');
    } else {
      console.log('FAIL: Mật khẩu không đúng!');
    }
  } catch (err) {
    console.error('Lỗi khi kiểm tra admin:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

checkAdmin();
