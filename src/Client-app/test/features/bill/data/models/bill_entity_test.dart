/// `BillEntity` — kiểu duy nhất của hoá đơn từ repository trở lên (spec Entity Hoá đơn 2026-10-14 mục 4.1).
///
/// Ca đầu đếm cột bằng máy: thêm cột vào bảng `Bills` mà quên thêm trường là đỏ ở đây, không phải ở màn hình.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/bill/data/models/bill_entity.dart';

/// Cột của bảng `Bills` mà entity CÓ (tên cột SQL). Ba cột lỗi đồng bộ cố ý vắng — không chỗ nào ngoài `core/sync` đọc.
const cotCuaEntity = {
  'id',
  'idaccount',
  'wallet_id',
  'category_id',
  'name',
  'amount',
  'start_date',
  'due_date',
  'pay_status',
  'is_paid',
  'time_notification',
  'is_recurrence',
  'time_recurrence',
  'recurrence',
  'icon',
  'colour',
  'note',
  'generated_from_bill_id',
  'period_end',
  'auto_pay_enabled',
  'anchor_day',
  'deleted_at',
  'is_deleted',
  'sync_status',
  'updated_at',
};
const cotBo = {'sync_retry_count', 'sync_error', 'sync_blocked_until'};

Bill hangMau() => Bill(
      id: 'b1',
      idaccount: 7,
      walletId: 'w1',
      categoryId: 'c1',
      name: 'Tiền điện',
      amount: 300000,
      startDate: DateTime(2026, 9, 1),
      dueDate: DateTime(2026, 9, 20),
      payStatus: 'Payed',
      isPaid: true,
      timeNotification: '3',
      isRecurrence: true,
      timeRecurrence: 'Month',
      recurrence: 'monthly',
      icon: 'bolt',
      colour: '#FF0000',
      note: 'ghi chú',
      generatedFromBillId: 'b0',
      periodEnd: DateTime(2026, 9, 18),
      autoPayEnabled: true,
      anchorDay: 31,
      deletedAt: DateTime(2026, 9, 21),
      isDeleted: true,
      syncStatus: 'synced',
      syncRetryCount: 2,
      syncError: 'x',
      syncBlockedUntil: DateTime(2026, 9, 22),
      updatedAt: DateTime(2026, 9, 21, 8),
    );

void main() {
  test('đếm bằng máy: cột bảng Bills = cột entity + ba cột lỗi đồng bộ',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final cot = db.bills.$columns.map((c) => c.$name).toSet();
    expect(cot, cotCuaEntity.union(cotBo),
        reason:
            'Thêm cột vào Bills thì thêm trường vào BillEntity (và fromDrift, copyWith, ==) rồi cập nhật cotCuaEntity.');
  });

  test('fromDrift chép đủ 25 trường', () {
    final d = hangMau();
    final e = BillEntity.fromDrift(d);
    expect(e.id, d.id);
    expect(e.idaccount, d.idaccount);
    expect(e.walletId, d.walletId);
    expect(e.categoryId, d.categoryId);
    expect(e.name, d.name);
    expect(e.amount, d.amount);
    expect(e.startDate, d.startDate);
    expect(e.dueDate, d.dueDate);
    expect(e.payStatus, d.payStatus);
    expect(e.isPaid, d.isPaid);
    expect(e.timeNotification, d.timeNotification);
    expect(e.isRecurrence, d.isRecurrence);
    expect(e.timeRecurrence, d.timeRecurrence);
    expect(e.recurrence, d.recurrence);
    expect(e.icon, d.icon);
    expect(e.colour, d.colour);
    expect(e.note, d.note);
    expect(e.generatedFromBillId, d.generatedFromBillId);
    expect(e.periodEnd, d.periodEnd);
    expect(e.autoPayEnabled, d.autoPayEnabled);
    expect(e.anchorDay, d.anchorDay);
    expect(e.deletedAt, d.deletedAt);
    expect(e.isDeleted, d.isDeleted);
    expect(e.syncStatus, d.syncStatus);
    expect(e.updatedAt, d.updatedAt);
  });

  test('== theo mọi trường; copyWith giữ phần không đổi', () {
    final a = BillEntity.fromDrift(hangMau());
    final b = BillEntity.fromDrift(hangMau());
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.copyWith(dueDate: DateTime(2026, 10, 20)), isNot(a));
    final c = a.copyWith(
        startDate: DateTime(2026, 10, 1),
        periodEnd: DateTime(2026, 10, 18),
        anchorDay: 15);
    expect((c.startDate, c.periodEnd, c.anchorDay, c.name, c.dueDate),
        (DateTime(2026, 10, 1), DateTime(2026, 10, 18), 15, a.name, a.dueDate));
  });

  test('giá trị mặc định khớp mặc định của bảng (fixture test dựng gọn)', () {
    final e = BillEntity(
        id: 'x',
        idaccount: 1,
        name: 'n',
        amount: 1,
        dueDate: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1));
    expect((
      e.payStatus,
      e.isPaid,
      e.isRecurrence,
      e.timeRecurrence,
      e.recurrence,
      e.icon,
      e.colour,
      e.note,
      e.autoPayEnabled,
      e.isDeleted,
      e.syncStatus
    ), (
      'Pending',
      false,
      false,
      'Month',
      'monthly',
      'receipt',
      '#4CAF50',
      '',
      false,
      false,
      'pending'
    ));
  });
}
