const { encrypt, decrypt, isEncrypted, hashBlindIndex } = require('../src/Backend/utils/crypto.util');
const { maskEmail, maskPhone, maskAccountNumber, maskFullname, maskAddress } = require('../src/Backend/utils/masking.util');
const { validateReasonInactive, filterSensitiveNote } = require('../src/Backend/utils/content-filter.util');
const assert = require('assert');

console.log('=== TEST 1: Crypto Util ===');
const plainPhone = '0987654321';
const encryptedPhone = encrypt(plainPhone);
console.log('Plain:', plainPhone, '-> Encrypted:', encryptedPhone);
assert(isEncrypted(encryptedPhone), 'Phải nhận diện là chuỗi mã hóa');
assert.strictEqual(decrypt(encryptedPhone), plainPhone, 'Giải mã phải ra số điện thoại ban đầu');
assert.strictEqual(encrypt(encryptedPhone), encryptedPhone, 'Không được mã hóa lặp');

const hash1 = hashBlindIndex('1234567890');
const hash2 = hashBlindIndex(' 123456-7890 ');
console.log('Blind Index:', hash1);
assert.strictEqual(hash1, hash2, 'Blind Index phải chuẩn hóa khoảng trắng và dấu gạch');
assert.strictEqual(hash1.length, 64, 'HMAC-SHA256 phải dài 64 ký tự hex');

console.log('=== TEST 2: Masking Util ===');
assert.strictEqual(maskEmail('phubao@gmail.com'), 'ph***@gmail.com');
assert.strictEqual(maskEmail('a@gmail.com'), 'a*@gmail.com');
assert.strictEqual(maskPhone('0987654321'), '098****321');
assert.strictEqual(maskPhone(encryptedPhone), '098****321', 'Masking phone phải tự động giải mã ciphertext');
assert.strictEqual(maskAccountNumber('123456789012'), '**** **** **** 9012');
assert.strictEqual(maskFullname('Nguyễn Phú Bảo'), 'Nguyễn P. B.');
assert.strictEqual(maskAddress('123 Đường Lê Lợi, Phường Bến Nghé, Quận 1, TP.HCM'), '***, Phường Bến Nghé, Quận 1, TP.HCM');
console.log('Masking tests PASS!');

console.log('=== TEST 3: Content Filter Util ===');
// Reason containing phone
const r1 = validateReasonInactive('Khóa vì nghi ngờ lừa đảo, liên hệ 0987654321');
assert.strictEqual(r1.valid, false, 'Phải chặn lý do chứa SĐT');
console.log('PII Phone blocked:', r1.error);

// Reason containing email
const r2 = validateReasonInactive('Liên hệ admin@finance.vn');
assert.strictEqual(r2.valid, false, 'Phải chặn lý do chứa email');

// Reason containing profanity
const r3 = validateReasonInactive('Tài khoản này là thằng chó lừa đảo');
assert.strictEqual(r3.valid, false, 'Phải chặn lý do chứa từ ngữ thô tục');

// Valid reason
const r4 = validateReasonInactive('Vi phạm điều khoản đăng nhập bất thường nhiều thiết bị');
assert.strictEqual(r4.valid, true, 'Lý do hợp lệ phải PASS');

// Filter Note
const rawNote = 'Mua hàng online số thẻ 4532015896321478 và cvv: 123 mật khẩu: abcxyz';
const cleanedNote = filterSensitiveNote(rawNote);
console.log('Raw Note:', rawNote);
console.log('Cleaned Note:', cleanedNote);
assert(!cleanedNote.includes('4532015896321478'), 'Phải lược bỏ số thẻ');
assert(!cleanedNote.includes('123'), 'Phải lược bỏ CVV');
assert(!cleanedNote.includes('abcxyz'), 'Phải lược bỏ mật khẩu');

console.log('✅ TẤT CẢ UNIT TEST UTILITY ĐÃ PASS 100%!');
