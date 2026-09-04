import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'os_notifier.dart';

/// **File DUY NHẤT trong dự án được phép import `flutter_local_notifications`.**
///
/// Bẫy 7.7 của `docs/NOTIFICATION_FEATURE.md`: một import lọt ra ngoài file này
/// làm gãy `flutter build web`, mà `flutter test` **vẫn xanh** — test chạy trên
/// VM, tức nhánh `dart.library.io`, không bao giờ đi qua đường web. Nếu phải
/// thêm một khả năng mới của gói, thêm phương thức vào `OsNotifier` rồi cài
/// đặt ở đây; đừng import thẳng ở nơi gọi.
class LocalOsNotifier implements OsNotifier {
  LocalOsNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Id kênh Android.
  ///
  /// **Không đổi sau khi phát hành.** Android tạo kênh theo id ở lần dùng đầu
  /// tiên rồi ghi nhớ nó cùng mọi tuỳ chọn người dùng đã chỉnh (âm thanh, độ
  /// quan trọng, có hiện trên màn hình khoá không). Đổi id là sinh ra một kênh
  /// thứ hai, còn kênh cũ ở lại trong Cài đặt — người dùng tắt tiếng ở kênh cũ
  /// và không hiểu vì sao vẫn kêu.
  static const String kenhNhacId = 'flowmoney_alerts';

  static const String _kenhNhacTen = 'Nhắc tài chính';
  static const String _kenhNhacMoTa =
      'Nhắc hoá đơn đến hạn, cảnh báo ngân sách và tiến độ mục tiêu.';

  bool _daKhoiTao = false;

  @override
  bool get isSupported => true;

  @override
  Future<void> init() async {
    // Luỹ đẳng: `main()` gọi một lần, trang cài đặt có thể gọi lại. Khai báo
    // plugin nhiều lần là gắn chồng callback xử lý cú chạm, và một cú chạm sẽ
    // điều hướng nhiều lần.
    if (_daKhoiTao) return;
    _daKhoiTao = true;

    await _plugin.initialize(
      settings: const InitializationSettings(
        // `@mipmap/ic_launcher` là icon app, luôn có sẵn trong mọi dự án
        // Flutter. Dùng nó thay vì một drawable riêng để không phải thêm tài
        // nguyên ở lát này; đổi sang icon đơn sắc là việc của phần mĩ thuật.
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Ba cờ `request*Permission` đều false: quyền được xin **có ngữ cảnh**
        // qua `requestPermission()`, không phải lúc app khởi động. Trên iOS
        // người dùng chỉ được hỏi MỘT lần trong cả vòng đời cài đặt — hỏi lúc
        // mở app lần đầu, khi họ chưa hiểu app làm gì, là gần như chắc chắn bị
        // từ chối, và từ chối là mất vĩnh viễn.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _khiChamVaoThongBao,
    );
  }

  /// Xin quyền thông báo.
  ///
  /// **Chủ động KHÔNG gọi `requestExactAlarmsPermission()`.** Google Play chặn
  /// `SCHEDULE_EXACT_ALARM` trừ nhóm báo thức/lịch, và trên Android 14 quyền
  /// ấy phải bật tay trong Cài đặt hệ thống. Nhắc hoá đơn lệch mươi phút không
  /// ảnh hưởng gì tới người dùng, nên lịch dùng
  /// `AndroidScheduleMode.inexactAllowWhileIdle`. Câu "nhắc hoá đơn thì nên
  /// chính xác" nghe rất hợp lý, nên ghi rõ ở đây để người sau không lặng lẽ
  /// đổi rồi bị Play từ chối lúc phát hành.
  @override
  Future<bool> requestPermission() async {
    await init();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Từ Android 13 (API 33), không có quyền này thì thông báo bị nuốt hoàn
      // toàn — không lỗi, không log.
      return await android?.requestNotificationsPermission() ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          kenhNhacId,
          _kenhNhacTen,
          channelDescription: _kenhNhacMoTa,
          // `high` chứ không `max`: thông báo hiện ra và có tiếng, nhưng không
          // chiếm màn hình kiểu cuộc gọi đến. Tiền bạc thì đáng chú ý, không
          // đáng cắt ngang.
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}

/// Điểm vào cho `os_notifier_factory.dart`. Cùng tên với hàm ở bản web và bản
/// stub — conditional import đòi ba file phơi ra cùng một API.
OsNotifier createOsNotifier() => LocalOsNotifier();

/// Xử lý cú chạm vào thông báo.
///
/// Lát này chưa điều hướng: `payload` mang `dedupeKey`, và việc dịch nó thành
/// một đường dẫn trong app cần router — thứ chưa sẵn sàng ở tầng này. Cú chạm
/// vẫn mở app, và vòng quét chạy ngay sau đó sinh đúng hàng trong trung tâm
/// thông báo, nên người dùng không mất thông tin.
void _khiChamVaoThongBao(NotificationResponse response) {
  // Cố ý để trống. Xem chú thích trên.
}
