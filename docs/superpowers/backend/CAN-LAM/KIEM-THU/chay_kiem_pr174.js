// Kịch bản nghiệm thu các việc còn lại sau PR #174, chạy THẬT trên CSDL RIÊNG (T1, T3, T6, 55.A3, 60.1, 60.2).
// Không phủ 52.3, 52.4, 52.5, 48.1: bốn việc ấy cần Render, khoá thật hoặc trí nhớ người làm.
// Cách chạy (từ src/Backend, xem VIEC_BACKEND_CON_LAI.md mục "Cách làm"):
//   DATABASE_URL=postgresql://postgres:<mk>@127.0.0.1:5432/flowmoney_kiem_thu DIRECT_URL=<như trên> NODE_ENV=development LOG_LEVEL=error \
//     node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_pr174.js . kq2.txt
// Tự từ chối chạy nếu DATABASE_URL không phải CSDL flowmoney_kiem_thu trên máy này. Chạy lại nhiều lần được.
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(process.argv[2]);
const DST = process.argv[3];
const REPO = path.resolve(ROOT, '../..');
if (!/@(127\.0\.0\.1|localhost)(:\d+)?\/flowmoney_kiem_thu(\?|$)/.test(process.env.DATABASE_URL || '')) {
  console.error('Từ chối chạy: DATABASE_URL phải là CSDL flowmoney_kiem_thu trên máy này (kịch bản này GHI dữ liệu).');
  process.exit(2);
}

const cam = (rel, exportsObj) => {
  const f = path.join(ROOT, rel);
  require.cache[f] = { id: f, filename: f, loaded: true, exports: exportsObj, children: [], paths: [] };
};
cam('core/socket.js', { getIO: () => null, emitToAccount: () => {}, emitSyncCompleted: () => {}, emitForceLogout: () => {} });
cam('core/email.service.js', { sendMail: async () => ({ ok: true }) });

const { prisma, pool } = require(path.join(ROOT, 'config/db'));
const eventBus = require(path.join(ROOT, 'core/event-bus'));
const ocrService = require(path.join(ROOT, 'modules/ai/features/ocr/ocr.service'));
const paymentRepository = require(path.join(ROOT, 'modules/payment/payment.repository'));
const paymentService = require(path.join(ROOT, 'modules/payment/payment.service'));
const hs = require(path.join(ROOT, 'modules/household/household.service'));
const { requireFeature } = require(path.join(ROOT, 'middleware/feature-permission.middleware'));

const kq = [];
async function ca(ma, mo, mong, fn) {
  let thuc;
  try { thuc = await fn(); } catch (e) { thuc = `NÉM ${e.code || e.constructor.name}: ${String(e.message).split('\n').pop().slice(0, 90)}`; }
  kq.push({ ma, mo, mong: String(mong), thuc: String(thuc), dat: String(thuc) === String(mong) });
}
const RUN = Date.now().toString(36);
let dem = 0;
const tk = async (ten, { type = 'Basic', han = null } = {}) => {
  dem += 1;
  const a = await prisma.account.create({ data: {
    idrole: 2, email: `${ten}${RUN}${dem}@thu.local`, username: `${ten}${RUN}${dem}`, password: 'x', type, premium_expires_at: han,
  } });
  return a.idaccount;
};
const doc = (rel) => fs.readFileSync(path.join(REPO, rel), 'utf8');

/** Mọi cụm trong [cam] phải vắng khỏi [s]. Trả rỗng khi đạt, không thì liệt kê cụm còn lại. */
const conLai = (s, ds) => ds.filter((x) => s.includes(x)).join(' | ') || 'không';

(async () => {
  await pool.query(`INSERT INTO role ("Idrole","Rolename") VALUES (1,'Admin'),(2,'User') ON CONFLICT DO NOTHING`);

  // ─ T1 câu 67: socket che số tài khoản, DTO của chủ tài khoản giữ nguyên. Đi processReceipt thật, chỉ giả ảnh.
  {
    const A = await tk('ocr');
    const daPhat = [];
    const goc = eventBus.publish;
    eventBus.publish = (ten, d) => { daPhat.push({ ten, d }); };
    const trich = (thap) => ({
      document_type: 'BANK_TRANSFER', total_amount: 150000, transaction_date: new Date().toISOString(),
      transaction_code: `FT${RUN}${dem++}`, source_bank: 'MB', source_account: '0123456789', destination_bank: 'VCB',
      destination_account: '9876543210', destination_name: 'NGUOI NHAN', note: 'x', ...thap,
    });
    try {
      const u = { fullname: 'NGUOI NHAN' };
      const w = [{ idwallet: randomUUID(), name: 'V', account_number: '0123456789', type: 'Bank' }, { idwallet: randomUUID(), name: 'V2', account_number: '9876543210', type: 'Bank' }];
      const r1 = await ocrService.processReceipt(A, { image_base64: 'x', _mockExtraction: trich(), _mockUser: u, _mockWallets: w });
      const e1 = daPhat.find((x) => x.ten === 'ocr.completed');
      await ca('T1 :67', 'ocr.completed có một trong hai khối chi tiết', 'true', async () => Boolean(e1 && (e1.d.transfer_details || e1.d.transaction_info)));
      const chiTiet = e1 ? (e1.d.transfer_details || e1.d.transaction_info) : {};
      await ca('T1 :67', 'socket KHÔNG mang số tài khoản đầy đủ', 'false', async () => JSON.stringify(chiTiet).includes('0123456789') || JSON.stringify(chiTiet).includes('9876543210'));
      await ca('T1 :67', 'socket còn 4 số cuối để nhận ra tài khoản', 'true', async () => JSON.stringify(chiTiet).includes('6789'));
      const dto = r1.transfer_details || r1.transaction_info || (r1.data && (r1.data.transfer_details || r1.data.transaction_info)) || {};
      await ca('T1 :67', 'DTO trả về chủ tài khoản giữ số đầy đủ', 'true', async () => JSON.stringify(dto).includes('0123456789'));
    } finally {
      eventBus.publish = goc;
    }
  }

  // ─ T1: tài liệu
  {
    const s = doc('docs/Admin-web/Event-Notification-to-ClientApp.md');
    await ca('T1', 'hết câu nói ngược mã', 'không', async () => conLai(s, [
      'In-App Banner', 'Banner cam', 'Hiển thị Banner', 'exponential backoff', 'Dialog phong tỏa', 'Đóng popup VietQR',
      'đếm ngược tự động thử lại', 'thông báo người dùng tạm nghỉ', 'Từ Thiết Bị Khác', 'từ thiết bị khác',
      'Toast thông báo chúc mừng', 'NotificationBell', 'Backoff đếm ngược', 'Hiển thị Banner và', '9 Tín Hiệu', '9 TÍN HIỆU', 'Phát hiện hóa đơn trùng lặp',
    ]));
    await ca('T1', 'bảng 3.1 có hai sự kiện nhà', 'true', async () => /\*\*19\*\* \| `household\.changed`/.test(s) && /\*\*20\*\* \| `household\.invited`/.test(s));
    await ca('T1', 'ma trận có hai sự kiện nhà', 'true', async () => /`household\.changed` \| ✅/.test(s) && /`household\.invited` \| ✅/.test(s));
  }

  // ─ T3: tài liệu
  {
    const s = doc('docs/Functional-Mobile/4_TRU_COT.md');
    await ca('T3', 'hết câu nói ngược mã', 'không', async () => conLai(s, [
      'lộ trình tương lai', 'Chạy phân tích lại kỳ này', 'Giới hạn tối đa 15 lượt', 'Vẫn xem lại được kết quả dự báo', '15 lượt/tháng', '1 ảnh/tx',
      '20 tx/lần', '5 từ/cat', 'Điểm cơ bản', '4 banks', 'Tải hóa đơn', 'Debounce 10s', 'Chuyển chu kỳ đồng bộ về 10s', '"supported_banks": ["MB", "MOMO", "ZALOPAY"]',
    ]));
    await ca('T3', 'có đủ dòng App thi hành (≥ 8)', 'true', async () => (s.match(/App thi hành:/g) || []).length >= 8);
    await ca('T3', 'trả lại /export-report', 'true', async () => s.includes('`/export-report`, `/analytics/export`'));
  }

  // ─ T6
  {
    const s = doc('src/Backend/modules/payment/payment.repository.js');
    await ca('T6', 'mã chạy thật không còn nhánh chỉ để hợp bản giả', 'false', async () => s.includes('typeof tx.payment_transaction'));
    const t = doc('src/Backend/tests/unit/payos_group3_comprehensive_audit.test.js');
    await ca('T6', 'hết nhãn [Tier 2] trên ca giả repository', 'false', async () => t.includes('[Tier 2]'));
    // Đường thật: chỉ mục unique là của migration 38, `db push` không tạo.
    await pool.query(`CREATE UNIQUE INDEX IF NOT EXISTS uq_kiem_payos_tx ON payment_transaction (payos_transaction_id) WHERE payos_transaction_id IS NOT NULL`);
    const A = await tk('pay');
    const orderId = randomUUID();
    await prisma.payment_order.create({ data: {
      id: orderId, idaccount: A, order_code: BigInt(Date.now()), amount: 49000, status: 'PENDING', transfer_content: `T${RUN}`,
      package_type: 'Premium', expired_at: new Date(Date.now() + 6e5),
    } });
    const ref = `REF${RUN}`;
    const ghi = () => paymentRepository.recordTransaction({ id: randomUUID(), orderId, idaccount: A, payosTransactionId: ref, amount: 49000 });
    await ca('T6', 'năm webhook đua nhau cùng reference: không ném, đúng một hàng', 'không ném|1', async () => {
      await Promise.all([ghi(), ghi(), ghi(), ghi(), ghi()]);
      return `không ném|${await prisma.payment_transaction.count({ where: { payos_transaction_id: ref } })}`;
    });
    const kichHoat = () => paymentRepository.activatePremiumSubscription({
      idaccount: A, orderId, paidAt: new Date(), newExpiresAt: new Date(Date.now() + 30 * 864e5),
      transactionData: { id: randomUUID(), payosTransactionId: ref, amount: 49000 },
    });
    await ca('T6', 'kích hoạt hai lần cùng reference: không ném, vẫn một hàng', 'không ném|1', async () => {
      await kichHoat(); await kichHoat();
      return `không ném|${await prisma.payment_transaction.count({ where: { payos_transaction_id: ref } })}`;
    });
    await pool.query('DROP INDEX IF EXISTS uq_kiem_payos_tx');
  }

  // ─ 55.A3: Premium + NULL, bốn nơi và job
  {
    const P = await tk('hong', { type: 'Premium', han: null });
    const O = await tk('chu', { type: 'Premium', han: new Date(Date.now() + 30 * 864e5) });
    await hs.createHousehold(O, { name: 'Nhà thử' });
    const H = (await prisma.household_member.findFirst({ where: { idaccount: O, left_at: null } })).idhousehold;
    await prisma.account.update({ where: { idaccount: O }, data: { premium_expires_at: null } });
    await ca('55.A3', '/subscription-info: isPremium false, isExpired true', 'false|true', async () => {
      const r = await paymentService.getSubscriptionInfo(P);
      return `${r.isPremium}|${r.isExpired}`;
    });
    await ca('55.A3', 'requireFeature(household): chặn FEATURE_DISABLED', 'chặn', async () => {
      let quaDuoc = false; let trang = 200;
      const res = { status(c) { trang = c; return this; }, json() { return this; }, setHeader() {} };
      await requireFeature('household')({ user: { idaccount: P } }, res, () => { quaDuoc = true; });
      return quaDuoc || trang === 200 ? 'cho qua' : 'chặn';
    });
    await ca('55.A3', 'chủ nhà Premium + NULL: nhà về ReadOnly', 'ReadOnly', async () => {
      await hs.updateHouseholdStatusByOwner(O);
      return (await prisma.household.findUnique({ where: { idhousehold: H } })).status;
    });
    await ca('55.A3', 'job hạ cấp: Type về Basic', 'Basic', async () => {
      await paymentRepository.downgradeExpiredPremiumAccounts(new Date());
      return (await prisma.account.findUnique({ where: { idaccount: P } })).type;
    });
    const t = fs.existsSync(path.join(ROOT, 'tests/unit/premium_effective.test.js'));
    await ca('55.A3', 'có ca test trong repo', 'true', async () => t);
  }

  // ─ 60.1: hai script Test/ từ chối cả hai dạng URL Supabase. URL giả, không kết nối đi đâu.
  for (const tep of ['Test/test_sync_new_schema.js', 'Test/test_can_lam_fixes.js']) {
    for (const url of ['postgresql://u:p@db.khong-co-that.supabase.co:5432/postgres', 'postgresql://u:p@aws-0.pooler.supabase.com:6543/postgres']) {
      await ca('60.1', `${tep} từ chối ${url.split('@')[1].split(':')[0]}`, 'từ chối', async () => {
        const r = spawnSync(process.execPath, [path.join(REPO, tep)], {
          env: { ...process.env, DATABASE_URL: url, DIRECT_URL: url }, timeout: 15000, encoding: 'utf8',
        });
        return /từ chối chạy/i.test(`${r.stderr}${r.stdout}`) ? 'từ chối' : 'cho chạy';
      });
    }
  }

  // ─ 60.2
  await ca('60.2', 'kết quả verify:household không ghi vào cây mã, hoặc đã ignore', 'true', async () => {
    const s = doc('src/Backend/scripts/verify_household_contract.js');
    return s.includes('tmpdir()') || doc('.gitignore').includes('kq_household_contract');
  });

  const dat = kq.filter((k) => k.dat).length;
  const dong = [`Thư mục: ${ROOT}`, `TỔNG: ${dat} đạt / ${kq.length} ca`, ''];
  for (const k of kq) dong.push(`${k.dat ? 'ĐẠT ' : 'SAI '} [${k.ma}] ${k.mo}\n     mong: ${k.mong}\n     thực: ${k.thuc}`);
  fs.writeFileSync(DST, `${dong.join('\n')}\n`);
  console.log(`TỔNG: ${dat} đạt / ${kq.length} ca`);
  process.exit(dat === kq.length ? 0 : 1);
})().catch((e) => { console.error(e); process.exit(3); });
