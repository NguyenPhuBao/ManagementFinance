/// `SyncOpFailure` phải mang theo **mã lỗi** backend gắn, không chỉ `kind`.
///
/// `kind` chỉ nói "vĩnh viễn hay tạm thời" — đủ để engine quyết định có gửi lại
/// hay không, nhưng **không** đủ cho người nghe `pushResultStream` phân biệt
/// `BILL_ALREADY_PAID` (đáng hoàn tác khoản trả) với `WALLET_NAME_DUPLICATE`
/// (đừng đụng vào). Không có `code`, lớp nghe buộc phải dò `message` — câu chữ
/// đổi được, mã thì không.
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
  _Client(this.adapter) {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
  final _Adapter adapter;
}

/// Từ chối mọi thao tác đẩy lên kèm [ma] — đúng hình dạng `sync.service.js` trả.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.ma);
  final String? ma;

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
              .map((op) => {
                    'localId': op['localId'],
                    'status': 'error',
                    'message': 'Hoá đơn này đã có khoản chi',
                    if (ma != null) 'code': ma,
                  })
              .toList(),
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(jsonEncode({'data': const {}}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const accountId = 7;

  group('data class', () {
    test('giữ code mà backend trả về', () {
      const f = SyncOpFailure(
        localId: 'x',
        entity: SyncEntityType.transaction,
        message: 'Hoá đơn này đã có khoản chi',
        kind: SyncFailureKind.permanent,
        code: 'BILL_ALREADY_PAID',
      );
      expect(f.code, 'BILL_ALREADY_PAID',
          reason: 'Thiếu trường này thì nơi nghe pushResultStream chỉ thấy '
              '`permanent` chung chung và không biết lỗi nào đáng hoàn tác.');
    });

    test('code là null khi backend không gắn mã', () {
      const f = SyncOpFailure(
        localId: 'x',
        entity: SyncEntityType.bill,
        message: 'lỗi cũ không có mã',
        kind: SyncFailureKind.transient,
      );
      expect(f.code, isNull,
          reason: 'Backend cũ không gắn mã; đừng bịa ra một giá trị.');
    });
  });

  group('đi qua engine', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    const idVi = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

    /// Ví phải có trước: `transactions.walletId` mang khoá ngoại tới `wallets`,
    /// nên seed thẳng giao dịch là `FOREIGN KEY constraint failed (787)`.
    Future<void> seedGiaoDichChoDay() async {
      await db.walletDao.insert(WalletsCompanion.insert(
        id: idVi,
        idaccount: accountId,
        name: 'Tiền mặt',
        // `synced` để ví KHÔNG vào hàng đợi đẩy: ví được đẩy trước giao dịch
        // (thứ tự khoá ngoại), nên để `pending` thì `failures.first` là ví chứ
        // không phải khoản chi cần đo.
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 9, 1),
      ));
      await db.transactionDao.insert(TransactionsCompanion.insert(
        id: 'tx-1',
        walletId: idVi,
        idaccount: accountId,
        amount: 50000,
        type: 'chi',
        date: DateTime(2026, 9, 1),
        syncStatus: const Value('pending'),
        updatedAt: DateTime(2026, 9, 1),
      ));
    }

    Future<SyncResult> chay(String? ma) async {
      final engine = SyncEngine(
        dioClient: _Client(_Adapter(ma)),
        db: db,
        connectivity: _Online(),
      );
      addTearDown(engine.dispose);
      final ketQua = engine.pushResultStream.first;
      await engine.start(idaccount: accountId);
      return ketQua.timeout(const Duration(seconds: 5));
    }

    test('mã backend trả về đi tới tận SyncOpFailure', () async {
      await seedGiaoDichChoDay();
      final r = await chay('BILL_ALREADY_PAID');
      expect(r.failures, isNotEmpty);
      expect(r.failures.first.code, 'BILL_ALREADY_PAID',
          reason: 'Đây là đường duy nhất mà BillPaymentConflictResolver biết '
              'được một khoản trả vừa bị từ chối vì máy khác đã trả trước.');
      expect(r.failures.first.entity, SyncEntityType.transaction);
    });

    test('backend không gắn mã thì code là null, không bịa', () async {
      await seedGiaoDichChoDay();
      final r = await chay(null);
      expect(r.failures, isNotEmpty);
      expect(r.failures.first.code, isNull);
    });
  });
}
