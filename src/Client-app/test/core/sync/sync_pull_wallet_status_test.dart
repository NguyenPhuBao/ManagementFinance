/// Pull `status` của ví — **lưu trữ ví lan được sang máy khác** (G28).
///
/// Trước 2026-09-14 cột này cố ý không đi chiều nào: `chk_wallet_status` cho
/// phép `'Inactive'` nhưng kiểu cột khi ấy là `varchar(7)` còn chuỗi ấy dài 8
/// ký tự, nên ví lưu trữ đẩy lên là **kẹt hàng đợi đẩy vĩnh viễn, im lặng**.
/// Đo lại 2026-09-14: cột nay `varchar(20)`, `NOT NULL`, `DEFAULT 'Active'`.
///
/// Hai luật mà tệp này canh, phá cái nào cũng hỏng **im lặng**:
///
/// 1. **Chữ thường khi lưu.** Cột SQLite mặc định `'active'` và hợp đồng ghi ở
///    `wallet_entity.dart` là `'active' | 'inactive'`. Ghi thẳng chuỗi của
///    server là để cột mang hai cách viết, và mọi câu SQL thô so chuỗi trực
///    tiếp lọc lệch — trong đó có chính migration v22.
/// 2. **Thiếu khoá nghĩa là *chưa biết*.** Cột của server hiện `NOT NULL` nên
///    nó luôn trả giá trị; phép phòng thủ ở đây là cho một bản backend không
///    trả khoá ấy. Đọc `null` thành "hoạt động" là **đánh thức mọi ví lưu
///    trữ** ngay lượt pull đầu tiên — cùng bài học với `include_in_total`,
///    `idgoal` và `auto_pay`.
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

/// Đánh dấu "không gửi khoá này" — khác với gửi `null`.
const _vangMat = Object();

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

  Map<String, dynamic> viTuBackend({
    required String id,
    Object? status = _vangMat,
  }) {
    return {
      'idwallet': id,
      'idaccount': accountId,
      'name': 'Ví thẻ',
      'type': 'Bank',
      'currency': 'VND',
      'icon': 'wallet',
      'color': '#4CAF50',
      'is_default': false,
      'include_in_total': true,
      if (!identical(status, _vangMat)) 'status': status,
      'update_at': iso,
    };
  }

  /// Hàng cục bộ **đang lưu trữ** — đúng thứ một lượt pull sai luật sẽ đánh
  /// thức dậy.
  Future<void> hangCucBoDangLuuTru(String id) =>
      db.walletDao.insert(WalletsCompanion(
        id: Value(id),
        idaccount: const Value(accountId),
        name: const Value('Ví thẻ'),
        type: const Value('bank'),
        balance: const Value(0),
        status: const Value('inactive'),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime(2026, 8, 1)),
      ));

  test('server gửi Inactive → ví thành lưu trữ trên máy này', () async {
    client.adapter.pullData = {
      'wallets': [viTuBackend(id: 'w-1', status: 'Inactive')],
    };
    await runSync();
    expect((await db.walletDao.getById('w-1'))!.status, 'inactive',
        reason: 'Đây là cả mục đích của G28: lưu trữ trên máy A thì máy B phải '
            'thấy lưu trữ. Và phải lưu CHỮ THƯỜNG — cột SQLite mặc định chữ '
            'thường, trộn hai cách viết là mọi câu SQL thô so chuỗi trực tiếp '
            'lọc lệch.');
  });

  test('server gửi Active → ví bỏ lưu trữ trên máy này', () async {
    await hangCucBoDangLuuTru('w-2');
    client.adapter.pullData = {
      'wallets': [viTuBackend(id: 'w-2', status: 'Active')],
    };
    await runSync();
    expect((await db.walletDao.getById('w-2'))!.status, 'active',
        reason: 'Bỏ lưu trữ trên máy A cũng phải lan sang máy B. Thiếu chiều '
            'này là đồng bộ một chiều rưỡi: ví đóng băng được ở mọi máy nhưng '
            'chỉ mở lại được ở đúng máy đã bấm.');
  });

  test('server im lặng (thiếu khoá) → GIỮ NGUYÊN trạng thái cục bộ', () async {
    await hangCucBoDangLuuTru('w-3');
    client.adapter.pullData = {
      'wallets': [viTuBackend(id: 'w-3')],
    };
    await runSync();
    expect((await db.walletDao.getById('w-3'))!.status, 'inactive',
        reason: 'Cột Status của server hiện NOT NULL nên nó luôn trả giá trị; '
            'ca này canh lớp phòng thủ trước một bản backend không trả khoá '
            'ấy. Đọc thẳng null thành "hoạt động" là đánh thức mọi ví lưu trữ '
            'ngay lượt pull đầu tiên — im lặng.');
  });

  test('server trả null tường minh → cũng giữ nguyên', () async {
    await hangCucBoDangLuuTru('w-4');
    client.adapter.pullData = {
      'wallets': [viTuBackend(id: 'w-4', status: null)],
    };
    await runSync();
    expect((await db.walletDao.getById('w-4'))!.status, 'inactive',
        reason: 'null và vắng mặt phải cùng nghĩa "chưa biết".');
  });

  test('giá trị lạ từ server đọc thành hoạt động', () async {
    await hangCucBoDangLuuTru('w-5');
    client.adapter.pullData = {
      'wallets': [viTuBackend(id: 'w-5', status: 'archived')],
    };
    await runSync();
    expect((await db.walletDao.getById('w-5'))!.status, 'active',
        reason: 'Cùng luật với WalletStatus.tuKhoa: giá trị lạ KHÔNG được giữ '
            'nguyên, vì giữ nguyên là để nó đi thẳng lên server rồi vỡ '
            'chk_wallet_status.');
  });
}
