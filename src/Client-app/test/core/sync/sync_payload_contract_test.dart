/// Test "hợp đồng" (contract) cho ánh xạ tên trường giữa Client và Backend.
///
/// Vì sao cần: payload push được dựng THỦ CÔNG ở client, đi qua
/// `SyncPayloadNormalizer`, rồi mới tới `mapEntityFields()` ở backend. Ba nơi
/// này không chia sẻ một định nghĩa chung nào, nên một tên trường sai sẽ **không
/// gây lỗi** — nó chỉ lặng lẽ bị bỏ qua. Dự án đã dính đúng lớp lỗi này nhiều
/// lần (giao dịch kẹt vĩnh viễn vì `cat_food`; nhóm danh mục không bao giờ được
/// đẩy lên backend).
///
/// File này khoá lại tập khoá của từng payload. Đổi tên trường mà quên cập nhật
/// phía kia sẽ làm test đỏ ngay thay vì hỏng âm thầm.
library;

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
  List<Map<String, dynamic>> pushed = [];
  Map<String, dynamic> pullData = const {};

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      pushed.addAll(ops.cast<Map<String, dynamic>>());
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
  const walletId = '11111111-1111-4111-8111-111111111111';
  const categoryId = '22222222-2222-4222-8222-222222222222';

  late AppDatabase db;
  late _Client client;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Client();
    engine =
        SyncEngine(dioClient: client, db: db, connectivity: _Online());
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  Future<void> runSync() async {
    final done = engine.statusStream.where((s) => s == SyncStatus.idle).first;
    engine.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));
  }

  Map<String, dynamic> payloadOf(String entity) {
    final op = client.adapter.pushed.firstWhere(
      (op) => op['entity'] == entity,
      orElse: () => throw StateError('Không có op nào cho entity "$entity"'),
    );
    return op['payload'] as Map<String, dynamic>;
  }

  group('PUSH — tập khoá của payload gửi lên backend', () {
    setUp(() async {
      final now = DateTime.now();
      await db.walletDao.insert(WalletsCompanion(
        id: const Value(walletId),
        idaccount: const Value(accountId),
        name: const Value('Ví tiền mặt'),
        type: const Value('cash'),
        balance: const Value(1000),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await db.categoryDao.insert(CategoriesCompanion.insert(
        id: categoryId,
        idaccount: accountId,
        name: 'Cà phê',
        classify: 'chi',
        updatedAt: now,
      ));
      await db.transactionDao.insert(TransactionsCompanion(
        id: const Value('33333333-3333-4333-8333-333333333333'),
        idaccount: const Value(accountId),
        walletId: const Value(walletId),
        categoryId: const Value(categoryId),
        amount: const Value(-45000),
        type: const Value('chi'),
        date: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await db.budgetDao.insert(BudgetsCompanion(
        id: const Value('44444444-4444-4444-8444-444444444444'),
        idaccount: const Value(accountId),
        categoryId: const Value(categoryId),
        amount: const Value(500000),
        startDate: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await db.billDao.insert(BillsCompanion(
        id: const Value('55555555-5555-4555-8555-555555555555'),
        idaccount: const Value(accountId),
        walletId: const Value(walletId),
        categoryId: const Value(categoryId),
        name: const Value('Tiền điện'),
        amount: const Value(300000),
        dueDate: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await db.goalDao.insert(GoalsCompanion(
        id: const Value('66666666-6666-4666-8666-666666666666'),
        idaccount: const Value(accountId),
        name: const Value('Mua laptop'),
        targetAmount: const Value(20000000),
        targetDate: Value(now),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
      await runSync();
    });

    test('wallet', () {
      expect(
        payloadOf('wallet').keys.toSet(),
        {
          'id', 'name', 'type', 'balance', 'currency', 'icon',
          'color', // normalizer đổi colour → color
          'is_default', 'is_deleted', 'include_in_total',
          'update_at', // normalizer đổi updated_at → update_at
          'idaccount',
        },
      );
    });

    test('category — phải có isGroup/parentId để backend dựng lại cây nhóm', () {
      expect(
        payloadOf('category').keys.toSet(),
        {
          'id', 'name', 'namecategory', 'classify', 'icon', 'colour',
          'is_default', 'is_deleted',
          'isGroup', // mapEntityFields: isGroup → Is_group
          'parentId', // mapEntityFields: parentId → Idgroup
          'update_at', 'idaccount',
        },
      );
    });

    test('transaction', () {
      expect(
        payloadOf('transaction').keys.toSet(),
        {
          'id',
          'walletId', // normalizer đổi wallet_id → walletId
          'categoryId', // normalizer đổi category_id → categoryId
          'idwallet_transfer',
          'amount', 'type', 'note',
          'dateTransaction', // normalizer đổi date → dateTransaction
          'is_deleted', 'update_at', 'idaccount',
        },
      );
    });

    test('budget — gửi thẳng tên field Prisma', () {
      expect(
        payloadOf('budget').keys.toSet(),
        {
          'id', 'idcategory', 'total_amount', 'spent',
          'threshold_warning_amount', 'over_spending', 'over_amount',
          'start', 'end', 'recurrence', 'time_recurrence',
          'nexttime_recurrence', 'note', 'is_deleted', 'update_at',
          'idaccount',
        },
      );
    });

    test('bill', () {
      expect(
        payloadOf('bill').keys.toSet(),
        {
          'id', 'idwallet', 'idcategory', 'name', 'amount', 'start_date',
          'due_date', 'pay_status', 'recurrence', 'time_recurrence',
          'time_notification', 'icon', 'color', 'note', 'is_deleted',
          'update_at', 'idaccount',
        },
      );
    });

    test('goal', () {
      expect(
        payloadOf('goal').keys.toSet(),
        {
          'id', 'name', 'target_amount', 'current_amount', 'start_date',
          'target_date', 'idwallet', 'cycle_take_money',
          'time_cycle_take_money', 'status_complete', 'recurrence',
          'time_recurrence', 'icon', 'color', 'note', 'is_deleted',
          'update_at', 'idaccount',
        },
      );
    });

    test('KHÔNG được rò rỉ trường thuần client lên backend', () {
      for (final op in client.adapter.pushed) {
        final payload = op['payload'] as Map<String, dynamic>;
        for (final forbidden in const [
          'syncStatus',
          'sync_status',
          'isLocalOnly',
          'is_local_only',
          'keywords',
          'updatedAt', // phải đã được đổi thành update_at
        ]) {
          expect(payload.containsKey(forbidden), false,
              reason: '${op['entity']} không được gửi "$forbidden"');
        }
      }
    });
  });

  group('PULL — mapper phải đọc đúng tên field Prisma backend trả về', () {
    test('đọc được đúng các trường của mọi thực thể', () async {
      client.adapter.pullData = {
        'wallets': [
          {
            'idwallet': walletId,
            'idaccount': accountId,
            'name': 'Ví ngân hàng',
            'balance': 5000,
            'color': '#123456',
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        'categories': [
          {
            'idcategory': categoryId,
            'name_category': 'Ăn uống',
            'classify': 'Chi',
            'is_group': true,
            'create_by': accountId,
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        'budgets': [
          {
            'idbudget': '44444444-4444-4444-8444-444444444444',
            'idaccount': accountId,
            'idcategory': categoryId,
            'total_amount': 750000,
            'over_spending': 'Stop',
            'start': '2026-09-01T00:00:00.000Z',
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
        'goals': [
          {
            'idgoal': '66666666-6666-4666-8666-666666666666',
            'idaccount': accountId,
            'name': 'Mua laptop',
            'target_amount': 20000000,
            'current_amount': 1000,
            'target_date': '2026-12-01T00:00:00.000Z',
            'status_complete': 'True',
            'update_at': '2026-09-01T10:00:00.000Z',
          },
        ],
      };

      await runSync();

      final wallet = await db.walletDao.getById(walletId);
      expect(wallet?.balance, 5000, reason: 'đọc "balance"');
      expect(wallet?.colour, '#123456', reason: 'backend dùng "color"');

      final category = await db.categoryDao.getById(categoryId);
      expect(category?.name, 'Ăn uống', reason: 'backend dùng "name_category"');
      expect(category?.isGroup, true, reason: 'backend dùng "is_group"');

      final budgets = await db.budgetDao.getAll(accountId);
      expect(budgets.single.amount, 750000,
          reason: 'backend dùng "total_amount", không phải "amount"');
      expect(budgets.single.overSpending, 'Stop');

      final goals = await db.goalDao.getAll(accountId);
      expect(goals.single.isCompleted, true,
          reason: 'backend dùng "status_complete" dạng chuỗi "True"');
    });
  });
}
