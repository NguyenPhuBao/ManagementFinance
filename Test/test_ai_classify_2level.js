/**
 * Test Suite: AI Classify 2-Level Architecture (Cấp 1: Type & Cấp 2: Category)
 * Kiểm tra 3 cơ sở đối soát CSDL:
 * 1. items -> 100% Transaction
 * 2. destination_name / destination_account trùng user -> 100% Transfer
 * 3. keywords nội bộ -> Transfer
 * Và kiểm tra: Khi Transfer thì category_id = null (không phân loại danh mục).
 */

const assert = require('assert');
const { typeDetector } = require('../src/Backend/modules/ai/features/classify/pipeline/type.detector');
const classifyService = require('../src/Backend/modules/ai/features/classify/classify.service');
const classifyRepository = require('../src/Backend/modules/ai/features/classify/classify.repository');

async function runTests() {
  console.log('====================================================');
  console.log('🧪 BẮT ĐẦU TEST SUITE: AI CLASSIFY 2-LEVEL PIPELINE');
  console.log('====================================================\n');

  let passed = 0;
  let total = 0;

  function record(desc, ok) {
    total++;
    if (ok) {
      passed++;
      console.log(`  ✅ [PASS] ${desc}`);
    } else {
      console.error(`  ❌ [FAIL] ${desc}`);
    }
  }

  // Giả lập mock profile & wallets của user Nguyễn Phú Bảo
  const mockUserProfile = {
    idaccount: 1,
    fullname: 'Nguyễn Phú Bảo',
    email: 'nguyenphubao@example.com'
  };

  const mockUserWallets = [
    {
      idwallet: 'wallet-vcb-uuid',
      name: 'Vietcombank',
      type: 'Banking',
      bank_account: {
        account_number: '1012345678',
        bank_name: 'Vietcombank',
        account_name: 'NGUYEN PHU BAO'
      }
    },
    {
      idwallet: 'wallet-tcb-uuid',
      name: 'Techcombank',
      type: 'Banking',
      bank_account: {
        account_number: '1903456789',
        bank_name: 'Techcombank',
        account_name: 'NGUYEN PHU BAO'
      }
    },
    {
      idwallet: 'wallet-momo-uuid',
      name: 'Ví MoMo',
      type: 'E-Wallet',
      bank_account: null
    }
  ];

  // --------------------------------------------------------------------------
  // TEST 1: Cơ sở 1 - Hóa đơn mua sắm có items -> Luôn là Transaction
  // --------------------------------------------------------------------------
  console.log('--- Test Group 1: Cơ sở 1 (Mặt hàng items) ---');
  const res1 = typeDetector.detectType({
    items: [
      { name: 'Bột giặt Robot 800g', quantity: 1, unit_price: 19000, total_price: 19000 },
      { name: 'KTYT FAMAPRO UV', quantity: 3, unit_price: 6333, total_price: 19000 }
    ],
    merchant: 'ĐỒNG MART',
    amount: 38000,
    userProfile: mockUserProfile,
    userWallets: mockUserWallets
  });
  record('Hóa đơn có items phải phân loại là Transaction (confidence = 1.0)', res1.type === 'Transaction' && res1.confidence === 1.0);
  record('Lý do xác định phải là has_invoice_items', res1.reason === 'has_invoice_items');

  // --------------------------------------------------------------------------
  // TEST 2: Cơ sở 2 - Trùng tên người dùng (destination_name matches user) -> Transfer
  // --------------------------------------------------------------------------
  console.log('\n--- Test Group 2: Cơ sở 2 (Đối soát tên người nhận) ---');
  const res2 = typeDetector.detectType({
    destination_name: 'NGUYEN PHU BAO',
    destination_bank: 'Techcombank',
    amount: 2000000,
    note: 'Chuyen tien tieu vat',
    userProfile: mockUserProfile,
    userWallets: mockUserWallets
  });
  record('Trùng tên người dùng (không dấu) phải phân loại là Transfer', res2.type === 'Transfer');
  record('Lý do xác định phải là destination_name_matches_user', res2.reason === 'destination_name_matches_user');
  record('Độ tin cậy Transfer >= 0.95', res2.confidence >= 0.95);

  // --------------------------------------------------------------------------
  // TEST 3: Cơ sở 2 - Trùng số tài khoản nhận trong ví user -> Transfer
  // --------------------------------------------------------------------------
  console.log('\n--- Test Group 3: Cơ sở 2 (Đối soát STK trong danh sách ví) ---');
  const res3 = typeDetector.detectType({
    destination_account: '1903456789',
    destination_name: 'NGUYEN P B',
    amount: 5000000,
    userProfile: mockUserProfile,
    userWallets: mockUserWallets
  });
  record('Trùng STK ví của user phải phân loại là Transfer', res3.type === 'Transfer');
  record('Khớp đúng ví đích wallet-tcb-uuid', res3.destination_wallet_id === 'wallet-tcb-uuid');
  record('Lý do xác định phải là destination_account_in_wallets', res3.reason === 'destination_account_in_wallets');

  // --------------------------------------------------------------------------
  // TEST 4: Cơ sở 2 - Chuyển cho bên thứ 3 (Shopee, Grab, người lạ) -> Transaction
  // --------------------------------------------------------------------------
  console.log('\n--- Test Group 4: Cơ sở 2 (Chuyển tiền bên thứ 3) ---');
  const res4 = typeDetector.detectType({
    destination_name: 'CONG TY TNHH SHOPEE',
    destination_account: '987654321',
    note: 'Thanh toan don hang Shopee 2611',
    amount: 350000,
    userProfile: mockUserProfile,
    userWallets: mockUserWallets
  });
  record('Chuyển tiền người lạ / công ty phải phân loại là Transaction', res4.type === 'Transaction');
  record('Lý do xác định là third_party_payment', res4.reason === 'third_party_payment');

  // --------------------------------------------------------------------------
  // TEST 5: Cơ sở 3 - Từ khóa nội bộ trong ghi chú -> Transfer
  // --------------------------------------------------------------------------
  console.log('\n--- Test Group 5: Cơ sở 3 (Từ khóa nội dung chuyển khoản) ---');
  const res5 = typeDetector.detectType({
    note: 'chuyen tien sang vi tiet kiem chi tieu',
    amount: 1000000,
    userProfile: mockUserProfile,
    userWallets: mockUserWallets
  });
  record('Nội dung chứa từ khóa "chuyen tien sang vi" phải gợi ý Transfer', res5.type === 'Transfer');
  record('Lý do xác định là internal_transfer_keywords', res5.reason === 'internal_transfer_keywords');

  // --------------------------------------------------------------------------
  // TEST 6: Phân loại Cấp 2 - Khi là Transfer thì category_id = null (KHÔNG phân loại danh mục)
  // --------------------------------------------------------------------------
  console.log('\n--- Test Group 6: Cấp 2 - Quy tắc xử lý danh mục (Transfer vs Transaction) ---');
  
  // Test qua classifyService.classifyTransaction
  const txTransferResult = await classifyService.classifyTransaction(1, {
    destination_name: 'NGUYEN PHU BAO',
    destination_account: '1903456789',
    amount: 5000000,
    note: 'Chuyen tien sang Techcombank',
    _mockWallets: mockUserWallets,
    _mockUser: mockUserProfile
  });

  record('Khi là Transfer: type phải là "Transfer"', txTransferResult.type === 'Transfer');
  record('Khi là Transfer: category_id BẮT BUỘC là null', txTransferResult.category_id === null);
  record('Khi là Transfer: category_name là null', txTransferResult.category_name === null);
  record('Khi là Transfer: suggested_categories phải là mảng rỗng []', Array.isArray(txTransferResult.suggested_categories) && txTransferResult.suggested_categories.length === 0);

  // --------------------------------------------------------------------------
  // TEST 7: Phân loại Cấp 2 - Khi là Transaction thì PHẢI phân loại danh mục
  // --------------------------------------------------------------------------
  const txPurchaseResult = await classifyService.classifyTransaction(1, {
    text: 'Thanh toan tien com trua Highlands Coffee',
    destination_name: 'HIGHLANDS COFFEE',
    amount: 65000,
    counterpart_name: 'HIGHLANDS COFFEE',
    note: 'Cafe highlands',
    _mockWallets: mockUserWallets,
    _mockUser: mockUserProfile
  });

  record('Khi là Transaction: type phải là "Transaction"', txPurchaseResult.type === 'Transaction');
  record('Khi là Transaction: category_id PHẢI có giá trị (không null)', txPurchaseResult.category_id !== null);
  record('Khi là Transaction: category_name có giá trị hợp lệ', typeof txPurchaseResult.category_name === 'string');

  // --------------------------------------------------------------------------
  // TEST 8: classifyExtractedReceipt (Hỗ trợ tầng OCR sau này)
  // --------------------------------------------------------------------------
  console.log('\n--- Test Group 7: classifyExtractedReceipt (Tích hợp cho OCR) ---');
  const ocrReceiptInput = {
    document_type: 'RECEIPT',
    merchant_name: 'ĐỒNG MART',
    total_amount: 57000,
    items: [
      { name: 'Bột giặt Robot 800g', quantity: 1, unit_price: 19000, total_price: 19000 },
      { name: 'KTYT FAMAPRO UV', quantity: 3, unit_price: 6333, total_price: 19000 }
    ]
  };
  const ocrResult = await classifyService.classifyExtractedReceipt(1, ocrReceiptInput, {
    _mockWallets: mockUserWallets,
    _mockUser: mockUserProfile
  });

  record('OCR Hóa đơn: detected_type phải là "Transaction"', ocrResult.detected_type === 'Transaction');
  record('OCR Hóa đơn: option_single có category_id hợp lệ', ocrResult.option_single && ocrResult.option_single.suggested_category_id !== null);
  record('OCR Hóa đơn: option_grouped có mảng groups', Array.isArray(ocrResult.option_grouped?.groups));
  record('OCR Hóa đơn: các item trong group giữ trọn vẹn name và category_id', 
    ocrResult.option_grouped?.groups?.[0]?.items?.[0]?.name !== undefined &&
    ocrResult.option_grouped?.groups?.[0]?.items?.[0]?.category_id !== undefined
  );

  console.log('\n====================================================');
  console.log(`📊 TỔNG KẾT: ${passed}/${total} TESTS PASS (${Math.round((passed / total) * 100)}%)`);
  console.log('====================================================');

  if (passed < total) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runTests().catch((err) => {
  console.error('Test runner error:', err);
  process.exit(1);
});
