/// Pull phải ghi cờ xoá vào ĐÚNG cột mà các DAO dùng để lọc.
///
/// Vì sao cần: mọi `getAll`/`watchAll` trong dự án lọc theo `deletedAt.isNull()`,
/// nhưng khối Pull trước đây chỉ gán `isDeleted` và bỏ trống `deletedAt`. Hệ quả:
/// bản ghi xoá mềm trên máy khác kéo về máy này vẫn **hiện ra trong danh sách**
/// — không exception, không log, đúng lớp lỗi âm thầm mà dự án đã dính nhiều lần
/// (xem G7 trong `docs/CLIENT_APP_KNOWN_GAPS.md`: lần đó Pull ghi cứng
/// `isDeleted = false` nên danh mục đã xoá bị hồi sinh; lần này cờ đọc đúng
/// nhưng ghi nhầm cột).
///
/// `upsertAll` dùng `insertAllOnConflictUpdate` nên cột không gán sẽ **giữ
/// nguyên** giá trị cũ ở hàng đã có, và nhận **mặc định** ở hàng mới — cả hai
/// đường đều để `deletedAt = null`.
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
  // Thời điểm xoá do backend trả về. Backend KHÔNG lọc `delete_at` khi trả dữ
  // liệu, nên hàng đã xoá vẫn nằm trong response — đó là lý do client phải tự
  // đọc cờ này.
  const deletedAtIso = '2026-09-01T10:00:00.000Z';

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

  group('PULL — bản ghi đã xoá mềm trên server không được hiện ở client', () {
    setUp(() {
      client.adapter.pullData = const {
        'wallets': [
          {
            'idwallet': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            'idaccount': accountId,
            'name': 'Ví đã xoá',
            'balance': 100000,
            'delete_at': deletedAtIso,
            'update_at': deletedAtIso,
          }
        ],
        'categories': [
          {
            'idcategory': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            'idaccount': accountId,
            'create_by': accountId,
            'name_category': 'Danh mục đã xoá',
            'classify': 'Chi',
            'delete_at': deletedAtIso,
            'update_at': deletedAtIso,
          }
        ],
        'budgets': [
          {
            'idbudget': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            'idaccount': accountId,
            'total_amount': 500000,
            'start': deletedAtIso,
            'delete_at': deletedAtIso,
            'update_at': deletedAtIso,
          }
        ],
        'bills': [
          {
            'idbill': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            'idaccount': accountId,
            'name': 'Hoá đơn đã xoá',
            'amount': 300000,
            'due_date': deletedAtIso,
            'delete_at': deletedAtIso,
            'update_at': deletedAtIso,
          }
        ],
        'goals': [
          {
            'idgoal': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
            'idaccount': accountId,
            'name': 'Mục tiêu đã xoá',
            'target_amount': 900000,
            'target_date': deletedAtIso,
            'delete_at': deletedAtIso,
            'update_at': deletedAtIso,
          }
        ],
        'transactions': [
          {
            'idtran': 'ffffffff-ffff-4fff-8fff-ffffffffffff',
            'idwallet': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            'idaccount': accountId,
            'amount': -45000,
            'type': 'chi',
            'date_transaction': deletedAtIso,
            'deleted_at': deletedAtIso,
            'update_at': deletedAtIso,
          }
        ],
      };
    });

    test('budget — không lọt vào getAll sau khi pull', () async {
      await runSync();
      expect(await db.budgetDao.getAll(accountId), isEmpty,
          reason: 'Ngân sách có delete_at trên server phải bị coi là đã xoá. '
              'Nếu Pull chỉ gán isDeleted mà bỏ trống deletedAt, '
              'BudgetDao.getAll (lọc theo deletedAt.isNull()) vẫn trả nó về.');
    });

    test('bill — không lọt vào getAll sau khi pull', () async {
      await runSync();
      expect(await db.billDao.getAll(accountId), isEmpty,
          reason: 'BillDao.getAll cũng lọc theo deletedAt.isNull().');
    });

    test('goal — không lọt vào getAll sau khi pull', () async {
      await runSync();
      expect(await db.goalDao.getAll(accountId), isEmpty,
          reason: 'GoalDao.getAll cũng lọc theo deletedAt.isNull().');
    });

    test('wallet — không lọt vào getAll sau khi pull', () async {
      await runSync();
      expect(await db.walletDao.getAll(accountId), isEmpty,
          reason: 'WalletDao.getAll cũng lọc theo deletedAt.isNull().');
    });

    test('hai cờ xoá phải luôn đi cùng nhau', () async {
      await runSync();
      // Đọc thẳng bảng, bỏ qua mọi bộ lọc của DAO: cần thấy CẢ HAI cột.
      final row = await (db.select(db.budgets)
            ..where((t) =>
                t.id.equals('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')))
          .getSingle();
      expect(row.isDeleted, isTrue,
          reason: 'Cờ boolean phải bật — đây là phần vốn đã đúng.');
      expect(row.deletedAt, isNotNull,
          reason: 'Cột thời điểm xoá cũng phải được ghi. Đây là cột mà mọi '
              'truy vấn đọc dữ liệu thật sự dùng để lọc; bỏ trống nó là '
              'nguồn gốc của lỗi bản ghi ma.');
    });
  });
}
