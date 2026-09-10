/// Kéo về mục tiêu mang `Priority = 0` thì lưu là chưa sắp — G32.
///
/// Vì sao cần: backend gọi `Number(null)` nên mục tiêu CHƯA sắp được lưu là `0`.
/// Kéo về y nguyên thì SQLite giữ `0`, và `0` đứng trước mọi số đã sắp — mục
/// tiêu chưa sắp nhảy lên đầu danh sách trên mọi máy. Đã tái hiện đầu-cuối trên
/// máy ảo ngày 2026-09-10
/// (`docs/superpowers/backend/CAN-LAM/GOAL_PRIORITY_NULL_TO_ZERO.md`).
///
/// Canh ở tầng LƯU chứ không chỉ ở tầng đọc (`GoalEntity.fromDrift`): SQLite là
/// thứ được đẩy lại lên server, và là thứ mọi truy vấn trần đọc thẳng.
library;

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/core/sync/sync_models.dart';

class _Online implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
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

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': ops
              .map((op) => {'localId': op['localId'], 'status': 'synced'})
              .toList(),
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(jsonEncode({'data': pullData}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const accountId = 7;
  const moc = '2026-09-10T10:58:09.000Z';
  const chuaSapBiEp = '11111111-1111-4111-8111-111111111111';
  const daSap = '22222222-2222-4222-8222-222222222222';
  const chuaSap = '33333333-3333-4333-8333-333333333333';

  late AppDatabase db;
  late _Client client;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Client();
    engine = SyncEngine(dioClient: client, db: db, connectivity: _Online());
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  Future<void> runSync() async {
    final done = engine.statusStream.where((s) => s.isTerminal).first;
    engine.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));
  }

  Map<String, dynamic> mucTieu(String id, Object? uuTien) => {
        'idgoal': id,
        'idaccount': accountId,
        'name': 'Mục tiêu $id',
        'target_amount': 1000000,
        'target_date': moc,
        'priority': uuTien,
        'update_at': moc,
      };

  test('Priority = 0 từ server thì lưu NULL, số dương thì giữ nguyên',
      () async {
    client.adapter.pullData = {
      'goals': [
        mucTieu(chuaSapBiEp, 0),
        mucTieu(daSap, 150),
        mucTieu(chuaSap, null),
      ],
    };
    await runSync();

    final uuTienTheoId = {
      for (final g in await db.select(db.goals).get()) g.id: g.priority,
    };

    expect(uuTienTheoId.keys, containsAll([chuaSapBiEp, daSap, chuaSap]),
        reason: 'Cả ba mục tiêu phải được kéo về — thiếu hàng nào là ca test '
            'đang canh sai chỗ.');
    expect(uuTienTheoId[chuaSapBiEp], isNull,
        reason: 'Server lưu 0 cho mục tiêu chưa sắp vì `Number(null)`. Lưu 0 '
            'xuống SQLite là mục tiêu ấy đứng ĐẦU danh sách, và lần sửa kế tiếp '
            'đẩy lại 0 lên server.');
    expect(uuTienTheoId[daSap], 150,
        reason: 'Số dương là thứ người dùng đã sắp bằng kéo thả — phải giữ '
            'nguyên.');
    expect(uuTienTheoId[chuaSap], isNull);
  });
}
