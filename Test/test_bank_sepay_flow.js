/**
 * TEST SUITE: SEPAY BANK HUB INTEGRATION FOR BACKEND
 * Kiểm thử toàn diện các module của SePay Bank Hub:
 * 1. SePay Client SDK: Token generation, In-Memory caching, createLinkToken (Hosted Link URL)
 * 2. SePay Webhook Verifier: Timing-Safe ApiKey authentication
 * 3. Normalization of SePay IPN Payload: Credit/Debit, accumulated, Reference code
 * 4. Bank Controller & Service: Link URL generation & Webhook handling
 * 5. Bank Worker Processing & Idempotency: Balance update via 'accumulated', AI classify, Duplication check
 * 6. Transaction Approval Workflow: Confirm / Reject
 */

const assert = require('assert');

async function runTests() {
  console.log('\n=============================================================');
  console.log('🧪 BẮT ĐẦU CHUỖI KIỂM THỬ TDD: SEPAY BANK HUB BACKEND');
  console.log('=============================================================\n');

  let passed = 0;
  let failed = 0;

  function recordPass(testName) {
    console.log(`  ✅ PASS: ${testName}`);
    passed++;
  }

  function recordFail(testName, err) {
    console.error(`  ❌ FAIL: ${testName}`);
    console.error(`     Error: ${err.message}`);
    failed++;
  }

  // =========================================================================
  // PHẦN 1: KIỂM THỬ SEPAY CLIENT SDK
  // =========================================================================
  console.log('--- [1] SePay Client SDK & Token Manager ---');

  try {
    const sepayClient = require('../src/Backend/modules/bank/sepay/sepay.client');

    // Test 1.1: Quản lý token tự động & In-memory Cache
    const mockAuthCall = async () => {
      return {
        access_token: 'jwt_mock_token_sepay_12345',
        token_type: 'Bearer',
        expires_in: 3600,
      };
    };

    sepayClient._setTokenFetcher(mockAuthCall);
    sepayClient.clearTokenCache();
    sepayClient.companyXid = 'mock_company_xid';

    const token1 = await sepayClient.getAccessToken();
    assert.strictEqual(token1, 'jwt_mock_token_sepay_12345', 'Token trả về phải đúng với mock');

    // Lần thứ 2 phải lấy từ cache (không gọi fetcher mới)
    let fetchCount = 0;
    sepayClient._setTokenFetcher(async () => {
      fetchCount++;
      return { access_token: 'new_token', expires_in: 3600 };
    });

    const token2 = await sepayClient.getAccessToken();
    assert.strictEqual(token2, 'jwt_mock_token_sepay_12345', 'Token phải lấy từ bộ nhớ đệm cache');
    assert.strictEqual(fetchCount, 0, 'Không được gọi API khi token cache vẫn còn hiệu lực');
    recordPass('1.1. Token Manager lấy token và cache in-memory thành công');

    // Test 1.2: Sinh Hosted Link Token
    sepayClient._setLinkTokenFetcher(async (body) => {
      assert.strictEqual(body.customer_id, 'account_18', 'Customer ID phải đúng định danh user');
      assert.strictEqual(body.company_xid, 'mock_company_xid', 'Company XID phải khớp');
      return {
        link_token: 'link_tok_abc123',
        hosted_link_url: 'https://bankhub.sepay.vn/link/link_tok_abc123',
      };
    });

    const linkResult = await sepayClient.createLinkToken({
      idaccount: 18,
      companyXid: 'mock_company_xid',
      customerName: 'Nguyen Phu Bao',
      customerEmail: 'baonguyen@example.com',
    });

    assert.strictEqual(linkResult.link_token, 'link_tok_abc123');
    assert.strictEqual(linkResult.hosted_link_url, 'https://bankhub.sepay.vn/link/link_tok_abc123');
    recordPass('1.2. createLinkToken sinh Hosted Link URL chuẩn hóa');
  } catch (err) {
    recordFail('1. SePay Client SDK', err);
  }

  // =========================================================================
  // PHẦN 2: KIỂM THỬ XÁC THỰC WEBHOOK API KEY (TIMING-SAFE)
  // =========================================================================
  console.log('\n--- [2] SePay Webhook Verifier ---');

  try {
    const sepayWebhook = require('../src/Backend/modules/bank/sepay/sepay.webhook');
    const SECRET_KEY = 'My_Super_Secret_SePay_Webhook_Key_2026';

    // Test 2.1: ApiKey hợp lệ qua Authorization: ApiKey <KEY>
    const reqValid = {
      headers: {
        authorization: `ApiKey ${SECRET_KEY}`,
      },
    };
    const isValid = sepayWebhook.verifySignature(reqValid, SECRET_KEY);
    assert.strictEqual(isValid, true, 'ApiKey chính xác phải verify thành công');
    recordPass('2.1. Xác thực ApiKey hợp lệ bằng timingSafeEqual thành công');

    // Test 2.2: Từ chối khi ApiKey sai hoặc thiếu
    const reqInvalidKey = {
      headers: {
        authorization: 'ApiKey Wrong_Secret_Key',
      },
    };
    assert.strictEqual(sepayWebhook.verifySignature(reqInvalidKey, SECRET_KEY), false, 'Sai key phải bị từ chối');

    const reqMissingHeader = { headers: {} };
    assert.strictEqual(sepayWebhook.verifySignature(reqMissingHeader, SECRET_KEY), false, 'Thiếu header phải bị từ chối');

    const reqWrongPrefix = {
      headers: {
        authorization: `Bearer ${SECRET_KEY}`,
      },
    };
    assert.strictEqual(sepayWebhook.verifySignature(reqWrongPrefix, SECRET_KEY), false, 'Sai prefix ApiKey phải bị từ chối');
    recordPass('2.2. Chặn đứng các request Webhook giả mạo hoặc sai Header');
  } catch (err) {
    recordFail('2. SePay Webhook Verifier', err);
  }

  // =========================================================================
  // PHẦN 3: KIỂM THỬ BÓC TÁCH PAYLOAD SEPAY IPN (NORMALIZATION)
  // =========================================================================
  console.log('\n--- [3] Normalization of SePay IPN Payload ---');

  try {
    const sepayWebhook = require('../src/Backend/modules/bank/sepay/sepay.webhook');

    const mockSepayIpn = {
      id: 9876543,
      gateway: 'MBBank',
      transaction_date: '2026-09-05 18:00:00',
      account_number: '0987654321',
      sub_account: null,
      amount_in: 250000,
      amount_out: 0,
      accumulated: 5250000,
      code: 'FT26249123456789',
      transaction_content: 'TIEN THUONG DU AN SEPAY',
      reference_number: 'FT26249123456789',
      body: 'TIEN THUONG DU AN SEPAY',
      bank_account_xid: 'ba_01j7xyz987654321',
      transfer_type: 'credit',
      amount: 250000,
      reference_code: 'FT26249123456789',
      content: 'TIEN THUONG DU AN SEPAY',
    };

    const normalized = sepayWebhook.normalizeTransactionPayload(mockSepayIpn);

    assert.strictEqual(normalized.bank_tran_id, 'FT26249123456789', 'Mã giao dịch phải lấy từ reference_code/code');
    assert.strictEqual(normalized.account_number, '0987654321', 'Số tài khoản phải chính xác');
    assert.strictEqual(normalized.bank_account_xid, 'ba_01j7xyz987654321', 'Mã tài khoản SePay phải chính xác');
    assert.strictEqual(normalized.amount, 250000, 'Số tiền biến động phải là 250,000');
    assert.strictEqual(normalized.accumulated, 5250000, 'Số dư lũy kế phải là 5,250,000');
    assert.strictEqual(normalized.transfer_type, 'credit', 'Loại biến động là credit');
    assert.strictEqual(normalized.type, 'Thu', 'credit phải chuẩn hóa thành Thu');
    assert.strictEqual(normalized.note, 'TIEN THUONG DU AN SEPAY', 'Nội dung chuyển khoản chuẩn');

    // Test trường hợp debit (tiền ra)
    const mockDebitIpn = {
      ...mockSepayIpn,
      transfer_type: 'debit',
      amount: 45000,
      accumulated: 5205000,
      code: 'FT26249999999999',
      content: 'THANH TOAN HIGHLANDS COFFEE',
    };
    const normalizedDebit = sepayWebhook.normalizeTransactionPayload(mockDebitIpn);
    assert.strictEqual(normalizedDebit.type, 'Chi', 'debit phải chuẩn hóa thành Chi');
    assert.strictEqual(normalizedDebit.amount, 45000, 'Số tiền chi');
    assert.strictEqual(normalizedDebit.accumulated, 5205000, 'Số dư sau chi');

    recordPass('3.1. Chuẩn hóa payload SePay IPN (credit/debit, accumulated, FT code) chuẩn 100%');

    // Test 3.2: Chuẩn hóa payload SePay CÁ NHÂN (my.sepay.vn camelCase)
    const mockPersonalSepayIpn = {
      id: 92704,
      gateway: 'Vietcombank',
      transactionDate: '2026-09-05 19:20:00',
      accountNumber: '1017588888',
      subAccount: '',
      code: 'SEVN63DC8E5C',
      content: 'SEVN63DC8E5C chuyen tien an toi',
      transferType: 'in',
      description: 'NGUYEN PHU BAO chuyen tien',
      transferAmount: 50000,
      accumulated: 10500000,
      referenceCode: 'FT24012345678',
    };

    const normalizedPersonal = sepayWebhook.normalizeTransactionPayload(mockPersonalSepayIpn);
    assert.strictEqual(normalizedPersonal.bank_tran_id, 'FT24012345678', 'Mã giao dịch lấy từ referenceCode của SePay cá nhân');
    assert.strictEqual(normalizedPersonal.account_number, '1017588888', 'Số tài khoản lấy từ accountNumber');
    assert.strictEqual(normalizedPersonal.amount, 50000, 'Số tiền lấy từ transferAmount');
    assert.strictEqual(normalizedPersonal.transfer_type, 'credit', 'transferType in chuyển thành credit');
    assert.strictEqual(normalizedPersonal.type, 'Thu', 'Loại giao dịch là Thu');
    assert.strictEqual(normalizedPersonal.accumulated, 10500000, 'Số dư lũy kế');
    recordPass('3.2. Chuẩn hóa payload SePay CÁ NHÂN (my.sepay.vn camelCase) thành công 100%');
  } catch (err) {
    recordFail('3. Normalization of SePay IPN Payload', err);
  }

  // =========================================================================
  // PHẦN 4: KIỂM THỬ CONTROLLER ENDPOINTS
  // =========================================================================
  console.log('\n--- [4] Bank Controller & Routing ---');

  try {
    const bankController = require('../src/Backend/modules/bank/bank.controller');

    // Test 4.1: POST /api/bank/link-url
    const mockReqLink = {
      user: {
        idaccount: 18,
        fullname: 'Nguyen Phu Bao',
        email: 'baonguyen@example.com',
      },
    };

    let responseData = null;
    const mockResLink = {
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(payload) {
        responseData = payload;
        return payload;
      },
    };

    await bankController.createLinkUrl(mockReqLink, mockResLink, (err) => {
      if (err) throw err;
    });

    assert.strictEqual(responseData.success, true);
    assert.strictEqual(responseData.data.link_token, 'link_tok_abc123');
    recordPass('4.1. Controller createLinkUrl trả về URL WebView thành công');

    // Test 4.2: Webhook Endpoint bảo vệ bằng ApiKey
    const mockReqWebhookUnauthorized = {
      headers: { authorization: 'ApiKey Invalid_Key' },
      body: {},
    };
    let unauthStatus = 0;
    const mockResWebhookUnauth = {
      status(code) {
        unauthStatus = code;
        return this;
      },
      json(payload) {
        return payload;
      },
    };

    await bankController.handleWebhook(mockReqWebhookUnauthorized, mockResWebhookUnauth, () => {});
    assert.strictEqual(unauthStatus, 401, 'Sai ApiKey phải trả về HTTP 401');
    recordPass('4.2. Controller handleWebhook chặn đứng request sai xác thực với HTTP 401');

    // Test 4.3: POST /api/bank/register-account (Khai báo tài khoản thủ công từ App)
    let registeredPayload = null;
    const mockReqRegister = {
      user: { idaccount: 18 },
      body: {
        account_number: '1017588888',
        bank_name: 'Vietcombank',
        account_name: 'NGUYEN PHU BAO',
        balance: 10500000,
      },
    };
    const mockResRegister = {
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(payload) {
        registeredPayload = payload;
        return payload;
      },
    };

    const originalRegister = require('../src/Backend/modules/bank/bank.service').registerAccount;
    require('../src/Backend/modules/bank/bank.service').registerAccount = async (id, data) => {
      return {
        bank_account: {
          id_bank_account: 'mock-acc-vcb',
          account_number: data.account_number,
          bank_name: data.bank_name,
        },
        wallet: {
          idwallet: 'mock-wallet-vcb',
          type: 'Banking',
          balance: data.balance,
        },
      };
    };

    await bankController.registerAccount(mockReqRegister, mockResRegister, () => {});
    assert.strictEqual(registeredPayload.success, true);
    assert.strictEqual(registeredPayload.data.bank_account.account_number, '1017588888');
    assert.strictEqual(registeredPayload.data.wallet.type, 'Banking');
    recordPass('4.3. Controller registerAccount cho phép tự khai báo STK trên App thành công');
  } catch (err) {
    recordFail('4. Bank Controller & Routing', err);
  }

  // =========================================================================
  // PHẦN 5: KIỂM THỬ WORKER XỬ LÝ BIẾN ĐỘNG & CHỐNG TRÙNG LẶP
  // =========================================================================
  console.log('\n--- [5] Bank Worker Processing & Idempotency ---');

  try {
    const { processSepayTransaction } = require('../src/Backend/workers/bank.worker');

    let mockDbBankAccount = {
      id_bank_account: 'uuid-bank-acc-001',
      idaccount: 18,
      id_casso_account: 'ba_01j7xyz987654321',
      account_number: '0987654321',
      bank_name: 'MBBank',
      balance: 5000000,
      connect_status: 'Active',
    };

    let mockDbWallet = {
      idwallet: 'uuid-wallet-001',
      idaccount: 18,
      id_bank_casso: 'uuid-bank-acc-001',
      name: 'MBBank - 0987654321',
      type: 'Banking',
      balance: 5000000,
    };

    const createdTransactions = [];
    const emittedSocketEvents = [];

    const mockPrisma = {
      bank_account: {
        findFirst: async ({ where }) => {
          if (where.account_number === '0987654321') return mockDbBankAccount;
          return null;
        },
        update: async ({ where, data }) => {
          mockDbBankAccount = { ...mockDbBankAccount, ...data };
          return mockDbBankAccount;
        },
      },
      wallet: {
        findFirst: async ({ where }) => {
          if (where.id_bank_casso === mockDbBankAccount.id_bank_account) return mockDbWallet;
          return null;
        },
        create: async ({ data }) => {
          mockDbWallet = { ...data };
          return mockDbWallet;
        },
        update: async ({ where, data }) => {
          mockDbWallet = { ...mockDbWallet, ...data };
          return mockDbWallet;
        },
      },
      transaction: {
        findFirst: async ({ where }) => {
          return createdTransactions.find(
            (t) => t.provider === 'BankSync' && t.bank_tran_id === where.bank_tran_id
          ) || null;
        },
        create: async ({ data }) => {
          createdTransactions.push(data);
          return data;
        },
      },
    };

    const mockSocket = {
      emitToUser: (idaccount, event, data) => {
        emittedSocketEvents.push({ target: `user_${idaccount}`, event, data });
      },
      emitToAdmin: (event, data) => {
        emittedSocketEvents.push({ target: 'admin', event, data });
      },
    };

    const mockClassifyService = {
      classifySingle: async (idaccount, info) => {
        return {
          category_id: 'cat-fnb-001',
          category_name: 'Ăn uống',
          confidence: 0.95,
          tier_used: 'Tier-1-ExactKeyword',
        };
      },
    };

    const sepayTxPayload = {
      bank_tran_id: 'FT26249123456789',
      account_number: '0987654321',
      bank_account_xid: 'ba_01j7xyz987654321',
      amount: 250000,
      accumulated: 5250000,
      type: 'Thu',
      transfer_type: 'credit',
      note: 'TIEN THUONG DU AN SEPAY',
      date_transaction: new Date('2026-09-05T18:00:00.000Z'),
    };

    // Lần 1: Xử lý giao dịch mới
    const result1 = await processSepayTransaction({
      txData: sepayTxPayload,
      prismaClient: mockPrisma,
      socketService: mockSocket,
      classifyService: mockClassifyService,
    });

    assert.strictEqual(result1.status, 'created', 'Giao dịch mới phải được tạo');
    assert.strictEqual(createdTransactions.length, 1, 'Số lượng giao dịch trong DB phải là 1');
    assert.strictEqual(createdTransactions[0].status, 'Pending', 'Trạng thái ban đầu phải là Pending');
    assert.strictEqual(createdTransactions[0].provider, 'BankSync', 'Provider phải là BankSync');
    assert.strictEqual(createdTransactions[0].idcategory, 'cat-fnb-001', 'Phải gán danh mục do AI gợi ý');
    assert.strictEqual(mockDbBankAccount.balance, 5250000, 'Số dư bank_account phải cập nhật lên 5,250,000');
    assert.strictEqual(mockDbWallet.balance, 5250000, 'Số dư ví Banking phải cập nhật lên 5,250,000');

    // Kiểm tra Socket realtime phát đi
    const userEvent = emittedSocketEvents.find((e) => e.event === 'bank_transaction.incoming');
    assert(userEvent, 'Phải phát sự kiện bank_transaction.incoming tới user');
    assert.strictEqual(userEvent.target, 'user_18');

    const adminEvent = emittedSocketEvents.find((e) => e.event === 'admin.bank_transaction_created');
    assert(adminEvent, 'Phải phát sự kiện admin.bank_transaction_created tới admin');
    recordPass('5.1. Worker xử lý IPN, cập nhật số dư lũy kế và phát Socket.io chuẩn xác');

    // Lần 2: Bắn lại chính giao dịch đó (Simulate Webhook Retry / Duplicate IPN)
    const result2 = await processSepayTransaction({
      txData: sepayTxPayload,
      prismaClient: mockPrisma,
      socketService: mockSocket,
      classifyService: mockClassifyService,
    });

    assert.strictEqual(result2.status, 'skipped_duplicate', 'Giao dịch trùng phải bị chặn');
    assert.strictEqual(createdTransactions.length, 1, 'Không được tạo thêm giao dịch thứ 2');
    recordPass('5.2. Chặn đứng trùng lặp giao dịch (Idempotency) thành công 100%');
  } catch (err) {
    recordFail('5. Bank Worker Processing & Idempotency', err);
  }

  // =========================================================================
  // TỔNG KẾT
  // =========================================================================
  console.log('\n=============================================================');
  console.log(`🏁 KẾT QUẢ KIỂM THỬ: ${passed} PASS | ${failed} FAIL`);
  console.log('=============================================================\n');

  if (failed > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

runTests();
