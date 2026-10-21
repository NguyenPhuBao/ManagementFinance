/**
 * 2-Tier Test Suite: Maintenance Failover, Outbox Queue & Ghost Maintenance Killer
 * Tuân thủ Rule 11 (2-Tier Testing Architecture)
 * 
 * Tầng 1: Thao tác vận hành khi CSDL sập, tự động suy giảm mềm và đệm hàng đợi (Outbox Buffer).
 * Tầng 2: Tác động hệ thống thực tế khi CSDL khôi phục: Flush Outbox và Ghost Maintenance Killer
 *         triệt tiêu hoàn toàn nguy cơ bảo trì ma chưa kết thúc.
 */

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const { MaintenanceRepository } = require('../../modules/admin/maintenance.repository');
const { MaintenanceManager } = require('../../core/resilience/maintenance.manager');

describe('2-Tier Test Suite: Maintenance Failover & Bi-directional Reconciliation', () => {
  let mockDbRows = [];
  let dbOnline = true;

  // Mock pool database có khả năng bật/tắt kết nối linh hoạt
  const mockPool = {
    query: async (sql, params = []) => {
      if (!dbOnline) {
        throw new Error('Connection terminated unexpectedly (Simulated DB Outage)');
      }

      // 1. SELECT COUNT / SELECT
      if (sql.includes('SELECT COUNT(*)')) {
        return { rows: [{ total: String(mockDbRows.length) }] };
      }
      if (sql.includes('SELECT * FROM "maintenance_history" WHERE "status" = \'ONGOING\'')) {
        const ongoing = mockDbRows.filter((r) => r.status === 'ONGOING');
        return { rows: ongoing };
      }
      if (sql.includes('SELECT * FROM "maintenance_history"')) {
        return { rows: mockDbRows };
      }

      // 2. INSERT
      if (sql.includes('INSERT INTO "maintenance_history"')) {
        const record = {
          id: mockDbRows.length + 1,
          type: params[0],
          reason: params[1],
          activated_by: params[2],
          started_at: params[3],
          scheduled_end_at: params[4],
          status: params[5] || 'ONGOING',
          ended_at: null,
          created_at: new Date().toISOString(),
        };
        mockDbRows.push(record);
        return { rows: [record] };
      }

      // 3. UPDATE ONGOING -> COMPLETED (Ghost Killer hoặc Tắt bảo trì)
      if (sql.includes('UPDATE "maintenance_history"') && sql.includes('"status" = \'ONGOING\'')) {
        const updated = [];
        for (const row of mockDbRows) {
          if (row.status === 'ONGOING') {
            row.status = 'COMPLETED';
            row.ended_at = params[0] || new Date().toISOString();
            updated.push(row);
          }
        }
        return { rows: updated };
      }

      // 4. UPDATE ID cụ thể
      if (sql.includes('UPDATE "maintenance_history"') && sql.includes('"id" =')) {
        return { rows: [] };
      }

      return { rows: [] };
    },
  };

  beforeEach(() => {
    mockDbRows = [];
    dbOnline = true;
  });

  // =========================================================================
  // 🧱 TẦNG 1: KIỂM THỬ THAO TÁC KHI CSDL SẬP & ĐỆM OUTBOX HÀNG ĐỢI
  // =========================================================================
  describe('🧱 TẦNG 1: Thao Tác Khi CSDL Sập & Đệm Hàng Đợi (Outbox Buffering)', () => {
    it('1.1. Khi CSDL bị lỗi, createRecord không crash, lưu vào _inMemoryFallback và đưa vào _pendingDbSyncQueue', async () => {
      const repo = new MaintenanceRepository({ pool: mockPool });
      dbOnline = false; // Giả lập CSDL sập

      const record = await repo.createRecord({
        type: 'EMERGENCY',
        reason: 'Sự cố mạng diện rộng',
        activated_by: 'admin_test',
        status: 'ONGOING',
      });

      // Trả về bản ghi memory
      assert.ok(record);
      assert.strictEqual(record.reason, 'Sự cố mạng diện rộng');
      assert.strictEqual(record.status, 'ONGOING');

      // Có trong fallback
      assert.strictEqual(repo._inMemoryFallback.length, 1);

      // BẮT BUỘC có trong Outbox Queue để sẵn sàng bù dữ liệu
      assert.ok(Array.isArray(repo._pendingDbSyncQueue));
      assert.strictEqual(repo._pendingDbSyncQueue.length, 1);
      assert.strictEqual(repo._pendingDbSyncQueue[0].action, 'CREATE_RECORD');
    });

    it('1.2. Khi CSDL bị lỗi, completeOngoingRecord cập nhật trong fallback và đưa OP_COMPLETE vào Outbox Queue', async () => {
      const repo = new MaintenanceRepository({ pool: mockPool });
      dbOnline = false; // Giả lập CSDL sập

      await repo.createRecord({
        type: 'EMERGENCY',
        reason: 'Bảo trì tạm thời',
        activated_by: 'admin_test',
        status: 'ONGOING',
      });

      const completed = await repo.completeOngoingRecord({
        ended_at: new Date(),
        status: 'COMPLETED',
      });

      assert.strictEqual(completed.length, 1);
      assert.strictEqual(completed[0].status, 'COMPLETED');
      assert.ok(completed[0].ended_at);

      // Kiểm tra Outbox Queue ghi nhận thao tác COMPLETE
      const completeTask = repo._pendingDbSyncQueue.find((x) => x.action === 'COMPLETE_ONGOING');
      assert.ok(completeTask, 'Hàng đợi phải có tác vụ COMPLETE_ONGOING');
    });

    it('1.3. MaintenanceManager vẫn Bật/Tắt bảo trì trơn tru trong RAM ngay cả khi CSDL sập', async () => {
      const repo = new MaintenanceRepository({ pool: mockPool });
      const manager = new MaintenanceManager({
        notificationService: { broadcast: async () => {} },
      });
      dbOnline = false; // Giả lập CSDL sập

      // 1. Admin Bật bảo trì
      const status1 = manager.setMaintenance(true, 'Bảo trì cứu trợ khẩn cấp', 'superadmin');
      assert.strictEqual(status1.active, true);
      assert.strictEqual(manager.isMaintenanceActive(), true);

      // 2. Admin Tắt bảo trì
      const status2 = manager.setMaintenance(false, null, 'superadmin');
      assert.strictEqual(status2.active, false);
      assert.strictEqual(manager.isMaintenanceActive(), false);
    });
  });

  // =========================================================================
  // ⚡ TẦNG 2: TÁC ĐỘNG HỆ THỐNG THỰC TẾ & GHOST MAINTENANCE KILLER
  // =========================================================================
  describe('⚡ TẦNG 2: Tác Động Hệ Thống Thực Tế & Ghost Maintenance Killer', () => {
    it('2.1. [GHOST KILLER] Khi CSDL khôi phục và hệ thống đang KHÔNG bảo trì, tự động chốt COMPLETED toàn bộ bản ghi ONGOING mồ côi', async () => {
      const repo = new MaintenanceRepository({ pool: mockPool });

      // 1. Lúc DB sống, có bản ghi ONGOING #10 được tạo trong CSDL
      mockDbRows.push({
        id: 10,
        type: 'EMERGENCY',
        reason: 'Bảo trì lúc 10h',
        activated_by: 'admin',
        started_at: '2026-10-21T10:00:00.000Z',
        ended_at: null,
        status: 'ONGOING',
      });

      // 2. DB bị sập
      dbOnline = false;

      // 3. Admin tắt bảo trì trong lúc DB sập -> Hệ thống hiện tại có active = false
      const currentActiveState = { active: false };

      // 4. DB sống lại!
      dbOnline = true;

      // 5. Kích hoạt cơ chế đối soát tự động reconcileWithDatabase
      const result = await repo.reconcileWithDatabase({ currentActiveState });

      // TÁC ĐỘNG HỆ THỐNG:
      // - Bản ghi #10 trong CSDL bắt buộc phải bị Ghost Killer đổi thành COMPLETED
      const record10 = mockDbRows.find((r) => r.id === 10);
      assert.strictEqual(record10.status, 'COMPLETED', 'Bản ghi mồ côi trong CSDL phải được chuyển sang COMPLETED');
      assert.ok(record10.ended_at, 'Phải có thời điểm kết thúc ended_at');

      // - Trong CSDL không còn bất kỳ bản ghi nào mang status ONGOING
      const remainingOngoing = mockDbRows.filter((r) => r.status === 'ONGOING');
      assert.strictEqual(remainingOngoing.length, 0, 'Tuyệt đối không còn bản ghi ONGOING nào trong CSDL');
      assert.strictEqual(result.ghostSessionsClosed >= 1, true);
    });

    it('2.2. [OUTBOX FLUSH] Tự động flush toàn bộ các phiên bảo trì phát sinh trong lúc DB sập vào CSDL khi DB khôi phục', async () => {
      const repo = new MaintenanceRepository({ pool: mockPool });

      // 1. CSDL sập
      dbOnline = false;

      // 2. Phát sinh phiên bảo trì khẩn cấp trong lúc DB sập
      await repo.createRecord({
        type: 'EMERGENCY',
        reason: 'Khắc phục sự cố sập DB',
        activated_by: 'admin_sys',
        status: 'ONGOING',
      });

      // Đã ghi vào queue
      assert.strictEqual(repo._pendingDbSyncQueue.length, 1);
      assert.strictEqual(mockDbRows.length, 0); // CSDL chưa có gì

      // 3. CSDL khôi phục
      dbOnline = true;

      // 4. Thực thi flush hàng đợi bù dữ liệu
      const flushedCount = await repo.flushPendingQueue();

      // TÁC ĐỘNG HỆ THỐNG:
      // - CSDL đã được INSERT bản ghi phiên bảo trì
      assert.strictEqual(flushedCount, 1);
      assert.strictEqual(mockDbRows.length, 1);
      assert.strictEqual(mockDbRows[0].reason, 'Khắc phục sự cố sập DB');

      // - Hàng đợi bù đã được dọn sạch rỗng
      assert.strictEqual(repo._pendingDbSyncQueue.length, 0);
    });

    it('2.3. [STATE ALIGNMENT] Khi hệ thống ĐANG bảo trì thật sự (active = true), CSDL đồng bộ bản ghi ONGOING chính xác', async () => {
      const repo = new MaintenanceRepository({ pool: mockPool });

      // CSDL chưa có bản ghi nào
      dbOnline = true;

      // Hệ thống đang thực sự trong phiên bảo trì khẩn cấp
      const currentActiveState = {
        active: true,
        isEmergency: true,
        reason: 'Nâng cấp máy chủ định kỳ',
        activatedBy: 'admin_ops',
        activatedAt: '2026-10-21T12:00:00.000Z',
      };

      const result = await repo.reconcileWithDatabase({ currentActiveState });

      // TÁC ĐỘNG HỆ THỐNG: CSDL tự động có bản ghi ONGOING đồng bộ với RAM
      assert.strictEqual(mockDbRows.length, 1);
      assert.strictEqual(mockDbRows[0].status, 'ONGOING');
      assert.strictEqual(mockDbRows[0].reason, 'Nâng cấp máy chủ định kỳ');
      assert.strictEqual(result.alignedWithActive, true);
    });

    it('2.4. MaintenanceManager.reconcileStateWithDatabase điều phối thành công toàn bộ chu trình', async () => {
      const repo = new MaintenanceRepository({ pool: mockPool });
      const manager = new MaintenanceManager({
        notificationService: { broadcast: async () => {} },
      });

      // CSDL có bản ghi mồ côi
      mockDbRows.push({
        id: 77,
        type: 'SCHEDULED',
        reason: 'Lịch cũ bị kẹt',
        activated_by: 'admin',
        started_at: '2026-10-21T09:00:00.000Z',
        ended_at: null,
        status: 'ONGOING',
      });

      // Manager đang active = false
      assert.strictEqual(manager.isMaintenanceActive(), false);

      // Kích hoạt reconcile từ Manager
      const res = await manager.reconcileStateWithDatabase(repo);

      assert.strictEqual(res.success, true);
      assert.strictEqual(mockDbRows.find((r) => r.id === 77).status, 'COMPLETED');
    });
  });
});
