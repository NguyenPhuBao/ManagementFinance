// Kịch bản nghiệm thu gia đình 2a, chạy THẬT trên CSDL riêng flowmoney_kiem_thu. Socket và thư là bản giả.
// Từ src/Backend: DATABASE_URL=<...flowmoney_kiem_thu> DIRECT_URL=<như trên> NODE_ENV=development \
//   LOG_LEVEL=error REDIS_PROVIDER=none REDIS_URL= \
//   node ../../docs/superpowers/backend/CAN-LAM/KIEM-THU/chay_kiem_gia_dinh_2.js . <tệp kết quả NGOÀI cây mã>
// Dòng cuối phải là "N đạt / N ca". Có ca hỏng thì mã thoát 1.
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');

const ROOT = path.resolve(process.argv[2] || '.');
const DST = process.argv[3];
if (!/@(127\.0\.0\.1|localhost)(:\d+)?\/flowmoney_kiem_thu(\?|$)/.test(process.env.DATABASE_URL || '')) {
  console.error('Từ chối chạy: DATABASE_URL phải là flowmoney_kiem_thu trên máy này');
  process.exit(2);
}
const cam = (rel, exportsObj) => {
  const f = path.join(ROOT, rel);
  require.cache[f] = { id: f, filename: f, loaded: true, exports: exportsObj, children: [], paths: [] };
};
cam('core/socket.js', { getIO: () => null, emitToAccount: () => {}, emitSyncCompleted: () => {}, emitForceLogout: () => {} });
cam('core/email.service.js', { sendMail: async () => ({ ok: true }) });

const { prisma, pool } = require(path.join(ROOT, 'config/db'));
const syncService = require(path.join(ROOT, 'modules/sync/sync.service'));
const syncRepo = require(path.join(ROOT, 'modules/sync/sync.repository'));
const hs = require(path.join(ROOT, 'modules/household/household.service'));

const RUN = Date.now().toString(36);
let dem = 0;
let nhip = Date.now();
const moi = () => new Date((nhip += 1000)).toISOString();
const kq = [];
const ca = async (ma, mo, mong, fn) => {
  let thuc;
  try { thuc = await fn(); } catch (e) { thuc = `NÉM ${e.code || e.message}`; }
  const dat = String(thuc) === String(mong);
  kq.push(`${dat ? 'ĐẠT ' : 'HỎNG'} | ${ma} | ${mo}${dat ? '' : ` | mong ${mong}, ra ${thuc}`}`);
};
const tk = async (ten, premium = false) => {
  dem += 1;
  const a = await prisma.account.create({ data: {
    idrole: 2, email: `${ten}${RUN}${dem}@thu.local`, username: `${ten}${RUN}${dem}`, password: 'x',
    type: premium ? 'Premium' : 'Basic', premium_expires_at: premium ? new Date(Date.now() + 30 * 864e5) : null,
  } });
  return a.idaccount;
};
const push = async (id, entity, payload, operation = 'update') => {
  const r = await syncService.processPush(id, [{ localId: 'x', entity, operation, payload: { ...payload } }]);
  return r.results[0];
};
const ma = (r) => (r.status === 'synced' ? 'synced' : (r.code || `error:${String(r.message).slice(0, 40)}`));
// Server chỉ ánh xạ updatedAt / update_at (sync.repository.js): dùng update_at, không updated_at.
const vi = (id, hh, nguoi) => ({ id, name: `V${id.slice(0, 6)}`, type: 'Cash', balance: 0, currency: 'VND', icon: 'w', color: '#000000', is_default: false, include_in_total: false, status: 'Active', idhousehold: hh, idaccount: nguoi, is_deleted: false, update_at: moi() });
const gd = (id, w, hh, nguoi, thap = {}) => ({ id, walletId: w, categoryId: null, idwallet_transfer: null, idgoal: null, idbill: null, amount: 2000, type: 'Transaction', note: 'thu', date: moi(), is_deleted: false, update_at: moi(), idhousehold: hh, idaccount: nguoi, ...thap });
const muctieu = (id, hh, nguoi) => ({ id, name: `M${id.slice(0, 6)}`, targetAmount: 1000000, currentAmount: 0, targetDate: new Date(Date.now() + 90 * 864e5).toISOString(), idhousehold: hh, idaccount: nguoi, is_deleted: false, update_at: moi() });

(async () => {
  await pool.query(`INSERT INTO role ("Idrole","Rolename") VALUES (1,'Admin'),(2,'User') ON CONFLICT DO NOTHING`);
  const A = await tk('chu', true);
  await hs.createHousehold(A, { name: 'Nhà thử' });
  const H = (await prisma.household_member.findFirst({ where: { idaccount: A, left_at: null } })).idhousehold;
  const B = await tk('tv');
  await prisma.household_member.create({ data: { idhousehold: H, idaccount: B, role: 'Member' } });
  const W = randomUUID();
  await push(A, 'wallet', vi(W, H, A));
  const VR = randomUUID();
  await push(B, 'wallet', vi(VR, null, B));

  const P = randomUUID();
  const NN = randomUUID();
  await ca('2a', 'tạo nửa của nhà có mã cặp', 'synced', async () => ma(await push(B, 'transaction', gd(NN, W, H, B, { idfund_pair: P }), 'create')));
  await ca('2a', 'CSDL lưu mã cặp', P, async () => (await prisma.transaction.findUnique({ where: { idtran: NN } })).idfund_pair);
  const NR = randomUUID();
  await ca('2a', 'tạo nửa riêng có mã cặp', 'synced', async () => ma(await push(B, 'transaction', gd(NR, VR, null, B, { idfund_pair: P, amount: -2000 }), 'create')));
  await ca('2a', 'pull trả mã cặp cho người góp', P, async () => {
    const ds = await syncRepo.getTransactionsByAccount(B, null, H);
    return ds.find((t) => t.idtran === NR).idfund_pair;
  });
  await ca('2a', 'nửa riêng không về máy Chủ nhà', 0, async () => {
    const ds = await syncRepo.getTransactionsByAccount(A, null, H);
    return ds.filter((t) => t.idtran === NR).length;
  });
  await ca('2a', 'người ghi sửa được', 'synced', async () => ma(await push(B, 'transaction', gd(NN, W, H, B, { idfund_pair: P, amount: 3000 }))));
  await ca('2a', 'lượt sửa thật sự ghi amount = 3000', 3000, async () => Number((await prisma.transaction.findUnique({ where: { idtran: NN } })).amount));
  await ca('2a', 'sửa không mang khoá không xoá mã cặp (amount thành 3500)', `${P}|3500`, async () => {
    await push(B, 'transaction', gd(NN, W, H, B, { amount: 3500 }));
    const t = await prisma.transaction.findUnique({ where: { idtran: NN } });
    return `${t.idfund_pair}|${Number(t.amount)}`;
  });
  await ca('2a', 'Chủ nhà sửa khoản góp của người khác bị từ chối', 'HOUSEHOLD_ROLE_FORBIDDEN', async () => ma(await push(A, 'transaction', gd(NN, W, H, B, { idfund_pair: P, amount: 9000 }))));
  await ca('2a', 'sau lượt sửa, pull trả đúng mã và amount mới', `${P}|3500`, async () => {
    const t = (await syncRepo.getTransactionsByAccount(B, null, H)).find((x) => x.idtran === NN);
    return `${t.idfund_pair}|${Number(t.amount)}`;
  });
  await ca('2a', 'người ghi gửi idfund_pair null tường minh: mã giữ nguyên', P, async () => {
    await push(B, 'transaction', gd(NN, W, H, B, { idfund_pair: null, amount: 3600 }));
    return (await prisma.transaction.findUnique({ where: { idtran: NN } })).idfund_pair;
  });
  await ca('2a', 'người ghi gửi idfund_pair rỗng: mã giữ nguyên', P, async () => {
    await push(B, 'transaction', gd(NN, W, H, B, { idfund_pair: '', amount: 3700 }));
    return (await prisma.transaction.findUnique({ where: { idtran: NN } })).idfund_pair;
  });
  await ca('2a', 'Chủ nhà update + is_deleted trên khoản có mã của người khác bị từ chối', 'HOUSEHOLD_ROLE_FORBIDDEN', async () => ma(await push(A, 'transaction', gd(NN, W, H, B, { idfund_pair: P, is_deleted: true, amount: 9000 }))));
  await ca('2a', 'khoản ấy không đổi amount / deleted_at', '3700|null', async () => {
    const t = await prisma.transaction.findUnique({ where: { idtran: NN } });
    return `${Number(t.amount)}|${t.deleted_at}`;
  });
  await ca('2a', 'Chủ nhà create đè lên hàng có mã của người khác bị từ chối', 'HOUSEHOLD_ROLE_FORBIDDEN', async () => ma(await push(A, 'transaction', gd(NN, W, H, B, { idfund_pair: P, amount: 9100 }), 'create')));
  const KA = randomUUID();
  await push(A, 'transaction', gd(KA, W, H, A), 'create');
  await ca('2a', 'Thành viên create đè lên khoản thường của người khác bị từ chối', 'HOUSEHOLD_ROLE_FORBIDDEN', async () => ma(await push(B, 'transaction', gd(KA, W, H, B, { amount: 9200 }), 'create')));
  await ca('2a', 'Chủ nhà xoá khoản góp của người khác được', 'synced|có deleted_at', async () => {
    const r = ma(await push(A, 'transaction', gd(NN, W, H, B, { idfund_pair: P, is_deleted: true }), 'delete'));
    const t = await prisma.transaction.findUnique({ where: { idtran: NN } });
    return `${r}|${t.deleted_at ? 'có deleted_at' : 'deleted_at null'}`;
  });
  const T = randomUUID();
  await ca('2a', 'Transfer không được mang mã cặp', 'HOUSEHOLD_SCOPE_MISMATCH', async () => ma(await push(A, 'transaction', gd(T, W, H, A, { type: 'Transfer', idwallet_transfer: W, idfund_pair: randomUUID() }), 'create')));
  const K = randomUUID();
  await push(B, 'transaction', gd(K, W, H, B), 'create');
  await ca('2a', 'Chủ nhà vẫn sửa được khoản thường của Thành viên', 'synced', async () => ma(await push(A, 'transaction', gd(K, W, H, B, { amount: 1000 }))));

  const G = randomUUID();
  await ca('2a', 'Chủ nhà đẩy mục tiêu của nhà', 'synced', async () => ma(await push(A, 'goal', muctieu(G, H, A), 'create')));
  const GX = randomUUID();
  await ca('2a', 'giao dịch riêng trỏ mục tiêu của nhà bị từ chối', 'HOUSEHOLD_SCOPE_MISMATCH', async () => ma(await push(B, 'transaction', gd(GX, VR, null, B, { idgoal: G }), 'create')));

  const dat = kq.filter((k) => k.startsWith('ĐẠT')).length;
  kq.push(`${dat} đạt / ${kq.length} ca`);
  const ra = kq.join('\n');
  console.log(ra);
  if (DST) fs.writeFileSync(DST, `${ra}\n`);
  process.exit(ra.includes('HỎNG') ? 1 : 0);
})().catch((e) => { console.error('LOI', e); process.exit(1); });
