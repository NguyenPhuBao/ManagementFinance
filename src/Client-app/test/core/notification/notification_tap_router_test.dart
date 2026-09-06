/// `NotificationTapRouter` — nơi DUY NHẤT biến một cú chạm vào thông báo cấp
/// hệ điều hành thành một lần điều hướng trong app.
///
/// Ba thứ khó, cả ba đều hỏng im lặng:
///
/// 1. **Cold start.** Lịch nhắc hoá đơn nổ khi app đã đóng hẳn — đó là ca
///    chính, không phải ca phụ. Payload khi ấy chỉ lấy được qua
///    `payloadKhoiDong()`.
/// 2. **Điều hướng hai lần.** Trên Android cùng một cú chạm có thể vừa nằm
///    trong chi tiết khởi động, vừa được đẩy lên qua callback. Không chặn thì
///    người dùng thấy màn hình nhảy hai lần.
/// 3. **Chưa đăng nhập.** Token hết hạn là chuyện thường sau vài ngày app
///    đóng. Điều hướng lúc ấy chỉ bị guard của router đá về `/login`, và cú
///    chạm coi như mất.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/notification/notification_tap_router.dart';
import 'package:flowmoney/core/notification/os/os_notifier.dart';

/// Bản giả chỉ phơi ra hai thành viên mà bộ định tuyến cú chạm dùng tới.
class _OsGia implements OsNotifier {
  final StreamController<String> cham = StreamController<String>.broadcast();

  /// Thứ `payloadKhoiDong()` trả về — `null` = app mở bình thường. Đặt sau khi
  /// dựng, trước khi gọi `start()`.
  String? payloadMoApp;

  @override
  Stream<String> get payloadDaCham => cham.stream;

  @override
  Future<String?> payloadKhoiDong() async => payloadMoApp;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  bool get isSupported => true;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String? payload,
  }) async {}

  @override
  Future<Set<int>> pendingIds() async => const {};

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  late _OsGia os;
  late StreamController<void> phienDoi;
  late List<String> daDieuHuong;
  late bool dangNhap;

  setUp(() {
    os = _OsGia();
    phienDoi = StreamController<void>.broadcast();
    daDieuHuong = [];
    dangNhap = true;
  });

  tearDown(() async {
    await os.cham.close();
    await phienDoi.close();
  });

  NotificationTapRouter dung() => NotificationTapRouter(
        osNotifier: os,
        dieuHuong: daDieuHuong.add,
        dangDangNhap: () => dangNhap,
        phienDoi: phienDoi.stream,
      );

  /// Chờ micro-task của listener chạy xong.
  Future<void> nhipTho() => Future<void>.delayed(Duration.zero);

  group('chạm khi app đang sống', () {
    test('điều hướng tới route suy từ payload', () async {
      final router = dung();
      await router.start();

      os.cham.add('billDue:hd1:2026-09-17:3');
      await nhipTho();

      expect(daDieuHuong, ['/bills'],
          reason: 'Payload là dedupeKey; nó phải được dịch qua '
              'deeplinkTuDedupeKey chứ không dùng thẳng làm route.');
      await router.stop();
    });

    test('thông báo mục tiêu dẫn thẳng tới đúng mục tiêu', () async {
      final router = dung();
      await router.start();

      os.cham.add('goalAuto:mt-abc:2026-09-15T08:00');
      await nhipTho();

      expect(daDieuHuong, ['/goals/mt-abc'],
          reason: 'Thông báo đã biết chính xác mục tiêu nào; đổ người dùng '
              'xuống danh sách là vứt đi thông tin mình đang cầm.');
      await router.stop();
    });

    test('stop() cắt hẳn: chạm sau đó không điều hướng nữa', () async {
      final router = dung();
      await router.start();
      await router.stop();

      os.cham.add('billDue:hd1:2026-09-17:3');
      await nhipTho();

      expect(daDieuHuong, isEmpty);
    });
  });

  group('mở app từ trạng thái đóng hẳn', () {
    test('payload khởi động cũng điều hướng', () async {
      os.payloadMoApp = 'billOverdue:hd1:2026-09-10';

      final router = dung();
      await router.start();
      await nhipTho();

      expect(daDieuHuong, ['/bills'],
          reason: 'Đây là ca CHÍNH của lịch đặt trước — nó nổ khi app không '
              'còn chạy. Bỏ qua nó là bỏ qua phần lớn giá trị của tính năng.');
      await router.stop();
    });

    test('cùng payload đến bằng cả hai đường chỉ điều hướng MỘT lần', () async {
      os.payloadMoApp = 'billOverdue:hd1:2026-09-10';

      final router = dung();
      await router.start();
      // Android có thể đẩy tiếp chính cú chạm ấy qua callback.
      os.cham.add('billOverdue:hd1:2026-09-10');
      await nhipTho();

      expect(daDieuHuong, ['/bills'],
          reason: 'Trên Android một cú chạm lúc app đã chết có thể vừa nằm '
              'trong chi tiết khởi động vừa được đẩy lên qua callback. Điều '
              'hướng hai lần làm màn hình nhảy, và với route dùng push() thì '
              'nó chồng hai trang lên nhau.');
      await router.stop();
    });

    test('lần chạm SAU với cùng payload vẫn điều hướng', () async {
      os.payloadMoApp = 'billOverdue:hd1:2026-09-10';

      final router = dung();
      await router.start();
      os.cham.add('billOverdue:hd1:2026-09-10');
      await nhipTho();
      // Người dùng quay lại màn hình khoá và bấm lại chính thông báo ấy.
      os.cham.add('billOverdue:hd1:2026-09-10');
      await nhipTho();

      expect(daDieuHuong, ['/bills', '/bills'],
          reason: 'Phép chặn trùng chỉ được bỏ qua ĐÚNG MỘT lần. Nhớ mãi thì '
              'thông báo ấy chết vĩnh viễn trong cả phiên chạy.');
      await router.stop();
    });

    test('app mở bình thường thì không điều hướng gì', () async {
      final router = dung();
      await router.start();
      await nhipTho();

      expect(daDieuHuong, isEmpty);
      await router.stop();
    });
  });

  group('chưa đăng nhập', () {
    test('giữ lại, đăng nhập xong mới điều hướng', () async {
      dangNhap = false;
      os.payloadMoApp = 'billDue:hd1:2026-09-17:3';

      final router = dung();
      await router.start();
      await nhipTho();

      expect(daDieuHuong, isEmpty,
          reason: 'Điều hướng lúc chưa có phiên chỉ bị guard của router đá về '
              '/login, và cú chạm coi như mất.');

      dangNhap = true;
      phienDoi.add(null);
      await nhipTho();

      expect(daDieuHuong, ['/bills'],
          reason: 'Token hết hạn sau vài ngày app đóng là chuyện thường. Bắt '
              'người dùng tự đi tìm lại thứ họ vừa bấm là hỏng đúng lúc tính '
              'năng cần chạy nhất.');
      await router.stop();
    });

    test('phiên đổi mà vẫn chưa đăng nhập thì tiếp tục giữ', () async {
      dangNhap = false;
      final router = dung();
      await router.start();

      os.cham.add('walletNeg:vi1:2026-09-15');
      await nhipTho();
      phienDoi.add(null);
      await nhipTho();

      expect(daDieuHuong, isEmpty);

      dangNhap = true;
      phienDoi.add(null);
      await nhipTho();

      expect(daDieuHuong, ['/wallets']);
      await router.stop();
    });

    test('chỉ giữ cú chạm MỚI NHẤT', () async {
      dangNhap = false;
      final router = dung();
      await router.start();

      os.cham.add('billDue:hd1:2026-09-17:3');
      os.cham.add('walletNeg:vi1:2026-09-15');
      await nhipTho();

      dangNhap = true;
      phienDoi.add(null);
      await nhipTho();

      expect(daDieuHuong, ['/wallets'],
          reason: 'Xếp hàng nhiều cú chạm là sau khi đăng nhập app tự nhảy qua '
              'mấy màn liên tiếp. Người dùng chỉ đang chờ đúng cái họ bấm '
              'lần cuối.');
      await router.stop();
    });
  });
}
