/// Hoá đơn tạo từ form phải đẩy lên kèm ví và danh mục.
///
/// `bill.Idwallet` và `bill.Idcategory` đều NOT NULL trong `schema.prisma`.
/// Trước đây form hỏi ví rồi vứt đi và không hỏi danh mục, nên `/sync/push`
/// gửi lên hai giá trị null; `prisma.bill.create` ném lỗi, bản ghi bị
/// `markSyncBlocked` rồi quay lại hàng đợi ở mọi chu kỳ. Không có thông báo
/// nào tới người dùng — hoá đơn chỉ đơn giản là không bao giờ lên tới server.
///
/// Test này đi hết đường thật: BillDraft (thứ form dựng) → repository →
/// SQLite → payload mà SyncEngine gửi đi.
library;

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/bill/data/datasources/bill_local_datasource.dart';
import 'package:flowmoney/features/bill/data/repositories/bill_repository_impl.dart';
import 'package:flowmoney/features/bill/domain/bill_draft.dart';

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
  final List<Map<String, dynamic>> pushed = [];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      for (final op in ops) {
        pushed.add(Map<String, dynamic>.from(op as Map));
      }
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
    return ResponseBody.fromString(jsonEncode({'data': {}}), 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const accountId = 7;
  const walletId = '11111111-1111-4111-8111-111111111111';
  const categoryId = '22222222-2222-4222-8222-222222222222';

  late AppDatabase db;
  late _Client client;
  late SyncEngine engine;
  late BillRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Client();
    engine = SyncEngine(dioClient: client, db: db, connectivity: _Online());
    repository =
        BillRepositoryImpl(dataSource: BillLocalDataSource(db), db: db);

    await db.walletDao.insert(WalletsCompanion.insert(
      id: walletId,
      idaccount: accountId,
      name: 'Ví chính',
      balance: const Value(5000000),
      syncStatus: const Value('synced'),
      updatedAt: DateTime.now(),
    ));
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  Future<Map<String, dynamic>> pushedBillPayload() async {
    final done = engine.statusStream.where((s) => s.isTerminal).first;
    engine.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));

    final op = client.adapter.pushed
        .firstWhere((op) => op['entity'] == 'bill', orElse: () => {});
    expect(op.isNotEmpty, true, reason: 'Không có thao tác bill nào được đẩy.');
    return Map<String, dynamic>.from(op['payload'] as Map);
  }

  test('payload mang idwallet và idcategory người dùng đã chọn', () async {
    final draft = BillDraft(
      name: 'Tiền điện',
      amount: 250000,
      startDate: _startDate,
      dueDate: _dueDate,
      walletId: walletId,
      categoryId: categoryId,
      isRecurring: true,
      timeRecurrence: kBillCycleMonth,
      note: '',
    );

    await repository.addBill(draft.toInsertCompanion(
      id: '33333333-3333-4333-8333-333333333333',
      idaccount: accountId,
      now: DateTime(2026, 9, 4),
    ));

    final payload = await pushedBillPayload();

    expect(payload['idwallet'], walletId,
        reason: 'null ở đây là backend ném lỗi NOT NULL và bản ghi kẹt vòng '
            'lặp thử lại vĩnh viễn — im lặng với người dùng.');
    expect(payload['idcategory'], categoryId,
        reason: 'Cùng lý do: bill.Idcategory là NOT NULL, RESTRICT.');
    expect(payload['recurrence'], true,
        reason: 'Nhánh đẩy đọc cờ isRecurrence; form chỉ ghi chuỗi cũ thì '
            'backend luôn thấy hoá đơn là không lặp.');
    expect(payload['time_recurrence'], kBillCycleMonth);
    expect(payload['pay_status'], 'Pending');
    expect(payload['start_date'] != null, true,
        reason: 'Thiếu start_date thì backend tự đặt now(), hai bên lệch mốc '
            'bắt đầu chuỗi.');
  });

  test('sau khi thanh toán, payload báo pay_status = Payed', () async {
    final draft = BillDraft(
      name: 'Internet',
      amount: 200000,
      startDate: _startDate,
      dueDate: _dueDate,
      walletId: walletId,
      categoryId: categoryId,
      isRecurring: false,
      timeRecurrence: kBillCycleMonth,
      note: '',
    );
    await repository.addBill(draft.toInsertCompanion(
      id: '44444444-4444-4444-8444-444444444444',
      idaccount: accountId,
      now: DateTime(2026, 9, 4),
    ));
    final bill = (await db.billDao.getAll(accountId)).single;
    await repository.payBill(
        bill: bill, walletId: walletId, idaccount: accountId);

    final payload = await pushedBillPayload();

    expect(payload['pay_status'], 'Payed',
        reason: 'markPaid từng chỉ đặt isPaid, mà nhánh đẩy gửi pay_status. '
            'Thanh toán xong thì server vẫn thấy Pending vĩnh viễn.');
  });
}

final _startDate = DateTime(2026, 9, 5);
final _dueDate = DateTime(2026, 10, 5);
