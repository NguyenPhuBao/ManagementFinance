/**
 * Thay đổi danh mục hệ thống từ Admin-web phải tới được máy người dùng ngay.
 *
 * Lỗi: emitCategoryUpdated chỉ phát `admin.category_updated` vào admin_room; Client-app không nghe sự kiện nào cho
 * danh mục nên chỉ thấy thay đổi ở lần /sync/pull kế tiếp (chu kỳ 15 phút / mở app). Nhật ký Supabase 14/11/2026:
 * khôi phục "Giải trí" lúc 21:25:35 UTC, sau đó không có /sync/pull nào tới ít nhất 21:39.
 *
 * Cách sửa (Chủ dự án chốt): phát thêm `sync.completed` tới MỌI socket. Client-app đã nghe tên này
 * (`RealtimeEvent.dongBoXong`, canDongBoLai = true) và tự kéo về im lặng; không đọc payload.
 */
const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const socketCore = require('../../core/socket');
const adminService = require('../../modules/admin/admin.service');
const adminRepository = require('../../modules/admin/admin.repository');
const { prisma } = require('../../config/db');

describe('Danh mục hệ thống đổi ⇒ báo mọi máy kéo dữ liệu', () => {
  const emitted = [];
  const mockIO = {
    to: (room) => ({ emit: (event, payload) => emitted.push({ room, event, payload }) }),
    emit: (event, payload) => emitted.push({ room: 'all', event, payload }),
  };
  let savedIO;

  before(() => { savedIO = socketCore.getIO(); socketCore._setMockIO(mockIO); });
  after(() => { socketCore._setMockIO(savedIO); });
  beforeEach(() => { emitted.length = 0; });

  const toAll = () => emitted.filter((e) => e.room === 'all' && e.event === 'sync.completed');

  it('emitCategoryUpdated: vẫn báo Admin-web, và phát sync.completed tới mọi socket', () => {
    socketCore.emitCategoryUpdated({ action: 'delete', idcategory: 'c-1' });
    assert.ok(emitted.some((e) => e.room === 'admin_room' && e.event === 'admin.category_updated'));
    assert.strictEqual(toAll().length, 1);
  });

  it('Tầng 2: khôi phục danh mục hệ thống ⇒ máy người dùng nhận sync.completed', async () => {
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
    assert.strictEqual(toAll().length, 1, 'khôi phục phải báo mọi máy kéo về');
  });

  it('Tầng 2: xoá mềm danh mục hệ thống ⇒ máy người dùng nhận sync.completed', async () => {
    const saved = { find: prisma.category.findUnique, del: adminRepository.deleteCategory };
    prisma.category.findUnique = async () => ({ idcategory: 'c-3', is_default: true, delete_at: null });
    adminRepository.deleteCategory = async () => ({});
    try {
      await adminService.deleteCategory('c-3');
    } finally {
      prisma.category.findUnique = saved.find;
      adminRepository.deleteCategory = saved.del;
    }
    assert.strictEqual(toAll().length, 1);
  });

  it('Payload không chứa dữ liệu danh mục (client không đọc payload, tránh phát thừa thông tin)', () => {
    socketCore.emitCategoryUpdated({ action: 'update', category: { id: 'c-4', name: 'Y tế', keyword: 'thuoc' } });
    const ev = toAll()[0];
    assert.ok(ev);
    assert.doesNotMatch(JSON.stringify(ev.payload || {}), /Y tế|thuoc|c-4/);
  });
});
