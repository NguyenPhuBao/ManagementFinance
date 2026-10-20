/// `MayChuInterceptor` ghi trạng thái máy chủ từ phản hồi của Dio CHUNG (spec G89 mục 3.2) và báo làm mới gói khi
/// 403 `FEATURE_DISABLED` (mục 6.2).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/api/interceptors/auth_interceptor.dart';
import 'package:flowmoney/core/api/interceptors/may_chu_interceptor.dart';
import 'package:flowmoney/core/network/trang_thai_may_chu.dart';

class _Adapter implements HttpClientAdapter {
  int status = 200;
  Object? body = const {'success': true};
  Map<String, List<String>> them = const {};

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...them,
      });

  @override
  void close({bool force = false}) {}
}

class _KhoGia implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late TrangThaiMayChu tt;
  late _Adapter adapter;
  late DateTime clock;
  late int soLanBao;
  late Dio dio;

  setUp(() {
    tt = TrangThaiMayChu();
    adapter = _Adapter();
    clock = DateTime(2026, 10, 20, 10, 0);
    soLanBao = 0;
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000/api'))..httpClientAdapter = adapter;
    dio.interceptors.add(MayChuInterceptor(
      trangThai: tt,
      khiBiTatQuyen: () async => soLanBao++,
      now: () => clock,
    ));
  });

  /// Gọi một request; lỗi Dio nuốt lại (interceptor không được nuốt — ca riêng canh).
  Future<void> goi({bool coPhien = true}) async {
    try {
      await dio.get<dynamic>('/sync/pull', options: Options(headers: coPhien ? {'Authorization': 'Bearer t'} : null));
    } on DioException catch (_) {}
  }

  void baoTri() {
    adapter
      ..status = 503
      ..body = {'success': false, 'code': 'MAINTENANCE_MODE', 'message': 'Admin gõ'}
      ..them = {
        'retry-after': ['60']
      };
  }

  test('503 bảo trì trên request mang phiên → ghi MayChuBaoTri', () async {
    baoTri();
    await goi();
    expect(tt.value, isA<MayChuBaoTri>());
    expect((tt.value as MayChuBaoTri).thuLaiLuc, clock.add(const Duration(seconds: 60)));
  });

  test('request KHÔNG mang phiên (đăng nhập, đăng ký) → không ghi', () async {
    baoTri();
    await goi(coPhien: false);
    expect(tt.value, isA<MayChuBinhThuong>(),
        reason: 'màn Đăng nhập tự nói lỗi (spec 4.3) — ghi ở đây là toast "Chưa đồng bộ được…" chồng lên câu ấy');
  });

  test('2xx mang phiên → về bình thường (dòng nhắc tự ẩn)', () async {
    baoTri();
    await goi();
    adapter
      ..status = 200
      ..body = const {'success': true}
      ..them = const {};
    await goi();
    expect(tt.value, isA<MayChuBinhThuong>());
  });

  test('lỗi không phân loại được (503 không code, 500) → GIỮ trạng thái đang có', () async {
    baoTri();
    await goi();
    final truoc = tt.value;
    adapter
      ..status = 503
      ..body = const {'message': 'Service Unavailable'}
      ..them = const {};
    await goi();
    adapter.status = 500;
    await goi();
    expect(identical(tt.value, truoc), isTrue);
  });

  test('403 phong toả → MayChuPhongToa có giờ', () async {
    final het = DateTime(2026, 10, 20, 15, 30);
    adapter
      ..status = 403
      ..body = {'code': 'AIOPS_QUARANTINED', 'quarantineExpiresAt': het.toUtc().toIso8601String()};
    await goi();
    expect(tt.value, isA<MayChuPhongToa>());
    expect((tt.value as MayChuPhongToa).hetHanLuc!.isAtSameMomentAs(het), isTrue);
  });

  test('interceptor KHÔNG nuốt lỗi: nơi gọi vẫn nhận DioException 503', () async {
    baoTri();
    await expectLater(
      dio.get<dynamic>('/sync/pull', options: Options(headers: {'Authorization': 'Bearer t'})),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 503)),
    );
  });

  test('403 FEATURE_DISABLED → báo làm mới gói, giãn ≥ 30 s, không đụng trạng thái máy chủ', () async {
    adapter
      ..status = 403
      ..body = const {'code': 'FEATURE_DISABLED', 'featureId': 'ai_assistant', 'accountType': 'Basic'};
    await goi();
    expect(soLanBao, 1);
    clock = clock.add(const Duration(seconds: 29));
    await goi();
    expect(soLanBao, 1, reason: 'mỗi lần báo là một GET /payment/subscription-info — không dội theo từng request');
    clock = clock.add(const Duration(seconds: 1));
    await goi();
    expect(soLanBao, 2);
    expect(tt.value, isA<MayChuBinhThuong>());
  });

  test('Retry-After hai giá trị → nơi gọi vẫn nhận DioException 503 gốc, và trạng thái vẫn ghi', () async {
    baoTri();
    adapter.them = {
      'retry-after': ['60', '120']
    };
    await expectLater(
      dio.get<dynamic>('/sync/pull', options: Options(headers: {'Authorization': 'Bearer t'})),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 503)),
    );
    expect(tt.value, isA<MayChuBaoTri>());
  });

  test('hook khiBiTatQuyen ném ĐỒNG BỘ → nơi gọi vẫn nhận DioException 403 gốc', () async {
    final d = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000/api'))
      ..httpClientAdapter = adapter
      ..interceptors.add(MayChuInterceptor(
        trangThai: tt,
        khiBiTatQuyen: () => throw StateError('x'),
        now: () => clock,
      ));
    adapter
      ..status = 403
      ..body = const {'code': 'FEATURE_DISABLED'};
    await expectLater(
      d.get<dynamic>('/sync/pull', options: Options(headers: {'Authorization': 'Bearer t'})),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 403)),
    );
  });

  test('DioClient gắn MayChuInterceptor SAU AuthInterceptor; không truyền trạng thái thì không gắn', () {
    final auth = AuthInterceptor(secureStorage: _KhoGia());
    final co = DioClient(secureStorage: _KhoGia(), authInterceptor: auth, trangThaiMayChu: tt).dio.interceptors;
    final iAuth = co.indexWhere((i) => i is AuthInterceptor);
    final iMayChu = co.indexWhere((i) => i is MayChuInterceptor);
    expect(iAuth, isNonNegative);
    expect(iMayChu, greaterThan(iAuth),
        reason:
            '503 của /auth/refresh (Dio riêng) chỉ tới được interceptor này qua lỗi AuthInterceptor chép sang request gốc');

    final khong = DioClient(secureStorage: _KhoGia(), authInterceptor: auth).dio.interceptors;
    expect(khong.whereType<MayChuInterceptor>(), isEmpty);
  });
}
