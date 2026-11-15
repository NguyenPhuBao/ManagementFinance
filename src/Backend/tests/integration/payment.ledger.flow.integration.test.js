/**
 * Luồng tiền trên CSDL thử thật (TEST_DATABASE_URL đã áp migration 53). PayOS được stub — không gọi mạng.
 * Kế hoạch 2026-11-15 "đơn mẫu chống lạm dụng" — P1–P8, P11–P13, P15–P20.
 */
const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { pool } = require('../../config/db');
const payosClient = require('../../modules/payment/payos.client');
const paymentService = require('../../modules/payment/payment.service');
const paymentController = require('../../modules/payment/payment.controller');
const adminRepository = require('../../modules/admin/admin.repository');
const { decrypt } = require('../../utils/crypto.util');

const PIN = '246810';
const uid = () => crypto.randomUUID();
let seq = 0;
const code = () => Number(`9${String(Date.now()).slice(-8)}${String(++seq).padStart(3, '0')}`);

function mockRes() {
  const r = { statusCode: 200, body: null };
  r.status = (c) => { r.statusCode = c; return r; };
  r.json = (b) => { r.body = b; return r; };
  return r;
}
async function call(fn, req) {
  const res = mockRes();
  let nextErr = null;
  await fn(req, res, (e) => { nextErr = e; });
  if (nextErr) { res.statusCode = nextErr.statusCode || 500; res.body = { message: nextErr.message, code: nextErr.code }; }
  return res;
}

describe('Luồng tiền: đơn mẫu, webhook, hoàn tiền, thống kê', () => {
  let admin;
  let user;
  const saved = {};
  const payos = { links: [], linkInfo: null };

  before(async () => {
    const rows = (await pool.query('SELECT "Idaccount" AS id FROM "account" WHERE "Delete_at" IS NULL ORDER BY 1 LIMIT 2')).rows;
    admin = { idaccount: rows[0].id, username: 'it-admin' };
    user = rows[1] ? rows[1].id : rows[0].id;
    const pinHash = await bcrypt.hash(PIN, 4);
    saved.getAccountById = adminRepository.getAccountById;
    adminRepository.getAccountById = async (id) => ({ idaccount: id, pin_hash: pinHash, password: 'x' });
    saved.createPaymentLink = payosClient.createPaymentLink;
    saved.verifyWebhookData = payosClient.verifyWebhookData;
    saved.getPaymentLinkInfo = payosClient.getPaymentLinkInfo;
    payosClient.createPaymentLink = async (p) => {
      payos.links.push(p);
      return { checkoutUrl: 'https://pay.test/x', paymentLinkId: `pl-${p.orderCode}`, qrCode: 'qr', bin: '970422', accountNumber: '0123456789', accountName: 'CONG TY TEST', description: p.description };
    };
    payosClient.verifyWebhookData = async (payload) => payload.data;
    payosClient.getPaymentLinkInfo = async () => payos.linkInfo;
    // Ngày thử: xoá sạch hạn mức hôm nay bằng cách đếm từ dữ liệu thật (không xoá được đơn — trigger chặn)
  });
  after(() => {
    adminRepository.getAccountById = saved.getAccountById;
    payosClient.createPaymentLink = saved.createPaymentLink;
    payosClient.verifyWebhookData = saved.verifyWebhookData;
    payosClient.getPaymentLinkInfo = saved.getPaymentLinkInfo;
  });
  beforeEach(() => { payos.links.length = 0; payos.linkInfo = null; });

  const todayTemplates = async () => (await pool.query(
    `SELECT count(*)::int n FROM "payment_order" WHERE "is_template" = TRUE AND "created_at" >= (date_trunc('day', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') AT TIME ZONE 'Asia/Ho_Chi_Minh') AT TIME ZONE 'UTC'`
  )).rows[0].n;
  const createSample = (body) => call(paymentController.createSampleOrder, { body, user: admin });

  describe('Đơn mẫu', () => {
    it('P4. Thiếu / sai PIN ⇒ 400, không gọi PayOS, không ghi đơn', async () => {
      const before = await todayTemplates();
      const r1 = await createSample({});
      const r2 = await createSample({ pin: '000000' });
      assert.equal(r1.statusCode, 400);
      assert.equal(r2.statusCode, 400);
      assert.equal(payos.links.length, 0);
      assert.equal(await todayTemplates(), before);
    });

    it('P1–P3, P20. Bỏ qua amount / status / simulateWebhook / idaccount: đơn 2.000 đ, PENDING, gắn admin tạo, không có dòng sổ; nhật ký đủ', async () => {
      if (await todayTemplates() >= 10) return; // hạn mức hôm nay đã hết trên CSDL thử
      const r = await createSample({ pin: PIN, amount: 500000000, status: 'PAID', simulateWebhook: true, idaccount: user, packageType: 'Premium' });
      assert.equal(r.statusCode, 201, JSON.stringify(r.body));
      assert.equal(payos.links[0].amount, 2000);
      const o = (await pool.query('SELECT * FROM "payment_order" WHERE "order_code" = $1', [payos.links[0].orderCode])).rows[0];
      assert.equal(Number(o.amount), 2000);
      assert.equal(o.status, 'PENDING');
      assert.equal(o.is_template, true);
      assert.equal(o.idaccount, admin.idaccount);
      assert.equal((await pool.query('SELECT 1 FROM "payment_transaction" WHERE "order_id" = $1', [o.id])).rowCount, 0);
      const log = (await pool.query(`SELECT "Action" a FROM "audit_log" WHERE "Action" LIKE '%đơn thử nghiệm%' AND "Action" LIKE $1 ORDER BY "Idlog" DESC LIMIT 1`, [`%${payos.links[0].orderCode}%`])).rows[0];
      assert.ok(log && /2\.000/.test(log.a), 'nhật ký có số tiền và mã đơn');
    });

    it('P5, P7. Hạn mức 10 đơn / ngày cho toàn hệ thống, kể cả gọi đồng thời', async () => {
      const results = await Promise.all(Array.from({ length: 12 }, () => createSample({ pin: PIN })));
      assert.equal(await todayTemplates(), 10, 'không bao giờ vượt 10 đơn mẫu trong ngày');
      assert.ok(results.some((r) => r.statusCode === 429 && r.body.code === 'SAMPLE_DAILY_LIMIT'));
      const quota = await call(paymentController.getSampleQuota, { user: admin });
      assert.deepEqual({ used: quota.body.data.used, limit: quota.body.data.limit, amount: quota.body.data.amount }, { used: 10, limit: 10, amount: 2000 });
    });

    it('P6. Đơn mẫu tạo hôm qua không tính vào hạn mức hôm nay', async () => {
      const quota = await paymentService.getSampleQuota(new Date(Date.now() + 24 * 3600 * 1000));
      assert.equal(quota.used, 0);
    });

    it('P8. Ẩn đơn mẫu: không xoá dòng nào; danh sách mặc định không hiện; thống kê vẫn tính', async () => {
      const total = (await pool.query('SELECT count(*)::int n FROM "payment_order" WHERE "is_template" = TRUE')).rows[0].n;
      const r = await call(paymentController.deleteSampleOrders, { user: admin });
      assert.equal(r.statusCode, 200);
      assert.equal((await pool.query('SELECT count(*)::int n FROM "payment_order" WHERE "is_template" = TRUE')).rows[0].n, total);
      assert.equal((await pool.query('SELECT count(*)::int n FROM "payment_order" WHERE "is_template" = TRUE AND "hidden_at" IS NULL')).rows[0].n, 0);
      const list = await call(paymentController.getOrdersForAdmin, { query: { limit: 100 }, user: admin });
      const items = list.body.data.items || list.body.data.orders || [];
      assert.ok(items.every((o) => !o.is_template));
      const csv = await call(paymentController.getOrdersForAdmin, { query: { limit: 100, includeHidden: 'true' }, user: admin });
      assert.ok((csv.body.data.items || csv.body.data.orders).some((o) => o.is_template), 'xuất CSV vẫn có đơn mẫu đã ẩn');
      const stats = (await call(paymentController.getPaymentStatsForAdmin, { query: {}, user: admin })).body.data;
      assert.equal(stats.orders.template, total);
    });
  });

  describe('Tiền vào (webhook)', () => {
    let order;
    beforeEach(async () => {
      const id = uid();
      const oc = code();
      await pool.query(
        `INSERT INTO "payment_order" ("id","idaccount","order_code","amount","status","payment_link_id","recognition_code","expired_at") VALUES ($1,$2,$3,49000,'PENDING',$4,$5, now() + interval '10 minutes')`,
        [id, user, oc, `pl-${oc}`, `R${String(oc).slice(-5)}`]
      );
      order = { id, oc };
    });
    const webhook = (data) => ({ code: '00', desc: 'success', success: true, signature: 'sig', data: { orderCode: order.oc, amount: 49000, description: 'CS ABC', accountNumber: '0123456789', transactionDateTime: '2026-11-15 10:00:00', currency: 'VND', paymentLinkId: `pl-${order.oc}`, code: '00', desc: 'success', counterAccountBankId: '970422', counterAccountBankName: 'MB Bank', counterAccountName: 'NGUYEN VAN A', counterAccountNumber: '9876543210', ...data } });

    it('P11. Đủ trường: dòng sổ IN có mã ngân hàng, tài khoản nhận, người chuyển mã hoá, payload gốc mã hoá; có nhật ký webhook', async () => {
      const ref = `FT${Date.now()}`;
      await paymentService.handlePayOSWebhook(webhook({ reference: ref }));
      const tx = (await pool.query('SELECT * FROM "payment_transaction" WHERE "order_id" = $1', [order.id])).rows[0];
      assert.equal(tx.payos_transaction_id, ref);
      assert.equal(tx.direction, 'IN');
      assert.equal(tx.source, 'WEBHOOK');
      assert.equal(tx.receiving_account_number, '0123456789');
      assert.equal(tx.payment_link_id, `pl-${order.oc}`);
      assert.equal(tx.counter_account_bank_name, 'MB Bank');
      assert.notEqual(tx.counter_account_number, '9876543210', 'tài khoản người chuyển phải mã hoá');
      assert.equal(decrypt(tx.counter_account_number), '9876543210');
      assert.equal(decrypt(tx.counter_account_name), 'NGUYEN VAN A');
      assert.equal(JSON.parse(decrypt(tx.raw_payload)).signature, 'sig');
      const log = (await pool.query('SELECT * FROM "payment_webhook_log" WHERE "reference" = $1', [ref])).rows[0];
      assert.ok(log && log.signature_valid === true && /^enc:/.test(log.payload));
    });

    it('P12. Thiếu reference, PayOS API trả được ⇒ ghi sổ với reference từ API', async () => {
      const ref = `FT${Date.now()}A`;
      payos.linkInfo = { status: 'PAID', amountPaid: 49000, transactions: [{ reference: ref, amount: 49000, accountNumber: '0123456789', description: 'CS ABC', transactionDateTime: '2026-11-15 10:00:00', counterAccountBankName: 'MB Bank', counterAccountNumber: '111' }] };
      await paymentService.handlePayOSWebhook(webhook({ reference: '' }));
      const tx = (await pool.query('SELECT * FROM "payment_transaction" WHERE "order_id" = $1', [order.id])).rows[0];
      assert.equal(tx.payos_transaction_id, ref);
    });

    it('P13. Thiếu reference ở cả hai nguồn ⇒ không ghi sổ, không kích hoạt, không dùng mã đơn; có nhật ký MISSING_REFERENCE', async () => {
      payos.linkInfo = { status: 'PAID', amountPaid: 49000, transactions: [] };
      await paymentService.handlePayOSWebhook(webhook({ reference: undefined }));
      assert.equal((await pool.query('SELECT 1 FROM "payment_transaction" WHERE "order_id" = $1', [order.id])).rowCount, 0);
      assert.equal((await pool.query(`SELECT 1 FROM "payment_transaction" WHERE "payos_transaction_id" = $1`, [String(order.oc)])).rowCount, 0);
      const o = (await pool.query('SELECT "status" FROM "payment_order" WHERE "id" = $1', [order.id])).rows[0];
      assert.ok(['PENDING', 'EXPIRED'].includes(o.status));
      assert.equal((await pool.query(`SELECT 1 FROM "payment_webhook_log" WHERE "order_code" = $1 AND "handled_as" = 'MISSING_REFERENCE'`, [order.oc])).rowCount, 1);
    });
  });

  describe('Tiền ra (hoàn tiền thủ công của admin)', () => {
    let order;
    beforeEach(async () => {
      const id = uid();
      await pool.query(
        `INSERT INTO "payment_order" ("id","idaccount","order_code","amount","amount_received","status","paid_at","created_at") VALUES ($1,$2,$3,49000,49000,'REFUND_PENDING', now() - interval '2 days', now() - interval '3 days')`,
        [id, user, code()]
      );
      order = id;
    });
    const refund = (body) => call(paymentController.processRefund, { params: { id: order }, body, user: admin });
    const valid = () => ({ pin: PIN, refundedAmount: 49000, bankReference: `FT-OUT-${Date.now()}`, refundReason: 'Khách huỷ', refundedAt: new Date(Date.now() - 86400000).toISOString(), refundProof: 'https://proof/x.png' });

    it('P15. Thiếu / sai PIN ⇒ 400, đơn không đổi', async () => {
      const { pin, ...noPin } = valid();
      assert.equal((await refund(noPin)).statusCode, 400);
      assert.equal((await refund({ ...valid(), pin: '000000' })).statusCode, 400);
      assert.equal((await pool.query('SELECT "status" FROM "payment_order" WHERE "id" = $1', [order])).rows[0].status, 'REFUND_PENDING');
    });

    it('P16. Thiếu mã GD; số tiền vượt số đã nhận; ngày ở tương lai / trước khi tạo đơn ⇒ từ chối', async () => {
      assert.equal((await refund({ ...valid(), bankReference: '' })).statusCode, 400);
      assert.equal((await refund({ ...valid(), refundedAmount: 50000 })).statusCode, 400);
      assert.equal((await refund({ ...valid(), refundedAt: new Date(Date.now() + 86400000).toISOString() })).statusCode, 400);
      assert.equal((await refund({ ...valid(), refundedAt: new Date(Date.now() - 10 * 86400000).toISOString() })).statusCode, 400);
      assert.equal((await refund({ ...valid(), refundedAt: '' })).statusCode, 400);
    });

    it('P17. Hợp lệ ⇒ REFUNDED, ngày hoàn do admin nhập, dòng sổ OUT đủ trường; hoàn lần 2 bị từ chối', async () => {
      const body = valid();
      const r = await refund(body);
      assert.equal(r.statusCode, 200, JSON.stringify(r.body));
      // Đọc qua Prisma như hệ thống thật: cột thời gian không kèm múi giờ lưu UTC (pg thô sẽ hiểu theo giờ máy)
      const { prisma } = require('../../config/db');
      const o = await prisma.payment_order.findUnique({ where: { id: order } });
      assert.equal(o.status, 'REFUNDED');
      assert.equal(new Date(o.refunded_at).getTime(), new Date(body.refundedAt).getTime());
      const tx = await prisma.payment_transaction.findFirst({ where: { order_id: order, direction: 'OUT' } });
      assert.equal(tx.payos_transaction_id, body.bankReference);
      assert.equal(tx.source, 'ADMIN_REFUND');
      assert.equal(Number(tx.amount), 49000);
      assert.equal(tx.created_by, admin.idaccount);
      assert.equal(tx.proof, body.refundProof);
      assert.equal(new Date(tx.transaction_time).getTime(), new Date(body.refundedAt).getTime());
      const again = await refund({ ...valid() });
      assert.equal(again.statusCode, 409);
      const log = (await pool.query(`SELECT 1 FROM "audit_log" WHERE "Action" LIKE $1`, [`%${body.bankReference}%`])).rowCount;
      assert.equal(log, 1);
    });

    it('Đơn PENDING (chưa nhận tiền) không hoàn được', async () => {
      const id = uid();
      await pool.query(`INSERT INTO "payment_order" ("id","idaccount","order_code","amount","status") VALUES ($1,$2,$3,49000,'PENDING')`, [id, user, code()]);
      const r = await call(paymentController.processRefund, { params: { id }, body: valid(), user: admin });
      assert.equal(r.statusCode, 409);
    });
  });

  describe('Thống kê và API đã gỡ', () => {
    it('P19. Tách user / thử nghiệm; tỷ lệ thành công chỉ tính đơn user', async () => {
      const s = (await call(paymentController.getPaymentStatsForAdmin, { query: {}, user: admin })).body.data;
      const q = async (where) => (await pool.query(`SELECT count(*)::int n, coalesce(sum("amount") FILTER (WHERE "status"='PAID'),0)::float r, count(*) FILTER (WHERE "status"='PAID')::int p FROM "payment_order" WHERE ${where}`)).rows[0];
      const u = await q('"is_template" = FALSE');
      const t = await q('"is_template" = TRUE');
      assert.deepEqual(s.orders, { total: u.n + t.n, user: u.n, template: t.n });
      assert.deepEqual(s.paid, { total: u.p + t.p, user: u.p, template: t.p });
      assert.deepEqual(s.revenue, { total: u.r + t.r, user: u.r, template: t.r });
      assert.equal(s.successRate, u.n ? Number(((u.p / u.n) * 100).toFixed(2)) : 0);
    });

    it('P18. Không còn API giả lập webhook', () => {
      const router = require('../../api/admin.routes');
      const paths = router.stack.filter((l) => l.route).map((l) => l.route.path);
      assert.ok(!paths.includes('/payments/simulate-webhook'));
      assert.equal(paymentController.simulateWebhook, undefined);
      assert.equal(paymentService.simulateWebhook, undefined);
    });
  });
});
