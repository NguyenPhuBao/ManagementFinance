/**
 * TEST SUITE: RECEIPT & BANK TRANSFER OCR (F013)
 * Kiểm thử toàn diện:
 * 1. Bóc tách Hóa đơn mua sắm (RECEIPT -> Provider 'ORC', Option Single & Grouped)
 * 2. Bóc tách Biên lai chuyển tiền nội bộ (BANK_TRANSFER -> Provider 'BankSync', Transfer, Idcategory = null, Bank_tran_id)
 * 3. Bóc tách Biên lai thanh toán bên thứ 3 (BANK_TRANSFER -> Provider 'BankSync', Transaction, Category)
 * 4. Bóc tách Tin nhắn SMS (SMS_BANKING -> Provider 'SMS', Bank_tran_id)
 * 5. Thuật toán Tự phục hồi dữ liệu thị giác (Self-Healing: sum items when total_amount missing)
 * 6. Xử lý ngoại lệ ảnh mờ / không đọc được (HTTP 422 OCR_PARSE_FAILED)
 * 7. Tích hợp sự kiện Realtime Notification (Socket.io & EventBus ocr.completed)
 */

const assert = require('assert');
const eventBus = require('../src/Backend/core/event-bus');
const ocrService = require('../src/Backend/modules/ai/features/ocr/ocr.service');
const notificationService = require('../src/Backend/modules/notification/notification.service');

// Dữ liệu giả lập người dùng và ví
const MOCK_USER = {
  iduser: 18,
  idaccount: 18,
  fullname: 'Nguyễn Phú Bảo',
  email: 'tadd1632004@gmail.com',
};

const MOCK_WALLETS = [
  {
    idwallet: 'wallet-vcb-111',
    name: 'Vietcombank Chính',
    bank_account: { account_number: '1012345678', bank_name: 'Vietcombank', account_name: 'NGUYEN PHU BAO' },
  },
  {
    idwallet: 'wallet-tcb-222',
    name: 'Techcombank Tiết Kiệm',
    bank_account: { account_number: '1903456789', bank_name: 'Techcombank', account_name: 'NGUYEN PHU BAO' },
  },
];

async function runTests() {
  console.log('====================================================');
  console.log('🧪 BẮT ĐẦU TEST SUITE: AI RECEIPT & TRANSFER OCR (F013)');
  console.log('====================================================\n');

  let passed = 0;
  let total = 0;

  function test(name, fn) {
    total++;
    try {
      fn();
      console.log(`  ✅ [PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`  ❌ [FAIL] ${name}: ${err.message}`);
    }
  }

  // Khởi tạo notification listeners
  await notificationService.initNotificationListeners();

  // ---------------------------------------------------------------------------
  // TEST GROUP 1: Hóa đơn mua sắm tiêu dùng (RECEIPT)
  // ---------------------------------------------------------------------------
  console.log('--- Test Group 1: Hóa đơn mua sắm (RECEIPT -> Provider "ORC") ---');
  const receiptExtraction = {
    document_type: 'RECEIPT',
    merchant_name: 'ĐỒNG MART',
    merchant_address: '326 Lê Văn Khương, Q.12, TP.HCM',
    invoice_no: 'INV-121023427',
    transaction_date: '2026-08-30T21:33:37.000Z',
    total_amount: 57000,
    vat_amount: 3217,
    payment_method: 'VNPAYQR',
    items: [
      { name: 'Bột giặt Robot 800g', quantity: 1, unit_price: 19000, total_price: 19000 },
      { name: 'KTYT FAMAPRO UV', quantity: 3, unit_price: 6333, total_price: 19000 },
      { name: 'Loạt đồ chơi bong bóng', quantity: 1, unit_price: 19000, total_price: 19000 },
    ],
  };

  const receiptResult = await ocrService.processReceipt(18, {
    _mockExtraction: receiptExtraction,
    _mockUser: MOCK_USER,
    _mockWallets: MOCK_WALLETS,
  });

  test('Gán đúng Provider là "ORC" cho hóa đơn mua sắm', () => {
    assert.strictEqual(receiptResult.provider, 'ORC');
  });

  test('Phân loại đúng Loại giao dịch là "Transaction"', () => {
    assert.strictEqual(receiptResult.detected_type, 'Transaction');
  });

  test('Lưu đúng invoice_no vào bank_tran_id hoặc invoice_info', () => {
    assert.strictEqual(receiptResult.invoice_info.invoice_no, 'INV-121023427');
  });

  test('Sinh option_single với số tiền đúng và có gợi ý danh mục', () => {
    assert.strictEqual(receiptResult.option_single.amount, 57000);
    assert.ok(receiptResult.option_single.suggested_category_id !== undefined);
  });

  test('Sinh option_grouped gom nhóm các items bảo tồn chi tiết từng món', () => {
    assert.ok(Array.isArray(receiptResult.option_grouped.groups));
    assert.ok(receiptResult.option_grouped.groups.length > 0);
    const allItems = receiptResult.option_grouped.groups.flatMap((g) => g.items);
    assert.strictEqual(allItems.length, 3);
  });

  // ---------------------------------------------------------------------------
  // TEST GROUP 2: Biên lai chuyển tiền nội bộ (BANK_TRANSFER -> Provider 'BankSync', Transfer)
  // ---------------------------------------------------------------------------
  console.log('\n--- Test Group 2: Biên lai chuyển khoản nội bộ (Transfer) ---');
  const transferExtraction = {
    document_type: 'BANK_TRANSFER',
    source_bank: 'Vietcombank',
    source_account: '1012345678',
    destination_bank: 'Techcombank',
    destination_account: '1903456789',
    destination_name: 'NGUYEN PHU BAO',
    amount: 5000000,
    transaction_date: '2026-09-03T10:15:00.000Z',
    transaction_code: 'FT26245981273910',
    note: 'Chuyen tien sang Techcombank tiet kiem',
  };

  const transferResult = await ocrService.processReceipt(18, {
    _mockExtraction: transferExtraction,
    _mockUser: MOCK_USER,
    _mockWallets: MOCK_WALLETS,
  });

  test('Gán đúng Provider là "BankSync" cho biên lai ngân hàng', () => {
    assert.strictEqual(transferResult.provider, 'BankSync');
  });

  test('Lưu đúng transaction_code vào bank_tran_id chống trùng', () => {
    assert.strictEqual(transferResult.bank_tran_id, 'FT26245981273910');
  });

  test('Phân loại đúng Loại giao dịch là "Transfer" (Cấp 1 đối soát CSDL)', () => {
    assert.strictEqual(transferResult.detected_type, 'Transfer');
  });

  test('Khi là Transfer: BẮT BUỘC category_id = null (không phân loại danh mục)', () => {
    const recommendedOption = transferResult.options.find((o) => o.type === 'Transfer');
    assert.ok(recommendedOption);
    assert.strictEqual(recommendedOption.category_id, null);
  });

  test('Xác định đúng ví nguồn và ví đích trong CSDL', () => {
    assert.strictEqual(transferResult.transfer_details.source_wallet_id, 'wallet-vcb-111');
    assert.strictEqual(transferResult.transfer_details.destination_wallet_id, 'wallet-tcb-222');
  });

  // ---------------------------------------------------------------------------
  // TEST GROUP 3: Biên lai chuyển tiền thanh toán bên thứ 3 (Shopee, Grab)
  // ---------------------------------------------------------------------------
  console.log('\n--- Test Group 3: Biên lai thanh toán bên thứ 3 (Transaction) ---');
  const thirdPartyExtraction = {
    document_type: 'BANK_TRANSFER',
    source_bank: 'Vietcombank',
    source_account: '1012345678',
    destination_bank: 'MBBank',
    destination_account: '987654321',
    destination_name: 'CONG TY TNHH SHOPEE',
    amount: 350000,
    transaction_date: '2026-09-03T11:20:00.000Z',
    transaction_code: 'FT999888777',
    note: 'Thanh toan don hang Shopee 2611',
  };

  const thirdPartyResult = await ocrService.processReceipt(18, {
    _mockExtraction: thirdPartyExtraction,
    _mockUser: MOCK_USER,
    _mockWallets: MOCK_WALLETS,
  });

  test('Gán đúng Provider "BankSync" và bank_tran_id cho bên thứ 3', () => {
    assert.strictEqual(thirdPartyResult.provider, 'BankSync');
    assert.strictEqual(thirdPartyResult.bank_tran_id, 'FT999888777');
  });

  test('Phân loại đúng là "Transaction" (không phải Transfer)', () => {
    assert.strictEqual(thirdPartyResult.detected_type, 'Transaction');
  });

  test('Khi là Transaction: Có gợi ý danh mục chi tiêu từ Classify 3-Tier', () => {
    assert.ok(thirdPartyResult.option_single);
    assert.strictEqual(thirdPartyResult.option_single.amount, 350000);
    assert.ok(thirdPartyResult.option_single.suggested_category_id !== undefined);
  });

  // ---------------------------------------------------------------------------
  // TEST GROUP 4: Tin nhắn SMS Banking (SMS_BANKING -> Provider 'SMS')
  // ---------------------------------------------------------------------------
  console.log('\n--- Test Group 4: Tin nhắn SMS Banking (Provider "SMS") ---');
  const smsExtraction = {
    document_type: 'SMS_BANKING',
    source_account: '1012345678',
    amount: 200000,
    transaction_date: '2026-09-03T12:00:00.000Z',
    transaction_code: 'SMS888999',
    note: 'Thanh toan tien dien EVN',
  };

  const smsResult = await ocrService.processReceipt(18, {
    _mockExtraction: smsExtraction,
    _mockUser: MOCK_USER,
    _mockWallets: MOCK_WALLETS,
  });

  test('Gán đúng Provider là "SMS" cho ảnh chụp tin nhắn SMS Banking', () => {
    assert.strictEqual(smsResult.provider, 'SMS');
  });

  test('Trích xuất đúng bank_tran_id từ SMS Banking', () => {
    assert.strictEqual(smsResult.bank_tran_id, 'SMS888999');
  });

  // ---------------------------------------------------------------------------
  // TEST GROUP 5: Thuật toán Tự Phục Hồi Dữ Liệu Thị Giác (Self-Healing)
  // ---------------------------------------------------------------------------
  console.log('\n--- Test Group 5: Tự phục hồi dữ liệu thị giác (Self-Healing) ---');
  const missingTotalExtraction = {
    document_type: 'RECEIPT',
    merchant_name: 'Bách Hóa Xanh',
    total_amount: null, // Thiếu tổng tiền
    items: [
      { name: 'Sữa chua nha đam', quantity: 2, unit_price: 8000, total_price: 16000 },
      { name: 'Bánh mì sandwich', quantity: 1, unit_price: 24000, total_price: 24000 },
    ],
  };

  const healedResult = await ocrService.processReceipt(18, {
    _mockExtraction: missingTotalExtraction,
    _mockUser: MOCK_USER,
    _mockWallets: MOCK_WALLETS,
  });

  test('Tự động cộng dồn total_amount từ danh sách items khi thiếu (16k + 24k = 40k)', () => {
    assert.strictEqual(healedResult.invoice_info.total_amount, 40000);
    assert.strictEqual(healedResult.option_single.amount, 40000);
  });

  // ---------------------------------------------------------------------------
  // TEST GROUP 6: Xử lý ảnh mờ / không đọc được (HTTP 422 Unprocessable Entity)
  // ---------------------------------------------------------------------------
  console.log('\n--- Test Group 6: Bắt lỗi ảnh mờ / rác (HTTP 422) ---');
  const blurryExtraction = {
    document_type: 'UNKNOWN',
    total_amount: 0,
    amount: 0,
    items: [],
    merchant_name: null,
    raw_text: 'anh bi mo khong doc duoc gi',
  };

  let errorThrown = null;
  try {
    await ocrService.processReceipt(18, {
      _mockExtraction: blurryExtraction,
      _mockUser: MOCK_USER,
      _mockWallets: MOCK_WALLETS,
    });
  } catch (err) {
    errorThrown = err;
  }

  test('Ném lỗi HTTP 422 khi ảnh mờ không đọc được thông tin hợp lệ', () => {
    assert.ok(errorThrown, 'Phải ném lỗi khi ảnh mờ');
    assert.strictEqual(errorThrown.statusCode, 422);
    assert.strictEqual(errorThrown.errorCode, 'OCR_PARSE_FAILED');
  });

  // ---------------------------------------------------------------------------
  // TEST GROUP 7: Module Notification & Realtime Event
  // ---------------------------------------------------------------------------
  console.log('\n--- Test Group 7: Tích hợp sự kiện Realtime Notification ---');
  let eventReceived = null;
  await eventBus.subscribe('ocr.completed', (payload) => {
    eventReceived = payload;
  });

  // Gọi lại 1 lần processReceipt để kiểm tra event phát ra
  await ocrService.processReceipt(18, {
    _mockExtraction: receiptExtraction,
    _mockUser: MOCK_USER,
    _mockWallets: MOCK_WALLETS,
  });

  test('Phát sự kiện ocr.completed tới EventBus & Notification Module', () => {
    assert.ok(eventReceived, 'EventBus phải nhận được ocr.completed');
    assert.strictEqual(eventReceived.idaccount, 18);
    assert.strictEqual(eventReceived.provider, 'ORC');
    assert.strictEqual(eventReceived.detected_type, 'Transaction');
  });

  // ---------------------------------------------------------------------------
  // TỔNG KẾT
  // ---------------------------------------------------------------------------
  console.log('\n====================================================');
  console.log(`📊 TỔNG KẾT OCR TEST SUITE: ${passed}/${total} TESTS PASS (${Math.round((passed / total) * 100)}%)`);
  console.log('====================================================\n');

  if (passed !== total) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Lỗi thực thi test suite:', err);
  process.exit(1);
});
