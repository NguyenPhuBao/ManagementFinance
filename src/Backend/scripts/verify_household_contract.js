// Kịch bản nghiệm thu hợp đồng gia đình + AIOps, chạy THẬT trên CSDL RIÊNG, payload như app gửi (đơn 57 · 58 · 59).
// Cách chạy (từ src/Backend):
//   npm run verify:household
// Tự từ chối chạy nếu DATABASE_URL không phải CSDL flowmoney_kiem_thu trên máy này.
const path = require('path');
const fs = require('fs');
const { randomUUID } = require('crypto');

const ROOT = process.argv[2] ? path.resolve(process.argv[2]) : path.resolve(__dirname, '..');
const DST = process.argv[3] ? path.resolve(process.argv[3]) : path.resolve(__dirname, '../kq_household_contract.txt');

if (!/@(127\.0\.0\.1|localhost)(:\d+)?\/flowmoney_kiem_thu(\?|$)/.test(process.env.DATABASE_URL || '')) {
  console.error('Từ chối chạy: DATABASE_URL phải là CSDL flowmoney_kiem_thu trên máy này (kịch bản này GHI dữ liệu).');
  process.exit(2);
}

const su = []; // sự kiện socket: {den, ten, data}
const thu = []; // thư đã gửi
const cam = (rel, exportsObj) => {
  const f = path.join(ROOT, rel);
  require.cache[f] = { id: f, filename: f, loaded: true, exports: exportsObj, children: [], paths: [] };
};
cam('core/socket.js', {
  getIO: () => null,
  emitToAccount: (den, ten, data) => su.push({ den: Number(den), ten, data }),
  emitSyncCompleted: (den, data) => su.push({ den: Number(den), ten: 'sync.completed', data }),
  emitForceLogout: (den, code, reason) => su.push({ den: Number(den), ten: 'force_logout', data: { code, reason } }),
});
cam('core/email.service.js', { sendMail: async (m) => { thu.push(m); return { ok: true }; } });

const { prisma, pool } = require(path.join(ROOT, 'config/db'));
const syncService = require(path.join(ROOT, 'modules/sync/sync.service'));
const hs = require(path.join(ROOT, 'modules/household/household.service'));
const { AIOpsQuarantine } = require(path.join(ROOT, 'modules/aiops/aiops.quarantine'));
const repoMod = require(path.join(ROOT, 'modules/aiops/aiops.quarantine.repository'));
const authMw = require(path.join(ROOT, 'middleware/auth'));

const kq = [];
const ngu = (ms) => new Promise((r) => setTimeout(r, ms));
let nhip = Date.now();
const moi = () => new Date((nhip += 1000)).toISOString();
let dem = 0;
const RUN = Date.now().toString(36);
async function ca(ma, mo, mong, fn) {
  let thuc;
  try { thuc = await fn(); } catch (e) { thuc = `NÉM ${e.code || e.constructor.name}: ${String(e.message).split('\n').pop().slice(0, 90)}`; }
  const dat = String(thuc) === String(mong);
  kq.push({ ma, mo, mong: String(mong), thuc: String(thuc), dat });
}
const tk = async (ten, { premium = false } = {}) => {
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
const vi = (id, hh, nguoi, thap = {}) => ({ id, name: `V${id.slice(0, 6)}`, type: 'Cash', balance: 0, currency: 'VND', icon: 'w', color: '#fff', is_default: false, is_deleted: false, include_in_total: true, status: 'Active', update_at: moi(), idhousehold: hh, idaccount: nguoi, ...thap });
const gd = (id, w, hh, nguoi, thap = {}) => ({ id, walletId: w, categoryId: null, idwallet_transfer: null, idgoal: null, idbill: null, amount: 1000, type: 'Transaction', note: 'x', dateTransaction: new Date().toISOString(), is_deleted: false, update_at: moi(), idhousehold: hh, idaccount: nguoi, ...thap });
const dm = (id, hh, nguoi, thap = {}) => ({ id, name: `K${id.slice(0, 6)}`, namecategory: `K${id.slice(0, 6)}`, classify: 'Chi', icon: 'c', color: '#000', is_default: false, is_deleted: false, isGroup: false, parentId: null, update_at: moi(), idhousehold: hh, idaccount: nguoi, ...thap });
async function nha({ them = [] } = {}) {
  const A = await tk('chu', { premium: true });
  await hs.createHousehold(A, { name: 'Nhà thử' });
  const H = (await prisma.household_member.findFirst({ where: { idaccount: A, left_at: null } })).idhousehold;
  const ds = {};
  for (const [ten, vai] of them) {
    const id = await tk(ten);
    await prisma.household_member.create({ data: { idhousehold: H, idaccount: id, role: vai } });
    ds[ten] = id;
  }
  const W1 = randomUUID(); const W2 = randomUUID();
  const r1 = await push(A, 'wallet', vi(W1, H, A)); const r2 = await push(A, 'wallet', vi(W2, H, A));
  if (r1.status !== 'synced' || r2.status !== 'synced') throw new Error(`dựng ví hỏng: ${JSON.stringify(r1)} ${JSON.stringify(r2)}`);
  return { A, H, W1, W2, ...ds };
}

(async () => {
  await pool.query(`INSERT INTO role ("Idrole","Rolename") VALUES (1,'Admin'),(2,'User') ON CONFLICT DO NOTHING`);

  // ─ 57.1
  await ca('57.1', 'không nhà: bốn khoá', 'household,myRole,members,formerMembers|null', async () => {
    const X = await tk('x'); const r = await hs.getMyHousehold(X); return `${Object.keys(r)}|${r.household}`;
  });
  await ca('57.1', 'có nhà: khoá household', 'contributionDueDay,createAt,id,maxMembers,maxSharedWallets,name,ownerId,status', async () => {
    const { A } = await nha(); return Object.keys((await hs.getMyHousehold(A)).household).sort();
  });

  // ─ 57.2
  const e = await nha();
  const nguoiMoi = `moi${Date.now()}@thu.local`;
  await hs.createEmailInvite(e.A, { email: nguoiMoi, role: 'Member' });
  const moiA = await prisma.household_invite.findFirst({ where: { email: nguoiMoi } });
  const E = (await prisma.account.create({ data: { idrole: 2, email: nguoiMoi, username: `e${Date.now()}`, password: 'x' } })).idaccount;
  const F = await tk('khac');
  await ca('57.2', 'GET /invitations — người đăng ký sau thấy lời mời (không email trong token)', 1, async () => (await hs.getMyInvitations(E, undefined)).length);
  await ca('57.2', 'đúng người xem trước', 'Nhà thử', async () => (await hs.previewInvite({ idaccount: E }, moiA.code)).householdName);
  await ca('57.2', 'người khác /join', 'NÉM HOUSEHOLD_INVITE_WRONG_ACCOUNT', async () => { await hs.joinByCode(F, moiA.code, undefined); return 'vào được'; }).then(() => { const k = kq[kq.length - 1]; k.thuc = k.thuc.split(':')[0]; k.dat = k.thuc === k.mong; });
  await ca('57.2', 'người khác /accept', 'NÉM HOUSEHOLD_INVITE_WRONG_ACCOUNT', async () => { await hs.acceptEmailInvite(F, moiA.code, undefined); return 'vào được'; }).then(() => { const k = kq[kq.length - 1]; k.thuc = k.thuc.split(':')[0]; k.dat = k.thuc === k.mong; });
  await ca('57.2', 'người khác /decline', 'NÉM HOUSEHOLD_INVITE_WRONG_ACCOUNT', async () => { await hs.declineEmailInvite(F, moiA.code, undefined); return 'từ chối được'; }).then(() => { const k = kq[kq.length - 1]; k.thuc = k.thuc.split(':')[0]; k.dat = k.thuc === k.mong; });
  await ca('57.2 + 57.1', 'đúng người /accept trả hình dạng lồng', 'Nhà thử', async () => (await hs.acceptEmailInvite(E, moiA.code, undefined)).household.name);
  const nguoiMoi2 = `moi2${Date.now()}@thu.local`;
  await hs.createEmailInvite(e.A, { email: nguoiMoi2, role: 'Member' });
  const moiB = await prisma.household_invite.findFirst({ where: { email: nguoiMoi2 } });
  const E2 = (await prisma.account.create({ data: { idrole: 2, email: nguoiMoi2, username: `e2${Date.now()}`, password: 'x' } })).idaccount;
  await ca('57.2', 'đúng người /decline', 'true', async () => hs.declineEmailInvite(E2, moiB.code, undefined));

  // ─ 57.3
  await ca('57.3', 'thư có mã + html, tên nhà chứa thẻ đã thoát', 'có mã:true|thẻ thô:false', async () => {
    const A = await tk('chu3', { premium: true });
    await hs.createHousehold(A, { name: '<a href=x>nha</a>' });
    thu.length = 0;
    const em = `thu${Date.now()}@thu.local`;
    await hs.createEmailInvite(A, { email: em, role: 'Viewer' });
    await ngu(100);
    const inv = await prisma.household_invite.findFirst({ where: { email: em } });
    const m = thu[0] || {};
    return `có mã:${String(m.html).includes(inv.code)}|thẻ thô:${String(m.html).includes('<a href=x>')}`;
  });

  // ─ 57.4 ca 10, 12, 13
  {
    const n = await nha({ them: [['B', 'Member']] });
    const Tp = randomUUID(); const T = randomUUID(); const K = randomUUID();
    await push(n.A, 'transaction', gd(Tp, n.W1, n.H, n.A));
    await push(n.B, 'transaction', gd(T, n.W1, n.H, n.B));
    await push(n.A, 'category', dm(K, n.H, n.A));
    await ca('57.4', 'ca 10 — Member đẩy khoản của Chủ', 'HOUSEHOLD_ROLE_FORBIDDEN', async () => ma(await push(n.B, 'transaction', gd(Tp, n.W1, n.H, n.A, { amount: 2000 }))));
    await ca('57.4', 'ca 12 — Member đẩy danh mục nhà do Chủ tạo', 'synced', async () => ma(await push(n.B, 'category', dm(K, n.H, n.A, { icon: 'moi' }))));
    await ca('57.4', 'ca 13 — Chủ đẩy khoản của Member, Idaccount giữ', `synced|${n.B}`, async () => {
      const r = await push(n.A, 'transaction', gd(T, n.W1, n.H, n.B, { amount: 3000 }));
      const h = await prisma.transaction.findUnique({ where: { idtran: T } });
      return `${ma(r)}|${h.idaccount}`;
    });
    const D = await tk('ngoai');
    await ca('57.4', 'người ngoài đẩy khoản của nhà', 'HOUSEHOLD_NOT_MEMBER', async () => ma(await push(D, 'transaction', gd(T, n.W1, n.H, n.B))));
    const riengE = await tk('rieng'); const VR = randomUUID();
    await push(riengE, 'wallet', vi(VR, null, riengE));
    await ca('57.4', 'hàng riêng của người khác vẫn bị chặn', 'error:Ownership mismatch: payload.idaccount do', async () => ma(await push(D, 'wallet', vi(VR, null, riengE))));
    await ca('58.6', 'người ngoài đổi idhousehold hàng của nhà', 'HOUSEHOLD_NOT_MEMBER', async () => ma(await push(D, 'transaction', gd(T, n.W1, 999, D))));
  }

  // ─ 58.1
  {
    const n = await nha({ them: [['B', 'Member']] });
    const moiTr = { type: 'Transfer', idwallet_transfer: n.W2 };
    await ca('58.1', 'Member đẩy Transfer mới (update)', 'HOUSEHOLD_ROLE_FORBIDDEN', async () => ma(await push(n.B, 'transaction', gd(randomUUID(), n.W1, n.H, n.B, moiTr))));
    const X = randomUUID(); await push(n.B, 'transaction', gd(X, n.W1, n.H, n.B));
    await ca('58.1', 'Member đổi khoản của mình thành Transfer', 'HOUSEHOLD_ROLE_FORBIDDEN', async () => ma(await push(n.B, 'transaction', gd(X, n.W1, n.H, n.B, moiTr))));
    const Y = randomUUID(); await push(n.A, 'transaction', gd(Y, n.W1, n.H, n.A, moiTr));
    await prisma.account.update({ where: { idaccount: n.B }, data: { type: 'Premium', premium_expires_at: new Date(Date.now() + 864e5) } });
    await hs.transferOwner(n.A, n.B);
    await ca('58.1', 'Chủ cũ sửa Transfer sau khi chuyển chủ', 'HOUSEHOLD_ROLE_FORBIDDEN', async () => ma(await push(n.A, 'transaction', gd(Y, n.W1, n.H, n.A, { ...moiTr, amount: 9 }))));
    await ca('58.1', 'Chủ cũ xoá Transfer', 'HOUSEHOLD_ROLE_FORBIDDEN', async () => ma(await push(n.A, 'transaction', gd(Y, n.W1, n.H, n.A, moiTr), 'delete')));
    await ca('58.1', 'Chủ mới sửa được', 'synced', async () => ma(await push(n.B, 'transaction', gd(Y, n.W1, n.H, n.A, { ...moiTr, amount: 10 }))));
  }

  // ─ 58.2 + 59.2
  {
    const n = await nha();
    await prisma.household.update({ where: { idhousehold: n.H }, data: { max_shared_wallets: 2 } });
    const V3 = randomUUID();
    await ca('58.2', 'ví mới khi đủ trần', 'HOUSEHOLD_WALLET_LIMIT', async () => ma(await push(n.A, 'wallet', vi(V3, n.H, n.A))));
    await ca('58.2', 'sửa ví đã có khi đủ trần không bị chặn', 'synced', async () => ma(await push(n.A, 'wallet', vi(n.W1, n.H, n.A, { icon: 'moi' }))));
    await ca('59.2', 'xoá ví chưa từng lên server khi đủ trần', 'synced', async () => ma(await push(n.A, 'wallet', vi(randomUUID(), n.H, n.A), 'delete')));
    const Mm = await tk('mm'); await prisma.household_member.create({ data: { idhousehold: n.H, idaccount: Mm, role: 'Member' } });
    await ca('59.2', 'Member xoá khoản Transfer chưa từng lên server', 'synced', async () => ma(await push(Mm, 'transaction', gd(randomUUID(), n.W1, n.H, Mm, { type: 'Transfer', idwallet_transfer: n.W2 }), 'delete')));
    await push(n.A, 'wallet', vi(n.W2, n.H, n.A, { status: 'Inactive' }));
    await ca('58.2', 'lưu trữ một ví rồi đẩy lại', 'synced', async () => ma(await push(n.A, 'wallet', vi(V3, n.H, n.A))));
  }

  // ─ 58.4
  {
    const n = await nha({ them: [['B', 'Member'], ['C', 'Member']] });
    const D = await tk('ngoai'); const VD = randomUUID(); const TD = randomUUID();
    await push(D, 'wallet', vi(VD, null, D)); await push(D, 'transaction', gd(TD, VD, null, D));
    const denNha = () => su.filter((s) => [n.A, n.B, n.C].includes(s.den)).map((s) => s.ten).join(',') || 'không';
    su.length = 0;
    await ca('58.4', 'D giả idhousehold khi đẩy mới ⇒ từ chối, không ai nhận', 'HOUSEHOLD_NOT_MEMBER|không', async () => { const r = await push(D, 'transaction', gd(randomUUID(), VD, n.H, D)); return `${ma(r)}|${denNha()}`; });
    su.length = 0;
    await ca('58.4', 'D xoá hàng riêng kèm idhousehold ⇒ không ai trong nhà nhận', 'synced|không', async () => { const r = await push(D, 'transaction', { id: TD, idhousehold: n.H, idaccount: D }, 'delete'); return `${ma(r)}|${denNha()}`; });
    su.length = 0;
    await ca('58.4', 'B đẩy hợp lệ ⇒ A, C nhận sync.completed, không household.changed', 'synced|sync.completed,sync.completed', async () => { const r = await push(n.B, 'transaction', gd(randomUUID(), n.W1, n.H, n.B)); return `${ma(r)}|${denNha()}`; });
    const TB = randomUUID(); await push(n.B, 'transaction', gd(TB, n.W1, n.H, n.B));
    su.length = 0;
    await ca('58.4', 'B đẩy hàng của nhà KHÔNG có khoá idhousehold ⇒ A, C vẫn nhận', 'synced|sync.completed,sync.completed', async () => { const p = gd(TB, n.W1, n.H, n.B); delete p.idhousehold; const r = await push(n.B, 'transaction', p); return `${ma(r)}|${denNha()}`; });
  }

  // ─ 59.1
  {
    const n = await nha({ them: [['B', 'Member']] });
    const Ee = await tk('nannhan'); const K = randomUUID(); await push(n.A, 'category', dm(K, n.H, n.A));
    const hd = randomUUID();
    await ca('59.1', 'Member đẩy hoá đơn mới vào tài khoản người khác', 'từ chối|0 hàng', async () => {
      const r = await push(n.B, 'bill', { id: hd, idaccount: Ee, idhousehold: n.H, idwallet: n.W1, idcategory: K, name: 'la', amount: 5, due_date: new Date().toISOString(), update_at: moi() });
      const so = await prisma.bill.count({ where: { idaccount: Ee } });
      return `${r.status === 'synced' ? 'ghi được' : 'từ chối'}|${so} hàng`;
    });
    await ca('59.1', 'Member tạo khoản mới mang tên Chủ', 'từ chối', async () => { const r = await push(n.B, 'transaction', gd(randomUUID(), n.W1, n.H, n.A)); return r.status === 'synced' ? 'ghi được' : 'từ chối'; });
    await ca('59.1', 'Member tạo khoản mới của mình', 'synced', async () => ma(await push(n.B, 'transaction', gd(randomUUID(), n.W1, n.H, n.B))));
    await ca('59.1', 'hoá đơn riêng của chính mình kèm idhousehold rác vẫn ghi', 'synced', async () => { const V = randomUUID(); await push(Ee, 'wallet', vi(V, null, Ee)); const K2 = randomUUID(); await push(Ee, 'category', dm(K2, null, Ee)); return ma(await push(Ee, 'bill', { id: randomUUID(), idaccount: Ee, idhousehold: 123456, idwallet: V, idcategory: K2, name: 'r', amount: 5, due_date: new Date().toISOString(), update_at: moi() })); });
  }

  // ─ 59.3
  await ca('59.3', 'danh mục mới is_default: true từ client', 'không thành khuôn', async () => {
    const X = await tk('x'); const id = randomUUID();
    const r = await push(X, 'category', dm(id, null, X, { is_default: true }));
    const h = await prisma.category.findUnique({ where: { idcategory: id } });
    return (r.status === 'synced' && h?.is_default) ? 'thành khuôn toàn cục' : 'không thành khuôn';
  });

  // ─ 57.6 + 58.3
  {
    const n = await nha({ them: [['B', 'Member'], ['C', 'Member']] });
    const T = randomUUID(); const K = randomUUID();
    await push(n.B, 'transaction', gd(T, n.W1, n.H, n.B)); await push(n.A, 'category', dm(K, n.H, n.A));
    const m = await hs.createInviteCode(n.A, { role: 'Member' });
    su.length = 0;
    await ca('57.6', 'POST /dissolve chạy được', 'true', async () => hs.dissolveHousehold(n.A));
    await ngu(150);
    await ca('58.3', 'A, B, C mỗi người đúng một HOUSEHOLD_DISSOLVED', '1,1,1', async () => [n.A, n.B, n.C].map((id) => su.filter((s) => s.den === id && s.ten === 'household.changed' && s.data.eventType === 'HOUSEHOLD_DISSOLVED').length));
    await ca('57.6', 'mọi hàng của nhà có cột xoá + server_update_at mới', 'xoá:true,true,true|server:true,true,true', async () => {
      const w = await prisma.wallet.findUnique({ where: { idwallet: n.W1 } });
      const t = await prisma.transaction.findUnique({ where: { idtran: T } });
      const c = await prisma.category.findUnique({ where: { idcategory: K } });
      const moc = Date.now() - 5000;
      return `xoá:${!!w.delete_at},${!!t.deleted_at},${!!c.delete_at}|server:${+w.server_update_at > moc},${+t.server_update_at > moc},${+c.server_update_at > moc}`;
    });
    await ca('57.6', 'mã chưa dùng bị từ chối', 'NÉM HOUSEHOLD_INVITE_INVALID', async () => { await hs.previewInvite({ idaccount: n.A }, m.code); return 'xem được'; }).then(() => { const k = kq[kq.length - 1]; k.thuc = k.thuc.split(':')[0]; k.dat = k.thuc === k.mong; });
  }

  // ─ 57.7 + 57.8 #6
  {
    const n = await nha({ them: [['B', 'Member'], ['C', 'Member']] });
    const em = `dem${Date.now()}@thu.local`;
    await hs.createEmailInvite(n.A, { email: em, role: 'Member' });
    const Ex = (await prisma.account.create({ data: { idrole: 2, email: em, username: `dem${Date.now()}`, password: 'x' } })).idaccount;
    await ca('57.8 #6', 'memberCount nhà 3 người', '3', async () => (await hs.getMyInvitations(Ex, undefined))[0].memberCount);
    const m = await hs.createInviteCode(n.A, { role: 'Member' });
    await prisma.household.update({ where: { idhousehold: n.H }, data: { status: 'ReadOnly' } });
    const Y = await tk('y');
    await ca('57.7', 'nhà ReadOnly: /join bị từ chối', 'NÉM HOUSEHOLD_READ_ONLY', async () => { await hs.joinByCode(Y, m.code, undefined); return 'vào được'; }).then(() => { const k = kq[kq.length - 1]; k.thuc = k.thuc.split(':')[0]; k.dat = k.thuc === k.mong; });
  }

  // ─ 58.5 — CSDL thật + quét thật
  {
    const R = repoMod.AIOpsQuarantineRepository || repoMod.default || repoMod;
    const repo = new R();
    await repo.initTables();
    const q = new AIOpsQuarantine({ repository: repo, autoExpire: false });
    const moKhoa = async () => { await ngu(350); await q.sweepExpiredQuarantines(); await ngu(250); };
    const doc = async (id) => { const a = await prisma.account.findUnique({ where: { idaccount: id } }); return `${a.status}|${a.reason_inactive}`; };
    const khoaAi = async (username, ip) => { q.quarantinePair({ ip, username, reason: `Tấn công dò mật khẩu Brute-Force (15 lần đăng nhập sai - Mục tiêu: ${username})`, durationMs: 200 }); await ngu(120); };

    const X = await tk('x'); const xn = (await prisma.account.findUnique({ where: { idaccount: X } })).username;
    su.length = 0;
    await khoaAi(xn, '8.8.8.1');
    await ca('58.5', 'force_logout không lộ dấu', 'false', async () => su.some((s) => s.ten === 'force_logout' && String(s.data.reason).includes('[AIOPS')));
    await moKhoa();
    await ca('58.5', '(1) AIOps khoá → quá hạn → mở', 'Active|null', () => doc(X));

    const Y = await tk('y'); const yn = (await prisma.account.findUnique({ where: { idaccount: Y } })).username;
    await prisma.account.update({ where: { idaccount: Y }, data: { status: 'Inactive', reason_inactive: 'Gian lan - admin' } });
    await khoaAi(yn, '8.8.8.2'); await moKhoa();
    await ca('58.5', '(2) admin khoá → AIOps → sau hạn vẫn khoá, lý do giữ', 'Inactive|Gian lan - admin', () => doc(Y));

    const P = await tk('p'); const pn = (await prisma.account.findUnique({ where: { idaccount: P } })).username;
    await q.permanentBanAccount(pn, { bannedBy: 'admin' }); await ngu(120);
    const lyDoP = (await prisma.account.findUnique({ where: { idaccount: P } })).reason_inactive;
    await khoaAi(pn, '8.8.8.3'); await moKhoa();
    await ca('58.5', '(3) khoá vĩnh viễn → AIOps từ IP khác → vẫn khoá', `Inactive|${lyDoP}`, () => doc(P));

    const Rs = await tk('r'); const rn = (await prisma.account.findUnique({ where: { idaccount: Rs } })).username;
    await khoaAi(rn, '8.8.8.4'); await ngu(350);
    const q2 = new AIOpsQuarantine({ repository: repo, autoExpire: false });
    await q2.hydrateFromDatabase(); await ngu(300);
    await ca('58.5', '(4) khởi động lại qua mốc hạn → mở', 'Active|null', () => doc(Rs));

    const Ad = await tk('Admin_0'); const an = (await prisma.account.findUnique({ where: { idaccount: Ad } })).username;
    await khoaAi(an, '8.8.8.5'); await moKhoa();
    await ca('58.5', '(5) username chứa Admin → tự mở', 'Active|null', () => doc(Ad));

    const Z = await tk('z'); const zn = (await prisma.account.findUnique({ where: { idaccount: Z } })).username;
    await prisma.account.update({ where: { idaccount: Z }, data: { status: 'Inactive', reason_inactive: 'Khoa theo canh bao AIOps' } });
    await pool.query(`INSERT INTO aiops_account_quarantine (id, username, status, reason, expires_at) VALUES ($1, $2, 'TEMPORARY', 'r', NOW() - INTERVAL '1 minute')`, [randomUUID().slice(0, 30), zn]);
    await moKhoa();
    await ca('58.5', '(6) admin khoá lý do chứa AIOps → không tự mở', 'Inactive|Khoa theo canh bao AIOps', () => doc(Z));

    if (authMw.accountRejection) {
      await ca('58.5', '(7) message 401 không chứa dấu', 'false', async () => authMw.accountRejection({ valid: false, status: 'Inactive', reason_inactive: '[AIOPS_AUTO_QUARANTINE]: x' }, 1).message.includes('[AIOPS'));
    }
    const Pd = await tk('pd'); const pdn = (await prisma.account.findUnique({ where: { idaccount: Pd } })).username;
    await prisma.account.update({ where: { idaccount: Pd }, data: { status: 'PendingDelete' } });
    su.length = 0;
    await khoaAi(pdn, '8.8.8.6');
    await ca('58.6', 'PendingDelete không bị khoá, không force_logout', 'PendingDelete|0', async () => `${(await prisma.account.findUnique({ where: { idaccount: Pd } })).status}|${su.filter((s) => s.ten === 'force_logout' && s.den === Pd).length}`);
    q.stopAutoExpireTimer(); q2.stopAutoExpireTimer();
  }

  const dat = kq.filter((k) => k.dat).length;
  const dong = [`Thư mục: ${ROOT}`, `TỔNG: ${dat} đạt / ${kq.length} ca`, ''];
  for (const k of kq) dong.push(`${k.dat ? 'ĐẠT  ' : 'TRƯỢT'} | ${k.ma} | ${k.mo} | mong: ${k.mong}${k.dat ? '' : ` | thực: ${k.thuc}`}`);
  console.log(dong.slice(0, 2).join('\n'));
  if (DST) fs.writeFileSync(DST, dong.join('\n') + '\n', 'utf8');
  process.exit(dat === kq.length ? 0 : 1);
})().catch((e) => {
  kq.push({ dat: false, ma: 'KỊCH BẢN', mo: 'dừng giữa chừng', mong: '-', thuc: `${e.code || ''} ${e.message}`.slice(0, 400) });
  const dong = kq.map((k) => `${k.dat ? 'ĐẠT  ' : 'TRƯỢT'} | ${k.ma} | ${k.mo} | mong: ${k.mong}${k.dat ? '' : ` | thực: ${k.thuc}`}`);
  if (DST) fs.writeFileSync(DST, dong.join('\n') + '\n', 'utf8');
  process.exit(1);
});

