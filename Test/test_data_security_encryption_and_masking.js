/**
 * TEST_DATA_SECURITY_ENCRYPTION_AND_MASKING.JS
 * Bộ kiểm thử tự động toàn diện các quy chuẩn bảo mật lưu trữ CSDL:
 * - Trigger CSDL chặn SĐT và STK ngân hàng dạng rõ (xác thực 2 đầu)
 * - Mã hóa AES-256-GCM At-Rest và Blind Index tra soát
 * - Bộ lọc PII và từ ngữ xúc phạm cho lý do khóa tài khoản (reason_inactive)
 * - Các hàm che giấu thông tin định danh (Masking: Email, Phone, STK, Họ tên, Địa chỉ)
 * - Lọc dữ liệu nhạy cảm và mã hóa At-Rest cho trường Note
 * - Pre-signed URL cho ảnh chứng từ giao dịch
 * - Redaction tự động bảo vệ số dư (Balance) và thông tin xác thực trên Logger
 */

const path = require('path');
require('../src/Backend/node_modules/dotenv').config({ path: path.join(__dirname, '../src/Backend/.env') });
const assert = require('assert');
const { Client } = require('../src/Backend/node_modules/pg');
const { prisma } = require('../src/Backend/config/db');
const { encrypt, decrypt, isEncrypted, hashBlindIndex } = require('../src/Backend/utils/crypto.util');
const { maskEmail, maskPhone, maskAccountNumber, maskFullname, maskAddress } = require('../src/Backend/utils/masking.util');
const { validateReasonInactive, filterSensitiveNote } = require('../src/Backend/utils/content-filter.util');
const { getPresignedReceiptUrl, verifyPresignedUrl } = require('../src/Backend/utils/storage.util');
const adminService = require('../src/Backend/modules/admin/admin.service');
const syncRepository = require('../src/Backend/modules/sync/sync.repository');

const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
  yellow: '\x1b[33m',
  bright: '\x1b[1m',
};

async function runTests() {
  console.log(`\n${colors.cyan}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}   KIỂM THỬ BẢO MẬT CSDL, MÃ HÓA AT-REST, MASKING & 2-END TRIGGERS   ${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}======================================================================${colors.reset}\n`);

  const pgClient = new Client({ connectionString: process.env.DATABASE_URL });
  await pgClient.connect();

  let passedCount = 0;
  const totalCases = 13;

  try {
    // ------------------------------------------------------------------------
    // CASE 1: Trigger CSDL chặn SĐT dạng rõ (Plaintext)
    // ------------------------------------------------------------------------
    console.log(`1. Kiểm thử Trigger CSDL: Chặn lưu SĐT người dùng dạng rõ (Plaintext)...`);
    let plainPhoneBlocked = false;
    try {
      await pgClient.query(`
        INSERT INTO "user" ("Idaccount", "Fullname", "Email", "Phone")
        VALUES (999991, 'Hacker Phone Test', 'hacker_phone@gmail.com', '0987654321');
      `);
    } catch (err) {
      if (err.message.includes('BẢO MẬT: Nghiêm cấm lưu trữ số điện thoại người dùng dạng rõ')) {
        plainPhoneBlocked = true;
      }
    }
    assert(plainPhoneBlocked, 'Trigger trg_check_phone_encrypted phải chặn lưu SĐT dạng rõ!');
    console.log(`   ${colors.green}✔ Đạt: CSDL đã chặn và ném ngoại lệ bảo mật khi phát hiện SĐT dạng rõ${colors.reset}`);
    passedCount++;

    // ------------------------------------------------------------------------
    // CASE 2: Trigger CSDL chấp thuận SĐT đã mã hóa AES-256
    // ------------------------------------------------------------------------
    console.log(`\n2. Kiểm thử Trigger CSDL: Chấp thuận SĐT đã mã hóa AES-256...`);
    const encPhone = encrypt('0987654321');
    await pgClient.query('BEGIN;');
    try {
      const accRes = await pgClient.query(`
        INSERT INTO "account" ("Idrole", "Email", "Username", "Password", "Status")
        VALUES (2, 'temp_acc_test_sec_1@gmail.com', 'temp_acc_test_sec_1', 'hash', 'Active')
        RETURNING "Idaccount";
      `);
      const tempId = accRes.rows[0].Idaccount;

      await pgClient.query(`
        INSERT INTO "user" ("Idaccount", "Fullname", "Email", "Phone")
        VALUES ($1, 'Test Encrypted Phone', 'temp_acc_test_sec_1@gmail.com', $2);
      `, [tempId, encPhone]);
      console.log(`   ${colors.green}✔ Đạt: Bản ghi với SĐT mã hóa '${encPhone.substring(0, 25)}...' được lưu thành công${colors.reset}`);
      passedCount++;
    } finally {
      await pgClient.query('ROLLBACK;');
    }

    // ------------------------------------------------------------------------
    // CASE 3: Trigger CSDL chặn STK ngân hàng dạng rõ (Plaintext)
    // ------------------------------------------------------------------------
    console.log(`\n3. Kiểm thử Trigger CSDL: Chặn lưu STK ngân hàng dạng rõ (Plaintext)...`);
    let plainBankBlocked = false;
    try {
      await pgClient.query(`
        INSERT INTO "bank_account" ("Id_bank_account", "Idaccount", "Id_casso_account", "Account_number", "Account_name", "Bank_name")
        VALUES ('temp-uuid-bank-1', 1, 'casso_plain_test', '123456789012', 'Test Account', 'Vietcombank');
      `);
    } catch (err) {
      if (err.message.includes('BẢO MẬT: Nghiêm cấm lưu trữ số tài khoản ngân hàng dạng rõ')) {
        plainBankBlocked = true;
      }
    }
    assert(plainBankBlocked, 'Trigger trg_check_bank_account_encrypted phải chặn lưu STK dạng rõ!');
    console.log(`   ${colors.green}✔ Đạt: CSDL đã chặn và ném ngoại lệ bảo mật khi phát hiện STK dạng rõ${colors.reset}`);
    passedCount++;

    // ------------------------------------------------------------------------
    // CASE 4: Trigger CSDL chấp thuận STK ngân hàng đã mã hóa AES-256
    // ------------------------------------------------------------------------
    console.log(`\n4. Kiểm thử Trigger CSDL: Chấp thuận STK đã mã hóa AES-256...`);
    const encAccNum = encrypt('123456789012');
    await pgClient.query('BEGIN;');
    try {
      await pgClient.query(`
        INSERT INTO "bank_account" ("Id_bank_account", "Idaccount", "Id_casso_account", "Account_number", "Account_name", "Bank_name")
        VALUES ('temp-uuid-bank-enc', 1, 'casso_enc_test', $1, 'Test Account', 'Vietcombank');
      `, [encAccNum]);
      console.log(`   ${colors.green}✔ Đạt: Bản ghi với STK mã hóa '${encAccNum.substring(0, 25)}...' được lưu thành công${colors.reset}`);
      passedCount++;
    } finally {
      await pgClient.query('ROLLBACK;');
    }

    // ------------------------------------------------------------------------
    // CASE 5: Kiểm tra Crypto Util & Tra soát Blind Index
    // ------------------------------------------------------------------------
    console.log(`\n5. Kiểm thử Crypto Util & Blind Index (HMAC-SHA256)...`);
    const originalAcc = '9876543210';
    const encryptedAcc = encrypt(originalAcc);
    assert(isEncrypted(encryptedAcc), 'Phải là chuỗi mã hóa');
    assert.strictEqual(decrypt(encryptedAcc), originalAcc, 'Giải mã phải ra đúng số tài khoản gốc');

    const blindHash1 = hashBlindIndex('9876543210');
    const blindHash2 = hashBlindIndex(' 9876-5432-10 ');
    assert.strictEqual(blindHash1, blindHash2, 'Blind Index phải bỏ qua dấu gạch và khoảng trắng');
    assert.strictEqual(blindHash1.length, 64, 'HMAC-SHA256 phải có độ dài 64 ký tự hex');
    console.log(`   ${colors.green}✔ Đạt: Mã hóa AES-256-GCM toàn vẹn, Blind Index hash=${blindHash1.substring(0, 20)}...${colors.reset}`);
    passedCount++;

    // ------------------------------------------------------------------------
    // CASE 6: Kiểm tra Bộ Tiện Ích Masking
    // ------------------------------------------------------------------------
    console.log(`\n6. Kiểm thử Bộ tiện ích Masking (Email, SĐT, STK, Họ tên, Địa chỉ)...`);
    assert.strictEqual(maskEmail('phubao@gmail.com'), 'ph***@gmail.com');
    assert.strictEqual(maskEmail('admin@finance.vn'), 'ad***@finance.vn');
    assert.strictEqual(maskEmail('a@gmail.com'), 'a*@gmail.com');

    assert.strictEqual(maskPhone('0987654321'), '098****321');
    assert.strictEqual(maskPhone(encrypt('0912345678')), '091****678', 'Tự động giải mã rồi mask');

    assert.strictEqual(maskAccountNumber('123456789012'), '**** **** **** 9012');
    assert.strictEqual(maskAccountNumber(encrypt('987654321099')), '**** **** **** 1099');

    assert.strictEqual(maskFullname('Nguyễn Phú Bảo'), 'Nguyễn P. B.');
    assert.strictEqual(maskFullname('Trần Văn An'), 'Trần V. A.');

    assert.strictEqual(maskAddress('123 Đường Lê Lợi, Phường Bến Nghé, Quận 1, TP.HCM'), '***, Phường Bến Nghé, Quận 1, TP.HCM');
    console.log(`   ${colors.green}✔ Đạt: Toàn bộ 5 chuẩn masking hiển thị chính xác theo yêu cầu${colors.reset}`);
    passedCount++;

    // ------------------------------------------------------------------------
    // CASE 7: Lý do khóa tài khoản chứa PII bị chặn (HTTP 400)
    // ------------------------------------------------------------------------
    console.log(`\n7. Kiểm thử Chặn Lý do khóa tài khoản chứa PII (SĐT, Email, CCCD)...`);
    const userList = await adminService.getUsers();
    const targetUser = userList.find(u => u.status === 'Active') || userList[0];

    let piiBlocked = false;
    try {
      await adminService.updateStatus(targetUser.id, {
        status: 'Inactive',
        reason_inactive: 'Nghi ngờ vi phạm quy chế, vui lòng gọi SĐT 0987654321',
      });
    } catch (err) {
      if (err.statusCode === 400 && err.message.includes('thông tin định danh cá nhân')) {
        piiBlocked = true;
      }
    }
    assert(piiBlocked, 'Phải ném HTTP 400 khi lý do khóa chứa SĐT!');
    console.log(`   ${colors.green}✔ Đạt: Chặn thành công lý do khóa tài khoản chứa số điện thoại PII${colors.reset}`);
    passedCount++;

    // ------------------------------------------------------------------------
    // CASE 8: Lý do khóa tài khoản chứa từ ngữ xúc phạm bị chặn (HTTP 400)
    // ------------------------------------------------------------------------
    console.log(`\n8. Kiểm thử Chặn Lý do khóa tài khoản chứa từ ngữ xúc phạm/thô tục...`);
    let profanityBlocked = false;
    try {
      await adminService.updateStatus(targetUser.id, {
        status: 'Inactive',
        reason_inactive: 'Tài khoản này là thằng chó lừa đảo',
      });
    } catch (err) {
      if (err.statusCode === 400 && err.message.includes('xúc phạm')) {
        profanityBlocked = true;
      }
    }
    assert(profanityBlocked, 'Phải ném HTTP 400 khi lý do chứa từ ngữ xúc phạm!');
    console.log(`   ${colors.green}✔ Đạt: Chặn thành công lý do khóa tài khoản chứa từ ngữ thô tục${colors.reset}`);
    passedCount++;

    // ------------------------------------------------------------------------
    // CASE 9: Lý do khóa tài khoản hợp lệ được lưu thành công
    // ------------------------------------------------------------------------
    console.log(`\n9. Kiểm thử Chấp nhận Lý do khóa tài khoản hợp lệ...`);
    const validLock = await adminService.updateStatus(targetUser.id, {
      status: 'Inactive',
      reason_inactive: 'Tài khoản vi phạm chính sách đăng nhập bất thường',
    });
    assert.strictEqual(validLock.newStatus, 'Inactive');
    assert.strictEqual(validLock.reason_inactive, 'Tài khoản vi phạm chính sách đăng nhập bất thường');

    // Khôi phục lại trạng thái ban đầu
    await adminService.updateStatus(targetUser.id, { status: 'Active' });
    console.log(`   ${colors.green}✔ Đạt: Cập nhật thành công lý do hợp lệ và khôi phục Active an toàn${colors.reset}`);
    passedCount++;

    // ------------------------------------------------------------------------
    // CASE 10: Masking trong Admin Service (getUsers & getUserDetail)
    // ------------------------------------------------------------------------
    console.log(`\n10. Kiểm thử Masking dữ liệu hiển thị trên Admin Service...`);
    const freshUsers = await adminService.getUsers();
    const sample = freshUsers.find(u => u.email && u.email.includes('@'));
    assert(sample.email.includes('***'), `Email trả về phải được mask: ${sample.email}`);
    if (sample.phone) {
      assert(sample.phone.includes('****'), `SĐT trả về phải được mask: ${sample.phone}`);
    }
    console.log(`   ${colors.green}✔ Đạt: API Admin getUsers đã mask email '${sample.email}' và SĐT '${sample.phone}'${colors.reset}`);
    passedCount++;

    // ------------------------------------------------------------------------
    // CASE 11: Lọc dữ liệu nhạy cảm và mã hóa At-Rest cho trường Note
    // ------------------------------------------------------------------------
    console.log(`\n11. Kiểm thử Lọc thông tin thẻ/CVV/mật khẩu & Mã hóa At-Rest cho Note...`);
    const testAccount = await prisma.account.findFirst({ where: { status: 'Active' } });
    const idacc = testAccount ? testAccount.idaccount : 1;

    let userWallet = await prisma.wallet.findFirst({ where: { idaccount: idacc, delete_at: null } });
    if (!userWallet) {
      userWallet = await prisma.wallet.create({
        data: {
          idwallet: 'test-wallet-' + Date.now(),
          idaccount: idacc,
          name: 'Ví Test Note',
          type: 'Cash',
          balance: 1000000,
        },
      });
    }

    const rawNote = 'Thanh toán trực tuyến số thẻ 4532015896321475 và cvv: 999 mật khẩu: mySecret123';
    const testTranId = 'test-tran-note-' + Date.now();

    // Upsert transaction qua syncRepository
    await syncRepository.upsertTransaction({
      idtran: testTranId,
      idaccount: idacc,
      idwallet: userWallet.idwallet,
      amount: 150000,
      note: rawNote,
      provider: 'Manual',
      update_at: new Date(),
    });

    // Truy vấn trực tiếp từ PostgreSQL để kiểm tra giá trị lưu At-Rest trong CSDL
    const dbRow = await pgClient.query('SELECT "Note" FROM "transaction" WHERE "Idtran" = $1;', [testTranId]);
    const storedInDb = dbRow.rows[0]?.Note;

    assert(storedInDb, 'Phải có giá trị Note trong DB');
    assert(isEncrypted(storedInDb), 'Note lưu trong CSDL bắt buộc phải là chuỗi mã hóa AES-256 (enc:...)');
    assert(!storedInDb.includes('4532015896321475'), 'CSDL không được chứa số thẻ dạng rõ!');

    // Lấy lại qua syncRepository (đã giải mã cho user)
    const pulledList = await syncRepository.getTransactionsByAccount(idacc);
    const pulledItem = pulledList.find(t => t.idtran === testTranId);
    assert(pulledItem, 'Phải lấy được transaction');
    assert(pulledItem.note.includes('[THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ]'), 'Số thẻ phải được thay thế');
    assert(pulledItem.note.includes('[ĐÃ LƯỢC BỎ]'), 'CVV và mật khẩu phải được loại bỏ');

    // Dọn dẹp bản ghi test qua Xóa mềm (tuân thủ trigger protect_transaction_hard_delete)
    await pgClient.query('UPDATE "transaction" SET "Deleted_at" = NOW() WHERE "Idtran" = $1;', [testTranId]);
    console.log(`   ${colors.green}✔ Đạt: Note được lọc sạch thẻ/CVV/pwd và mã hóa At-Rest AES-256 trong CSDL${colors.reset}`);
    passedCount++;

    // ------------------------------------------------------------------------
    // CASE 12: Pre-signed URL cho ảnh chứng từ giao dịch (transaction.images)
    // ------------------------------------------------------------------------
    console.log(`\n12. Kiểm thử Pre-signed URL thời hạn ngắn cho ảnh chứng từ giao dịch...`);
    const imageKey = 'receipts/acc_1/tx_20260910_receipt.jpg';
    const presignedUrl = getPresignedReceiptUrl(imageKey, 1800); // 30 phút

    assert(presignedUrl.includes('expires='), 'URL phải chứa tham số expires');
    assert(presignedUrl.includes('sig='), 'URL phải chứa chữ ký HMAC sig');

    // Phân tích và verify URL
    const urlObj = new URL(presignedUrl, 'http://localhost');
    const expiresParam = urlObj.searchParams.get('expires');
    const sigParam = urlObj.searchParams.get('sig');

    const isValidNow = verifyPresignedUrl(imageKey, expiresParam, sigParam);
    assert.strictEqual(isValidNow, true, 'Pre-signed URL phải hợp lệ ở thời điểm hiện tại');

    // Kiểm tra URL hết hạn
    const isExpiredValid = verifyPresignedUrl(imageKey, Math.floor(Date.now() / 1000) - 10, sigParam);
    assert.strictEqual(isExpiredValid, false, 'Pre-signed URL quá hạn bắt buộc phải bị từ chối');
    console.log(`   ${colors.green}✔ Đạt: Pre-signed URL ${presignedUrl.substring(0, 45)}... sinh và xác thực chuẩn xác${colors.reset}`);
    passedCount++;

    // ------------------------------------------------------------------------
    // CASE 13: Redaction bảo vệ Số dư (Balance) và Mật khẩu trên Logger
    // ------------------------------------------------------------------------
    console.log(`\n13. Kiểm thử Redaction tự động của Logger chống lộ lọt Balance/Mật khẩu...`);
    const logger = require('../src/Backend/core/logger');
    // Test logger formats directly via stringify inspection
    const testLogMeta = {
      user: 'test_user',
      balance: 50000000,
      password: 'myPassword123',
      token: 'jwt.token.secret',
    };

    // Kiểm tra hàm sanitizeMeta gián tiếp qua format logger
    const logOutput = logger.format.transform({
      level: 'info',
      message: 'Test balance protection log',
      ...testLogMeta,
    });

    const logString = JSON.stringify(logOutput);
    assert(!logString.includes('50000000'), 'Logger không được in số dư thực!');
    assert(!logString.includes('myPassword123'), 'Logger không được in mật khẩu!');
    assert(logString.includes('[BẢO MẬT: ĐÃ CHE DỮ LIỆU NHẠY CẢM]'), 'Logger phải in nhãn bảo mật');
    console.log(`   ${colors.green}✔ Đạt: Logger tự động che toàn bộ trường Balance, Password, Token nhạy cảm${colors.reset}`);
    passedCount++;

  } finally {
    await pgClient.end();
  }

  console.log(`\n${colors.green}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.green}${colors.bright}    TỔNG KẾT: ${passedCount}/${totalCases} KIỂM THỬ BẢO MẬT ĐÃ HOÀN TẤT THÀNH CÔNG (100% PASS)  ${colors.reset}`);
  console.log(`${colors.green}${colors.bright}======================================================================${colors.reset}\n`);
}

runTests().catch((err) => {
  console.error(`\n${colors.red}❌ BỘ KIỂM THỬ BẢO MẬT THẤT BẠI:${colors.reset}`, err);
  process.exit(1);
});
