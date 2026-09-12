/// Kênh thời gian thực: vòng đời, xác thực, và ánh xạ sự kiện.
///
/// Socket thật không xuất hiện ở đây. `RealtimeChannel` nhận một
/// `RealtimeSocketFactory`, nên toàn bộ hành vi kiểm được mà không cần mạng,
/// không cần backend, và không cần `socket_io_client`.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'dart:async';

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

/// Connectivity giả: test tự quyết định khi nào "đổi mạng".
/// Cùng khuôn với `test/core/network/connection_monitor_test.dart`.
class _ConnectivityGia implements Connectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> hienTai = [ConnectivityResult.wifi];

  void doi(List<ConnectivityResult> moi) {
    hienTai = moi;
    _controller.add(moi);
  }

  void mat() => doi([ConnectivityResult.none]);
  void co() => doi([ConnectivityResult.wifi]);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => hienTai;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

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
      connectivity: mang,
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

  test('bốn sự kiện có thật được phát ra thành RealtimeEvent', () async {
    final kenh = dungKenh();
    final thay = <RealtimeEvent>[];
    final sub = kenh.events.listen(thay.add);
    await kenh.start(idaccount: 10);

    daTao.single
      ..banSuKien('bank_transaction.incoming', {'amount': 500000})
      ..banSuKien('ocr.completed', {'total_amount': 1})
      ..banSuKien('ocr.duplicate', {'error': 'trùng'})
      // Hình dạng thật của backend (`core/socket.js` emitSyncCompleted):
      // client vẫn không đọc trường nào trong đó.
      ..banSuKien('sync.completed', {
        'summary': {'pushed': 1},
        'timestamp': '2026-09-12T10:00:00.000Z',
      });
    await Future<void>.delayed(Duration.zero);

    expect(thay, [
      RealtimeEvent.giaoDichNganHang,
      RealtimeEvent.ocrXong,
      RealtimeEvent.ocrTrung,
      RealtimeEvent.dongBoXong,
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

  group('nối lại', () {
    test('bảng giãn cách: 2 → 5 → 15 → 30 → 60, rồi giữ 60', () {
      expect(khoangChoLanThu(1), const Duration(seconds: 2));
      expect(khoangChoLanThu(2), const Duration(seconds: 5));
      expect(khoangChoLanThu(3), const Duration(seconds: 15));
      expect(khoangChoLanThu(4), const Duration(seconds: 30));
      expect(khoangChoLanThu(5), const Duration(seconds: 60));
      expect(khoangChoLanThu(6), const Duration(seconds: 60),
          reason: 'Chạm trần thì giữ nguyên, không giãn tiếp — server hỏng cả '
              'ngày thì client vẫn phải thử lại mỗi phút.');
      expect(khoangChoLanThu(99), const Duration(seconds: 60));
      expect(khoangChoLanThu(0), const Duration(seconds: 2),
          reason: 'Giá trị vô lý phải quy về lần đầu chứ không được ném lỗi.');
    });

    test('nối hỏng thì thử lại sau đúng khoảng chờ, và ĐỌC LẠI token',
        () => FakeAsync().run((async) {
              kho = _FakeSecureStorage(
                  {AppConstants.accessTokenKey: 'token-cu'});
              final kenh = dungKenh();
              kenh.start(idaccount: 10);
              async.flushMicrotasks();

              expect(daTao, hasLength(1));
              expect(daTao[0].token, 'token-cu');

              // AuthInterceptor làm mới token trong lúc socket đang đứt.
              kho.write(key: AppConstants.accessTokenKey, value: 'token-moi');
              daTao[0].banNoiHong();

              async.elapse(const Duration(seconds: 1));
              expect(daTao, hasLength(1),
                  reason: 'Chưa hết khoảng chờ thì chưa được thử lại.');

              async.elapse(const Duration(seconds: 2));
              async.flushMicrotasks();
              expect(daTao, hasLength(2));
              expect(daTao[1].token, 'token-moi',
                  reason: 'Token truy cập có hạn. Nối lại bằng token cũ là gõ '
                      'cửa server bằng đúng chuỗi vừa bị từ chối — đó chính là '
                      'lý do tắt cơ chế nối lại của thư viện.');

              kenh.stop();
            }));

    test('giãn cách nới dần qua các lần hỏng liên tiếp',
        () => FakeAsync().run((async) {
              final kenh = dungKenh();
              kenh.start(idaccount: 10);
              async.flushMicrotasks();

              daTao[0].banNoiHong();
              async.elapse(const Duration(seconds: 2));
              async.flushMicrotasks();
              expect(daTao, hasLength(2));

              daTao[1].banNoiHong();
              async.elapse(const Duration(seconds: 2));
              expect(daTao, hasLength(2),
                  reason: 'Lần thứ hai phải chờ 5 giây, không phải 2.');
              async.elapse(const Duration(seconds: 3));
              async.flushMicrotasks();
              expect(daTao, hasLength(3));

              kenh.stop();
            }));

    test('nối được thì giãn cách reset về đầu',
        () => FakeAsync().run((async) {
              final kenh = dungKenh();
              kenh.start(idaccount: 10);
              async.flushMicrotasks();

              daTao[0].banNoiHong();
              async.elapse(const Duration(seconds: 2));
              async.flushMicrotasks();
              daTao[1].banNoiHong();
              async.elapse(const Duration(seconds: 5));
              async.flushMicrotasks();
              expect(daTao, hasLength(3));

              // Lần này nối được, rồi lại đứt.
              daTao[2].banNoiDuoc();
              daTao[2].banDut();
              async.elapse(const Duration(seconds: 2));
              async.flushMicrotasks();

              expect(daTao, hasLength(4),
                  reason: 'Reset rồi thì lần đứt kế tiếp chỉ chờ 2 giây. Không '
                      'reset thì một máy đã từng mất mạng lâu sẽ mãi mãi chờ 60 '
                      'giây cho mỗi lần chớp mạng.');

              kenh.stop();
            }));

    test('đứt kết nối cũng kích hoạt nối lại',
        () => FakeAsync().run((async) {
              final kenh = dungKenh();
              kenh.start(idaccount: 10);
              async.flushMicrotasks();

              daTao[0].banNoiDuoc();
              daTao[0].banDut('transport close');
              async.elapse(const Duration(seconds: 2));
              async.flushMicrotasks();

              expect(daTao, hasLength(2));
              kenh.stop();
            }));

    test('mạng về thì nối lại NGAY, không nằm chờ hết giãn cách',
        () => FakeAsync().run((async) {
              final kenh = dungKenh();
              kenh.start(idaccount: 10);
              async.flushMicrotasks();

              // Bốn lần hỏng liên tiếp đẩy giãn cách lên 30 giây.
              for (var i = 0; i < 4; i++) {
                daTao.last.banNoiHong();
                async.elapse(khoangChoLanThu(i + 1));
                async.flushMicrotasks();
              }
              expect(daTao, hasLength(5));

              daTao.last.banNoiHong();
              // Đang chờ 60 giây. Mạng về ở giây thứ hai.
              async.elapse(const Duration(seconds: 2));
              mang.co();
              async.elapse(const Duration(milliseconds: 100));
              async.flushMicrotasks();

              expect(daTao, hasLength(6),
                  reason: 'Đo trên máy ảo ngày 2026-09-09: mạng về lúc 16:51:36 '
                      'mà kênh nằm im tới 16:52:02 mới nối — 26 giây vô ích, vì '
                      'nó chỉ biết chờ hết giãn cách. SyncEngine không có lỗi '
                      'này vì nó nghe onConnectivityChanged. Giãn cách là để '
                      'khỏi dội vào một server đang hỏng, KHÔNG phải để phạt '
                      'người dùng vừa đi qua một cái hầm.');

              // Và bậc giãn cách phải về ĐẦU, không chỉ nối lại một lần.
              daTao.last.banNoiHong();
              async.elapse(const Duration(seconds: 2));
              async.flushMicrotasks();
              expect(daTao, hasLength(7),
                  reason: 'Không reset _soLanHong thì lần hỏng kế tiếp nhảy '
                      'thẳng lên 60 giây, và người dùng vừa có mạng lại phải '
                      'chờ cả phút. Bản sai có chủ ý "quên reset" đi lọt qua '
                      'phép kiểm ở trên, nên phải canh thêm ở đây.');

              kenh.stop();
            }));

    test('mạng MẤT thì không thử nối, khỏi tốn công vô ích',
        () => FakeAsync().run((async) {
              final kenh = dungKenh();
              kenh.start(idaccount: 10);
              async.flushMicrotasks();

              daTao.last.banNoiHong();
              async.elapse(const Duration(seconds: 1));
              mang.mat();
              async.elapse(const Duration(milliseconds: 100));
              async.flushMicrotasks();

              expect(daTao, hasLength(1),
                  reason: 'Chỉ sự kiện CÓ mạng mới đáng nối lại ngay. Phản ứng '
                      'với cả sự kiện mất mạng là tự bắn thêm một lần nối chắc '
                      'chắn hỏng.');

              kenh.stop();
            }));

    test('stop() huỷ được lần nối lại ĐANG CHỜ',
        () => FakeAsync().run((async) {
              final kenh = dungKenh();
              kenh.start(idaccount: 10);
              async.flushMicrotasks();

              daTao[0].banNoiHong();
              expect(async.pendingTimers, isNotEmpty,
                  reason: 'Dựng bối cảnh: phải đang có một hẹn giờ nối lại thì '
                      'phép kiểm bên dưới mới có nghĩa.');

              kenh.stop();

              // Canh THẲNG cái hẹn giờ, không canh gián tiếp qua "có socket mới
              // hay không". Chốt `if (_daDung) return` trong `_noi()` đã chặn
              // lần nối lại rồi, nên một test chỉ đếm số socket sẽ xanh KỂ CẢ
              // khi hẹn giờ vẫn còn sống — đã kiểm bằng bản sai có chủ ý.
              expect(async.pendingTimers, isEmpty,
                  reason: 'Hẹn giờ sót lại giữ đối tượng sống thêm tới một phút '
                      'sau khi đăng xuất, rồi nổ một lần vô ích. Cùng loại lỗi '
                      'với việc quên gọi cancelAll() khi dừng '
                      'NotificationScanner.');

              async.elapse(const Duration(seconds: 120));
              async.flushMicrotasks();

              expect(daTao, hasLength(1),
                  reason: 'Và không có lần nối lại nào SAU khi đã dừng — nối '
                      'lại lúc ấy là nối bằng token của người vừa rời đi.');
            }));
  });
}
