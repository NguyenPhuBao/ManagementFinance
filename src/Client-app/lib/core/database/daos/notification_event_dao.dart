import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/notification_event_table.dart';

part 'notification_event_dao.g.dart';

/// Nhật ký thông báo (B5a) — chỉ thêm hàng, B5b mới đọc để học.
///
/// ⚠️ Chuỗi `'dat_lich'` ở đây là chữ thô vì DAO nằm ở tầng CSDL và không được
/// import `core/notification/`: cùng lý lẽ với `watchFeed` nhận `List<String>`
/// thay cho `NotificationGroup`. Ca test `schema_v26_test` canh để hai phía
/// không lệch.
@DriftAccessor(tables: [AppNotificationEvents])
class NotificationEventDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationEventDaoMixin {
  NotificationEventDao(super.db);

  Future<void> ghi(AppNotificationEventsCompanion e) =>
      into(appNotificationEvents).insert(e);

  /// Một giao tác — "Đọc tất cả" ghi N hàng một lần.
  Future<void> ghiNhieu(List<AppNotificationEventsCompanion> es) async {
    if (es.isEmpty) return;
    await batch((b) => b.insertAll(appNotificationEvents, es));
  }

  Future<List<AppNotificationEvent>> getAll(int idaccount) {
    return (select(appNotificationEvents)
          ..where((t) => t.idaccount.equals(idaccount))
          ..orderBy([(t) => OrderingTerm.asc(t.luc)]))
        .get();
  }

  /// `dat_lich` mới nhất (theo mốc hẹn) của [osId] — để `huy_lich` biết khoá.
  Future<AppNotificationEvent?> datLichGanNhat(int idaccount, int osId) {
    return (select(appNotificationEvents)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.suKien.equals('dat_lich') &
              t.osId.equals(osId))
          ..orderBy([(t) => OrderingTerm.desc(t.luc)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Mọi `dat_lich` có mốc hẹn **sau** [moc] — lịch còn chờ lúc đăng xuất.
  Future<List<AppNotificationEvent>> datLichSau(int idaccount, DateTime moc) {
    return (select(appNotificationEvents)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.suKien.equals('dat_lich') &
              t.luc.isBiggerThanValue(moc)))
        .get();
  }

  Future<bool> coDatLich(int idaccount, String dedupeKey) async {
    final r = await (select(appNotificationEvents)
          ..where((t) =>
              t.idaccount.equals(idaccount) &
              t.suKien.equals('dat_lich') &
              t.dedupeKey.equals(dedupeKey))
          ..limit(1))
        .getSingleOrNull();
    return r != null;
  }

  Future<int> purgeOlderThan(DateTime cutoff) {
    return (delete(appNotificationEvents)
          ..where((t) => t.luc.isSmallerThanValue(cutoff)))
        .go();
  }
}
