/// `companionTu` — ánh xạ ngược duy nhất `NotificationEntity` → `AppNotificationsCompanion` (spec Entity Thông báo 2026-10-15, 4.3), cho
/// *Hoàn tác* sau khi vuốt xoá cứng hàng biến động D1: hàng phải về **y nguyên** 14 trường. Vòng tròn: chèn `companionTu(e)` rồi đọc lại
/// bằng `fromDrift` phải `==` e — cả khi mọi trường nullable có giá trị lẫn khi tất cả `null`.
/// Drift của dự án lưu `DateTime` dạng số nguyên GIÂY (không `storeDateTimeAsText` — đo 2026-10-15) nên hàng đọc lại là `DateTime`
/// local cùng mốc giây: fixture dùng mốc tròn giây và `==` của Equatable so được. Nếu một ngày bật text mode (hàng về UTC) thì ca này đỏ —
/// khi ấy đổi sang so từng trường bằng `isAtSameMomentAs`, đừng sửa Entity.
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/notification/data/models/notification_entity.dart';
import 'package:flowmoney/features/notification/data/models/notification_entity_companion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final moc = DateTime(2026, 10, 15, 7);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<NotificationEntity> vongTron(NotificationEntity e) async {
    expect(await db.notificationDao.insertIfAbsent(companionTu(e)), isTrue);
    return NotificationEntity.fromDrift(
        (await db.notificationDao.getAll(e.idaccount)).single);
  }

  test('đủ 14 trường — hàng đọc lại == Entity gốc', () async {
    final e = NotificationEntity(
      id: 'n1',
      idaccount: 10,
      kind: 'bienDongSoDu',
      dedupeKey: 'bienDong:mb:1',
      title: 'T',
      body: 'B',
      severity: 'info',
      subjectType: 'wallet',
      subjectId: 'w1',
      deeplink: '/add?khoa=bienDong:mb:1',
      createdAt: moc,
      readAt: moc.add(const Duration(minutes: 1)),
      dismissedAt: moc.add(const Duration(minutes: 2)),
      osDeliveredAt: moc.add(const Duration(minutes: 3)),
    );
    expect(await vongTron(e), e,
        reason:
            'Thiếu một trường trong companionTu là Hoàn tác trả về hàng khác hàng đã xoá.');
  });

  test('mọi trường nullable null — vẫn == và không bịa giá trị', () async {
    final e = NotificationEntity(
        id: 'n2',
        idaccount: 10,
        kind: 'billDue',
        dedupeKey: 'k2',
        title: 'T',
        body: 'B',
        severity: 'warning',
        createdAt: moc);
    final doc = await vongTron(e);
    expect(doc, e);
    expect(doc.readAt, isNull);
    expect(doc.osDeliveredAt, isNull);
  });
}
