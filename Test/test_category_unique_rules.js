/**
 * Test Suite: Category Unique Rules (Admin-web & Backend)
 * 1. Unique Group 1: Idaccount & namecategory (1 tài khoản không được có >1 category giống nhau, không phân biệt hoa/thường)
 * 2. Unique Group 2: Is_default & namecategory (không được phép có 2 category hệ thống giống nhau, không phân biệt hoa/thường)
 * 3. Case-Insensitive Matching: So sánh ép về chữ thường, nhưng khi lưu giữ đúng giá trị gốc ban đầu.
 * 4. Update Category: Loại trừ chính category đang sửa.
 */

const { prisma } = require('../src/Backend/config/db');
const adminService = require('../src/Backend/modules/admin/admin.service');

const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  bright: "\x1b[1m",
};

function assert(condition, message) {
  if (!condition) {
    console.error(`${colors.red}  ✗ FAILED: ${message}${colors.reset}`);
    throw new Error(message);
  }
  console.log(`${colors.green}  ✓ PASSED: ${message}${colors.reset}`);
}

async function runCategoryUniqueTests() {
  console.log(`\n${colors.cyan}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}   KIỂM THỬ QUY TẮC UNIQUE CATEGORY (ADMIN-WEB & BACKEND)             ${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}======================================================================${colors.reset}\n`);

  // Lấy 2 tài khoản test khác nhau
  const accounts = await prisma.account.findMany({
    where: { idrole: 2, delete_at: null },
    take: 2,
  });

  if (accounts.length < 2) {
    console.error('Cần ít nhất 2 tài khoản người dùng để chạy test.');
    process.exit(1);
  }

  const acc1 = accounts[0].idaccount;
  const acc2 = accounts[1].idaccount;
  console.log(`${colors.yellow}Account 1: ${acc1}, Account 2: ${acc2}${colors.reset}\n`);

  const createdCategoryIds = [];
  const testSuffix = Date.now().toString().slice(-4);
  const sysCatName = `Ăn Uống Test ${testSuffix}`;
  const userCatName = `Cà Phê Sữa Test ${testSuffix}`;

  try {
    // =========================================================================
    // TEST 1: Tạo danh mục hệ thống (is_default = true) và kiểm tra lưu đúng chữ hoa/thường
    // =========================================================================
    console.log(`${colors.bright}1. Kiểm thử tạo danh mục hệ thống và bảo toàn chữ hoa/thường gốc:${colors.reset}`);
    const catSys1 = await adminService.addCategory({
      name: sysCatName,
      classify: 'Chi',
      is_default: true,
      keyword: 'an uong,cafe',
      icon: 'restaurant',
    }, acc1);
    createdCategoryIds.push(catSys1.id);
    assert(catSys1.name === sysCatName, `Tên trả về đúng gốc: "${catSys1.name}"`);

    const dbSys1 = await prisma.category.findUnique({ where: { idcategory: catSys1.id } });
    assert(dbSys1.name_category === sysCatName, `CSDL lưu đúng chuỗi ban đầu: "${dbSys1.name_category}"`);

    // =========================================================================
    // TEST 2: Thử tạo danh mục hệ thống trùng tên nhưng viết thường toàn bộ (is_default = true)
    // =========================================================================
    console.log(`\n${colors.bright}2. Kiểm thử chặn tạo danh mục hệ thống trùng tên (chữ thường):${colors.reset}`);
    let rejectedSysLower = false;
    try {
      await adminService.addCategory({
        name: sysCatName.toLowerCase(),
        classify: 'Chi',
        is_default: true,
      }, acc1);
    } catch (err) {
      rejectedSysLower = true;
      assert(err.statusCode === 400, `Bị từ chối với HTTP 400: ${err.message}`);
    }
    assert(rejectedSysLower, 'Đã chặn thành công danh mục hệ thống trùng tên viết thường');

    // =========================================================================
    // TEST 3: Thử tạo danh mục hệ thống trùng tên viết HOA và khác classify (Thu vs Chi)
    // =========================================================================
    console.log(`\n${colors.bright}3. Kiểm thử chặn danh mục hệ thống trùng tên kể cả khác classify:${colors.reset}`);
    let rejectedSysDiffClassify = false;
    try {
      await adminService.addCategory({
        name: sysCatName.toUpperCase(),
        classify: 'Thu', // Khác classify vẫn phải chặn
        is_default: true,
      }, acc1);
    } catch (err) {
      rejectedSysDiffClassify = true;
      assert(err.statusCode === 400, `Bị từ chối với HTTP 400: ${err.message}`);
    }
    assert(rejectedSysDiffClassify, 'Đã chặn thành công danh mục hệ thống trùng tên dù khác classify');

    // =========================================================================
    // TEST 4: Tạo danh mục cá nhân cho Account 1 (is_default = false)
    // =========================================================================
    console.log(`\n${colors.bright}4. Kiểm thử tạo danh mục cá nhân cho Account 1:${colors.reset}`);
    const catUser1 = await adminService.addCategory({
      name: userCatName,
      classify: 'Chi',
      is_default: false,
    }, acc1);
    createdCategoryIds.push(catUser1.id);
    assert(catUser1.name === userCatName, `Tạo thành công danh mục cá nhân: "${catUser1.name}"`);

    // =========================================================================
    // TEST 5: Chặn Account 1 tạo danh mục cá nhân trùng tên (chữ thường)
    // =========================================================================
    console.log(`\n${colors.bright}5. Kiểm thử chặn Account 1 tạo danh mục cá nhân trùng tên:${colors.reset}`);
    let rejectedUser1Dup = false;
    try {
      await adminService.addCategory({
        name: userCatName.toLowerCase(),
        classify: 'Chi',
        is_default: false,
      }, acc1);
    } catch (err) {
      rejectedUser1Dup = true;
      assert(err.statusCode === 400, `Bị từ chối với HTTP 400: ${err.message}`);
    }
    assert(rejectedUser1Dup, 'Đã chặn Account 1 tạo danh mục trùng tên');

    // =========================================================================
    // TEST 6: Cho phép Account 2 tạo danh mục cùng tên (khác idaccount)
    // =========================================================================
    console.log(`\n${colors.bright}6. Kiểm thử Account 2 tạo danh mục cùng tên (khác idaccount):${colors.reset}`);
    const catUser2 = await adminService.addCategory({
      name: userCatName.toLowerCase(),
      classify: 'Chi',
      is_default: false,
    }, acc2);
    createdCategoryIds.push(catUser2.id);
    assert(catUser2.id !== null, `Account 2 tạo thành công danh mục: "${catUser2.name}"`);

    // =========================================================================
    // TEST 7: Thử cập nhật danh mục của Account 1 sang tên đã có của Account 1
    // =========================================================================
    console.log(`\n${colors.bright}7. Kiểm thử cập nhật danh mục Account 1 sang tên đã tồn tại:${colors.reset}`);
    // Tạo thêm danh mục thứ 2 cho Account 1
    const catUser1Extra = await adminService.addCategory({
      name: `Danh mục phụ ${testSuffix}`,
      classify: 'Chi',
      is_default: false,
    }, acc1);
    createdCategoryIds.push(catUser1Extra.id);

    let rejectedUpdateDup = false;
    try {
      // Đổi tên danh mục phụ thành tên của catUser1
      await adminService.updateCategory(catUser1Extra.id, {
        name: userCatName.toUpperCase(),
        classify: 'Chi',
        is_default: false,
      }, acc1);
    } catch (err) {
      rejectedUpdateDup = true;
      assert(err.statusCode === 400, `Bị từ chối đổi tên trùng: ${err.message}`);
    }
    assert(rejectedUpdateDup, 'Đã chặn đổi tên danh mục cá nhân sang tên đã tồn tại của chính tài khoản');

    // =========================================================================
    // TEST 8: Cập nhật danh mục giữ nguyên tên cũ của chính nó (loại trừ chính nó)
    // =========================================================================
    console.log(`\n${colors.bright}8. Kiểm thử cập nhật giữ nguyên tên cũ của chính danh mục:${colors.reset}`);
    const updatedSelf = await adminService.updateCategory(catUser1.id, {
      name: userCatName, // Cùng tên
      classify: 'Chi',
      is_default: false,
      keyword: 'caphe,sua',
      icon: 'local_cafe',
    }, acc1);
    assert(updatedSelf.name === userCatName, 'Cập nhật thành công khi giữ nguyên tên cũ của chính nó');

    // =========================================================================
    // TEST 9: Thử cập nhật danh mục hệ thống sang tên danh mục hệ thống khác
    // =========================================================================
    console.log(`\n${colors.bright}9. Kiểm thử chặn đổi tên danh mục hệ thống sang tên hệ thống đã có:${colors.reset}`);
    // Tạo 1 danh mục hệ thống khác
    const catSys2 = await adminService.addCategory({
      name: `Hệ Thống 2 ${testSuffix}`,
      classify: 'Chi',
      is_default: true,
    }, acc1);
    createdCategoryIds.push(catSys2.id);

    let rejectedSysUpdateDup = false;
    try {
      // Thử đổi catSys2 sang tên của catSys1
      await adminService.updateCategory(catSys2.id, {
        name: sysCatName.toLowerCase(),
        classify: 'Chi',
        is_default: true,
      }, acc1);
    } catch (err) {
      rejectedSysUpdateDup = true;
      assert(err.statusCode === 400, `Bị từ chối đổi tên trùng: ${err.message}`);
    }
    assert(rejectedSysUpdateDup, 'Đã chặn đổi tên danh mục hệ thống sang tên hệ thống khác');

    console.log(`\n${colors.green}${colors.bright}======================================================================${colors.reset}`);
    console.log(`${colors.green}${colors.bright}   TẤT CẢ CÁC BÀI TEST QUY TẮC UNIQUE CATEGORY ĐÃ ĐẠT PASS 100%!     ${colors.reset}`);
    console.log(`${colors.green}${colors.bright}======================================================================${colors.reset}\n`);

  } finally {
    // Dọn dẹp dữ liệu test
    console.log('Đang dọn dẹp dữ liệu test...');
    for (const id of createdCategoryIds) {
      try {
        await prisma.category.delete({ where: { idcategory: id } });
      } catch (delErr) {
        // bỏ qua nếu đã xóa
      }
    }
    console.log('Đã dọn dẹp dữ liệu test sạch sẽ.');
  }
}

runCategoryUniqueTests()
  .catch((err) => {
    console.error('Test Suite Failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
