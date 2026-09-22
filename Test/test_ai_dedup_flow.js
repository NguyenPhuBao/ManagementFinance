/**
 * TEST SUITE: AI DEDUPLICATION ENGINE & OCR INTEGRATION (F013)
 * Kiểm thử toàn diện:
 * 1. Quy tắc 1 (Strict Unique Code Matching): Trùng bank_tran_id (Hóa đơn / FT Chuyển khoản / SMS)
 * 2. Quy tắc 2 (Fuzzy Invoice Matching): Hóa đơn không có invoice_no, đối soát merchant + tiền + ngày
 * 3. Quy tắc 3 (Transfer / SMS Matching): Biên lai không có mã FT, đối soát STK + tiền + ngày
 * 4. Tích hợp OCR Pipeline: Chặn đứng xử lý, ném HTTP 409 Conflict, KHÔNG gọi Classify AI
 * 5. Tích hợp Realtime Notification: Phát sự kiện ocr.duplicate tới EventBus và Socket.io
 */

const assert = require('assert');
const eventBus = require('../src/Backend/core/event-bus');
const dedupService = require('../src/Backend/modules/ai/features/dedup/dedup.service');
const ocrService = require('../src/Backend/modules/ai/features/ocr/ocr.service');
const classifyService = require('../src/Backend/modules/ai/features/classify/classify.service');
const notificationService = require('../src/Backend/modules/notification/notification.service');

const MOCK_EXISTING_TRANSACTIONS = [
  {
    idtran: 'tx-uuid-001',
    idaccount: 18,
    amount: 57000,
    date_transaction: new Date('2026-08-30T21:33:37.000Z'),
    type: 'Transaction',
    provider: 'ORC',
    bank_tran_id: 'INV-121023427',
    note: 'ĐỒNG MART: Bột giặt Robot 800g',
    status: 'Confirmed',
  },
  {
    idtran: 'tx-uuid-002',
    idaccount: 18,
    amount: 5000000,
    date_transaction: new Date('2026-09-03T10:15:00.000Z'),
    type: 'Transfer',
    provider: 'BankSync',
    bank_tran_id: 'FT26245981273910',
    note: 'Chuyen tien sang Techcombank tiet kiem',
    status: 'Confirmed',
  },
  {
    idtran: 'tx-uuid-003',
    idaccount: 18,
    amount: 45000,
    date_transaction: new Date('2026-09-03T08:00:00.000Z'),
    type: 'Transaction',
    provider: 'ORC',
    bank_tran_id: null,
    note: 'Cà phê Highland Coffee: 1 Cà phê sữa',
    status: 'Confirmed',
  },
  {
    idtran: 'tx-uuid-004',
    idaccount: 18,
    amount: 60000,
    date_transaction: new Date('2026-09-03T09:00:00.000Z'),
    type: 'Transaction',
    provider: 'ORC',
    bank_tran_id: 'INV-SPLIT-999_grp_1',
    note: 'Hóa đơn nhóm 1',
    status: 'Confirmed',
  },
];

async function runTests() {
  console.log('====================================================');
  console.log('🧪 BẮT ĐẦU TEST SUITE: AI DEDUPLICATION ENGINE');
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

  await notificationService.initNotificationListeners();

  // ----------------------------------------------------
  // Test Group 1: Quy tắc 1 (Strict Unique Code Matching)
  // ----------------------------------------------------
  console.log('--- Test Group 1: Quy tắc 1 (Strict Unique Code Matching) ---');

  const dupCodeCheck = await dedupService.checkDuplicate(
    18,
    { document_type: 'RECEIPT', invoice_no: 'INV-121023427', total_amount: 57000 },
    'ORC',
    'INV-121023427',
    { _mockExistingTransactions: MOCK_EXISTING_TRANSACTIONS }
  );

  test('Phát hiện trùng lặp 100% khi trùng bank_tran_id', () => {
    assert.strictEqual(dupCodeCheck.is_duplicate, true);
    assert.strictEqual(dupCodeCheck.reason, 'duplicate_bank_tran_id');
    assert.ok(dupCodeCheck.existing_transaction);
    assert.strictEqual(dupCodeCheck.existing_transaction.idtran, 'tx-uuid-001');
  });

  const dupGroupedCheck = await dedupService.checkDuplicate(
    18,
    { document_type: 'RECEIPT', invoice_no: 'INV-SPLIT-999', total_amount: 120000 },
    'ORC',
    'INV-SPLIT-999',
    { _mockExistingTransactions: MOCK_EXISTING_TRANSACTIONS }
  );

  test('Phát hiện trùng lặp khi hóa đơn cũ đã từng lưu dưới dạng nhóm (_grp_1)', () => {
    assert.strictEqual(dupGroupedCheck.is_duplicate, true);
    assert.strictEqual(dupGroupedCheck.reason, 'duplicate_bank_tran_id');
    assert.strictEqual(dupGroupedCheck.existing_transaction.idtran, 'tx-uuid-004');
  });

  const nonDupCodeCheck = await dedupService.checkDuplicate(
    18,
    { document_type: 'RECEIPT', invoice_no: 'INV-NEW-999', total_amount: 57000 },
    'ORC',
    'INV-NEW-999',
    { _mockExistingTransactions: MOCK_EXISTING_TRANSACTIONS }
  );

  test('Không báo trùng khi bank_tran_id là mã mới chưa có trong CSDL', () => {
    assert.strictEqual(nonDupCodeCheck.is_duplicate, false);
  });


  // ----------------------------------------------------
  // Test Group 2: Quy tắc 2 (Fuzzy Invoice Matching)
  // ----------------------------------------------------
  console.log('\n--- Test Group 2: Quy tắc 2 (Fuzzy Invoice Matching) ---');

  // Hóa đơn giấy không có số hóa đơn (invoice_no = null) nhưng trùng quán Highland, số tiền 45.000đ, cùng ngày
  const dupFuzzyCheck = await dedupService.checkDuplicate(
    18,
    {
      document_type: 'RECEIPT',
      merchant_name: 'Highland Coffee',
      total_amount: 45000,
      transaction_date: '2026-09-03T11:30:00.000Z',
    },
    'ORC',
    null,
    { _mockExistingTransactions: MOCK_EXISTING_TRANSACTIONS }
  );

  test('Phát hiện trùng lặp hóa đơn mờ/thiếu mã hóa đơn theo merchant + tiền + ngày', () => {
    assert.strictEqual(dupFuzzyCheck.is_duplicate, true);
    assert.strictEqual(dupFuzzyCheck.reason, 'fuzzy_invoice_matched');
    assert.strictEqual(dupFuzzyCheck.existing_transaction.idtran, 'tx-uuid-003');
  });

  // Cùng quán Highland nhưng số tiền khác (65.000đ) -> Không trùng
  const diffAmountFuzzyCheck = await dedupService.checkDuplicate(
    18,
    {
      document_type: 'RECEIPT',
      merchant_name: 'Highland Coffee',
      total_amount: 65000,
      transaction_date: '2026-09-03T11:30:00.000Z',
    },
    'ORC',
    null,
    { _mockExistingTransactions: MOCK_EXISTING_TRANSACTIONS }
  );

  test('Không báo trùng khi số tiền khác dù cùng cửa hàng và cùng ngày', () => {
    assert.strictEqual(diffAmountFuzzyCheck.is_duplicate, false);
  });

  // ----------------------------------------------------
  // Test Group 3: Quy tắc 3 (Transfer / SMS Matching)
  // ----------------------------------------------------
  console.log('\n--- Test Group 3: Quy tắc 3 (Transfer / SMS Matching) ---');

  const dupTransferCheck = await dedupService.checkDuplicate(
    18,
    {
      document_type: 'BANK_TRANSFER',
      amount: 5000000,
      transaction_date: '2026-09-03T10:15:00.000Z',
      note: 'Chuyen tien sang Techcombank tiet kiem',
    },
    'BankSync',
    'FT26245981273910',
    { _mockExistingTransactions: MOCK_EXISTING_TRANSACTIONS }
  );

  test('Phát hiện trùng lặp chuyển khoản nội bộ', () => {
    assert.strictEqual(dupTransferCheck.is_duplicate, true);
    assert.strictEqual(dupTransferCheck.existing_transaction.idtran, 'tx-uuid-002');
  });

  // ----------------------------------------------------
  // Test Group 4: Tích hợp OCR Pipeline & Bảo Vệ Tài Nguyên Classify AI
  // ----------------------------------------------------
  console.log('\n--- Test Group 4: Tích hợp OCR Pipeline & Bảo Vệ Classify AI ---');

  let classifyCalled = false;
  const originalClassify = classifyService.classifyExtractedReceipt;
  classifyService.classifyExtractedReceipt = async (...args) => {
    classifyCalled = true;
    return originalClassify.apply(classifyService, args);
  };

  let duplicateEventPayload = null;
  const unsubscribeDup = eventBus.subscribe('ocr.duplicate', (payload) => {
    duplicateEventPayload = payload;
  });

  // Chạy thử OCR với ảnh hóa đơn trùng mã 'INV-121023427'
  let thrownError = null;
  try {
    await ocrService.processReceipt(18, {
      _mockExtraction: {
        document_type: 'RECEIPT',
        invoice_no: 'INV-121023427',
        merchant_name: 'ĐỒNG MART',
        total_amount: 57000,
        items: [{ name: 'Bột giặt Robot 800g', total_price: 57000 }],
      },
      _mockExistingTransactions: MOCK_EXISTING_TRANSACTIONS,
    });
  } catch (err) {
    thrownError = err;
  }

  test('OCR Pipeline chặn lại ngay lập tức và ném mã lỗi HTTP 409 Conflict', () => {
    assert.ok(thrownError, 'Phải ném lỗi khi phát hiện trùng');
    assert.strictEqual(thrownError.statusCode, 409);
    assert.strictEqual(thrownError.errorCode, 'TRANSACTION_ALREADY_EXISTS');
    assert.strictEqual(thrownError.data.is_duplicate, true);
    assert.strictEqual(thrownError.data.bank_tran_id, 'INV-121023427');
  });

  test('BẢO VỆ TÀI NGUYÊN: Classify AI TUYỆT ĐỐI KHÔNG ĐƯỢC GỌI khi giao dịch bị trùng', () => {
    assert.strictEqual(classifyCalled, false, 'Classify AI không được phép chạy khi giao dịch đã tồn tại!');
  });

  test('Phát sự kiện ocr.duplicate tới EventBus và Notification Module', () => {
    assert.ok(duplicateEventPayload, 'Phải có sự kiện ocr.duplicate được phát ra');
    assert.strictEqual(duplicateEventPayload.idaccount, 18);
    assert.strictEqual(duplicateEventPayload.bank_tran_id, 'INV-121023427');
    assert.strictEqual(duplicateEventPayload.reason, 'duplicate_bank_tran_id');
  });

  // Dọn dẹp
  classifyService.classifyExtractedReceipt = originalClassify;
  if (typeof unsubscribeDup === 'function') unsubscribeDup();

  // ----------------------------------------------------
  // Test Group 5: Khi Chưa Trùng -> Xử Lý Bình Thường Qua Classify AI
  // ----------------------------------------------------
  console.log('\n--- Test Group 5: Giao dịch mới không trùng -> Chuyển tiếp bình thường ---');

  const validNewReceipt = await ocrService.processReceipt(18, {
    _mockExtraction: {
      document_type: 'RECEIPT',
      invoice_no: 'INV-FRESH-BRAND-NEW',
      merchant_name: 'WinMart Cộng Hòa',
      total_amount: 80000,
      items: [{ name: 'Sữa chua Vinamilk', total_price: 80000 }],
    },
    _mockExistingTransactions: MOCK_EXISTING_TRANSACTIONS,
  });


  test('Giao dịch chưa có trong CSDL được xử lý thành công (HTTP 200 DTO)', () => {
    assert.strictEqual(validNewReceipt.provider, 'ORC');
    assert.strictEqual(validNewReceipt.detected_type, 'Transaction');
    assert.strictEqual(validNewReceipt.bank_tran_id, 'INV-FRESH-BRAND-NEW');
    assert.ok(validNewReceipt.option_single);
  });

  console.log('\n====================================================');
  console.log(`📊 TỔNG KẾT DEDUP TEST SUITE: ${passed}/${total} TESTS PASS (${Math.round((passed / total) * 100)}%)`);
  console.log('====================================================\n');

  if (passed === total) {
    process.exit(0);
  } else {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
