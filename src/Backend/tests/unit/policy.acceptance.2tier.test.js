const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const { prisma } = require('../../config/db');
const { hashBlindIndex } = require('../../utils/crypto.util');
const socket = require('../../core/socket');
const adminService = require('../../modules/admin/admin.service');
const policyService = require('../../modules/policy/policy.service');
const policyController = require('../../modules/policy/policy.controller');
const adminController = require('../../modules/admin/admin.controller');

const fakeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  res.set = () => res;
  return res;
};

let policies;
let acceptances;
let emitted;
const orig = {};

beforeEach(() => {
  policies = [];
  acceptances = [];
  emitted = [];
  const P = prisma.privacy_policy;
  const A = prisma.policy_acceptance;
  orig.p = { findFirst: P.findFirst, findMany: P.findMany, create: P.create };
  orig.a = { findFirst: A.findFirst, findUnique: A.findUnique, findMany: A.findMany, create: A.create };
  orig.count = prisma.account.count;
  orig.verify = adminService.verifySecurityAction;
  orig.resolve = adminService.resolveAccountId;

  const latest = () => [...policies].sort((x, y) => y.version - x.version)[0] || null;
  P.findFirst = async () => latest();
  P.findMany = async () => [...policies].sort((x, y) => y.version - x.version).map((p) => ({
    ...p,
    _count: { acceptances: acceptances.filter((a) => a.policy_version === p.version).length },
  }));
  P.create = async ({ data }) => { const r = { published_at: new Date(), ...data }; policies.push(r); return r; };
  A.findFirst = async ({ where }) =>
    [...acceptances].filter((a) => a.idaccount === where.idaccount).sort((x, y) => y.policy_version - x.policy_version)[0] || null;
  A.findUnique = async ({ where }) => {
    const k = where.idaccount_policy_version;
    return acceptances.find((a) => a.idaccount === k.idaccount && a.policy_version === k.policy_version) || null;
  };
  A.findMany = async ({ where }) =>
    acceptances.filter((a) => a.idaccount === where.idaccount).sort((x, y) => y.policy_version - x.policy_version);
  A.create = async ({ data }) => { const r = { id: BigInt(acceptances.length + 1), accepted_at: new Date(), ...data }; acceptances.push(r); return r; };
  prisma.account.count = async () => 4;
  socket._setMockIO({ emit: (event, data) => emitted.push({ event, data }), to: () => ({ emit: () => {} }) });
  adminService.resolveAccountId = async (iduser) => (iduser === 1 ? 7 : null);
});

afterEach(() => {
  Object.assign(prisma.privacy_policy, orig.p);
  Object.assign(prisma.policy_acceptance, orig.a);
  prisma.account.count = orig.count;
  adminService.verifySecurityAction = orig.verify;
  adminService.resolveAccountId = orig.resolve;
  socket._setMockIO(null);
});

const seed = (version) => policies.push({ version, title: `Chính sách v${version}`, content: `Nội dung ${version}`, published_at: new Date(), published_by: 102 });

describe('Tầng 1: trạng thái chính sách của người dùng', () => {
  it('chưa có chính sách nào: không bắt đồng ý', async () => {
    const res = fakeRes();
    await policyController.current({ user: { idaccount: 7 } }, res);
    assert.strictEqual(res.statusCode, 200);
    assert.deepStrictEqual(
      { policy: res.body.data.policy, acceptedVersion: res.body.data.acceptedVersion, mustAccept: res.body.data.mustAccept },
      { policy: null, acceptedVersion: null, mustAccept: false }
    );
  });

  it('đã đồng ý v1, hiện hành v2: trả nội dung v2 và mustAccept', async () => {
    seed(1); seed(2);
    acceptances.push({ idaccount: 7, policy_version: 1, accepted_at: new Date() });
    const res = fakeRes();
    await policyController.current({ user: { idaccount: 7 } }, res);
    const d = res.body.data;
    assert.strictEqual(d.policy.version, 2);
    assert.strictEqual(d.policy.content, 'Nội dung 2');
    assert.strictEqual(d.acceptedVersion, 1);
    assert.strictEqual(d.mustAccept, true);
  });
});

describe('Tầng 2: ghi bằng chứng đồng ý', () => {
  const req = (version, extra = {}) => ({
    user: { idaccount: 7 },
    body: { version, idaccount: 999, ...extra },
    ip: '113.161.45.12',
    headers: { 'x-device-name': 'Pixel 8', 'user-agent': 'FlowMoney/1.0', 'x-forwarded-for': '1.2.3.4' },
  });

  it('đồng ý phiên bản hiện hành: lưu idaccount từ JWT, chỉ mục mù IP thật, thiết bị; không lưu IP', async () => {
    seed(1);
    const res = fakeRes();
    await policyController.accept(req(1), res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(acceptances.length, 1);
    const a = acceptances[0];
    assert.strictEqual(a.idaccount, 7);
    assert.strictEqual(a.policy_version, 1);
    assert.strictEqual(a.ip_hash, hashBlindIndex('113.161.45.12'));
    assert.strictEqual(a.device_name, 'Pixel 8');
    assert.ok(!JSON.stringify(a, (k, v) => (typeof v === 'bigint' ? String(v) : v)).includes('113.161'));
  });

  it('đồng ý phiên bản cũ: 409 POLICY_VERSION_OUTDATED, không ghi', async () => {
    seed(1); seed(2);
    const res = fakeRes();
    await policyController.accept(req(1), res);
    assert.strictEqual(res.statusCode, 409);
    assert.strictEqual(res.body.code, 'POLICY_VERSION_OUTDATED');
    assert.strictEqual(acceptances.length, 0);
  });

  it('đồng ý lại cùng phiên bản: 200, không ghi thêm dòng', async () => {
    seed(1);
    await policyController.accept(req(1), fakeRes());
    const res = fakeRes();
    await policyController.accept(req(1), res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(acceptances.length, 1);
  });

  it('chưa có chính sách hoặc thiếu phiên bản: 404 / 400', async () => {
    const r1 = fakeRes();
    await policyController.accept(req(1), r1);
    assert.strictEqual(r1.statusCode, 404);
    seed(1);
    const r2 = fakeRes();
    await policyController.accept(req(undefined), r2);
    assert.strictEqual(r2.statusCode, 400);
  });
});

describe('Tầng 2: admin đăng phiên bản mới', () => {
  const pub = (body) => ({ user: { idaccount: 102 }, body });

  it('PIN sai: 400, không tạo phiên bản, không phát sự kiện', async () => {
    adminService.verifySecurityAction = async () => { const e = new Error('Mã PIN sai'); e.statusCode = 400; throw e; };
    const res = fakeRes();
    await adminController.publishPolicy(pub({ title: 'Chính sách', content: 'Nội dung', pin: '000000' }), res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(policies.length, 0);
    assert.strictEqual(emitted.length, 0);
  });

  it('PIN đúng: phiên bản = lớn nhất + 1, ghi người đăng, phát system.policy_updated tới mọi client, ghi tên hành động nhật ký', async () => {
    let verifyBody;
    adminService.verifySecurityAction = async (body) => { verifyBody = body; return { verified: true }; };
    seed(3);
    const req = pub({ title: '  Chính sách mới  ', content: 'Nội dung mới', pin: '246810' });
    const res = fakeRes();
    await adminController.publishPolicy(req, res);
    assert.strictEqual(res.statusCode, 201);
    const created = policies.find((p) => p.version === 4);
    assert.ok(created);
    assert.strictEqual(created.title, 'Chính sách mới');
    assert.strictEqual(created.published_by, 102);
    assert.strictEqual(verifyBody.action, 'PUBLISH_POLICY');
    assert.strictEqual(verifyBody.pin, '246810');
    assert.deepStrictEqual(emitted.map((e) => [e.event, e.data.version]), [['system.policy_updated', 4]]);
    assert.ok(req.auditActionName.includes('v4'));
  });

  it('tiêu đề hoặc nội dung rỗng: 400 trước khi kiểm PIN', async () => {
    let verified = false;
    adminService.verifySecurityAction = async () => { verified = true; return {}; };
    const res = fakeRes();
    await adminController.publishPolicy(pub({ title: ' ', content: 'x', pin: '246810' }), res);
    assert.strictEqual(res.statusCode, 400);
    const res2 = fakeRes();
    await adminController.publishPolicy(pub({ title: 'A', content: '   ', pin: '246810' }), res2);
    assert.strictEqual(res2.statusCode, 400);
    assert.strictEqual(verified, false);
  });
});

describe('Tầng 2: admin xem phiên bản và lịch sử đồng ý', () => {
  it('danh sách phiên bản mới nhất trước, kèm số người đã đồng ý và tổng người dùng hoạt động', async () => {
    seed(1); seed(2);
    acceptances.push({ idaccount: 7, policy_version: 1 }, { idaccount: 8, policy_version: 2 }, { idaccount: 9, policy_version: 2 });
    const res = fakeRes();
    await adminController.getPolicies({}, res);
    const d = res.body.data;
    assert.deepStrictEqual(d.policies.map((p) => [p.version, p.acceptedCount]), [[2, 2], [1, 1]]);
    assert.strictEqual(d.activeUsers, 4);
  });

  it('lịch sử đồng ý theo người dùng: đổi iduser sang idaccount; không có người dùng thì 404', async () => {
    seed(1); seed(2);
    acceptances.push({ idaccount: 7, policy_version: 1, accepted_at: new Date('2026-11-01') }, { idaccount: 7, policy_version: 2, accepted_at: new Date('2026-11-10') });
    const res = fakeRes();
    await adminController.getUserPolicy({ params: { id: '1' } }, res);
    assert.strictEqual(res.statusCode, 200);
    assert.deepStrictEqual(res.body.data.acceptances.map((a) => a.policy_version), [2, 1]);
    assert.strictEqual(res.body.data.currentVersion, 2);
    const r404 = fakeRes();
    await adminController.getUserPolicy({ params: { id: '99' } }, r404);
    assert.strictEqual(r404.statusCode, 404);
  });
});

describe('Tầng 1: route', () => {
  const paths = (router) => router.stack.filter((l) => l.route).map((l) => `${Object.keys(l.route.methods)[0].toUpperCase()} ${l.route.path}`);

  it('/api/policy có xác thực; admin có route đăng, xem phiên bản và lịch sử theo người dùng', () => {
    const policyRoutes = require('../../api/policy.routes');
    assert.deepStrictEqual(paths(policyRoutes).sort(), ['GET /current', 'POST /accept']);
    assert.ok(policyRoutes.stack.some((l) => !l.route && l.handle && l.handle.name === 'authenticate'));
    const admin = paths(require('../../api/admin.routes'));
    ['GET /policies', 'POST /policies', 'GET /getuser/:id/policy'].forEach((p) => assert.ok(admin.includes(p), p));
    const src = require('fs').readFileSync(require.resolve('../../api/index'), 'utf8');
    assert.match(src, /router\.use\('\/policy', require\('\.\/policy\.routes'\)\)/);
  });
});
