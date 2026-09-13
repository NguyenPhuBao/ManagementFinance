/// Pull `period_end` của hoá đơn — cùng luật với `anchor_day`.
///
/// Server im lặng nghĩa là **chưa biết**, không phải **hãy xoá**: cột này chỉ
/// đi qua đồng bộ từ v21 (2026-09-12), nên mọi hàng đã nằm sẵn trên server
/// mang NULL cho tới khi client đẩy lại từng hàng. Gán thẳng `Value(null)` là
/// xoá ngày kết thúc kỳ ngay chu kỳ pull đầu tiên, và kỳ sau lại nối từ hạn
/// trả — hở đúng số ngày ân hạn, im lặng.
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
    Object? periodEnd = _vangMat,
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
      if (!identical(periodEnd, _vangMat)) 'period_end': periodEnd,
      'update_at': iso,
    };
  }

  Future<void> hangCucBo(String id) => db.billDao.insert(BillsCompanion.insert(
        id: id,
        idaccount: accountId,
        name: 'Hoá đơn',
        amount: 300000,
        periodEnd: Value(DateTime(2026, 10, 1)),
        dueDate: DateTime(2026, 10, 16),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 8, 1),
      ));

  test('server có period_end → ghi vào periodEnd', () async {
    client.adapter.pullData = {
      'bills': [
        billFromBackend(id: 'b-1', periodEnd: '2026-10-01T00:00:00.000Z'),
      ],
    };
    await runSync();
    final b = (await db.billDao.getById('b-1'))!;
    // Drift trả DateTime theo giờ máy; so theo UTC vì `==` của Dart đòi cùng
    // múi giờ dù cùng thời điểm.
    expect(b.periodEnd!.toUtc(), DateTime.parse('2026-10-01T00:00:00.000Z'));
    expect(b.dueDate.toUtc(), DateTime.parse('2026-10-16T00:00:00.000Z'));
  });

  test('server im lặng (thiếu khoá) → giữ nguyên periodEnd cục bộ', () async {
    await hangCucBo('b-2');
    client.adapter.pullData = {
      'bills': [billFromBackend(id: 'b-2')],
    };
    await runSync();
    expect((await db.billDao.getById('b-2'))!.periodEnd, DateTime(2026, 10, 1),
        reason: 'Hàng cũ trên server mang NULL cho tới khi client đẩy lại; đọc '
            'thẳng là xoá ngày kết thúc kỳ ngay chu kỳ pull đầu tiên và kỳ sau '
            'lại nối từ hạn trả.');
  });

  test('server trả null tường minh → cũng giữ nguyên', () async {
    await hangCucBo('b-3');
    client.adapter.pullData = {
      'bills': [billFromBackend(id: 'b-3', periodEnd: null)],
    };
    await runSync();
    expect((await db.billDao.getById('b-3'))!.periodEnd, DateTime(2026, 10, 1));
  });
}
