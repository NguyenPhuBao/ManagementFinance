/// Hai chỗ trong `AuthInterceptor` nhận body 401 mang mã trạng thái tài khoản
/// (spec cưỡng chế đăng xuất §3.3). Cả hai làm cùng một việc: phát
/// `taiKhoanBiTuChoi`, xoá token **không** phát `sessionExpiredStream`, rồi trả
/// lỗi gốc cho nơi gọi.
///
/// Vì sao không được phát `sessionExpiredStream`: server thu hồi refresh token
/// TRƯỚC khi trả mã này (`auth.service.js:411`). Một lượt đăng xuất trơn chạy
/// đua với hộp thoại "Tài khoản đã bị xoá" thì người dùng chỉ thấy màn Đăng
/// nhập trống, không biết vì sao mình bị đá ra.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/interceptors/auth_interceptor.dart';
import 'package:flowmoney/core/auth/buoc_dang_xuat.dart';
import 'package:flowmoney/core/constants/app_constants.dart';

/// Kho token trong RAM. Cùng khuôn với `auth_interceptor_test.dart`.
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

  bool get rong => _store.isEmpty;
  String? operator [](String key) => _store[key];

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Body 401 thật của `authenticate` khi tài khoản hỏng
/// (`ResponseHandler.unauthorized(res, message, extra)` — mã ở CẤP GỐC).
String _bodyCoMa(String ma, {int idaccount = 11, String? cau}) => '''
{"success":false,
 "message":"${cau ?? 'Tài khoản của bạn đã bị vô hiệu hóa. Lý do: Vi phạm điều khoản.'}",
 "code":"$ma",
 "idaccount":$idaccount,
 "reason_inactive":null,
 "errors":null}''';

/// Body 401 thật khi access token chỉ hết hạn — đi qua
/// `ResponseHandler.error(res, msg, 401)`, KHÔNG có `code` ở cấp gốc.
const _bodyHetHan =
    '{"success":false,"message":"Token expired","errors":null,"timestamp":"x"}';

class _MayChuGia implements HttpClientAdapter {
  static const tokenMoi = 'access-moi';

  // ── /auth/refresh ────────────────────────────────────────────────────────
  int soLanGoiLamMoi = 0;
  int maLamMoi = 200;
  String? bodyLamMoi;
  DioExceptionType? loiMangKhiLamMoi;
  Completer<void>? khoaLamMoi;

  // ── request thường ───────────────────────────────────────────────────────
  String bodyRequestThuong = _bodyHetHan;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/auth/refresh')) {
      soLanGoiLamMoi++;
      if (khoaLamMoi != null) await khoaLamMoi!.future;
      if (loiMangKhiLamMoi != null) {
        throw DioException(
          requestOptions: options,
          type: loiMangKhiLamMoi!,
          message: 'giả: ${loiMangKhiLamMoi!.name}',
        );
      }
      if (maLamMoi == 200) {
        return _json(
          '{"success":true,"data":{"accessToken":"$tokenMoi",'
          '"refreshToken":"refresh-moi"}}',
          200,
        );
      }
      return _json(bodyLamMoi ?? '{"success":false}', maLamMoi);
    }

    final bearer = options.headers['Authorization'] as String?;
    if (bearer == 'Bearer $tokenMoi') {
      return _json('{"success":true,"data":{}}', 200);
    }
    return _json(bodyRequestThuong, 401);
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

({Dio dio, AuthInterceptor interceptor}) _dung(
  _FakeSecureStorage kho,
  _MayChuGia mayChu,
) {
  const base = 'http://localhost:3000/api';
  final dioLamMoi = Dio(BaseOptions(baseUrl: base))..httpClientAdapter = mayChu;
  final interceptor = AuthInterceptor(secureStorage: kho, dioLamMoi: dioLamMoi);
  final dio = Dio(BaseOptions(baseUrl: base))
    ..httpClientAdapter = mayChu
    ..interceptors.add(interceptor);
  return (dio: dio, interceptor: interceptor);
}

_FakeSecureStorage _khoCoPhien() => _FakeSecureStorage({
      AppConstants.accessTokenKey: 'token-cu',
      AppConstants.refreshTokenKey: 'refresh-cu',
    });

void main() {
  late _FakeSecureStorage kho;
  late _MayChuGia mayChu;

  setUp(() {
    kho = _khoCoPhien();
    mayChu = _MayChuGia();
  });

  // ─── §3.3 chỗ 1: 401 của một request thường ────────────────────────────
  group('401 của request thường', () {
    test('có code ACCOUNT_INACTIVE → KHÔNG gọi /auth/refresh, phát thông báo, '
        'xoá token trong im lặng', () async {
      mayChu.bodyRequestThuong = _bodyCoMa('ACCOUNT_INACTIVE');
      final (:dio, :interceptor) = _dung(kho, mayChu);
      addTearDown(interceptor.dispose);

      final nhan = <ThongBaoBuocDangXuat>[];
      interceptor.taiKhoanBiTuChoi.listen(nhan.add);
      var soTinHieuPhienChet = 0;
      interceptor.sessionExpiredStream.listen((_) => soTinHieuPhienChet++);

      await expectLater(
        dio.get<dynamic>('/sync/pull'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', 401)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(mayChu.soLanGoiLamMoi, 0,
          reason: 'server đã thu hồi refresh token rồi; làm mới lúc này chỉ vấp '
              'Token Reuse Detection và nhận về một 401 KHÔNG mã');
      expect(nhan, hasLength(1));
      expect(nhan.single.lyDo, LyDoBuocDangXuat.biKhoa);
      expect(nhan.single.nguon, NguonBuocDangXuat.http);
      expect(nhan.single.idaccount, 11);
      expect(kho.rong, isTrue, reason: 'token đã bị server thu hồi');
      expect(soTinHieuPhienChet, 0,
          reason: 'một lượt đăng xuất trơn chạy đua với hộp thoại có lý do thì '
              'người dùng chỉ thấy màn Đăng nhập trống');
    });

    test('có code ACCOUNT_DELETED → lyDo daXoa', () async {
      mayChu.bodyRequestThuong = _bodyCoMa('ACCOUNT_DELETED',
          cau: 'Account no longer exists or has been deleted');
      final (:dio, :interceptor) = _dung(kho, mayChu);
      addTearDown(interceptor.dispose);

      final cho = interceptor.taiKhoanBiTuChoi.first
          .timeout(const Duration(seconds: 3));
      await expectLater(
          dio.get<dynamic>('/sync/pull'), throwsA(isA<DioException>()));

      final tb = await cho;
      expect(tb.lyDo, LyDoBuocDangXuat.daXoa);
      expect(tb.loiNhan, contains('no longer exists'));
    });

    test('KHÔNG có code (token hết hạn thật) → đi đường làm mới như cũ',
        () async {
      final (:dio, :interceptor) = _dung(kho, mayChu);
      addTearDown(interceptor.dispose);

      final nhan = <ThongBaoBuocDangXuat>[];
      interceptor.taiKhoanBiTuChoi.listen(nhan.add);

      final res = await dio.get<dynamic>('/sync/pull');
      await Future<void>.delayed(Duration.zero);

      expect(res.statusCode, 200, reason: 'thử lại bằng token mới phải thành công');
      expect(mayChu.soLanGoiLamMoi, 1);
      expect(nhan, isEmpty,
          reason: 'đọc 401 hết hạn thành "bị khoá" là đá người dùng ra mỗi lần '
              'access token hết hạn');
      expect(kho[AppConstants.accessTokenKey], _MayChuGia.tokenMoi);
    });

    test('code nằm dưới errors → vẫn đi đường làm mới', () async {
      mayChu.bodyRequestThuong =
          '{"success":false,"message":"x","errors":{"code":"ACCOUNT_DELETED"}}';
      final (:dio, :interceptor) = _dung(kho, mayChu);
      addTearDown(interceptor.dispose);

      final nhan = <ThongBaoBuocDangXuat>[];
      interceptor.taiKhoanBiTuChoi.listen(nhan.add);

      await dio.get<dynamic>('/sync/pull');
      await Future<void>.delayed(Duration.zero);

      expect(mayChu.soLanGoiLamMoi, 1);
      expect(nhan, isEmpty,
          reason: 'AUTH_401_BODY_CODE.md đã bác hình dạng này');
    });
  });

  // ─── §3.3 chỗ 2: 401 của chính /auth/refresh ──────────────────────────
  group('401 của /auth/refresh', () {
    test('có code → phát thông báo nguồn lamMoi, xoá token, KHÔNG phát '
        'sessionExpiredStream', () async {
      mayChu
        ..maLamMoi = 401
        ..bodyLamMoi = _bodyCoMa('ACCOUNT_DELETED');
      final (:dio, :interceptor) = _dung(kho, mayChu);
      addTearDown(interceptor.dispose);

      final nhan = <ThongBaoBuocDangXuat>[];
      interceptor.taiKhoanBiTuChoi.listen(nhan.add);
      var soTinHieuPhienChet = 0;
      interceptor.sessionExpiredStream.listen((_) => soTinHieuPhienChet++);

      await expectLater(
          dio.get<dynamic>('/sync/pull'), throwsA(isA<DioException>()));
      await Future<void>.delayed(Duration.zero);

      expect(mayChu.soLanGoiLamMoi, 1);
      expect(nhan, hasLength(1));
      expect(nhan.single.nguon, NguonBuocDangXuat.lamMoi,
          reason: 'bước dọn SQLite của §3.6b bỏ qua đúng nguồn này — lỗi lược '
              'đồ phía server còn đội lốt được ACCOUNT_DELETED ở đây');
      expect(nhan.single.lyDo, LyDoBuocDangXuat.daXoa);
      expect(kho.rong, isTrue);
      expect(soTinHieuPhienChet, 0);
    });

    test('KHÔNG có code → đường cũ: xoá token và PHÁT sessionExpiredStream',
        () async {
      mayChu
        ..maLamMoi = 401
        ..bodyLamMoi = _bodyHetHan;
      final (:dio, :interceptor) = _dung(kho, mayChu);
      addTearDown(interceptor.dispose);

      final nhan = <ThongBaoBuocDangXuat>[];
      interceptor.taiKhoanBiTuChoi.listen(nhan.add);
      final tinHieu = interceptor.sessionExpiredStream.first
          .timeout(const Duration(seconds: 3));

      await expectLater(
          dio.get<dynamic>('/sync/pull'), throwsA(isA<DioException>()));

      await expectLater(tinHieu, completes,
          reason: 'đây vẫn là G12: không ai báo thì app quay vòng '
              '401 → refresh → xoá token trong im lặng');
      expect(nhan, isEmpty);
      expect(kho.rong, isTrue);
    });

    test('trả 400 có code VALIDATION_ERROR → KHÔNG đọc thành bị khoá', () async {
      mayChu
        ..maLamMoi = 400
        ..bodyLamMoi =
            '{"success":false,"message":"Thiếu refreshToken","code":"VALIDATION_ERROR"}';
      final (:dio, :interceptor) = _dung(kho, mayChu);
      addTearDown(interceptor.dispose);

      final nhan = <ThongBaoBuocDangXuat>[];
      interceptor.taiKhoanBiTuChoi.listen(nhan.add);
      final tinHieu = interceptor.sessionExpiredStream.first
          .timeout(const Duration(seconds: 3));

      await expectLater(
          dio.get<dynamic>('/sync/pull'), throwsA(isA<DioException>()));

      expect(nhan, isEmpty,
          reason: 'body 400 của repo này cũng mang code; đọc nó ở đây là hiện '
              'hộp thoại "Tài khoản đã bị vô hiệu hoá" cho một lỗi nhập liệu');
      await expectLater(tinHieu, completes,
          reason: '400 vẫn là phiên chết theo §3.8, chỉ là không có lý do');
    });

    test('hỏng vì mất mạng → không phát gì cả, giữ nguyên hai token', () async {
      mayChu.loiMangKhiLamMoi = DioExceptionType.connectionError;
      final (:dio, :interceptor) = _dung(kho, mayChu);
      addTearDown(interceptor.dispose);

      final nhan = <ThongBaoBuocDangXuat>[];
      interceptor.taiKhoanBiTuChoi.listen(nhan.add);
      var soTinHieuPhienChet = 0;
      interceptor.sessionExpiredStream.listen((_) => soTinHieuPhienChet++);

      await expectLater(
          dio.get<dynamic>('/sync/pull'), throwsA(isA<DioException>()));
      await Future<void>.delayed(Duration.zero);

      expect(nhan, isEmpty);
      expect(soTinHieuPhienChet, 0, reason: 'cam kết offline-first, §3.8 điểm 1');
      expect(kho[AppConstants.accessTokenKey], 'token-cu');
      expect(kho[AppConstants.refreshTokenKey], 'refresh-cu');
    });

    test('hai request cùng nhận 401, lượt làm mới chung trả 401 có code → '
        'thông báo phát ĐÚNG MỘT lần', () async {
      mayChu
        ..maLamMoi = 401
        ..bodyLamMoi = _bodyCoMa('ACCOUNT_INACTIVE')
        ..khoaLamMoi = Completer<void>();
      final (:dio, :interceptor) = _dung(kho, mayChu);
      addTearDown(interceptor.dispose);

      final nhan = <ThongBaoBuocDangXuat>[];
      interceptor.taiKhoanBiTuChoi.listen(nhan.add);

      final a = dio.get<dynamic>('/sync/pull');
      final b = dio.get<dynamic>('/wallets');
      await Future<void>.delayed(Duration.zero);
      mayChu.khoaLamMoi!.complete();

      await expectLater(a, throwsA(isA<DioException>()));
      await expectLater(b, throwsA(isA<DioException>()));
      await Future<void>.delayed(Duration.zero);

      expect(mayChu.soLanGoiLamMoi, 1,
          reason: 'chốt §3.8 điểm 2 phải còn nguyên');
      expect(nhan, hasLength(1),
          reason: 'N request chờ chung một lượt làm mới mà phát N lần là N hộp '
              'thoại chồng lên nhau');
    });
  });
}
