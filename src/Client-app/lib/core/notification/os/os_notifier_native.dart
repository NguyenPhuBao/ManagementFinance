import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../notification_actions.dart';
import 'os_notifier.dart';
import 'os_scheduled_id.dart';

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

  /// Khoá gộp. Mọi thông báo của app vào **cùng một nhóm**: người dùng quan
  /// tâm tới "FlowMoney có gì mới", không tới việc chuyện đó thuộc hoá đơn hay
  /// ngân sách. Năm dòng riêng trên màn hình khoá là thứ khiến họ tắt hết.
  static const String khoaNhom = 'flowmoney_alerts_group';

  /// Danh mục iOS mang hai nút hành động của nhắc hoá đơn.
  ///
  /// iOS **đăng ký nút một lần ở `initialize()`** rồi mỗi thông báo chỉ trỏ
  /// tới danh mục bằng `categoryIdentifier` — khác hẳn Android, nơi nút đi
  /// kèm từng thông báo. Quên bước đăng ký là trên iOS không có nút nào,
  /// **im lặng**, trong khi Android vẫn đủ hai nút.
  static const String danhMucHoaDon = 'flowmoney_bill_actions';

  /// Id của bản tóm tắt. **Số âm có chủ ý.**
  ///
  /// `osScheduledId()` xoá bit dấu nên luôn trả về 0..2^31-1. Chọn một số âm
  /// là cách DUY NHẤT bảo đảm bản tóm tắt không bao giờ ghi đè một thông báo
  /// thật — và nếu nó đụng thì hỏng hoàn toàn im lặng.
  static const int idTomTat = -1;

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

      final phanHoi = chiTiet.notificationResponse;
      final payload = phanHoi?.payload;
      if (payload == null || payload.isEmpty) return null;

      // ⚠️ PHẢI tính tới `actionId`. Đây là đường DUY NHẤT khi nút "Trả ngay"
      // được bấm lúc app đã đóng hẳn — tức ca chính của một lịch đặt trước.
      // Bỏ qua nó thì nút mở đúng danh sách hoá đơn thay vì hoá đơn ấy, và
      // không có gì báo là đã đi sai chỗ.
      return khoaSauChamNut(actionId: phanHoi?.actionId, payload: payload);
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

    // Nút "Hoãn" **không phát gì ra `_cham`**: cả điểm của nó là xong việc mà
    // không mở màn nào. Phát ra là app bật lên đúng lúc người dùng vừa nói
    // "để lát nữa".
    if (response.actionId == hanhDongHoan) {
      unawaited(_datLichHoan(payload));
      return;
    }

    // Nút "Trả ngay" đi qua ĐÚNG đường của một cú chạm, chỉ đổi khoá thành một
    // khoá trỏ vào chính hoá đơn ấy. Nhờ vậy `payloadDaCham` vẫn là
    // `Stream<String>` và `NotificationTapRouter` không phải biết nút là gì.
    // Cùng một hàm với `payloadKhoiDong()` — hai đường vào của một cú bấm
    // không được phép quyết định khác nhau.
    if (_cham.isClosed) return;
    _cham.add(khoaSauChamNut(actionId: response.actionId, payload: payload));
  }

  /// Đặt lại lịch sau một lần "Hoãn", khi app **đang sống**.
  ///
  /// Nuốt lỗi: người dùng vừa bấm xong và đã rời đi: một trục trặc của
  /// AlarmManager không được phép nổi lên thành màn đỏ.
  Future<void> _datLichHoan(String payload) async {
    final lich = lichHoan(dedupeKey: payload, now: DateTime.now());
    if (lich == null) return;
    try {
      await zonedSchedule(
        // GIỮ NGUYÊN khoá, nên cùng id — đó là thứ làm lịch hoãn sống sót qua
        // `resync()`. Xem chú thích ở `lichHoan()`.
        id: osScheduledId(lich.khoa),
        title: lich.title,
        body: lich.body,
        when: lich.when,
        payload: lich.khoa,
      );
    } catch (_) {
      // Bỏ qua có chủ ý — xem chú thích trên.
    }
  }

  @override
  Future<void> init() async {
    // Luỹ đẳng: `main()` gọi một lần, trang cài đặt có thể gọi lại. Khai báo
    // plugin nhiều lần là gắn chồng callback xử lý cú chạm, và một cú chạm sẽ
    // điều hướng nhiều lần.
    if (_daKhoiTao) return;
    _daKhoiTao = true;

    await _plugin.initialize(
      // KHÔNG `const`: `DarwinNotificationAction.plain` không phải hằng.
      settings: InitializationSettings(
        // `@mipmap/ic_launcher` là icon app, luôn có sẵn trong mọi dự án
        // Flutter. Dùng nó thay vì một drawable riêng để không phải thêm tài
        // nguyên ở lát này; đổi sang icon đơn sắc là việc của phần mĩ thuật.
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Ba cờ `request*Permission` đều false: quyền được xin **có ngữ cảnh**
        // qua `requestPermission()`, không phải lúc app khởi động. Trên iOS
        // người dùng chỉ được hỏi MỘT lần trong cả vòng đời cài đặt — hỏi lúc
        // mở app lần đầu, khi họ chưa hiểu app làm gì, là gần như chắc chắn bị
        // từ chối, và từ chối là mất vĩnh viễn.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          // Nút hành động của iOS đăng ký MỘT LẦN ở đây; mỗi thông báo chỉ trỏ
          // tới danh mục bằng `categoryIdentifier`. Bỏ bước này là iOS không
          // có nút nào mà không báo gì, trong khi Android vẫn đủ hai nút.
          notificationCategories: [
            DarwinNotificationCategory(
              danhMucHoaDon,
              actions: [
                // `foreground` vì việc của nút này ĐÚNG LÀ mở app.
                DarwinNotificationAction.plain(
                  hanhDongTraNgay,
                  'Trả ngay',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                // Không `foreground`: cả điểm của nút Hoãn là làm xong việc mà
                // không phải mở app.
                DarwinNotificationAction.plain(hanhDongHoan, 'Hoãn 1 ngày'),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _khiChamVaoThongBao,
      // Đường DUY NHẤT khi app đã đóng hẳn — ca chính của một lịch đặt trước.
      onDidReceiveBackgroundNotificationResponse: khiChamNutLucAppDong,
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
  Future<bool> daCoQuyen() async {
    try {
      await init();

      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? false;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        // `checkPermissions` KHÔNG bật hộp thoại — khác `requestPermissions`.
        final tt = await ios?.checkPermissions();
        return tt?.isEnabled ?? false;
      }

      return false;
    } catch (_) {
      // Trang cài đặt gọi hàm này ngay lúc dựng; một trục trặc của nền tảng
      // không được phép làm trắng màn hình.
      return false;
    }
  }

  /// Chi tiết thông báo, **kèm nút hành động nếu khoá cho phép**.
  ///
  /// Dùng chung cho cả [show] và [zonedSchedule]: hai đường phải cho ra cùng
  /// một hình dạng thông báo, nếu không cùng một hoá đơn sẽ có nút khi nhắc
  /// đặt trước mà không có nút khi vòng quét bắn — người dùng đọc thành app
  /// hỏng ngẫu nhiên.
  ///
  /// Nút chỉ gắn cho nhắc hoá đơn (`coHanhDong`). Gắn cho mọi loại là hứa một
  /// hành vi không tồn tại: "Hoãn" một cảnh báo ví âm thì hoãn cái gì?
  ///
  /// ⚠️ `groupKey` phải giữ nguyên ở cả hai nhánh — nhắc hoá đơn đặt trước là
  /// loại hay dồn lại nhất, bỏ nó ra ngoài nhóm là bỏ đúng chỗ cần gộp.
  NotificationDetails _chiTiet(String? payload) {
    final coNut = payload != null && coHanhDong(payload);

    return NotificationDetails(
      android: AndroidNotificationDetails(
        kenhNhacId,
        _kenhNhacTen,
        channelDescription: _kenhNhacMoTa,
        // `high` chứ không `max`: thông báo hiện ra và có tiếng, nhưng không
        // chiếm màn hình kiểu cuộc gọi đến. Tiền bạc thì đáng chú ý, không
        // đáng cắt ngang.
        importance: Importance.high,
        priority: Priority.high,
        groupKey: khoaNhom,
        actions: coNut
            ? const [
                AndroidNotificationAction(
                  hanhDongTraNgay,
                  'Trả ngay',
                  // Việc của nút này ĐÚNG LÀ mở app, nên phải khai báo — thiếu
                  // nó thì Android 12+ chặn việc mở màn từ nền.
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
                AndroidNotificationAction(
                  hanhDongHoan,
                  'Hoãn 1 ngày',
                  // KHÔNG mở app: cả điểm của nút này là xong việc mà không
                  // phải mở app. Đặt true ở đây là xoá sạch giá trị của nó.
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: khoaNhom,
        categoryIdentifier: coNut ? danhMucHoaDon : null,
      ),
    );
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
      notificationDetails: _chiTiet(payload),
    );

    // SAU thông báo thật, không phải trước: mọi phép kiểm và mọi người đọc log
    // đều mong lời gọi đầu tiên là thông báo mà nơi gọi vừa yêu cầu.
    await _dangBanTomTat();
  }

  /// Đăng (hoặc cập nhật) bản tóm tắt của nhóm.
  ///
  /// Từ Android 7, đặt `groupKey` mà **không** có bản tóm tắt thì các thông báo
  /// vẫn nằm rời nhau — công sức gộp coi như không có. Bản tóm tắt dùng id cố
  /// định nên mỗi lần đăng lại chỉ ghi đè chính nó.
  ///
  /// `GroupAlertBehavior.children` để bản tóm tắt **im lặng**: tiếng và rung là
  /// việc của thông báo thật, còn tóm tắt kêu nữa là mỗi sự kiện kêu hai lần.
  Future<void> _dangBanTomTat() async {
    // **Chỉ Android.** iOS gộp theo `threadIdentifier` và không có khái niệm
    // bản tóm tắt; đăng thêm một cái ở đó là một thông báo TRỐNG nằm trên màn
    // hình khoá — và nó không bao giờ lộ ra trong một lần kiểm chạy trên
    // Android.
    if (defaultTargetPlatform != TargetPlatform.android) return;

    await _plugin.show(
      id: idTomTat,
      title: _kenhNhacTen,
      body: null,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          kenhNhacId,
          _kenhNhacTen,
          channelDescription: _kenhNhacMoTa,
          importance: Importance.high,
          priority: Priority.high,
          groupKey: khoaNhom,
          setAsGroupSummary: true,
          groupAlertBehavior: GroupAlertBehavior.children,
        ),
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
      notificationDetails: _chiTiet(payload),
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

/// Xử lý nút hành động khi app **đã đóng hẳn** — chạy trong một isolate NỀN.
///
/// Đây là ca **chính** của nút "Hoãn": lịch nhắc nổ lúc app không còn chạy, và
/// nếu bấm nút cũng phải mở app thì nút ấy không hơn gì một cú chạm.
///
/// ## `@pragma('vm:entry-point')` là BẮT BUỘC
///
/// Hàm này không có nơi gọi tĩnh nào trong mã Dart — phía nền tảng gọi nó qua
/// một cổng riêng. Bản release cắt bỏ mọi thứ không ai gọi, nên thiếu chú thích
/// này thì **debug chạy tốt còn release im lặng không làm gì**: đúng kiểu hỏng
/// chỉ lộ ra sau khi phát hành.
///
/// ## Isolate này KHÔNG có gì
///
/// Không DI container, không CSDL đang mở, và không cả múi giờ của máy —
/// `tz.local` ở đây rơi về UTC (bẫy 7.3). Vì thế nó chỉ làm đúng một việc
/// không cần ba thứ đó: đặt lại lịch ở một mốc **tuyệt đối** cách bây giờ đúng
/// [buocHoan]. Cộng một khoảng thời gian vào `DateTime.now()` cho ra cùng một
/// khoảnh khắc dù đọc bằng múi giờ nào, nên UTC ở đây vô hại.
///
/// Đó cũng là lý do **không có nút "Đã trả"**: trả hoá đơn cần cả CSDL lẫn ví,
/// tức cần đúng những thứ isolate này không có. Xem `notification_actions.dart`.
@pragma('vm:entry-point')
void khiChamNutLucAppDong(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;

  // Chỉ "Hoãn" tới được đây. "Trả ngay" khai báo `foreground`/
  // `showsUserInterface`, nên nền tảng mở app và cú bấm đi qua
  // `onDidReceiveNotificationResponse` ở isolate chính.
  if (response.actionId != hanhDongHoan) return;

  final lich = lichHoan(dedupeKey: payload, now: DateTime.now());
  if (lich == null) return;

  // Một dòng nhật ký, cùng lý do với `NotificationScanner._ghiNhat`: đường này
  // hỏng HOÀN TOÀN im lặng. Ngày 2026-09-07 nút "Hoãn" không chạy vì thiếu
  // `ActionBroadcastReceiver` trong manifest, và không có gì phân biệt được
  // "isolate chưa từng chạy" với "isolate chạy rồi nhưng đặt lịch hỏng". Dòng
  // này trả lời đúng câu ấy trong `adb logcat`.
  debugPrint('[Hoãn] isolate nền nhận "$payload", dời tới ${lich.when}');

  unawaited(_datLichHoanTuIsolateNen(lich));
}

/// Nuốt **mọi** lỗi: không có ai để báo, và một ngoại lệ chưa bắt trong isolate
/// nền làm tiến trình chết theo cách không lần lại được từ log của người dùng.
Future<void> _datLichHoanTuIsolateNen(LichHoan lich) async {
  try {
    // Dữ liệu múi giờ là Dart thuần, không qua kênh nền tảng nào — gọi được ở
    // đây. `tz.local` vẫn là UTC, và điều đó không sao: xem chú thích trên.
    tzdata.initializeTimeZones();

    final plugin = FlutterLocalNotificationsPlugin();
    // Cần `initialize` để có icon thông báo; **không** gắn callback nào ở đây.
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    await plugin.zonedSchedule(
      id: osScheduledId(lich.khoa),
      title: lich.title,
      body: lich.body,
      payload: lich.khoa,
      scheduledDate: tz.TZDateTime.from(lich.when, tz.local),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          LocalOsNotifier.kenhNhacId,
          'Nhắc tài chính',
          importance: Importance.high,
          priority: Priority.high,
          groupKey: LocalOsNotifier.khoaNhom,
          // Lịch hoãn vẫn phải mang nút, nếu không hoãn được đúng MỘT lần rồi
          // lần sau chỉ còn cách mở app.
          actions: [
            AndroidNotificationAction(
              hanhDongTraNgay,
              'Trả ngay',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              hanhDongHoan,
              'Hoãn 1 ngày',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          threadIdentifier: LocalOsNotifier.khoaNhom,
          categoryIdentifier: LocalOsNotifier.danhMucHoaDon,
        ),
      ),
    );
  } catch (_) {
    // Bỏ qua có chủ ý — xem chú thích trên.
  }
}

/// Điểm vào cho `os_notifier_factory.dart`. Cùng tên với hàm ở bản web và bản
/// stub — conditional import đòi ba file phơi ra cùng một API.
OsNotifier createOsNotifier() => LocalOsNotifier();

