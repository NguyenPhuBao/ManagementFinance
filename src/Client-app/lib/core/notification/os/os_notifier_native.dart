import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

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

  /// Broadcast: `NotificationTapRouter` có thể huỷ rồi nghe lại.
  final StreamController<String> _cham = StreamController<String>.broadcast();

  @override
  bool get isSupported => true;

  @override
  Stream<String> get payloadDaCham => _cham.stream;

  @override
  Future<String?> payloadKhoiDong() async {
    // Cả `init()` cũng nằm trong try: hàm này chạy trên đường khởi động app,
    // và một trục trặc của nền tảng ở đó không được phép làm app không mở lên.
    try {
      await init();
      final chiTiet = await _plugin.getNotificationAppLaunchDetails();
      if (chiTiet == null || !chiTiet.didNotificationLaunchApp) return null;

      final payload = chiTiet.notificationResponse?.payload;
      if (payload == null || payload.isEmpty) return null;
      return payload;
    } catch (_) {
      return null;
    }
  }

  /// Xử lý cú chạm khi app **đang sống**.
  ///
  /// Là phương thức của lớp chứ không phải hàm top-level: nó phải chạm tới
  /// `_cham`, và gắn callback ở đây cũng khiến `init()` luỹ đẳng trở thành
  /// điều kiện đủ để không có hai người cùng nghe một cú chạm.
  void _khiChamVaoThongBao(NotificationResponse response) {
    final payload = response.payload;
    // Không payload thì không suy ra được màn nào — im lặng thay vì phát chuỗi
    // rỗng ra cho nơi nhận tự lọc.
    if (payload == null || payload.isEmpty) return;
    if (_cham.isClosed) return;
    _cham.add(payload);
  }

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
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      // `tz.local` được đặt trong `main.dart` bằng `flutter_timezone`. Quên
      // bước ấy thì `TZDateTime` neo vào UTC và nhắc lệch 7 tiếng ở Việt Nam,
      // **không có lỗi nào báo ra** (bẫy 7.3).
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      // KHÔNG dùng chế độ chính xác — xem chú thích ở `requestPermission()`.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          kenhNhacId,
          _kenhNhacTen,
          channelDescription: _kenhNhacMoTa,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  @override
  Future<Set<int>> pendingIds() async {
    await init();
    final cho = await _plugin.pendingNotificationRequests();
    return {for (final r in cho) r.id};
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

