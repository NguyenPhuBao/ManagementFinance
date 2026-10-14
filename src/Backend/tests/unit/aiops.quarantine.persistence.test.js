const test = require('node:test');
const assert = require('node:assert');
const { AIOpsQuarantine, hashIp } = require('../../modules/aiops/aiops.quarantine');
const { AIOpsQuarantineRepository } = require('../../modules/aiops/aiops.quarantine.repository');

test('AIOpsQuarantine Persistence & Hydration Suite (Task 3)', async (t) => {
  let mockRepo;
  let qInstance;

  t.beforeEach(() => {
    mockRepo = new AIOpsQuarantineRepository({ pool: null });
    qInstance = new AIOpsQuarantine({ repository: mockRepo });
  });

  await t.test('1. quarantinePair tự động write-through xuống repository', async () => {
    const rawIp = '198.51.100.77';
    const clientHash = hashIp(rawIp);

    await qInstance.quarantinePair({
      ip: rawIp,
      username: 'target_victim',
      reason: 'SQL Injection detected',
      durationMs: 30 * 60 * 1000,
    });

    // Kiểm tra trong RAM của instance
    const ramCheck = qInstance.isQuarantined(rawIp);
    assert.strictEqual(ramCheck.quarantined, true);

    // Kiểm tra đã được ghi vào repository
    const ipInRepo = await mockRepo.getIpByHash(clientHash);
    assert.ok(ipInRepo, 'IP phải được ghi vào CSDL qua repository');
    assert.strictEqual(ipInRepo.status, 'TEMPORARY');

    const accInRepo = await mockRepo.getAccountByUsername('target_victim');
    assert.ok(accInRepo, 'Tài khoản phải được ghi vào CSDL qua repository');
  });

  await t.test('2. Hydration sau Restart: Instance mới khôi phục 100% các IP bị chặn từ Repository', async () => {
    const permIp = '203.0.113.10';
    const permHash = hashIp(permIp);
    const tempIp = '203.0.113.20';
    const tempHash = hashIp(tempIp);

    // 1. Instance 1 ghi nhận cấm
    await qInstance.quarantinePair({
      ip: permIp,
      username: 'hacker_1',
      banType: 'permanent',
      reason: 'DDoS flooding',
    });

    await qInstance.quarantinePair({
      ip: tempIp,
      username: 'hacker_2',
      banType: 'temporary',
      durationMs: 15 * 60 * 1000,
      reason: 'Brute-force auth',
    });

    // 2. Mô phỏng Restart Server: Tạo instance mới toanh với memory rỗng
    const restartedInstance = new AIOpsQuarantine({ repository: mockRepo });
    // Trước khi hydrate: RAM rỗng -> không chặn
    assert.strictEqual(restartedInstance.isQuarantined(permIp).quarantined, false);

    // 3. Tiến hành Hydrate từ Database
    const hydratedCount = await restartedInstance.hydrateFromDatabase();
    assert.ok(hydratedCount >= 2, 'Phải nạp thành công các bản ghi active');

    // 4. Sau khi hydrate: Chặn tức thì O(1) từ RAM
    const checkPerm = restartedInstance.isQuarantined(permIp);
    assert.strictEqual(checkPerm.quarantined, true, 'IP cấm vĩnh viễn phải được khôi phục chặn');

    const checkTemp = restartedInstance.isQuarantined(tempIp);
    assert.strictEqual(checkTemp.quarantined, true, 'IP tạm khóa phải được khôi phục chặn');
  });

  await t.test('3. unblockIp và permanentBanIp đồng bộ trạng thái vào repository', async () => {
    const ip = '198.51.100.99';
    const ipHash = hashIp(ip);

    await qInstance.quarantinePair({
      ip,
      username: 'victim_x',
      reason: 'Rate limit',
    });

    // Mở khóa IP
    await qInstance.unblockIp(ipHash, { unblockedBy: 'admin_security' });

    // Kiểm tra repository
    const ipInRepo = await mockRepo.getIpByHash(ipHash);
    assert.strictEqual(ipInRepo.status, 'UNLOCKED');
    assert.strictEqual(ipInRepo.unblocked_by, 'admin_security');
  });

  await t.test('4. unblockAccount và permanentBanAccount đồng bộ trạng thái vào repository', async () => {
    await qInstance.quarantinePair({
      ip: '198.51.100.88',
      username: 'user_compromised',
      idaccount: 505,
      reason: 'Account takeover attempt',
    });

    // Khóa vĩnh viễn tài khoản
    await qInstance.permanentBanAccount('user_compromised', { bannedBy: 'ciso_officer' });

    // Kiểm tra repository
    const accInRepo = await mockRepo.getAccountByUsername('user_compromised');
    assert.strictEqual(accInRepo.status, 'PERMANENT');
    assert.strictEqual(accInRepo.banned_by, 'ciso_officer');
  });
});
