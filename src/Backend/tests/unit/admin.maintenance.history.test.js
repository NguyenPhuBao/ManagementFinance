/**
 * Test: Maintenance History Persistence & Emergency Default (2-Tier: Backend System Impact)
 * Kiểm tra bảo trì tức thì luôn mặc định là KHẨN CẤP và tự động lưu trữ lịch sử vào CSDL kèm người kích hoạt.
 */
const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert');
const {
  MaintenanceManager,
} = require('../../core/resilience/maintenance.manager');
const {
  MaintenanceRepository,
} = require('../../modules/admin/maintenance.repository');

describe('Maintenance History & Emergency Mode Architecture Suite', () => {
  let repository;
  let manager;

  beforeEach(() => {
    repository = new MaintenanceRepository({ pool: null }); // Sử dụng in-memory engine sạch
    manager = new MaintenanceManager();
  });

  it('1. setMaintenance(true) mặc định là BẢO TRÌ KHẨN CẤP và lưu bản ghi vào CSDL', async () => {
    const adminName = 'admin_super_hero';
    const reason = 'Nâng cấp cụm máy chủ khẩn cấp chống rò rỉ bộ nhớ';

    const status = manager.setMaintenance(true, reason, adminName);

    assert.strictEqual(status.active, true, 'Hệ thống phải ở trạng thái active');
    assert.strictEqual(status.isEmergency, true, 'Bảo trì tức thì BẮT BUỘC luôn là khẩn cấp');
    assert.strictEqual(status.activatedBy, adminName, 'Phải lưu danh tính người kích hoạt');
    assert.strictEqual(status.reason, reason, 'Phải lưu đúng lý do');

    // Kiểm tra trực tiếp vào repository
    const hist = await repository.createRecord({
      type: 'EMERGENCY',
      reason,
      activated_by: adminName,
      status: 'ONGOING',
    });

    assert.ok(hist.id, 'Phải có ID bản ghi');
    assert.strictEqual(hist.type, 'EMERGENCY');
    assert.strictEqual(hist.activated_by, adminName);
    assert.strictEqual(hist.status, 'ONGOING');
    assert.strictEqual(hist.ended_at, null);
  });

  it('2. setMaintenance(false) tự động hoàn tất phiên bảo trì và cập nhật ended_at', async () => {
    const adminName = 'security_admin';
    await repository.createRecord({
      type: 'EMERGENCY',
      reason: 'Khắc phục sự cố mạng',
      activated_by: adminName,
      status: 'ONGOING',
    });

    // Tắt bảo trì
    const completedList = await repository.completeOngoingRecord({
      ended_at: new Date(),
      status: 'COMPLETED',
    });

    assert.strictEqual(completedList.length, 1);
    assert.strictEqual(completedList[0].status, 'COMPLETED');
    assert.ok(completedList[0].ended_at, 'Phải có thời điểm kết thúc');

    // Kiểm tra query history
    const history = await repository.getHistory({ page: 1, limit: 10 });
    assert.strictEqual(history.pagination.total, 1);
    assert.strictEqual(history.data[0].status, 'COMPLETED');
  });

  it('3. getHistory hỗ trợ phân trang và bộ lọc type / status', async () => {
    // Tạo 3 bản ghi mẫu
    await repository.createRecord({
      type: 'EMERGENCY',
      reason: 'Sự cố 1',
      activated_by: 'admin1',
      status: 'COMPLETED',
    });
    await repository.createRecord({
      type: 'SCHEDULED',
      reason: 'Bảo trì định kỳ',
      activated_by: 'admin2',
      status: 'ONGOING',
    });
    await repository.createRecord({
      type: 'SCHEDULED',
      reason: 'Bảo trì bị hủy',
      activated_by: 'admin3',
      status: 'CANCELLED',
    });

    // Lọc theo type = EMERGENCY
    const emergencyOnly = await repository.getHistory({ type: 'EMERGENCY' });
    assert.strictEqual(emergencyOnly.pagination.total, 1);
    assert.strictEqual(emergencyOnly.data[0].activated_by, 'admin1');

    // Lọc theo status = ONGOING
    const ongoingOnly = await repository.getHistory({ status: 'ONGOING' });
    assert.strictEqual(ongoingOnly.pagination.total, 1);
    assert.strictEqual(ongoingOnly.data[0].type, 'SCHEDULED');

    // Lấy toàn bộ với phân trang
    const all = await repository.getHistory({ page: 1, limit: 2 });
    assert.strictEqual(all.pagination.total, 3);
    assert.strictEqual(all.data.length, 2);
    assert.strictEqual(all.pagination.totalPages, 2);
  });
});
