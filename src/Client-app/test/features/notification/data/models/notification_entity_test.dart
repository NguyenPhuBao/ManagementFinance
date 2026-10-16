/// `NotificationEntity.fromDrift` — Entity Thông báo, kiểu duy nhất từ repository trở lên (spec Entity Thông báo 2026-10-15, 4.1).
/// Đếm cột bằng máy: Entity = cột bảng − 1 (`osScheduledId` — 0 chỗ đọc, 0 chỗ ghi trong `lib`, đo 2026-10-15).
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/notification/data/models/notification_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final moc = DateTime(2026, 10, 15, 7);
  AppNotification hang({String id = 'n-1'}) => AppNotification(
        id: id,
        idaccount: 10,
        kind: 'billDue',
        dedupeKey: 'billDue:b1:2026-10-20:3',
        title: 'Sắp đến hạn',
        body: 'Tiền nhà 20/10',
        severity: 'warning',
        subjectType: 'bill',
        subjectId: 'b1',
        deeplink: '/bills/b1',
        createdAt: moc,
        readAt: moc.add(const Duration(minutes: 1)),
        dismissedAt: moc.add(const Duration(minutes: 2)),
        osScheduledId: 42,
        osDeliveredAt: moc.add(const Duration(minutes: 3)),
      );

  test('fromDrift chép đủ 14 trường, không chép osScheduledId', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final e = NotificationEntity.fromDrift(hang());
    expect(e.props.length, db.appNotifications.$columns.length - 1,
        reason:
            'Thêm cột vào bảng AppNotifications thì quyết định: vào Entity, hay ghi vào danh sách cột không chép.');
    expect(e.id, 'n-1');
    expect(e.idaccount, 10);
    expect(e.kind, 'billDue');
    expect(e.dedupeKey, 'billDue:b1:2026-10-20:3');
    expect(e.title, 'Sắp đến hạn');
    expect(e.body, 'Tiền nhà 20/10');
    expect(e.severity, 'warning');
    expect(e.subjectType, 'bill');
    expect(e.subjectId, 'b1');
    expect(e.deeplink, '/bills/b1');
    expect(e.createdAt, moc);
    expect(e.readAt, moc.add(const Duration(minutes: 1)));
    expect(e.dismissedAt, moc.add(const Duration(minutes: 2)));
    expect(e.osDeliveredAt, moc.add(const Duration(minutes: 3)));
  });

  test(
      'đẳng thức theo giá trị — hai bản map từ cùng hàng là ==, khác id thì không',
      () {
    expect(NotificationEntity.fromDrift(hang()),
        NotificationEntity.fromDrift(hang()),
        reason:
            'Hoàn tác D1 chèn lại đúng hàng đã chụp — so theo giá trị mới kiểm được "y nguyên".');
    expect(NotificationEntity.fromDrift(hang()).hashCode,
        NotificationEntity.fromDrift(hang()).hashCode);
    expect(NotificationEntity.fromDrift(hang()),
        isNot(NotificationEntity.fromDrift(hang(id: 'n-2'))));
  });
}
