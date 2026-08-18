import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/core/sync/sync_models.dart';

class MockConnectivityOnline implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return [ConnectivityResult.wifi];
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return Stream.value([ConnectivityResult.wifi]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDioClientForE2E implements DioClient {
  final Dio _dio = Dio();

  MockDioClientForE2E() {
    _dio.httpClientAdapter = _MockHttpAdapter();
  }

  @override
  Dio get dio => _dio;
}

class _MockHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Check if endpoint is /sync/push
    if (options.path.contains('/sync/push')) {
      final data = options.data as Map<String, dynamic>;
      final ops = data['operations'] as List<dynamic>;

      final results = ops.map((op) {
        return {
          'localId': op['localId'],
          'status': 'synced',
        };
      }).toList();

      final jsonResponse = {
        'status': 'success',
        'results': results,
        'summary': {
          'total': ops.length,
          'synced': ops.length,
          'conflicts': 0,
          'errors': 0,
        }
      };

      return ResponseBody.fromString(
        DioMediaType.parse('application/json').toString(),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    return ResponseBody.fromString('{"error": "Not Found"}', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late SyncEngine syncEngine;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncEngine = SyncEngine(
      dioClient: MockDioClientForE2E(),
      db: db,
      connectivity: MockConnectivityOnline(),
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
  });

  test('E2E TEST: User action -> Saves to SQLite (pending) -> SyncEngine pushes to Backend API -> Updates SQLite (synced)', () async {
    const idaccount = 1;
    const walletId = 'wallet-e2e-100';
    const txId = 'tx-e2e-200';

    print('----------------------------------------------------------------------');
    print('1️⃣ KHỞI TẠO: Thao tác người dùng tạo mới Ví & Giao dịch trên App...');
    print('----------------------------------------------------------------------');

    // 1. Thêm Ví vào SQLite Local với syncStatus = 'pending'
    await db.walletDao.insert(
      WalletsCompanion(
        id: const Value(walletId),
        idaccount: const Value(idaccount),
        name: const Value('Ví Lương VCB'),
        type: const Value('bank'),
        balance: const Value(20000000.0),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // 2. Thêm Giao dịch vào SQLite Local với syncStatus = 'pending'
    await db.transactionDao.insert(
      TransactionsCompanion(
        id: const Value(txId),
        idaccount: const Value(idaccount),
        walletId: const Value(walletId),
        amount: const Value(350000.0),
        type: const Value('chi'),
        note: const Value('Tiền siêu thị WinMart'),
        date: Value(DateTime.now()),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // XÁC NHẬN BƯỚC 1: Dữ liệu đã lưu vào SQLite Local ở trạng thái 'pending'
    final pendingWalletsBefore = await db.walletDao.getPending(idaccount);
    final pendingTxBefore = await db.transactionDao.getPending(idaccount);

    expect(pendingWalletsBefore.length, equals(1));
    expect(pendingWalletsBefore.first.syncStatus, equals('pending'));
    expect(pendingTxBefore.length, equals(1));
    expect(pendingTxBefore.first.syncStatus, equals('pending'));

    print('✅ BƯỚC 1 HOÀN THÀNH: Dữ liệu ĐÃ LƯU THÀNH CÔNG VÀO CSDL SQLITE LOCAL (Trạng thái: pending)');
    print('   - Wallet in SQLite: ID = ${pendingWalletsBefore.first.id}, Name = ${pendingWalletsBefore.first.name}, Status = ${pendingWalletsBefore.first.syncStatus}');
    print('   - Transaction in SQLite: ID = ${pendingTxBefore.first.id}, Amount = ${pendingTxBefore.first.amount}, Status = ${pendingTxBefore.first.syncStatus}\n');

    print('----------------------------------------------------------------------');
    print('2️⃣ ĐỒNG BỘ: Khởi động SyncEngine đẩy Batch sang API Backend /api/sync/push...');
    print('----------------------------------------------------------------------');

    // 3. Khởi động SyncEngine
    syncEngine.start(idaccount: idaccount);

    // Chờ 3 giây cho quá trình Debounce và Gửi HTTP request
    await Future.delayed(const Duration(seconds: 3));

    // XÁC NHẬN BƯỚC 2: Kiểm tra lại SQLite Local sau khi Backend phản hồi thành công
    final pendingWalletsAfter = await db.walletDao.getPending(idaccount);
    final pendingTxAfter = await db.transactionDao.getPending(idaccount);

    final walletLocal = await db.walletDao.getById(walletId);
    final txLocalList = await db.transactionDao.getAll(idaccount);
    final txLocal = txLocalList.firstWhere((t) => t.id == txId);

    expect(pendingWalletsAfter, isEmpty);
    expect(pendingTxAfter, isEmpty);
    expect(walletLocal?.syncStatus, equals('synced'));
    expect(txLocal?.syncStatus, equals('synced'));

    print('✅ BƯỚC 2 HOÀN THÀNH: Gửi API Backend THÀNH CÔNG và CẬP NHẬT SQLITE LOCAL sang trạng thái: synced');
    print('   - Wallet in SQLite sau Sync: ID = ${walletLocal?.id}, Status = ${walletLocal?.syncStatus}');
    print('   - Transaction in SQLite sau Sync: ID = ${txLocal?.id}, Status = ${txLocal?.syncStatus}');
    print('----------------------------------------------------------------------\n');
  });
}
