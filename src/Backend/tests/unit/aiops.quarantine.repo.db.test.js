/**
 * Câu SQL mới của kho khoá AIOps (mục 2.2) trên CSDL thật: upsertAccountLock tạo dòng khi chưa có,
 * khoá lại thì cập nhật đúng dòng; listQuarantineRows trả cả dòng đã mở.
 * Chỉ chạy khi có TEST_DATABASE_URL; mọi thao tác trong một giao tác, ROLLBACK ở cuối.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const { Client } = require('pg');
const { AIOpsQuarantineRepository } = require('../../modules/aiops/aiops.quarantine.repository');

const URL = process.env.TEST_DATABASE_URL;

test('Kho khoá AIOps trên CSDL thật (mục 2.2)', { skip: !URL && 'Không có TEST_DATABASE_URL' }, async (t) => {
  const db = new Client({ connectionString: URL });
  await db.connect();
  t.after(async () => {
    await db.query('ROLLBACK').catch(() => {});
    await db.end();
  });
  await db.query('BEGIN');
  const repo = new AIOpsQuarantineRepository({ pool: db });
  const name = `thu_khoa_${Date.now()}`;

  await t.test('khoá tài khoản chưa có dòng: tạo dòng TEMPORARY có hạn', async () => {
    const exp = new Date(Date.now() + 4 * 3600e3);
    const n = await repo.upsertAccountLock({ username: name, idaccount: null, status: 'TEMPORARY', reason: '[AIOPS_ADMIN_TEMP] thử', bannedBy: 'admin.a', expiresAt: exp });
    assert.equal(n, 1);
    const row = await repo.getAccountByUsername(name);
    assert.equal(row.status, 'TEMPORARY');
    assert.equal(row.banned_by, 'admin.a');
    assert.ok(Math.abs(new Date(row.expires_at).getTime() - exp.getTime()) < 1000);
  });

  await t.test('mở khoá: dòng còn, UNLOCKED; khoá vĩnh viễn lại: cùng dòng thành PERMANENT, không có hạn', async () => {
    await repo.updateAccountStatus({ username: name, status: 'UNLOCKED', unblockedBy: 'admin.b', unblockReason: 'thử' });
    assert.equal((await repo.getAccountByUsername(name)).status, 'UNLOCKED');
    await repo.upsertAccountLock({ username: name, status: 'PERMANENT', reason: '[AIOPS_ADMIN_BAN] thử', bannedBy: 'admin.a' });
    const rows = await db.query('SELECT * FROM "aiops_account_quarantine" WHERE "username" = $1', [name]);
    assert.equal(rows.rowCount, 1);
    assert.equal(rows.rows[0].status, 'PERMANENT');
    assert.equal(rows.rows[0].expires_at, null);
  });

  await t.test('hai tên đăng nhập trùng 16 ký tự đầu không bị gộp vào cùng một dòng (khoá tay lẫn tự khoá)', async () => {
    const a = 'nguyenvananh2024_a_thu56';
    const b = 'nguyenvananh2024_b_thu56';
    await repo.upsertAccountLock({ username: a, status: 'TEMPORARY', reason: 'x', expiresAt: new Date(Date.now() + 60e3) });
    await repo.upsertAccountLock({ username: b, status: 'PERMANENT', reason: 'y' });
    await repo.recordQuarantinePair({ ipHash: 'hash_thu_56_c', maskedIp: '198.51.xxx.xxx', username: 'nguyenvananh2024_c_thu56', reason: 'z' });
    const rows = await db.query(`SELECT "username", "status" FROM "aiops_account_quarantine" WHERE "username" LIKE 'nguyenvananh2024_%_thu56' ORDER BY 1`);
    assert.deepEqual(rows.rows.map((r) => [r.username, r.status]), [[a, 'TEMPORARY'], [b, 'PERMANENT'], ['nguyenvananh2024_c_thu56', 'TEMPORARY']]);
  });

  await t.test('listQuarantineRows trả cả dòng đã mở', async () => {
    const other = `${name}_mo`;
    await repo.upsertAccountLock({ username: other, status: 'TEMPORARY', reason: 'x', expiresAt: new Date(Date.now() + 60e3) });
    await repo.updateAccountStatus({ username: other, status: 'UNLOCKED', unblockedBy: 'admin.b' });
    const data = await repo.listQuarantineRows();
    assert.ok(data, 'đọc được từ CSDL');
    assert.equal(data.accounts.find((r) => r.username === other)?.status, 'UNLOCKED');
    assert.equal(data.accounts.find((r) => r.username === name)?.status, 'PERMANENT');
  });
});
