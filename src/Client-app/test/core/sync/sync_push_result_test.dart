/// `SyncEngine.pushResultStream` — kênh cho giao diện biết **vừa đẩy được bao
/// nhiêu thay đổi**.
///
/// `statusStream` chỉ nói chu kỳ kết thúc ở `idle` hay `error`, không nói được
/// "đã đưa 5 thay đổi lên server". Mà đó chính là câu người dùng cần nghe sau
/// một quãng mất mạng: họ ghi chép offline và muốn biết công sức ấy đã an toàn.
///
/// Kênh RIÊNG chứ không nhét vào `statusStream`, cùng lý do như
/// `sessionInvalidStream`: hai luồng mang hai loại thông tin khác nhau và có
/// vòng đời khác nhau.
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
  /// Bật lên để server từ chối mọi thao tác đẩy.
  bool tuChoiPush = false;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/pull')) {
      return ResponseBody.fromString(jsonEncode({'data': {}}), 200, headers: {
        Headers.contentTypeHeader: ['application/json']
      });
    }
    if (o.path.contains('/sync/push')) {
      final ops = (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': ops
              .map((op) => {
                    'localId': op['localId'],
                    'status': tuChoiPush ? 'failed' : 'synced',
                    if (tuChoiPush) 'message': 'Từ chối để kiểm thử',
                  })
              .toList(),
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString('{}', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const accountId = 7;
  late AppDatabase db;
  late _Client client;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Client();
    engine = SyncEngine(
      dioClient: client,
      db: db,
      connectivity: _Online(),
    );
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  Future<void> themViChoDay(String id) => db.walletDao.insert(WalletsCompanion(
        id: Value(id),
        idaccount: const Value(accountId),
        name: const Value('Ví offline'),
        type: const Value('cash'),
        balance: const Value(0),
        // `pending` là thứ khiến bản ghi được gom vào lần đẩy tới.
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ));

  Future<List<SyncResult>> chayVaThu() async {
    final thu = <SyncResult>[];
    final sub = engine.pushResultStream.listen(thu.add);
    final xong = engine.statusStream.where((s) => s.isTerminal).first;
    engine.start(idaccount: accountId);
    await xong.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return thu;
  }

  test('đẩy thành công thì phát số thao tác đã lên server', () async {
    await themViChoDay('11111111-1111-4111-8111-111111111111');
    await themViChoDay('22222222-2222-4222-8222-222222222222');

    final ketQua = await chayVaThu();

    expect(ketQua, isNotEmpty,
        reason: 'Không phát gì thì giao diện không có cách nào nói "đã đồng bộ '
            'N thay đổi" — nó chỉ biết chu kỳ đã kết thúc.');
    expect(ketQua.last.succeeded, 2);
    expect(ketQua.last.failed, 0);
  });

  test('không có gì chờ đẩy thì KHÔNG phát', () async {
    final ketQua = await chayVaThu();

    expect(ketQua, isEmpty,
        reason: 'Phần lớn chu kỳ đồng bộ không có gì để đẩy. Phát mọi lần là '
            'ép nơi nhận phải tự lọc, và sớm muộn sẽ có chỗ quên lọc rồi hiện '
            '"đã đồng bộ 0 thay đổi".');
  });

  test('server từ chối thì vẫn phát, kèm số thất bại', () async {
    client.adapter.tuChoiPush = true;
    await themViChoDay('33333333-3333-4333-8333-333333333333');

    final ketQua = await chayVaThu();

    expect(ketQua, isNotEmpty);
    expect(ketQua.last.failed, greaterThan(0),
        reason: 'Người dùng cần phân biệt "đã lên server" với "còn kẹt lại". '
            'Chỉ phát khi thành công là để họ tưởng dữ liệu đã an toàn.');
  });

  test('dispose rồi thì không phát thêm', () async {
    await themViChoDay('44444444-4444-4444-8444-444444444444');
    engine.dispose();

    final thu = <SyncResult>[];
    // Sau dispose, stream đã đóng — lắng nghe không được nhận gì và cũng
    // không được ném.
    final sub = engine.pushResultStream.listen(thu.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(thu, isEmpty);
  });
}
