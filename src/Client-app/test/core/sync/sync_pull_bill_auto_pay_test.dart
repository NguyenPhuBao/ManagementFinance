/// Pull `auto_pay` của hoá đơn — cùng luật với `anchor_day` và `period_end`.
///
/// Server im lặng nghĩa là **chưa biết**, không phải **hãy tắt đi**: cột này chỉ
/// đi qua đồng bộ từ 2026-09-13 (bước 12), nên mọi hàng đã nằm sẵn trên server
/// mang NULL cho tới khi client đẩy lại từng hàng. Gán thẳng `Value(false)` là
/// **tắt tự động trả của mọi hoá đơn** ngay chu kỳ pull đầu tiên — người dùng
/// không được báo gì, và chỉ phát hiện ra khi một hoá đơn đến hạn mà không ai
/// trả.
library;

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';
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

/// Đánh dấu "không gửi khoá này" — khác với gửi `null`.
const _vangMat = Object();

void main() {
  const accountId = 7;
  const iso = '2026-09-01T10:00:00.000Z';

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

  Map<String, dynamic> billFromBackend({
    required String id,
    Object? autoPay = _vangMat,
  }) {
    return {
      'idbill': id,
      'idaccount': accountId,
      'idwallet': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'idcategory': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'name': 'Hoá đơn',
      'amount': 300000,
      'start_date': '2026-09-01T00:00:00.000Z',
      'due_date': '2026-10-16T00:00:00.000Z',
      'pay_status': 'Pending',
      'recurrence': true,
      'time_recurrence': kBillCycleMonth,
      if (!identical(autoPay, _vangMat)) 'auto_pay': autoPay,
      'update_at': iso,
    };
  }

  /// Hàng cục bộ **đang bật** tự động trả — đúng thứ một lượt pull sai luật sẽ
  /// tắt mất.
  Future<void> hangCucBoDangBat(String id) =>
      db.billDao.insert(BillsCompanion.insert(
        id: id,
        idaccount: accountId,
        name: 'Hoá đơn',
        amount: 300000,
        dueDate: DateTime(2026, 10, 16),
        autoPayEnabled: const Value(true),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 8, 1),
      ));

  test('server gửi auto_pay: true → bật cột cục bộ', () async {
    client.adapter.pullData = {
      'bills': [billFromBackend(id: 'b-1', autoPay: true)],
    };
    await runSync();
    expect((await db.billDao.getById('b-1'))!.autoPayEnabled, isTrue,
        reason: 'Đây là cả mục đích của bước 12: bật trên máy A thì máy B phải '
            'thấy bật.');
  });

  test('server gửi auto_pay: false → tắt cột cục bộ', () async {
    await hangCucBoDangBat('b-2');
    client.adapter.pullData = {
      'bills': [billFromBackend(id: 'b-2', autoPay: false)],
    };
    await runSync();
    expect((await db.billDao.getById('b-2'))!.autoPayEnabled, isFalse,
        reason: 'Tắt trên máy A cũng phải lan sang máy B — nếu không, tắt ở một '
            'nơi mà máy kia vẫn tự trừ tiền.');
  });

  test('server im lặng (thiếu khoá) → GIỮ NGUYÊN giá trị cục bộ', () async {
    await hangCucBoDangBat('b-3');
    client.adapter.pullData = {
      'bills': [billFromBackend(id: 'b-3')],
    };
    await runSync();
    expect((await db.billDao.getById('b-3'))!.autoPayEnabled, isTrue,
        reason: 'Hàng cũ trên server mang NULL cho tới khi client đẩy lại từng '
            'hàng. Đọc thẳng là TẮT tự động trả của mọi hoá đơn ngay chu kỳ '
            'pull đầu tiên — im lặng, và chỉ lộ ra khi một hoá đơn đến hạn mà '
            'không ai trả.');
  });

  test('server trả null tường minh → cũng giữ nguyên', () async {
    await hangCucBoDangBat('b-4');
    client.adapter.pullData = {
      'bills': [billFromBackend(id: 'b-4', autoPay: null)],
    };
    await runSync();
    expect((await db.billDao.getById('b-4'))!.autoPayEnabled, isTrue,
        reason: 'NULL trên server là "chưa biết", cùng nghĩa với việc thiếu '
            'khoá — không phải lệnh tắt.');
  });
}
