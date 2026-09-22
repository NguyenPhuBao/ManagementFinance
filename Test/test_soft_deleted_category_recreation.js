const path = require('path');
const dbPath = path.resolve(__dirname, '../src/Backend/config/db');
const { prisma } = require(dbPath);
const adminService = require('../src/Backend/modules/admin/admin.service');
const syncRepository = require('../src/Backend/modules/sync/sync.repository');
const { randomUUID } = require('crypto');

async function runTest() {
  console.log('=== KIỂM TRA NGHIỆP VỤ: DANH MỤC ĐÃ XÓA MỀM CÓ THỂ TẠO MỚI CÙNG TÊN CÙNG ID TÀI KHOẢN ===\n');

  // Tìm 1 tài khoản test hoặc dùng id 1
  let account = await prisma.account.findFirst();
  if (!account) {
    console.error('Không tìm thấy tài khoản nào');
    return;
  }
  const idaccount = account.idaccount;
  const testName = 'Test Soft Delete ' + Date.now();

  console.log(`1. Tạo danh mục ban đầu "${testName}" cho tài khoản ${idaccount}...`);
  const cat1 = await prisma.category.create({
    data: {
      idcategory: randomUUID(),
      create_by: idaccount,
      name_category: testName,
      classify: 'Chi',
      is_default: false,
    }
  });
  console.log(`   -> Tạo thành công cat1: ${cat1.idcategory}`);

  console.log('2. Thử tạo danh mục thứ 2 CÙNG TÊN khi cat1 đang active (kỳ vọng BỊ CHẶN)...');
  try {
    await prisma.category.create({
      data: {
        idcategory: randomUUID(),
        create_by: idaccount,
        name_category: testName,
        classify: 'Thu',
        is_default: false,
      }
    });
    console.error('   ❌ LỖI: Lẽ ra phải bị chặn nhưng lại tạo được!');
  } catch (err) {
    console.log(`   ✓ ĐÚNG KỲ VỌNG: Bị chặn bởi unique constraint (${err.message.includes('Unique constraint failed') ? 'Unique constraint' : err.message})`);
  }

  console.log('3. Xóa mềm cat1 (soft delete)...');
  await prisma.category.update({
    where: { idcategory: cat1.idcategory },
    data: { delete_at: new Date(), update_at: new Date() }
  });
  console.log('   -> Đã xóa mềm cat1');

  console.log('4. Tạo danh mục cat2 CÙNG TÊN CÙNG TÀI KHOẢN trực tiếp qua Prisma / CSDL...');
  let cat2;
  try {
    cat2 = await prisma.category.create({
      data: {
        idcategory: randomUUID(),
        create_by: idaccount,
        name_category: testName,
        classify: 'Chi',
        is_default: false,
      }
    });
    console.log(`   ✓ THÀNH CÔNG: Đã tạo cat2 (${cat2.idcategory}) cùng tên với danh mục đã xóa mềm!`);
  } catch (err) {
    console.error('   ❌ THẤT BẠI: Không thể tạo danh mục cùng tên sau khi xóa mềm:', err.message);
  }

  console.log('5. Xóa mềm cat2 và test qua adminService.createCategory...');
  if (cat2) {
    await prisma.category.update({
      where: { idcategory: cat2.idcategory },
      data: { delete_at: new Date(), update_at: new Date() }
    });
  }

  try {
    const adminCreated = await adminService.addCategory({
      name: testName,
      classify: 'Chi',
      is_default: false,
    }, idaccount);
    console.log(`   ✓ THÀNH CÔNG (adminService): Đã tạo danh mục (${adminCreated.id}) qua adminService!`);
    
    // Cleanup
    await prisma.category.delete({ where: { idcategory: adminCreated.id } });
  } catch (err) {
    console.error('   ❌ THẤT BẠI qua adminService:', err.message);
  }

  console.log('6. Xóa mềm và test qua syncRepository.upsertCategory...');
  const cat3Id = randomUUID();
  try {
    const synced = await syncRepository.upsertCategory({
      idcategory: cat3Id,
      idaccount: idaccount,
      name_category: testName,
      classify: 'Chi',
      is_default: false,
    });
    console.log(`   ✓ THÀNH CÔNG (syncRepository): Đã tạo danh mục (${synced.idcategory}) qua syncRepository!`);

    // Cleanup
    await prisma.category.delete({ where: { idcategory: cat3Id } });
  } catch (err) {
    console.error('   ❌ THẤT BẠI qua syncRepository:', err.message);
  }

  // Cleanup test data
  if (cat1) await prisma.category.delete({ where: { idcategory: cat1.idcategory } }).catch(() => {});
  if (cat2) await prisma.category.delete({ where: { idcategory: cat2.idcategory } }).catch(() => {});

  console.log('\n=== KẾT THÚC KIỂM TRA ===');
}

runTest().catch(console.error).finally(() => prisma.$disconnect());
