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

  /// Nếu đặt, `read` ném lỗi khi đọc đúng khoá này — mô phỏng
  /// `PlatformException` thật của keystore (keystore hỏng, huỷ sinh trắc
  /// học, khôi phục OS…), thứ không phải `DioException`.
  String? khoaNemLoiKhiDoc;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == khoaNemLoiKhiDoc) {
      throw StateError('kho token hỏng');
    }
    return _store[key];
  }

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
  static const String tokenMoi = 'access-moi';
  static const String refreshMoi = 'refresh-moi';

  /// Kịch bản cho `/auth/refresh`, lấy theo thứ tự gọi; hết kịch bản thì 200.
  /// `int` = trả mã ấy; `DioExceptionType` = ném lỗi không có phản hồi;
  /// `String` = body JSON thô, trả 200.
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
      if (kb is String) {
        return _json(kb, 200);
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

    test('làm mới trả 200 nhưng body không có accessToken → giữ hai token, không tín hiệu, nơi gọi nhận lỗi tạm thời',
        () async {
      final storage = _khoCoPhien();
      final server = _MayChuGia()..kichBanRefresh.add('{"success":true,"data":{}}');
      final (:dio, :interceptor) = _dungVoiMayChu(storage, server);
      addTearDown(interceptor.dispose);
      var emissions = 0;
      final sub = interceptor.sessionExpiredStream.listen((_) => emissions++);
      addTearDown(sub.cancel);

      await expectLater(
        dio.get<dynamic>('/sync/pull'),
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.unknown)
            .having((e) => e.response?.statusCode, 'statusCode', isNot(401))),
        reason: '200 mà không đọc được token thì không kết luận gì về phiên; '
            'mã cũ coi null là làm mới thất bại và xoá token.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions, 0);
      expect(await storage.read(key: AppConstants.accessTokenKey), 'token-cu');
      expect(await storage.read(key: AppConstants.refreshTokenKey), 'refresh-cu');
      expect(server.refreshCalls, 1);
    });
  });

  group('§3.8 điểm 2 — nhiều 401 cùng lúc chỉ làm mới một lần', () {
    test('hai request cùng nhận 401 → /auth/refresh gọi đúng một lần, cả hai thử lại bằng token mới',
        () async {
      final storage = _khoCoPhien();
      final server = _MayChuGia()..khoaRefresh = Completer<void>();
      final (:dio, :interceptor) = _dungVoiMayChu(storage, server);
      addTearDown(interceptor.dispose);

      final a = dio.get<dynamic>('/sync/pull');
      final b = dio.get<dynamic>('/auth/profile');
      // Cả hai 401 đã vào onError và đang chờ lượt làm mới.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      server.khoaRefresh!.complete();
      final ketQua = await Future.wait([a, b]);

      expect(ketQua.map((r) => r.statusCode), [200, 200]);
      expect(server.refreshCalls, 1,
          reason: 'Lượt thứ hai gửi đúng refresh token đã bị thu hồi ở lượt đầu '
              '→ Token Reuse Detection (auth.service.js:380-389) thu hồi MỌI '
              'token của tài khoản, kể cả cặp vừa cấp, và app đăng xuất.');
      expect(server.bearerDaThay.where((h) => h == 'Bearer access-moi').length, 2,
          reason: 'cả hai request được thử lại bằng token mới');
      expect(await storage.read(key: AppConstants.accessTokenKey), 'access-moi');
    });

    test('lượt làm mới chung trả 401 → cả hai nhận lỗi, tín hiệu phát đúng một lần', () async {
      final storage = _khoCoPhien();
      final server = _MayChuGia()
        ..khoaRefresh = Completer<void>()
        ..kichBanRefresh.addAll([401, 401]);
      final (:dio, :interceptor) = _dungVoiMayChu(storage, server);
      addTearDown(interceptor.dispose);
      var emissions = 0;
      final sub = interceptor.sessionExpiredStream.listen((_) => emissions++);
      addTearDown(sub.cancel);

      final a = dio.get<dynamic>('/sync/pull');
      final b = dio.get<dynamic>('/auth/profile');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      server.khoaRefresh!.complete();

      await expectLater(a, throwsA(isA<DioException>()));
      await expectLater(b, throwsA(isA<DioException>()));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(server.refreshCalls, 1);
      expect(emissions, 1,
          reason: 'xoá token và phát tín hiệu nằm trong lượt làm mới chung; '
              'để từng request chờ tự xoá thì N request phát N lần');
      expect(storage.isEmpty, isTrue);
    });

    test('401 tới sau khi lượt làm mới đã xong (request gửi bằng token cũ) → không gọi refresh, thử lại bằng token hiện có',
        () async {
      final storage = _khoCoPhien();
      final server = _MayChuGia()
        ..duongDanBiKhoa = '/goals'
        ..khoaDuongDan = Completer<void>();
      final (:dio, :interceptor) = _dungVoiMayChu(storage, server);
      addTearDown(interceptor.dispose);

      // /goals đi ra với token cũ và bị máy chủ giả giữ lại...
      final muon = dio.get<dynamic>('/goals');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // ...trong lúc đó /sync/pull nhận 401, làm mới xong, kho đã có token mới.
      await dio.get<dynamic>('/sync/pull');
      expect(server.refreshCalls, 1);
      // Giờ /goals mới được trả lời: 401 vì nó mang token cũ.
      server.khoaDuongDan!.complete();
      final res = await muon;

      expect(res.statusCode, 200);
      expect(server.refreshCalls, 1,
          reason: 'token của request này đã bị lượt làm mới trước thay rồi — '
              'chỉ thử lại bằng token trong kho, không tốn thêm một lượt '
              '/auth/refresh (mỗi lượt thu hồi refresh token cũ)');
      expect(server.bearerDaThay.last, 'Bearer access-moi');
    });

    test('kho token ném lỗi khi đọc refresh token → mọi request chờ đều nhận lỗi tạm thời, không treo, giữ token', () async {
      final storage = _khoCoPhien()..khoaNemLoiKhiDoc = AppConstants.refreshTokenKey;
      final server = _MayChuGia();
      final (:dio, :interceptor) = _dungVoiMayChu(storage, server);
      addTearDown(interceptor.dispose);
      var emissions = 0;
      final sub = interceptor.sessionExpiredStream.listen((_) => emissions++);
      addTearDown(sub.cancel);

      final a = dio.get<dynamic>('/sync/pull');
      final b = dio.get<dynamic>('/auth/profile');
      for (final f in [a, b]) {
        await expectLater(
          f.timeout(const Duration(seconds: 3)),
          throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.unknown)),
          reason: 'Lỗi kho token không nói gì về phiên; future dùng chung không được '
              'ném lỗi thô ra cho N request đang chờ.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions, 0);
      expect(await storage.read(key: AppConstants.accessTokenKey), 'token-cu');
      expect(server.refreshCalls, 0, reason: 'chưa đọc được refresh token thì không gọi /auth/refresh');
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
