const test = require('node:test');
const assert = require('node:assert/strict');

// Mô phỏng chính xác môi trường Cloud Server (Render / Linux / Docker) chạy múi giờ UTC
process.env.TZ = 'UTC';

// Import trực tiếp hàm getVnTimeParts từ admin.service
const adminService = require('../../modules/admin/admin.service');

test('AdminStats Timezone Test — Gom bucket phải chuẩn theo múi giờ Việt Nam (GMT+7)', async (t) => {
  await t.test('1. Kiểm tra log lúc 17:47 GMT+7 (10:47 UTC) phải rơi vào bucket 17:00 chứ không phải 10:00', async () => {
    // Giả lập log có time_req là 17:47:00 tại Việt Nam (+07:00) => tương đương 10:47:00Z UTC
    const vnTimeIso = '2026-09-26T17:47:00+07:00';
    const mockLogs = [
      {
        idlog: 1,
        time_req: new Date(vnTimeIso),
        req_status: 'Pass',
      },
    ];

    // Tạo mock repository trả về mockLogs
    const adminRepository = require('../../modules/admin/admin.repository');
    const originalGetLoginLogs = adminRepository.getLoginLogsByRange;
    const originalGetRequestLogs = adminRepository.getRequestLogsByRange;

    try {
      adminRepository.getLoginLogsByRange = async () => mockLogs;
      adminRepository.getRequestLogsByRange = async () => mockLogs;

      // Gọi getLoginStats với date cụ thể
      const loginStats = await adminService.getLoginStats('date:2026-09-26');
      
      const bucket10 = loginStats.timeline.find((b) => b.key === '10');
      const bucket17 = loginStats.timeline.find((b) => b.key === '17');

      // Khẳng định: log phải vào bucket 17:00, không được rơi vào bucket 10:00 (lệch giờ UTC)
      assert.strictEqual(
        bucket17?.count,
        1,
        `Kỳ vọng bucket '17' (17:00 giờ VN) có count = 1, nhưng thực tế bucket 17 có count = ${bucket17?.count} và bucket 10 có count = ${bucket10?.count}`
      );
      assert.strictEqual(
        bucket10?.count,
        0,
        `Kỳ vọng bucket '10' có count = 0, nhưng thực tế có count = ${bucket10?.count}`
      );
    } finally {
      adminRepository.getLoginLogsByRange = originalGetLoginLogs;
      adminRepository.getRequestLogsByRange = originalGetRequestLogs;
    }
  });

  await t.test('2. Kiểm tra log lúc 02:30 sáng ngày 26/09 GMT+7 (19:30 ngày 25/09 UTC) khi xem theo 7 ngày phải thuộc ngày 26 chứ không phải 25', async () => {
    // 02:30 sáng ngày 26/09 Việt Nam tương đương 19:30 ngày 25/09 UTC
    const logDate = new Date('2026-09-26T02:30:00+07:00');
    const mockLogs = [
      {
        idlog: 2,
        time_req: logDate,
        req_status: 'Pass',
      },
    ];

    const adminRepository = require('../../modules/admin/admin.repository');
    const originalGetLoginLogs = adminRepository.getLoginLogsByRange;

    try {
      adminRepository.getLoginLogsByRange = async () => mockLogs;

      const loginStats = await adminService.getLoginStats('7days');
      const bucketDay26 = loginStats.timeline.find((b) => b.key.endsWith('-26'));
      const bucketDay25 = loginStats.timeline.find((b) => b.key.endsWith('-25'));

      assert.strictEqual(
        bucketDay26?.count,
        1,
        `Kỳ vọng bucket ngày 26/09 có count = 1, thực tế ngày 26 có ${bucketDay26?.count}, ngày 25 có ${bucketDay25?.count}`
      );
      if (bucketDay25) {
        assert.strictEqual(bucketDay25.count, 0, `Kỳ vọng bucket ngày 25/09 có count = 0`);
      }
    } finally {
      adminRepository.getLoginLogsByRange = originalGetLoginLogs;
    }
  });
});
