/// `ThongBaoRepository` — repository của mảng Thông báo trên `NotificationDao` (spec Entity Thông báo 2026-10-15 mục 4.2; trước là
/// `ThongBaoNguon`, spec bịt điểm rò 2026-10-10 mục 4.4). Không mang luật: mỗi lối chuyển tiếp đúng một hàm DAO, map Entity ở biên.
/// Test này canh "chuyển tiếp đúng hàm" và "chenLai trả hàng y nguyên", không canh luật của DAO. `==` sau vòng tròn CSDL đứng được vì
/// Drift lưu `DateTime` dạng giây và trả `DateTime` local (fixture mốc tròn giây) — xem `notification_entity_companion_test`.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/database/daos/notification_dao.dart'
    show kKindBienDongSoDu;
import 'package:flowmoney/features/notification/data/models/notification_entity.dart';
import 'package:flowmoney/features/notification/data/repositories/thong_bao_repository.dart';
import 'package:flowmoney/features/notification/data/repositories/thong_bao_repository_impl.dart';

void main() {
  late AppDatabase db;
  late ThongBaoRepository repo;
  final moc = DateTime(2026, 10, 10, 8);

  NotificationEntity hang(String id, {String kind = 'billDue'}) =>
      NotificationEntity(
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
    repo = ThongBaoRepositoryImpl(db.notificationDao);
  });
  tearDown(() => db.close());

  test('chenLai · getAll · watchUnreadCount · watchFeed — trả Entity',
      () async {
    expect(await repo.chenLai(hang('n1')), isTrue);
    expect(await repo.chenLai(hang('n1')), isFalse,
        reason: 'trùng dedupeKey thì không chèn');
    final tatCa = await repo.getAll(10);
    expect(tatCa, hasLength(1));
    expect(tatCa.single, hang('n1'),
        reason: 'chenLai rồi đọc lại phải y nguyên — Hoàn tác D1 dựa vào đó.');
    expect(await repo.watchUnreadCount(10).first, 1);
    expect((await repo.watchFeed(10, limit: 3).first).single.id, 'n1');
  });

  test('markRead / markUnread / markAllRead / khoaChuaDoc đổi đúng số chưa đọc',
      () async {
    await repo.chenLai(hang('n1'));
    await repo.chenLai(hang('n2'));
    await repo.markRead('n1');
    expect(await repo.watchUnreadCount(10).first, 1);
    expect(await repo.khoaChuaDoc(10), ['k-n2']);
    await repo.markUnread('n1');
    expect(await repo.watchUnreadCount(10).first, 2);
    await repo.markAllRead(10);
    expect(await repo.watchUnreadCount(10).first, 0);
  });

  test('dismiss / khoiPhuc / xoaCung', () async {
    await repo.chenLai(hang('n1', kind: kKindBienDongSoDu));
    await repo.dismiss('n1');
    expect(await repo.watchFeed(10).first, isEmpty,
        reason: 'feed bỏ hàng đã gỡ');
    await repo.khoiPhuc('n1');
    expect(await repo.watchFeed(10).first, hasLength(1));
    expect(await repo.xoaCung(10, 'k-n1'), 1,
        reason: 'xoaCung chỉ xoá hàng loại biến động số dư');
    expect(await repo.getAll(10), isEmpty);
  });

  test('watchDemBienDong đếm hàng loại 20 (bienDongSoDu)', () async {
    await repo.chenLai(hang('n1', kind: kKindBienDongSoDu));
    expect(await repo.watchDemBienDong(10).first, 1);
  });
}
