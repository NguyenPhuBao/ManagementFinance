/// Lượt kéo về bị máy chủ TRẢ LỜI bằng lỗi (2026-10-26, đơn 53 vế C): `SyncEngine.keoVeBiTuChoi` bật để Trang chủ hiện
/// dòng nhắc *"Chưa nhận được dữ liệu mới"* — trước đó `ApDuLieuKeoVe` nuốt lỗi và dữ liệu máy khác đứng im, không ai biết.
///
/// Người dùng chốt: MỌI lỗi máy chủ trả lời (500 có / không `code`, 4xx lạ) — trừ 401 (phiên, `AuthInterceptor` lo), 403
/// (phong toả — dòng nhắc riêng G89), 429 / 503 (bảo trì · quá tải — thoáng qua hoặc đã có dòng riêng), và mất mạng (không
/// phản hồi). Cờ KHÔNG đổi trạng thái chu kỳ: không `error` (bộ quét nổ "Đồng bộ hỏng"), không giãn cách (lượt đẩy vẫn tốt).
library;

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/ap_du_lieu_keo_ve.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import '../../helpers/sync_engine_thu.dart';

class _Online implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// `/sync/pull` trả [keo]; mọi path khác (đẩy) trả 200 rỗng.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.keo);
  ResponseBody Function(RequestOptions o) keo;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/pull')) return keo(o);
    return _json(200, {
      'success': true,
      'data': {'results': const [], 'summary': const {}}
    });
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });

class _Client implements DioClient {
  _Client(HttpClientAdapter adapter) {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
}

/// Hình dạng `sync.controller.js` `pull` (đo 2026-10-26): `DECRYPT_FAILED` có `code` ở gốc; mọi lỗi khác đi
/// `ResponseHandler.error` — 500 KHÔNG `code`.
ResponseBody _giaiMaHong(RequestOptions _) => _json(500, {
      'success': false,
      'code': 'DECRYPT_FAILED',
      'message': 'Lỗi giải mã dữ liệu hệ thống (DECRYPT_FAILED). Vui lòng thử lại sau.',
    });

ResponseBody _loi500(RequestOptions _) => _json(500, {'success': false, 'message': 'x', 'errors': null});

ResponseBody _ok(RequestOptions _) => _json(200, {'success': true, 'data': const {}});

void main() {
  const accountId = 9;
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<SyncEngine> chay(_Adapter adapter) async {
    final engine = taoSyncEngineThu(
      dioClient: _Client(adapter),
      db: db,
      connectivity: _Online(),
      now: () => DateTime(2026, 10, 26, 10, 0),
    );
    addTearDown(engine.dispose);
    await engine.start(idaccount: accountId);
    return engine;
  }

  group('bộ phân loại keoVeBiMayChuTuChoi', () {
    test('lỗi máy chủ trả lời → true', () {
      for (final s in [500, 502, 504, 400, 404, 422]) {
        expect(keoVeBiMayChuTuChoi(s), isTrue, reason: 'HTTP $s — dữ liệu máy khác không về');
      }
    });

    test('không phản hồi / thành công / bốn mã đã có đường riêng → false', () {
      expect(keoVeBiMayChuTuChoi(null), isFalse, reason: 'mất mạng: offline-first, không phải máy chủ từ chối');
      expect(keoVeBiMayChuTuChoi(200), isFalse);
      expect(keoVeBiMayChuTuChoi(401), isFalse, reason: 'phiên — AuthInterceptor làm mới / đăng xuất');
      expect(keoVeBiMayChuTuChoi(403), isFalse, reason: 'phong toả AIOps có dòng nhắc riêng (G89)');
      expect(keoVeBiMayChuTuChoi(429), isFalse, reason: 'giới hạn tần suất — thoáng qua');
      expect(keoVeBiMayChuTuChoi(503), isFalse, reason: 'bảo trì (dòng riêng) / quá tải (thoáng qua)');
    });
  });

  test('⭐ 500 DECRYPT_FAILED ở /sync/pull → cờ bật; chu kỳ KHÔNG error, KHÔNG giãn cách', () async {
    final engine = await chay(_Adapter(_giaiMaHong));
    expect(engine.keoVeBiTuChoi.value, isTrue,
        reason: 'trước bản này lỗi bị nuốt — dữ liệu máy khác đứng im, không một dấu hiệu nào trên máy');
    expect(engine.status, SyncStatus.idle,
        reason: 'error là NotificationScanner nổ "Đồng bộ hỏng" — người dùng chốt chỉ dòng nhắc Trang chủ');
    expect(engine.consecutiveFailures, 0, reason: 'lượt đẩy vẫn tốt — giãn cách là làm chậm việc đưa thay đổi lên');
    expect(engine.nextAllowedSyncAt, isNull);
  });

  test('500 KHÔNG code (ResponseHandler.error) → cũng bật (người dùng chốt: mọi lỗi máy chủ trả lời)', () async {
    final engine = await chay(_Adapter(_loi500));
    expect(engine.keoVeBiTuChoi.value, isTrue);
  });

  test('lượt kéo sau thành công → cờ tắt (dòng nhắc tự ẩn)', () async {
    final adapter = _Adapter(_giaiMaHong);
    final engine = await chay(adapter);
    expect(engine.keoVeBiTuChoi.value, isTrue);
    adapter.keo = _ok;
    await engine.syncNow();
    expect(engine.keoVeBiTuChoi.value, isFalse);
  });

  test('mất mạng giữa chừng (không phản hồi) → GIỮ nguyên cờ — chưa biết máy chủ đã hết lỗi chưa', () async {
    final adapter = _Adapter(_giaiMaHong);
    final engine = await chay(adapter);
    adapter.keo = (o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
    await engine.syncNow();
    expect(engine.keoVeBiTuChoi.value, isTrue);
  });

  test('503 / 403 / 401 / mất mạng từ đầu → cờ không bật', () async {
    for (final status in [503, 403, 401, 429]) {
      final adapter = _Adapter((_) => _json(status, {'success': false, 'message': 'x'}));
      final engine = await chay(adapter);
      expect(engine.keoVeBiTuChoi.value, isFalse, reason: 'HTTP $status');
    }
    final engine = await chay(
        _Adapter((o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError)));
    expect(engine.keoVeBiTuChoi.value, isFalse);
  });

  test('stop() (đăng xuất) → cờ tắt: phiên sau có thể là tài khoản khác', () async {
    final engine = await chay(_Adapter(_giaiMaHong));
    expect(engine.keoVeBiTuChoi.value, isTrue);
    engine.stop();
    expect(engine.keoVeBiTuChoi.value, isFalse);
  });

  test('có thao tác chờ đẩy: đẩy vẫn chạy và chu kỳ vẫn idle khi chỉ lượt kéo hỏng', () async {
    await db.categoryDao.insert(CategoriesCompanion.insert(
      id: 'fee25499-c4a9-4924-b69b-43081c563d95',
      idaccount: accountId,
      name: 'Danh mục mới',
      classify: 'chi',
      syncStatus: const Value('pending'),
      updatedAt: DateTime(2026, 9, 2),
    ));
    final engine = await chay(_Adapter(_giaiMaHong));
    expect(engine.keoVeBiTuChoi.value, isTrue);
    expect(engine.consecutiveFailures, 0);
  });
}
