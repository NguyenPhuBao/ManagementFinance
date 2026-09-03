import 'dart:convert';

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

class _MockDioClientForE2E implements DioClient {
  final Dio _dio = Dio();
  late final _MockHttpAdapter adapter;

  _MockDioClientForE2E() {
    adapter = _MockHttpAdapter();
    _dio.httpClientAdapter = adapter;
  }

  @override
  Dio get dio => _dio;
}

class _MockHttpAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> pushedOperations = [];
  Map<String, dynamic> pullData = const {};

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
      pushedOperations = ops.cast<Map<String, dynamic>>();

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
        jsonEncode(jsonResponse),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    if (options.path.contains('/sync/pull')) {
      return ResponseBody.fromString(
        jsonEncode({'data': pullData}),
        200,
        headers: {
          Headers.contentTypeHeader: [
            DioMediaType.parse('application/json').toString()
          ],
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
  late _MockDioClientForE2E dioClient;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dioClient = _MockDioClientForE2E();
    syncEngine = SyncEngine(
      dioClient: dioClient,
      db: db,
      connectivity: MockConnectivityOnline(),
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
  });

  test(
      'E2E TEST: User action -> Saves to SQLite (pending) -> SyncEngine pushes to Backend API -> Updates SQLite (synced)',
      () async {
    const idaccount = 1;
    const walletId = 'wallet-e2e-100';
    const txId = 'tx-e2e-200';
    const serverCategoryId = 'server-category-e2e';
    const localGroupId = 'local-group-e2e';
    const localChildId = 'local-child-e2e';

    print(
        '----------------------------------------------------------------------');
    print(
        '1️⃣ KHỞI TẠO: Thao tác người dùng tạo mới Ví & Giao dịch trên App...');
    print(
        '----------------------------------------------------------------------');

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
    await db.categoryDao.insert(
      CategoriesCompanion.insert(
        id: localGroupId,
        idaccount: idaccount,
        name: 'Local group',
        classify: 'chi',
        isGroup: const Value(true),
        isLocalOnly: const Value(true),
        updatedAt: DateTime.now(),
      ),
    );
    await db.categoryDao.insert(
      CategoriesCompanion.insert(
        id: serverCategoryId,
        idaccount: idaccount,
        name: 'Server-backed category',
        classify: 'chi',
        isLocalOnly: const Value(false),
        updatedAt: DateTime.now(),
      ),
    );
    await db.categoryDao.insert(
      CategoriesCompanion.insert(
        id: localChildId,
        idaccount: idaccount,
        name: 'Local child',
        classify: 'chi',
        parentId: const Value(localGroupId),
        isLocalOnly: const Value(true),
        updatedAt: DateTime.now(),
      ),
    );

    // XÁC NHẬN BƯỚC 1: Dữ liệu đã lưu vào SQLite Local ở trạng thái 'pending'
    final pendingWalletsBefore = await db.walletDao.getPending(idaccount);
    final pendingTxBefore = await db.transactionDao.getPending(idaccount);

    expect(pendingWalletsBefore.length, equals(1));
    expect(pendingWalletsBefore.first.syncStatus, equals('pending'));
    expect(pendingTxBefore.length, equals(1));
    expect(pendingTxBefore.first.syncStatus, equals('pending'));

    print(
        '✅ BƯỚC 1 HOÀN THÀNH: Dữ liệu ĐÃ LƯU THÀNH CÔNG VÀO CSDL SQLITE LOCAL (Trạng thái: pending)');
    print(
        '   - Wallet in SQLite: ID = ${pendingWalletsBefore.first.id}, Name = ${pendingWalletsBefore.first.name}, Status = ${pendingWalletsBefore.first.syncStatus}');
    print(
        '   - Transaction in SQLite: ID = ${pendingTxBefore.first.id}, Amount = ${pendingTxBefore.first.amount}, Status = ${pendingTxBefore.first.syncStatus}\n');

    print(
        '----------------------------------------------------------------------');
    print(
        '2️⃣ ĐỒNG BỘ: Khởi động SyncEngine đẩy Batch sang API Backend /api/sync/push...');
    print(
        '----------------------------------------------------------------------');

    // 3. Khởi động SyncEngine
    final syncCompleted = syncEngine.statusStream
        .where((status) => status.isTerminal)
        .first;
    syncEngine.start(idaccount: idaccount);
    await syncCompleted.timeout(const Duration(seconds: 3));

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
    expect(
      dioClient.adapter.pushedOperations
          .map((operation) => operation['localId']),
      isNot(contains(localGroupId)),
    );
    expect(
      dioClient.adapter.pushedOperations
          .map((operation) => operation['localId']),
      isNot(contains(localChildId)),
    );
    final categoryOperation = dioClient.adapter.pushedOperations.singleWhere(
      (operation) => operation['localId'] == serverCategoryId,
    );
    final categoryPayload =
        categoryOperation['payload'] as Map<String, dynamic>;
    // Cấu trúc nhóm ĐƯỢC gửi lên: backend lưu Is_group + Idgroup và
    // mapEntityFields() nhận đúng hai key camelCase này.
    expect(categoryPayload, contains('parentId'));
    expect(categoryPayload, contains('isGroup'));
    // Các trường thuần client thì không gửi.
    expect(categoryPayload, isNot(contains('isLocalOnly')));
    expect(categoryPayload, isNot(contains('keywords')));

    print(
        '✅ BƯỚC 2 HOÀN THÀNH: Gửi API Backend THÀNH CÔNG và CẬP NHẬT SQLITE LOCAL sang trạng thái: synced');
    print(
        '   - Wallet in SQLite sau Sync: ID = ${walletLocal?.id}, Status = ${walletLocal?.syncStatus}');
    print(
        '   - Transaction in SQLite sau Sync: ID = ${txLocal?.id}, Status = ${txLocal?.syncStatus}');
    print(
        '----------------------------------------------------------------------\n');
  });

  test('E2E TEST: Pull preserves a local-only category when IDs collide',
      () async {
    const idaccount = 1;
    const categoryId = 'local-only-collision';
    await db.categoryDao.insert(
      CategoriesCompanion.insert(
        id: categoryId,
        idaccount: idaccount,
        name: 'Custom local category',
        classify: 'chi',
        parentId: const Value('custom-parent'),
        isGroup: const Value(true),
        isLocalOnly: const Value(true),
        syncStatus: const Value('synced'),
        updatedAt: DateTime(2026, 8, 21),
      ),
    );
    dioClient.adapter.pullData = {
      'categories': [
        {
          'id': categoryId,
          'name': 'Server category',
          'classify': 'chi',
          'updated_at': '2026-08-21T00:00:00.000Z',
        },
      ],
    };

    final syncCompleted = syncEngine.statusStream
        .where((status) => status.isTerminal)
        .first;
    syncEngine.start(idaccount: idaccount);
    await syncCompleted.timeout(const Duration(seconds: 3));

    final localCategory = await db.categoryDao.getById(categoryId);
    expect(localCategory?.name, 'Custom local category');
    expect(localCategory?.parentId, 'custom-parent');
    expect(localCategory?.isGroup, isTrue);
  });

  test(
      'BUG FIX: transaction on local-seed default category (cat_food) is '
      'repaired to the backend UUID and pushes on the next cycle — not '
      'deferred forever', () async {
    const idaccount = 1;
    const walletId = 'wallet-repair-1';
    const txId = 'tx-repair-1';
    const localSeedCategoryId = 'cat_food'; // giống ID seed cục bộ thật
    const backendCategoryUuid = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

    // Ví đã 'synced' sẵn — không nằm trong push batch, không ảnh hưởng test.
    await db.walletDao.insert(
      WalletsCompanion(
        id: const Value(walletId),
        idaccount: const Value(idaccount),
        name: const Value('Ví chính'),
        type: const Value('cash'),
        balance: const Value(1000000.0),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Category default seed cục bộ — đúng như app seed lúc khởi động lần đầu.
    await db.categoryDao.insert(
      CategoriesCompanion.insert(
        id: localSeedCategoryId,
        idaccount: 0,
        name: 'Ăn uống',
        classify: 'chi',
        isDefault: const Value(true),
        syncStatus: const Value('synced'),
        updatedAt: DateTime.now(),
      ),
    );

    // Giao dịch pending tham chiếu category seed cục bộ 'cat_food'.
    await db.transactionDao.insert(
      TransactionsCompanion(
        id: const Value(txId),
        idaccount: const Value(idaccount),
        walletId: const Value(walletId),
        categoryId: const Value(localSeedCategoryId),
        amount: const Value(-50000.0),
        type: const Value('chi'),
        note: const Value('Ăn trưa'),
        date: Value(DateTime.now()),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Backend đã có sẵn category "Ăn uống" (cùng tên + classify) dạng UUID —
    // giả lập response GET /sync/pull.
    dioClient.adapter.pullData = {
      'categories': [
        {
          'idcategory': backendCategoryUuid,
          'name_category': 'Ăn uống',
          'classify': 'Chi',
          'is_default': true,
          'create_by': 1,
          'update_at': DateTime.now().toUtc().toIso8601String(),
        },
      ],
    };

    // ── Vòng sync #1: lúc thu thập push batch, 'cat_food' chưa resolve được
    // (chưa có bản UUID) nên transaction bị defer (không push). Sau đó Pull
    // trả về category UUID → repair phải cập nhật categoryId 'cat_food' → UUID.
    final firstSyncDone =
        syncEngine.statusStream.where((s) => s.isTerminal).first;
    syncEngine.start(idaccount: idaccount);
    await firstSyncDone.timeout(const Duration(seconds: 3));

    // Seed 'cat_food' phải đã bị dedup xoá sau khi có bản UUID.
    final seedAfterRound1 = await db.categoryDao.getById(localSeedCategoryId);
    expect(seedAfterRound1, null,
        reason: 'cat_food seed phải bị xoá sau removeDuplicateLocalSeedCategories()');
    final uuidCategory = await db.categoryDao.getById(backendCategoryUuid);
    expect(uuidCategory != null, true);

    // Transaction phải đã được REPAIR sang categoryId UUID, vẫn 'pending'
    // (chưa push được ở vòng này vì lúc thu thập batch categoryId cũ chưa resolve).
    final txAfterRound1 = (await db.transactionDao.getAll(idaccount))
        .firstWhere((t) => t.id == txId);
    expect(
      txAfterRound1.categoryId,
      equals(backendCategoryUuid),
      reason: 'Regression check cho bug thứ tự gọi hàm: nếu '
          'removeDuplicateLocalSeedCategories() chạy TRƯỚC repair, '
          "getById('cat_food') trả về null và categoryId sẽ kẹt ở "
          "'cat_food' vĩnh viễn (transaction không bao giờ push được).",
    );
    expect(txAfterRound1.syncStatus, equals('pending'));

    // ── Vòng sync #2: mô phỏng chu kỳ sync kế tiếp — categoryId giờ đã là
    // UUID hợp lệ nên phải push thành công lên backend.
    dioClient.adapter.pullData = const {}; // không còn gì mới để pull
    final secondSyncDone =
        syncEngine.statusStream.where((s) => s.isTerminal).first;
    await syncEngine.syncNow();
    await secondSyncDone.timeout(const Duration(seconds: 3));

    final txAfterRound2 = (await db.transactionDao.getAll(idaccount))
        .firstWhere((t) => t.id == txId);
    expect(
      txAfterRound2.syncStatus,
      equals('synced'),
      reason: 'Transaction phải được push thành công, không còn bị defer mãi mãi',
    );

    final pushedTxOp = dioClient.adapter.pushedOperations
        .singleWhere((op) => op['localId'] == txId);
    final pushedPayload = pushedTxOp['payload'] as Map<String, dynamic>;
    expect(pushedPayload['categoryId'], equals(backendCategoryUuid));
  });
}
