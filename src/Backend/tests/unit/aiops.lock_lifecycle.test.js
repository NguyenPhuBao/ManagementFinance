/**
 * Mục 2.1–2.2 kế hoạch sửa trang AIOps (docs/superpowers/specs/2026-11-16-aiops-sua-loi-design.md):
 * - Admin tạm khoá tài khoản: hết hạn thì tự mở (account.status về Active), dòng theo dõi chuyển UNLOCKED.
 * - Khoá vĩnh viễn: không tự mở.
 * - Mọi khoá đều có dòng theo dõi (kể cả tài khoản chưa dính sự cố); mở khoá thì dòng vẫn còn trong danh sách,
 *   và danh sách đọc từ kho lưu (không mất khi khởi động lại).
 * Bảng account được giả lập trong bộ nhớ qua prisma.account (findFirst / findMany / updateMany).
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const { AIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
const { AIOpsQuarantineRepository } = require('../../modules/aiops/aiops.quarantine.repository');
const { AIOPS_AUTO_REASON_PREFIX, AIOPS_ADMIN_TEMP_PREFIX, AIOPS_ADMIN_BAN_PREFIX, lyDoChoNguoiDung } = require('../../modules/aiops/aiops.reason');
const { prisma } = require('../../config/db');

// ── Bảng account giả lập + bộ so điều kiện where của Prisma (đủ cho các dạng mã AIOps dùng) ──
let accounts = [];
const matches = (row, where) => {
  if (!where) return true;
  return Object.entries(where).every(([key, cond]) => {
    if (key === 'AND') return cond.every((c) => matches(row, c));
    if (key === 'OR') return cond.some((c) => matches(row, c));
    const v = row[key];
    if (cond && typeof cond === 'object') {
      if ('startsWith' in cond) return typeof v === 'string' && v.startsWith(cond.startsWith);
      if ('not' in cond) return v !== cond.not;
      if ('in' in cond) return cond.in.includes(v);
      if ('equals' in cond) return v === cond.equals;
    }
    return v === cond;
  });
};
const original = {};
const installFakeAccounts = () => {
  for (const k of ['findFirst', 'findMany', 'updateMany']) original[k] = prisma.account[k];
  prisma.account.findFirst = async ({ where } = {}) => accounts.find((r) => matches(r, where)) || null;
  prisma.account.findMany = async ({ where } = {}) => accounts.filter((r) => matches(r, where));
  prisma.account.updateMany = async ({ where, data }) => {
    const hit = accounts.filter((r) => matches(r, where));
    hit.forEach((r) => Object.assign(r, data));
    return { count: hit.length };
  };
};
const restoreAccounts = () => {
  for (const k of Object.keys(original)) prisma.account[k] = original[k];
};
const account = (username) => accounts.find((r) => r.username === username);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const make = (repository = new AIOpsQuarantineRepository({ pool: null })) => ({
  repository,
  q: new AIOpsQuarantine({ repository, autoExpire: false, io: null }),
});

test('AIOps — vòng đời khoá tài khoản / IP và danh sách khoá (mục 2.1, 2.2)', async (t) => {
  installFakeAccounts();
  t.after(restoreAccounts);
  t.beforeEach(() => {
    accounts = [
      { idaccount: 11, username: 'binh', status: 'Active', reason_inactive: null, idrole: 2 },
      { idaccount: 12, username: 'chi', status: 'Active', reason_inactive: null, idrole: 2 },
    ];
  });

  await t.test('1. Lý do trả cho app bỏ mọi tiền tố nội bộ của AIOps', () => {
    assert.equal(lyDoChoNguoiDung(`${AIOPS_AUTO_REASON_PREFIX}: Dò mật khẩu`), 'Dò mật khẩu');
    assert.equal(lyDoChoNguoiDung(`${AIOPS_ADMIN_TEMP_PREFIX} Quản trị viên tạm khóa 4 giờ`), 'Quản trị viên tạm khóa 4 giờ');
    assert.equal(lyDoChoNguoiDung(`${AIOPS_ADMIN_BAN_PREFIX} Khóa do vi phạm`), 'Khóa do vi phạm');
    assert.equal(lyDoChoNguoiDung('Vi phạm điều khoản'), 'Vi phạm điều khoản');
  });

  await t.test('2. Tạm khoá tài khoản chưa dính sự cố: account Inactive có dấu tạm khoá, có dòng theo dõi TEMPORARY, hiện trong danh sách', async () => {
    const { q, repository } = make();
    await q.temporaryBlockAccount('binh', { durationMs: 4 * 3600e3, blockedBy: 'admin.a' });
    assert.equal(account('binh').status, 'Inactive');
    assert.ok(account('binh').reason_inactive.startsWith(AIOPS_ADMIN_TEMP_PREFIX), account('binh').reason_inactive);
    assert.match(account('binh').reason_inactive, /4 giờ/);
    const row = await repository.getAccountByUsername('binh');
    assert.equal(row?.status, 'TEMPORARY');
    assert.equal(row.idaccount, 11);
    assert.ok(Math.abs(new Date(row.expires_at).getTime() - (Date.now() + 4 * 3600e3)) < 5000);
    const list = await q.listQuarantines();
    const item = list.find((x) => x.username === 'binh');
    assert.ok(item, 'tài khoản khoá thủ công phải có trong danh sách');
    assert.equal(item.accountStatus, 'temporary');
    assert.equal(item.ipHash, null);
  });

  await t.test('3. Hết hạn tạm khoá: tự mở account và dòng theo dõi chuyển UNLOCKED nhưng vẫn ở lại danh sách', async () => {
    const { q, repository } = make();
    await q.temporaryBlockAccount('binh', { durationMs: 5, blockedBy: 'admin.a' });
    await sleep(20);
    await q.sweepExpiredQuarantines();
    assert.equal(account('binh').status, 'Active');
    assert.equal(account('binh').reason_inactive, null);
    assert.equal((await repository.getAccountByUsername('binh')).status, 'UNLOCKED');
    const item = (await q.listQuarantines()).find((x) => x.username === 'binh');
    assert.ok(item, 'dòng đã mở vẫn ở lại danh sách');
    assert.equal(item.accountStatus, 'unlocked');
  });

  await t.test('4. Khoá vĩnh viễn: dấu riêng, không tự mở dù quét bao nhiêu lần', async () => {
    const { q, repository } = make();
    await q.temporaryBlockAccount('binh', { durationMs: 5, blockedBy: 'admin.a' });
    await q.permanentBanAccount('binh', { bannedBy: 'admin.a' });
    await sleep(20);
    await q.sweepExpiredQuarantines();
    assert.equal(account('binh').status, 'Inactive');
    assert.ok(account('binh').reason_inactive.startsWith(AIOPS_ADMIN_BAN_PREFIX));
    assert.equal((await repository.getAccountByUsername('binh')).status, 'PERMANENT');
  });

  await t.test('5. Khoá có lý do do người khác đổi tay (không còn dấu AIOps): hết hạn không tự mở', async () => {
    const { q } = make();
    await q.temporaryBlockAccount('binh', { durationMs: 5, blockedBy: 'admin.a' });
    account('binh').reason_inactive = 'Vi phạm điều khoản (trang Người dùng)';
    await sleep(20);
    await q.sweepExpiredQuarantines();
    assert.equal(account('binh').status, 'Inactive');
  });

  await t.test('6. Đối soát lúc khởi động: account mang dấu tạm khoá mà không còn hạn khoá hiệu lực thì được mở', async () => {
    const { q } = make();
    accounts[1] = { ...accounts[1], status: 'Inactive', reason_inactive: `${AIOPS_ADMIN_TEMP_PREFIX} Quản trị viên tạm khóa 4 giờ` };
    await q._reconcileAutoLocks();
    assert.equal(account('chi').status, 'Active');
  });

  await t.test('7. Đối soát không mở khoá vĩnh viễn của admin', async () => {
    const { q } = make();
    accounts[1] = { ...accounts[1], status: 'Inactive', reason_inactive: `${AIOPS_ADMIN_BAN_PREFIX} Khóa do vi phạm` };
    await q._reconcileAutoLocks();
    assert.equal(account('chi').status, 'Inactive');
  });

  await t.test('8. Mở khoá: account Active, dòng UNLOCKED ghi người mở; khoá lại thì dòng trở lại TEMPORARY', async () => {
    const { q, repository } = make();
    await q.temporaryBlockAccount('binh', { durationMs: 4 * 3600e3, blockedBy: 'admin.a' });
    await q.unblockAccount('binh', { unblockedBy: 'admin.b' });
    assert.equal(account('binh').status, 'Active');
    const row = await repository.getAccountByUsername('binh');
    assert.equal(row.status, 'UNLOCKED');
    assert.equal(row.unblocked_by, 'admin.b');
    await q.temporaryBlockAccount('binh', { durationMs: 4 * 3600e3, blockedBy: 'admin.a' });
    assert.equal((await repository.getAccountByUsername('binh')).status, 'TEMPORARY');
    assert.equal(account('binh').status, 'Inactive');
  });

  await t.test('9. Khởi động lại (bộ nhớ trống): danh sách vẫn còn cả dòng đang khoá lẫn dòng đã mở', async () => {
    const repository = new AIOpsQuarantineRepository({ pool: null });
    const first = make(repository).q;
    await first.temporaryBlockAccount('binh', { durationMs: 4 * 3600e3, blockedBy: 'admin.a' });
    await first.temporaryBlockAccount('chi', { durationMs: 4 * 3600e3, blockedBy: 'admin.a' });
    await first.unblockAccount('chi', { unblockedBy: 'admin.a' });
    first.quarantinePair({ ip: '203.0.113.9', reason: 'Dò mật khẩu', vector: 'auth' });
    await sleep(10);

    const restarted = make(repository).q;
    const list = await restarted.listQuarantines();
    assert.equal(list.find((x) => x.username === 'binh')?.accountStatus, 'temporary');
    assert.equal(list.find((x) => x.username === 'chi')?.accountStatus, 'unlocked');
    assert.ok(list.some((x) => x.maskedIp && x.ipStatus === 'temporary'), 'IP đang khoá có trong danh sách');
  });

  await t.test('11. Mở khoá ở trang Người dùng: dòng AIOps đang khoá của tài khoản đó chuyển UNLOCKED, ghi người mở', async () => {
    const { q, repository } = make();
    await q.temporaryBlockAccount('binh', { durationMs: 4 * 3600e3, blockedBy: 'admin.a' });
    await q.releaseAccountFromUserPage({ idaccount: 11, username: 'binh', by: 'admin.b' });
    const row = await repository.getAccountByUsername('binh');
    assert.equal(row.status, 'UNLOCKED');
    assert.equal(row.unblocked_by, 'admin.b');
    assert.equal(row.unblock_reason, 'Mở từ trang Người dùng');
  });

  await t.test('12. adminService.updateStatus → Active gọi giải phóng dòng AIOps; → Inactive thì không', async () => {
    const adminRepository = require('../../modules/admin/admin.repository');
    const adminService = require('../../modules/admin/admin.service');
    const { defaultAIOpsQuarantine } = require('../../modules/aiops/aiops.quarantine');
    const saved = { get: adminRepository.getUserById, upd: adminRepository.updateAccountStatus, rel: defaultAIOpsQuarantine.releaseAccountFromUserPage };
    const calls = [];
    adminRepository.getUserById = async () => ({ iduser: 5, fullname: 'Bình', account: { idaccount: 11, username: 'binh', status: 'Inactive' } });
    adminRepository.updateAccountStatus = async () => ({});
    defaultAIOpsQuarantine.releaseAccountFromUserPage = async (arg) => calls.push(arg);
    try {
      await adminService.updateStatus(5, { status: 'Active' }, { username: 'admin.b' });
      assert.deepEqual(calls, [{ idaccount: 11, username: 'binh', by: 'admin.b' }]);
      calls.length = 0;
      adminRepository.getUserById = async () => ({ iduser: 5, fullname: 'Bình', account: { idaccount: 11, username: 'binh', status: 'Active' } });
      await adminService.updateStatus(5, { status: 'Inactive', reason_inactive: 'Vi phạm điều khoản sử dụng' }, { username: 'admin.b' });
      assert.equal(calls.length, 0);
    } finally {
      adminRepository.getUserById = saved.get;
      adminRepository.updateAccountStatus = saved.upd;
      defaultAIOpsQuarantine.releaseAccountFromUserPage = saved.rel;
    }
  });

  await t.test('10. IP chỉ tạm khoá: yêu cầu "khoá vĩnh viễn" IP vẫn ghi TEMPORARY có hạn', async () => {
    const { q, repository } = make();
    const rec = q.quarantinePair({ ip: '198.51.100.7', reason: 'Quét lỗ hổng', vector: 'exploit' });
    await sleep(10);
    await q.extendIp(rec.ipHash, { blockedBy: 'admin.a' });
    const row = await repository.getIpByHash(rec.ipHash);
    assert.equal(row.status, 'TEMPORARY');
    assert.ok(row.expires_at);
  });
});
