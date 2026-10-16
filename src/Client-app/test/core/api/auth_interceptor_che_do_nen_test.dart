/// `AuthInterceptor` ở **chế độ nền** — lượt WorkManager của tự chuyển tiền (spec
/// 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 4.2).
///
/// Hai rủi ro, cả hai im lặng:
/// 1. App và engine nền cùng làm mới MỘT refresh token → backend đếm *dùng lại token* (heuristic AIOps) → cách ly
///    hoặc cưỡng chế đăng xuất.
/// 2. Lượt nền gặp 401 rồi xoá token → người dùng mở app thấy mình đã bị đăng xuất mà không biết vì sao.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/interceptors/auth_interceptor.dart';
import 'package:flowmoney/core/constants/app_constants.dart';

class _Kho implements FlutterSecureStorage {
  final Map<String, String> du = {
    AppConstants.accessTokenKey: 'token-cu',
    AppConstants.refreshTokenKey: 'refresh-cu',
  };

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
      du[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      du.remove(key);

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
      du.remove(key);
    } else {
      du[key] = value;
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Mọi request thường trả 401 với [body]; `/auth/refresh` trả token mới (và được đếm).
class _MayChu implements HttpClientAdapter {
  _MayChu(this.body);
  final String body;
  int refresh = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final h = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (o.path.endsWith('/auth/refresh')) {
      refresh++;
      return ResponseBody.fromString(
          '{"success":true,"data":{"accessToken":"moi","refreshToken":"moi"}}', 200,
          headers: h);
    }
    return ResponseBody.fromString(body, 401, headers: h);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<({_Kho kho, _MayChu may, List<Object> phat})> chay(String body) async {
    const base = 'http://localhost:3000/api';
    final kho = _Kho();
    final may = _MayChu(body);
    final it = AuthInterceptor(
      secureStorage: kho,
      dioLamMoi: Dio(BaseOptions(baseUrl: base))..httpClientAdapter = may,
      cheDoNen: true,
    );
    addTearDown(it.dispose);
    final phat = <Object>[];
    final s1 = it.sessionExpiredStream.listen((_) => phat.add('phien_chet'));
    final s2 = it.taiKhoanBiTuChoi.listen(phat.add);
    addTearDown(() async {
      await s1.cancel();
      await s2.cancel();
    });
    final dio = Dio(BaseOptions(baseUrl: base))
      ..httpClientAdapter = may
      ..interceptors.add(it);
    await expectLater(dio.get<dynamic>('/sync/pull'), throwsA(isA<DioException>()));
    await Future<void>.delayed(Duration.zero);
    return (kho: kho, may: may, phat: phat);
  }

  test('401 → KHÔNG gọi /auth/refresh, KHÔNG xoá token, KHÔNG phát phiên chết', () async {
    final r = await chay('{"success":false,"message":"Unauthorized"}');
    expect(r.may.refresh, 0, reason: 'app và nền cùng làm mới MỘT refresh token = backend đếm dùng lại token');
    expect(r.kho.du[AppConstants.accessTokenKey], 'token-cu');
    expect(r.kho.du[AppConstants.refreshTokenKey], 'refresh-cu');
    expect(r.phat, isEmpty);
  });

  test('401 MANG MÃ tài khoản → ở nền vẫn không xoá token (app tự xử lúc mở)', () async {
    final r = await chay(
        '{"success":false,"code":"ACCOUNT_INACTIVE","idaccount":10,"reason_inactive":"thử"}');
    expect(r.kho.du[AppConstants.accessTokenKey], 'token-cu');
    expect(r.phat, isEmpty, reason: 'không ai nghe ở engine nền — và đăng xuất im lặng ở nền là lỗi');
  });
}
