/// Lượt đồng bộ bị máy chủ chặn (bảo trì / phong toả) KHÔNG bị tính là lượt hỏng, hẹn thử lại đúng mốc server cho, có sàn
/// 30 s, và kết thúc `pending` (spec G89 2026-10-20 mục 3.3). Từ 2026-10-26 thêm lượt đẩy gặp 503 QUÁ TẢI (`kMaQuaTai`):
/// cùng luật nhưng chỉ `SyncEngine.soLanQuaTaiKhongTinh` chu kỳ liên tiếp, và không đi qua `TrangThaiMayChu`.
library;

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/api/interceptors/may_chu_interceptor.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/network/trang_thai_may_chu.dart';
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

/// Trả lời mọi path bằng [traLoi]; đếm số lần gọi.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.traLoi);
  ResponseBody Function(RequestOptions o) traLoi;
  int soLanGoi = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    soLanGoi++;
    return traLoi(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body, {Map<String, List<String>> them = const {}}) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...them,
    });

/// Như Dio chung thật: request mang phiên và đi qua interceptor trạng thái máy chủ.
class _Client implements DioClient {
  _Client(HttpClientAdapter adapter, TrangThaiMayChu tt, DateTime Function() now) {
    dio.httpClientAdapter = adapter;
    dio.options.headers['Authorization'] = 'Bearer token-thu';
    dio.interceptors.add(MayChuInterceptor(trangThai: tt, now: now));
  }
  @override
  final Dio dio = Dio();
}

void main() {
  const accountId = 9;
  late AppDatabase db;
  late TrangThaiMayChu tt;
  late DateTime clock;
  DateTime now() => clock;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tt = TrangThaiMayChu();
    clock = DateTime(2026, 10, 20, 10, 0);
  });
  tearDown(() => db.close());

  Future<void> themThaoTacCho() => db.categoryDao.insert(CategoriesCompanion.insert(
        id: 'fee25499-c4a9-4924-b69b-43081c563d95',
        idaccount: accountId,
        name: 'Danh mục mới',
        classify: 'chi',
        syncStatus: const Value('pending'),
        updatedAt: DateTime(2026, 9, 2),
      ));

  ResponseBody baoTri(RequestOptions _) => _json(503, {
        'success': false,
        'code': 'MAINTENANCE_MODE',
        'message': 'x'
      }, them: {
        'retry-after': ['60']
      });

  ResponseBody phongToa(DateTime? het) => _json(403, {
        'success': false,
        'code': 'AIOPS_QUARANTINED',
        'error': 'AIOPS_QUARANTINED',
        'quarantineExpiresAt': het?.toUtc().toIso8601String(),
      });

  Future<SyncEngine> chay(_Adapter adapter, {bool coCong = true}) async {
    final engine = taoSyncEngineThu(
      dioClient: _Client(adapter, tt, now),
      db: db,
      connectivity: _Online(),
      now: now,
      trangThaiMayChu: coCong ? tt : null,
    );
    addTearDown(engine.dispose);
    // `start()` đợi trọn chu kỳ đầu; lượt bị chặn kết thúc `pending` (không `isTerminal`) nên KHÔNG chờ statusStream.
    await engine.start(idaccount: accountId);
    return engine;
  }

  test('bảo trì: đẩy + kéo 503 → không tính lượt hỏng, hẹn đúng Retry-After, kết thúc pending', () async {
    await themThaoTacCho();
    final engine = await chay(_Adapter(baoTri));
    expect(tt.value, isA<MayChuBaoTri>());
    expect(engine.consecutiveFailures, 0, reason: 'bảo trì không phải lỗi của máy này (người dùng chốt 2026-10-20)');
    expect(engine.nextAllowedSyncAt, isNull, reason: 'giãn cách chặn cả lần thử ngay khi đổi mạng');
    expect(engine.backoffRetryAt, clock.add(const Duration(seconds: 60)));
    expect(engine.status, SyncStatus.pending,
        reason: 'error là NotificationScanner nổ "Đồng bộ hỏng" cho một sự cố đã có dòng nhắc riêng');
  });

  test('không có gì để đẩy, chỉ lượt kéo 503 → vẫn hẹn (hôm nay rơi vào resetBackoff + idle)', () async {
    final engine = await chay(_Adapter(baoTri));
    expect(engine.backoffRetryAt, clock.add(const Duration(seconds: 60)));
    expect(engine.status, SyncStatus.pending);
  });

  test('bảo trì không dựng giãn cách: kích hoạt ngay sau đó vẫn gọi server (đổi mạng thử ngay)', () async {
    final adapter = _Adapter(baoTri);
    final engine = await chay(adapter);
    final truoc = adapter.soLanGoi;
    await engine.syncNow();
    expect(adapter.soLanGoi, greaterThan(truoc));
  });

  test('⭐ phong toả giờ đã QUA → hẹn bayGio + 30 s, không hẹn ngay', () async {
    final engine = await chay(_Adapter((_) => phongToa(clock.subtract(const Duration(minutes: 5)))));
    expect(engine.backoffRetryAt, clock.add(kSanThuLai),
        reason: 'mốc quá khứ → Duration.zero → vòng request dồn vào đúng IP AIOps đang nghi DoS');
  });

  test('phong toả giờ tương lai → hẹn đúng giờ ấy', () async {
    final het = clock.add(const Duration(minutes: 20));
    final engine = await chay(_Adapter((_) => phongToa(het)));
    expect(engine.backoffRetryAt!.isAtSameMomentAs(het), isTrue);
    expect(engine.consecutiveFailures, 0);
  });

  test('phong toả KHÔNG giờ → giãn cách như hôm nay', () async {
    await themThaoTacCho();
    final engine = await chay(_Adapter((_) => phongToa(null)));
    expect(engine.consecutiveFailures, 1);
    expect(engine.status, SyncStatus.error);
  });

  test('trạng thái chặn CŨ (trước chu kỳ) không được tính — lỗi mạng thường vẫn giãn cách', () async {
    await themThaoTacCho();
    tt.value = MayChuBaoTri(thuLaiLuc: clock);
    final engine = await chay(_Adapter((o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        )));
    expect(engine.consecutiveFailures, 1,
        reason: 'một 503 cũ còn sót (trợ lý online, chu kỳ trước) không được biến lỗi mạng thành hẹn 30 s mãi');
    expect(engine.backoffRetryAt, isNull);
  });

  test('không truyền cổng → hành vi y như cũ (bảo trì tính là lượt hỏng)', () async {
    await themThaoTacCho();
    final engine = await chay(_Adapter(baoTri), coCong: false);
    expect(engine.consecutiveFailures, 1);
  });

  // ── Quá tải (503 SERVER_OVERLOADED, `load-shedding.middleware.js`) — 2026-10-26 ─────────────────────────────────────
  // Server cắt tải khi event loop trễ > 250 ms (`event-loop-monitor.js:9`), `Retry-After: 5`. Trước đó lượt đẩy trúng lúc
  // ấy là chu kỳ `error` → NotificationScanner nổ "Đồng bộ hỏng" cho một sự cố vài giây. Không qua TrangThaiMayChu.

  ResponseBody quaTai(RequestOptions _, {String retryAfter = '5'}) => _json(503, {
        'success': false,
        'statusCode': 503,
        'code': 'SERVER_OVERLOADED',
        'message': 'Hệ thống đang xử lý lượng truy cập lớn. Vui lòng thử lại sau ít giây!',
        'retryAfter': 5,
      }, them: {
        'retry-after': [retryAfter]
      });

  test('⭐ quá tải lúc đẩy → không tính lượt hỏng, hẹn sàn 30 s, pending, không dòng nhắc', () async {
    await themThaoTacCho();
    final engine = await chay(_Adapter(quaTai));
    expect(engine.consecutiveFailures, 0, reason: 'vài giây quá tải không phải lỗi của máy này');
    expect(engine.nextAllowedSyncAt, isNull);
    expect(engine.backoffRetryAt, clock.add(kSanThuLai), reason: 'Retry-After 5 s — sàn 30 s');
    expect(engine.status, SyncStatus.pending, reason: 'error là "Đồng bộ hỏng" cho một sự cố thoáng qua');
    expect(tt.value, isA<MayChuBinhThuong>(), reason: 'quá tải không dựng dòng nhắc Trang chủ / toast');
  });

  test('quá tải Retry-After 90 → hẹn đúng 90 s', () async {
    await themThaoTacCho();
    final engine = await chay(_Adapter((o) => quaTai(o, retryAfter: '90')));
    expect(engine.backoffRetryAt, clock.add(const Duration(seconds: 90)));
  });

  test('quá tải KÉO DÀI: quá ${SyncEngine.soLanQuaTaiKhongTinh} lượt liên tiếp → lượt kế tính là hỏng thường', () async {
    await themThaoTacCho();
    final engine = await chay(_Adapter(quaTai));
    for (var i = 1; i < SyncEngine.soLanQuaTaiKhongTinh; i++) {
      await engine.syncNow();
    }
    expect(engine.consecutiveFailures, 0, reason: '${SyncEngine.soLanQuaTaiKhongTinh} lượt đầu chưa tính');
    expect(engine.status, SyncStatus.pending);
    await engine.syncNow();
    expect(engine.consecutiveFailures, 1,
        reason: 'server quá tải mãi là server hỏng — người dùng phải được báo "Đồng bộ hỏng", và giãn cách phải tăng');
    expect(engine.status, SyncStatus.error);
  });

  test('quá tải → 200 → quá tải: bộ đếm lượt quá tải về 0 sau lượt thành công', () async {
    await themThaoTacCho();
    final adapter = _Adapter(quaTai);
    final engine = await chay(adapter);
    for (var i = 1; i < SyncEngine.soLanQuaTaiKhongTinh; i++) {
      await engine.syncNow();
    }
    adapter.traLoi = (_) => _json(200, {'success': true, 'data': const {}});
    await engine.syncNow();
    expect(engine.status, SyncStatus.idle);
    await themThaoTacCho();
    adapter.traLoi = quaTai;
    await engine.syncNow();
    expect(engine.consecutiveFailures, 0, reason: 'đếm LIÊN TIẾP — một lượt thành công ở giữa xoá chuỗi');
    expect(engine.status, SyncStatus.pending);
  });

  test('503 KHÔNG code (lỗi lược đồ) → vẫn giãn cách như cũ', () async {
    await themThaoTacCho();
    final engine = await chay(_Adapter((_) => _json(503, {'success': false, 'message': 'x'})));
    expect(engine.consecutiveFailures, 1, reason: 'chỉ đúng mã SERVER_OVERLOADED mới được miễn');
    expect(engine.status, SyncStatus.error);
  });

  test('hết bảo trì: lượt kế 200 → bình thường, không còn hẹn, idle', () async {
    final adapter = _Adapter(baoTri);
    final engine = await chay(adapter);
    adapter.traLoi = (_) => _json(200, {'success': true, 'data': const {}});
    await engine.syncNow();
    expect(tt.value, isA<MayChuBinhThuong>());
    expect(engine.backoffRetryAt, isNull);
    expect(engine.status, SyncStatus.idle);
  });
}
