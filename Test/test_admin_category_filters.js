const adminService = require('../src/Backend/modules/admin/admin.service');
const { prisma } = require('../src/Backend/config/db');
const assert = require('assert');

async function testCategoryFilters() {
  console.log('=== BẮT ĐẦU KIỂM THỬ: BỘ LỌC NGƯỜI TẠO & TỪ KHÓA CHO DANH MỤC ADMIN ===\n');

  // 1. Kiểm tra getUsers trả về idaccount
  console.log('1. Kiểm tra adminService.getUsers() trả về idaccount...');
  const users = await adminService.getUsers();
  assert(Array.isArray(users), 'getUsers phải trả về một mảng');
  if (users.length > 0) {
    assert(users[0].idaccount !== undefined, 'Mỗi user phải có trường idaccount');
    console.log(`   ✓ PASSED: getUsers trả về ${users.length} users, user mẫu có idaccount=${users[0].idaccount}`);
  } else {
    console.log('   ⚠️ Không có user idrole=2 trong DB, bỏ qua check mẫu');
  }

  // 2. Kiểm tra getCategories không truyền param (mặc định)
  console.log('2. Kiểm tra adminService.getCategories() mặc định...');
  const allCats = await adminService.getCategories();
  assert(Array.isArray(allCats), 'getCategories phải trả về một mảng');
  assert(allCats.length > 0, 'Phải có ít nhất 1 danh mục trong hệ thống');
  console.log(`   ✓ PASSED: Lấy được ${allCats.length} danh mục tổng cộng.`);

  // 3. Kiểm tra lọc theo created_by = 1 (Administrator / Hệ thống)
  console.log('3. Kiểm tra lọc theo created_by = 1 (Hệ thống / Admin)...');
  const adminCats = await adminService.getCategories({ created_by: 1 });
  assert(Array.isArray(adminCats), 'Phải trả về mảng danh mục');
  assert(adminCats.every(c => c.created_by_id === 1 || c.is_default), 'Tất cả danh mục phải do admin (id 1) tạo hoặc là default');
  console.log(`   ✓ PASSED: Lọc created_by=1 trả về ${adminCats.length} danh mục.`);

  // 4. Kiểm tra lọc theo keyword (so khớp ký tự / chuỗi con, không phân biệt hoa thường)
  console.log('4. Kiểm tra lọc theo keyword không phân biệt hoa thường và chuỗi con...');
  // Tìm một danh mục có keyword để test
  const catWithKeyword = allCats.find(c => c.keyword && c.keyword.trim().length >= 3);
  if (catWithKeyword) {
    // Lấy một từ con trong keyword
    const subKeyword = catWithKeyword.keyword.trim().split(/[\s,]+/)[0];
    console.log(`   -> Test với subKeyword: "${subKeyword}" (từ danh mục "${catWithKeyword.name}")`);
    
    // Thử với chữ hoa/chữ thường khác biệt
    const lowerKeyword = subKeyword.toLowerCase();
    const upperKeyword = subKeyword.toUpperCase();

    const resultLower = await adminService.getCategories({ keyword: lowerKeyword });
    const resultUpper = await adminService.getCategories({ keyword: upperKeyword });

    assert(resultLower.length > 0, `Phải tìm thấy danh mục với keyword "${lowerKeyword}"`);
    assert(resultLower.length === resultUpper.length, `Tìm kiếm hoa/thường phải cho cùng số lượng (lower: ${resultLower.length}, upper: ${resultUpper.length})`);
    assert(resultLower.some(c => c.id === catWithKeyword.id), 'Danh mục mẫu phải có mặt trong kết quả tìm kiếm');
    console.log(`   ✓ PASSED: Tìm kiếm keyword chuỗi con và case-insensitive thành công (${resultLower.length} kết quả).`);
  } else {
    console.log('   ⚠️ Không tìm thấy danh mục nào có keyword đủ dài để test');
  }

  // 5. Kiểm tra kết hợp nhiều điều kiện: is_default + created_by
  console.log('5. Kiểm tra kết hợp bộ lọc is_default=yes và created_by=1...');
  const combined = await adminService.getCategories({ is_default: 'yes', created_by: 1 });
  assert(combined.every(c => c.is_default === true && c.created_by_id === 1), 'Mọi bản ghi phải thỏa mãn cả 2 điều kiện');
  console.log(`   ✓ PASSED: Kết hợp bộ lọc trả về ${combined.length} danh mục thỏa mãn.`);

  // 6. Kiểm tra keyword không tồn tại
  console.log('6. Kiểm tra keyword không tồn tại trong hệ thống...');
  const nonExistent = await adminService.getCategories({ keyword: 'tu_khoa_khong_ton_tai_xyz999' });
  assert.strictEqual(nonExistent.length, 0, 'Phải trả về 0 kết quả');
  console.log('   ✓ PASSED: Trả về 0 kết quả đúng như kỳ vọng.');

  console.log('\n======================================================================');
  console.log('   TẤT CẢ CÁC BÀI KIỂM THỬ BỘ LỌC DANH MỤC ĐỀU PASS 100%!             ');
  console.log('======================================================================\n');
}

testCategoryFilters()
  .catch(err => {
    console.error('❌ LỖI KIỂM THỬ:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
