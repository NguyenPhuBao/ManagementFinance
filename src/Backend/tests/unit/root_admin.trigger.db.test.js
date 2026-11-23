/**
 * Trigger trg_protect_root_admin (database/FlowMoney_Schema.sql) trên CSDL thật.
 * Chỉ chạy khi có TEST_DATABASE_URL (CSDL thử trên máy này, dựng từ database/FlowMoney_Schema.sql); không có thì bỏ qua.
 * Mọi thao tác nằm trong một giao tác và ROLLBACK ở cuối: không để lại dữ liệu.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const { Client } = require('pg');

const URL = process.env.TEST_DATABASE_URL;
const ROOT = 'admin@wealthcommand.com';

test('Trigger bảo vệ tài khoản quản trị gốc (migration 56)', { skip: !URL && 'Không có TEST_DATABASE_URL' }, async (t) => {
  const db = new Client({ connectionString: URL });
  await db.connect();
  t.after(async () => {
    await db.query('ROLLBACK').catch(() => {});
    await db.end();
  });
  await db.query('BEGIN');

  // Chạy một câu trong SAVEPOINT; trả về lỗi (nếu có) và quay về SAVEPOINT để chạy tiếp.
  const attempt = async (sql, params = []) => {
    await db.query('SAVEPOINT sp');
    try {
      await db.query(sql, params);
      await db.query('RELEASE SAVEPOINT sp');
      return null;
    } catch (err) {
      await db.query('ROLLBACK TO SAVEPOINT sp');
      return err;
    }
  };
  const blocked = (err) => assert.ok(err && /ROOT_ACCOUNT_PROTECTED/.test(err.message), err ? err.message : 'phải bị chặn');

  // Xoá chỗ cho email gốc trong giao tác này (nếu CSDL thử đã có sẵn) rồi tạo tài khoản gốc thử.
  const existing = await db.query('SELECT "Idaccount" FROM "account" WHERE lower("Email") = $1', [ROOT]);
  let rootId = existing.rows[0]?.Idaccount;
  if (!rootId) {
    const r = await db.query(
      `INSERT INTO "account" ("Idrole","Email","Username","Password") VALUES (1,$1,'root_trigger_test','x') RETURNING "Idaccount"`,
      [ROOT]
    );
    rootId = r.rows[0].Idaccount;
  }
  const other = await db.query(
    `INSERT INTO "account" ("Idrole","Email","Username","Password") VALUES (2,'nguoi.dung.thu.56@example.com','nguoi_dung_thu_56','x') RETURNING "Idaccount"`
  );
  const otherId = other.rows[0].Idaccount;

  await t.test('đổi mật khẩu tài khoản gốc: được', async () => {
    assert.equal(await attempt('UPDATE "account" SET "Password" = $1 WHERE "Idaccount" = $2', ['y', rootId]), null);
  });
  await t.test('khoá / chờ xoá / xoá mềm tài khoản gốc: bị chặn', async () => {
    for (const status of ['Inactive', 'PendingDelete', 'Deleted']) {
      blocked(await attempt('UPDATE "account" SET "Status" = $1 WHERE "Idaccount" = $2', [status, rootId]));
    }
    blocked(await attempt('UPDATE "account" SET "Delete_at" = NOW() WHERE "Idaccount" = $1', [rootId]));
  });
  await t.test('đổi vai, email, tên đăng nhập tài khoản gốc: bị chặn', async () => {
    blocked(await attempt('UPDATE "account" SET "Idrole" = 2 WHERE "Idaccount" = $1', [rootId]));
    blocked(await attempt(`UPDATE "account" SET "Email" = 'khac@example.com' WHERE "Idaccount" = $1`, [rootId]));
    blocked(await attempt(`UPDATE "account" SET "Username" = 'ten_khac' WHERE "Idaccount" = $1`, [rootId]));
  });
  await t.test('xoá vật lý tài khoản gốc: bị chặn', async () => {
    blocked(await attempt('DELETE FROM "account" WHERE "Idaccount" = $1', [rootId]));
  });
  await t.test('người dùng thường không chiếm được email gốc', async () => {
    blocked(await attempt('UPDATE "account" SET "Email" = $1 WHERE "Idaccount" = $2', [ROOT.toUpperCase(), otherId]));
  });
  await t.test('tài khoản khác không bị ảnh hưởng: khoá được', async () => {
    assert.equal(await attempt(`UPDATE "account" SET "Status" = 'Inactive' WHERE "Idaccount" = $1`, [otherId]), null);
  });
});
