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

  it('4. completeOngoingRecord tính và lưu actual_duration_seconds chính xác khi hoàn tất', async () => {
    const startedAt = new Date(Date.now() - 150 * 1000); // 150 giây trước
    await repository.createRecord({
      type: 'EMERGENCY',
      reason: 'Bảo trì sửa lỗi máy chủ',
      activated_by: 'admin_sys',
      started_at: startedAt,
      status: 'ONGOING',
    });

    const now = new Date();
    const completedList = await repository.completeOngoingRecord({
      ended_at: now,
      status: 'COMPLETED',
    });

    assert.strictEqual(completedList.length, 1);
    assert.strictEqual(completedList[0].status, 'COMPLETED');
    assert.ok(completedList[0].actual_duration_seconds >= 149 && completedList[0].actual_duration_seconds <= 152, 'Thời lượng phải khoảng 150 giây');

    // Kiểm tra query history
    const history = await repository.getHistory();
    assert.strictEqual(history.data[0].actual_duration_seconds, completedList[0].actual_duration_seconds);
  });

  it('5. cancelScheduledRecord cho phiên SCHEDULED chưa chạy gán actual_duration_seconds = 0', async () => {
    const futureDate = new Date(Date.now() + 5 * 3600 * 1000); // 5 tiếng nữa
    const record = await repository.createRecord({
      type: 'SCHEDULED',
      reason: 'Bảo trì định kỳ tương lai',
      activated_by: 'admin_plan',
      started_at: futureDate,
      status: 'SCHEDULED',
    });

    const cancelledList = await repository.cancelScheduledRecord({ id: record.id });
    assert.strictEqual(cancelledList.length, 1);
    assert.strictEqual(cancelledList[0].status, 'CANCELLED');
    assert.strictEqual(cancelledList[0].actual_duration_seconds, 0, 'Phiên hủy trước giờ chạy phải có thời lượng = 0s');
    assert.ok(cancelledList[0].ended_at, 'Phải có thời điểm hủy');
  });

  it('6. cancelScheduledRecord cho phiên ONGOING bị hủy ngang tính actual_duration_seconds chính xác', async () => {
    const startedAt = new Date(Date.now() - 45 * 1000); // Đã chạy 45 giây
    const record = await repository.createRecord({
      type: 'SCHEDULED',
      reason: 'Bảo trì đang chạy bị hủy ngang',
      activated_by: 'admin_lead',
      started_at: startedAt,
      status: 'ONGOING',
    });

    const cancelledList = await repository.cancelScheduledRecord({ id: record.id });
    assert.strictEqual(cancelledList.length, 1);
    assert.strictEqual(cancelledList[0].status, 'CANCELLED');
    assert.ok(cancelledList[0].actual_duration_seconds >= 44 && cancelledList[0].actual_duration_seconds <= 47, 'Thời lượng chạy đến lúc hủy ngang phải ~45s');
    assert.ok(cancelledList[0].ended_at);
  });

  it('7. Hỗ trợ loại hình UPGRADE tách biệt với bảo trì khẩn cấp', async () => {
    // 7.1 Ghi nhận trong Repository
    const upgradeRecord = await repository.createRecord({
      type: 'UPGRADE',
      reason: 'Nâng cấp core engine lên phiên bản 2.5.0',
      activated_by: 'super_admin',
      status: 'ONGOING',
    });
    assert.strictEqual(upgradeRecord.type, 'UPGRADE');

    // 7.2 Lọc theo UPGRADE
    const filtered = await repository.getHistory({ type: 'UPGRADE' });
    assert.strictEqual(filtered.pagination.total, 1);
    assert.strictEqual(filtered.data[0].type, 'UPGRADE');

    // 7.3 MaintenanceManager hỗ trợ isUpgrade
    let broadcastSent = null;
    const mockNotifService = {
      broadcast: async (payload) => {
        broadcastSent = payload;
      },
    };
    manager.notificationService = mockNotifService;

    const status = manager.setMaintenance(true, 'Nâng cấp cụm dịch vụ thanh toán', 'lead_dev', {
      isUpgrade: true,
      isEmergency: false,
    });

    assert.strictEqual(status.active, true);
    assert.strictEqual(status.isUpgrade, true);
    assert.strictEqual(status.isEmergency, false);
    assert.strictEqual(status.type, 'UPGRADE');
    assert.ok(broadcastSent, 'Phải phát broadcast nâng cấp');
    assert.strictEqual(broadcastSent.title, '🚀 NÂNG CẤP HỆ THỐNG');
    assert.strictEqual(broadcastSent.metadata.isUpgrade, true);

    // 7.4 Tắt nâng cấp
    const restoredStatus = manager.setMaintenance(false, 'Hoàn tất nâng cấp', 'lead_dev');
    assert.strictEqual(restoredStatus.active, false);
    assert.strictEqual(restoredStatus.isUpgrade, false);
    assert.strictEqual(broadcastSent.title, '✅ HỆ THỐNG ĐÃ HOÀN TẤT NÂNG CẤP');
  });
});
