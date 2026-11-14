const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { prisma } = require('../../config/db');
const { encrypt } = require('../../utils/crypto.util');
const storageMod = require('../../core/storage');
const syncRepository = require('../../modules/sync/sync.repository');
const emailService = require('../../core/email.service');
const socket = require('../../core/socket');
const service = require('../../modules/account/data-export.service');
const controller = require('../../modules/account/data-export.controller');

const OWNER = 7;
const OTHER = 8;
const DAY = 24 * 3600 * 1000;

const fakeRes = () => {
  const res = { statusCode: 200, body: null, headers: {}, sent: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  res.set = (k, v) => { if (typeof k === 'object') Object.assign(res.headers, k); else res.headers[k] = v; return res; };
  res.setHeader = res.set;
  res.send = (b) => { res.sent = b; return res; };
  return res;
};

let rows;
let dir;
let mails;
let emits;
let auditQuery;
const saved = [];
const patch = (obj, key, fn) => { saved.push([obj, key, obj[key]]); obj[key] = fn; };

beforeEach(() => {
  rows = [];
  mails = [];
  emits = [];
  dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fm-export-'));
  storageMod.setStorageForTest(storageMod.createStorage({ env: { STORAGE_LOCAL_DIR: dir } }));
  const t = prisma.data_export_request;
  patch(t, 'create', async ({ data }) => { const r = { ...data, requested_at: data.requested_at || new Date() }; rows.push(r); return r; });
  patch(t, 'findFirst', async ({ where }) => {
    const list = rows.filter((r) => (where.idaccount === undefined || r.idaccount === where.idaccount) && (where.id === undefined || r.id === where.id)
      && (!where.status?.not || r.status !== where.status.not)
      && (!where.requested_at?.gte || r.requested_at >= where.requested_at.gte));
    return list.sort((a, b) => b.requested_at - a.requested_at)[0] || null;
  });
  patch(t, 'findMany', async ({ where }) => rows.filter((r) => {
    if (where.idaccount !== undefined && r.idaccount !== where.idaccount) return false;
    if (where.status && r.status !== where.status) return false;
    if (where.expires_at?.lt && !(r.expires_at && r.expires_at < where.expires_at.lt)) return false;
    return true;
  }));
  patch(t, 'update', async ({ where, data }) => { const r = rows.find((x) => x.id === where.id); Object.assign(r, data); return r; });

  patch(prisma.account, 'findUnique', async ({ where }) => (where.idaccount === OWNER ? {
    idaccount: OWNER, email: 'an.nguyen@gmail.com', username: 'an', type: 'Premium', status: 'Active',
    password: '$2a$10$hash-mat-khau', pin_hash: 'pin-hash', create_at: new Date('2026-01-01'), premium_expires_at: null, is_first_login: false,
  } : null));
  patch(prisma.user, 'findUnique', async () => ({ fullname: 'Nguyễn An', email: 'an.nguyen@gmail.com', phone: encrypt('0901234567'), address: encrypt('12 Lê Lợi'), country_code: 'VN' }));
  patch(prisma.account_device_history, 'findMany', async () => [{ id: 1n, device_name: 'Pixel 8', ip_address: '113.161.xx.xx', ip_encrypted: 'enc:bi-mat', ip_hash: 'hash-bi-mat', user_agent: 'okhttp', first_seen_at: new Date(), last_active_at: new Date() }]);
  patch(prisma.policy_acceptance, 'findMany', async () => [{ policy_version: 1, accepted_at: new Date(), ip_hash: 'hash-bi-mat', device_name: 'Pixel 8' }]);
  patch(prisma.household_member, 'findMany', async () => [{ role: 'Owner', joined_at: new Date(), left_at: null, household: { name: 'Nhà An' } }]);
  patch(prisma.payment_order, 'findMany', async () => [{ id: 'o1', order_code: 123n, package_type: 'PREMIUM_1M', amount: '49000', status: 'PAID', created_at: new Date(), checkout_url: 'https://pay', qr_url: 'qr' }]);
  patch(prisma.auditlog, 'findMany', async (args) => { auditQuery = args; return [{ time_req: new Date(), request: 'POST /api/sync/push', action: 'Đồng bộ', req_status: 'Pass', reason: null }]; });
  patch(syncRepository, 'getWalletsByAccount', async () => [{ idwallet: 'w1', name: 'Ví chính', balance: '100000', currency: 'VND' }]);
  patch(syncRepository, 'getTransactionsByAccount', async () => [
    { idtran: 't1', idwallet: 'w1', idcategory: 'c1', amount: '-50000', type: 'Transaction', status: 'Done', note: 'Ăn trưa; bạn bè "vui"', date_transaction: new Date('2026-11-01T05:00:00Z'), deleted_at: null },
  ]);
  patch(syncRepository, 'getBudgetsByAccount', async () => []);
  patch(syncRepository, 'getBillsByAccount', async () => []);
  patch(syncRepository, 'getGoalsByAccount', async () => []);
  patch(syncRepository, 'getCategoriesByAccount', async () => [{ idcategory: 'c1', name_category: 'Ăn uống', classify: 'Chi' }]);
  patch(emailService, 'sendMail', async (m) => { mails.push(m); return { success: true }; });
  patch(socket, 'emitToAccount', (id, ev, data) => emits.push({ id, ev, data }));
});

afterEach(() => {
  while (saved.length) { const [o, k, v] = saved.pop(); o[k] = v; }
  storageMod.setStorageForTest(null);
  fs.rmSync(dir, { recursive: true, force: true });
});

describe('Tầng 1: nội dung bản sao dữ liệu', () => {
  it('JSON có đủ các mục, giải mã hồ sơ, IP bản che; không có mật khẩu, PIN, IP mã hóa, chỉ mục mù, đường dẫn thanh toán', async () => {
    const { json } = await service.buildPackage(OWNER);
    const data = JSON.parse(json);
    for (const k of ['meta', 'account', 'profile', 'wallets', 'transactions', 'budgets', 'bills', 'goals', 'categories', 'households', 'payments', 'devices', 'policyAcceptances', 'serverActivity']) {
      assert.ok(k in data, `thiếu mục ${k}`);
    }
    assert.strictEqual(data.profile.phone, '0901234567');
    assert.strictEqual(data.profile.address, '12 Lê Lợi');
    assert.strictEqual(data.devices[0].ip, '113.161.xx.xx');
    for (const secret of ['hash-mat-khau', 'pin-hash', 'enc:bi-mat', 'hash-bi-mat', 'https://pay', '"password"', '"pin_hash"']) {
      assert.ok(!json.includes(secret), `lộ ${secret}`);
    }
    assert.strictEqual(data.payments[0].order_code, '123');
  });

  it('nhật ký chỉ gồm lượt gọi máy chủ 12 tháng gần nhất; phần giới thiệu nói rõ không thu thập hoạt động trong app', async () => {
    const { json } = await service.buildPackage(OWNER);
    const data = JSON.parse(json);
    const since = auditQuery.where.time_req.gte.getTime();
    assert.ok(Math.abs(Date.now() - 365 * DAY - since) < 60000);
    assert.strictEqual(auditQuery.where.idaccount, OWNER);
    assert.match(data.meta.scope, /máy chủ/);
    assert.match(data.meta.scope, /không thu thập/);
    assert.strictEqual(data.serverActivity[0].request, 'POST /api/sync/push');
  });

  it('CSV giao dịch mở đúng bằng Excel: BOM, sep=;, CRLF, số tiền thô, ghi chú có ; và " được bọc', async () => {
    const { csv } = await service.buildPackage(OWNER);
    assert.ok(csv.startsWith('﻿sep=;\r\n'));
    const lines = csv.slice(1).split('\r\n');
    assert.match(lines[1], /^Ngày;Loại;Số tiền;Ví;Danh mục;Ghi chú;Đã xóa$/);
    assert.ok(lines[2].includes(';-50000;'), 'số tiền thô có dấu');
    assert.ok(lines[2].includes(';Ví chính;Ăn uống;'), 'đổi mã ví / danh mục thành tên');
    assert.ok(lines[2].includes('"Ăn trưa; bạn bè ""vui"""'));
  });
});

describe('Tầng 2: yêu cầu, tạo tệp, gửi email, tải về, dọn tệp', () => {
  it('yêu cầu: tài khoản lấy từ JWT, trả 202 với email đã che; tạo tệp nền, gửi email không kèm đường dẫn, phát sự kiện', async () => {
    const res = fakeRes();
    await controller.request({ user: { idaccount: OWNER }, body: { idaccount: OTHER } }, res);
    assert.strictEqual(res.statusCode, 202);
    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].idaccount, OWNER);
    assert.strictEqual(res.body.data.email, 'an***@gmail.com');
    await service.processRequest(rows[0].id);
    const r = rows[0];
    assert.strictEqual(r.status, 'READY');
    assert.ok(Math.abs(r.expires_at.getTime() - Date.now() - DAY) < 60000);
    assert.match(r.json_ref, new RegExp(`^local://data-exports/${OWNER}/${r.id}\\.json$`));
    assert.match(r.csv_ref, new RegExp(`^local://data-exports/${OWNER}/${r.id}\\.csv$`));
    assert.strictEqual(mails.length, 1);
    assert.strictEqual(mails[0].to, 'an.nguyen@gmail.com');
    assert.ok(!/https?:\/\//.test(mails[0].html), 'email không chứa đường dẫn tải');
    assert.ok(r.email_sent_at);
    assert.deepStrictEqual(emits.map((e) => [e.id, e.ev]), [[OWNER, 'account.data_export_ready']]);
  });

  it('yêu cầu lại trong 24 giờ: 429 kèm Retry-After; yêu cầu lỗi trước đó không chặn', async () => {
    rows.push({ id: 'old', idaccount: OWNER, status: 'READY', requested_at: new Date(Date.now() - 2 * 3600e3) });
    const res = fakeRes();
    await controller.request({ user: { idaccount: OWNER }, body: {} }, res);
    assert.strictEqual(res.statusCode, 429);
    assert.strictEqual(res.body.code, 'DATA_EXPORT_RATE_LIMITED');
    assert.ok(Number(res.headers['Retry-After']) > 20 * 3600);
    rows[0].status = 'FAILED';
    const res2 = fakeRes();
    await controller.request({ user: { idaccount: OWNER }, body: {} }, res2);
    assert.strictEqual(res2.statusCode, 202);
  });

  it('tải về: chỉ chủ tài khoản; JSON và CSV đúng nội dung; hết hạn trả 410', async () => {
    const res = fakeRes();
    await controller.request({ user: { idaccount: OWNER }, body: {} }, res);
    const id = rows[0].id;
    await service.processRequest(id);

    const json = fakeRes();
    await controller.download({ user: { idaccount: OWNER }, params: { id }, query: { format: 'json' } }, json);
    assert.strictEqual(json.statusCode, 200);
    assert.match(json.headers['Content-Disposition'], /attachment; filename="flowmoney-du-lieu-ca-nhan-\d{8}\.json"/);
    assert.strictEqual(JSON.parse(json.sent.toString('utf8')).profile.fullname, 'Nguyễn An');
    const csv = fakeRes();
    await controller.download({ user: { idaccount: OWNER }, params: { id }, query: { format: 'csv' } }, csv);
    assert.match(csv.headers['Content-Type'], /text\/csv/);

    const other = fakeRes();
    await controller.download({ user: { idaccount: OTHER }, params: { id }, query: { format: 'json' } }, other);
    assert.strictEqual(other.statusCode, 404);

    rows[0].expires_at = new Date(Date.now() - 1000);
    const late = fakeRes();
    await controller.download({ user: { idaccount: OWNER }, params: { id }, query: { format: 'json' } }, late);
    assert.strictEqual(late.statusCode, 410);
  });

  it('trạng thái mới nhất: trả đúng yêu cầu của chính tài khoản', async () => {
    rows.push({ id: 'a', idaccount: OWNER, status: 'READY', requested_at: new Date(), ready_at: new Date(), expires_at: new Date(Date.now() + DAY) });
    rows.push({ id: 'b', idaccount: OTHER, status: 'PROCESSING', requested_at: new Date() });
    const res = fakeRes();
    await controller.latest({ user: { idaccount: OWNER } }, res);
    assert.strictEqual(res.body.data.id, 'a');
    assert.deepStrictEqual(res.body.data.files, ['json', 'csv']);
  });

  it('job dọn: xóa tệp hết hạn khỏi kho, chuyển EXPIRED, giữ dòng yêu cầu', async () => {
    const res = fakeRes();
    await controller.request({ user: { idaccount: OWNER }, body: {} }, res);
    await service.processRequest(rows[0].id);
    const file = path.join(dir, 'data-exports', String(OWNER), `${rows[0].id}.json`);
    assert.ok(fs.existsSync(file));
    rows[0].expires_at = new Date(Date.now() - 1000);
    const n = await service.purgeExpired();
    assert.strictEqual(n, 1);
    assert.ok(!fs.existsSync(file));
    assert.strictEqual(rows[0].status, 'EXPIRED');
    assert.strictEqual(rows[0].json_ref, null);
    assert.strictEqual(rows.length, 1);
    const src = fs.readFileSync(require.resolve('../../core/scheduler.service'), 'utf8');
    assert.match(src.slice(src.indexOf('async function runDailyMaintenanceRoutine')), /runDailyDataExportPurgeTask\(\)/);
  });

  it('tạo tệp lỗi: chuyển FAILED, không gửi email', async () => {
    syncRepository.getTransactionsByAccount = async () => { throw new Error('CSDL lỗi'); };
    const res = fakeRes();
    await controller.request({ user: { idaccount: OWNER }, body: {} }, res);
    await service.processRequest(rows[0].id);
    assert.strictEqual(rows[0].status, 'FAILED');
    assert.strictEqual(mails.length, 0);
  });

  it('route đã gắn: /api/account/data-export cần đăng nhập; admin xem lịch sử yêu cầu', () => {
    const index = fs.readFileSync(require.resolve('../../api/index'), 'utf8');
    assert.match(index, /router\.use\('\/account', require\('\.\/account\.routes'\)\)/);
    const routes = fs.readFileSync(require.resolve('../../api/account.routes'), 'utf8');
    assert.match(routes, /router\.use\(authenticate\)/);
    for (const r of ["post('/data-export'", "get('/data-export/latest'", "get('/data-export/:id/download'"]) assert.ok(routes.includes(r), r);
    const admin = fs.readFileSync(require.resolve('../../api/admin.routes'), 'utf8');
    assert.ok(admin.includes("router.get('/getuser/:id/data-exports'"));
  });
});
