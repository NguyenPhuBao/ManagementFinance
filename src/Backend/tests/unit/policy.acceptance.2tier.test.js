/**
 * Chính sách: nhiều chính sách song song, phiên bản theo từng chính sách, trạng thái ACTIVE / INACTIVE (migration 54),
 * bằng chứng người dùng đồng ý (migration 49). CSDL giả trong bộ nhớ; ràng buộc CSDL thật kiểm ở test integration.
 */
const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const { prisma } = require('../../config/db');
const { hashBlindIndex } = require('../../utils/crypto.util');
const socket = require('../../core/socket');
const adminService = require('../../modules/admin/admin.service');
const policyController = require('../../modules/policy/policy.controller');
const adminController = require('../../modules/admin/admin.controller');

const fakeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  res.set = () => res;
  return res;
};

// ── CSDL giả: lọc theo bằng / { in } / { not }, sắp theo orderBy (đối tượng hoặc mảng) ──
const match = (row, where = {}) =>
  Object.entries(where).every(([k, v]) => {
    if (v && typeof v === 'object' && !(v instanceof Date)) {
      if ('in' in v) return v.in.includes(row[k]);
      if ('not' in v) return row[k] !== v.not;
    }
    return row[k] === v;
  });
const sortBy = (rows, orderBy) => {
  const keys = (Array.isArray(orderBy) ? orderBy : orderBy ? [orderBy] : []).flatMap((o) => Object.entries(o));
  return [...rows].sort((a, b) => {
    for (const [k, dir] of keys) {
      if (a[k] === b[k]) continue;
      const c = a[k] > b[k] ? 1 : -1;
      return dir === 'desc' ? -c : c;
    }
    return 0;
  });
};

let docs;
let policies;
let acceptances;
let emitted;
const orig = {};

const withRel = (p, include) => {
  if (!p) return p;
  const r = { ...p };
  if (include?.document) r.document = docs.find((d) => d.id === p.document_id) || null;
  if (include?._count) r._count = { acceptances: acceptances.filter((a) => a.policy_version === p.version).length };
  return r;
};

beforeEach(() => {
  docs = [];
  policies = [];
  acceptances = [];
  emitted = [];
  const P = prisma.privacy_policy;
  const D = prisma.policy_document;
  const A = prisma.policy_acceptance;
  orig.p = { findFirst: P.findFirst, findMany: P.findMany, findUnique: P.findUnique, create: P.create, update: P.update };
  orig.d = { findUnique: D.findUnique, findMany: D.findMany, create: D.create };
  orig.a = { findFirst: A.findFirst, findUnique: A.findUnique, findMany: A.findMany, create: A.create };
  orig.count = prisma.account.count;
  orig.verify = adminService.verifySecurityAction;
  orig.resolve = adminService.resolveAccountId;

  P.findFirst = async ({ where, orderBy, include } = {}) => withRel(sortBy(policies.filter((p) => match(p, where)), orderBy)[0] || null, include);
  P.findMany = async ({ where, orderBy, include } = {}) => sortBy(policies.filter((p) => match(p, where)), orderBy).map((p) => withRel(p, include));
  P.findUnique = async ({ where, include }) => withRel(policies.find((p) => p.version === where.version) || null, include);
  P.create = async ({ data, include }) => {
    if (policies.some((p) => p.version === data.version)) throw Object.assign(new Error('dup'), { code: 'P2002' });
    const r = { published_at: new Date(), status_changed_at: null, status_changed_by: null, ...data };
    policies.push(r);
    return withRel(r, include);
  };
  P.update = async ({ where, data, include }) => {
    const r = policies.find((p) => p.version === where.version);
    // Giống index uq_privacy_policy_one_active
    if (data.status === 'ACTIVE' && policies.some((p) => p !== r && p.document_id === r.document_id && p.status === 'ACTIVE')) {
      throw Object.assign(new Error('unique'), { code: 'P2002' });
    }
    Object.assign(r, data);
    return withRel(r, include);
  };
  D.findUnique = async ({ where }) => docs.find((d) => (where.id !== undefined ? d.id === where.id : d.title === where.title)) || null;
  D.findMany = async ({ orderBy } = {}) => sortBy(docs, orderBy);
  D.create = async ({ data }) => { const r = { id: docs.length + 1, created_at: new Date(), ...data }; docs.push(r); return r; };
  A.findFirst = async ({ where, orderBy }) => sortBy(acceptances.filter((a) => match(a, where)), orderBy)[0] || null;
  A.findUnique = async ({ where }) => {
    const k = where.idaccount_policy_version;
    return acceptances.find((a) => a.idaccount === k.idaccount && a.policy_version === k.policy_version) || null;
  };
  A.findMany = async ({ where, orderBy, include }) =>
    sortBy(acceptances.filter((a) => match(a, where)), orderBy).map((a) =>
      include?.policy ? { ...a, policy: withRel(policies.find((p) => p.version === a.policy_version), include.policy.include) } : a
    );
  A.create = async ({ data }) => { const r = { id: BigInt(acceptances.length + 1), accepted_at: new Date(), ...data }; acceptances.push(r); return r; };
  prisma.account.count = async () => 4;
  socket._setMockIO({ emit: (event, data) => emitted.push({ event, data }), to: () => ({ emit: () => {} }) });
  adminService.resolveAccountId = async (iduser) => (iduser === 1 ? 7 : null);
});

afterEach(() => {
  Object.assign(prisma.privacy_policy, orig.p);
  Object.assign(prisma.policy_document, orig.d);
  Object.assign(prisma.policy_acceptance, orig.a);
  prisma.account.count = orig.count;
  adminService.verifySecurityAction = orig.verify;
  adminService.resolveAccountId = orig.resolve;
  socket._setMockIO(null);
});

/** Thêm một phiên bản: mã nội bộ `version` tăng chung, `doc_version` tăng theo chính sách. */
const seed = (title, status = 'ACTIVE') => {
  let doc = docs.find((d) => d.title === title);
  if (!doc) { doc = { id: docs.length + 1, title, created_at: new Date() }; docs.push(doc); }
  const docVersion = policies.filter((p) => p.document_id === doc.id).length + 1;
  const row = {
    version: policies.length + 1, document_id: doc.id, doc_version: docVersion, title, content: `Nội dung ${title} v${docVersion}`,
    status, published_at: new Date(), published_by: 102, status_changed_at: null, status_changed_by: null,
  };
  policies.push(row);
  return row;
};

describe('Tầng 1: trạng thái chính sách của người dùng', () => {
  it('chưa có chính sách đang sử dụng: không bắt đồng ý', async () => {
    seed('Điều khoản', 'INACTIVE');
    const res = fakeRes();
    await policyController.current({ user: { idaccount: 7 } }, res);
    assert.strictEqual(res.statusCode, 200);
    const d = res.body.data;
    assert.deepStrictEqual({ policy: d.policy, policies: d.policies, mustAccept: d.mustAccept }, { policy: null, policies: [], mustAccept: false });
  });

  it('nhiều chính sách đang dùng: trả đủ danh sách, mustAccept khi còn chính sách chưa đồng ý; policy (cũ) là chính sách chưa đồng ý', async () => {
    const a = seed('Chính sách người dùng');
    const b = seed('Thu thập dữ liệu');
    seed('Đã ngừng', 'INACTIVE');
    acceptances.push({ idaccount: 7, policy_version: a.version, accepted_at: new Date() });
    const res = fakeRes();
    await policyController.current({ user: { idaccount: 7 } }, res);
    const d = res.body.data;
    assert.deepStrictEqual(d.policies.map((p) => [p.title, p.docVersion, p.accepted]), [['Chính sách người dùng', 1, true], ['Thu thập dữ liệu', 1, false]]);
    assert.strictEqual(d.mustAccept, true);
    assert.strictEqual(d.policy.version, b.version);
    assert.strictEqual(d.policy.content, 'Nội dung Thu thập dữ liệu v1');
    acceptances.push({ idaccount: 7, policy_version: b.version, accepted_at: new Date() });
    const res2 = fakeRes();
    await policyController.current({ user: { idaccount: 7 } }, res2);
    assert.strictEqual(res2.body.data.mustAccept, false);
  });
});

describe('Tầng 2: ghi bằng chứng đồng ý', () => {
  const req = (version, extra = {}) => ({
    user: { idaccount: 7 },
    body: { version, idaccount: 999, ...extra },
    ip: '113.161.45.12',
    headers: { 'x-device-name': 'Pixel 8', 'user-agent': 'FlowMoney/1.0', 'x-forwarded-for': '1.2.3.4' },
  });

  it('đồng ý một chính sách đang dùng: lưu idaccount từ JWT, chỉ mục mù IP thật, thiết bị; không lưu IP', async () => {
    seed('A');
    const b = seed('B');
    const res = fakeRes();
    await policyController.accept(req(b.version), res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(acceptances.length, 1);
    const a = acceptances[0];
    assert.strictEqual(a.idaccount, 7);
    assert.strictEqual(a.policy_version, b.version);
    assert.strictEqual(a.ip_hash, hashBlindIndex('113.161.45.12'));
    assert.strictEqual(a.device_name, 'Pixel 8');
    assert.ok(!JSON.stringify(a, (k, v) => (typeof v === 'bigint' ? String(v) : v)).includes('113.161'));
  });

  it('đồng ý bản đã ngừng sử dụng: 409 POLICY_VERSION_OUTDATED, không ghi', async () => {
    const old = seed('A', 'INACTIVE');
    seed('A');
    const res = fakeRes();
    await policyController.accept(req(old.version), res);
    assert.strictEqual(res.statusCode, 409);
    assert.strictEqual(res.body.code, 'POLICY_VERSION_OUTDATED');
    assert.strictEqual(acceptances.length, 0);
  });

  it('đồng ý lại cùng phiên bản: 200, không ghi thêm dòng', async () => {
    const a = seed('A');
    await policyController.accept(req(a.version), fakeRes());
    const res = fakeRes();
    await policyController.accept(req(a.version), res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(acceptances.length, 1);
  });

  it('không có chính sách nào đang dùng hoặc thiếu phiên bản: 404 / 400', async () => {
    const r1 = fakeRes();
    await policyController.accept(req(1), r1);
    assert.strictEqual(r1.statusCode, 404);
    seed('A');
    const r2 = fakeRes();
    await policyController.accept(req(undefined), r2);
    assert.strictEqual(r2.statusCode, 400);
  });
});

describe('Tầng 2: admin thêm chính sách', () => {
  const pub = (body) => ({ user: { idaccount: 102 }, body });
  const okPin = () => {
    const calls = [];
    adminService.verifySecurityAction = async (body) => { calls.push(body); return { verified: true }; };
    return calls;
  };

  it('PIN sai: 400, không tạo gì, không phát sự kiện', async () => {
    adminService.verifySecurityAction = async () => { const e = new Error('Mã PIN sai'); e.statusCode = 400; throw e; };
    const res = fakeRes();
    await adminController.publishPolicy(pub({ title: 'Chính sách', content: 'Nội dung', pin: '000000' }), res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(policies.length, 0);
    assert.strictEqual(docs.length, 0);
    assert.strictEqual(emitted.length, 0);
  });

  it('tiêu đề mới: tạo chính sách mới ở v1, trạng thái Ngừng sử dụng; không phát sự kiện tới app', async () => {
    const calls = okPin();
    seed('Có sẵn');
    const req = pub({ title: '  Chính sách mới  ', content: 'Nội dung mới', pin: '246810' });
    const res = fakeRes();
    await adminController.publishPolicy(req, res);
    assert.strictEqual(res.statusCode, 201);
    const created = policies.find((p) => p.title === 'Chính sách mới');
    assert.ok(created);
    assert.strictEqual(created.doc_version, 1);
    assert.strictEqual(created.status, 'INACTIVE');
    assert.strictEqual(created.version, 2, 'mã nội bộ vẫn tăng chung');
    assert.strictEqual(created.published_by, 102);
    assert.strictEqual(calls[0].action, 'PUBLISH_POLICY');
    assert.strictEqual(calls[0].pin, '246810');
    assert.deepStrictEqual(res.body.data.docVersion, 1);
    assert.strictEqual(emitted.length, 0);
    assert.match(req.auditActionName, /Chính sách mới.*v1/);
  });

  it('chọn chính sách có sẵn: tạo phiên bản kế tiếp CỦA CHÍNH SÁCH ĐÓ ở trạng thái Ngừng; bản đang dùng không đổi', async () => {
    okPin();
    const a1 = seed('A');
    seed('B');
    seed('B', 'INACTIVE');
    const res = fakeRes();
    await adminController.publishPolicy(pub({ documentId: a1.document_id, content: 'A bản 2', pin: '246810' }), res);
    assert.strictEqual(res.statusCode, 201);
    const a2 = policies.find((p) => p.content === 'A bản 2');
    assert.strictEqual(a2.doc_version, 2, 'phiên bản tăng theo chính sách A, không theo tổng số bản');
    assert.strictEqual(a2.title, 'A');
    assert.strictEqual(a2.status, 'INACTIVE');
    assert.strictEqual(a1.status, 'ACTIVE');
  });

  it('tiêu đề trùng chính sách có sẵn: 409 POLICY_TITLE_EXISTS; chính sách không tồn tại: 404', async () => {
    okPin();
    seed('A');
    const res = fakeRes();
    await adminController.publishPolicy(pub({ title: 'A', content: 'x', pin: '246810' }), res);
    assert.strictEqual(res.statusCode, 409);
    assert.strictEqual(res.body.code, 'POLICY_TITLE_EXISTS');
    const r404 = fakeRes();
    await adminController.publishPolicy(pub({ documentId: 99, content: 'x', pin: '246810' }), r404);
    assert.strictEqual(r404.statusCode, 404);
    assert.strictEqual(policies.length, 1);
  });

  it('tiêu đề (khi tạo mới) hoặc nội dung rỗng: 400 trước khi kiểm PIN', async () => {
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

describe('Tầng 2: admin ngừng / kích hoạt chính sách (PIN)', () => {
  const act = (version, body) => ({ user: { idaccount: 102 }, params: { id: String(version) }, body });

  it('ngừng bản đang dùng: kiểm PIN, chuyển INACTIVE, ghi người đổi, phát system.policy_updated, ghi nhật ký', async () => {
    const calls = [];
    adminService.verifySecurityAction = async (body) => { calls.push(body); return {}; };
    const a = seed('A');
    const req = act(a.version, { status: 'INACTIVE', pin: '246810' });
    const res = fakeRes();
    await adminController.setPolicyStatus(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(a.status, 'INACTIVE');
    assert.strictEqual(a.status_changed_by, 102);
    assert.ok(a.status_changed_at instanceof Date);
    assert.strictEqual(calls[0].action, 'CHANGE_POLICY_STATUS');
    assert.strictEqual(calls[0].pin, '246810');
    assert.deepStrictEqual(emitted.map((e) => [e.event, e.data.version, e.data.status]), [['system.policy_updated', a.version, 'INACTIVE']]);
    assert.match(req.auditActionName, /Ngừng chính sách "A" v1/);
  });

  it('kích hoạt khi chính sách đó đang có bản khác đang dùng: 409 POLICY_ALREADY_ACTIVE, không đổi gì', async () => {
    adminService.verifySecurityAction = async () => ({});
    const a1 = seed('A');
    const a2 = seed('A', 'INACTIVE');
    const res = fakeRes();
    await adminController.setPolicyStatus(act(a2.version, { status: 'ACTIVE', pin: '246810' }), res);
    assert.strictEqual(res.statusCode, 409);
    assert.strictEqual(res.body.code, 'POLICY_ALREADY_ACTIVE');
    assert.match(res.body.message, /v1/);
    assert.strictEqual(a1.status, 'ACTIVE');
    assert.strictEqual(a2.status, 'INACTIVE');
    assert.strictEqual(emitted.length, 0);
  });

  it('kích hoạt khi chính sách đó không có bản nào đang dùng: ACTIVE; chính sách khác không ảnh hưởng', async () => {
    adminService.verifySecurityAction = async () => ({});
    const a1 = seed('A', 'INACTIVE');
    const b1 = seed('B');
    const res = fakeRes();
    await adminController.setPolicyStatus(act(a1.version, { status: 'ACTIVE', pin: '246810' }), res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(a1.status, 'ACTIVE');
    assert.strictEqual(b1.status, 'ACTIVE');
  });

  it('PIN sai: 400, không đổi; trạng thái lạ: 400 trước khi kiểm PIN; không có bản: 404', async () => {
    const a = seed('A');
    adminService.verifySecurityAction = async () => { const e = new Error('Mã PIN sai'); e.statusCode = 400; throw e; };
    const r1 = fakeRes();
    await adminController.setPolicyStatus(act(a.version, { status: 'INACTIVE', pin: '0' }), r1);
    assert.strictEqual(r1.statusCode, 400);
    assert.strictEqual(a.status, 'ACTIVE');
    let verified = false;
    adminService.verifySecurityAction = async () => { verified = true; return {}; };
    const r2 = fakeRes();
    await adminController.setPolicyStatus(act(a.version, { status: 'DELETED', pin: '246810' }), r2);
    assert.strictEqual(r2.statusCode, 400);
    assert.strictEqual(verified, false);
    const r3 = fakeRes();
    await adminController.setPolicyStatus(act(99, { status: 'INACTIVE', pin: '246810' }), r3);
    assert.strictEqual(r3.statusCode, 404);
  });
});

describe('Tầng 2: admin xem danh sách và lịch sử đồng ý', () => {
  it('danh sách: tên chính sách, phiên bản trong chính sách, trạng thái, nội dung, số người đồng ý; kèm danh sách chính sách để chọn', async () => {
    const a1 = seed('A', 'INACTIVE');
    const a2 = seed('A');
    const b1 = seed('B');
    acceptances.push({ idaccount: 7, policy_version: a1.version }, { idaccount: 8, policy_version: a2.version }, { idaccount: 9, policy_version: b1.version }, { idaccount: 10, policy_version: b1.version });
    const res = fakeRes();
    await adminController.getPolicies({}, res);
    const d = res.body.data;
    assert.deepStrictEqual(
      d.policies.map((p) => [p.title, p.docVersion, p.status, p.acceptedCount]),
      [['A', 2, 'ACTIVE', 1], ['A', 1, 'INACTIVE', 1], ['B', 1, 'ACTIVE', 2]]
    );
    assert.strictEqual(d.policies[0].content, 'Nội dung A v2');
    assert.deepStrictEqual(d.documents.map((x) => x.title), ['A', 'B']);
    assert.strictEqual(d.activeUsers, 4);
  });

  it('lịch sử đồng ý theo người dùng: có tên chính sách và phiên bản; không có người dùng thì 404', async () => {
    const a1 = seed('A', 'INACTIVE');
    const a2 = seed('A');
    acceptances.push({ idaccount: 7, policy_version: a1.version, accepted_at: new Date('2026-11-01') }, { idaccount: 7, policy_version: a2.version, accepted_at: new Date('2026-11-10') });
    const res = fakeRes();
    await adminController.getUserPolicy({ params: { id: '1' } }, res);
    assert.strictEqual(res.statusCode, 200);
    assert.deepStrictEqual(res.body.data.acceptances.map((a) => [a.title, a.doc_version]), [['A', 2], ['A', 1]]);
    assert.deepStrictEqual(res.body.data.activePolicies.map((p) => [p.title, p.docVersion]), [['A', 2]]);
    const r404 = fakeRes();
    await adminController.getUserPolicy({ params: { id: '99' } }, r404);
    assert.strictEqual(r404.statusCode, 404);
  });
});

describe('Tầng 1: route', () => {
  const paths = (router) => router.stack.filter((l) => l.route).map((l) => `${Object.keys(l.route.methods)[0].toUpperCase()} ${l.route.path}`);

  it('/api/policy có xác thực; admin có route thêm, đổi trạng thái, xem danh sách và lịch sử theo người dùng', () => {
    const policyRoutes = require('../../api/policy.routes');
    assert.deepStrictEqual(paths(policyRoutes).sort(), ['GET /current', 'POST /accept']);
    assert.ok(policyRoutes.stack.some((l) => !l.route && l.handle && l.handle.name === 'authenticate'));
    const admin = paths(require('../../api/admin.routes'));
    ['GET /policies', 'POST /policies', 'PATCH /policies/:id/status', 'GET /getuser/:id/policy'].forEach((p) => assert.ok(admin.includes(p), p));
    const src = require('fs').readFileSync(require.resolve('../../api/index'), 'utf8');
    assert.match(src, /router\.use\('\/policy', require\('\.\/policy\.routes'\)\)/);
  });
});
