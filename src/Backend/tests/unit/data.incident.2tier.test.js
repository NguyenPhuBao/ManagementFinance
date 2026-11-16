const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');

const { prisma } = require('../../config/db');
const adminService = require('../../modules/admin/admin.service');
const service = require('../../modules/admin/data-incident.service');
const controller = require('../../modules/admin/data-incident.controller');

const H = 3600 * 1000;
const ADMIN = { idaccount: 102, username: 'admin.local' };

const fakeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  return res;
};

let rows;
let nextId;
let emitted;
const saved = [];
const patch = (obj, key, fn) => { saved.push([obj, key, obj[key]]); obj[key] = fn; };

beforeEach(() => {
  rows = [];
  nextId = 1;
  emitted = [];
  const t = prisma.data_incident;
  patch(t, 'create', async ({ data }) => { const r = { id: nextId++, status: 'OPEN', sensitive: false, report_not_required: false, created_at: new Date(), updated_at: new Date(), ...data }; rows.push(r); return r; });
  patch(t, 'count', async ({ where }) => rows.filter((r) => r.code.startsWith(where.code.startsWith)).length);
  patch(t, 'findUnique', async ({ where }) => rows.find((r) => r.id === where.id) || null);
  patch(t, 'findMany', async ({ where } = {}) => rows.filter((r) => !where?.status || r.status === where.status));
  patch(t, 'update', async ({ where, data }) => { const r = rows.find((x) => x.id === where.id); Object.assign(r, data); return r; });
  patch(service, 'emitChanged', (incident) => emitted.push(incident.code));
});

afterEach(() => {
  while (saved.length) { const [o, k, v] = saved.pop(); o[k] = v; }
});

const create = (over = {}) => service.createIncident({
  title: 'Lộ bản sao lưu CSDL',
  description: 'Bản sao lưu bị đặt công khai',
  source: 'PROCESSOR',
  detectedAt: new Date(Date.now() - 2 * H).toISOString(),
  ...over,
}, ADMIN.idaccount);

describe('Tầng 1: tạo sự cố và hạn 72 giờ', () => {
  it('tạo: bắt buộc tiêu đề, mô tả; mã SC-năm-số tăng dần; hạn = phát hiện + 72 giờ', async () => {
    const a = await create();
    const b = await create({ title: 'Tài khoản admin bị chiếm' });
    const year = new Date().getFullYear();
    assert.strictEqual(a.code, `SC-${year}-001`);
    assert.strictEqual(b.code, `SC-${year}-002`);
    assert.strictEqual(a.status, 'OPEN');
    assert.strictEqual(a.created_by, ADMIN.idaccount);
    const view = service.toView(a);
    assert.strictEqual(new Date(view.deadline).getTime(), new Date(a.detected_at).getTime() + 72 * H);
    assert.ok(view.remainingMs > 69 * H && view.remainingMs <= 70 * H);
    assert.strictEqual(view.overdue, false);
    await assert.rejects(() => create({ title: '' }), (e) => e.statusCode === 400);
    await assert.rejects(() => create({ description: '  ' }), (e) => e.statusCode === 400);
  });

  it('thời điểm phát hiện ở tương lai hoặc nguồn lạ bị từ chối; thiếu thì lấy thời điểm hiện tại', async () => {
    await assert.rejects(() => create({ detectedAt: new Date(Date.now() + H).toISOString() }), (e) => e.statusCode === 400);
    await assert.rejects(() => create({ source: 'HACKER' }), (e) => e.statusCode === 400);
    const c = await create({ detectedAt: undefined });
    assert.ok(Math.abs(new Date(c.detected_at).getTime() - Date.now()) < 5000);
  });

  it('danh sách: sự cố chưa đóng lên trước, quá hạn đánh dấu overdue', async () => {
    await create({ detectedAt: new Date(Date.now() - 80 * H).toISOString() });
    const list = await service.listIncidents({});
    assert.strictEqual(list[0].overdue, true);
    assert.ok(list[0].remainingMs < 0);
  });
});

describe('Tầng 2: các bước xử lý theo quy trình', () => {
  it('ngăn chặn → báo cơ quan đúng hạn → báo người dùng; mỗi bước phát sự kiện cho admin', async () => {
    const a = await create();
    await service.runAction(a.id, 'contain', {}, ADMIN.idaccount);
    assert.strictEqual(rows[0].status, 'CONTAINED');
    assert.ok(rows[0].contained_at);
    await service.runAction(a.id, 'report', { reference: 'CV-123/A05' }, ADMIN.idaccount);
    assert.strictEqual(rows[0].status, 'REPORTED');
    assert.ok(rows[0].authority_reported_at);
    assert.strictEqual(rows[0].authority_report_ref, 'CV-123/A05');
    await service.runAction(a.id, 'notify-users', {}, ADMIN.idaccount);
    assert.ok(rows[0].users_notified_at);
    assert.strictEqual(rows[0].updated_by, ADMIN.idaccount);
    assert.deepStrictEqual(emitted.slice(-3), [a.code, a.code, a.code]);
  });

  it('báo cơ quan sau 72 giờ: bắt buộc lý do báo muộn', async () => {
    const a = await create({ detectedAt: new Date(Date.now() - 75 * H).toISOString() });
    await assert.rejects(() => service.runAction(a.id, 'report', {}, ADMIN.idaccount), (e) => e.statusCode === 400 && e.code === 'LATE_REASON_REQUIRED');
    await service.runAction(a.id, 'report', { lateReason: 'Bên xử lý báo chậm' }, ADMIN.idaccount);
    assert.strictEqual(rows[0].late_reason, 'Bên xử lý báo chậm');
    assert.strictEqual(service.toView(rows[0]).reportedLate, true);
  });

  it('đóng: cần nguyên nhân gốc và đã báo cơ quan, hoặc ghi lý do không cần báo', async () => {
    const a = await create();
    await assert.rejects(() => service.runAction(a.id, 'close', { rootCause: 'Cấu hình sai' }, ADMIN.idaccount), (e) => e.code === 'REPORT_REQUIRED');
    await assert.rejects(() => service.runAction(a.id, 'close', { reportNotRequired: true }, ADMIN.idaccount), (e) => e.statusCode === 400);
    await service.runAction(a.id, 'close', { rootCause: 'Cấu hình sai', reportNotRequired: true, noReportReason: 'Dữ liệu đã mã hóa, không có khóa' }, ADMIN.idaccount);
    assert.strictEqual(rows[0].status, 'CLOSED');
    assert.strictEqual(rows[0].report_not_required, true);
    assert.ok(rows[0].closed_at);
  });

  it('sự cố đã đóng không sửa, không chạy bước nào nữa (409)', async () => {
    const a = await create();
    await service.runAction(a.id, 'report', {}, ADMIN.idaccount);
    await service.runAction(a.id, 'close', { rootCause: 'X' }, ADMIN.idaccount);
    await assert.rejects(() => service.updateIncident(a.id, { title: 'Sửa' }, ADMIN.idaccount), (e) => e.statusCode === 409);
    await assert.rejects(() => service.runAction(a.id, 'notify-users', {}, ADMIN.idaccount), (e) => e.statusCode === 409);
  });

  it('cập nhật: chỉ nhận trường cho phép, số người bị ảnh hưởng phải là số không âm', async () => {
    const a = await create();
    await service.updateIncident(a.id, { affectedUsers: 12, dataTypes: 'Email, giao dịch', sensitive: true, status: 'CLOSED', code: 'X' }, ADMIN.idaccount);
    assert.strictEqual(rows[0].affected_users, 12);
    assert.strictEqual(rows[0].sensitive, true);
    assert.strictEqual(rows[0].status, 'OPEN', 'không đổi trạng thái qua cập nhật');
    assert.notStrictEqual(rows[0].code, 'X');
    await assert.rejects(() => service.updateIncident(a.id, { affectedUsers: -1 }, ADMIN.idaccount), (e) => e.statusCode === 400);
  });

  it('controller: đóng sự cố phải xác thực PIN (CLOSE_DATA_INCIDENT); nhập sai PIN thì không đóng', async () => {
    const a = await create();
    await service.runAction(a.id, 'report', {}, ADMIN.idaccount);
    patch(adminService, 'verifySecurityAction', async () => { const e = new Error('Mã PIN sai'); e.statusCode = 400; throw e; });
    const bad = fakeRes();
    await controller.action({ params: { id: String(a.id), action: 'close' }, body: { pin: '000000', rootCause: 'X' }, user: ADMIN }, bad);
    assert.strictEqual(bad.statusCode, 400);
    assert.strictEqual(rows[0].status, 'REPORTED');
    let verifyArgs;
    adminService.verifySecurityAction = async (body, user) => { verifyArgs = { body, user }; return { verified: true }; };
    const ok = fakeRes();
    const req = { params: { id: String(a.id), action: 'close' }, body: { pin: '246810', rootCause: 'X' }, user: ADMIN };
    await controller.action(req, ok);
    assert.strictEqual(ok.statusCode, 200);
    assert.strictEqual(verifyArgs.body.action, 'CLOSE_DATA_INCIDENT');
    assert.strictEqual(rows[0].status, 'CLOSED');
    assert.match(req.auditActionName, /Đóng sự cố dữ liệu SC-/);
  });

  it('controller: tạo trả 201, người tạo lấy từ JWT; route không có DELETE; migration có trigger chặn xóa', async () => {
    const res = fakeRes();
    await controller.create({ body: { title: 'T', description: 'D', source: 'AIOPS', created_by: 999 }, user: ADMIN }, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(rows[0].created_by, ADMIN.idaccount);
    assert.ok(res.body.data.deadline);
    const routes = fs.readFileSync(require.resolve('../../api/admin.routes'), 'utf8');
    for (const r of ["router.get('/data-incidents'", "router.post('/data-incidents'", "router.patch('/data-incidents/:id'", "router.post('/data-incidents/:id/:action'"]) assert.ok(routes.includes(r), r);
    assert.ok(!/router\.delete\('\/data-incidents/.test(routes));
    const sql = fs.readFileSync(require.resolve('../../database/51_data_incident.sql'), 'utf8');
    assert.match(sql, /BEFORE DELETE ON "data_incident"/);
  });
});
