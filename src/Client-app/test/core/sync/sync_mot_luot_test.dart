/// `SyncEngine.syncMotLuot` — một lượt đồng bộ cho lượt nền của WorkManager (spec
/// 2026-10-10-tu-chuyen-tien-chay-nen-design.md mục 3.3).
///
/// Lượt nền KHÔNG được gọi `start()`: hàm ấy dựng hẹn giờ 15 phút và bộ nghe mạng, và chỉ `auth_bloc.dart` được gọi
/// nó (test quét thứ tư `sync_engine_start_owner_test`). Nhưng `syncNow()` một mình thì bỏ qua vì chưa có tài khoản.
library;

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';

class _Online implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Adapter implements HttpClientAdapter {
  int pull = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/pull')) {
      pull++;
      return ResponseBody.fromString(jsonEncode({'data': <String, Object>{}}), 200, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });
    }
    return ResponseBody.fromString('{}', 404);
  }

  @override
  void close({bool force = false}) {}
}

class _Client implements DioClient {
  _Client() {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
  final _Adapter adapter = _Adapter();
}

void main() {
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

  test('tiền đề: syncNow() khi chưa start thì không chạy gì', () async {
    await engine.syncNow();
    expect(client.adapter.pull, 0);
  });

  test('syncMotLuot chạy MỘT lượt cho tài khoản', () async {
    await engine.syncMotLuot(7);
    expect(client.adapter.pull, 1);
  });

  test('sau syncMotLuot không còn phiên — lượt hẹn sau đó (scheduleSync) không chạy', () async {
    await engine.syncMotLuot(7);
    engine.scheduleSync();
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(client.adapter.pull, 1,
        reason: '_currentIdaccount phải trả về như cũ — lượt nền không để lại phiên nào trong engine');
  });
}
