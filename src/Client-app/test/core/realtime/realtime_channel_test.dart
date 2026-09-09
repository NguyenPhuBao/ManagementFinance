/// Kênh thời gian thực: vòng đời, xác thực, và ánh xạ sự kiện.
///
/// Socket thật không xuất hiện ở đây. `RealtimeChannel` nhận một
/// `RealtimeSocketFactory`, nên toàn bộ hành vi kiểm được mà không cần mạng,
/// không cần backend, và không cần `socket_io_client`.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/constants/app_constants.dart';
import 'package:flowmoney/core/realtime/realtime_channel.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/realtime/realtime_socket.dart';

/// Kho token trong RAM — không đụng tới keychain thật của máy.
/// Cùng khuôn với `test/core/api/auth_interceptor_test.dart`.
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
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Socket giả: ghi lại token đã dùng, và cho test tự bắn sự kiện vào.
class _FakeSocket implements RealtimeSocket {
  _FakeSocket({required this.url, required this.token});

  final String url;
  final String token;

  bool daGoiConnect = false;
  bool daDispose = false;

  void Function(String event, dynamic data)? _batKy;
  void Function()? _khiNoiDuoc;
  void Function(Object? error)? _khiNoiHong;
  void Function(Object? reason)? _khiDut;

  @override
  void onAny(void Function(String event, dynamic data) handler) =>
      _batKy = handler;

  @override
  void onConnect(void Function() handler) => _khiNoiDuoc = handler;

  @override
  void onConnectError(void Function(Object? error) handler) =>
      _khiNoiHong = handler;

  @override
  void onDisconnect(void Function(Object? reason) handler) => _khiDut = handler;

  @override
  void connect() => daGoiConnect = true;

  @override
  void dispose() => daDispose = true;

  // ── Điều khiển từ phía test ──────────────────────────────────────────────
  void banSuKien(String ten, [dynamic data]) => _batKy?.call(ten, data);
  void banNoiDuoc() => _khiNoiDuoc?.call();
  void banNoiHong([Object? e]) => _khiNoiHong?.call(e ?? 'lỗi giả');
  void banDut([Object? r]) => _khiDut?.call(r ?? 'io server disconnect');
}

void main() {
  late List<_FakeSocket> daTao;
  late _FakeSecureStorage kho;

  setUp(() {
    daTao = [];
    kho = _FakeSecureStorage({AppConstants.accessTokenKey: 'token-1'});
  });

  RealtimeChannel dungKenh() => RealtimeChannel(
        secureStorage: kho,
        apiBaseUrl: 'http://127.0.0.1:3000/api',
        socketFactory: ({required String url, required String token}) {
          final s = _FakeSocket(url: url, token: token);
          daTao.add(s);
          return s;
        },
      );

  test('start nối tới GỐC máy chủ, không phải địa chỉ /api', () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 10);

    expect(daTao, hasLength(1));
    expect(daTao.single.url, 'http://127.0.0.1:3000',
        reason: 'Socket.io gắn vào gốc máy chủ. Giữ /api lại là bắt tay sai '
            'đường dẫn và chỉ hỏng bằng connect_error chung chung.');
    expect(daTao.single.daGoiConnect, isTrue);

    await kenh.stop();
  });

  test('token lấy từ kho bảo mật và đưa vào lúc bắt tay', () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 10);

    expect(daTao.single.token, 'token-1',
        reason: 'Backend xác thực JWT ngay ở middleware bắt tay; thiếu token '
            'là bị từ chối trước cả khi vào room.');

    await kenh.stop();
  });

  test('không có token thì KHÔNG nối, và không ném lỗi', () async {
    final kenh = RealtimeChannel(
      secureStorage: _FakeSecureStorage(),
      apiBaseUrl: 'http://127.0.0.1:3000/api',
      socketFactory: ({required String url, required String token}) {
        final s = _FakeSocket(url: url, token: token);
        daTao.add(s);
        return s;
      },
    );

    await kenh.start(idaccount: 10);

    expect(daTao, isEmpty,
        reason: 'Chưa có token nghĩa là chưa tới lúc, không phải lỗi. Nối tay '
            'không sẽ bị server từ chối rồi rơi vào vòng thử lại vô ích.');

    await kenh.stop();
  });

  test('ba sự kiện có thật được phát ra thành RealtimeEvent', () async {
    final kenh = dungKenh();
    final thay = <RealtimeEvent>[];
    final sub = kenh.events.listen(thay.add);
    await kenh.start(idaccount: 10);

    daTao.single
      ..banSuKien('bank_transaction.incoming', {'amount': 500000})
      ..banSuKien('ocr.completed', {'total_amount': 1})
      ..banSuKien('ocr.duplicate', {'error': 'trùng'});
    await Future<void>.delayed(Duration.zero);

    expect(thay, [
      RealtimeEvent.giaoDichNganHang,
      RealtimeEvent.ocrXong,
      RealtimeEvent.ocrTrung,
    ]);

    await sub.cancel();
    await kenh.stop();
  });

  test('sự kiện lạ bị bỏ qua', () async {
    final kenh = dungKenh();
    final thay = <RealtimeEvent>[];
    final sub = kenh.events.listen(thay.add);
    await kenh.start(idaccount: 10);

    daTao.single
      ..banSuKien('notification.new', {})
      ..banSuKien('audit_activity', {})
      ..banSuKien('linh tinh', null);
    await Future<void>.delayed(Duration.zero);

    expect(thay, isEmpty,
        reason: 'Backend thêm sự kiện mới không được làm vỡ bản client đang '
            'chạy trên máy người dùng.');

    await sub.cancel();
    await kenh.stop();
  });

  test('payload rác không làm vỡ gì — hệ quả của quyết định "hộp đen"',
      () async {
    final kenh = dungKenh();
    final thay = <RealtimeEvent>[];
    final sub = kenh.events.listen(thay.add);
    await kenh.start(idaccount: 10);

    daTao.single
      ..banSuKien('bank_transaction.incoming', null)
      ..banSuKien('ocr.completed', 'chuỗi chứ không phải map')
      ..banSuKien('ocr.duplicate', <dynamic>[1, 2, 3]);
    await Future<void>.delayed(Duration.zero);

    expect(thay, hasLength(3),
        reason: 'Client không đọc trường nào trong payload, nên hình dạng của '
            'nó không thể làm hỏng gì. Test này canh chính điều đó: ai thêm '
            'một phép đọc trường vào sẽ làm nó đỏ.');

    await sub.cancel();
    await kenh.stop();
  });

  test('stop() dispose socket và không phát gì nữa', () async {
    final kenh = dungKenh();
    final thay = <RealtimeEvent>[];
    final sub = kenh.events.listen(thay.add);
    await kenh.start(idaccount: 10);
    final socket = daTao.single;

    await kenh.stop();
    socket.banSuKien('bank_transaction.incoming', {});
    await Future<void>.delayed(Duration.zero);

    expect(socket.daDispose, isTrue,
        reason: 'Socket còn sống sau đăng xuất nghĩa là máy vẫn nằm trong room '
            'của người vừa rời đi — đây là lỗi bảo mật, không phải lỗi giao '
            'diện.');
    expect(thay, isEmpty);

    await sub.cancel();
  });
}
