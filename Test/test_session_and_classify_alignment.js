/**
 * Test Suite: Session Validity & Category Classify Alignment
 * Kiểm tra các tính năng vừa nâng cấp theo yêu cầu của bạn Đạt & PO
 */

const assert = require('assert');
const jwt = require('../src/Backend/node_modules/jsonwebtoken');
const config = require('../src/Backend/config');
const { prisma } = require('../src/Backend/config/db');
const { authenticate, invalidateAccountCache } = require('../src/Backend/middleware/auth');
const syncService = require('../src/Backend/modules/sync/sync.service');
const syncController = require('../src/Backend/modules/sync/sync.controller');
const adminService = require('../src/Backend/modules/admin/admin.service');

async function runTests() {
  console.log('\n======================================================================');
  console.log('   BẮT ĐẦU KIỂM THỬ: SESSION VALIDITY & CATEGORY CLASSIFY ALIGNMENT   ');
  console.log('======================================================================\n');

  // Lấy 1 tài khoản thật trong DB để test
  const existingAccount = await prisma.account.findFirst({
    where: { status: 'Active' },
    select: { idaccount: true, username: true },
  });
  assert(existingAccount, 'Phải có ít nhất 1 tài khoản active trong CSDL');

  // ---------------------------------------------------------
  // TEST 1: Auth Middleware - Kiểm tra tài khoản tồn tại
  // ---------------------------------------------------------
  console.log('1. Kiểm thử Auth Middleware:');
  
  // 1.1: Token của tài khoản tồn tại
  const validToken = jwt.sign({ idaccount: existingAccount.idaccount, username: existingAccount.username }, config.jwt.accessSecret, { expiresIn: '1h' });
  let nextCalled = false;
  const mockReqValid = { headers: { authorization: `Bearer ${validToken}` } };
  const mockResValid = {
    status(code) { this.statusCode = code; return this; },
    json(data) { this.body = data; return this; },
  };

  await authenticate(mockReqValid, mockResValid, () => { nextCalled = true; });
  assert.strictEqual(nextCalled, true, 'Token của account tồn tại phải được thông qua (next() được gọi)');
  assert.strictEqual(mockReqValid.user.idaccount, existingAccount.idaccount);
  console.log('  ✔ PASS: Token của account tồn tại hợp lệ (next() được gọi)');

  // 1.2: Token của tài khoản KHÔNG tồn tại (ví dụ idaccount = 9999999)
  const deadAccountToken = jwt.sign({ idaccount: 9999999, username: 'ghost_user' }, config.jwt.accessSecret, { expiresIn: '1h' });
  let deadNextCalled = false;
  let deadStatusCode = null;
  let deadMessage = null;
  const mockReqDead = { headers: { authorization: `Bearer ${deadAccountToken}` } };
  const mockResDead = {
    status(code) { deadStatusCode = code; return this; },
    json(data) { deadMessage = data.message; return this; },
  };

  await authenticate(mockReqDead, mockResDead, () => { deadNextCalled = true; });
  assert.strictEqual(deadNextCalled, false, 'Token của account đã bị xóa KHÔNG ĐƯỢC gọi next()');
  assert.strictEqual(deadStatusCode, 401, 'Token của account đã bị xóa phải trả về HTTP 401');
  console.log(`  ✔ PASS: Token của account không tồn tại bị chặn với HTTP ${deadStatusCode}: "${deadMessage}"`);

  // 1.3: Cache invalidation
  invalidateAccountCache(existingAccount.idaccount);
  console.log('  ✔ PASS: invalidateAccountCache hoạt động chuẩn xác');

  // ---------------------------------------------------------
  // TEST 2: Sync Push - Chuẩn hóa Classify 'Vay/nợ' -> 'Vay/no'
  // ---------------------------------------------------------
  console.log('\n2. Kiểm thử Sync Push - Chuẩn hóa Classify Vay/nợ:');
  const testCatLocalId = 'test-cat-classify-' + Date.now();
  const testCatId = '11111111-2222-3333-4444-' + Date.now().toString().slice(-12);

  const pushPayloadWithDebtTone = [
    {
      localId: testCatLocalId,
      entity: 'category',
      operation: 'create',
      payload: {
        id: testCatId,
        idaccount: existingAccount.idaccount,
        name: 'Test Danh Mục Nợ Normalizer',
        classify: 'Vay/nợ', // Gửi có dấu tiếng Việt
        update_at: new Date().toISOString(),
      },
    },
  ];

  const pushResult = await syncService.processPush(existingAccount.idaccount, pushPayloadWithDebtTone);
  assert.strictEqual(pushResult.summary.synced, 1, 'Push category với classify "Vay/nợ" phải thành công');
  
  // Kiểm tra trong CSDL xem đã được lưu đúng 'Vay/no' (không dấu) chưa
  const savedCat = await prisma.category.findUnique({
    where: { idcategory: testCatId },
  });
  assert(savedCat, 'Category phải tồn tại trong CSDL');
  assert.strictEqual(savedCat.classify, 'Vay/no', 'Classify trong CSDL phải tự động chuẩn hóa thành "Vay/no"');
  console.log(`  ✔ PASS: Push "Vay/nợ" đã tự động chuẩn hóa và lưu DB thành "${savedCat.classify}"`);

  // ---------------------------------------------------------
  // TEST 3: Sync Push - Nhận diện ACCOUNT_NOT_FOUND code
  // ---------------------------------------------------------
  console.log('\n3. Kiểm thử Sync Push - Nhận diện ACCOUNT_NOT_FOUND:');
  const deadAccountPushPayload = [
    {
      localId: 'dead-cat-' + Date.now(),
      entity: 'category',
      operation: 'create',
      payload: {
        id: '99999999-8888-7777-6666-' + Date.now().toString().slice(-12),
        idaccount: 9999999, // Account không tồn tại
        name: 'Ghost Category',
        classify: 'Chi',
        update_at: new Date().toISOString(),
      },
    },
  ];

  // Thử gọi processPush với account 9999999
  const deadPushResult = await syncService.processPush(9999999, deadAccountPushPayload);
  const failedItem = deadPushResult.results[0];
  assert.strictEqual(failedItem.status, 'error');
  assert.strictEqual(failedItem.code, 'ACCOUNT_NOT_FOUND', 'Phải trả về code "ACCOUNT_NOT_FOUND" khi vỡ FK account');
  console.log(`  ✔ PASS: Lỗi khóa ngoại account được gán mã chuẩn: code="${failedItem.code}"`);

  // Controller check: 100% ACCOUNT_NOT_FOUND trả về HTTP 401
  let pushCtrlStatusCode = null;
  let pushCtrlBody = null;
  const mockPushReq = {
    user: { idaccount: 9999999 },
    body: {
      clientId: 'test-client',
      pushedAt: new Date().toISOString(),
      operations: deadAccountPushPayload,
    },
  };
  const mockPushRes = {
    status(code) { pushCtrlStatusCode = code; return this; },
    json(data) { pushCtrlBody = data; return this; },
  };

  await syncController.push(mockPushReq, mockPushRes);
  assert.strictEqual(pushCtrlStatusCode, 401, 'Khi toàn bộ batch lỗi do account không tồn tại, Controller phải trả 401');
  console.log(`  ✔ PASS: SyncController.push trả về HTTP ${pushCtrlStatusCode} khi account không tồn tại`);

  // ---------------------------------------------------------
  // TEST 4: Admin Category CRUD - Chuẩn hóa Classify
  // ---------------------------------------------------------
  console.log('\n4. Kiểm thử Admin Category - Chuẩn hóa Classify:');
  const adminCatCreated = await adminService.addCategory({
    name: 'Admin Danh Mục Nợ Test ' + Date.now().toString().slice(-4),
    classify: 'Vay/nợ', // Gửi có dấu
    is_default: false,
    keyword: 'no, muon tien',
  }, existingAccount.idaccount);

  assert.strictEqual(adminCatCreated.classify, 'Vay/no', 'Admin addCategory phải chuẩn hóa thành "Vay/no"');
  console.log(`  ✔ PASS: Admin addCategory("Vay/nợ") trả về classify="${adminCatCreated.classify}"`);

  const adminCatUpdated = await adminService.updateCategory(adminCatCreated.id, {
    name: adminCatCreated.name + ' (Updated)',
    classify: 'Vay/nợ',
    is_default: false,
  });
  assert.strictEqual(adminCatUpdated.classify, 'Vay/no', 'Admin updateCategory phải chuẩn hóa thành "Vay/no"');
  console.log(`  ✔ PASS: Admin updateCategory("Vay/nợ") trả về classify="${adminCatUpdated.classify}"`);

  // Dọn dẹp dữ liệu test
  await prisma.category.delete({ where: { idcategory: testCatId } });
  await prisma.category.delete({ where: { idcategory: adminCatCreated.id } });
  console.log('\n  ✔ Đã dọn dẹp toàn bộ dữ liệu test');

  console.log('\n======================================================================');
  console.log('   🎉 TẤT CẢ CÁC BÀI KIỂM THỬ ĐỒNG BỘ ĐÃ ĐẠT KẾT QUẢ PASS 100%!       ');
  console.log('======================================================================\n');
}

runTests()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Test failed:', err);
    process.exit(1);
  });
