const test = require('node:test');
const assert = require('node:assert');
const aiopsController = require('../../modules/aiops/aiops.controller');
const { defaultAIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
const { defaultAIOpsQuarantineRepository } = require('../../modules/aiops/aiops.quarantine.repository');

test('AIOps Quarantine Controller & Forensics Endpoint Suite (Task 4)', async (t) => {
  // Mock Response Helper
  const createMockRes = () => {
    const res = {};
    res.statusCode = 200;
    res.jsonPayload = null;
    res.status = (code) => {
      res.statusCode = code;
      return res;
    };
    res.json = (data) => {
      res.jsonPayload = data;
      return res;
    };
    return res;
  };

  await t.test('1. getQuarantineForensics: Trả về danh sách điều tra chéo N-N thành công', async () => {
    // Đăng ký 1 pair để tạo link với ipHash duy nhất cho test run
    const uniqueTestIp = `ip_ctrl_test_${Date.now()}`;
    await defaultAIOpsQuarantineRepository.recordQuarantinePair({
      ipHash: uniqueTestIp,
      username: 'user_controller_test',
      reason: 'SQL Injection detected',
    });

    const req = {
      query: { ipHash: uniqueTestIp, page: 1, limit: 10 },
      user: { username: 'investigator_admin' },
    };
    const res = createMockRes();

    await aiopsController.getQuarantineForensics(req, res);

    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.jsonPayload.success, true);
    assert.ok(res.jsonPayload.data);
    assert.strictEqual(res.jsonPayload.data.total, 1);
    assert.strictEqual(res.jsonPayload.data.incidents[0].username, 'user_controller_test');
  });

  await t.test('2. unblockIp trích xuất unblocked_by từ req.user', async () => {
    const ipHash = 'ip_unblock_ctrl';
    const pair = defaultAIOpsQuarantine.quarantinePair({
      ipHash,
      maskedIp: '8.8.xx.xx',
      username: 'user_temp',
    });
    if (pair?._persistPromise) {
      await pair._persistPromise;
    }

    const req = {
      body: { ipHash },
      user: { username: 'sec_admin_01' },
    };
    const res = createMockRes();

    await aiopsController.unblockIp(req, res);
    assert.strictEqual(res.statusCode, 200);

    const ipInDb = await defaultAIOpsQuarantineRepository.getIpByHash(ipHash);
    assert.strictEqual(ipInDb.status, 'UNLOCKED');
    assert.strictEqual(ipInDb.unblocked_by, 'sec_admin_01');
  });

  await t.test('3. permanentBanAccount trích xuất banned_by từ req.user', async () => {
    const username = 'hacker_to_ban';
    const pair = defaultAIOpsQuarantine.quarantinePair({
      ipHash: 'ip_sample_hash',
      username,
    });
    if (pair?._persistPromise) {
      await pair._persistPromise;
    }

    const req = {
      body: { username },
      user: { username: 'lead_ciso' },
    };
    const res = createMockRes();

    await aiopsController.permanentBanAccount(req, res);
    assert.strictEqual(res.statusCode, 200);

    const accInDb = await defaultAIOpsQuarantineRepository.getAccountByUsername(username);
    assert.strictEqual(accInDb.status, 'PERMANENT');
    assert.strictEqual(accInDb.banned_by, 'lead_ciso');
  });
});
