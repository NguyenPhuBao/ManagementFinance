/// Sự kiện `account.force_logout` đi ra đường riêng, không lẫn vào `events`.
///
/// Vì sao tách luồng: `events` mang cam kết "client không đọc trường nào của
/// payload" (xem chú thích đầu `realtime_event.dart`), vì
/// `bank_transaction.incoming` được backend phát từ hai chỗ với hai hình dạng.
/// Sự kiện này thì BẮT BUỘC đọc payload — nó phải có cửa riêng để cam kết kia
/// không bị nới lỏng theo. Spec cưỡng chế đăng xuất §3.2.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/auth/buoc_dang_xuat.dart';
import 'package:flowmoney/core/constants/app_constants.dart';
import 'package:flowmoney/core/realtime/realtime_channel.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/realtime/realtime_socket.dart';

/// Kho token trong RAM — không đụng tới keychain thật của máy.
/// Cùng khuôn với `test/core/realtime/realtime_channel_test.dart`.
class _FakeSecureStorage implements FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? seed]) : _store = {...?seed};

  final Map<String, String> _store;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Connectivity giả: test tự quyết định khi nào "đổi mạng".
class _ConnectivityGia implements Connectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> hienTai = [ConnectivityResult.wifi];

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => hienTai;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Socket giả: cho test tự bắn sự kiện vào.
class _FakeSocket implements RealtimeSocket {
  _FakeSocket({required this.url, required this.token});

  final String url;
  final String token;

  void Function(String event, dynamic data)? _batKy;

  @override
  void onAny(void Function(String event, dynamic data) handler) =>
      _batKy = handler;

  @override
  void onConnect(void Function() handler) {}

  @override
  void onConnectError(void Function(Object? error) handler) {}

  @override
  void onDisconnect(void Function(Object? reason) handler) {}

  @override
  void connect() {}

  @override
  void dispose() {}

  void banSuKien(String ten, [dynamic data]) => _batKy?.call(ten, data);
}

void main() {
  late List<_FakeSocket> daTao;
  late _FakeSecureStorage kho;
  late _ConnectivityGia mang;

  setUp(() {
    daTao = [];
    kho = _FakeSecureStorage({AppConstants.accessTokenKey: 'token-1'});
    mang = _ConnectivityGia();
  });

  RealtimeChannel dungKenh() => RealtimeChannel(
        secureStorage: kho,
        apiBaseUrl: 'http://127.0.0.1:3000/api',
        connectivity: mang,
        socketFactory: ({required String url, required String token}) {
          final s = _FakeSocket(url: url, token: token);
          daTao.add(s);
          return s;
        },
      );

  test('force_logout đúng tài khoản → phát buocDangXuat, KHÔNG vào events',
      () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final suKienThuong = <RealtimeEvent>[];
    kenh.events.listen(suKienThuong.add);
    final cho = expectLater(
      kenh.buocDangXuat,
      emits(isA<ThongBaoBuocDangXuat>()
          .having((t) => t.lyDo, 'lyDo', LyDoBuocDangXuat.daXoa)
          .having((t) => t.nguon, 'nguon', NguonBuocDangXuat.socket)
          .having((t) => t.idaccount, 'idaccount', 11)),
    );

    daTao.single.banSuKien('account.force_logout', {
      'idaccount': 11,
      'reason': 'ACCOUNT_DELETED',
      'message':
          'Tài khoản của bạn đã bị ngừng hoạt động hoặc xóa bởi quản trị viên.',
    });

    await cho;
    await Future<void>.delayed(Duration.zero);
    expect(suKienThuong, isEmpty,
        reason: 'lẫn vào events là kéo theo cả một vòng syncNow() và một toast '
            '"vừa có giao dịch mới" hoàn toàn sai');
    await kenh.stop();
  });

  test('admin khoá (ACCOUNT_INACTIVE) → biKhoa, giữ nguyên câu của server',
      () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final cho = expectLater(
      kenh.buocDangXuat,
      emits(isA<ThongBaoBuocDangXuat>()
          .having((t) => t.lyDo, 'lyDo', LyDoBuocDangXuat.biKhoa)
          .having((t) => t.loiNhan, 'loiNhan', contains('Vi phạm điều khoản'))),
    );

    daTao.single.banSuKien('account.force_logout', {
      'idaccount': 11,
      'reason': 'ACCOUNT_INACTIVE',
      'message': 'Tài khoản của bạn đã bị vô hiệu hóa. Lý do: Vi phạm điều khoản.',
    });

    await cho;
    await kenh.stop();
  });

  test('lệch idaccount → im hẳn', () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final nhan = <ThongBaoBuocDangXuat>[];
    kenh.buocDangXuat.listen(nhan.add);

    daTao.single.banSuKien('account.force_logout', {
      'idaccount': 12,
      'reason': 'ACCOUNT_DELETED',
    });

    await Future<void>.delayed(Duration.zero);
    expect(nhan, isEmpty,
        reason: 'gói tin của tài khoản khác mà nhận là đá nhầm người đang '
            'đăng nhập ra, kèm một lượt dọn SQLite');
    await kenh.stop();
  });

  test('payload thiếu idaccount → vẫn phát (socket đã xác thực bằng JWT của ta)',
      () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final nhan = <ThongBaoBuocDangXuat>[];
    kenh.buocDangXuat.listen(nhan.add);

    daTao.single.banSuKien('account.force_logout', {'reason': 'ACCOUNT_INACTIVE'});

    await Future<void>.delayed(Duration.zero);
    expect(nhan, hasLength(1),
        reason: 'không lọc được thì vẫn phải nhận: room đã do server chọn theo '
            'JWT của chính phiên này');
    expect(nhan.single.lyDo, LyDoBuocDangXuat.biKhoa);
    await kenh.stop();
  });

  test('payload không phải Map → vẫn phát biKhoa', () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final nhan = <ThongBaoBuocDangXuat>[];
    kenh.buocDangXuat.listen(nhan.add);

    daTao.single.banSuKien('account.force_logout', 'hỏng');

    await Future<void>.delayed(Duration.zero);
    expect(nhan, hasLength(1),
        reason: 'bỏ qua sự kiện là để người dùng ngồi lại trong app');
    expect(nhan.single.lyDo, LyDoBuocDangXuat.biKhoa);
    await kenh.stop();
  });

  test('sau stop() thì im', () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final socket = daTao.single;
    final nhan = <ThongBaoBuocDangXuat>[];
    kenh.buocDangXuat.listen(nhan.add);
    await kenh.stop();

    socket.banSuKien('account.force_logout', {'idaccount': 11});

    await Future<void>.delayed(Duration.zero);
    expect(nhan, isEmpty,
        reason: 'gói tin tới muộn sau khi đăng xuất không được đá người vừa '
            'đăng nhập vào máy ra');
  });

  test('sự kiện thường vẫn đi đường cũ, không lọt sang buocDangXuat', () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final nhan = <ThongBaoBuocDangXuat>[];
    kenh.buocDangXuat.listen(nhan.add);
    final cho = expectLater(kenh.events, emits(RealtimeEvent.ocrXong));

    daTao.single.banSuKien('ocr.completed', {'gì đó': 1});

    await cho;
    expect(nhan, isEmpty);
    await kenh.stop();
  });
}
