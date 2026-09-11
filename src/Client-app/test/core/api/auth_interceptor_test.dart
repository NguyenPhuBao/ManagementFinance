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

/// Máy chủ giả: route theo đường dẫn, không chạm mạng thật. Dùng chung cho Dio
/// chính (đi qua interceptor) và Dio làm mới (không đi qua interceptor).
class _MayChuGia implements HttpClientAdapter {
  // Không ca nào trong Step 1 đổi giá trị mặc định, nhưng để tham số hoá cho
  // các test sau này cần token khác.
  // ignore: unused_element_parameter
  _MayChuGia({this.tokenMoi = 'access-moi', this.refreshMoi = 'refresh-moi'});

  final String tokenMoi;
  final String refreshMoi;

  /// Kịch bản cho `/auth/refresh`, lấy theo thứ tự gọi; hết kịch bản thì 200.
  /// `int` = trả mã ấy; `DioExceptionType` = ném lỗi không có phản hồi.
  final List<Object> kichBanRefresh = [];
  int refreshCalls = 0;

  /// Nếu có, `/auth/refresh` chờ completer này trước khi trả lời.
  Completer<void>? khoaRefresh;

  /// Nếu có, request tới [duongDanBiKhoa] chờ completer này trước khi trả lời.
  String? duongDanBiKhoa;
  Completer<void>? khoaDuongDan;

  /// Request thường: 401 nếu Bearer khác [tokenMoi]; nếu không trả [maSauThuLai].
  int maSauThuLai = 200;
  final List<String?> bearerDaThay = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/auth/refresh')) {
      refreshCalls++;
      if (khoaRefresh != null) await khoaRefresh!.future;
      final kb = kichBanRefresh.isEmpty ? 200 : kichBanRefresh.removeAt(0);
      if (kb is DioExceptionType) {
        throw DioException(requestOptions: options, type: kb, message: 'giả: ${kb.name}');
      }
      if (kb == 200) {
        return _json(
          '{"success":true,"data":{"accessToken":"$tokenMoi","refreshToken":"$refreshMoi"}}',
          200,
        );
      }
      return _json('{"success":false,"message":"gia"}', kb as int);
    }
    if (options.path == duongDanBiKhoa && khoaDuongDan != null) {
      await khoaDuongDan!.future;
    }
    final bearer = options.headers['Authorization'] as String?;
    bearerDaThay.add(bearer);
    if (bearer != 'Bearer $tokenMoi') {
      return _json('{"success":false,"message":"Unauthorized"}', 401);
    }
    return _json('{"success":true,"data":{}}', maSauThuLai);
  }

  ResponseBody _json(String body, int status) => ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

({Dio dio, AuthInterceptor interceptor}) _dungVoiMayChu(
  _FakeSecureStorage storage,
  _MayChuGia server,
) {
  const base = 'http://localhost:3000/api';
  final dioLamMoi = Dio(BaseOptions(baseUrl: base))..httpClientAdapter = server;
  final interceptor = AuthInterceptor(secureStorage: storage, dioLamMoi: dioLamMoi);
  final dio = Dio(BaseOptions(baseUrl: base))
    ..httpClientAdapter = server
    ..interceptors.add(interceptor);
  return (dio: dio, interceptor: interceptor);
}

_FakeSecureStorage _khoCoPhien() => _FakeSecureStorage({
      AppConstants.accessTokenKey: 'token-cu',
      AppConstants.refreshTokenKey: 'refresh-cu',
    });

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

  group('§3.8 điểm 1 — làm mới hỏng tạm thời thì giữ token', () {
    for (final loai in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      test('làm mới gặp ${loai.name} → giữ hai token, không tín hiệu, nơi gọi nhận lỗi ấy chứ không phải 401',
          () async {
        final storage = _khoCoPhien();
        final server = _MayChuGia()..kichBanRefresh.add(loai);
        final (:dio, :interceptor) = _dungVoiMayChu(storage, server);
        addTearDown(interceptor.dispose);
        var emissions = 0;
        final sub = interceptor.sessionExpiredStream.listen((_) => emissions++);
        addTearDown(sub.cancel);

        await expectLater(
          dio.get<dynamic>('/sync/pull'),
          throwsA(isA<DioException>()
              .having((e) => e.type, 'type', loai)
              .having((e) => e.response?.statusCode, 'statusCode', isNull)),
          reason: 'verifySession coi 401 là phiên chết; trả 401 gốc ra ngoài '
              'là AuthBloc đăng xuất — đúng lỗi §3.8 muốn đóng. Lỗi kết nối '
              'thì AuthRepositoryImpl dịch thành NetworkException → unknown.',
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(emissions, 0, reason: 'không kết luận được gì về phiên');
        expect(await storage.read(key: AppConstants.accessTokenKey), 'token-cu',
            reason: 'giữ token để lần gọi API sau tự làm mới lại');
        expect(await storage.read(key: AppConstants.refreshTokenKey), 'refresh-cu');
        expect(server.refreshCalls, 1);
      });
    }

    test('làm mới trả 503 → giữ hai token, không tín hiệu, nơi gọi nhận 503', () async {
      final storage = _khoCoPhien();
      final server = _MayChuGia()..kichBanRefresh.add(503);
      final (:dio, :interceptor) = _dungVoiMayChu(storage, server);
      addTearDown(interceptor.dispose);
      var emissions = 0;
      final sub = interceptor.sessionExpiredStream.listen((_) => emissions++);
      addTearDown(sub.cancel);

      await expectLater(
        dio.get<dynamic>('/sync/pull'),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 503)),
        reason: '5xx của /auth/refresh là sự cố máy chủ, không phải phiên chết; '
            'verifySession dịch ServerException(503) thành unknown.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions, 0);
      expect(await storage.read(key: AppConstants.accessTokenKey), 'token-cu');
      expect(await storage.read(key: AppConstants.refreshTokenKey), 'refresh-cu');
    });

    for (final ma in [400, 401]) {
      test('làm mới trả $ma (không mã) → xoá token, tín hiệu đúng một lần, nơi gọi nhận 401 gốc',
          () async {
        final storage = _khoCoPhien();
        final server = _MayChuGia()..kichBanRefresh.add(ma);
        final (:dio, :interceptor) = _dungVoiMayChu(storage, server);
        addTearDown(interceptor.dispose);
        var emissions = 0;
        final sub = interceptor.sessionExpiredStream.listen((_) => emissions++);
        addTearDown(sub.cancel);

        await expectLater(
          dio.get<dynamic>('/sync/pull'),
          throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 401)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(emissions, 1, reason: 'đường cũ giữ nguyên: đây là phiên chết thật');
        expect(storage.isEmpty, isTrue);
      });
    }

    test('làm mới thành công → thử lại bằng token mới, lưu cả hai token', () async {
      final storage = _khoCoPhien();
      final server = _MayChuGia();
      final (:dio, :interceptor) = _dungVoiMayChu(storage, server);
      addTearDown(interceptor.dispose);

      final res = await dio.get<dynamic>('/sync/pull');

      expect(res.statusCode, 200);
      expect(server.bearerDaThay, ['Bearer token-cu', 'Bearer access-moi'],
          reason: 'request gốc mang token cũ → 401 → thử lại đúng một lần bằng token mới');
      expect(await storage.read(key: AppConstants.accessTokenKey), 'access-moi');
      expect(await storage.read(key: AppConstants.refreshTokenKey), 'refresh-moi',
          reason: 'token rotation: server thu hồi refresh token cũ (auth.service.js:421)');
    });

    test('thử lại hỏng (500) sau khi làm mới thành công → giữ token mới, không tín hiệu', () async {
      final storage = _khoCoPhien();
      final server = _MayChuGia()..maSauThuLai = 500;
      final (:dio, :interceptor) = _dungVoiMayChu(storage, server);
      addTearDown(interceptor.dispose);
      var emissions = 0;
      final sub = interceptor.sessionExpiredStream.listen((_) => emissions++);
      addTearDown(sub.cancel);

      await expectLater(
        dio.get<dynamic>('/sync/pull'),
        throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'statusCode', 500)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions, 0);
      expect(await storage.read(key: AppConstants.accessTokenKey), 'access-moi',
          reason: 'Lỗi thứ ba tìm ra khi sửa §3.8: token vừa được cấp, thử lại '
              'hỏng không nói gì về phiên — trước đây `catch (_)` xoá cả hai token.');
      expect(await storage.read(key: AppConstants.refreshTokenKey), 'refresh-moi');
    });
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
