import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/notification_table.dart';

part 'notification_dao.g.dart';

@DriftAccessor(tables: [AppNotifications])
class NotificationDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationDaoMixin {
  NotificationDao(super.db);

  /// Chèn nếu chưa có. Trả `true` **chỉ khi hàng thật sự được ghi**.
  ///
  /// Giá trị trả về là tín hiệu DUY NHẤT quyết định có bắn thông báo ra hệ điều
  /// hành hay không. Báo nhầm `true` là người dùng nhận lại thông báo cũ mỗi
  /// lần mở app.
  ///
  /// Dùng `insertReturningOrNull` chứ không đọc rowid: với `OR IGNORE`, khi
  /// đụng ràng buộc SQLite không chèn gì và `last_insert_rowid()` giữ nguyên
  /// giá trị của lần chèn TRƯỚC — đọc nó sẽ tưởng là vừa chèn thành công.
  Future<bool> insertIfAbsent(AppNotificationsCompanion entry) async {
    final row = await into(appNotifications)
        .insertReturningOrNull(entry, mode: InsertMode.insertOrIgnore);
    return row != null;
  }

  /// Chèn cả loạt, trả về những companion **thật sự** được ghi.
  Future<List<AppNotificationsCompanion>> insertAllIfAbsent(
    List<AppNotificationsCompanion> entries,
  ) async {
    final moi = <AppNotificationsCompanion>[];
    await transaction(() async {
      for (final e in entries) {
        if (await insertIfAbsent(e)) moi.add(e);
      }
    });
    return moi;
  }

  /// Đường thô — gồm cả hàng đã xoá mềm. Dùng cho khoá trùng và dọn dẹp.
  Future<List<AppNotification>> getAll(int idaccount) {
    return (select(appNotifications)
          ..where((t) => t.idaccount.equals(idaccount)))
        .get();
  }

  /// Danh sách hiển thị: bỏ hàng đã xoá mềm, mới nhất lên trước.
  Stream<List<AppNotification>> watchFeed(int idaccount, {int limit = 50}) {
    return (select(appNotifications)
          ..where((t) =>
              t.idaccount.equals(idaccount) & t.dismissedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  Stream<int> watchUnreadCount(int idaccount) {
    final dem = appNotifications.id.count();
    final q = selectOnly(appNotifications)
      ..addColumns([dem])
      ..where(appNotifications.idaccount.equals(idaccount) &
          appNotifications.readAt.isNull() &
          appNotifications.dismissedAt.isNull());
    return q.map((r) => r.read(dem) ?? 0).watchSingle();
  }

  Future<void> markRead(String id) async {
    await (update(appNotifications)..where((t) => t.id.equals(id)))
        .write(AppNotificationsCompanion(readAt: Value(DateTime.now())));
  }

  Future<void> markAllRead(int idaccount) async {
    await (update(appNotifications)
          ..where((t) =>
              t.idaccount.equals(idaccount) & t.readAt.isNull()))
        .write(AppNotificationsCompanion(readAt: Value(DateTime.now())));
  }

  /// Xoá mềm. Xem chú thích cột `dismissedAt` để biết vì sao không DELETE.
  Future<void> dismiss(String id) async {
    await (update(appNotifications)..where((t) => t.id.equals(id)))
        .write(AppNotificationsCompanion(dismissedAt: Value(DateTime.now())));
  }

  /// Dọn hàng cũ. Bảng này chỉ lớn lên — hàng đã xoá mềm phải giữ để chặn
  /// trùng — nên không dọn thì sau một năm màn danh sách tải hàng nghìn hàng.
  /// An toàn vì mọi `dedupeKey` đều đã hết hạn từ lâu trước mốc cắt.
  Future<int> purgeOlderThan(DateTime cutoff) {
    return (delete(appNotifications)
          ..where((t) => t.createdAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
