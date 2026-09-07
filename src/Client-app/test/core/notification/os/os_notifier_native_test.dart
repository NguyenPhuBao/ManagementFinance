/// `LocalOsNotifier` — lớp mỏng bọc `flutter_local_notifications`.
///
/// Lớp này gần như không có logic, nhưng nó là **chỗ duy nhất** trong dự án
/// nói chuyện với hệ điều hành, và mọi cách nó hỏng đều hỏng **im lặng**:
/// kênh Android khai sai tên thì thông báo không bao giờ hiện mà không có lỗi
/// nào; `payload` rỗng thì cú chạm vào thông báo mở app về màn hình trắng.
/// Test dưới đây chặn lời gọi ở tầng `MethodChannel` — tức là đúng ranh giới
/// giữa Dart và nền tảng — nên chúng canh được những thứ đó mà không cần máy
/// thật.
///
/// Cái chúng **không** canh được: hành vi thật của AlarmManager và của
/// UNUserNotificationCenter. Phần ấy phải kiểm trên máy ảo Android/iOS.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:flowmoney/core/notification/os/os_notifier_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kenh = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> daGoi;

  /// Thứ nền tảng trả về cho `getNotificationAppLaunchDetails`. `null` = app
  /// khởi động bình thường, không phải do người dùng chạm vào thông báo.
  Map<Object?, Object?>? chiTietKhoiDong;

  setUp(() {
    daGoi = [];
    chiTietKhoiDong = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // Trên máy thật, bản cài đặt theo nền tảng được gắn vào lúc plugin tự đăng
    // ký. Trong test không có bước đó, nên phải gắn tay — nếu không
    // `resolvePlatformSpecificImplementation` ném `LateInitializationError`.
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kenh, (call) async {
      daGoi.add(call);
      if (call.method == 'getNotificationAppLaunchDetails') {
        return chiTietKhoiDong;
      }
      // `initialize` và `requestNotificationsPermission` đều trả bool.
      return true;
    });
  });

  /// Giả lập cú chạm mà nền tảng đẩy NGƯỢC lên Dart.
  ///
  /// Đi qua đúng đường thật (`didReceiveNotificationResponse` trên cùng kênh)
  /// chứ không gọi thẳng callback: cái đáng canh là plugin có được khai báo
  /// kèm handler hay không, và chỉ đường này mới trả lời được câu đó.
  Future<void> guiCuCham(String? payload) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      kenh.name,
      kenh.codec.encodeMethodCall(
        MethodCall('didReceiveNotificationResponse', <String, Object?>{
          'notificationId': 503122046,
          'actionId': null,
          'input': null,
          'payload': payload,
          'notificationResponseType': 0,
        }),
      ),
      (_) {},
    );
  }

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kenh, null);
  });

  MethodCall goiTen(String ten) =>
      daGoi.firstWhere((c) => c.method == ten,
          orElse: () => throw StateError(
              'Không có lời gọi "$ten". Đã gọi: '
              '${daGoi.map((c) => c.method).toList()}'));

  test('isSupported là true trên nền tảng có thông báo hệ điều hành', () {
    expect(LocalOsNotifier().isSupported, isTrue,
        reason: 'Trang cài đặt dựa vào cờ này để quyết định có hiện phần xin '
            'quyền hay không.');
  });

  test('init() khai báo plugin đúng một lần dù gọi nhiều lần', () async {
    final os = LocalOsNotifier();
    await os.init();
    await os.init();

    expect(daGoi.where((c) => c.method == 'initialize').length, 1,
        reason: 'init() được gọi từ main() và có thể được gọi lại từ trang cài '
            'đặt. Khai báo lại plugin mỗi lần là gắn chồng callback xử lý cú '
            'chạm, và một cú chạm sẽ điều hướng nhiều lần.');
  });

  test('show() đẩy xuống nền tảng đúng id, tiêu đề, nội dung và payload',
      () async {
    final os = LocalOsNotifier();
    await os.init();
    await os.show(
      id: 503122046,
      title: 'Hoá đơn sắp đến hạn',
      body: 'Tiền điện còn 2 ngày tới hạn (300 nghìn).',
      payload: 'billDue:hd1:2026-09-17:3',
    );

    final call = goiTen('show');
    final args = (call.arguments as Map).cast<String, Object?>();
    expect(args['id'], 503122046);
    expect(args['title'], 'Hoá đơn sắp đến hạn');
    expect(args['body'], 'Tiền điện còn 2 ngày tới hạn (300 nghìn).');
    expect(args['payload'], 'billDue:hd1:2026-09-17:3',
        reason: 'Payload là đường duy nhất để lúc người dùng bấm vào thông '
            'báo, app biết mở đúng bản ghi nào. Đánh rơi nó là cú chạm mở ra '
            'màn hình mặc định.');
  });

  test('show() gắn thông báo vào một kênh Android có tên ổn định', () async {
    final os = LocalOsNotifier();
    await os.init();
    await os.show(id: 1, title: 't', body: 'b');

    final args = (goiTen('show').arguments as Map).cast<String, Object?>();
    final android = (args['platformSpecifics'] as Map).cast<String, Object?>();
    expect(android['channelId'], LocalOsNotifier.kenhNhacId,
        reason: 'Android tạo kênh theo id ở lần dùng đầu tiên và GHI NHỚ nó. '
            'Đổi id sau khi phát hành là tạo một kênh thứ hai, còn kênh cũ ở '
            'lại trong Cài đặt với mọi tuỳ chọn người dùng đã chỉnh — và họ '
            'không hiểu vì sao tắt tiếng mãi không có tác dụng.');
    expect(android['channelName'], isNotEmpty,
        reason: 'Tên kênh là thứ người dùng đọc trong Cài đặt hệ thống.');
  });

  test('cancel() huỷ đúng một id', () async {
    final os = LocalOsNotifier();
    await os.init();
    await os.cancel(503122046);

    final args = goiTen('cancel').arguments;
    final id = args is Map ? args['id'] : args;
    expect(id, 503122046);
  });

  test('cancelAll() gọi xuống nền tảng', () async {
    final os = LocalOsNotifier();
    await os.init();
    await os.cancelAll();

    expect(daGoi.map((c) => c.method), contains('cancelAll'),
        reason: 'Đây là bước chặn nhắc hoá đơn của người đăng nhập trước nổ '
            'trên màn hình khoá của người đăng nhập sau.');
  });

  group('đặt lịch trước', () {
    setUp(() {
      // `zonedSchedule` dựng TZDateTime nên cần bảng múi giờ đã nạp. Trên máy
      // thật việc này làm trong main.dart trước setupDependencies().
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    });

    test('zonedSchedule() đẩy xuống nền tảng đúng mốc theo giờ ĐỊA PHƯƠNG',
        () async {
      final os = LocalOsNotifier();
      await os.init();
      await os.zonedSchedule(
        id: 42,
        title: 'Hoá đơn sắp đến hạn',
        body: 'Tiền điện còn 3 ngày tới hạn.',
        when: DateTime(2026, 9, 17, 21, 30),
        payload: 'billDue:hd1:2026-09-20:3',
      );

      final args =
          (goiTen('zonedSchedule').arguments as Map).cast<String, Object?>();
      expect(args['id'], 42);
      expect(args['payload'], 'billDue:hd1:2026-09-20:3');
      expect(args['scheduledDateTime'].toString(), startsWith('2026-09-17T21:30'),
          reason: 'Quên setLocalLocation thì TZDateTime neo vào UTC và nhắc '
              'lệch 7 tiếng ở Việt Nam — không có lỗi nào báo ra (bẫy 7.3).');
    });

    test('dùng chế độ KHÔNG chính xác cho lịch Android', () async {
      final os = LocalOsNotifier();
      await os.init();
      await os.zonedSchedule(
        id: 42,
        title: 't',
        body: 'b',
        when: DateTime(2026, 9, 17, 21, 30),
      );

      final args =
          (goiTen('zonedSchedule').arguments as Map).cast<String, Object?>();
      final android = (args['platformSpecifics'] as Map).cast<String, Object?>();
      expect(android['scheduleMode'], 'inexactAllowWhileIdle',
          reason: 'Chế độ chính xác đòi SCHEDULE_EXACT_ALARM, thứ Google Play '
              'chặn trừ nhóm báo thức/lịch. Nhắc hoá đơn lệch mươi phút không '
              'sao — nhưng bị Play từ chối lúc phát hành thì có.');
    });

    test('pendingIds() trả về id của các lịch đang chờ', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kenh, (call) async {
        daGoi.add(call);
        if (call.method == 'pendingNotificationRequests') {
          return [
            {'id': 11, 'title': 'a', 'body': 'b', 'payload': 'k1'},
            {'id': 22, 'title': 'c', 'body': 'd', 'payload': 'k2'},
          ];
        }
        return true;
      });

      final os = LocalOsNotifier();
      await os.init();

      expect(await os.pendingIds(), {11, 22},
          reason: 'Đây là thứ làm resync() luỹ đẳng. Trả rỗng thì mỗi lần đồng '
              'bộ là một vòng huỷ-rồi-đặt-lại toàn bộ lịch.');
    });
  });

  test('requestPermission() hỏi quyền thông báo của Android', () async {
    final os = LocalOsNotifier();
    await os.init();
    final duoc = await os.requestPermission();

    expect(duoc, isTrue);
    expect(daGoi.map((c) => c.method), contains('requestNotificationsPermission'),
        reason: 'Từ Android 13 không xin quyền là thông báo bị nuốt hoàn toàn, '
            'không có lỗi nào báo ra.');
  });

  test('KHÔNG xin quyền báo thức chính xác', () async {
    final os = LocalOsNotifier();
    await os.init();
    await os.requestPermission();

    expect(daGoi.map((c) => c.method),
        isNot(contains('requestExactAlarmsPermission')),
        reason: 'Chủ ý: Google Play chặn SCHEDULE_EXACT_ALARM trừ nhóm báo '
            'thức/lịch, và Android 14 bắt người dùng bật tay trong Cài đặt. '
            'Nhắc hoá đơn lệch mươi phút không sao. "Nhắc hoá đơn nên chính '
            'xác" nghe rất hợp lý nên người sau sẽ muốn thêm — test này là '
            'chỗ họ gặp lời giải thích.');
  });

  group('hỏi quyền mà KHÔNG xin quyền', () {
    test('daCoQuyen() đọc trạng thái thật của Android', () async {
      final os = LocalOsNotifier();
      await os.init();

      expect(await os.daCoQuyen(), isTrue);
      expect(daGoi.map((c) => c.method), contains('areNotificationsEnabled'),
          reason: 'Đây là câu hỏi "hệ điều hành có đang cho phép không", khác '
              'hẳn câu "xin cấp quyền". Trang cài đặt cần hỏi mỗi lần mở để '
              'công tắc không sáng trong khi thông báo đang bị chặn.');
      expect(daGoi.map((c) => c.method),
          isNot(contains('requestNotificationsPermission')),
          reason: 'Hỏi mà hoá ra lại xin là bật hộp thoại quyền mỗi lần người '
              'dùng mở trang cài đặt — và trên iOS họ chỉ được hỏi MỘT lần '
              'trong cả vòng đời cài đặt, tiêu phí nó ở đây là mất vĩnh viễn.');
    });

    test('nền tảng ném thì trả false chứ không làm chết trang', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kenh, (call) async {
        throw PlatformException(code: 'loi');
      });

      expect(await LocalOsNotifier().daCoQuyen(), isFalse);
    });
  });

  group('gộp thông báo trên Android', () {
    Map<String, Object?> androidCua(MethodCall call) =>
        ((call.arguments as Map)['platformSpecifics'] as Map)
            .cast<String, Object?>();

    test('mỗi thông báo mang cùng một khoá nhóm', () async {
      final os = LocalOsNotifier();
      await os.init();
      await os.show(id: 1, title: 't', body: 'b');

      final con = androidCua(goiTen('show'));
      expect(con['groupKey'], LocalOsNotifier.khoaNhom);
      expect(con['setAsGroupSummary'], isFalse,
          reason: 'Thông báo thật không được tự nhận là bản tóm tắt, nếu không '
              'Android coi cả nhóm là tóm tắt và không hiện gì cả.');
    });

    test('kèm một bản tóm tắt, nếu không Android vẫn hiện từng dòng', () async {
      final os = LocalOsNotifier();
      await os.init();
      await os.show(id: 1, title: 't', body: 'b');

      final show = daGoi.where((c) => c.method == 'show').toList();
      expect(show, hasLength(2),
          reason: 'Từ Android 7, đặt groupKey mà KHÔNG có bản tóm tắt thì các '
              'thông báo vẫn nằm rời — công sức gộp coi như không có. Bản tóm '
              'tắt phải đi sau thông báo thật để mọi phép kiểm cũ vẫn đọc '
              'được lời gọi đầu tiên.');

      final tomTat = (show.last.arguments as Map).cast<String, Object?>();
      expect(tomTat['id'], LocalOsNotifier.idTomTat);

      final a = androidCua(show.last);
      expect(a['setAsGroupSummary'], isTrue);
      expect(a['groupKey'], LocalOsNotifier.khoaNhom);
    });

    test('trên iOS KHÔNG đăng bản tóm tắt', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      FlutterLocalNotificationsPlatform.instance =
          IOSFlutterLocalNotificationsPlugin();

      final os = LocalOsNotifier();
      await os.init();
      await os.show(id: 1, title: 't', body: 'b');

      expect(daGoi.where((c) => c.method == 'show'), hasLength(1),
          reason: 'iOS gộp theo `threadIdentifier`, nó không có khái niệm bản '
              'tóm tắt. Đăng thêm một cái ở đây là một thông báo TRỐNG nằm '
              'trên màn hình khoá của người dùng iOS, và nó sẽ không bao giờ '
              'lộ ra trong bất cứ lần kiểm nào chạy trên Android.');
    });

    test('id của bản tóm tắt là số ÂM nên không thể đụng id thật', () {
      expect(LocalOsNotifier.idTomTat, lessThan(0),
          reason: 'osScheduledId luôn trả về 0..2^31-1 (nó xoá bit dấu). Chọn '
              'một số âm là cách DUY NHẤT bảo đảm bản tóm tắt không bao giờ '
              'ghi đè một thông báo thật — mà nếu đụng thì hỏng im lặng.');
    });

    test('lịch đặt trước cũng vào cùng nhóm', () async {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

      final os = LocalOsNotifier();
      await os.init();
      await os.zonedSchedule(
        id: 2,
        title: 't',
        body: 'b',
        when: DateTime(2026, 9, 20, 8),
      );

      expect(androidCua(goiTen('zonedSchedule'))['groupKey'],
          LocalOsNotifier.khoaNhom,
          reason: 'Nhắc hoá đơn đặt trước là loại thông báo hay dồn lại nhất — '
              'bỏ nó ra ngoài nhóm là bỏ đúng chỗ cần gộp.');
    });
  });

  group('cú chạm vào thông báo', () {
    test('phát payload ra stream khi app đang sống', () async {
      final os = LocalOsNotifier();
      await os.init();

      final nhan = os.payloadDaCham.first;
      await guiCuCham('billDue:hd1:2026-09-17:3');

      expect(await nhan, 'billDue:hd1:2026-09-17:3',
          reason: 'Payload là đường DUY NHẤT để app biết người dùng vừa bấm '
              'vào thông báo nào. Nuốt nó đi thì cú chạm chỉ mở app ra trang '
              'chủ và người dùng phải tự đi tìm lại thứ vừa hiện trên màn hình '
              'khoá.');
    });

    test('stream là broadcast: nghe lại sau khi huỷ vẫn được', () async {
      final os = LocalOsNotifier();
      await os.init();

      await os.payloadDaCham.listen((_) {}).cancel();

      final nhan = os.payloadDaCham.first;
      await guiCuCham('billDue:hd1:2026-09-17:3');

      expect(await nhan, 'billDue:hd1:2026-09-17:3');
    });

    test('cú chạm không mang payload thì không phát gì', () async {
      final os = LocalOsNotifier();
      await os.init();
      final daNhan = <String>[];
      os.payloadDaCham.listen(daNhan.add);

      await guiCuCham(null);
      await Future<void>.delayed(Duration.zero);

      expect(daNhan, isEmpty,
          reason: 'Không có payload thì không suy ra được màn nào. Phát chuỗi '
              'rỗng ra là ép nơi nhận tự lọc, và sớm muộn sẽ có chỗ quên lọc '
              'rồi điều hướng về một route vô nghĩa.');
    });
  });

  group('payload đã mở app từ trạng thái đóng hẳn', () {
    test('đọc được payload của thông báo đã khởi động app', () async {
      chiTietKhoiDong = <Object?, Object?>{
        'notificationLaunchedApp': true,
        'notificationResponse': <Object?, Object?>{
          'notificationId': 503122046,
          'actionId': null,
          'input': null,
          'payload': 'goalAuto:mt1:2026-09-15T08:00',
          'notificationResponseType': 0,
        },
      };

      final os = LocalOsNotifier();

      expect(await os.payloadKhoiDong(), 'goalAuto:mt1:2026-09-15T08:00',
          reason: 'Đây là ca CHÍNH của lịch đặt trước: nó nổ khi app đã đóng '
              'hẳn. Lúc ấy `onDidReceiveNotificationResponse` có thể chưa kịp '
              'gắn, nên đường duy nhất còn lại là hỏi nền tảng xem app được mở '
              'bởi thông báo nào.');
    });

    test('app mở bình thường thì trả null', () async {
      chiTietKhoiDong = null;
      final os = LocalOsNotifier();

      expect(await os.payloadKhoiDong(), isNull);
    });

    test('mở từ thông báo nhưng không có payload thì trả null', () async {
      chiTietKhoiDong = <Object?, Object?>{
        'notificationLaunchedApp': true,
        'notificationResponse': <Object?, Object?>{
          'notificationId': 1,
          'actionId': null,
          'input': null,
          'payload': null,
          'notificationResponseType': 0,
        },
      };

      final os = LocalOsNotifier();

      expect(await os.payloadKhoiDong(), isNull);
    });

    test('nền tảng ném thì trả null chứ không làm chết khởi động', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kenh, (call) async {
        throw PlatformException(code: 'loi', message: 'nền tảng trở chứng');
      });

      final os = LocalOsNotifier();

      expect(await os.payloadKhoiDong(), isNull,
          reason: 'Hàm này chạy trên đường khởi động app. Để một trục trặc của '
              'nền tảng nổi lên ở đó là app không mở được — hỏng nặng hơn hẳn '
              'so với việc bỏ lỡ một cú điều hướng.');
    });
  });
}
