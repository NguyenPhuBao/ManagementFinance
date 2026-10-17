/// Kéo về giao dịch: `idbill` có thì ghi vào `billId`, KHÔNG có thì giữ nguyên cột cục bộ — việc 4c.
///
/// Vì sao cần: từ việc 4c, sổ giao dịch KHOÁ khoản trả hoá đơn theo `billId` (`transactionOwnerOf`). Hàng trên server
/// ghi trước 2026-09-12 mang `Idbill` NULL; nhánh kéo về ghi đè `Value(null)` thay cho `Value.absent()` là mọi khoản
/// trả ấy mất khoá sau một vòng đồng bộ (và Hoàn tác mất đường lần về) — không exception, không log.
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
import '../../helpers/sync_engine_thu.dart';

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
  const moc = '2026-10-17T10:00:00.000Z';
  const viId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const txId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
  const billId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

  late AppDatabase db;
  late _Client client;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Client();
    engine = taoSyncEngineThu(dioClient: client, db: db, connectivity: _Online());
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

  Map<String, dynamic> giaoDich({String? idbill, String note = 'Thanh toán hóa đơn: Internet'}) => {
        'idtran': txId,
        'idwallet': viId,
        'idaccount': accountId,
        'amount': -120000,
        // Giá trị backend thật (`sync_payload_normalizer.dart` — `Transaction` / `Transfer`), chiều ở dấu `amount`.
        'type': 'Transaction',
        'note': note,
        'date_transaction': moc,
        'update_at': moc,
        if (idbill != null) 'idbill': idbill,
      };

  test('server gửi idbill → billId được ghi', () async {
    client.adapter.pullData = {
      'wallets': [
        {'idwallet': viId, 'idaccount': accountId, 'name': 'Ví', 'update_at': moc},
      ],
      'transactions': [giaoDich(idbill: billId)],
    };
    await runSync();

    final hang = await db.transactionDao.getById(txId);
    expect(hang?.billId, billId,
        reason: 'Server gửi idbill thì phải ghi vào billId — thiếu là khoản '
            'trả kéo về máy thứ hai không khoá ở Sổ giao dịch (việc 4c).');
  });

  test('server im lặng về idbill → billId cục bộ GIỮ NGUYÊN', () async {
    final cu = DateTime(2026, 10, 1);
    await db.walletDao.insert(WalletsCompanion.insert(
      id: viId,
      idaccount: accountId,
      name: 'Ví',
      syncStatus: const Value('synced'),
      updatedAt: cu,
    ));
    await db.transactionDao.insert(TransactionsCompanion.insert(
      id: txId,
      walletId: viId,
      idaccount: accountId,
      amount: 120000,
      type: 'chi',
      date: cu,
      note: const Value('Thanh toán hóa đơn: Internet'),
      billId: const Value(billId),
      // `synced` để bước đẩy không xen vào ca này.
      syncStatus: const Value('synced'),
      updatedAt: cu,
    ));

    client.adapter.pullData = {
      'transactions': [giaoDich(note: 'Thanh toán hóa đơn: Internet — sửa ở máy kia')],
    };
    await runSync();

    final hang = await db.transactionDao.getById(txId);
    expect(hang?.note, 'Thanh toán hóa đơn: Internet — sửa ở máy kia',
        reason: 'Đòi kết quả: hàng PHẢI đã được ghi đè bởi lượt kéo — nếu không, '
            'vế billId dưới xanh mà chẳng canh gì.');
    expect(hang?.billId, billId,
        reason: 'Server im lặng nghĩa là chưa biết, không phải hãy xoá. Ghi NULL '
            'là khoản trả mất khoá ở Sổ giao dịch (việc 4c) và Hoàn tác mất '
            'đường lần về.');
  });

  test('server gửi "idbill": null TƯỜNG MINH → billId cục bộ GIỮ NGUYÊN', () async {
    final cu = DateTime(2026, 10, 1);
    await db.walletDao.insert(WalletsCompanion.insert(
      id: viId,
      idaccount: accountId,
      name: 'Ví',
      syncStatus: const Value('synced'),
      updatedAt: cu,
    ));
    await db.transactionDao.insert(TransactionsCompanion.insert(
      id: txId,
      walletId: viId,
      idaccount: accountId,
      amount: 120000,
      type: 'chi',
      date: cu,
      note: const Value('Thanh toán hóa đơn: Internet'),
      billId: const Value(billId),
      syncStatus: const Value('synced'),
      updatedAt: cu,
    ));

    client.adapter.pullData = {
      'transactions': [
        {
          ...giaoDich(note: 'Thanh toán hóa đơn: Internet — sửa ở máy kia'),
          'idbill': null,
        },
      ],
    };
    await runSync();

    final hang = await db.transactionDao.getById(txId);
    expect(hang?.note, 'Thanh toán hóa đơn: Internet — sửa ở máy kia',
        reason: 'Đòi kết quả: hàng PHẢI đã được ghi đè bởi lượt kéo — nếu không, '
            'vế billId dưới xanh mà chẳng canh gì.');
    expect(hang?.billId, billId,
        reason: 'Server thật (Prisma findMany không select) gửi "idbill": null '
            'tường minh cho hàng ghi trước 2026-09-12, không phải vắng khoá. '
            'Viết lại phép đọc thành containsKey là ghi NULL đè billId → khoản '
            'trả mất khoá ở Sổ giao dịch (việc 4c), mà ca vắng-khoá ở trên '
            'vẫn xanh.');
  });
}
