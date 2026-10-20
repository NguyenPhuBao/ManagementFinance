/// Màn Đăng nhập khi máy chủ chặn (spec G89 mục 4.3): câu của client, không phải câu admin gõ.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/auth/data/datasources/auth_remote_data_source.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body, {this.them = const {}});
  final int status;
  final Object body;
  final Map<String, List<String>> them;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...them,
      });

  @override
  void close({bool force = false}) {}
}

void main() {
  final bayGio = DateTime(2026, 10, 20, 10, 0);

  AuthRemoteDataSourceImpl ds(_Adapter a) => AuthRemoteDataSourceImpl(
      dio: Dio(BaseOptions(baseUrl: 'http://x/api'))..httpClientAdapter = a, now: () => bayGio);

  Matcher cau(String c) => throwsA(predicate((e) => e.toString() == 'Exception: $c', c));

  test('503 MAINTENANCE_MODE → câu client, KHÔNG lộ lý do admin gõ', () async {
    final a = _Adapter(503, {
      'success': false,
      'code': 'MAINTENANCE_MODE',
      'message': 'Nâng cấp CSDL — admin Bảo'
    }, them: {
      'retry-after': ['60']
    });
    await expectLater(ds(a).login('dat', 'x'), cau('Máy chủ đang bảo trì. Thử lại sau ít phút.'));
  });

  test('503 MAINTENANCE_MODE với retry-after lặp hai giá trị → vẫn câu client, không lỗi thô', () async {
    final a = _Adapter(503, {
      'success': false,
      'code': 'MAINTENANCE_MODE'
    }, them: {
      'retry-after': ['60', '120']
    });
    await expectLater(ds(a).login('dat', 'x'), cau('Máy chủ đang bảo trì. Thử lại sau ít phút.'));
  });

  test('403 AIOPS_QUARANTINED giờ đã qua → bỏ vế "tới…"', () async {
    final a = _Adapter(403, {
      'code': 'AIOPS_QUARANTINED',
      'quarantineExpiresAt': DateTime(2026, 10, 20, 9, 0).toUtc().toIso8601String(),
    });
    await expectLater(
        ds(a).login('dat', 'x'), cau('Mạng này đang bị máy chủ tạm chặn. Thử lại sau hoặc đổi mạng (Wi-Fi ↔ 4G).'));
  });

  test('403 AIOPS_QUARANTINED có giờ → nêu giờ', () async {
    final a = _Adapter(403, {
      'code': 'AIOPS_QUARANTINED',
      'quarantineExpiresAt': DateTime(2026, 10, 20, 15, 30).toUtc().toIso8601String(),
    });
    await expectLater(ds(a).login('dat', 'x'),
        cau('Mạng này đang bị máy chủ tạm chặn tới 15:30. Thử lại sau hoặc đổi mạng (Wi-Fi ↔ 4G).'));
  });

  test('403 AIOPS_QUARANTINED không giờ → bỏ vế "tới…"', () async {
    final a = _Adapter(403, {'code': 'AIOPS_QUARANTINED', 'quarantineExpiresAt': null});
    await expectLater(
        ds(a).login('dat', 'x'), cau('Mạng này đang bị máy chủ tạm chặn. Thử lại sau hoặc đổi mạng (Wi-Fi ↔ 4G).'));
  });

  test('403 trạng thái tài khoản lúc đăng nhập → câu của server như cũ', () async {
    final a = _Adapter(403, {'success': false, 'code': 'ACCOUNT_INACTIVE', 'message': 'Tài khoản đã bị vô hiệu hoá.'});
    await expectLater(ds(a).login('dat', 'x'), cau('Tài khoản đã bị vô hiệu hoá.'));
  });

  test('401 sai mật khẩu → câu của server như cũ', () async {
    final a = _Adapter(401, {'success': false, 'message': 'Sai tên đăng nhập hoặc mật khẩu'});
    await expectLater(ds(a).login('dat', 'x'), cau('Sai tên đăng nhập hoặc mật khẩu'));
  });
}
