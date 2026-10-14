const test = require('node:test');
const assert = require('node:assert');
const { AIOpsQuarantineRepository } = require('../../modules/aiops/aiops.quarantine.repository');

test('AIOpsQuarantineRepository Unit Test Suite (Task 2)', async (t) => {
  let repo;

  // Sử dụng mock pool / in-memory fallback cho unit tests
  t.beforeEach(() => {
    repo = new AIOpsQuarantineRepository({ pool: null });
  });

  await t.test('1. recordQuarantinePair: Lưu trữ thành công vào cả 3 bảng (IP, Account và Incident Link)', async () => {
    const pair = await repo.recordQuarantinePair({
      ip: '113.161.45.22',
      ipHash: 'ip_hash_111',
      maskedIp: '113.161.xx.xx',
      username: 'attacker_target_1',
      idaccount: 101,
      reason: 'Brute-force login attack',
      durationMs: 15 * 60 * 1000,
      banType: 'temporary',
      vector: 'auth',
      threatScore: 85,
      bannedBy: 'AIOps Sentinel',
    });

    assert.ok(pair, 'Phải trả về bản ghi pair');
    assert.strictEqual(pair.ipHash, 'ip_hash_111');
    assert.strictEqual(pair.username, 'attacker_target_1');

    // Kiểm tra trong bộ lưu trữ IP
    const ipRecord = await repo.getIpByHash('ip_hash_111');
    assert.ok(ipRecord, 'Phải tìm thấy IP trong bảng IP quarantine');
    assert.strictEqual(ipRecord.status, 'TEMPORARY');
    assert.strictEqual(ipRecord.hits, 1);

    // Kiểm tra trong bộ lưu trữ Account
    const accRecord = await repo.getAccountByUsername('attacker_target_1');
    assert.ok(accRecord, 'Phải tìm thấy tài khoản trong bảng Account quarantine');
    assert.strictEqual(accRecord.status, 'TEMPORARY');
    assert.strictEqual(accRecord.idaccount, 101);

    // Kiểm tra bảng liên kết incident link
    const links = await repo.getLinksByIpHash('ip_hash_111');
    assert.strictEqual(links.length, 1);
    assert.strictEqual(links[0].username, 'attacker_target_1');
  });

  await t.test('2. Quan hệ N-N: 1 IP tấn công nhiều tài khoản -> Bảng liên kết lưu đầy đủ', async () => {
    const attackerHash = 'ip_hash_botnet';
    await repo.recordQuarantinePair({
      ip: '42.112.50.88',
      ipHash: attackerHash,
      maskedIp: '42.112.xx.xx',
      username: 'victim_user_a',
      reason: 'SQL Injection',
    });

    await repo.recordQuarantinePair({
      ip: '42.112.50.88',
      ipHash: attackerHash,
      maskedIp: '42.112.xx.xx',
      username: 'victim_user_b',
      reason: 'SQL Injection',
    });

    // 1 IP phải có 2 liên kết tới 2 tài khoản khác nhau
    const links = await repo.getLinksByIpHash(attackerHash);
    assert.strictEqual(links.length, 2);
    const usernames = links.map((l) => l.username);
    assert.ok(usernames.includes('victim_user_a'));
    assert.ok(usernames.includes('victim_user_b'));
  });

  await t.test('3. loadActiveQuarantines: Nạp đúng các IP và tài khoản đang có hiệu lực (TEMPORARY chưa hết hạn & PERMANENT)', async () => {
    // 1. IP vĩnh viễn
    await repo.recordQuarantinePair({
      ipHash: 'ip_perm',
      maskedIp: '1.1.xx.xx',
      username: 'user_perm',
      banType: 'permanent',
      reason: 'DDoS',
    });

    // 2. IP tạm khóa chưa hết hạn (15 phút)
    await repo.recordQuarantinePair({
      ipHash: 'ip_temp_valid',
      maskedIp: '2.2.xx.xx',
      username: 'user_valid',
      banType: 'temporary',
      durationMs: 15 * 60 * 1000,
      reason: 'Brute-force',
    });

    const activeData = await repo.loadActiveQuarantines();
    assert.ok(Array.isArray(activeData.ips));
    assert.ok(Array.isArray(activeData.accounts));
    assert.ok(Array.isArray(activeData.links));

    const activeIpHashes = activeData.ips.map((x) => x.ip_hash);
    assert.ok(activeIpHashes.includes('ip_perm'));
    assert.ok(activeIpHashes.includes('ip_temp_valid'));
  });

  await t.test('4. updateIpStatus: Mở khóa IP cập nhật status UNLOCKED và unblocked_by', async () => {
    await repo.recordQuarantinePair({
      ipHash: 'ip_to_unblock',
      maskedIp: '3.3.xx.xx',
      username: 'user_x',
      reason: 'Rate limit',
    });

    const updatedCount = await repo.updateIpStatus({
      ipHash: 'ip_to_unblock',
      status: 'UNLOCKED',
      unblockedBy: 'super_admin',
      unblockReason: 'Admin xác minh người dùng hợp lệ',
    });

    assert.ok(updatedCount > 0);
    const ip = await repo.getIpByHash('ip_to_unblock');
    assert.strictEqual(ip.status, 'UNLOCKED');
    assert.strictEqual(ip.unblocked_by, 'super_admin');
    assert.strictEqual(ip.expires_at, null, 'expires_at của IP khi mở khóa UNLOCKED phải là null');
    assert.ok(ip.unblocked_at, 'unblocked_at phải có giá trị thời gian');
  });

  await t.test('5. updateAccountStatus: Khóa vĩnh viễn tài khoản cập nhật PERMANENT', async () => {
    await repo.recordQuarantinePair({
      ipHash: 'ip_any',
      maskedIp: '4.4.xx.xx',
      username: 'malicious_user',
      idaccount: 999,
      reason: 'Gian lận',
    });

    await repo.updateAccountStatus({
      username: 'malicious_user',
      idaccount: 999,
      status: 'PERMANENT',
      bannedBy: 'security_lead',
    });

    const acc = await repo.getAccountByUsername('malicious_user');
    assert.strictEqual(acc.status, 'PERMANENT');
    assert.strictEqual(acc.expires_at, null, 'expires_at của tài khoản khi khóa vĩnh viễn phải là null');
  });

  await t.test('6. getForensicInvestigationLogs: Truy vết điều tra chéo N-N', async () => {
    const ipTarget = 'ip_forensics_test';
    await repo.recordQuarantinePair({
      ipHash: ipTarget,
      maskedIp: '5.5.xx.xx',
      username: 'target_acc_1',
      reason: 'Quét cổng',
    });
    await repo.recordQuarantinePair({
      ipHash: ipTarget,
      maskedIp: '5.5.xx.xx',
      username: 'target_acc_2',
      reason: 'Thử SQL injection',
    });

    // Tra cứu theo IP
    const ipForensics = await repo.getForensicInvestigationLogs({ ipHash: ipTarget });
    assert.strictEqual(ipForensics.total, 2);
    assert.strictEqual(ipForensics.incidents.length, 2);

    // Tra cứu theo Tài khoản
    const accForensics = await repo.getForensicInvestigationLogs({ username: 'target_acc_1' });
    assert.strictEqual(accForensics.total, 1);
    assert.strictEqual(accForensics.incidents[0].ip_hash, ipTarget);
  });

  await t.test('7. Đồng bộ CSDL: expires_at được xóa null khi UNLOCKED và cập nhật hạn mới khi TEMPORARY', async () => {
    // 1. Kiểm tra Account khi mở khóa UNLOCKED -> expires_at chuyển về null
    await repo.recordQuarantinePair({
      ipHash: 'ip_sync_test',
      maskedIp: '6.6.xx.xx',
      username: 'account_sync_user',
      idaccount: 777,
      durationMs: 3600000,
      banType: 'temporary',
    });

    const initialAcc = await repo.getAccountByUsername('account_sync_user');
    assert.ok(initialAcc.expires_at !== null, 'Ban đầu phải có expires_at khi TEMPORARY');

    // Mở khóa tài khoản
    await repo.updateAccountStatus({
      username: 'account_sync_user',
      idaccount: 777,
      status: 'UNLOCKED',
      unblockedBy: 'admin',
    });
    const unblockedAcc = await repo.getAccountByUsername('account_sync_user');
    assert.strictEqual(unblockedAcc.status, 'UNLOCKED');
    assert.strictEqual(unblockedAcc.expires_at, null, 'expires_at phải là null khi UNLOCKED');

    // 2. Kiểm tra IP khi tạm khóa TEMPORARY với hạn mới
    const newExpiresAt = new Date(Date.now() + 8 * 3600000);
    await repo.updateIpStatus({
      ipHash: 'ip_sync_test',
      status: 'TEMPORARY',
      bannedBy: 'security_admin',
      expiresAt: newExpiresAt,
    });
    const tempIp = await repo.getIpByHash('ip_sync_test');
    assert.strictEqual(tempIp.status, 'TEMPORARY');
    assert.strictEqual(tempIp.expires_at.getTime(), newExpiresAt.getTime(), 'expires_at của IP phải được cập nhật thời hạn mới');

    // 3. Kiểm tra Account khi tạm khóa TEMPORARY với hạn mới
    await repo.updateAccountStatus({
      username: 'account_sync_user',
      idaccount: 777,
      status: 'TEMPORARY',
      bannedBy: 'security_admin',
      expiresAt: newExpiresAt,
    });
    const tempAcc = await repo.getAccountByUsername('account_sync_user');
    assert.strictEqual(tempAcc.status, 'TEMPORARY');
    assert.strictEqual(tempAcc.expires_at.getTime(), newExpiresAt.getTime(), 'expires_at của Account phải được cập nhật thời hạn mới');
  });

  await t.test('8. Đồng bộ SQL PostgreSQL: Parameterized query truyền đúng expires_at và logic CASE WHEN', async () => {
    let executedSql = '';
    let executedParams = [];
    const mockPool = {
      query: async (sql, params) => {
        executedSql = sql;
        executedParams = params;
        return { rowCount: 1, rows: [] };
      },
    };
    const dbRepo = new AIOpsQuarantineRepository({ pool: mockPool });

    // 1. IP UNLOCKED -> $1 = 'UNLOCKED', $6 = null
    await dbRepo.updateIpStatus({
      ipHash: 'ip_sql_test',
      status: 'UNLOCKED',
      unblockedBy: 'admin_audit',
    });
    assert.ok(executedSql.includes('UPDATE "aiops_ip_quarantine"'));
    assert.ok(executedSql.includes('"expires_at" = CASE'));
    assert.strictEqual(executedParams[0], 'UNLOCKED');

    // 2. Account TEMPORARY -> $1 = 'TEMPORARY', $8 = newExpiresAt
    const tempExp = new Date();
    await dbRepo.updateAccountStatus({
      username: 'user_sql_test',
      status: 'TEMPORARY',
      expiresAt: tempExp,
    });
    assert.ok(executedSql.includes('UPDATE "aiops_account_quarantine"'));
    assert.strictEqual(executedParams[0], 'TEMPORARY');
    assert.strictEqual(executedParams[7], tempExp);
  });

  await t.test('9. autoExpireInDatabase: Tự động chuyển UNLOCKED và xóa expires_at cho các bản ghi đã quá hạn', async () => {
    // Tạo 1 IP và 1 tài khoản có hạn trong quá khứ
    const pastExp = new Date(Date.now() - 60000);
    await repo.recordQuarantinePair({
      ipHash: 'ip_expired_auto',
      maskedIp: '9.9.xx.xx',
      username: 'user_expired_auto',
      banType: 'temporary',
      durationMs: 1000,
    });

    // Cố ý set expires_at về quá khứ
    const ip = await repo.getIpByHash('ip_expired_auto');
    ip.expires_at = pastExp;
    const acc = await repo.getAccountByUsername('user_expired_auto');
    acc.expires_at = pastExp;

    // Chạy autoExpireInDatabase
    const result = await repo.autoExpireInDatabase();
    assert.ok(result.expiredIps.length > 0 || result.expiredAccounts.length > 0);

    const expiredIp = await repo.getIpByHash('ip_expired_auto');
    assert.strictEqual(expiredIp.status, 'UNLOCKED');
    assert.strictEqual(expiredIp.expires_at, null);

    const expiredAcc = await repo.getAccountByUsername('user_expired_auto');
    assert.strictEqual(expiredAcc.status, 'UNLOCKED');
    assert.strictEqual(expiredAcc.expires_at, null);
  });
});
