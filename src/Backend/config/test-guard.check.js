/**
 * Chặn `node --test` chạy trần: `.env` trỏ CSDL và Redis dùng chung, nên test không qua rào sẽ ghi dữ liệu thật.
 * `NODE_TEST_CONTEXT` do trình chạy test của Node đặt, ứng dụng và script thường không có biến này.
 */
function assertGuardedTestRun() {
  if (process.env.NODE_TEST_CONTEXT && process.env.FLOWMONEY_TEST_GUARD !== '1') {
    throw new Error('Test đang chạy không có rào chắn nên có thể ghi vào CSDL dùng chung. Dùng `npm test` / `npm run test:unit`, hoặc thêm `--require ./tests/setup/test-guard.js`.');
  }
}

module.exports = { assertGuardedTestRun };
