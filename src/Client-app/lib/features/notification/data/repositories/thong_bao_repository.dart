import '../models/notification_entity.dart';

/// Cổng đọc / ghi bảng thông báo CỤC BỘ của mảng — repository của Thông báo (spec Entity Thông báo 2026-10-15 mục 4.2; trước đó là
/// `ThongBaoNguon` ở `core/notification`, spec bịt điểm rò 2026-10-10 mục 4.4).
///
/// Chỉ **chuyển tiếp** đúng mười hai lối giao diện và nguồn Thêm giao dịch đang dùng — không luật, không gộp. Interface chỉ nhận / trả
/// `NotificationEntity` và Dart thuần (quét 27 luật 4): hàng Drift dừng ở `ThongBaoRepositoryImpl`. Bộ quét, `BadgeUpdater` và ba bộ nhập
/// ở `application/` vẫn cầm `NotificationDao` — chúng là bộ điều phối, không phải trang.
abstract class ThongBaoRepository {
  Stream<int> watchUnreadCount(int idaccount);
  Stream<List<NotificationEntity>> watchFeed(int idaccount,
      {int limit = 50, List<String>? kinds, bool chiChuaDoc = false});
  Future<List<NotificationEntity>> getAll(int idaccount);
  Stream<int> watchDemBienDong(int idaccount);
  Future<void> markRead(String id);
  Future<void> markAllRead(int idaccount);
  Future<void> markUnread(String id);
  Future<List<String>> khoaChuaDoc(int idaccount);
  Future<void> dismiss(String id);
  Future<void> khoiPhuc(String id);

  /// Chèn lại một hàng **y nguyên** (14 trường) nếu chưa có khoá ấy — *Hoàn tác* sau khi vuốt xoá cứng hàng biến động D1. Trả `true`
  /// chỉ khi hàng thật sự được ghi (giữ hợp đồng `NotificationDao.insertIfAbsent`). Thay `insertIfAbsent(AppNotificationsCompanion)`.
  Future<bool> chenLai(NotificationEntity hang);
  Future<int> xoaCung(int idaccount, String dedupeKey);
}
