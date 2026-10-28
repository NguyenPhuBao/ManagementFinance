/// Nhánh kéo về đọc `idhousehold` của năm thực thể (gia đình, schema v32 — đơn 50 D.1: server trả khoá này, số hoặc
/// `null`). Server im lặng (thiếu khoá — backend chưa lên đơn 50) nghĩa là CHƯA BIẾT: giữ giá trị cục bộ (`Value.absent`),
/// cùng luật `idgoal` / `idbill`; đặc tả không có luồng đổi phạm vi một hàng riêng ↔ nhà và server SẼ từ chối đổi
/// `Idhousehold` của hàng đã có (đơn 56.3, chưa đóng — backend đang chạy vẫn cho đổi).
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
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
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
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      final ops = (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': ops.map((op) => {'localId': op['localId'], 'status': 'synced'}).toList(),
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(jsonEncode({'data': pullData}), 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const accountId = 25;
  const iso = '2026-10-23T09:00:00.000Z';
  const viId = '11111111-1111-4111-8111-111111111111';
  const gdId = '33333333-3333-4333-8333-333333333333';
  const dmNha = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  const dmRieng = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  const nsId = '44444444-4444-4444-8444-444444444444';
  const mtId = '66666666-6666-4666-8666-666666666666';

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

  test('năm thực thể kéo về mang idhousehold của server', () async {
    // ⚠️ Hàng của nhà mang `idaccount` của CHÍNH TÔI (tôi là người tạo / chủ nhà): phép "không hiện ở danh sách cá nhân"
    // bên dưới chỉ đỏ-rồi-xanh nhờ vế `idhousehold IS NULL` của Task 2 — dựng với tài khoản khác là ca xanh ngay, không canh gì.
    client.adapter.pullData = {
      'wallets': [
        {
          'idwallet': viId,
          'idaccount': accountId,
          'name': 'Quỹ chung',
          'type': 'Cash',
          'idhousehold': 12,
          'update_at': iso
        },
      ],
      'transactions': [
        {
          'idtran': gdId,
          'idaccount': accountId,
          'idwallet': viId,
          'idcategory': dmNha,
          'amount': -50000,
          'type': 'Transaction',
          'date_transaction': iso,
          'idhousehold': 12,
          'update_at': iso,
        },
      ],
      'categories': [
        {
          'idcategory': dmNha,
          'create_by': accountId,
          'namecategory': 'Ăn uống',
          'classify': 'Chi',
          'is_default': false,
          'idhousehold': 12,
          'update_at': iso,
        },
      ],
      'budgets': [
        {
          'idbudget': nsId,
          'idaccount': accountId,
          'idcategory': dmNha,
          'total_amount': 1,
          'start': iso,
          'idhousehold': 12,
          'update_at': iso
        },
      ],
      'goals': [
        {
          'idgoal': mtId,
          'idaccount': accountId,
          'name': 'Du lịch',
          'target_amount': 1,
          'target_date': iso,
          'idhousehold': 12,
          'update_at': iso
        },
      ],
    };
    await runSync();
    expect((await db.walletDao.getById(viId))!.idhousehold, 12);
    expect((await db.transactionDao.getById(gdId))!.idhousehold, 12);
    expect((await db.categoryDao.getById(dmNha))!.idhousehold, 12);
    expect((await db.budgetDao.getById(nsId))!.idhousehold, 12);
    expect((await db.goalDao.getById(mtId))!.idhousehold, 12);
    expect(await db.walletDao.getAll(accountId), isEmpty,
        reason:
            'quỹ chung tôi tạo về máy nhưng KHÔNG hiện ở danh sách ví cá nhân (Task 2 — lọc theo tài khoản thôi là nó hiện)');
    expect(await db.transactionDao.getAll(accountId), isEmpty, reason: 'khoản của nhà không vào Sổ cá nhân (Task 2)');
  });

  test('server trả `idhousehold: null` TƯỜNG MINH cho hàng riêng → giữ giá trị cục bộ (cùng luật thiếu khoá)',
      () async {
    // Backend trả `null` cho mọi hàng riêng ở năm bảng (`findMany` không `select`). `null` tường minh đọc là "chưa biết"
    // như thiếu khoá: đặc tả không có đường "nhà → riêng" để phải nghe, server SẼ từ chối đổi (đơn 56.3, chưa đóng).
    await db.walletDao.insert(WalletsCompanion(
      id: const Value(viId),
      idaccount: const Value(accountId),
      name: const Value('Quỹ chung'),
      idhousehold: const Value(12),
      syncStatus: const Value('synced'),
      updatedAt: Value(DateTime.utc(2026, 10, 1)),
    ));
    client.adapter.pullData = {
      'wallets': [
        {
          'idwallet': viId,
          'idaccount': accountId,
          'name': 'Quỹ chung',
          'type': 'Cash',
          'idhousehold': null,
          'update_at': iso
        },
      ],
    };
    await runSync();
    expect((await db.walletDao.getById(viId))!.idhousehold, 12);
  });

  test('server KHÔNG trả khoá idhousehold → giá trị cục bộ còn nguyên', () async {
    await db.walletDao.insert(WalletsCompanion(
      id: const Value(viId),
      idaccount: const Value(18),
      name: const Value('Quỹ chung'),
      idhousehold: const Value(12),
      syncStatus: const Value('synced'),
      updatedAt: Value(DateTime.utc(2026, 10, 1)),
    ));
    client.adapter.pullData = {
      'wallets': [
        {'idwallet': viId, 'idaccount': 18, 'name': 'Quỹ chung (đổi tên)', 'type': 'Cash', 'update_at': iso},
      ],
    };
    await runSync();
    final w = (await db.walletDao.getById(viId))!;
    expect(w.name, 'Quỹ chung (đổi tên)', reason: 'tiền đề: hàng đã được ghi đè bởi lượt kéo');
    expect(w.idhousehold, 12,
        reason: 'gán thẳng Value(null) là biến quỹ chung thành ví riêng ngay chu kỳ đầu với backend chưa lên đơn 50');
  });

  test('danh mục của nhà mang từ khoá: KHÔNG gieo vào bảng từ khoá của tôi; danh mục riêng vẫn gieo', () async {
    client.adapter.pullData = {
      'categories': [
        {
          'idcategory': dmNha,
          'create_by': 18,
          'namecategory': 'Ăn uống',
          'classify': 'Chi',
          'is_default': false,
          'keyword': 'pho,bun',
          'idhousehold': 12,
          'update_at': iso
        },
        {
          'idcategory': dmRieng,
          'create_by': accountId,
          'namecategory': 'Cà phê',
          'classify': 'Chi',
          'is_default': false,
          'keyword': 'cafe',
          'update_at': iso
        },
      ],
    };
    await runSync();
    expect(await db.categoryDao.getKeywords(accountId, dmNha), isEmpty,
        reason:
            'phần 1 không màn nào dùng từ khoá của danh mục nhà; gieo vào bảng của TÔI là rác mà xoaHangCuaNha phải '
            'dọn, và bộ gợi ý cá nhân đọc cả bảng ấy');
    expect(await db.categoryDao.getKeywords(accountId, dmRieng), ['cafe']);
  });
}
