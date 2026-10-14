/**
 * Test Suite v2: Admin Operations & Defense-in-Depth
 * Module: src/Backend/modules/admin
 * 
 * Kiểm thử toàn diện:
 * 1. Category Privacy Defense (Cấm tuyệt đối sửa/xóa danh mục của user, chỉ sửa is_default=true)
 * 2. Category Name Uniqueness & Debt Canonical Classify
 * 3. User Lifecycle Management (Khóa/Mở tài khoản kèm lý do, Cưỡng chế đăng xuất)
 * 4. User Protection (Cấm xóa tài khoản Admin, Cấm can thiệp tài khoản PendingDelete)
 * 5. Audit Log Query Capping (Giới hạn tối đa 200 bản ghi)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const adminService = require('../../modules/admin/admin.service');
const adminRepository = require('../../modules/admin/admin.repository');
const { prisma } = require('../../config/db');

describe('Admin Operations Suite v2 — Privacy, Lifecycle & Safety Constraints', () => {
  // ─── 1. CATEGORY PRIVACY DEFENSE-IN-DEPTH ─────────────────────────────────
  describe('1. Category Privacy Defense (Bảo vệ quyền riêng tư người dùng)', () => {
    it('1.1. Cấm tuyệt đối Admin sửa danh mục do người dùng tạo (is_default = false)', async () => {
      const origFindUnique = prisma.category.findUnique;
      prisma.category.findUnique = async () => ({
        idcategory: 'user-cat-uuid-1',
        name_category: 'Quỹ đen cá nhân',
        is_default: false, // Danh mục của người dùng
        delete_at: null,
      });

      try {
        await assert.rejects(
          async () => {
            await adminService.updateCategory('user-cat-uuid-1', { name: 'Đổi tên' }, 1);
          },
          (err) => {
            assert.strictEqual(err.statusCode, 403);
            assert.ok(err.message.includes('Vi phạm quyền riêng tư: Tuyệt đối cấm chỉnh sửa danh mục của người dùng'));
            return true;
          }
        );
      } finally {
        prisma.category.findUnique = origFindUnique;
      }
    });

    it('1.2. Cấm tuyệt đối Admin xóa danh mục do người dùng tạo (is_default = false)', async () => {
      const origFindUnique = prisma.category.findUnique;
      prisma.category.findUnique = async () => ({
        idcategory: 'user-cat-uuid-2',
        name_category: 'Chi tiêu bí mật',
        is_default: false,
        delete_at: null,
      });

      try {
        await assert.rejects(
          async () => {
            await adminService.deleteCategory('user-cat-uuid-2');
          },
          (err) => {
            assert.strictEqual(err.statusCode, 403);
            assert.ok(err.message.includes('Vi phạm quyền riêng tư: Tuyệt đối cấm xóa danh mục của người dùng'));
            return true;
          }
        );
      } finally {
        prisma.category.findUnique = origFindUnique;
      }
    });

    it('1.3. Chặn đổi tên danh mục hệ thống trùng với danh mục hệ thống khác đã có', async () => {
      const origFindUnique = prisma.category.findUnique;
      const origFindFirst = prisma.category.findFirst;

      prisma.category.findUnique = async () => ({
        idcategory: 'sys-cat-1',
        name_category: 'Ăn uống',
        is_default: true,
        delete_at: null,
      });

      // Giả lập danh mục "Mua sắm" đã tồn tại
      prisma.category.findFirst = async () => ({
        idcategory: 'sys-cat-2',
        name_category: 'Mua sắm',
        is_default: true,
      });

      try {
        await assert.rejects(
          async () => {
            await adminService.updateCategory('sys-cat-1', { name: 'Mua sắm' }, 1);
          },
          (err) => {
            assert.strictEqual(err.statusCode, 400);
            assert.ok(err.message.includes('đã tồn tại trong hệ thống. Không được phép đổi tên trùng'));
            return true;
          }
        );
      } finally {
        prisma.category.findUnique = origFindUnique;
        prisma.category.findFirst = origFindFirst;
      }
    });

    it('1.4. [Tầng 1 & Tầng 2] getCategories trả về đầy đủ các danh mục bao gồm cả danh mục hệ thống đã bị xóa mềm', async () => {
      const origGetAllCategories = adminRepository.getAllCategories;
      const mockCats = [
        {
          idcategory: 'cat-active-1',
          create_by: 1,
          name_category: 'Ăn uống',
          classify: 'Chi',
          is_default: true,
          is_group: false,
          idgroup: null,
          keyword: 'com, pho',
          icon: 'restaurant',
          create_at: new Date('2026-01-01'),
          update_at: new Date('2026-01-01'),
          delete_at: null,
        },
        {
          idcategory: 'cat-deleted-2',
          create_by: 1,
          name_category: 'Xăng xe',
          classify: 'Chi',
          is_default: true,
          is_group: false,
          idgroup: null,
          keyword: 'xang, dau',
          icon: 'local_gas_station',
          create_at: new Date('2026-01-01'),
          update_at: new Date('2026-10-10'),
          delete_at: new Date('2026-10-10'),
        },
      ];

      adminRepository.getAllCategories = async () => mockCats;

      try {
        const result = await adminService.getCategories();
        assert.strictEqual(result.length, 2, 'Phải trả về cả 2 danh mục');

        // Tầng 1: Đảm bảo trường status và delete_at được map chính xác
        const activeCat = result.find((c) => c.id === 'cat-active-1');
        assert.ok(activeCat, 'Tìm thấy danh mục active');
        assert.strictEqual(activeCat.status, 'active');
        assert.strictEqual(activeCat.delete_at, null);

        const deletedCat = result.find((c) => c.id === 'cat-deleted-2');
        assert.ok(deletedCat, 'Tìm thấy danh mục đã xóa mềm');
        assert.strictEqual(deletedCat.status, 'deleted');
        assert.notStrictEqual(deletedCat.delete_at, null);
      } finally {
        adminRepository.getAllCategories = origGetAllCategories;
      }
    });

    it('1.5. [Tầng 2 - System Impact] Repository getAllCategories không lọc bỏ delete_at: null đối với Admin', async () => {
      const origFindMany = prisma.category.findMany;
      let capturedWhere = null;
      prisma.category.findMany = async ({ where }) => {
        capturedWhere = where;
        return [];
      };

      try {
        await adminRepository.getAllCategories({});
        assert.ok(capturedWhere, 'findMany phải được gọi');
        assert.strictEqual(capturedWhere.is_default, true, 'is_default vẫn phải là true');
        assert.strictEqual(capturedWhere.delete_at, undefined, 'delete_at không được ép cứng thành null để không bỏ sót danh mục đã xóa');
      } finally {
        prisma.category.findMany = origFindMany;
      }
    });
  });

  // ─── 2. USER LIFECYCLE & PROTECTION CONSTRAINTS ──────────────────────────
  describe('2. User Protection & Lifecycle Constraints', () => {
    it('2.1. Cấm xóa tài khoản Quản trị viên (Admin Role idrole = 1)', async () => {
      const origGetUser = adminRepository.getUserById;
      adminRepository.getUserById = async () => ({
        iduser: 1,
        fullname: 'Super Admin',
        account: { idaccount: 1, idrole: 1, status: 'Active' },
      });

      try {
        await assert.rejects(
          async () => {
            await adminService.deleteUser(1);
          },
          (err) => {
            assert.strictEqual(err.statusCode, 403);
            assert.ok(err.message.includes('Không thể xóa tài khoản Quản trị viên'));
            return true;
          }
        );
      } finally {
        adminRepository.getUserById = origGetUser;
      }
    });

    it('2.2. Khóa thao tác xóa nếu tài khoản đang ở trạng thái Chờ xóa (PendingDelete)', async () => {
      const origGetUser = adminRepository.getUserById;
      adminRepository.getUserById = async () => ({
        iduser: 20,
        fullname: 'User Pending Delete',
        account: { idaccount: 20, idrole: 2, status: 'PendingDelete', countdown: 28 },
      });

      try {
        await assert.rejects(
          async () => {
            await adminService.deleteUser(20);
          },
          (err) => {
            assert.strictEqual(err.statusCode, 400);
            assert.ok(err.message.includes('Tài khoản đang trong trạng thái Chờ xóa (PendingDelete)'));
            return true;
          }
        );
      } finally {
        adminRepository.getUserById = origGetUser;
      }
    });

    it('2.3. Khóa tài khoản (status -> Inactive) bắt buộc phải có lý do hợp lệ', async () => {
      const origGetUser = adminRepository.getUserById;
      adminRepository.getUserById = async () => ({
        iduser: 30,
        fullname: 'Spam User',
        account: { idaccount: 30, idrole: 2, status: 'Active' },
      });

      try {
        await assert.rejects(
          async () => {
            await adminService.updateStatus(30, { status: 'Inactive', reason_inactive: '' });
          },
          (err) => {
            assert.strictEqual(err.statusCode, 400);
            assert.ok(err.message.includes('Vui lòng cung cấp lý do vô hiệu hóa tài khoản'));
            return true;
          }
        );
      } finally {
        adminRepository.getUserById = origGetUser;
      }
    });
  });

  // ─── 3. AUDIT LOG CAPPING CONSTRAINT ─────────────────────────────────────
  describe('3. Audit Log Query Capping', () => {
    it('3.1. getAuditLogs tự động khống chế limit tối đa 200 bản ghi để bảo vệ RAM', async () => {
      const origQueryLogs = adminRepository.queryAuditLogs;
      let requestedLimit = 0;

      adminRepository.queryAuditLogs = async (query) => {
        requestedLimit = query.limit;
        return { total: 0, totalPages: 0, items: [] };
      };

      try {
        // Client cố tình request limit 5000 bản ghi
        const res = await adminService.getAuditLogs({ limit: 5000 });
        assert.strictEqual(requestedLimit, 200, 'Limit truyền vào repository bắt buộc phải bị chặn ở trần 200');
        assert.strictEqual(res.limit, 200, 'Limit trả về response bắt buộc phải là 200');
      } finally {
        adminRepository.queryAuditLogs = origQueryLogs;
      }
    });
  });
});
