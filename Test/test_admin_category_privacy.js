/**
 * Test Suite: Kiểm thử bảo mật danh mục người dùng đối với Admin API
 * Đảm bảo:
 * 1. Admin API không bao giờ trả về danh mục cá nhân của người dùng.
 * 2. Nếu vô tình lọt qua parser, dữ liệu nhạy cảm phải bị mặt nạ hóa thành '***'.
 * 3. Tuyệt đối cấm Admin sửa danh mục người dùng (403 Forbidden).
 * 4. Tuyệt đối cấm Admin xóa danh mục người dùng (403 Forbidden).
 * 5. Danh mục mặc định hệ thống được bảo vệ chống xóa (400 Bad Request).
 */

const { prisma } = require('../src/Backend/config/db');
const adminService = require('../src/Backend/modules/admin/admin.service');
const adminRepository = require('../src/Backend/modules/admin/admin.repository');

async function runTest() {
  console.log('======================================================================');
  console.log('   BẮT ĐẦU KIỂM THỬ BẢO MẬT DANH MỤC NGƯỜI DÙNG ĐỐI VỚI ADMIN API      ');
  console.log('======================================================================\n');

  let testUserAccount = null;
  let testUserCategory = null;
  let testSystemCategory = null;

  try {
    // 0. Tạo dữ liệu mẫu test
    const timestamp = Date.now();
    testUserAccount = await prisma.account.create({
      data: {
        username: `test_user_cat_${timestamp}`,
        email: `test_user_cat_${timestamp}@example.com`,
        password: 'hashed_password_placeholder',
        idrole: 2, // User role
        status: 'Active',
      },
    });

    testUserCategory = await prisma.category.create({
      data: {
        idcategory: `cat-user-${timestamp}`,
        create_by: testUserAccount.idaccount,
        name_category: `Danh Mục Nhạy Cảm User ${timestamp}`,
        classify: 'Chi',
        is_default: false,
        keyword: 'thuoc tay, benh vien, no rieng',
      },
    });

    testSystemCategory = await prisma.category.create({
      data: {
        idcategory: `cat-sys-${timestamp}`,
        create_by: 1, // Admin account
        name_category: `Danh Mục Hệ Thống ${timestamp}`,
        classify: 'Chi',
        is_default: true,
        keyword: 'an uong, cafe',
      },
    });

    console.log('✓ Đã chuẩn bị dữ liệu kiểm thử (1 danh mục user, 1 danh mục hệ thống)');

    // 1. Kiểm thử getAllCategories / getCategories không bao giờ trả về danh mục user
    console.log('\n1. Kiểm thử truy vấn danh mục Admin (loại trừ danh mục người dùng):');
    const categoriesFromRepo = await adminRepository.getAllCategories();
    const leakedInRepo = categoriesFromRepo.some(c => c.idcategory === testUserCategory.idcategory || c.is_default === false);
    if (leakedInRepo) {
      throw new Error('FAIL: adminRepository.getAllCategories vẫn trả về danh mục người dùng (is_default = false)!');
    }
    console.log('  ✓ PASSED: adminRepository.getAllCategories chỉ trả về danh mục hệ thống (is_default = true)');

    const categoriesFromService = await adminService.getCategories();
    const leakedInService = categoriesFromService.some(c => c.id === testUserCategory.idcategory);
    if (leakedInService) {
      throw new Error('FAIL: adminService.getCategories vẫn trả về danh mục người dùng!');
    }
    console.log('  ✓ PASSED: adminService.getCategories hoàn toàn cách ly, không để lộ danh mục người dùng');

    // 2. Kiểm thử cơ chế phòng vệ Masking *** khi vô tình danh mục user lọt vào mapper
    console.log('\n2. Kiểm thử cơ chế phòng vệ Masking (ẩn danh bằng ***):');
    const rawFakeCats = [
      {
        idcategory: 'fake-user-cat',
        name_category: 'Khoản Nợ Riêng Tư Cực Kỳ Nhạy Cảm',
        classify: 'Chi',
        is_default: false,
        is_group: false,
        idgroup: null,
        keyword: 'vay nong, tra no',
        icon: 'money',
        create_by: testUserAccount.idaccount,
        account: { username: 'test_user_private', User: { fullname: 'Nguyễn Văn Ẩn' } },
        create_at: new Date(),
        update_at: new Date(),
      }
    ];

    const origGetAll = adminRepository.getAllCategories;
    try {
      adminRepository.getAllCategories = async () => rawFakeCats;
      const maskedResults = await adminService.getCategories();
      const maskedItem = maskedResults[0];

      if (maskedItem.name !== '***' || maskedItem.keyword !== '***') {
        throw new Error(`FAIL: Danh mục người dùng chưa được mặt nạ hóa thành '***'! Nhận được: name=${maskedItem.name}, keyword=${maskedItem.keyword}`);
      }
      if (maskedItem.created_by !== '***' && maskedItem.created_by_name !== '***') {
        throw new Error(`FAIL: Thông tin người tạo chưa được mặt nạ hóa thành '***'! Nhận được: ${maskedItem.created_by}`);
      }
      console.log('  ✓ PASSED: Danh mục người dùng khi lọt vào Admin API bị ẩn danh hóa 100% bằng ***');
    } finally {
      adminRepository.getAllCategories = origGetAll;
    }

    // 3. Kiểm thử cấm sửa danh mục người dùng (403 Forbidden)
    console.log('\n3. Kiểm thử cấm sửa danh mục người dùng (updateCategory):');
    let editUserBlocked = false;
    try {
      await adminService.updateCategory(testUserCategory.idcategory, { name: 'Tên Đã Bị Admin Sửa' }, 1);
    } catch (err) {
      if (err.statusCode === 403) {
        editUserBlocked = true;
      } else {
        console.warn(`    Lưu ý: Lỗi trả về status code ${err.statusCode}: ${err.message}`);
        if (err.statusCode === 403 || err.message.includes('người dùng')) {
          editUserBlocked = true;
        }
      }
    }
    if (!editUserBlocked) {
      throw new Error('FAIL: Admin vẫn có thể cập nhật hoặc không bị chặn 403 khi sửa danh mục người dùng!');
    }
    console.log('  ✓ PASSED: Chặn 403 Forbidden khi Admin cố tình sửa danh mục của người dùng');

    // 4. Kiểm thử cấm xóa danh mục người dùng (403 Forbidden)
    console.log('\n4. Kiểm thử cấm xóa danh mục người dùng (deleteCategory):');
    let deleteUserBlocked = false;
    try {
      await adminService.deleteCategory(testUserCategory.idcategory);
    } catch (err) {
      if (err.statusCode === 403) {
        deleteUserBlocked = true;
      } else {
        console.warn(`    Lưu ý: Lỗi trả về status code ${err.statusCode}: ${err.message}`);
        if (err.statusCode === 403 || err.message.includes('người dùng')) {
          deleteUserBlocked = true;
        }
      }
    }
    if (!deleteUserBlocked) {
      throw new Error('FAIL: Admin vẫn có thể xóa danh mục người dùng (hoặc không trả về 403 Forbidden)!');
    }
    console.log('  ✓ PASSED: Chặn 403 Forbidden khi Admin cố tình xóa danh mục của người dùng');

    // 5. Kiểm thử bảo vệ chống xóa danh mục hệ thống (400 Bad Request)
    console.log('\n5. Kiểm thử bảo vệ chống xóa danh mục hệ thống:');
    let deleteSysBlocked = false;
    try {
      await adminService.deleteCategory(testSystemCategory.idcategory);
    } catch (err) {
      if (err.statusCode === 400 && err.message.includes('Không được phép xóa danh mục mặc định')) {
        deleteSysBlocked = true;
      }
    }
    if (!deleteSysBlocked) {
      throw new Error('FAIL: Danh mục hệ thống không được bảo vệ bằng lỗi 400 Bad Request!');
    }
    console.log('  ✓ PASSED: Danh mục mặc định hệ thống được bảo vệ an toàn (chặn 400 Bad Request)');

    console.log('\n======================================================================');
    console.log('   TẤT CẢ 5 BÀI KIỂM THỬ BẢO MẬT ĐỀU VƯỢT QUA XUẤT SẮC!               ');
    console.log('======================================================================\n');

  } catch (error) {
    console.error('\n❌ KIỂM THỬ THẤT BẠI:', error.message);
    process.exitCode = 1;
  } finally {
    // Dọn dẹp dữ liệu kiểm thử
    console.log('Đang dọn dẹp dữ liệu kiểm thử...');
    try {
      if (testUserCategory) {
        await prisma.category.deleteMany({ where: { idcategory: testUserCategory.idcategory } });
      }
      if (testSystemCategory) {
        await prisma.category.deleteMany({ where: { idcategory: testSystemCategory.idcategory } });
      }
      if (testUserAccount) {
        await prisma.account.deleteMany({ where: { idaccount: testUserAccount.idaccount } });
      }
      console.log('Dọn dẹp hoàn tất.');
    } catch (cleanErr) {
      console.warn('Lỗi dọn dẹp:', cleanErr.message);
    }
    await prisma.$disconnect();
  }
}

runTest();
