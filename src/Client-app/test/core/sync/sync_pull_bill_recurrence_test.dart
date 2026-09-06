/// Pull phải ghi chu kỳ hoá đơn vào CẢ HAI cách biểu diễn.
///
/// Bảng `Bills` mang hai cột nói cùng một chuyện: cặp `isRecurrence` +
/// `timeRecurrence` (đúng theo DB v2 của backend) và cột `recurrence` dạng
/// chuỗi cũ. Nhánh pull trước đây chỉ ghi cặp mới, nên cột cũ giữ nguyên
/// **mặc định 'monthly'** của bảng. Hậu quả: một hoá đơn KHÔNG lặp kéo về từ
/// backend vẫn mang `recurrence = 'monthly'`, và bất kỳ chỗ nào còn đọc cột
/// cũ sẽ sinh ra kỳ mới mà người dùng không hề đặt.
///
/// Đây đúng lớp lỗi im lặng của quy tắc 4: không exception, không log, chỉ có
/// một hoá đơn tự mọc ra.
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
import 'package:flowmoney/core/bill/bill_recurrence.dart';

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
    required bool recurrence,
    String? timeRecurrence,
  }) {
    return {
      'idbill': id,
      'idaccount': accountId,
      'idwallet': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'idcategory': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      'name': 'Hoá đơn',
      'amount': 300000,
      'due_date': iso,
      'pay_status': 'Pending',
      'recurrence': recurrence,
      if (timeRecurrence != null) 'time_recurrence': timeRecurrence,
      'update_at': iso,
    };
  }

  test('hoá đơn không lặp kéo về không được mang chuỗi cũ "monthly"', () async {
    client.adapter.pullData = {
      'bills': [
        billFromBackend(
          id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          recurrence: false,
        ),
      ],
    };
    await runSync();

    final bill = (await db.billDao.getAll(accountId)).single;
    expect(bill.isRecurrence, false);
    expect(
      bill.recurrence,
      'once',
      reason: 'Bỏ trống cột cũ là để nó rơi về mặc định "monthly" của bảng — '
          'hoá đơn một lần sẽ tự đẻ ra kỳ tiếp theo.',
    );
  });

  test('chu kỳ năm kéo về ghi khớp ở cả hai cột', () async {
    client.adapter.pullData = {
      'bills': [
        billFromBackend(
          id: 'dddddddd-dddd-4ddd-8ddd-ddddddddddde',
          recurrence: true,
          timeRecurrence: kBillCycleYear,
        ),
      ],
    };
    await runSync();

    final bill = (await db.billDao.getAll(accountId)).single;
    expect(bill.isRecurrence, true);
    expect(bill.timeRecurrence, kBillCycleYear);
    expect(
      bill.recurrence,
      'yearly',
      reason: 'Hai cột lệch nhau thì tuỳ nơi đọc mà hoá đơn lặp theo năm hay '
          'theo tháng — cùng một hàng, hai hành vi.',
    );
  });

  test('chu kỳ quý kéo về ghi khớp ở cả hai cột', () async {
    client.adapter.pullData = {
      'bills': [
        billFromBackend(
          id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddf',
          recurrence: true,
          timeRecurrence: kBillCycleQuarter,
        ),
      ],
    };
    await runSync();

    final bill = (await db.billDao.getAll(accountId)).single;
    expect(bill.timeRecurrence, kBillCycleQuarter);
    expect(bill.recurrence, 'quarterly');
  });
}
