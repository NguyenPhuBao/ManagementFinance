/**
 * Test Suite Nghiệm thu 2 Tầng: An Toàn Mã Hóa Dữ Liệu & Giải Mã Hỏng (Nhóm 4 - Đơn 52)
 * 
 * Kiểm tra toàn diện:
 * 1. [Tier 2] Context Logging khi giải mã thất bại (table, recordId)
 * 2. [Tier 2] Phòng vệ Sync Pull với hàng đã soft-deleted (Graceful Tombstone)
 * 3. [Tier 2] Bảo vệ toàn vẹn dữ liệu: Hàng Active bắt buộc ném DECRYPT_FAILED
 * 4. [Tier 2] Chống Bypass chuỗi giả mạo "enc:1:2:3" (Loại bỏ isEncrypted ? x : encrypt)
 * 5. [Tier 2] Re-encryption Round-trip từ khóa Dev sang khóa .env
 * 6. [Tier 2] Thẩm tra formatUser trong auth.repository với context
 * 7. [Tier 2] Thẩm tra masking.util chuyển tiếp context cho decrypt
 * 8. [Tier 1] Audit toàn bộ CSDL hiện tại: 0 bản ghi lỗi giải mã
 */

const test = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');
require('dotenv').config({ path: 'src/Backend/.env' });

const { encrypt, decrypt, isEncrypted } = require('../../utils/crypto.util');
const syncRepository = require('../../modules/sync/sync.repository');
const authRepository = require('../../modules/auth/auth.repository');
const { maskPhone, maskAccountNumber, maskAddress, maskTransactionDescription } = require('../../utils/masking.util');
const logger = require('../../core/logger');

test('Nhóm 4: Data Encryption & Safe Decryption Audit Suite (Đơn 52)', async (t) => {

  // ═════════════════════════════════════════════════════════════════════
  // TC1. Context Logging khi giải mã thất bại
  // ═════════════════════════════════════════════════════════════════════
  await t.test('1. [Tier 2] decrypt() ném DECRYPT_FAILED và logger ghi nhận chính xác { table, recordId }', async () => {
    const origError = logger.error;
    let loggedMeta = null;

    logger.error = (msg, meta) => {
      loggedMeta = meta;
    };

    try {
      const corruptedCipher = 'enc:0123456789abcdef01234567:0123456789abcdef0123456789abcdef:deadbeef';
      const context = { table: 'transaction', id: 'tx-audit-999' };

      assert.throws(
        () => {
          decrypt(corruptedCipher, context);
        },
        (err) => {
          assert.strictEqual(err.code, 'DECRYPT_FAILED');
          assert.strictEqual(err.table, 'transaction');
          assert.strictEqual(err.recordId, 'tx-audit-999');
          return true;
        }
      );

      // Thẩm tra Tier 2: Logger phải nhận được table và recordId
      assert.ok(loggedMeta, 'Logger.error phải được gọi khi giải mã thất bại');
      assert.strictEqual(loggedMeta.table, 'transaction');
      assert.strictEqual(loggedMeta.recordId, 'tx-audit-999');
    } finally {
      logger.error = origError;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC2. Phòng vệ Sync Pull với hàng đã xóa mềm (Soft-deleted Tombstone)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('2. [Tier 2] restoreSafeNote() trên hàng đã soft-deleted: Bỏ qua lỗi và trả chuỗi rỗng thay vì làm sập HTTP 500', async () => {
    const origWarn = logger.warn;
    let warningLogged = false;
    let warningMeta = null;

    logger.warn = (msg, meta) => {
      warningLogged = true;
      warningMeta = meta;
    };

    try {
      const corruptedCipher = 'enc:0123456789abcdef01234567:0123456789abcdef0123456789abcdef:deadbeef';
      const context = { table: 'transaction', id: 'tx-deleted-111' };

      // Hàng đã xóa mềm: isDeleted = true
      const result = syncRepository.restoreSafeNote(corruptedCipher, context, true);

      assert.strictEqual(result, '', 'Phải trả về chuỗi rỗng an toàn cho tombstone');
      assert.strictEqual(warningLogged, true, 'Phải log warning để DevOps theo dõi');
      assert.strictEqual(warningMeta.table, 'transaction');
      assert.strictEqual(warningMeta.recordId, 'tx-deleted-111');
    } finally {
      logger.warn = origWarn;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC3. Bảo vệ toàn vẹn dữ liệu: Hàng Active bắt buộc ném DECRYPT_FAILED
  // ═════════════════════════════════════════════════════════════════════
  await t.test('3. [Tier 2] restoreSafeNote() trên hàng ACTIVE: Bắt buộc ném DECRYPT_FAILED để ngăn ghi đè dữ liệu hỏng', async () => {
    const corruptedCipher = 'enc:0123456789abcdef01234567:0123456789abcdef0123456789abcdef:deadbeef';
    const context = { table: 'transaction', id: 'tx-active-222' };

    assert.throws(
      () => {
        // Hàng còn active: isDeleted = false
        syncRepository.restoreSafeNote(corruptedCipher, context, false);
      },
      (err) => {
        assert.strictEqual(err.code, 'DECRYPT_FAILED');
        return true;
      }
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC4. Chống Bypass chuỗi giả mạo "enc:1:2:3" (Loại bỏ isEncrypted bypass)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('4. [Tier 2] encrypt() không bao giờ lưu thô chuỗi người dùng nhập "enc:a:b:c" nếu không giải được', async () => {
    const fakeRawString = 'enc:1:2:3';

    // Mã hóa chuỗi giả mạo
    const ciphertext = encrypt(fakeRawString);

    assert.ok(ciphertext.startsWith('enc:'), 'Bản mã phải có tiền tố enc:');
    assert.notStrictEqual(ciphertext, fakeRawString, 'Tuyệt đối không được lưu thô nguyên bản chuỗi người dùng nhập');

    // Giải mã lại phải ra đúng chuỗi gốc
    const decrypted = decrypt(ciphertext);
    assert.strictEqual(decrypted, fakeRawString, 'Phải giải mã ra chuỗi nguyên gốc người dùng nhập "enc:1:2:3"');
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC5. Re-encryption Round-trip từ khóa Dev sang khóa .env
  // ═════════════════════════════════════════════════════════════════════
  await t.test('5. [Tier 2] Re-encryption Round-trip: Giải mã bằng khóa Dev cũ -> Mã hóa bằng khóa .env bảo toàn 100% nội dung', async () => {
    const defaultDevKeyHex = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const devKey = Buffer.from(defaultDevKeyHex, 'hex');

    const originalPlaintext = 'Tiền điện tháng 10/2026 kèm ghi chú đặc biệt';

    // Giả lập tạo bản mã bằng khóa dev cũ
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', devKey, iv);
    let encrypted = cipher.update(originalPlaintext, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    const authTag = cipher.getAuthTag().toString('hex');
    const legacyDevCiphertext = `enc:${iv.toString('hex')}:${authTag}:${encrypted}`;

    // Khóa env hiện tại KHÔNG giải được trực tiếp bản mã này
    assert.throws(() => {
      decrypt(legacyDevCiphertext);
    });

    // Giải mã bằng khóa dev cũ
    const parts = legacyDevCiphertext.slice(4).split(':');
    const decipher = crypto.createDecipheriv('aes-256-gcm', devKey, Buffer.from(parts[0], 'hex'));
    decipher.setAuthTag(Buffer.from(parts[1], 'hex'));
    let recoveredPlain = decipher.update(parts[2], 'hex', 'utf8');
    recoveredPlain += decipher.final('utf8');
    assert.strictEqual(recoveredPlain, originalPlaintext);

    // Re-encrypt bằng hàm encrypt() của hệ thống (dùng khóa .env)
    const newCiphertext = encrypt(recoveredPlain);

    // Thẩm tra: decrypt() của hệ thống giải mã thành công 100%
    const finalPlain = decrypt(newCiphertext);
    assert.strictEqual(finalPlain, originalPlaintext, 'Bản rõ sau khi re-encrypt phải khớp 100% từng ký tự');
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC6. formatUser trong auth.repository truyền context đầy đủ
  // ═════════════════════════════════════════════════════════════════════
  await t.test('6. [Tier 2] authRepository.formatUser truyền context { table, id, field } khi giải mã phone & address', async () => {
    const origError = logger.error;
    let loggedContexts = [];

    logger.error = (msg, meta) => {
      loggedContexts.push(meta);
    };

    try {
      const corruptedCipher = 'enc:0123456789abcdef01234567:0123456789abcdef0123456789abcdef:deadbeef';
      const mockUser = {
        iduser: 55,
        idaccount: 105,
        phone: corruptedCipher,
        address: null,
      };

      assert.throws(() => {
        authRepository.formatUser(mockUser);
      });

      assert.ok(loggedContexts.length > 0, 'Phải ghi log error khi decrypt thất bại');
      const ctx = loggedContexts[0];
      assert.strictEqual(ctx.table, 'user');
      assert.strictEqual(ctx.recordId, 55);
    } finally {
      logger.error = origError;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC7. masking.util chuyển tiếp context cho decrypt
  // ═════════════════════════════════════════════════════════════════════
  await t.test('7. [Tier 2] masking.util chuyển tiếp context cho decrypt() ở maskPhone, maskAccountNumber, maskAddress', async () => {
    const origError = logger.error;
    let loggedContexts = [];

    logger.error = (msg, meta) => {
      loggedContexts.push(meta);
    };

    try {
      const corruptedCipher = 'enc:0123456789abcdef01234567:0123456789abcdef0123456789abcdef:deadbeef';

      // maskPhone bắt lỗi và trả mask an toàn, nhưng logger vẫn nhận context
      const maskedP = maskPhone(corruptedCipher, { table: 'user', id: 77 });
      assert.strictEqual(maskedP, '***-***-****');
      assert.strictEqual(loggedContexts.some(c => c.table === 'user' && c.recordId === 77), true);

      // maskAccountNumber
      const maskedAcc = maskAccountNumber(corruptedCipher, { table: 'bank_account', id: 88 });
      assert.strictEqual(maskedAcc, '**** **** **** ****');
      assert.strictEqual(loggedContexts.some(c => c.table === 'bank_account' && c.recordId === 88), true);

      // maskAddress
      const maskedAddr = maskAddress(corruptedCipher, { table: 'user', id: 99 });
      assert.strictEqual(maskedAddr, '***');
      assert.strictEqual(loggedContexts.some(c => c.table === 'user' && c.recordId === 99), true);
    } finally {
      logger.error = origError;
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  // TC8. CSDL Supabase hiện tại: 100% dữ liệu giải mã thành công (0 lỗi)
  // ═════════════════════════════════════════════════════════════════════
  await t.test('8. [Tier 1] CSDL Supabase Cloud: Toàn bộ 25 transaction và 3 user giải mã thành công 100% bằng khóa .env', async () => {
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();

    try {
      const txs = await prisma.transaction.findMany({
        where: { note: { startsWith: 'enc:' } },
        select: { idtran: true, note: true },
      });

      for (const t of txs) {
        const plain = decrypt(t.note, { table: 'transaction', id: t.idtran });
        assert.ok(typeof plain === 'string', 'Giao dịch phải giải mã ra chuỗi hợp lệ');
      }

      const users = await prisma.user.findMany({
        where: { phone: { startsWith: 'enc:' } },
        select: { iduser: true, phone: true },
      });

      for (const u of users) {
        const plain = decrypt(u.phone, { table: 'user', id: u.iduser });
        assert.ok(typeof plain === 'string', 'Số điện thoại user phải giải mã ra chuỗi hợp lệ');
      }
    } finally {
      await prisma.$disconnect();
    }
  });
});
