/// Kiểm chứng việc phân loại lỗi đẩy dữ liệu.
///
/// Trước đây mọi thất bại đều như nhau: bản ghi giữ `pending` và được gửi lại
/// mỗi chu kỳ, kể cả khi thử lại chắc chắn vô ích. Với lỗi vỡ khoá ngoại
/// `fk_*_account` (tài khoản không còn tồn tại), vòng lặp đó chạy mãi mà người
/// dùng không hề được báo.
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
  final _FailingAdapter adapter;
}

/// Trả về lỗi [failureMessage] cho MỌI thao tác được đẩy lên, và đếm số lần
/// endpoint /sync/push được gọi.
class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.failureMessage);

  final String failureMessage;
  int pushCallCount = 0;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/push')) {
      pushCallCount++;
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': ops
              .map((op) => {
                    'localId': op['localId'],
                    'status': 'error',
                    'message': failureMessage,
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

class _Run {
  _Run({required this.adapter, required this.sessionInvalid});
  final _FailingAdapter adapter;
  final bool sessionInvalid;
}

void main() {
  const accountId = 9; // tài khoản đã bị xoá khỏi server
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// Tạo một danh mục đang chờ đồng bộ để chắc chắn có gì đó để đẩy lên.
  Future<void> seedPendingCategory() => db.categoryDao.insert(
        CategoriesCompanion.insert(
          id: 'fee25499-c4a9-4924-b69b-43081c563d95',
          idaccount: accountId,
          name: 'Danh mục mới',
          classify: 'chi',
          syncStatus: const Value('pending'),
          updatedAt: DateTime(2026, 9, 2),
        ),
      );

  Future<_Run> runWith(String message) async {
    final adapter = _FailingAdapter(message);
    final engine = SyncEngine(
      dioClient: _Client(adapter),
      db: db,
      connectivity: _Online(),
    );
    var signalled = false;
    final sub = engine.sessionInvalidStream.listen((_) => signalled = true);
    final done =
        engine.statusStream.where((s) => s == SyncStatus.idle).first;
    await engine.start(idaccount: accountId);
    await done.timeout(const Duration(seconds: 5));
    await sub.cancel();
    engine.dispose();
    return _Run(adapter: adapter, sessionInvalid: signalled);
  }

  test(
      'Vỡ khoá ngoại fk_*_account → phát tín hiệu phiên chết và KHÔNG thử lại',
      () async {
    await seedPendingCategory();

    final r = await runWith(
      'Invalid `prisma.category.create()` invocation\n'
      'Foreign key constraint violated on the constraint: `fk_category_account`',
    );

    expect(r.sessionInvalid, true,
        reason: 'Phải báo ra ngoài để AuthBloc xử lý, thay vì lặp im lặng');
    expect(r.adapter.pushCallCount, 1,
        reason: 'Trước đây điều kiện retry chỉ là `failed > 0` nên lỗi vĩnh '
            'viễn cũng bị gửi lại, nhân đôi số request hỏng mỗi chu kỳ');
  });

  test('Khoá ngoại KHÁC (fk_transaction_category) vẫn được thử lại', () async {
    await seedPendingCategory();

    final r = await runWith(
      'Foreign key constraint violated on the constraint: '
      '`fk_transaction_category`',
    );

    expect(r.sessionInvalid, false,
        reason: 'Đây chỉ là sai thứ tự đẩy, không phải phiên chết');
    expect(r.adapter.pushCallCount, 2,
        reason: 'Pull xong mới có UUID danh mục từ backend nên đáng thử lại');
  });

  test('Ownership mismatch KHÔNG bị coi là phiên chết', () async {
    await seedPendingCategory();

    final r = await runWith(
      'Ownership mismatch: payload.idaccount does not match token',
    );

    expect(r.sessionInvalid, false,
        reason: 'Đó là dòng dữ liệu sót của tài khoản khác — cần dọn dữ liệu, '
            'đăng xuất người dùng ở đây là sai');
    expect(r.adapter.pushCallCount, 1, reason: 'Lỗi vĩnh viễn → không thử lại');
  });
}
