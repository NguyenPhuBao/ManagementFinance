/// `SyncEngine.dayVaCho` — đẩy MỘT lượt rồi CHỜ thật (spec gia đình 2026-11-01 mục 7.3, trước khi Rời nhà / Giải tán).
///
/// Vì sao không dùng `syncNow()` trần: khi chu kỳ khác đang chạy, `syncNow()` chỉ ghi nợ một lượt chạy bù rồi TRẢ VỀ NGAY
/// (`sync_yeu_cau_giua_chu_ky_test`) — nơi gọi tưởng đã đẩy xong mà hàng chưa đi. `dayVaCho` phải đợi cả lượt đang chạy lẫn lượt
/// bù, và có trần để mạng treo không giữ người dùng mãi.
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart' show kTranDayTruocKhiRoi;
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

class _Offline implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.none];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Client implements DioClient {
  _Client(this.adapter) {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
  final _Adapter adapter;
}

/// Giữ các lượt `/sync/pull` có số thứ tự trong [giuLuot] cho tới khi test gọi [tha]; các lượt khác trả ngay.
class _Adapter implements HttpClientAdapter {
  _Adapter({this.giuLuot = const {1}});

  final Set<int> giuLuot;
  final Completer<void> _cho = Completer<void>();
  int soLanPull = 0;
  int soLanPush = 0;

  /// `true` thì `/sync/push` trả 500 (chu kỳ hỏng → engine giãn cách).
  bool pushLoi = false;

  void tha() {
    if (!_cho.isCompleted) _cho.complete();
  }

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/pull')) {
      soLanPull++;
      if (giuLuot.contains(soLanPull)) await _cho.future;
      return ResponseBody.fromString(jsonEncode({'data': const <String, dynamic>{}}), 200,
          headers: {Headers.contentTypeHeader: ['application/json']});
    }
    if (o.path.contains('/sync/push')) {
      soLanPush++;
      if (pushLoi) return ResponseBody.fromString('{}', 500);
      final ops = (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
          jsonEncode({
            'status': 'success',
            'results': [for (final op in ops) {'localId': op['localId'], 'status': 'synced'}],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json']
          });
    }
    return ResponseBody.fromString('{}', 404);
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _doiToiKhi(bool Function() dieuKien, {required String vi}) async {
  final han = DateTime.now().add(const Duration(seconds: 5));
  while (!dieuKien()) {
    if (DateTime.now().isAfter(han)) fail('Hết 5 giây chờ: $vi');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  const accountId = 7;
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('không chu kỳ nào đang chạy: dayVaCho chạy một lượt và chờ nó xong', () async {
    final adapter = _Adapter(giuLuot: const {});
    final engine = taoSyncEngineThu(dioClient: _Client(adapter), db: db, connectivity: _Online());
    addTearDown(engine.dispose);
    await engine.start(idaccount: accountId);
    final truoc = adapter.soLanPull;

    await engine.dayVaCho();

    expect(adapter.soLanPull, truoc + 1, reason: 'phải thật sự chạy một lượt đồng bộ');
    expect(engine.status.isTerminal, isTrue);
  });

  test('chu kỳ đang chạy: dayVaCho KHÔNG trả về ngay, và đợi cả lượt bù của chính nó', () async {
    final adapter = _Adapter();
    final engine = taoSyncEngineThu(dioClient: _Client(adapter), db: db, connectivity: _Online());
    addTearDown(() {
      adapter.tha();
      engine.dispose();
    });
    unawaited(engine.start(idaccount: accountId));
    await _doiToiKhi(() => adapter.soLanPull == 1, vi: 'chu kỳ thứ nhất đi tới /sync/pull');
    expect(engine.status, SyncStatus.syncing);

    var xong = false;
    final f = engine.dayVaCho().then((_) => xong = true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(xong, isFalse,
        reason: 'syncNow() trần trả về ngay ở đây (chỉ ghi nợ lượt bù) — dayVaCho mà trả về là hàng chưa đẩy đã bị coi là đã đẩy');

    adapter.tha();
    await f;
    expect(adapter.soLanPull, 2, reason: 'lượt bù mà yêu cầu của dayVaCho ghi nợ phải chạy XONG trước khi dayVaCho trả về');
    expect(engine.status.isTerminal, isTrue);
  });

  test('mạng treo quá trần: dayVaCho trả về đúng hạn, không treo mãi', () async {
    final adapter = _Adapter(giuLuot: const {1, 2, 3});
    final engine = taoSyncEngineThu(dioClient: _Client(adapter), db: db, connectivity: _Online());
    addTearDown(() {
      adapter.tha();
      engine.dispose();
    });
    unawaited(engine.start(idaccount: accountId));
    await _doiToiKhi(() => adapter.soLanPull == 1, vi: 'chu kỳ thứ nhất đi tới /sync/pull');

    final dongHo = Stopwatch()..start();
    await engine.dayVaCho(tran: const Duration(milliseconds: 200));

    expect(dongHo.elapsedMilliseconds, inInclusiveRange(150, 3000), reason: 'hết trần thì trả về, lượt đẩy vẫn treo');
    expect(engine.status, SyncStatus.syncing, reason: 'chứng tỏ trả về vì hết hạn chứ không phải vì đồng bộ xong');
  });

  test('đang GIÃN CÁCH sau chu kỳ hỏng: dayVaCho vẫn thật sự đẩy (người dùng chủ động, như start())', () async {
    final adapter = _Adapter(giuLuot: const {});
    adapter.pushLoi = true;
    var dongHo = DateTime(2026, 11, 1, 9);
    final engine = taoSyncEngineThu(dioClient: _Client(adapter), db: db, connectivity: _Online(), now: () => dongHo);
    addTearDown(engine.dispose);
    await db.walletDao.insert(WalletsCompanion(
        id: const Value('w1'), idaccount: const Value(accountId), name: const Value('Vi'), updatedAt: Value(dongHo)));
    await engine.start(idaccount: accountId); // chu kỳ đầu: đẩy hỏng → giãn cách
    expect(engine.nextAllowedSyncAt, isNotNull, reason: 'tiền đề: engine đang giãn cách');
    final soLanDayTruoc = adapter.soLanPush;

    adapter.pushLoi = false;
    dongHo = dongHo.add(const Duration(seconds: 5)); // vẫn trong cửa sổ giãn cách (≥ 30 s)
    await engine.dayVaCho();

    expect(adapter.soLanPush, greaterThan(soLanDayTruoc),
        reason: 'giãn cách tới 60 phút: syncNow trần chỉ hẹn lại rồi về, không đẩy gì — phép đếm sau đó thấy hàng còn và Rời nhà bị từ chối oan bằng hangChuaDay');
    expect((await db.walletDao.getById('w1'))!.syncStatus, 'synced');
  });

  // Hộp hỏi lại của Rời nhà / Giải tán (đợt 1B) dựa vào ba nhánh dưới đây: dayVaCho trả về BÌNH THƯỜNG (không ném, không treo)
  // và nơi gọi tự đếm lại hàng chưa đẩy.
  test('chưa có phiên (chưa start): dayVaCho trả về ngay, không gọi mạng', () async {
    final adapter = _Adapter(giuLuot: const {});
    final engine = taoSyncEngineThu(dioClient: _Client(adapter), db: db, connectivity: _Online());
    addTearDown(engine.dispose);

    await engine.dayVaCho();

    expect(adapter.soLanPull, 0, reason: 'chưa có phiên thì chu kỳ bỏ qua (danh tính chỉ đến từ phiên)');
    expect(adapter.soLanPush, 0);
  });

  test('mất mạng: dayVaCho trả về bình thường, không gọi mạng, trạng thái pending', () async {
    final adapter = _Adapter(giuLuot: const {});
    final engine = taoSyncEngineThu(dioClient: _Client(adapter), db: db, connectivity: _Offline());
    addTearDown(engine.dispose);
    await engine.start(idaccount: accountId);

    await engine.dayVaCho();

    expect(adapter.soLanPull, 0);
    expect(engine.status, SyncStatus.pending, reason: 'offline: hoãn, không phải lỗi');
  });

  test('engine bị dispose giữa lúc đang chờ: dayVaCho được đánh thức ngay, không chờ hết trần 30 giây', () async {
    final adapter = _Adapter();
    final engine = taoSyncEngineThu(dioClient: _Client(adapter), db: db, connectivity: _Online());
    addTearDown(adapter.tha);
    unawaited(engine.start(idaccount: accountId));
    await _doiToiKhi(() => adapter.soLanPull == 1, vi: 'chu kỳ thứ nhất đi tới /sync/pull');

    final f = engine.dayVaCho(); // trần mặc định 30 s
    await Future<void>.delayed(const Duration(milliseconds: 50));
    engine.dispose();

    await f.timeout(const Duration(seconds: 5),
        onTimeout: () => fail('dispose không đánh thức dayVaCho: Rời nhà treo tới hết trần'));
  });

  test('trần mặc định của dayVaCho là 30 giây (kTranDayTruocKhiRoi)', () {
    expect(kTranDayTruocKhiRoi, const Duration(seconds: 30));
  });
}
