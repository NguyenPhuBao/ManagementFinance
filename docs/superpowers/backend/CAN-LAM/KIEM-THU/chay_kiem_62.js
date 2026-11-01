// Kịch bản nghiệm thu đơn 62 (62.1–62.5). KHÔNG cần CSDL, KHÔNG gọi PayOS, KHÔNG có giao dịch thật.
// config/db, repository, PayOS và socket đều bị thay bằng bản giả ngay trong tiến trình này.
// Cách chạy (từ src/Backend):
//   node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_62.js . kq_62.txt
// Dòng cuối phải là "14 đạt / 14 ca". Có ca hỏng thì mã thoát 1.
const path = require('path');
const fs = require('fs');

const ROOT = path.resolve(process.argv[2] || '.');
const DST = process.argv[3];

process.env.DATA_ENCRYPTION_KEY = process.env.DATA_ENCRYPTION_KEY || 'khoa-kich-ban';

const cam = (rel, exportsObj) => {
  const f = path.join(ROOT, rel);
  require.cache[f] = { id: f, filename: f, loaded: true, exports: exportsObj, children: [], paths: [] };
};

const socketDaPhat = [];
const adminDaPhat = [];
cam('core/socket.js', {
  emitToAccount: (id, ten, data) => socketDaPhat.push({ id, ten, data }),
  getIO: () => ({ to: () => ({ emit: (ten, data) => adminDaPhat.push({ ten, data }) }) }),
});
cam('middleware/auth.js', { invalidateAccountCache: () => {} });
cam('core/event-bus.js', { publish: () => {} });
cam('modules/household/household.service.js', { updateHouseholdStatusByOwner: async () => {} });

const payosClient = require(path.join(ROOT, 'modules/payment/payos.client'));
const repo = require(path.join(ROOT, 'modules/payment/payment.repository'));
const service = require(path.join(ROOT, 'modules/payment/payment.service'));
if (service.stopPaymentAutoExpiryJob) service.stopPaymentAutoExpiryJob();

// Sổ giả: ghi lại mọi lời gọi repository.
let so;
const datLai = () => {
  so = { kichHoat: [], capNhat: [], giaoDich: [], taoDon: [], dongBo: [] };
  socketDaPhat.length = 0;
  adminDaPhat.length = 0;
};
repo.activatePremiumSubscription = async (p) => { so.kichHoat.push(p); return { ok: true }; };
repo.updateOrderPaymentStatus = async (p) => { so.capNhat.push(p); return p; };
repo.recordTransaction = async (p) => { so.giaoDich.push(p); return p; };
repo.updateOrderSyncStatus = async (id, p) => { so.dongBo.push(p); return p; };
repo.createOrder = async (p) => { so.taoDon.push(p); return { id: p.id, order_code: p.orderCode, status: p.status }; };
repo.findAccountSubscription = async () => ({ type: 'Basic', premium_expires_at: null });

const donMoi = (ghiDe = {}) => ({
  id: 'don-1',
  idaccount: 30,
  order_code: 123456789,
  amount: 49000,
  amount_received: 0,
  status: 'PENDING',
  is_template: false,
  transfer_content: 'CSTHU ABC123',
  account: { type: 'Basic', premium_expires_at: null },
  expired_at: new Date(Date.now() + 600000),
  ...ghiDe,
});

const payosTra = (ketQua) => payosClient.setPayOSClientMock({
  paymentRequests: { get: async () => ketQua },
});
const webhook = async (don, soTien, gio) => {
  repo.findOrderByCode = async () => don;
  payosClient.setPayOSClientMock({ webhooks: { verify: async (w) => w.data } });
  return service.handlePayOSWebhook({
    code: '00',
    signature: 'gia',
    data: {
      orderCode: Number(don.order_code),
      amount: soTien,
      description: 'CSTHU ABC123',
      reference: `REF-${Date.now()}`,
      transactionDateTime: gio || '2026-11-01 13:57:17',
    },
  });
};

const kq = [];
const ca = async (ma, ten, fn) => {
  datLai();
  let dat = false;
  let chiTiet = '';
  try {
    chiTiet = (await fn()) || '';
    dat = true;
  } catch (e) {
    chiTiet = e.message;
  }
  payosClient.setPayOSClientMock(null);
  kq.push(`${dat ? 'ĐẠT ' : 'HỎNG'} | ${ma} | ${ten}${chiTiet ? ` | ${chiTiet}` : ''}`);
  return dat;
};
const can = (dk, cau) => { if (!dk) throw new Error(cau); };

(async () => {
  const dat = [];
  const chay = async (...a) => dat.push(await ca(...a));

  await chay('62.1', 'PayOS không trả tài khoản: báo 502, không lưu đơn', async () => {
    payosClient.setPayOSClientMock({
      paymentRequests: { create: async () => ({ checkoutUrl: 'https://pay.payos.vn/web/x', paymentLinkId: 'x' }) },
    });
    let loi = null;
    try { await service.createPremiumOrder(30); } catch (e) { loi = e; }
    can(loi, 'vẫn tạo được đơn, QR rơi về tài khoản ghi cứng');
    can(loi.statusCode === 502, `mã lỗi ${loi.statusCode}, cần 502`);
    can(so.taoDon.length === 0, 'vẫn lưu đơn');
  });

  await chay('62.1', 'PayOS trả tài khoản: QR và đơn dùng đúng tài khoản ấy', async () => {
    payosClient.setPayOSClientMock({
      paymentRequests: {
        create: async () => ({
          bin: '970436',
          accountNumber: '1234567890',
          accountName: 'KENH THU',
          description: 'CSTHU ABC123',
          checkoutUrl: 'https://pay.payos.vn/web/x',
          paymentLinkId: 'x',
        }),
      },
    });
    const don = await service.createPremiumOrder(30);
    can(don.qrUrl.includes('970436-1234567890'), `qrUrl sai: ${don.qrUrl}`);
    can(don.accountNumber === '1234567890', 'accountNumber sai');
  });

  await chay('62.1', 'Mã chạy không còn tài khoản cá nhân ghi cứng', async () => {
    const con = ['modules/payment/payment.service.js', 'modules/payment/payment.repository.js']
      .filter((t) => /2512070399999|NGUYEN PHU BAO/.test(fs.readFileSync(path.join(ROOT, t), 'utf8')));
    can(con.length === 0, `còn trong: ${con.join(', ')}`);
  });

  await chay('62.2', 'JIT: UNDERPAID 20.000 ra REFUND_PENDING, có dòng giao dịch', async () => {
    payosTra({ status: 'UNDERPAID', amountPaid: 20000, transactions: [{ reference: 'R1', transactionDateTime: '2026-11-01 13:00:00' }] });
    const don = await service.syncOrderWithPayOS(donMoi());
    can(don.status === 'REFUND_PENDING', `trạng thái ${don.status}`);
    can(so.capNhat[0]?.amountReceived === 20000, 'không ghi số đã nhận');
    can(so.giaoDich.length === 1, `${so.giaoDich.length} dòng giao dịch`);
    can(so.kichHoat.length === 0, 'vẫn kích hoạt');
  });

  await chay('62.2', 'JIT: PAID 70.000 ra WAITING_CONFIRMATION, chưa kích hoạt', async () => {
    payosTra({ status: 'PAID', amountPaid: 70000, transactions: [] });
    const don = await service.syncOrderWithPayOS(donMoi());
    can(don.status === 'WAITING_CONFIRMATION', `trạng thái ${don.status}`);
    can(so.kichHoat.length === 0, 'kích hoạt không qua xác nhận');
    can(socketDaPhat.some((s) => s.ten === 'payment.overpaid_confirmation'), 'không báo socket');
  });

  await chay('62.2', 'JIT: PAID 49.000 kích hoạt, hạn +30 ngày, phát account.upgraded', async () => {
    payosTra({ status: 'PAID', amountPaid: 49000, transactions: [{ reference: 'R2' }] });
    const don = await service.syncOrderWithPayOS(donMoi());
    can(don.status === 'PAID', `trạng thái ${don.status}`);
    can(so.kichHoat.length === 1, 'không kích hoạt');
    const ngay = Math.round((so.kichHoat[0].newExpiresAt - Date.now()) / 86400000);
    can(ngay === 30, `hạn +${ngay} ngày`);
    can(so.kichHoat[0].transactionData.payosTransactionId === 'R2', 'mất reference');
    can(socketDaPhat.some((s) => s.ten === 'account.upgraded'), 'không phát account.upgraded');
  });

  await chay('62.2', 'JIT: EXPIRED nhưng đã có 20.000 thì không rơi vào hết hạn', async () => {
    payosTra({ status: 'EXPIRED', amountPaid: 20000, transactions: [] });
    const don = await service.syncOrderWithPayOS(donMoi());
    can(don.status === 'REFUND_PENDING', `trạng thái ${don.status}`);
  });

  await chay('62.2', 'JIT: PROCESSING quá hạn cục bộ vẫn giữ PENDING', async () => {
    payosTra({ status: 'PROCESSING', amountPaid: 0 });
    const don = await service.syncOrderWithPayOS(donMoi({ expired_at: new Date(Date.now() - 1000) }));
    can(don.status === 'PENDING', `trạng thái ${don.status}`);
    can(so.dongBo.length === 0, 'vẫn ghi hết hạn');
  });

  await chay('62.2', 'JIT: EXPIRED không có tiền vẫn hết hạn như cũ', async () => {
    payosTra({ status: 'EXPIRED' });
    const don = await service.syncOrderWithPayOS(donMoi());
    can(don.status === 'EXPIRED', `trạng thái ${don.status}`);
  });

  await chay('62.3', 'Webhook tới đơn CANCELLED ra REFUND_PENDING, admin được báo', async () => {
    const r = await webhook(donMoi({ status: 'CANCELLED' }), 49000);
    can(r.action === 'REFUND_PENDING', `action ${r.action}`);
    can(so.capNhat[0]?.status === 'REFUND_PENDING', 'không đổi trạng thái đơn');
    can(so.capNhat[0]?.amountReceived === 49000, 'không ghi số đã nhận');
    can(so.kichHoat.length === 0, 'kích hoạt đơn đã huỷ');
    can(adminDaPhat.some((a) => a.ten === 'payment.refund_pending'), 'admin không được báo');
    can(socketDaPhat.some((s) => s.ten === 'payment.order_cancelled'), 'người dùng không được báo');
  });

  await chay('62.3', 'Phát lại webhook sau đó không đổi gì thêm', async () => {
    const r = await webhook(donMoi({ status: 'REFUND_PENDING' }), 49000);
    can(r.action === undefined, `action ${r.action}`);
    can(so.capNhat.length === 0, 'đổi trạng thái lần hai');
  });

  await chay('62.4', 'Đồng ý đơn thừa không ghi thêm dòng giao dịch', async () => {
    repo.findOrderByCode = async () => donMoi({ status: 'WAITING_CONFIRMATION', amount_received: 70000 });
    await service.confirmUpgrade(30, { orderCode: 123456789, accept: true });
    can(so.kichHoat.length === 1, 'không kích hoạt');
    can(!so.kichHoat[0].transactionData, 'vẫn truyền transactionData, ra hai dòng cho một lần chuyển');
  });

  const gioGoc = process.env.TZ;
  await chay('62.5', 'Máy chủ UTC: 13:57:17 giờ PayOS thành 06:57:17Z', async () => {
    process.env.TZ = 'UTC';
    await webhook(donMoi(), 49000, '2026-11-01 13:57:17');
    const gio = so.giaoDich[0]?.transactionTime || so.kichHoat[0]?.transactionData?.transactionTime;
    can(gio && gio.toISOString() === '2026-11-01T06:57:17.000Z', `ra ${gio && gio.toISOString()}`);
  });

  await chay('62.5', 'Máy chủ +07: kết quả vẫn thế; chuỗi lỗi không làm hỏng đơn', async () => {
    process.env.TZ = 'Asia/Ho_Chi_Minh';
    await webhook(donMoi(), 49000, '2026-11-01 13:57:17');
    const gio = so.kichHoat[0]?.transactionData?.transactionTime;
    can(gio && gio.toISOString() === '2026-11-01T06:57:17.000Z', `ra ${gio && gio.toISOString()}`);
    datLai();
    await webhook(donMoi(), 49000, 'khong-phai-ngay');
    const gio2 = so.kichHoat[0]?.transactionData?.transactionTime;
    can(gio2 && !Number.isNaN(gio2.getTime()), 'giờ không hợp lệ đi vào CSDL');
  });
  if (gioGoc === undefined) delete process.env.TZ; else process.env.TZ = gioGoc;

  const soDat = dat.filter(Boolean).length;
  kq.push(`${soDat} đạt / ${dat.length} ca`);
  const ra = kq.join('\n');
  console.log(ra);
  if (DST) fs.writeFileSync(DST, `${ra}\n`);
  process.exit(soDat === dat.length ? 0 : 1);
})().catch((e) => {
  console.error('LOI', e);
  process.exit(1);
});
