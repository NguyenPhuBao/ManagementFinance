/// Canh chừng G12: `AuthInterceptor` xoá token khi không thể làm mới phiên,
/// nhưng trước đây KHÔNG báo cho ai. App kẹt ở `AuthSuccess` với token đã bị
/// xoá — mọi request sau đó không có header → 401 → refresh (đã mất refresh
/// token) → xoá lại → lặp cho tới khi khởi động lại app.
///
/// Đây cũng là test đầu tiên chạm tới `auth_interceptor.dart`.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/interceptors/auth_interceptor.dart';
import 'package:flowmoney/core/constants/app_constants.dart';

/// Kho token trong RAM — không đụng tới keychain thật của máy.
class _FakeSecureStorage implements FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? seed])
      : _store = {...?seed};

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
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

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

  bool get isEmpty => _store.isEmpty;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Trả 401 cho mọi request, không chạm mạng thật.
class _Always401Adapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      '{"success":false,"message":"Unauthorized"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(AuthInterceptor interceptor, HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(interceptor);
  return dio;
}

void main() {
  test(
      'phiên không thể làm mới được thì interceptor phát tín hiệu, không chỉ xoá token trong im lặng',
      () async {
    // Có access token nhưng KHÔNG có refresh token — đúng tình huống phiên chết.
    final storage = _FakeSecureStorage({
      AppConstants.accessTokenKey: 'token-da-chet',
    });
    final interceptor = AuthInterceptor(secureStorage: storage);
    addTearDown(interceptor.dispose);
    final adapter = _Always401Adapter();
    final dio = _dioWith(interceptor, adapter);

    final signal = interceptor.sessionExpiredStream.first
        .timeout(const Duration(seconds: 3));

    await expectLater(
      dio.get<dynamic>('/sync/pull'),
      throwsA(isA<DioException>()),
    );

    await expectLater(
      signal,
      completes,
      reason: 'Canh chừng G12: không có tín hiệu này thì AuthBloc vẫn ở '
          'AuthSuccess trong khi token đã bị xoá, và app quay vòng '
          '401 → refresh hỏng → xoá token cho tới khi người dùng tự khởi '
          'động lại.',
    );

    expect(
      storage.isEmpty,
      isTrue,
      reason: 'Token phải được dọn sạch — đây là hành vi vốn có, tín hiệu '
          'chỉ được thêm vào chứ không thay thế nó.',
    );
  });

  test('không phát tín hiệu khi vốn đã không còn token nào để xoá', () async {
    // Sau lần xoá đầu tiên, mọi request tiếp theo vẫn nhận 401. Nếu lần nào
    // cũng phát tín hiệu thì AuthBloc sẽ bị dội sự kiện, và chính việc
    // verifySession() (cũng đi qua Dio này) sẽ tự nuôi vòng lặp đó.
    final storage = _FakeSecureStorage();
    final interceptor = AuthInterceptor(secureStorage: storage);
    addTearDown(interceptor.dispose);
    final dio = _dioWith(interceptor, _Always401Adapter());

    var emissions = 0;
    final sub = interceptor.sessionExpiredStream.listen((_) => emissions++);
    addTearDown(sub.cancel);

    await expectLater(
      dio.get<dynamic>('/auth/profile'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      emissions,
      0,
      reason: 'Không có gì để mất thì không có phiên nào vừa chết. Phát tín '
          'hiệu ở đây sẽ biến mỗi lần 401 lúc chưa đăng nhập thành một sự '
          'kiện đăng xuất giả.',
    );
  });

  test('lỗi khác 401 đi thẳng ra ngoài, không đụng tới token', () async {
    final storage = _FakeSecureStorage({
      AppConstants.accessTokenKey: 'token-con-tot',
      AppConstants.refreshTokenKey: 'refresh-con-tot',
    });
    final interceptor = AuthInterceptor(secureStorage: storage);
    addTearDown(interceptor.dispose);

    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
    dio.httpClientAdapter = _StatusAdapter(500);
    dio.interceptors.add(interceptor);

    var emissions = 0;
    final sub = interceptor.sessionExpiredStream.listen((_) => emissions++);
    addTearDown(sub.cancel);

    await expectLater(
      dio.get<dynamic>('/sync/push'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(emissions, 0);
    expect(
      await storage.read(key: AppConstants.accessTokenKey),
      'token-con-tot',
      reason: 'Lỗi 5xx là sự cố phía máy chủ, không phải phiên chết — giữ '
          'nguyên token là cam kết offline-first của dự án.',
    );
  });
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"success":false}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
