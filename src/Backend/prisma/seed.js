const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

const prisma = new PrismaClient();

// Danh mục mặc định toàn cục (Create_by = idaccount admin — đọc từ DB)
const DEFAULT_CATEGORIES = [
  // ── Thu ──
  { name: 'Lương', classify: 'Thu', icon: 'salary', keyword: 'luong, salary' },
  { name: 'Thưởng', classify: 'Thu', icon: 'bonus', keyword: 'thuong, bonus' },
  { name: 'Đầu tư', classify: 'Thu', icon: 'invest', keyword: 'dau tu, invest' },
  // ── Chi ──
  { name: 'Ăn uống', classify: 'Chi', icon: 'food', keyword: 'an uong, food, grab' },
  { name: 'Di chuyển', classify: 'Chi', icon: 'transport', keyword: 'di chuyen, xang, grabcar' },
  { name: 'Mua sắm', classify: 'Chi', icon: 'shopping', keyword: 'mua sam, shopping' },
  { name: 'Nhà cửa', classify: 'Chi', icon: 'home', keyword: 'nha cua, tien nha' },
  { name: 'Hóa đơn', classify: 'Chi', icon: 'bill', keyword: 'hoa don, dien nuoc' },
  { name: 'Giải trí', classify: 'Chi', icon: 'entertain', keyword: 'giai tri, movie, game' },
  { name: 'Y tế', classify: 'Chi', icon: 'health', keyword: 'y te, benh vien, thuoc' },
  { name: 'Giáo dục', classify: 'Chi', icon: 'education', keyword: 'giao duc, hoc phi' },
  // ── Vay/nợ ──
  { name: 'Cho vay', classify: 'Vay/no', icon: 'lend', keyword: 'cho vay' },
  { name: 'Đi vay', classify: 'Vay/no', icon: 'borrow', keyword: 'di vay, vay' },
];

async function seed() {
  try {
    // 1. Seed roles nếu chưa có
    const roleCount = await prisma.role.count();
    if (roleCount === 0) {
      await prisma.role.createMany({
        data: [
          { idrole: 1, rolename: 'admin', description: 'Quản trị hệ thống' },
          { idrole: 2, rolename: 'user', description: 'Người dùng' },
        ],
      });
      console.log('Roles seeded: admin(1), user(2)');
    }

    // 2. Kiem tra admin da ton tai chua
    const existing = await prisma.account.findUnique({ where: { username: 'admin' } });
    if (existing) {
      console.log('Tai khoan admin da ton tai:', existing.username);
      // Vẫn chạy phần seed bổ sung (category default + ví Saving) nếu thiếu
      await seedDefaultData(prisma);
      await prisma.$disconnect();
      return;
    }

    // 3. Hash mat khau
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash('123456', salt);
    console.log('Password hashed:', hashedPassword.substring(0, 20) + '...');

    // 3. Tao account + User trong transaction
    const result = await prisma.$transaction(async (tx) => {
      const account = await tx.account.create({
        data: {
          username: 'admin',
          email: 'admin@wealthcommand.com', // CSDL mới: Account bắt buộc có email
          password: hashedPassword,
          status: 'Active',
          type: 'Basic', // CSDL mới: loại tài khoản
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

      // Seed ví Saving cứng cho admin (CSDL mới: tối đa 1 ví Saving/account)
      const savingWallet = await tx.wallet.create({
        data: {
          idwallet: crypto.randomUUID(),
          idaccount: account.idaccount,
          name: 'Tiết kiệm',
          type: 'Saving',
          balance: 0,
          currency: 'VND',
          status: 'Active',
          include_in_total: true,
          update_at: new Date(),
        },
      });
      console.log('Saving wallet created: ' + savingWallet.idwallet);

      return { account, user };
    });

    // 4. Seed danh mục mặc định + ví Saving cứng cho admin
    await seedDefaultData(prisma);

    console.log('SUCCESS: Tai khoan admin-123456 da duoc tao');
    console.log(JSON.stringify({ username: result.account.username, status: result.account.status, role: 'admin' }));
  } catch (error) {
    console.error('FAILED:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

/**
 * Seed dữ liệu nền bổ sung (chạy dù admin đã tồn tại hay chưa):
 * 1. Ví Saving cứng cho admin (tối đa 1 ví Saving/account)
 * 2. Danh mục mặc định toàn cục (Create_by = idaccount admin — đọc từ DB)
 */
async function seedDefaultData(db) {
  const adminAccount = await db.account.findUnique({
    where: { username: 'admin' },
    select: { idaccount: true },
  });
  if (!adminAccount) return;
  const adminId = adminAccount.idaccount;

  // 1. Ví Saving cứng — chỉ tạo nếu chưa có ví Saving nào của admin
  const existingSaving = await db.wallet.findFirst({
    where: { idaccount: adminId, type: 'Saving', delete_at: null },
  });
  if (!existingSaving) {
    await db.wallet.create({
      data: {
        idwallet: crypto.randomUUID(),
        idaccount: adminId,
        name: 'Tiết kiệm',
        type: 'Saving',
        balance: 0,
        currency: 'VND',
        status: 'Active',
        include_in_total: true,
        update_at: new Date(),
      },
    });
    console.log('Saving wallet seeded for admin');
  }

  // 2. Danh mục mặc định toàn cục
  const existingCat = await db.category.count({ where: { is_default: true } });
  if (existingCat === 0) {
    await db.category.createMany({
      data: DEFAULT_CATEGORIES.map((c) => ({
        idcategory: crypto.randomUUID(),
        create_by: adminId,
        name_category: c.name,
        classify: c.classify,
        is_default: true,
        is_group: false,
        idgroup: null,
        keyword: c.keyword,
        icon: c.icon,
      })),
    });
    console.log('Default categories seeded: ' + DEFAULT_CATEGORIES.length);
  }
}

seed();
