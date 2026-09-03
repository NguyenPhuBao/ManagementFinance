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
import 'package:flowmoney/features/category/data/models/category_tree.dart';
import 'package:flowmoney/features/category/data/repositories/category_management_repository.dart';

class _FakeDioClient implements DioClient {
  @override
  final Dio dio = Dio();
}

/// DioClient giả lập backend, ghi lại mọi thao tác được push lên /sync/push.
class _CapturingDioClient implements DioClient {
  _CapturingDioClient() {
    dio.httpClientAdapter = adapter;
  }

  @override
  final Dio dio = Dio();
  final _CapturingAdapter adapter = _CapturingAdapter();
}

class _CapturingAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> pushed = [];
  Map<String, dynamic> pullData = const {};

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    if (options.path.contains('/sync/push')) {
      final ops =
          (options.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      pushed = ops.cast<Map<String, dynamic>>();
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

class _Offline implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.none];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OnlineOnce implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Đếm số lần SyncEngine được yêu cầu đồng bộ, không chạy sync thật.
class _SpySyncEngine extends SyncEngine {
  _SpySyncEngine({required super.dioClient, required super.db, super.connectivity});

  int scheduleCount = 0;

  @override
  void scheduleSync() => scheduleCount++;
}

void main() {
  const accountId = 7;
  late AppDatabase db;
  late _SpySyncEngine syncEngine;
  late CategoryManagementRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncEngine = _SpySyncEngine(
      dioClient: _FakeDioClient(),
      db: db,
      connectivity: _Offline(),
    );
    repo = CategoryManagementRepositoryImpl(db: db, syncEngine: syncEngine);
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
  });

  CategoryChildDraft draft({
    String? id,
    String? parentId,
    String name = 'Cà phê',
  }) =>
      CategoryChildDraft(
        id: id,
        accountId: accountId,
        name: name,
        classify: 'chi',
        parentId: parentId,
        icon: 'restaurant',
        colour: '#10B981',
        keywords: const [],
      );

  test(
      'Tạo danh mục mới KHÔNG chọn nhóm cha ("Chưa nhóm") phải thành công '
      '— regression: `parentId == id` từng là null == null nên chặn nhầm',
      () async {
    await repo.saveChild(draft());

    final saved = (await db.categoryDao.getAll(accountId))
        .where((c) => c.name == 'Cà phê')
        .toList();
    expect(saved.length, 1);
    expect(saved.single.parentId, null);
    expect(saved.single.idaccount, accountId);
  });

  test('Vẫn chặn khi SỬA một danh mục và đặt chính nó làm nhóm cha', () async {
    await repo.saveChild(draft());
    final created = (await db.categoryDao.getAll(accountId))
        .firstWhere((c) => c.name == 'Cà phê');

    expect(
      () => repo.saveChild(draft(id: created.id, parentId: created.id)),
      throwsA(isA<CategoryValidationException>()),
    );
  });

  test('Tạo danh mục phải kích hoạt đồng bộ nền (scheduleSync)', () async {
    expect(syncEngine.scheduleCount, 0);
    await repo.saveChild(draft());
    expect(syncEngine.scheduleCount, 1);
  });

  test('Danh mục người dùng tạo phải nằm trong batch đồng bộ lên backend',
      () async {
    await repo.saveChild(draft());
    final created = (await db.categoryDao.getAll(accountId))
        .firstWhere((c) => c.name == 'Cà phê');
    expect(created.isLocalOnly, false);

    final syncableIds =
        (await db.categoryDao.getSyncableCategories(accountId)).map((c) => c.id);
    expect(syncableIds, contains(created.id));
  });

  test('Nhóm danh mục (danh mục cha) cũng phải được đẩy lên backend', () async {
    await repo.saveGroup(CategoryGroupDraft(
      id: null,
      accountId: accountId,
      name: 'Thú cưng', // KHÔNG dùng tên trùng danh mục mặc định đã seed
      classify: 'chi',
      icon: 'restaurant',
      colour: '#10B981',
      childIds: const [],
    ));
    final group =
        (await db.categoryDao.getAll(accountId)).firstWhere((c) => c.isGroup);
    expect(group.isLocalOnly, false);

    await repo.saveChild(draft(parentId: group.id));

    final capturingDio = _CapturingDioClient();
    final realSync = SyncEngine(
      dioClient: capturingDio,
      db: db,
      connectivity: _OnlineOnce(),
    );
    final done = realSync.statusStream.where((s) => s.isTerminal).first;
    realSync.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));

    final categoryOps = capturingDio.adapter.pushed
        .where((op) => op['entity'] == 'category')
        .toList();
    final pushedIds = categoryOps.map((op) => op['localId']).toList();
    final child = (await db.categoryDao.getAll(accountId))
        .firstWhere((c) => c.name == 'Cà phê');

    expect(pushedIds, contains(group.id), reason: 'Nhóm phải được đẩy lên');
    expect(pushedIds, contains(child.id));
    // Nhóm phải đứng TRƯỚC con trong batch vì khoá ngoại fk_category_parent.
    expect(pushedIds.indexOf(group.id) < pushedIds.indexOf(child.id), true);

    final groupPayload = categoryOps
        .firstWhere((op) => op['localId'] == group.id)['payload']
        as Map<String, dynamic>;
    final childPayload = categoryOps
        .firstWhere((op) => op['localId'] == child.id)['payload']
        as Map<String, dynamic>;
    expect(groupPayload['isGroup'], true);
    expect(childPayload['isGroup'], false);
    expect(childPayload['parentId'], group.id,
        reason: 'Quan hệ cha–con phải được gửi lên qua Idgroup');

    realSync.dispose();
  });

  test('Pull đọc cờ xoá của danh mục thay vì hồi sinh nó', () async {
    const deletedId = '77777777-7777-4777-8777-777777777777';
    final pullDio = _CapturingDioClient()
      ..adapter.pullData = {
        'categories': [
          {
            'idcategory': deletedId,
            'name_category': 'Danh mục đã xoá trên server',
            'classify': 'Chi',
            'create_by': accountId,
            // Backend KHÔNG lọc delete_at khi trả dữ liệu nên hàng đã xoá vẫn
            // nằm trong response.
            'delete_at': '2026-09-02T00:00:00.000Z',
            'update_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      };
    final realSync = SyncEngine(
      dioClient: pullDio,
      db: db,
      connectivity: _OnlineOnce(),
    );
    final done = realSync.statusStream.where((s) => s.isTerminal).first;
    realSync.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));

    final pulled = await db.categoryDao.getById(deletedId);
    expect(pulled?.isDeleted, true,
        reason: 'Trước đây ghi cứng isDeleted = false nên danh mục đã xoá bị '
            'hồi sinh sau mỗi lần pull');

    realSync.dispose();
  });

  test('Pull đọc lại is_group/idgroup nên không xoá mất cấu trúc nhóm',
      () async {
    const groupId = '44444444-4444-4444-8444-444444444444';
    const childId = '55555555-5555-4555-8555-555555555555';
    final pullDio = _CapturingDioClient()
      ..adapter.pullData = {
        'categories': [
          {
            'idcategory': groupId,
            'name_category': 'Ăn uống',
            'classify': 'Chi',
            'is_group': true,
            'create_by': accountId,
            'update_at': DateTime.now().toUtc().toIso8601String(),
          },
          {
            'idcategory': childId,
            'name_category': 'Cà phê',
            'classify': 'Chi',
            'is_group': false,
            'idgroup': groupId,
            'create_by': accountId,
            'update_at': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      };
    final realSync = SyncEngine(
      dioClient: pullDio,
      db: db,
      connectivity: _OnlineOnce(),
    );
    final done = realSync.statusStream.where((s) => s.isTerminal).first;
    realSync.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));

    final group = await db.categoryDao.getById(groupId);
    final child = await db.categoryDao.getById(childId);
    expect(group?.isGroup, true);
    expect(child?.isGroup, false);
    expect(child?.parentId, groupId,
        reason: 'Trước đây insertOrReplace xoá sạch parentId sau mỗi lần pull');

    realSync.dispose();
  });

  test(
      'NHƯNG danh mục người dùng VẪN được đẩy lên backend khi có giao dịch '
      'tham chiếu — đảm bảo toàn vẹn khoá ngoại fk_transaction_category',
      () async {
    await repo.saveChild(draft());
    final category = (await db.categoryDao.getAll(accountId))
        .firstWhere((c) => c.name == 'Cà phê');

    const walletId = '22222222-2222-4222-8222-222222222222';
    await db.walletDao.insert(WalletsCompanion(
      id: const Value(walletId),
      idaccount: const Value(accountId),
      name: const Value('Ví tiền mặt'),
      type: const Value('cash'),
      balance: const Value(0),
      syncStatus: const Value('synced'),
      updatedAt: Value(DateTime.now()),
    ));
    await db.transactionDao.insert(TransactionsCompanion(
      id: const Value('33333333-3333-4333-8333-333333333333'),
      idaccount: const Value(accountId),
      walletId: const Value(walletId),
      categoryId: Value(category.id),
      amount: const Value(-45000),
      type: const Value('chi'),
      note: const Value('Cà phê sáng'),
      date: Value(DateTime.now()),
      syncStatus: const Value('pending'),
      updatedAt: Value(DateTime.now()),
    ));

    final capturingDio = _CapturingDioClient();
    final realSync = SyncEngine(
      dioClient: capturingDio,
      db: db,
      connectivity: _OnlineOnce(),
    );
    final done = realSync.statusStream.where((s) => s.isTerminal).first;
    realSync.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));

    final pushedIds = capturingDio.adapter.pushed.map((op) => op['localId']);
    expect(
      pushedIds,
      contains(category.id),
      reason: 'Danh mục được giao dịch tham chiếu phải có mặt trong batch push '
          '(SyncEngine bước 1b), nếu không backend sẽ lỗi khoá ngoại',
    );
    realSync.dispose();
  });

  test('Tạo nhóm và xoá danh mục cũng phải kích hoạt đồng bộ nền', () async {
    await repo.saveGroup(CategoryGroupDraft(
      id: null,
      accountId: accountId,
      name: 'Thú cưng', // KHÔNG dùng tên trùng danh mục mặc định đã seed
      classify: 'chi',
      icon: 'restaurant',
      colour: '#10B981',
      childIds: const [],
    ));
    expect(syncEngine.scheduleCount, 1);

    await repo.saveChild(draft());
    expect(syncEngine.scheduleCount, 2);

    final created = (await db.categoryDao.getAll(accountId))
        .firstWhere((c) => c.name == 'Cà phê');
    await repo.deleteChild(accountId: accountId, childId: created.id);
    expect(syncEngine.scheduleCount, 3);
  });
}
