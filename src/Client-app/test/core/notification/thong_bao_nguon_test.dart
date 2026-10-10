/// `ThongBaoNguon` — cổng cho tầng giao diện trên `NotificationDao` (spec bịt điểm rò 2026-10-10, mục 4.4). Không mang
/// luật: mỗi lối chuyển tiếp đúng một hàm DAO. Test này canh "chuyển tiếp đúng hàm", không canh luật của DAO.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/database/daos/notification_dao.dart' show kKindBienDongSoDu;
import 'package:flowmoney/core/notification/thong_bao_nguon.dart';

void main() {
  late AppDatabase db;
  late ThongBaoNguon nguon;
  final moc = DateTime(2026, 10, 10, 8);

  AppNotificationsCompanion hang(String id, {String kind = 'billDue'}) => AppNotificationsCompanion.insert(
        id: id,
        idaccount: 10,
        kind: kind,
        dedupeKey: 'k-$id',
        title: 'T $id',
        body: 'B $id',
        severity: 'info',
        createdAt: moc,
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    nguon = ThongBaoNguonDrift(db.notificationDao);
  });
  tearDown(() => db.close());

  test('insertIfAbsent · getAll · watchUnreadCount · watchFeed', () async {
    expect(await nguon.insertIfAbsent(hang('n1')), isTrue);
    expect(await nguon.insertIfAbsent(hang('n1')), isFalse, reason: 'trùng dedupeKey thì không chèn');
    expect(await nguon.getAll(10), hasLength(1));
    expect(await nguon.watchUnreadCount(10).first, 1);
    expect((await nguon.watchFeed(10, limit: 3).first).single.id, 'n1');
  });

  test('markRead / markUnread / markAllRead / khoaChuaDoc đổi đúng số chưa đọc', () async {
    await nguon.insertIfAbsent(hang('n1'));
    await nguon.insertIfAbsent(hang('n2'));
    await nguon.markRead('n1');
    expect(await nguon.watchUnreadCount(10).first, 1);
    expect(await nguon.khoaChuaDoc(10), ['k-n2']);
    await nguon.markUnread('n1');
    expect(await nguon.watchUnreadCount(10).first, 2);
    await nguon.markAllRead(10);
    expect(await nguon.watchUnreadCount(10).first, 0);
  });

  test('dismiss / khoiPhuc / xoaCung', () async {
    await nguon.insertIfAbsent(hang('n1', kind: kKindBienDongSoDu));
    await nguon.dismiss('n1');
    expect(await nguon.watchFeed(10).first, isEmpty, reason: 'feed bỏ hàng đã gỡ');
    await nguon.khoiPhuc('n1');
    expect(await nguon.watchFeed(10).first, hasLength(1));
    expect(await nguon.xoaCung(10, 'k-n1'), 1, reason: 'xoaCung chỉ xoá hàng loại biến động số dư');
    expect(await nguon.getAll(10), isEmpty);
  });

  test('watchDemBienDong đếm hàng loại 20 (bienDongSoDu)', () async {
    await nguon.insertIfAbsent(hang('n1', kind: kKindBienDongSoDu));
    expect(await nguon.watchDemBienDong(10).first, 1);
  });
}
