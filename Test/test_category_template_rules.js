const assert = require('assert');
const path = require('path');
require('../src/Backend/node_modules/dotenv').config({ path: path.join(__dirname, '../src/Backend/.env') });
const { prisma } = require('../src/Backend/config/db');
const adminService = require('../src/Backend/modules/admin/admin.service');
const syncService = require('../src/Backend/modules/sync/sync.service');

async function runTests() {
  console.log('🚀 Starting Category Template & Cloned Rules Test Suite...\n');
  let passed = 0;
  let failed = 0;

  // Cleanup test categories before running
  const testCatNames = ['Test Món Ăn Mới', 'test món ăn mới', 'TEST MÓN ĂN MỚI', 'Test User Cat', 'test user cat', 'Ăn uống'];
  await prisma.category.deleteMany({
    where: {
      name_category: { in: ['Test Món Ăn Mới', 'test món ăn mới', 'TEST MÓN ĂN MỚI', 'Test User Cat', 'test user cat'] }
    }
  });

  // --------------------------------------------------------------------------
  // TEST 1: syncService.getDefaultCategories returns list of default categories
  // --------------------------------------------------------------------------
  try {
    const defaults = await syncService.getDefaultCategories();
    assert(Array.isArray(defaults), 'Defaults should be an array');
    assert(defaults.length >= 10, 'Defaults should contain at least 10 categories');
    assert(defaults.every(c => c.is_default === true), 'All items must have is_default === true');
    console.log('✅ TEST 1 PASSED: syncService.getDefaultCategories returns active template categories');
    passed++;
  } catch (err) {
    console.error('❌ TEST 1 FAILED:', err.message);
    failed++;
  }

  // --------------------------------------------------------------------------
  // TEST 2: Admin creates default category successfully
  // --------------------------------------------------------------------------
  let createdDefaultId = null;
  try {
    const res = await adminService.addCategory({
      name: 'Test Món Ăn Mới',
      classify: 'Chi',
      is_default: true,
      keyword: 'mon an; am thuc',
    }, 1);
    createdDefaultId = res.id;
    assert(res.name === 'Test Món Ăn Mới', 'Name should match');
    assert(res.classify === 'Chi', 'Classify should match');
    console.log('✅ TEST 2 PASSED: Admin creates system default category successfully');
    passed++;
  } catch (err) {
    console.error('❌ TEST 2 FAILED:', err.message);
    failed++;
  }

  // --------------------------------------------------------------------------
  // TEST 3: Duplicate default category with different casing is REJECTED
  // --------------------------------------------------------------------------
  try {
    await adminService.addCategory({
      name: 'test món ăn mới',
      classify: 'Chi',
      is_default: true,
    }, 1);
    console.error('❌ TEST 3 FAILED: Should not allow duplicate default category (case-insensitive)');
    failed++;
  } catch (err) {
    assert(err.statusCode === 400, 'Error should be 400 Bad Request');
    console.log('✅ TEST 3 PASSED: Duplicate default category (case-insensitive) rejected');
    passed++;
  }

  // Lấy test account từ DB
  const userAccount = await prisma.account.findFirst({
    where: { idrole: 2, delete_at: null },
  });
  assert(userAccount, 'Must have at least 1 user account in DB');
  const mockUserId = userAccount.idaccount;

  // --------------------------------------------------------------------------
  // TEST 4: User creates category with SAME name as default category -> SUCCEEDS!
  // (Proves cross-default trigger is removed and user can own "Ăn uống")
  // --------------------------------------------------------------------------
  let userCatId = null;
  try {
    // Delete any existing mock user cat
    await prisma.category.deleteMany({
      where: { create_by: mockUserId, name_category: 'Ăn uống' }
    });
    
    // User creates "Ăn uống" which is also a system default category
    const userCat = await prisma.category.create({
      data: {
        idcategory: require('crypto').randomUUID(),
        create_by: mockUserId,
        name_category: 'Ăn uống',
        classify: 'Chi',
        is_default: false,
        update_at: new Date(),
      }
    });
    userCatId = userCat.idcategory;
    assert(userCat.name_category === 'Ăn uống', 'User category created with same name as system category');
    console.log('✅ TEST 4 PASSED: User can create category with same name as system default template');
    passed++;
  } catch (err) {
    console.error('❌ TEST 4 FAILED: User could not create category with same name as system category:', err.message);
    failed++;
  }

  // --------------------------------------------------------------------------
  // TEST 5: User cannot create duplicate category on the same account
  // (Case-insensitive check: "Ăn uống" vs "ăN UốNg")
  // --------------------------------------------------------------------------
  try {
    await prisma.category.create({
      data: {
        idcategory: require('crypto').randomUUID(),
        create_by: mockUserId,
        name_category: 'ăN UốNg',
        classify: 'Chi',
        is_default: false,
        update_at: new Date(),
      }
    });
    console.error('❌ TEST 5 FAILED: DB allowed duplicate category on same account');
    failed++;
  } catch (err) {
    assert(/unique|uq_category_owner_name/i.test(err.message), 'Should violate uq_category_owner_name');
    console.log('✅ TEST 5 PASSED: Duplicate category on same account (case-insensitive) blocked by DB index');
    passed++;
  }

  // --------------------------------------------------------------------------
  // TEST 6: Admin creates default category even if user already has category with that name
  // --------------------------------------------------------------------------
  let userCat2 = null;
  let adminDefaultWithSameName = null;
  try {
    userCat2 = await prisma.category.create({
      data: {
        idcategory: require('crypto').randomUUID(),
        create_by: mockUserId,
        name_category: 'Test User Cat',
        classify: 'Thu',
        is_default: false,
        update_at: new Date(),
      }
    });

    // Admin creates default category with same name "Test User Cat"
    adminDefaultWithSameName = await adminService.addCategory({
      name: 'Test User Cat',
      classify: 'Thu',
      is_default: true,
    }, 1);
    assert(adminDefaultWithSameName.name === 'Test User Cat');
    console.log('✅ TEST 6 PASSED: Admin can create default category matching an existing user category name');
    passed++;
  } catch (err) {
    console.error('❌ TEST 6 FAILED:', err.message);
    failed++;
  }

  // --------------------------------------------------------------------------
  // TEST 7: Converting user category to default category is REJECTED
  // --------------------------------------------------------------------------
  try {
    await adminService.updateCategory(userCat2.idcategory, {
      name: 'Test User Cat Updated',
      classify: 'Thu',
      is_default: true, // Cố tình chuyển đổi thành default
    }, 1);
    console.error('❌ TEST 7 FAILED: Should not allow converting user category to default category');
    failed++;
  } catch (err) {
    assert(err.statusCode === 400, 'Error status should be 400');
    assert(err.message.includes('Không cho phép chuyển đổi danh mục người dùng thành danh mục hệ thống'), 'Error message should match specification');
    console.log('✅ TEST 7 PASSED: Converting user category to default category rejected with 400');
    passed++;
  }

  // --------------------------------------------------------------------------
  // TEST 8: Deleting default category is REJECTED
  // --------------------------------------------------------------------------
  try {
    await adminService.deleteCategory(createdDefaultId);
    console.error('❌ TEST 8 FAILED: Should not allow deleting default category');
    failed++;
  } catch (err) {
    assert(err.statusCode === 400, 'Error status should be 400');
    assert(err.message.includes('Không được phép xóa danh mục mặc định của hệ thống'), 'Error message should match specification');
    console.log('✅ TEST 8 PASSED: Deleting default category rejected with 400');
    passed++;
  }

  // Cleanup test categories
  try {
    await prisma.category.deleteMany({
      where: {
        OR: [
          { idcategory: createdDefaultId || undefined },
          { idcategory: userCatId || undefined },
          { idcategory: userCat2?.idcategory || undefined },
          { idcategory: adminDefaultWithSameName?.id || undefined },
        ]
      }
    });
  } catch (e) {
    // ignore
  }

  console.log(`\n========================================`);
  console.log(`Test Results: ${passed} PASSED, ${failed} FAILED`);
  console.log(`========================================\n`);

  if (failed > 0) {
    process.exit(1);
  }
  process.exit(0);
}

runTests();
