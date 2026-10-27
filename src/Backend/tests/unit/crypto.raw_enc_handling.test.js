const test = require('node:test');
const assert = require('node:assert/strict');
const { encrypt, decrypt, isEncrypted } = require('../../utils/crypto.util');

test('Crypto Raw enc:... Handling & Error Code Verification (2-Tier Test)', async (t) => {
  await t.test('Tier 1 & Tier 2: Chuỗi thô có tiền tố "enc:1:2:3" do người dùng nhập được mã hóa an toàn và giải mã trả về nguyên văn', () => {
    const rawNote = 'enc:1:2:3';
    
    // Tầng 1: Mã hóa không được giữ nguyên chuỗi thô 'enc:1:2:3'
    const encryptedResult = encrypt(rawNote);
    assert.ok(isEncrypted(encryptedResult), 'Kết quả mã hóa phải thỏa mãn chuẩn isEncrypted');
    assert.notStrictEqual(encryptedResult, rawNote, 'Tuyệt đối không được trả về nguyên bản chuỗi thô enc:1:2:3');
    
    // Tầng 2: Giải mã bản mã hợp lệ phải thu được đúng nguyên văn 'enc:1:2:3' và không bị ném DECRYPT_FAILED
    const decryptedResult = decrypt(encryptedResult);
    assert.strictEqual(decryptedResult, rawNote, 'Giải mã phải khôi phục đúng nguyên văn người dùng đã nhập');
  });

  await t.test('Tier 2: Tính Idempotent - Mã hóa một bản mã hợp lệ không bị mã hóa lặp 2 lần', () => {
    const originalText = 'Số điện thoại 0912345678 và địa chỉ nhà';
    const cipherText = encrypt(originalText);
    
    // Gọi encrypt lần 2 trên cùng cipherText
    const secondCall = encrypt(cipherText);
    assert.strictEqual(secondCall, cipherText, 'Bản mã hợp lệ với khóa hiện tại không được mã hóa lặp 2 lần');
    assert.strictEqual(decrypt(secondCall), originalText);
  });

  await t.test('Tier 2: Bản mã hỏng hoặc sai định dạng ném lỗi kèm mã DECRYPT_FAILED', () => {
    // 1. Sai độ dài IV / Tag
    assert.throws(
      () => decrypt('enc:shortiv:shorttag:abcd'),
      (err) => {
        assert.strictEqual(err.code, 'DECRYPT_FAILED', 'Lỗi ném ra phải có code là DECRYPT_FAILED');
        return true;
      }
    );

    // 2. Auth tag giả mạo (tampering)
    const validCipher = encrypt('Dữ liệu chuẩn');
    const parts = validCipher.split(':');
    // Đổi auth tag
    parts[2] = '00000000000000000000000000000000';
    const tampered = parts.join(':');

    assert.throws(
      () => decrypt(tampered),
      (err) => {
        assert.strictEqual(err.code, 'DECRYPT_FAILED', 'Giải mã auth tag giả mạo phải ném DECRYPT_FAILED');
        return true;
      }
    );
  });
});
