/**
 * Máy chủ bắt buộc PIN quản trị cho các thao tác nhạy cảm của Admin-web (2026-11-16):
 * bảo trì (lên lịch, khẩn cấp, tắt, huỷ lịch), người dùng (vô hiệu hoá, kích hoạt, xoá),
 * danh mục (thêm, sửa, xoá, khôi phục), phân quyền (lưu, đặt lại mặc định).
 * Mỗi API: thiếu PIN → 400, service không chạy; sai PIN → 400; đúng PIN → service chạy, không nhận `pin`.
 */
const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');
const adminService = require('../../modules/admin/admin.service');
const adminController = require('../../modules/admin/admin.controller');
const { defaultMaintenanceManager } = require('../../core/resilience/maintenance.manager');
const { defaultMaintenanceRepository } = require('../../modules/admin/maintenance.repository');

const fakeRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  res.set = () => res;
  return res;
};

const CAT_ID = 'a'.repeat(36);
const USER = { idaccount: 1, username: 'admin' };

// [tên, handler, req (không có pin), nơi đặt stub, tên hàm service, hành động PIN mong đợi]
const CASES = [
  ['lên lịch bảo trì', 'setMaintenanceStatus', { body: { scheduledAt: '2099-01-01T00:00:00.000Z', reason: 'Nâng cấp' } }, defaultMaintenanceManager, 'scheduleMaintenance', 'SCHEDULE_MAINTENANCE'],
  ['bật bảo trì khẩn cấp', 'setMaintenanceStatus', { body: { active: true, reason: 'Sự cố', isEmergency: true } }, defaultMaintenanceManager, 'setMaintenance', 'EMERGENCY_MAINTENANCE'],
  ['tắt bảo trì', 'setMaintenanceStatus', { body: { active: false, reason: 'Xong' } }, defaultMaintenanceManager, 'setMaintenance', 'STOP_MAINTENANCE'],
  ['huỷ lịch bảo trì', 'cancelScheduledMaintenance', { params: { id: '42' }, body: {} }, defaultMaintenanceManager, 'cancelScheduledMaintenance', 'CANCEL_MAINTENANCE'],
  ['vô hiệu hoá người dùng', 'updateStatus', { params: { id: '5' }, body: { status: 'Inactive', reason_inactive: 'Spam quảng cáo' } }, adminService, 'updateStatus', 'DEACTIVATE_USER'],
  ['kích hoạt người dùng', 'updateStatus', { params: { id: '5' }, body: { status: 'Active' } }, adminService, 'updateStatus', 'ACTIVATE_USER'],
  ['xoá người dùng', 'deleteUser', { params: { id: '5' }, body: {} }, adminService, 'deleteUser', 'DELETE_USER'],
  ['thêm danh mục', 'addCategory', { body: { name: 'Cà phê', classify: 'Chi' } }, adminService, 'addCategory', 'SYNC_CATEGORIES'],
  ['sửa danh mục', 'updateCategory', { params: { id: CAT_ID }, body: { name: 'Cà phê', classify: 'Chi' } }, adminService, 'updateCategory', 'SYNC_CATEGORIES'],
  ['xoá danh mục', 'deleteCategory', { params: { id: CAT_ID }, body: {} }, adminService, 'deleteCategory', 'SYNC_CATEGORIES'],
  ['khôi phục danh mục', 'restoreCategory', { params: { id: CAT_ID }, body: {} }, adminService, 'restoreCategory', 'SYNC_CATEGORIES'],
  ['lưu phân quyền', 'updatePermissions', { body: { updates: [{ account_type: 'Basic', feature_id: 'wallets', is_enabled: true }] } }, adminService, 'updatePermissionsMatrix', 'UPDATE_PERMISSIONS'],
  ['đặt lại phân quyền mặc định', 'resetPermissions', { body: {} }, adminService, 'resetPermissionsToDefault', 'RESET_PERMISSIONS'],
];

describe('Máy chủ bắt buộc PIN cho thao tác nhạy cảm của Admin-web', () => {
  const origVerify = adminService.verifySecurityAction;
  const origHistory = defaultMaintenanceRepository.getHistory;
  const saved = [];

  beforeEach(() => {
    defaultMaintenanceRepository.getHistory = async () => ({ data: [] });
  });

  afterEach(() => {
    adminService.verifySecurityAction = origVerify;
    defaultMaintenanceRepository.getHistory = origHistory;
    while (saved.length) {
      const [target, fn, orig] = saved.pop();
      target[fn] = orig;
    }
  });

  const stub = (target, fn, impl) => {
    saved.push([target, fn, target[fn]]);
    target[fn] = impl;
  };

  for (const [name, handler, baseReq, target, fn, action] of CASES) {
    const makeReq = (extra = {}) => ({
      params: {},
      query: {},
      ...baseReq,
      body: { ...baseReq.body, ...extra },
      user: USER,
    });

    it(`${name}: thiếu PIN → 400, không chạy thao tác`, async () => {
      let called = false;
      stub(target, fn, (...args) => { called = true; return {}; });
      const res = fakeRes();
      await adminController[handler](makeReq(), res);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(called, false);
    });

    it(`${name}: sai PIN → 400, không chạy thao tác`, async () => {
      let called = false;
      stub(target, fn, (...args) => { called = true; return {}; });
      adminService.verifySecurityAction = async () => {
        const e = new Error('Mã PIN quản trị viên không chính xác!');
        e.statusCode = 400;
        throw e;
      };
      const res = fakeRes();
      await adminController[handler](makeReq({ pin: '000000' }), res);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(called, false);
    });

    it(`${name}: đúng PIN → chạy thao tác, ghi hành động ${action}, không chuyển PIN xuống`, async () => {
      let args = null;
      stub(target, fn, (...a) => { args = a; return { newStatus: 'Active' }; });
      let verified = null;
      adminService.verifySecurityAction = async (body, user) => { verified = { body, user }; return { verified: true }; };
      const res = fakeRes();
      await adminController[handler](makeReq({ pin: '246810' }), res);
      assert.ok(res.statusCode < 300, `mã ${res.statusCode}: ${JSON.stringify(res.body)}`);
      assert.ok(verified, 'phải kiểm PIN');
      assert.strictEqual(verified.body.pin, '246810');
      assert.strictEqual(verified.body.action, action);
      assert.strictEqual(verified.user, USER);
      assert.ok(args, 'phải chạy thao tác');
      assert.ok(!JSON.stringify(args).includes('246810'), 'PIN không được chuyển xuống service');
    });
  }
});
