/// `system.broadcast` đi luồng riêng `tinHeThong`, không lẫn vào `events` (spec 2026-10-26 mục 3.1) — ngoại lệ hộp đen thứ
/// hai sau `account.force_logout`, cùng khuôn (`realtime_buoc_dang_xuat_test.dart`).
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/constants/app_constants.dart';
import 'package:flowmoney/core/realtime/realtime_channel.dart';
import 'package:flowmoney/core/realtime/realtime_event.dart';
import 'package:flowmoney/core/realtime/realtime_socket.dart';
import 'package:flowmoney/core/realtime/tin_he_thong.dart';

/// Kho token trong RAM — không đụng tới keychain thật của máy.
class _FakeSecureStorage implements FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? seed]) : _store = {...?seed};

  final Map<String, String> _store;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
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
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

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
  void onAny(void Function(String event, dynamic data) handler) => _batKy = handler;

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

Map<String, Object?> _tin({String id = 'b-1', Object? metadata = const <String, Object?>{}}) => {
      'id': id,
      'title': 'Bảo trì nâng cấp tối nay',
      'message': 'FlowMoney nâng cấp máy chủ từ 23:00 đến 23:30.',
      'level': 'warning',
      'metadata': metadata,
    };

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

  test('tin admin → phát tinHeThong kèm idaccount của phiên, KHÔNG vào events', () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final thuong = <RealtimeEvent>[];
    kenh.events.listen(thuong.add);
    final cho = expectLater(
      kenh.tinHeThong,
      emits(isA<TinHeThongNhan>()
          .having((t) => t.idaccount, 'idaccount', 11)
          .having((t) => t.tin.id, 'id', 'b-1')
          .having((t) => t.tin.mucDo, 'mucDo', MucDoTinHeThong.warning)),
    );
    daTao.single.banSuKien('system.broadcast', _tin());
    await cho;
    await Future<void>.delayed(Duration.zero);
    expect(thuong, isEmpty, reason: 'lẫn vào events là một vòng syncNow() thừa cho mỗi tin admin');
    await kenh.stop();
  });

  test('tin bảo trì tự động → im', () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final nhan = <TinHeThongNhan>[];
    kenh.tinHeThong.listen(nhan.add);
    daTao.single.banSuKien('system.broadcast', _tin(metadata: {'type': 'EMERGENCY_MAINTENANCE'}));
    await Future<void>.delayed(Duration.zero);
    expect(nhan, isEmpty);
    await kenh.stop();
  });

  test('sau stop() thì im', () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final socket = daTao.single;
    final nhan = <TinHeThongNhan>[];
    kenh.tinHeThong.listen(nhan.add);
    await kenh.stop();
    socket.banSuKien('system.broadcast', _tin());
    await Future<void>.delayed(Duration.zero);
    expect(nhan, isEmpty, reason: 'tin tới muộn sau đăng xuất không được ghi cho tài khoản vừa rời');
  });

  test('sự kiện thường không lọt sang tinHeThong', () async {
    final kenh = dungKenh();
    await kenh.start(idaccount: 11);
    final nhan = <TinHeThongNhan>[];
    kenh.tinHeThong.listen(nhan.add);
    final cho = expectLater(kenh.events, emits(RealtimeEvent.dongBoXong));
    daTao.single.banSuKien('sync.completed', {'id': 'x', 'title': 't', 'message': 'm'});
    await cho;
    expect(nhan, isEmpty);
    await kenh.stop();
  });
}
