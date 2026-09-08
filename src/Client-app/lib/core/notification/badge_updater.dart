import 'dart:async';

// `show debugPrint` chứ không import trần: foundation phơi ra `Category`, trùng
// tên với data class Drift mà `app_database.dart` mang theo — đúng vết
// `notification_scanner.dart` đã phải tránh.
import 'package:flutter/foundation.dart' show debugPrint;

import '../database/daos/notification_dao.dart';
import 'os/os_notifier.dart';
import 'os/os_scheduled_id.dart';

/// Giữ badge trên icon app khớp với số thông báo **chưa đọc trong app**.
///
/// ## Vì sao cần một lớp riêng
///
/// Chuông trong app đọc thẳng `watchUnreadCount` nên nó luôn đúng. Badge thì
/// không: nó sống ở tầng hệ điều hành và chỉ đổi khi có ai đó nói cho hệ điều
/// hành biết. Rải lời gọi ấy vào `markRead`, `markAllRead`, `markUnread`,
/// `dismiss` và `khoiPhuc` là năm chỗ phải nhớ, và chỗ bị quên sẽ hỏng **âm
/// thầm** — badge lệch không ném lỗi, không ghi log. Nghe một stream thì chỉ
/// có một nguồn sự thật, và nó bắt được cả những đường ghi chưa tồn tại.
///
/// ## Vì sao huỷ theo từng id chứ không dọn sạch khay
///
/// Trên Android badge suy từ **thông báo đang nằm trên khay**, không từ bảng
/// `AppNotifications`. Nên đọc hết trong app mà không đụng tới khay thì chấm
/// trên icon vẫn sáng vĩnh viễn — badge chỉ đúng một nửa.
///
/// Nhưng dọn sạch khay là **sai**, vì có những thông báo trên khay mà bảng
/// không hề biết:
///
/// - **Lịch nhắc hoá đơn nổ lúc app đóng.** Hàng trong bảng chỉ sinh *sau đó*,
///   khi app mở và vòng quét chạy — xem `ReminderScheduler`. Trước lúc ấy khay
///   có, bảng trống.
/// - **Nhắc ghi chép hằng ngày** thì *không bao giờ* sinh hàng: nó cố ý chỉ
///   sống ở tầng hệ điều hành.
///
/// Số chưa đọc hoàn toàn có thể bằng 0 trong khi khay đang có một lời nhắc
/// thật chưa ai xem. Dọn sạch ở đó là **xoá mất nó**.
///
/// Nên [dongBo] đi từ chiều ngược lại: chỉ huỷ những id **suy ra được từ
/// `dedupeKey` của một hàng đã đọc**. Lời nhắc ghi chép mang khoá không có
/// trong bảng, nên nó miễn nhiễm **theo cấu trúc** — không nhờ một điều kiện
/// `if` nào mà người sau có thể dọn nhầm.
class BadgeUpdater {
  BadgeUpdater({required this.dao, required this.osNotifier});

  final NotificationDao dao;
  final OsNotifier osNotifier;

  StreamSubscription<int>? _sub;

  /// Bắt đầu theo dõi tài khoản [idaccount].
  ///
  /// Luỹ đẳng: gọi lại huỷ subscription cũ trước, đúng khuôn
  /// `NotificationScanner.start()`.
  Future<void> start(int idaccount) async {
    await _sub?.cancel();
    _sub = dao.watchUnreadCount(idaccount).listen((_) {
      unawaited(dongBo(idaccount));
    });
  }

  /// Dừng theo dõi. **Không** đụng tới badge: `NotificationScanner.stop()` đã
  /// gọi `cancelAll()` trên đường đăng xuất, và đặt badge sau lời gọi ấy là
  /// dựng lại đúng thứ vừa dọn đi.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Một lượt đồng bộ badge với trạng thái thật.
  ///
  /// Nuốt mọi lỗi: nơi gọi là một stream chạy suốt vòng đời app, và badge lệch
  /// là phiền chứ không phải hỏng — để nó ném lên là đánh sập một thứ đang chạy
  /// tốt vì một thứ trang trí.
  Future<void> dongBo(int idaccount) async {
    try {
      // `getAll` chứ không phải `watchFeed`: cần **cả** hàng đã xoá mềm. Một
      // thông báo bị vuốt đi trong app cũng phải rời khay — nó đã được xử lý
      // rồi, để lại trên khay là bắt người dùng dọn hai lần cùng một việc.
      final hang = await dao.getAll(idaccount);

      // Khoá theo id hệ điều hành, đúng công thức đã dùng lúc bắn ra. Đây là
      // **cầu nối duy nhất** giữa một hàng trong bảng và một thông báo trên
      // khay; không có nó thì chỉ còn cách dọn mù.
      final daXuLy = <int>{};
      var chuaDoc = 0;
      for (final h in hang) {
        if (h.readAt == null && h.dismissedAt == null) {
          chuaDoc++;
        } else {
          daXuLy.add(osScheduledId(h.dedupeKey));
        }
      }

      // Giao với khay, KHÔNG duyệt ngược lại. Đi từ phía khay thì mỗi id không
      // khớp hàng nào sẽ được giữ nguyên — và đó chính là chỗ trú của nhắc ghi
      // chép hằng ngày cùng lịch hoá đơn chưa kịp thành hàng.
      // Duyệt trên **bản sao**: `cancel()` làm thông báo rời khay, và một bản
      // cài đặt trả về tập sống sẽ bị sửa ngay giữa vòng lặp. Lỗi ấy rơi thẳng
      // vào `catch` bên dưới, tức là badge lặng lẽ ngừng cập nhật mà không ai
      // biết.
      final khay = {...await osNotifier.activeIds()};
      for (final id in khay) {
        if (daXuLy.contains(id)) await osNotifier.cancel(id);
      }

      await osNotifier.datBadge(chuaDoc);
      debugPrint('[BadgeUpdater] badge=$chuaDoc, khay=${khay.length}, '
          'đã huỷ=${khay.where(daXuLy.contains).length}');
    } catch (e) {
      // Nuốt lỗi (xem chú thích trên) nhưng **có ghi lại**: badge lệch không
      // ném ra đâu cả, nên một `catch` câm biến mọi trục trặc ở đây thành thứ
      // không chẩn đoán được. Đã mất một vòng dựng lại APK vì đúng điều đó.
      debugPrint('[BadgeUpdater] lỗi khi đồng bộ badge: $e');
    }
  }
}
