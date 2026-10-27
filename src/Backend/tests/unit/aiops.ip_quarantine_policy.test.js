const test = require('node:test');
const assert = require('node:assert/strict');
const { AIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
const { AIOpsQuarantineRepository } = require('../../modules/aiops/aiops.quarantine.repository');
const aiopsController = require('../../modules/aiops/aiops.controller');

test('AIOps IP Quarantine Security Policy Suite (2-Tier Testing)', async (t) => {

  await t.test('1. [Tier 1] Controller permanentBanIp chuyển hóa thành Tạm khóa 4 giờ và trả HTTP 200', async () => {
    let responseData = null;
    let responseStatus = 200;

    const req = {
      body: { ip: '113.161.45.88', ipHash: 'hash_test_ip_1' },
      user: { username: 'SuperAdmin' },
    };

    const res = {
      status(code) {
        responseStatus = code;
        return this;
      },
      json(data) {
        responseData = data;
        return this;
      },
    };

    await aiopsController.permanentBanIp(req, res);

    assert.strictEqual(responseStatus, 200, 'HTTP status phải là 200');
    assert.strictEqual(responseData.success, true, 'Response phải thành công');
    assert.strictEqual(responseData.data.durationMs, 4 * 60 * 60 * 1000, 'Thời lượng phải đúng 4 giờ (14,400,000 ms)');
    assert.strictEqual(responseData.data.status, 'TEMPORARY', 'Trạng thái phản hồi phải là TEMPORARY');
    assert.ok(responseData.message.includes('4 giờ'), 'Thông điệp phải nêu rõ chính sách tạm khóa 4 giờ');
  });

  await t.test('2. [Tier 2] quarantinePair với banType = permanent: IP BẮT BUỘC luôn là temporary kèm thời hạn 4 giờ', () => {
    const quarantine = new AIOpsQuarantine({ autoExpire: false, repository: null });
    const now = Date.now();

    // Giả lập kịch bản phát hiện tấn công nghiêm trọng yêu cầu banType = 'permanent'
    const record = quarantine.quarantinePair({
      ip: '14.162.12.99',
      username: 'target_victim',
      reason: 'Phát hiện Brute-force mức độ cao',
      banType: 'permanent',
    });

    assert.ok(record, 'Phải tạo thành công bản ghi cách ly');
    
    // Tầng 2: Nghiêm cấm gán ipStatus là permanent
    assert.strictEqual(record.ipStatus, 'temporary', 'Chính sách PO: ipStatus BẮT BUỘC phải là temporary');
    assert.ok(record.ipExpiresAt !== null, 'ipExpiresAt bắt buộc khác null');
    assert.ok(record.ipExpiresAt >= now + 3.9 * 3600 * 1000, 'Thời hạn IP phải xấp xỉ 4 giờ');

    // Trong khi đó accountStatus vẫn có thể là permanent theo nghiệp vụ tài khoản
    assert.strictEqual(record.accountStatus, 'permanent', 'accountStatus vẫn có thể là permanent');
    assert.strictEqual(record.accountExpiresAt, null, 'accountExpiresAt là null khi khóa vĩnh viễn tài khoản');
  });

  await t.test('3. [Tier 2] permanentBanIp chuyển hóa thành temporaryBlockIp với thời hạn 4 giờ trong RAM', async () => {
    const quarantine = new AIOpsQuarantine({ autoExpire: false, repository: null });
    const testIp = '42.113.88.12';

    // Tạo bản ghi ban đầu
    quarantine.quarantinePair({ ip: testIp, username: 'user1' });

    // Gọi permanentBanIp
    await quarantine.permanentBanIp(testIp, { bannedBy: 'AdminTester' });

    // Tầng 2: Kiểm tra RAM ma trận
    const pair = Array.from(quarantine._pairs.values()).find((p) => p.ip === testIp);
    assert.ok(pair, 'Bản ghi phải tồn tại trong ma trận');
    assert.strictEqual(pair.ipStatus, 'temporary', 'ipStatus phải là temporary sau khi gọi permanentBanIp');
    assert.ok(pair.ipExpiresAt !== null, 'ipExpiresAt không được là null');
    assert.ok(pair.ipExpiresAt > Date.now(), 'ipExpiresAt phải ở tương lai');
  });

  await t.test('4. [Tier 2] Repository updateIpStatus: Tự động ép status PERMANENT về TEMPORARY và tính expires_at 4 giờ', async () => {
    let capturedQuery = null;
    let capturedParams = null;

    const mockPool = {
      async query(sql, params) {
        capturedQuery = sql;
        capturedParams = params;
        return { rowCount: 1 };
      },
    };

    const repo = new AIOpsQuarantineRepository(mockPool);

    // Cố ý truyền status = 'PERMANENT' vào updateIpStatus
    await repo.updateIpStatus({
      ipHash: 'attacker_ip_hash_xyz',
      status: 'PERMANENT',
      bannedBy: 'RogueAdmin',
    });

    assert.ok(capturedQuery, 'Phải thực thi SQL UPDATE');
    
    // Tầng 2: Tham số $1 truyền vào SQL UPDATE phải là 'TEMPORARY', tuyệt đối không phải 'PERMANENT'
    assert.strictEqual(capturedParams[0], 'TEMPORARY', 'Repository phải ép status thành TEMPORARY để bảo vệ CSDL');
    
    // Tham số $6 (expiresAt) phải có giá trị thời gian hợp lệ
    const expiresAtParam = capturedParams[5];
    assert.ok(expiresAtParam instanceof Date, 'expires_at truyền vào SQL phải là kiểu Date');
    const diffHours = (expiresAtParam.getTime() - Date.now()) / (3600 * 1000);
    assert.ok(diffHours >= 3.9 && diffHours <= 4.1, 'expires_at phải cách thời điểm hiện tại đúng 4 giờ');
  });

  await t.test('5. [Tier 2] Repository recordQuarantinePair: Lưu IP luôn dùng TEMPORARY và có expires_at kể cả khi banType = permanent', async () => {
    const executedQueries = [];

    const mockPool = {
      async query(sql, params) {
        executedQueries.push({ sql, params });
        return { rowCount: 1, rows: [{ id: 'mock_id' }] };
      },
    };

    const repo = new AIOpsQuarantineRepository(mockPool);

    await repo.recordQuarantinePair({
      ip: '27.72.100.5',
      ipHash: 'hash_test_db_guard',
      username: 'test_acc',
      banType: 'permanent', // Cố ý yêu cầu permanent
    });

    const ipInsertQuery = executedQueries.find((q) => q.sql.includes('INSERT INTO "aiops_ip_quarantine"'));
    assert.ok(ipInsertQuery, 'Phải có câu lệnh INSERT aiops_ip_quarantine');

    // Cột status của IP ($5)
    assert.strictEqual(ipInsertQuery.params[4], 'TEMPORARY', 'Cột status của aiops_ip_quarantine bắt buộc phải là TEMPORARY');
    
    // Cột expires_at của IP ($10)
    const ipExpiresAt = ipInsertQuery.params[9];
    assert.ok(ipExpiresAt instanceof Date, 'expires_at của IP bắt buộc phải có giá trị Date');
    assert.ok(ipExpiresAt.getTime() > Date.now(), 'expires_at của IP phải ở tương lai');
  });
});
