/**
 * Migration 55 trên CSDL thử thật (TEST_DATABASE_URL đã áp migration 55): mỗi tài khoản quản trị một bộ cài đặt riêng.
 */
const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { pool } = require('../../config/db');
const preferenceService = require('../../modules/admin/admin-preference.service');

describe('Migration 55: cài đặt riêng từng tài khoản quản trị', () => {
  let a;
  let b;
  before(async () => {
    const ids = (await pool.query('SELECT "Idaccount" AS id FROM "account" ORDER BY 1 LIMIT 2')).rows.map((r) => r.id);
    [a, b] = ids;
    await pool.query('DELETE FROM "admin_preference" WHERE "idaccount" = ANY($1)', [ids]);
  });
  after(async () => {
    await pool.query('DELETE FROM "admin_preference" WHERE "idaccount" = ANY($1)', [[a, b]]);
  });

  it('hai tài khoản lưu khác nhau thì đọc lại đúng của mình', async () => {
    await preferenceService.update(a, { autoLockMinutes: 0, theme: 'dark' });
    await preferenceService.update(b, { autoLockMinutes: 60 });
    const ra = await preferenceService.get(a);
    const rb = await preferenceService.get(b);
    assert.equal(ra.settings.autoLockMinutes, 0);
    assert.equal(ra.settings.theme, 'dark');
    assert.equal(rb.settings.autoLockMinutes, 60);
    assert.equal(rb.settings.theme, 'light');
  });

  it('CSDL chặn settings không phải đối tượng và tài khoản không tồn tại', async () => {
    await assert.rejects(pool.query(`INSERT INTO "admin_preference" ("idaccount", "settings") VALUES ($1, '[1]'::jsonb)`, [a]), /ck_admin_preference_settings_object|duplicate key/);
    await assert.rejects(pool.query(`INSERT INTO "admin_preference" ("idaccount") VALUES (-1)`), /fk_admin_preference_account/);
  });
});
