/** Bật rào chắn ở chế độ dùng CSDL dùng chung; chỉ `npm run test:shared-db` nạp tệp này (xem test-guard.js). */
process.env.TEST_USE_SHARED_DB = '1';
require('./test-guard');
