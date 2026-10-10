/// Cổng đọc / ghi bảng thông báo CỤC BỘ cho **tầng giao diện** (spec bịt điểm rò 2026-10-10, mục 4.4).
///
/// Mảng thông báo không có tầng data (luật ở `core/notification`, giao diện ở `features/notification`), nên trang
/// từng cầm thẳng `sl<AppDatabase>().notificationDao` ở 8 chỗ. Cổng này chỉ **chuyển tiếp** đúng mười hai lối giao
/// diện đang dùng — không luật, không gộp, không đổi tên. `BadgeUpdater` và `NotificationScanner` ở `core` vẫn cầm
/// DAO: chúng là hạ tầng, không phải trang. Cùng khuôn `OsNotifier`: interface + một bản thi hành, tiêm được cho test.
library;

import '../database/app_database.dart';
import '../database/daos/notification_dao.dart';

abstract class ThongBaoNguon {
  Stream<int> watchUnreadCount(int idaccount);
  Stream<List<AppNotification>> watchFeed(int idaccount, {int limit = 50, List<String>? kinds, bool chiChuaDoc = false});
  Future<List<AppNotification>> getAll(int idaccount);
  Stream<int> watchDemBienDong(int idaccount);
  Future<void> markRead(String id);
  Future<void> markAllRead(int idaccount);
  Future<void> markUnread(String id);
  Future<List<String>> khoaChuaDoc(int idaccount);
  Future<void> dismiss(String id);
  Future<void> khoiPhuc(String id);
  Future<bool> insertIfAbsent(AppNotificationsCompanion entry);
  Future<int> xoaCung(int idaccount, String dedupeKey);
}

/// Bản thi hành duy nhất ngoài test: chuyển tiếp 1–1 sang [NotificationDao].
class ThongBaoNguonDrift implements ThongBaoNguon {
  ThongBaoNguonDrift(this._dao);
  final NotificationDao _dao;

  @override
  Stream<int> watchUnreadCount(int idaccount) => _dao.watchUnreadCount(idaccount);
  @override
  Stream<List<AppNotification>> watchFeed(int idaccount, {int limit = 50, List<String>? kinds, bool chiChuaDoc = false}) =>
      _dao.watchFeed(idaccount, limit: limit, kinds: kinds, chiChuaDoc: chiChuaDoc);
  @override
  Future<List<AppNotification>> getAll(int idaccount) => _dao.getAll(idaccount);
  @override
  Stream<int> watchDemBienDong(int idaccount) => _dao.watchDemBienDong(idaccount);
  @override
  Future<void> markRead(String id) => _dao.markRead(id);
  @override
  Future<void> markAllRead(int idaccount) => _dao.markAllRead(idaccount);
  @override
  Future<void> markUnread(String id) => _dao.markUnread(id);
  @override
  Future<List<String>> khoaChuaDoc(int idaccount) => _dao.khoaChuaDoc(idaccount);
  @override
  Future<void> dismiss(String id) => _dao.dismiss(id);
  @override
  Future<void> khoiPhuc(String id) => _dao.khoiPhuc(id);
  @override
  Future<bool> insertIfAbsent(AppNotificationsCompanion entry) => _dao.insertIfAbsent(entry);
  @override
  Future<int> xoaCung(int idaccount, String dedupeKey) => _dao.xoaCung(idaccount, dedupeKey);
}
