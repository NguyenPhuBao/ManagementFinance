/**
 * Thay đổi danh mục hệ thống (khuôn) từ Admin-web KHÔNG được tới máy người dùng (Chủ dự án chốt 2026-11-17).
 *
 * Nghiệp vụ mới: khuôn chỉ áp cho tài khoản tạo sau thay đổi; danh mục của tài khoản đã có là danh mục cá nhân, không bị
 * tác động. Vì vậy emitCategoryUpdated chỉ báo Admin-web (`admin.category_updated` vào admin_room), không phát
 * `sync.completed` tới mọi socket nữa (trước 2026-11-17 có phát, để máy kéo khuôn về ngay).
 * Kế hoạch: docs/superpowers/plans/2026-11-17-danh-muc-mac-dinh-chi-ap-cho-tai-khoan-moi.md (B4).
 */
const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const socketCore = require('../../core/socket');
const adminService = require('../../modules/admin/admin.service');
const adminRepository = require('../../modules/admin/admin.repository');
const { prisma } = require('../../config/db');

describe('Danh mục hệ thống đổi ⇒ chỉ báo Admin-web, không báo máy người dùng', () => {
  const emitted = [];
  const mockIO = {
    to: (room) => ({ emit: (event, payload) => emitted.push({ room, event, payload }) }),
    emit: (event, payload) => emitted.push({ room: 'all', event, payload }),
  };
  let savedIO;

  before(() => { savedIO = socketCore.getIO(); socketCore._setMockIO(mockIO); });
  after(() => { socketCore._setMockIO(savedIO); });
  beforeEach(() => { emitted.length = 0; });

  const toAll = () => emitted.filter((e) => e.room === 'all');
  const toAdmin = () => emitted.filter((e) => e.room === 'admin_room' && e.event === 'admin.category_updated');

  it('emitCategoryUpdated: báo Admin-web, không phát gì tới mọi socket', () => {
    socketCore.emitCategoryUpdated({ action: 'delete', idcategory: 'c-1' });
    assert.strictEqual(toAdmin().length, 1);
    assert.strictEqual(toAll().length, 0);
  });

  it('Tầng 2: khôi phục danh mục hệ thống ⇒ Admin-web nhận, máy người dùng không nhận', async () => {
    const saved = { find: prisma.category.findUnique, many: prisma.category.findMany, restore: adminRepository.restoreCategory };
    const row = { idcategory: 'c-2', name_category: 'Giải trí', classify: 'Chi', keyword: 'game', is_default: true, delete_at: new Date() };
    prisma.category.findUnique = async () => row;
    prisma.category.findMany = async () => [];
    adminRepository.restoreCategory = async () => ({ ...row, delete_at: null });
    try {
      await adminService.restoreCategory('c-2');
    } finally {
      prisma.category.findUnique = saved.find;
      prisma.category.findMany = saved.many;
      adminRepository.restoreCategory = saved.restore;
    }
    assert.strictEqual(toAdmin().length, 1);
    assert.strictEqual(toAll().length, 0, 'khôi phục khuôn không được báo máy người dùng kéo về');
  });

  it('Tầng 2: xoá mềm danh mục hệ thống ⇒ Admin-web nhận, máy người dùng không nhận', async () => {
    const saved = { find: prisma.category.findUnique, del: adminRepository.deleteCategory };
    prisma.category.findUnique = async () => ({ idcategory: 'c-3', is_default: true, delete_at: null });
    adminRepository.deleteCategory = async () => ({});
    try {
      await adminService.deleteCategory('c-3');
    } finally {
      prisma.category.findUnique = saved.find;
      adminRepository.deleteCategory = saved.del;
    }
    assert.strictEqual(toAdmin().length, 1);
    assert.strictEqual(toAll().length, 0);
  });
});
