// Kịch bản nghiệm thu đơn 66.1. KHÔNG cần CSDL, KHÔNG gọi PayOS, KHÔNG có giao dịch thật.
// Đi qua route Express thật, `authorize` thật và service thật; xác thực, repository, socket là bản giả trong tiến trình này.
// Cách chạy (từ src/Backend):
//   node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_66.js . kq_66.txt
// Dòng cuối phải là "9 đạt / 9 ca". Có ca hỏng thì mã thoát 1.
const path = require('path');
const fs = require('fs');
const http = require('http');
const { createRequire } = require('module');

const ROOT = path.resolve(process.argv[2] || '.');
const DST = process.argv[3];
const tuGoc = createRequire(path.join(ROOT, 'index.js'));

process.env.DATA_ENCRYPTION_KEY = process.env.DATA_ENCRYPTION_KEY || 'khoa-kich-ban';

const cam = (rel, exportsObj) => {
  const f = path.join(ROOT, rel);
  require.cache[f] = { id: f, filename: f, loaded: true, exports: exportsObj, children: [], paths: [] };
};

const socketKhach = [];
const socketAdmin = [];
cam('core/socket.js', {
  emitToAccount: (id, ten, data) => socketKhach.push({ id, ten, data }),
  getIO: () => ({ to: () => ({ emit: (ten, data) => socketAdmin.push({ ten, data }) }) }),
});
cam('core/event-bus.js', { publish: () => {} });
cam('modules/household/household.service.js', { updateHouseholdStatusByOwner: async () => {} });
cam('modules/admin/admin.controller.js', new Proxy({}, { get: () => (_req, res) => res.status(501).end() }));
cam('modules/aiops/aiops.controller.js', new Proxy({}, { get: () => (_req, res) => res.status(501).end() }));

// Header `x-thu` thay cho token: chỉ route và `authorize` là thật ở bước quyền.
cam('middleware/auth.js', {
  authenticate: (req, res, next) => {
    const nguoi = { admin: { idaccount: 1, rolename: 'admin' }, chu: { idaccount: 30, rolename: 'user' }, khac: { idaccount: 31, rolename: 'user' } }[req.headers['x-thu']];
    if (!nguoi) return res.status(401).json({ success: false });
    req.user = nguoi;
    return next();
  },
  invalidateAccountCache: () => {},
});

const express = tuGoc('express');
const repo = require(path.join(ROOT, 'modules/payment/payment.repository'));
const service = require(path.join(ROOT, 'modules/payment/payment.service'));
if (service.stopPaymentAutoExpiryJob) service.stopPaymentAutoExpiryJob();

let don;
let so;
const datLai = (trangThai = 'WAITING_CONFIRMATION') => {
  don = {
    id: 'don-1', order_code: 5166888392633n, idaccount: 30, status: trangThai, amount: 49000, amount_received: 70000,
    is_template: false, account: { idaccount: 30, type: 'Basic', premium_expires_at: null },
  };
  so = { kichHoat: [], capNhat: [] };
  socketKhach.length = 0;
  socketAdmin.length = 0;
};
repo.findOrderByCode = async (ma) => (String(ma) === String(don.order_code) ? don : null);
repo.activatePremiumSubscription = async (p) => { so.kichHoat.push(p); return { ok: true }; };
repo.updateOrderPaymentStatus = async (p) => { so.capNhat.push(p); return p; };

const app = express();
app.use(express.json());
app.use('/api/admin', require(path.join(ROOT, 'api/admin.routes')));
app.use('/api/payment', require(path.join(ROOT, 'api/payment.routes')));
app.use((err, _req, res, _next) => res.status(500).json({ success: false, message: err.message }));

const MA = '5166888392633';
const kq = [];
const ca = (ten, dat, chiTiet) => kq.push(`${dat ? 'ĐẠT ' : 'HỎNG'} | ${ten}${dat ? '' : ` | ${chiTiet}`}`);

const server = http.createServer(app);
server.listen(0, '127.0.0.1', async () => {
  const goc = `http://127.0.0.1:${server.address().port}/api`;
  const goi = async (ai, duong, than) => {
    const r = await fetch(goc + duong, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-thu': ai },
      body: JSON.stringify(than),
    });
    return r.status;
  };
  const duongAdmin = `/admin/payments/orders/${MA}/confirm-upgrade`;

  datLai();
  let st = await goi('admin', duongAdmin, { accept: true });
  ca('66.1 Admin Đồng ý đơn của khách: 200, kích hoạt đúng tài khoản khách', st === 200 && so.kichHoat[0]?.idaccount === 30, `mã ${st}, kích hoạt ${JSON.stringify(so.kichHoat)}`);
  ca('66.1 Admin Đồng ý: khách nhận account.upgraded', socketKhach.some((s) => s.id === 30 && s.ten === 'account.upgraded'), JSON.stringify(socketKhach));

  datLai();
  st = await goi('admin', duongAdmin, { accept: false });
  ca('66.1 Admin Từ chối: 200, REFUND_PENDING, lý do ghi là admin', st === 200 && so.capNhat[0]?.status === 'REFUND_PENDING' && so.capNhat[0]?.refundReason === 'Admin từ chối nâng cấp gói', `mã ${st}, ${JSON.stringify(so.capNhat)}`);
  ca('66.1 Admin Từ chối: màn của khách được báo để nạp lại', socketKhach.some((s) => s.id === 30 && s.ten === 'payment.order_cancelled'), JSON.stringify(socketKhach));

  datLai();
  st = await goi('khac', duongAdmin, { accept: true });
  ca('66.1 Tài khoản thường gọi route admin: 403, không đổi gì', st === 403 && so.kichHoat.length === 0, `mã ${st}`);

  datLai();
  st = await goi('khac', '/payment/confirm-upgrade', { orderCode: MA, accept: true });
  ca('66.1 Người khác gọi route người dùng: vẫn 404, không đổi gì', st === 404 && so.kichHoat.length === 0, `mã ${st}`);

  datLai();
  st = await goi('chu', '/payment/confirm-upgrade', { orderCode: MA, accept: false });
  ca('66.1 Chủ đơn tự từ chối: vẫn chạy, lý do giữ câu của người dùng', st === 200 && so.capNhat[0]?.refundReason === 'Do người dùng từ chối nâng cấp gói', `mã ${st}, ${JSON.stringify(so.capNhat)}`);

  datLai('PAID');
  st = await goi('admin', duongAdmin, { accept: true });
  ca('66.1 Đơn không còn chờ xác nhận: 400, không kích hoạt lần hai', st === 400 && so.kichHoat.length === 0, `mã ${st}`);

  datLai();
  const st1 = await goi('admin', '/admin/payments/orders/abc/confirm-upgrade', { accept: true });
  const st2 = await goi('admin', duongAdmin, { accept: 'true' });
  ca('66.1 Mã đơn hoặc accept sai kiểu: 400', st1 === 400 && st2 === 400, `mã ${st1}, ${st2}`);

  const dat = kq.filter((d) => d.startsWith('ĐẠT')).length;
  kq.push(`${dat} đạt / ${kq.length} ca`);
  const chu = kq.join('\n');
  console.log(chu);
  if (DST) fs.writeFileSync(DST, `${chu}\n`);
  process.exit(dat === kq.length - 1 ? 0 : 1);
});
