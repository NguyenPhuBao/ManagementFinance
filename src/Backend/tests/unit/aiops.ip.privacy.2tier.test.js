const { describe, it, afterEach } = require('node:test');
const assert = require('node:assert');
const { hashBlindIndex, encrypt } = require('../../utils/crypto.util');
const ipProtection = require('../../utils/ip-protection.util');
const { AIOpsQuarantine, hashIp } = require('../../modules/aiops/aiops.quarantine');
const { FeatureCollector } = require('../../modules/aiops/feature.collector');
const { AIOpsService } = require('../../modules/aiops/aiops.service');
const { AIOpsQuarantineRepository } = require('../../modules/aiops/aiops.quarantine.repository');
const aiopsController = require('../../modules/aiops/aiops.controller');
const adminService = require('../../modules/admin/admin.service');

const fakeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  return res;
};
const hasRawIp = (v) => JSON.stringify(v).match(/"(rawIp|raw_ip)"/) !== null;

describe('Tầng 1: một hàm băm IP có khóa cho toàn AIOps', () => {
  it('ipLookupHash dùng HMAC với BLIND_INDEX_SECRET, bỏ tiền tố ::ffff:, khớp chỉ mục mù của lịch sử thiết bị', () => {
    assert.strictEqual(ipProtection.ipLookupHash('::ffff:113.161.45.12'), hashBlindIndex('113.161.45.12'));
    assert.strictEqual(ipProtection.ipLookupHash('113.161.45.12'), ipProtection.protectIp('113.161.45.12').hash);
    assert.strictEqual(hashIp('113.161.45.12'), ipProtection.ipLookupHash('113.161.45.12'));
  });

  it('bộ thu thập đặc trưng băm IP giống lớp chặn (không còn muối ngẫu nhiên riêng)', () => {
    const a = new FeatureCollector();
    const b = new FeatureCollector();
    assert.strictEqual(a._hashIp('113.161.45.12'), hashIp('113.161.45.12'));
    assert.strictEqual(a._hashIp('113.161.45.12'), b._hashIp('113.161.45.12'));
  });

  it('stripRawIp bỏ rawIp / raw_ip ở mọi tầng, giữ phần còn lại', () => {
    const at = new Date('2026-11-13T00:00:00Z');
    const out = ipProtection.stripRawIp({
      a: 1, rawIp: '1.2.3.4', at,
      list: [{ actor: { rawIp: '1.2.3.4', maskedIp: '1.2.xxx.xxx', ipHash: 'h' } }, null, 'x'],
      nested: { raw_ip: 'enc:x', keep: true },
    });
    assert.deepStrictEqual(out, {
      a: 1, at,
      list: [{ actor: { maskedIp: '1.2.xxx.xxx', ipHash: 'h' } }, null, 'x'],
      nested: { keep: true },
    });
  });
});

describe('Tầng 2: chặn từ sự cố có tác dụng thật', () => {
  it('admin chặn bằng ipHash lấy từ sự cố → truy cập từ IP đó bị chặn', () => {
    const collector = new FeatureCollector();
    const incidentHash = collector._hashIp('203.0.113.9');
    const q = new AIOpsQuarantine({ repository: null, autoExpire: false });
    q.quarantineActor({ ipHash: incidentHash, maskedIp: '203.0.xxx.xxx', reason: 'thử', durationMs: 60000 });
    assert.strictEqual(q.isQuarantined('203.0.113.9').quarantined, true);
    assert.strictEqual(q.isQuarantined('203.0.113.10').quarantined, false);
  });
});

describe('Tầng 2: IP đầy đủ không ra khỏi Backend qua API / socket AIOps', () => {
  it('sự kiện admin.security_alert không mang rawIp', () => {
    const sent = [];
    const io = { to: () => ({ emit: (name, payload) => sent.push({ name, payload }) }) };
    const svc = new AIOpsService({ io, repository: {} });
    svc._dispatchAlert(
      {
        threatScore: 90, status: 'CRITICAL', vectorScores: {}, vectorDefenses: {},
        anomalies: [{ code: 'X', actor: { rawIp: '203.0.113.9', maskedIp: '203.0.xxx.xxx' } }],
        recommendedAction: 'BLOCK', evaluatedAt: new Date().toISOString(),
      },
      { topActors: [{ rawIp: '203.0.113.9' }] }
    );
    const alert = sent.find((s) => s.name === 'admin.security_alert');
    assert.ok(alert, 'phải phát cảnh báo');
    assert.strictEqual(alert.payload.anomalies[0].actor.maskedIp, '203.0.xxx.xxx');
    assert.ok(!hasRawIp(alert.payload));
  });

  it('sự kiện admin.anomaly_detected không mang rawIp', async () => {
    const sent = [];
    const io = { to: () => ({ emit: (name, payload) => sent.push({ name, payload }) }) };
    const repository = {
      upsertIncident: async (a) => ({ id: 'i1', ...a }),
      autoMitigateStaleIncidents: async () => [{ id: 'i0', actor: { rawIp: '203.0.113.8' } }],
    };
    const svc = new AIOpsService({
      io, repository,
      collector: { collectSample: () => ({}), snapshot: () => ({}), getSample: () => ({}) },
    });
    await svc._persistAndEmitAnomalies([{ code: 'X', actor: { rawIp: '203.0.113.9', maskedIp: '203.0.xxx.xxx' } }]);
    const events = sent.filter((s) => s.name === 'admin.anomaly_detected');
    assert.strictEqual(events.length, 2);
    assert.ok(!hasRawIp(events.map((e) => e.payload)));
  });

  it('chặn thủ công bằng IP: phản hồi chỉ có bản che và ipHash, không trả lại IP đầy đủ', () => {
    const { defaultAIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
    const origRepo = defaultAIOpsQuarantine.repository;
    defaultAIOpsQuarantine.repository = null;
    try {
      const req = { body: { ip: '198.51.100.51', reason: 'thử', durationMinutes: 5 } };
      const res = fakeRes();
      aiopsController.quarantineActor(req, res);
      assert.strictEqual(res.statusCode, 200);
      assert.ok(!JSON.stringify(res.body).includes('198.51.100.51'));
      assert.strictEqual(res.body.data.maskedIp, '198.51.xxx.xxx');
      assert.strictEqual(res.body.data.ipHash, hashIp('198.51.100.51'));
      defaultAIOpsQuarantine.unblock(hashIp('198.51.100.51'));
    } finally {
      defaultAIOpsQuarantine.repository = origRepo;
    }
  });

  it('phản hồi /admin/aiops/* đi qua bộ lọc: getStatus không trả rawIp', () => {
    const { stripRawIpResponse } = require('../../middleware/strip-raw-ip.middleware');
    const res = fakeRes();
    let nextCalled = false;
    stripRawIpResponse({}, res, () => { nextCalled = true; });
    assert.ok(nextCalled);
    res.json({ success: true, data: { anomalies: [{ actor: { rawIp: '203.0.113.9', maskedIp: '203.0.xxx.xxx' } }] } });
    assert.ok(!hasRawIp(res.body));
    assert.strictEqual(res.body.data.anomalies[0].actor.maskedIp, '203.0.xxx.xxx');
    const src = require('fs').readFileSync(require.resolve('../../api/admin.routes'), 'utf8');
    assert.match(src, /router\.use\('\/aiops', stripRawIpResponse\)/);
    assert.ok(src.indexOf("router.use('/aiops', stripRawIpResponse)") < src.indexOf("router.get('/aiops/status'"), 'bộ lọc phải gắn trước các route AIOps');
  });
});

describe('Tầng 2: lượt chặn cũ được tính lại giá trị băm khi nạp', () => {
  it('dòng có raw_ip mã hóa và ip_hash kiểu cũ → cập nhật ip_hash ở bảng chặn và bảng liên kết', async () => {
    const oldHash = 'abcdef0123456789';
    const newHash = hashIp('198.51.100.7');
    const queries = [];
    const pool = {
      query: async (sql, params = []) => {
        queries.push({ sql, params });
        if (/^SELECT \* FROM "aiops_ip_quarantine" ORDER/.test(sql.trim())) {
          return { rows: [{ id: 'q1', ip_hash: oldHash, masked_ip: '198.51.xxx.xxx', raw_ip: encrypt('198.51.100.7'), status: 'TEMPORARY' }] };
        }
        if (/^SELECT \* FROM "aiops_quarantine_incident_link"/.test(sql.trim())) {
          return { rows: [{ ip_hash: oldHash, username: 'u1' }] };
        }
        return { rows: [], rowCount: 0 };
      },
    };
    const repo = new AIOpsQuarantineRepository({ pool });
    repo.autoExpireInDatabase = async () => ({ expiredIps: [], expiredAccounts: [] });
    const loaded = await repo.loadActiveQuarantines();
    assert.strictEqual(loaded.ips[0].ip_hash, newHash);
    assert.strictEqual(loaded.links[0].ip_hash, newHash);
    const upd = queries.filter((q) => /^UPDATE/.test(q.sql.trim()));
    assert.ok(upd.some((q) => /"aiops_ip_quarantine"/.test(q.sql) && q.params.includes(newHash) && q.params.includes('q1')));
    assert.ok(upd.some((q) => /"aiops_quarantine_incident_link"/.test(q.sql) && q.params.includes(newHash) && q.params.includes(oldHash)));
  });

  it('dòng đã đúng giá trị băm hoặc không còn raw_ip → không ghi gì', async () => {
    const queries = [];
    const pool = {
      query: async (sql, params = []) => {
        queries.push({ sql, params });
        if (/^SELECT \* FROM "aiops_ip_quarantine" ORDER/.test(sql.trim())) {
          return { rows: [
            { id: 'q1', ip_hash: hashIp('198.51.100.7'), masked_ip: '198.51.xxx.xxx', raw_ip: encrypt('198.51.100.7') },
            { id: 'q2', ip_hash: 'oldhash-no-raw', masked_ip: '198.51.xxx.xxx', raw_ip: null },
          ] };
        }
        return { rows: [], rowCount: 0 };
      },
    };
    const repo = new AIOpsQuarantineRepository({ pool });
    repo.autoExpireInDatabase = async () => ({ expiredIps: [], expiredAccounts: [] });
    const loaded = await repo.loadActiveQuarantines();
    assert.strictEqual(loaded.ips[1].ip_hash, 'oldhash-no-raw');
    assert.ok(!queries.some((q) => /^UPDATE/.test(q.sql.trim())));
  });
});

describe('Tầng 2: xem IP đầy đủ của nguồn bị chặn phải qua PIN', () => {
  const origVerify = adminService.verifySecurityAction;
  afterEach(() => { adminService.verifySecurityAction = origVerify; });

  const withQuarantine = async (fn) => {
    const { defaultAIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
    const origRepo = defaultAIOpsQuarantine.repository;
    defaultAIOpsQuarantine.repository = {
      getIpByHash: async (h) => (h === 'db-only' ? { ip_hash: 'db-only', raw_ip: '198.51.100.20' } : null),
    };
    try { await fn(defaultAIOpsQuarantine); } finally { defaultAIOpsQuarantine.repository = origRepo; }
  };

  it('PIN sai: trả lỗi, không lộ IP; nhật ký vẫn ghi đúng tên hành động', async () => {
    adminService.verifySecurityAction = async () => { const e = new Error('Mã PIN sai'); e.statusCode = 400; throw e; };
    await withQuarantine(async () => {
      const req = { params: { hash: 'db-only' }, body: { pin: '000000' }, user: { idaccount: 102 } };
      const res = fakeRes();
      await aiopsController.revealQuarantineIp(req, res);
      assert.strictEqual(res.statusCode, 400);
      assert.ok(!JSON.stringify(res.body).includes('198.51.100.20'));
      assert.ok(req.auditActionName.startsWith('Xem IP đầy đủ'));
    });
  });

  it('PIN đúng: kiểm với hành động REVEAL_IP, trả IP (từ bộ nhớ hoặc CSDL); nhật ký không chứa IP', async () => {
    let verifyArgs;
    adminService.verifySecurityAction = async (body, user) => { verifyArgs = { body, user }; return { verified: true }; };
    await withQuarantine(async (q) => {
      q.quarantineActor({ rawIp: '203.0.113.77', reason: 'thử', durationMs: 60000 });
      const memHash = hashIp('203.0.113.77');
      const req = { params: { hash: memHash }, body: { pin: '246810' }, user: { idaccount: 102 } };
      const res = fakeRes();
      await aiopsController.revealQuarantineIp(req, res);
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.body.data.ip, '203.0.113.77');
      assert.strictEqual(verifyArgs.body.action, 'REVEAL_IP');
      assert.strictEqual(verifyArgs.user.idaccount, 102);
      assert.ok(!req.auditActionName.includes('203.0'));
      q.unblock(memHash);

      const res2 = fakeRes();
      await aiopsController.revealQuarantineIp({ params: { hash: 'db-only' }, body: { pin: '246810' }, user: { idaccount: 102 } }, res2);
      assert.strictEqual(res2.body.data.ip, '198.51.100.20');
    });
  });

  it('không có IP đầy đủ (đã dọn theo hạn): 404', async () => {
    adminService.verifySecurityAction = async () => ({ verified: true });
    await withQuarantine(async () => {
      const res = fakeRes();
      await aiopsController.revealQuarantineIp({ params: { hash: 'khong-co' }, body: { pin: '246810' }, user: { idaccount: 102 } }, res);
      assert.strictEqual(res.statusCode, 404);
    });
  });

  it('route POST /aiops/quarantine/:hash/reveal-ip đã gắn', () => {
    const src = require('fs').readFileSync(require.resolve('../../api/admin.routes'), 'utf8');
    assert.match(src, /router\.post\('\/aiops\/quarantine\/:hash\/reveal-ip', aiopsController\.revealQuarantineIp\)/);
  });
});
