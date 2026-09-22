/**
 * Test Suite: Kiểm thử bộ lọc ghi chú nhạy cảm (Note Filter)
 * Tuân thủ SYNC_NOTE_FILTER_REWRITE.md và Nghị định 13/2023/NĐ-CP
 * Kiểm tra: Thuật toán Luhn, bảo vệ từ khóa 'pin', bắt mật khẩu có dấu [:=], mã bảo mật CVV
 */

const { filterSensitiveNote, luhnOk } = require('../src/Backend/utils/content-filter.util');

const colors = {
  reset: "\x1b[0m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  cyan: "\x1b[36m",
  bright: "\x1b[1m",
};

let passed = 0;
let failed = 0;

function assert(condition, message, detail = '') {
  if (condition) {
    console.log(`${colors.green}  ✓ PASSED: ${message}${colors.reset}`);
    passed++;
  } else {
    console.error(`${colors.red}  ✗ FAILED: ${message}${colors.reset} ${detail}`);
    failed++;
  }
}

function runTests() {
  console.log(`\n${colors.cyan}${colors.bright}======================================================================${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}      TEST SUITE: KIỂM THỬ BỘ LỌC GHI CHÚ NHẠY CẢM (SENSITIVE NOTE)   ${colors.reset}`);
  console.log(`${colors.cyan}${colors.bright}======================================================================${colors.reset}\n`);

  // TC01: Thẻ Visa 16 số chuẩn (vượt qua Luhn)
  // 4532 0151 1283 0366 là số thẻ thử nghiệm chuẩn Luhn
  const visaNote = "Thanh toán thẻ 4532015112830366 tại siêu thị";
  const res1 = filterSensitiveNote(visaNote);
  assert(res1.includes('[THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ]') && !res1.includes('4532015112830366'),
    'TC01: Thẻ Visa 16 số liên tục (Luhn valid) phải được che', `Result: ${res1}`);

  // TC02: Thẻ Mastercard có dấu cách (4x4)
  const mcNote = "Chuyển tiền thẻ 5105 1051 0510 5100";
  const res2 = filterSensitiveNote(mcNote);
  assert(res2.includes('[THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ]') && !res2.includes('5105'),
    'TC02: Thẻ Mastercard 16 số có dấu cách (Luhn valid) phải được che', `Result: ${res2}`);

  // TC03: Thẻ Amex 15 số có dấu gạch ngang
  // 3782-822463-10005 (Amex valid Luhn)
  const amexNote = "Quẹt thẻ 3782-822463-10005";
  const res3 = filterSensitiveNote(amexNote);
  assert(res3.includes('[THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ]') && !res3.includes('3782'),
    'TC03: Thẻ Amex 15 số (Luhn valid) phải được che', `Result: ${res3}`);

  // TC04: Dãy 16 số nhưng KHÔNG thỏa mãn Luhn
  const invalidCard = "Mã tham chiếu 1234567812345671 giao dịch";
  const res4 = filterSensitiveNote(invalidCard);
  assert(res4 === invalidCard,
    'TC04: Dãy 16 số không qua thuật toán Luhn KHÔNG được che nhầm', `Result: ${res4}`);

  // TC05: Số điện thoại thông thường 10 chữ số
  const phoneNote = "Gọi cho 0912345678 nhận hàng";
  const res5 = filterSensitiveNote(phoneNote);
  assert(res5 === phoneNote,
    'TC05: Số điện thoại không bị coi là số thẻ', `Result: ${res5}`);

  // TC06: Mã chuyển khoản ngân hàng dài
  const ftNote = "Mã giao dịch FT2409101234567890 thành công";
  const res6 = filterSensitiveNote(ftNote);
  assert(res6 === ftNote,
    'TC06: Mã giao dịch ngân hàng kèm chữ cái không bị cắt', `Result: ${res6}`);

  // TC07: "Thay pin: 350000" KHÔNG bị lọc vì từ 'pin' không phải mật khẩu
  const pinNote = "Thay pin: 350000";
  const res7 = filterSensitiveNote(pinNote);
  assert(res7 === pinNote,
    'TC07: Ghi chú "Thay pin: 350000" KHÔNG bị lọc nhầm thành mật khẩu', `Result: ${res7}`);

  // TC08: "Pin sạc dự phòng: 250000" KHÔNG bị lọc
  const pinPowerNote = "Mua Pin sạc dự phòng: 250000";
  const res8 = filterSensitiveNote(pinPowerNote);
  assert(res8 === pinPowerNote,
    'TC08: Ghi chú "Pin sạc dự phòng: 250000" KHÔNG bị lọc nhầm', `Result: ${res8}`);

  // TC09: "Mật khẩu: mySecret123" bị che
  const pwdNote1 = "Ghi nhớ Mật khẩu: mySecret123 cho tài khoản";
  const res9 = filterSensitiveNote(pwdNote1);
  assert(res9.includes('Mật khẩu: [ĐÃ LƯỢC BỎ]') && !res9.includes('mySecret123'),
    'TC09: "Mật khẩu: mySecret123" được che thành công', `Result: ${res9}`);

  // TC10: "mat khau = pass_abc" bị che
  const pwdNote2 = "mat khau = pass_abc";
  const res10 = filterSensitiveNote(pwdNote2);
  assert(res10.includes('Mật khẩu: [ĐÃ LƯỢC BỎ]') && !res10.includes('pass_abc'),
    'TC10: "mat khau = pass_abc" có dấu = được che thành công', `Result: ${res10}`);

  // TC11: "password: secret" bị che
  const pwdNote3 = "Web login password: secretPassword!";
  const res11 = filterSensitiveNote(pwdNote3);
  assert(res11.includes('Mật khẩu: [ĐÃ LƯỢC BỎ]') && !res11.includes('secretPassword!'),
    'TC11: "password: secretPassword!" được che thành công', `Result: ${res11}`);

  // TC12: "passcode: 987654" bị che
  const pwdNote4 = "Cửa nhà passcode: 987654";
  const res12 = filterSensitiveNote(pwdNote4);
  assert(res12.includes('Mật khẩu: [ĐÃ LƯỢC BỎ]') && !res12.includes('987654'),
    'TC12: "passcode: 987654" được che thành công', `Result: ${res12}`);

  // TC13: Mã bảo mật "CVV: 123" bị che
  const cvvNote = "Mã CVV: 123 phía sau";
  const res13 = filterSensitiveNote(cvvNote);
  assert(res13.includes('CVV: [ĐÃ LƯỢC BỎ]') && !res13.includes('123'),
    'TC13: "CVV: 123" được che thành công', `Result: ${res13}`);

  // TC14: Mã bảo mật "cvc 4567" bị che
  const cvcNote = "cvc 4567";
  const res14 = filterSensitiveNote(cvcNote);
  assert(res14.includes('CVV: [ĐÃ LƯỢC BỎ]') && !res14.includes('4567'),
    'TC14: "cvc 4567" được che thành công', `Result: ${res14}`);

  // TC15: Chuỗi đã được che từ trước giữ nguyên không biến dạng
  const alreadyMasked = "Đã che [THÔNG TIN THẺ ĐÃ ĐƯỢC LƯỢC BỎ] an toàn";
  const res15 = filterSensitiveNote(alreadyMasked);
  assert(res15 === alreadyMasked,
    'TC15: Chuỗi đã che từ trước được bảo toàn nguyên vẹn', `Result: ${res15}`);

  console.log(`\n${colors.cyan}----------------------------------------------------------------------${colors.reset}`);
  console.log(`${colors.bright}Kết quả kiểm thử: ${passed} PASSED, ${failed} FAILED${colors.reset}`);
  if (failed > 0) {
    process.exit(1);
  } else {
    console.log(`${colors.green}${colors.bright}✔ 100% TEST CASES ĐẠT YÊU CẦU BẢO MẬT GHI CHÚ!${colors.reset}\n`);
  }
}

runTests();
