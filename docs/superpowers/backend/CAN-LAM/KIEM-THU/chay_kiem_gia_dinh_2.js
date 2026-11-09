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
const muctieu = (id, hh, nguoi, thap = {}) => ({ id, name: `M${id.slice(0, 6)}`, targetAmount: 1000000, currentAmount: 0, targetDate: new Date(Date.now() + 90 * 864e5).toISOString(), idhousehold: hh, idaccount: nguoi, is_deleted: false, update_at: moi(), ...thap });

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

  // Danh mục sai phạm vi (đợt 1B, Task 1): ca 2 là ca canh hồi quy, xanh ngay trước khi sửa.
  const dm = (id, hh, nguoi, thap = {}) => ({ id, name: `K${id.slice(0, 6)}`, namecategory: `K${id.slice(0, 6)}`, classify: 'Chi', icon: 'c', color: '#000', is_default: false, is_deleted: false, isGroup: false, parentId: null, update_at: moi(), idhousehold: hh, idaccount: nguoi, ...thap });
  const DMN = randomUUID();
  const DMR = randomUUID();
  await push(A, 'category', dm(DMN, H, A));
  await push(B, 'category', dm(DMR, null, B));
  await ca('2a', 'khoản nhà trỏ danh mục riêng bị từ chối', 'HOUSEHOLD_SCOPE_MISMATCH',
    async () => ma(await push(B, 'transaction', gd(randomUUID(), W, H, B, { categoryId: DMR }), 'create')));
  await ca('2a', 'khoản nhà trỏ danh mục của nhà được nhận', 'synced',
    async () => ma(await push(B, 'transaction', gd(randomUUID(), W, H, B, { categoryId: DMN }), 'create')));
  await ca('2a', 'khoản riêng trỏ danh mục của nhà bị từ chối', 'HOUSEHOLD_SCOPE_MISMATCH',
    async () => ma(await push(B, 'transaction', gd(randomUUID(), VR, null, B, { categoryId: DMN }), 'create')));
  // 63.2: ngân sách của nhà trỏ danh mục riêng; khoản của nhà trỏ khuôn mặc định (khuôn không thuộc nhà nào).
  await ca('63.2', 'ngân sách nhà trỏ danh mục riêng bị từ chối', 'HOUSEHOLD_SCOPE_MISMATCH',
    async () => ma(await push(A, 'budget', { id: randomUUID(), categoryId: DMR, idhousehold: H, idaccount: A, amount: 1000, update_at: moi() }, 'create')));
  const KHUON = randomUUID();
  await prisma.category.create({ data: { idcategory: KHUON, create_by: 1, name_category: `Khuon${RUN}`, classify: 'Chi', is_default: true } });
  await ca('63.2', 'khoản nhà trỏ khuôn mặc định bị từ chối', 'HOUSEHOLD_SCOPE_MISMATCH',
    async () => ma(await push(B, 'transaction', gd(randomUUID(), W, H, B, { categoryId: KHUON }), 'create')));

  const G = randomUUID();
  await ca('2a', 'Chủ nhà đẩy mục tiêu của nhà', 'synced', async () => ma(await push(A, 'goal', muctieu(G, H, A), 'create')));
  const GX = randomUUID();
  await ca('2a', 'giao dịch riêng trỏ mục tiêu của nhà bị từ chối', 'HOUSEHOLD_SCOPE_MISMATCH', async () => ma(await push(B, 'transaction', gd(GX, VR, null, B, { idgoal: G }), 'create')));

  // Đợt 2: mục tiêu chung (docs/Family/03). Cần database/46 trên CSDL thử.
  const W2 = randomUUID();
  await push(A, 'wallet', vi(W2, H, A));
  const G1 = randomUUID();
  await ca('3', 'Thành viên đặt mục tiêu của nhà bị từ chối', 'HOUSEHOLD_ROLE_FORBIDDEN',
    async () => ma(await push(B, 'goal', muctieu(randomUUID(), H, B, { idwallet: W2 }), 'create')));
  await ca('3', 'mục tiêu của nhà trỏ ví riêng bị từ chối', 'HOUSEHOLD_SCOPE_MISMATCH',
    async () => ma(await push(A, 'goal', muctieu(randomUUID(), H, A, { idwallet: VR }), 'create')));
  await ca('3', 'Chủ nhà đặt mục tiêu cho ví chung', 'synced',
    async () => ma(await push(A, 'goal', muctieu(G1, H, A, { idwallet: W2 }), 'create')));
  await ca('3', 'mục tiêu sống thứ hai cùng ví bị từ chối', 'UNIQUE_VIOLATION',
    async () => ma(await push(A, 'goal', muctieu(randomUUID(), H, A, { idwallet: W2 }), 'create')));
  await ca('3', 'Thành viên kéo về thấy mục tiêu của nhà', 1,
    async () => (await syncRepo.getGoalsByAccount(B, null, H)).filter((g) => g.idgoal === G1).length);
  // Ghi nhận hành vi: vì sao client hồi sinh hàng khi bật lại (quyết định Q1 của kế hoạch).
  await ca('3', 'cùng một lô: lệnh tạo chạy trước lệnh xoá nên vướng chỉ mục', 'UNIQUE_VIOLATION', async () => {
    const r = await syncService.processPush(A, [
      { localId: 'xoa', entity: 'goal', operation: 'delete', payload: muctieu(G1, H, A, { idwallet: W2 }) },
      { localId: 'tao', entity: 'goal', operation: 'create', payload: muctieu(randomUUID(), H, A, { idwallet: W2 }) },
    ]);
    return ma(r.results.find((x) => x.localId === 'tao'));
  });
  const G2 = randomUUID();
  await ca('3', 'lô sau, lệnh xoá đã xong: bật lại bằng hàng mới được nhận', 'synced',
    async () => ma(await push(A, 'goal', muctieu(G2, H, A, { idwallet: W2 }), 'create')));
  // Chủ mới tắt mục tiêu do Chủ cũ đặt. Đi đường chuyển chủ của service: `uq_household_one_owner` chỉ cho một Owner sống,
  // `transferOwner` hạ A trước, nâng C sau trong một giao tác.
  const C = await tk('chu2', true);
  await prisma.household_member.create({ data: { idhousehold: H, idaccount: C, role: 'Member' } });
  await hs.transferOwner(A, C);
  await ca('3', 'Chủ mới tắt được mục tiêu do Chủ cũ đặt', 'synced|true', async () => {
    const r = await push(C, 'goal', muctieu(G2, H, A, { idwallet: W2 }), 'delete');
    const g = await prisma.goal.findUnique({ where: { idgoal: G2 } });
    return `${ma(r)}|${g.delete_at !== null}`;
  });

  // 64.1: vào, rời, vào lại, rời, vào lại. `formerMembers` chỉ gồm người đã rời, mỗi người một lần.
  const R = await tk('roi');
  const vao = () => prisma.household_member.create({ data: { idhousehold: H, idaccount: R, role: 'Member' } });
  const soLanTrongDs = async () => (await hs.getMyHousehold(C)).formerMembers.filter((m) => m.idaccount === R).length;
  await vao();
  await hs.leaveHousehold(R);
  await vao();
  await ca('64.1', 'đã vào lại thì không còn trong formerMembers', 0, soLanTrongDs);
  await hs.leaveHousehold(R);
  await vao();
  await hs.leaveHousehold(R);
  await ca('64.1', 'rời nhiều lần chỉ xuất hiện một lần', 1, soLanTrongDs);

  const dat =kq.filter((k) => k.startsWith('ĐẠT')).length;
  kq.push(`${dat} đạt / ${kq.length} ca`);
  const ra = kq.join('\n');
  console.log(ra);
  if (DST) fs.writeFileSync(DST, `${ra}\n`);
  process.exit(ra.includes('HỎNG') ? 1 : 0);
})().catch((e) => { console.error('LOI', e); process.exit(1); });
