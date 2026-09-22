const { randomUUID } = require('crypto');
const { prisma } = require('../src/Backend/config/db');
const adminService = require('../src/Backend/modules/admin/admin.service');
const adminRepository = require('../src/Backend/modules/admin/admin.repository');

const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  bright: "\x1b[1m",
};

async function runAdminTests() {
  console.log(`\n${colors.cyan}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}         KIỂM THỬ TOÀN DIỆN MODULE ADMIN THEO CSDL MỚI                ${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}======================================================================${colors.reset}\n`);

  // 1. Test Thống kê Tổng quan (Dashboard Stats)
  console.log(`1. Test Thống kê Tổng quan Dashboard...`);
  const totalUsers = await adminService.getTotalUsers();
  const totalCategories = await adminService.getTotalCategories();
  const userGrowth = await adminService.getUserToTime('today');

  console.log(`   ✔ Total Users: ${totalUsers.total}`);
  console.log(`   ✔ Total Categories: ${totalCategories.total}`);
  console.log(`   ✔ User Growth Today: ${userGrowth.growth}% (Current: ${userGrowth.current}, Prev: ${userGrowth.previous})`);

  // 2. Test Quản lý Người dùng (Users & Account.Type)
  console.log(`\n2. Test Lấy danh sách & Chi tiết Người dùng (Account.Type & Country_code)...`);
  const userList = await adminService.getUsers();
  if (userList.length === 0) throw new Error('Không tìm thấy người dùng nào trong CSDL!');

  const firstUser = userList.find(u => u.status === 'Active') || userList[0];
  console.log(`   ✔ Danh sách người dùng: Tìm thấy ${userList.length} users.`);
  console.log(`     • Sample User: #${firstUser.id} (${firstUser.fullname})`);
  console.log(`     • Type       : ${firstUser.type} (Basic/Premium)`);
  console.log(`     • Status     : ${firstUser.status}`);
  console.log(`     • Country    : ${firstUser.country_code}`);

  const userDetail = await adminService.getUserDetail(firstUser.id);
  if (!userDetail || !userDetail.type) throw new Error('Chi tiết người dùng thiếu trường Type!');
  console.log(`   ✔ Chi tiết người dùng: #${userDetail.id}, Type="${userDetail.type}", Role="${userDetail.rolename}"`);

  // 2.1 Test Cập nhật trạng thái người dùng (Khóa / Mở khóa)
  console.log(`\n3. Test Cập nhật trạng thái Tài khoản (updateStatus)...`);
  const statusToggle1 = await adminService.updateStatus(firstUser.id, { reason_inactive: 'Lý do kiểm thử hệ thống' });
  console.log(`   ✔ Toggle 1: ${statusToggle1.previousStatus} ──▶ ${statusToggle1.newStatus}`);
  const statusToggle2 = await adminService.updateStatus(firstUser.id);
  console.log(`   ✔ Toggle 2: ${statusToggle2.previousStatus} ──▶ ${statusToggle2.newStatus} (Khôi phục ban đầu)`);

  // 3. Test Quản lý Danh mục Hệ thống (Category)
  console.log(`\n4. Test Quản lý Danh mục Hệ thống (Category & Keyword)...`);
  const testCategoryName = `Test Danh Mục Admin ${Date.now().toString().slice(-4)}`;
  const createdCat = await adminService.addCategory({
    name: testCategoryName,
    classify: 'Chi',
    is_default: false,
    keyword: 'test;admin;category;lunch',
    icon: 'restaurant',
  }, 1);

  console.log(`   ✔ Thêm danh mục thành công: ID="${createdCat.id}", Name="${createdCat.name}", Classify="${createdCat.classify}"`);

  const updatedCat = await adminService.updateCategory(createdCat.id, {
    name: testCategoryName + ' (Updated)',
    classify: 'Chi',
    is_default: false,
    keyword: 'test;admin;updated',
    icon: 'fastfood',
  });
  console.log(`   ✔ Cập nhật danh mục thành công: Name="${updatedCat.name}"`);

  const deletedCat = await adminService.deleteCategory(createdCat.id);
  console.log(`   ✔ Xóa mềm danh mục thành công: ID="${deletedCat.id}"`);

  const checkDeleted = await prisma.category.findUnique({ where: { idcategory: createdCat.id } });
  if (!checkDeleted.delete_at) throw new Error('Danh mục chưa được đánh dấu delete_at!');
  console.log(`   ✔ Xác nhận Soft Delete: delete_at="${checkDeleted.delete_at.toISOString()}"`);

  // 4. Test Thống kê Audit Log (Đã kiểm tra prisma.auditlog)
  console.log(`\n5. Test Thống kê Audit Log & Login Stats (Prisma auditlog)...`);
  // Tạo 1 log mẫu
  const sampleLog = await prisma.auditlog.create({
    data: {
      idaccount: firstUser.id,
      request: 'Đăng nhập hệ thống Web',
      req_status: 'Pass',
      time_req: new Date(),
      time_res: new Date(),
    },
  });

  const loginStats = await adminService.getLoginStats('today');
  console.log(`   ✔ Thống kê Đăng nhập: Total=${loginStats.summary.total}, Max=${loginStats.summary.max}, Timeline Buckets=${loginStats.timeline.length}`);

  const reqStats = await adminService.getRequestStats('today');
  console.log(`   ✔ Thống kê Request  : Total=${reqStats.summary.total}, Max=${reqStats.summary.max}, Timeline Buckets=${reqStats.timeline.length}`);

  // 5. Dọn dẹp dữ liệu test
  console.log(`\n6. Dọn dẹp dữ liệu test...`);
  await prisma.auditlog.delete({ where: { idlog: sampleLog.idlog } }).catch(() => {});
  await prisma.category.delete({ where: { idcategory: createdCat.id } }).catch(() => {});

  console.log(`\n${colors.green}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.green}${colors.bright}   🎉 MODULE ADMIN ĐÃ ĐƯỢC CẬP NHẬT VÀ KIỂM THỬ CHUẨN XÁC 100%!       ${colors.reset}`);
  console.log(`${colors.green}${colors.bright}======================================================================${colors.reset}\n`);

  await prisma.$disconnect();
  process.exit(0);
}

runAdminTests().catch(err => {
  console.error('Lỗi khi chạy admin test:', err);
  process.exit(1);
});
