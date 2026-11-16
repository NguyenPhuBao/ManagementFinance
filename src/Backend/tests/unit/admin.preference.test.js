/**
 * Cài đặt cá nhân của từng tài khoản quản trị (migration 55, 2026-11-16).
 * GET / PUT /api/admin/me/settings: đọc / ghi cài đặt của CHÍNH MÌNH (idaccount lấy từ token, không từ body);
 * chỉ 7 khoá, mỗi khoá chỉ giá trị hợp lệ; chưa lưu thì trả mặc định kèm saved = false.
 */
const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { prisma } = require('../../config/db');
const adminController = require('../../modules/admin/admin.controller');
const preferenceService = require('../../modules/admin/admin-preference.service');

const DEFAULTS = {
  theme: 'light',
  tableDensity: 'comfortable',
  soundEnabled: true,
  toastDuration: 4500,
  showUnreadBadge: true,
  metricsInterval: 3,
  autoLockMinutes: 30,
};

const fakeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  return res;
};

describe('Cài đặt cá nhân của tài khoản quản trị', () => {
  const delegate = prisma.admin_preference;
  const orig = { findUnique: delegate.findUnique, upsert: delegate.upsert };
  let rows;
  let calls;

  beforeEach(() => {
    rows = new Map();
    calls = [];
    delegate.findUnique = async ({ where }) => {
      calls.push(['findUnique', where]);
      return rows.has(where.idaccount) ? { idaccount: where.idaccount, settings: rows.get(where.idaccount) } : null;
    };
    delegate.upsert = async ({ where, create, update }) => {
      calls.push(['upsert', where]);
      const settings = rows.has(where.idaccount) ? update.settings : create.settings;
      rows.set(where.idaccount, settings);
      return { idaccount: where.idaccount, settings };
    };
  });
  afterEach(() => { Object.assign(delegate, orig); });

  it('chưa lưu → trả mặc định, saved = false', async () => {
    assert.deepEqual(await preferenceService.get(5), { settings: DEFAULTS, saved: false });
  });

  it('đã lưu → trộn với mặc định, bỏ khoá lạ còn sót trong CSDL, saved = true', async () => {
    rows.set(5, { autoLockMinutes: 0, theme: 'dark', khoaLa: 1 });
    assert.deepEqual(await preferenceService.get(5), { settings: { ...DEFAULTS, autoLockMinutes: 0, theme: 'dark' }, saved: true });
  });

  it('ghi một phần → trộn với bản đã lưu, chỉ ghi vào đúng tài khoản', async () => {
    rows.set(5, { theme: 'dark' });
    const out = await preferenceService.update(5, { autoLockMinutes: 15 });
    assert.deepEqual(out, { settings: { ...DEFAULTS, theme: 'dark', autoLockMinutes: 15 }, saved: true });
    assert.deepEqual(rows.get(5), { theme: 'dark', autoLockMinutes: 15 });
    assert.equal(rows.has(6), false);
  });

  for (const [ten, body] of [
    ['khoá lạ', { language: 'en' }],
    ['tự khoá 7 phút', { autoLockMinutes: 7 }],
    ['giao diện "blue"', { theme: 'blue' }],
    ['âm thanh là chuỗi', { soundEnabled: 'yes' }],
    ['thời gian thông báo 1234', { toastDuration: 1234 }],
    ['đối tượng rỗng', {}],
    ['không phải đối tượng', ['dark']],
  ]) {
    it(`từ chối ${ten} (400), không ghi gì`, async () => {
      await assert.rejects(preferenceService.update(5, body), (e) => e.statusCode === 400);
      assert.equal(calls.filter(([n]) => n === 'upsert').length, 0);
    });
  }

  it('controller: GET và PUT dùng idaccount trong token, bỏ qua idaccount trong body', async () => {
    rows.set(9, { theme: 'dark' });
    const getRes = fakeRes();
    await adminController.getMySettings({ user: { idaccount: 5 }, body: {} }, getRes);
    assert.equal(getRes.statusCode, 200);
    assert.equal(getRes.body.data.settings.theme, 'light');
    const putRes = fakeRes();
    await adminController.updateMySettings({ user: { idaccount: 5 }, body: { idaccount: 9, autoLockMinutes: 60 } }, putRes);
    assert.equal(putRes.statusCode, 400, 'idaccount là khoá lạ, không được nhận');
    const ok = fakeRes();
    await adminController.updateMySettings({ user: { idaccount: 5 }, body: { autoLockMinutes: 60 } }, ok);
    assert.equal(ok.statusCode, 200);
    assert.equal(rows.get(5).autoLockMinutes, 60);
    assert.deepEqual(rows.get(9), { theme: 'dark' }, 'tài khoản khác không bị đụng');
  });
});
