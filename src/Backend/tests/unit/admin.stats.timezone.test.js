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

  await t.test('2. Kiểm tra log lúc 02:30 sáng GMT+7 (19:30 tối hôm trước UTC) khi xem theo 7 ngày phải thuộc ngày hiện tại chứ không phải ngày hôm trước', async () => {
    // Lấy ngày cách đây 2 ngày để luôn nằm trọn vẹn trong cửa sổ 7days
    const targetVn = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000);
    const yyyy = targetVn.getFullYear();
    const mm = String(targetVn.getMonth() + 1).padStart(2, '0');
    const dd = String(targetVn.getDate()).padStart(2, '0');
    
    // 02:30 sáng ngày dd tại Việt Nam (+07:00) tương đương 19:30 ngày hôm trước (dd-1) theo UTC
    const logDate = new Date(`${yyyy}-${mm}-${dd}T02:30:00+07:00`);
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
      const expectedDayKey = `${yyyy}-${mm}-${dd}`;
      const bucketTarget = loginStats.timeline.find((b) => b.key === expectedDayKey);

      assert.strictEqual(
        bucketTarget?.count,
        1,
        `Kỳ vọng bucket ngày ${expectedDayKey} có count = 1, thực tế có ${bucketTarget?.count}`
      );
    } finally {
      adminRepository.getLoginLogsByRange = originalGetLoginLogs;
    }
  });
});
