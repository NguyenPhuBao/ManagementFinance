const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const { decrypt, isEncrypted, hashBlindIndex } = require('../../utils/crypto.util');
const ipProtection = require('../../utils/ip-protection.util');
const deviceHistory = require('../../modules/auth/device-history.service');
const { prisma } = require('../../config/db');
const { AIOpsQuarantineRepository } = require('../../modules/aiops/aiops.quarantine.repository');
const adminService = require('../../modules/admin/admin.service');
const adminController = require('../../modules/admin/admin.controller');

const fakeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  return res;
};

describe('Tầng 1: bảo vệ IP (che, mã hóa, chỉ mục mù)', () => {
  it('getClientIp lấy req.ip (đã qua trust proxy), bỏ qua x-forwarded-for do client tự gửi', () => {
    const req = { ip: '::ffff:113.161.45.12', headers: { 'x-forwarded-for': '1.2.3.4' } };
    assert.strictEqual(ipProtection.getClientIp(req), '113.161.45.12');
    assert.strictEqual(ipProtection.getClientIp({ headers: {}, socket: { remoteAddress: '14.162.1.2' } }), '14.162.1.2');
    assert.strictEqual(ipProtection.getClientIp({ headers: { 'x-forwarded-for': '9.9.9.9' } }), null);
  });

  it('protectIp trả bản che, bản mã AES-256-GCM giải được, chỉ mục mù ổn định', () => {
    const a = ipProtection.protectIp('113.161.45.12');
    assert.strictEqual(a.masked, '113.161.xx.xx');
    assert.ok(isEncrypted(a.encrypted));
    assert.strictEqual(decrypt(a.encrypted), '113.161.45.12');
    assert.strictEqual(a.hash, hashBlindIndex('113.161.45.12'));
    const b = ipProtection.protectIp('113.161.45.12');
    assert.notStrictEqual(a.encrypted, b.encrypted, 'IV ngẫu nhiên: hai bản mã khác nhau');
    assert.strictEqual(a.hash, b.hash);
    assert.notStrictEqual(a.hash, ipProtection.protectIp('113.161.45.13').hash);
    assert.deepStrictEqual(ipProtection.protectIp(null), { masked: null, encrypted: null, hash: null });
  });

  it('thời hạn giữ IP đọc từ IP_RETENTION_DAYS, mặc định 365 ngày', () => {
    const old = process.env.IP_RETENTION_DAYS;
    delete process.env.IP_RETENTION_DAYS;
    assert.strictEqual(ipProtection.getRetentionDays(), 365);
    process.env.IP_RETENTION_DAYS = '200';
    assert.strictEqual(ipProtection.getRetentionDays(), 200);
    process.env.IP_RETENTION_DAYS = 'abc';
    assert.strictEqual(ipProtection.getRetentionDays(), 365);
    if (old === undefined) delete process.env.IP_RETENTION_DAYS; else process.env.IP_RETENTION_DAYS = old;
  });
});

describe('Tầng 2: lịch sử thiết bị lưu IP mã hóa, xem có kiểm soát, dọn theo hạn', () => {
  let rows;
  let nextId;
  let updateManyArgs;
  const orig = {};

  beforeEach(() => {
    deviceHistory.clearCache();
    rows = [];
    nextId = 1;
    updateManyArgs = null;
    const t = prisma.account_device_history;
    ['findFirst', 'create', 'update', 'findMany', 'updateMany'].forEach((k) => { orig[k] = t[k]; });
    const sorted = (list) => [...list].sort((x, y) => new Date(y.last_active_at) - new Date(x.last_active_at));
    t.findFirst = async ({ where }) =>
      sorted(rows.filter((r) => r.idaccount === where.idaccount && (where.id === undefined || String(r.id) === String(where.id))))[0] || null;
    t.create = async ({ data }) => {
      const r = { ...data, id: BigInt(nextId++) };
      rows.push(r);
      return r;
    };
    t.update = async ({ where, data }) => {
      const r = rows.find((x) => String(x.id) === String(where.id));
      Object.assign(r, data);
      return r;
    };
    t.findMany = async ({ where, take, select }) =>
      sorted(rows.filter((r) => r.idaccount === where.idaccount)).slice(0, take).map((r) => {
        if (!select) return r;
        const out = {};
        Object.keys(select).forEach((k) => { if (select[k]) out[k] = r[k]; });
        return out;
      });
    t.updateMany = async (args) => {
      updateManyArgs = args;
      let count = 0;
      rows.forEach((r) => {
        if (r.ip_encrypted && new Date(r.last_active_at) < args.where.last_active_at.lt) {
          Object.assign(r, args.data);
          count++;
        }
      });
      return { count };
    };
  });

  afterEach(() => {
    Object.keys(orig).forEach((k) => { prisma.account_device_history[k] = orig[k]; });
  });

  it('ghi IP thật dạng mã hóa kèm chỉ mục mù; IP giả trong header không được lưu', async () => {
    const req = { ip: '113.161.45.12', headers: { 'x-device-name': 'Pixel 8', 'x-forwarded-for': '1.2.3.4' } };
    const r = await deviceHistory.trackDeviceAccess(7, req, {}, { skipThrottle: true });
    assert.strictEqual(r.action, 'INSERTED');
    assert.strictEqual(rows[0].ip_address, '113.161.xx.xx');
    assert.strictEqual(decrypt(rows[0].ip_encrypted), '113.161.45.12');
    assert.strictEqual(rows[0].ip_hash, hashBlindIndex('113.161.45.12'));
    assert.ok(!JSON.stringify(rows, (k, v) => (typeof v === 'bigint' ? String(v) : v)).includes('1.2.3.4'));
  });

  it('cùng dải /16 nhưng khác IP đầy đủ thì ghi dòng mới; cùng IP thì chỉ cập nhật', async () => {
    const dev = { 'x-device-name': 'Pixel 8' };
    await deviceHistory.trackDeviceAccess(7, { ip: '113.161.45.12', headers: dev }, {}, { skipThrottle: true });
    const same = await deviceHistory.trackDeviceAccess(7, { ip: '113.161.45.12', headers: dev }, {}, { skipThrottle: true });
    assert.strictEqual(same.action, 'UPDATED');
    const other = await deviceHistory.trackDeviceAccess(7, { ip: '113.161.99.1', headers: dev }, {}, { skipThrottle: true });
    assert.strictEqual(other.action, 'INSERTED');
    assert.strictEqual(rows.length, 2);
  });

  it('bản ghi cũ chưa có chỉ mục mù vẫn được so theo bản che, không sinh dòng rác', async () => {
    rows.push({ id: BigInt(99), idaccount: 7, device_name: 'Pixel 8', ip_address: '113.161.xx.xx', ip_hash: null, ip_encrypted: null, last_active_at: new Date(Date.now() - 1000) });
    const r = await deviceHistory.trackDeviceAccess(7, { ip: '113.161.45.12', headers: { 'x-device-name': 'Pixel 8' } }, {}, { skipThrottle: true });
    assert.strictEqual(r.action, 'UPDATED');
    assert.strictEqual(decrypt(rows[0].ip_encrypted), '113.161.45.12', 'bổ sung bản mã cho dòng cũ');
    assert.strictEqual(rows[0].ip_hash, hashBlindIndex('113.161.45.12'));
  });

  it('danh sách cho admin không chứa bản mã hay chỉ mục mù, chỉ báo có thể xem IP', async () => {
    await deviceHistory.trackDeviceAccess(7, { ip: '113.161.45.12', headers: { 'x-device-name': 'Pixel 8' } }, {}, { skipThrottle: true });
    rows.push({ id: BigInt(50), idaccount: 7, device_name: 'Cũ', ip_address: '14.162.xx.xx', ip_encrypted: null, ip_hash: null, user_agent: null, first_seen_at: new Date(0), last_active_at: new Date(0) });
    const list = await deviceHistory.listDevicesForAdmin(7, 10);
    assert.strictEqual(list.length, 2);
    assert.deepStrictEqual(Object.keys(list[0]).sort(), ['canRevealIp', 'device_name', 'first_seen_at', 'id', 'ip_address', 'last_active_at', 'user_agent']);
    assert.strictEqual(list[0].canRevealIp, true);
    assert.strictEqual(list[1].canRevealIp, false);
    assert.strictEqual(typeof list[0].id, 'string');
    assert.ok(!JSON.stringify(list).includes('enc:'));
  });

  it('revealDeviceIp chỉ giải mã đúng bản ghi của đúng tài khoản; đã dọn thì trả null', async () => {
    await deviceHistory.trackDeviceAccess(7, { ip: '113.161.45.12', headers: { 'x-device-name': 'Pixel 8' } }, {}, { skipThrottle: true });
    const id = String(rows[0].id);
    assert.strictEqual(await deviceHistory.revealDeviceIp(7, id), '113.161.45.12');
    assert.strictEqual(await deviceHistory.revealDeviceIp(8, id), null, 'khác tài khoản');
    rows[0].ip_encrypted = null;
    assert.strictEqual(await deviceHistory.revealDeviceIp(7, id), null);
  });

  it('purgeExpiredIpData xóa bản mã và chỉ mục mù quá hạn, giữ bản che và dòng lịch sử', async () => {
    const old = new Date(Date.now() - 800 * 86400000);
    rows.push({ id: BigInt(1), idaccount: 7, device_name: 'A', ip_address: '113.161.xx.xx', ip_encrypted: 'enc:x', ip_hash: 'h1', last_active_at: old });
    rows.push({ id: BigInt(2), idaccount: 7, device_name: 'B', ip_address: '14.162.xx.xx', ip_encrypted: 'enc:y', ip_hash: 'h2', last_active_at: new Date() });
    const n = await deviceHistory.purgeExpiredIpData(730);
    assert.strictEqual(n, 1);
    assert.deepStrictEqual(updateManyArgs.data, { ip_encrypted: null, ip_hash: null });
    assert.strictEqual(rows[0].ip_encrypted, null);
    assert.strictEqual(rows[0].ip_address, '113.161.xx.xx');
    assert.strictEqual(rows[1].ip_encrypted, 'enc:y');
  });
});

describe('Tầng 2: xem IP thật phải qua PIN trong cùng request', () => {
  const origVerify = adminService.verifySecurityAction;
  const origReveal = deviceHistory.revealDeviceIp;
  const origResolve = adminService.resolveAccountId;
  beforeEach(() => {
    adminService.resolveAccountId = async (iduser) => (iduser === 1 ? 7 : null);
  });
  afterEach(() => {
    adminService.verifySecurityAction = origVerify;
    deviceHistory.revealDeviceIp = origReveal;
    adminService.resolveAccountId = origResolve;
  });

  it('PIN sai: trả 400, không giải mã', async () => {
    let revealed = false;
    adminService.verifySecurityAction = async () => { const e = new Error('Mã PIN sai'); e.statusCode = 400; throw e; };
    deviceHistory.revealDeviceIp = async () => { revealed = true; return '1.1.1.1'; };
    const req = { params: { id: '1', deviceId: '3' }, body: { pin: '000000' }, user: { idaccount: 102 } };
    const res = fakeRes();
    await adminController.revealDeviceIp(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(revealed, false);
    assert.ok(req.auditActionName.startsWith('Xem IP đầy đủ'), 'lượt nhập sai PIN cũng ghi đúng tên hành động');
  });

  it('PIN đúng: kiểm PIN với đúng hành động, trả IP, nhật ký không chứa IP', async () => {
    let verifyArgs;
    adminService.verifySecurityAction = async (body, user) => { verifyArgs = { body, user }; return { verified: true }; };
    deviceHistory.revealDeviceIp = async (idaccount, deviceId) => (idaccount === 7 && deviceId === '3' ? '113.161.45.12' : null);
    const req = { params: { id: '1', deviceId: '3' }, body: { pin: '246810' }, user: { idaccount: 102 } };
    const res = fakeRes();
    await adminController.revealDeviceIp(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.data.ip, '113.161.45.12');
    assert.strictEqual(verifyArgs.body.pin, '246810');
    assert.strictEqual(verifyArgs.body.action, 'REVEAL_IP');
    assert.strictEqual(verifyArgs.user.idaccount, 102);
    assert.ok(req.auditActionName.includes('#1'));
    assert.ok(!req.auditActionName.includes('113.161'));
  });

  it('IP đã dọn theo hạn: trả 404', async () => {
    adminService.verifySecurityAction = async () => ({ verified: true });
    deviceHistory.revealDeviceIp = async () => null;
    const res = fakeRes();
    await adminController.revealDeviceIp({ params: { id: '1', deviceId: '3' }, body: { pin: '246810' }, user: { idaccount: 102 } }, res);
    assert.strictEqual(res.statusCode, 404);
  });

  it('người dùng không tồn tại: 404, không kiểm PIN', async () => {
    let verified = false;
    adminService.verifySecurityAction = async () => { verified = true; return { verified: true }; };
    const res = fakeRes();
    await adminController.revealDeviceIp({ params: { id: '99', deviceId: '3' }, body: { pin: '246810' }, user: { idaccount: 102 } }, res);
    assert.strictEqual(res.statusCode, 404);
    assert.strictEqual(verified, false);
  });

  it('danh sách thiết bị tra theo idaccount của người dùng', async () => {
    const origList = deviceHistory.listDevicesForAdmin;
    let asked;
    deviceHistory.listDevicesForAdmin = async (idaccount, limit) => { asked = { idaccount, limit }; return []; };
    try {
      const res = fakeRes();
      await adminController.getUserDevices({ params: { id: '1' } }, res);
      assert.strictEqual(res.statusCode, 200);
      assert.deepStrictEqual(asked, { idaccount: 7, limit: 10 });
      const res404 = fakeRes();
      await adminController.getUserDevices({ params: { id: '99' } }, res404);
      assert.strictEqual(res404.statusCode, 404);
    } finally {
      deviceHistory.listDevicesForAdmin = origList;
    }
  });
});

describe('Tầng 2: bảng cách ly AIOps không lưu IP thô', () => {
  it('ghi raw_ip dạng mã hóa; đọc ra được giải mã cho bộ lọc chặn', async () => {
    const queries = [];
    const stored = {};
    const pool = {
      query: async (sql, params = []) => {
        queries.push({ sql, params });
        if (/INSERT INTO "aiops_ip_quarantine"/.test(sql)) {
          stored.ip = { ip_hash: params[1], masked_ip: params[2], raw_ip: params[3], status: params[4] };
          return { rows: [stored.ip] };
        }
        if (/SELECT \* FROM "aiops_ip_quarantine" WHERE/.test(sql)) return { rows: stored.ip ? [stored.ip] : [] };
        if (/SELECT \* FROM "aiops_ip_quarantine"/.test(sql)) return { rows: stored.ip ? [stored.ip] : [] };
        return { rows: [], rowCount: 0 };
      },
    };
    const repo = new AIOpsQuarantineRepository({ pool });
    await repo.recordQuarantinePair({ ip: '198.51.100.7', ipHash: 'h-7', maskedIp: '198.51.xxx.xxx', username: 'u7', reason: 'thử' });
    assert.ok(isEncrypted(stored.ip.raw_ip), 'raw_ip phải là bản mã');
    assert.ok(!queries.some((q) => (q.params || []).includes('198.51.100.7')), 'không tham số SQL nào mang IP thô');
    const loaded = await repo.loadActiveQuarantines();
    assert.strictEqual(loaded.ips[0].raw_ip, '198.51.100.7');
    const one = await repo.getIpByHash('h-7');
    assert.strictEqual(one.raw_ip, '198.51.100.7');
  });
});

describe('Tầng 2: job hằng ngày dọn IP đầy đủ quá hạn', () => {
  it('xóa bản mã ở lịch sử thiết bị và raw_ip ở bảng cách ly theo IP_RETENTION_DAYS; job nằm trong chu trình hằng ngày', async () => {
    const scheduler = require('../../core/scheduler.service');
    const t = prisma.account_device_history;
    const q = prisma.aiops_ip_quarantine;
    const orig = { dev: t.updateMany, q: q.updateMany };
    const old = process.env.IP_RETENTION_DAYS;
    process.env.IP_RETENTION_DAYS = '100';
    const calls = {};
    t.updateMany = async (args) => { calls.dev = args; return { count: 3 }; };
    q.updateMany = async (args) => { calls.q = args; return { count: 2 }; };
    try {
      const before = Date.now();
      const result = await scheduler.runDailyIpRetentionPurgeTask();
      assert.deepStrictEqual(result, { devices: 3, quarantine: 2 });
      const cutoff = calls.dev.where.last_active_at.lt.getTime();
      assert.ok(Math.abs(before - 100 * 86400000 - cutoff) < 5000);
      assert.deepStrictEqual(calls.q.data, { raw_ip: null });
      assert.ok(Math.abs(calls.q.where.updated_at.lt.getTime() - cutoff) < 5000);
      assert.deepStrictEqual(calls.q.where.raw_ip, { not: null });
      const src = require('fs').readFileSync(require.resolve('../../core/scheduler.service'), 'utf8');
      assert.match(src.slice(src.indexOf('async function runDailyMaintenanceRoutine')), /runDailyIpRetentionPurgeTask\(\)/);
    } finally {
      t.updateMany = orig.dev;
      q.updateMany = orig.q;
      if (old === undefined) delete process.env.IP_RETENTION_DAYS; else process.env.IP_RETENTION_DAYS = old;
    }
  });
});

describe('Tầng 2: hết 30 ngày chờ xóa thì IP đầy đủ của tài khoản bị xóa', () => {
  it('processFullSoftDelete xóa ip_encrypted, ip_hash của đúng tài khoản trong cùng giao tác, giữ dòng nhật ký (bản che)', async () => {
    const scheduler = require('../../core/scheduler.service');
    const calls = [];
    const tx = new Proxy({}, {
      get: (_, model) => new Proxy({}, {
        get: (__, method) => async (args) => { calls.push({ model, method, args }); return { count: 1 }; },
      }),
    });
    const orig = { find: prisma.account.findUnique, tx: prisma.$transaction };
    prisma.account.findUnique = async () => ({ idaccount: 42, User: null });
    prisma.$transaction = async (fn) => fn(tx);
    try {
      await scheduler.processFullSoftDelete(42);
      const dev = calls.filter((c) => c.model === 'account_device_history');
      assert.strictEqual(dev.length, 1, 'phải có đúng một lệnh trên lịch sử thiết bị');
      assert.strictEqual(dev[0].method, 'updateMany', 'không xóa vật lý dòng nhật ký');
      assert.strictEqual(dev[0].args.where.idaccount, 42);
      assert.deepStrictEqual(dev[0].args.data, { ip_encrypted: null, ip_hash: null });
      assert.ok(!calls.some((c) => c.model === 'policy_acceptance'), 'bằng chứng đồng ý giữ nguyên');
    } finally {
      prisma.account.findUnique = orig.find;
      prisma.$transaction = orig.tx;
    }
  });
});

describe('Tầng 1: không nơi nào tin IP trong header x-forwarded-for do client gửi', () => {
  it('mã Backend (trừ test, node_modules) không đọc header x-forwarded-for; IP lấy qua req.ip (trust proxy)', () => {
    const fs = require('fs');
    const path = require('path');
    const root = path.join(__dirname, '..', '..');
    const hits = [];
    const walk = (dir) => {
      for (const name of fs.readdirSync(dir)) {
        if (['node_modules', 'tests', '.git', 'prisma', 'database', 'scripts', 'logs'].includes(name)) continue;
        const p = path.join(dir, name);
        const st = fs.statSync(p);
        if (st.isDirectory()) walk(p);
        else if (name.endsWith('.js') && /\[['"]x-forwarded-for['"]\]/.test(fs.readFileSync(p, 'utf8'))) hits.push(path.relative(root, p));
      }
    };
    walk(root);
    assert.deepStrictEqual(hits, []);
  });
});

describe('Tầng 2: giới hạn số lần nhập sai PIN quản trị', () => {
  const bcrypt = require('bcryptjs');
  const adminRepository = require('../../modules/admin/admin.repository');
  const origGet = adminRepository.getAccountById;
  const origAudit = prisma.auditlog.create;
  let audits;

  beforeEach(() => {
    audits = [];
    adminService._resetPinAttempts();
    const pin_hash = bcrypt.hashSync('246810', 4);
    adminRepository.getAccountById = async (id) => ({ idaccount: id, pin_hash, password: null });
    prisma.auditlog.create = async ({ data }) => { audits.push(data); return data; };
  });
  afterEach(() => {
    adminRepository.getAccountById = origGet;
    prisma.auditlog.create = origAudit;
    adminService._resetPinAttempts();
  });

  const tryPin = (pin, idaccount = 102) =>
    adminService.verifySecurityAction({ pin, action: 'REVEAL_IP' }, { idaccount }).then(() => 'ok', (e) => e.statusCode);

  it('sai 5 lần trong 15 phút thì khóa: lần 6 trả 429 dù PIN đúng; tài khoản admin khác không bị ảnh hưởng', async () => {
    for (let i = 0; i < 5; i++) assert.strictEqual(await tryPin('000000'), 400);
    assert.strictEqual(await tryPin('246810'), 429);
    assert.strictEqual(await tryPin('246810', 103), 'ok');
    assert.ok(audits.some((a) => a.req_status !== 'Pass' && /khóa|Khóa/.test(a.action)), 'ghi nhật ký khi khóa');
  });

  it('nhập đúng trước khi đủ 5 lần thì xóa bộ đếm', async () => {
    for (let i = 0; i < 4; i++) await tryPin('000000');
    assert.strictEqual(await tryPin('246810'), 'ok');
    for (let i = 0; i < 4; i++) assert.strictEqual(await tryPin('000000'), 400);
    assert.strictEqual(await tryPin('246810'), 'ok');
  });

  it('hết 15 phút khóa thì được thử lại', async () => {
    const realNow = Date.now;
    try {
      for (let i = 0; i < 5; i++) await tryPin('000000');
      assert.strictEqual(await tryPin('246810'), 429);
      const t = realNow();
      Date.now = () => t + 15 * 60 * 1000 + 1000;
      assert.strictEqual(await tryPin('246810'), 'ok');
    } finally {
      Date.now = realNow;
    }
  });
});
