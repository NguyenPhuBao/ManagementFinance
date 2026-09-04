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

import 'package:flowmoney/core/notification/os/os_notifier_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kenh = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> daGoi;

  setUp(() {
    daGoi = [];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // Trên máy thật, bản cài đặt theo nền tảng được gắn vào lúc plugin tự đăng
    // ký. Trong test không có bước đó, nên phải gắn tay — nếu không
    // `resolvePlatformSpecificImplementation` ném `LateInitializationError`.
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kenh, (call) async {
      daGoi.add(call);
      // `initialize` và `requestNotificationsPermission` đều trả bool.
      return true;
    });
  });

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
}
