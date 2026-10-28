/// `SyncEngine.keoLaiToanBo` (gia đình — spec 2026-10-23 mục 4.3): vào nhà là vào một phạm vi dữ liệu mà mốc kéo tăng
/// dần đã vượt qua — dữ liệu cũ của nhà mang `Server_update_at` dưới mốc, pull thường KHÔNG BAO GIỜ mang chúng về.
///
/// Ba chốt, cả ba hỏng im lặng: (1) mốc trong RAM cũng phải bỏ — chỉ xoá kho thì lượt kế vẫn đi theo RAM; (2) lượt đang
/// chạy lúc yêu cầu tới KHÔNG được ghi mốc (mốc của nó không chứa phạm vi mới); (3) lượt hỏng không xoá yêu cầu.
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
import 'package:flowmoney/core/sync/sync_checkpoint_store.dart';
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

class _FakeStore implements SyncCheckpointStore {
  final Map<int, DateTime> values = {};

  @override
  Future<DateTime?> read(int idaccount) async => values[idaccount];
  @override
  Future<void> write(int idaccount, DateTime value) async => values[idaccount] = value;
  @override
  Future<void> clear(int idaccount) async => values.remove(idaccount);
}

class _Client implements DioClient {
  _Client() {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
  final _Adapter adapter = _Adapter();
}

class _Adapter implements HttpClientAdapter {
  Map<String, dynamic> pullData = const {};
  final sinces = <String?>[];
  bool loiPull = false;

  /// Số lần hỏi `/sync/pull` — đếm ở ĐẦU `fetch`, trước nhánh hỏng, nên lượt hỏng cũng được đếm.
  int soLanHoiKeo = 0;

  /// Khác `null` → lượt kéo dừng ở đây (SAU khi ghi `since`) cho tới khi hoàn thành.
  Completer<void>? giu;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/pull')) {
      soLanHoiKeo++;
      if (loiPull) return ResponseBody.fromString('{}', 500);
      sinces.add(o.queryParameters['since']?.toString());
      final g = giu;
      if (g != null) await g.future;
      return ResponseBody.fromString(jsonEncode({'success': true, 'data': pullData}), 200, headers: {
        Headers.contentTypeHeader: ['application/json']
      });
    }
    if (o.path.contains('/sync/push')) {
      final ops = (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
          jsonEncode({
            'status': 'success',
            'results': ops.map((op) => {'localId': op['localId'], 'status': 'synced'}).toList(),
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

void main() {
  const accountId = 7;
  const tuDau = '1970-01-01T00:00:00.000Z';
  late AppDatabase db;
  late _Client client;
  late _FakeStore store;
  late SyncEngine engine;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Client();
    store = _FakeStore()..values[accountId] = DateTime.utc(2026, 10, 1);
    engine = taoSyncEngineThu(dioClient: client, db: db, connectivity: _Online(), checkpointStore: store);
    // CSDL không rỗng — đường ép kéo toàn bộ "máy trống" không che phép thử.
    await db.walletDao.insert(WalletsCompanion(
      id: const Value('11111111-1111-4111-8111-111111111111'),
      idaccount: const Value(accountId),
      name: const Value('Ví'),
      syncStatus: const Value('synced'),
      updatedAt: Value(DateTime.now()),
    ));
  });
  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  Future<void> batDau() async {
    final done = engine.statusStream.where((s) => s.isTerminal).first;
    engine.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));
  }

  /// Chờ tới khi `/sync/pull` đã được hỏi [n] lần (kể cả lần hỏng) — đừng ngủ một khoảng cố định: máy chậm là ca xanh
  /// vì lượt bù CHƯA chạy, không phải vì nó đúng.
  Future<void> choSoLanHoiKeo(int n) async {
    for (var i = 0; i < 500 && client.adapter.soLanHoiKeo < n; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(client.adapter.soLanHoiKeo, greaterThanOrEqualTo(n), reason: 'không thấy lượt hỏi kéo thứ $n');
    await Future<void>.delayed(const Duration(milliseconds: 20)); // lượt ấy chạy nốt phần sau lời gọi mạng
  }

  test('sau keoLaiToanBo lượt kéo kế đi từ 1970 và mốc đã lưu bị xoá ngay', () async {
    await batDau();
    expect(client.adapter.sinces.single, '2026-10-01T00:00:00.000Z', reason: 'tiền đề: pull tăng dần từ mốc đã lưu');

    await engine.keoLaiToanBo(accountId);

    expect(client.adapter.sinces.last, tuDau,
        reason: 'chỉ xoá kho thì lượt kế vẫn đi theo mốc RAM — dữ liệu cũ của nhà không bao giờ về');
    expect(store.values.containsKey(accountId), isFalse,
        reason: 'lượt kéo không có dữ liệu thì không ghi mốc; app bị giết giữa chừng vẫn kéo toàn bộ ở lần mở sau');
  });

  test('sau lượt kéo toàn bộ thành công, lượt sau lại tăng dần', () async {
    await batDau();
    client.adapter.pullData = {
      'wallets': [
        {
          'idwallet': '99999999-9999-4999-8999-999999999999',
          'idaccount': accountId,
          'name': 'Ví 2',
          'balance': 0,
          'update_at': '2026-10-20T10:00:00.000Z'
        },
      ],
    };
    await engine.keoLaiToanBo(accountId);
    expect(client.adapter.sinces.last, tuDau);

    await engine.syncNow();

    expect(client.adapter.sinces.last, isNot(tuDau), reason: 'yêu cầu đã được thoả — kéo toàn bộ MỖI lượt là tốn mạng');
  });

  test('⚠️ yêu cầu tới GIỮA một lượt đang chạy: lượt ấy không ghi mốc, yêu cầu sống qua lượt hỏng', () async {
    await batDau();
    client.adapter.pullData = {
      'wallets': [
        {
          'idwallet': '99999999-9999-4999-8999-999999999999',
          'idaccount': accountId,
          'name': 'Ví 2',
          'balance': 0,
          'update_at': '2026-10-20T10:00:00.000Z'
        },
      ],
    };
    client.adapter.giu = Completer<void>();
    final dangChay = engine.syncNow(); // lượt 2 — dừng giữa lượt kéo
    await choSoLanHoiKeo(2);

    final yeuCau = engine.keoLaiToanBo(accountId); // vào nhà lúc lượt 2 đang chạy
    await Future<void>.delayed(Duration.zero);
    client.adapter.loiPull = true; // lượt bù kế tiếp hỏng
    client.adapter.giu!.complete();
    client.adapter.giu = null;
    await dangChay;
    await yeuCau;
    await choSoLanHoiKeo(3); // lượt bù (unawaited) đã hỏi kéo — và hỏng

    expect(store.values.containsKey(accountId), isFalse,
        reason:
            'lượt 2 bắt đầu TRƯỚC yêu cầu — mốc của nó không chứa phạm vi mới; ghi nó là lần mở app sau kéo tăng dần');

    client.adapter.loiPull = false;
    await engine.syncNow();
    expect(client.adapter.sinces.last, tuDau, reason: 'lượt hỏng không được xoá yêu cầu');
  });
}
