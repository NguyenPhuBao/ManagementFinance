/// `SyncEngine` phải phát kết quả đẩy **TRƯỚC** khi nhánh kéo về ghi đè SQLite.
///
/// Vì sao thứ tự này là một cam kết chứ không phải chi tiết nội bộ: người nghe
/// `pushResultStream` phản ứng với **thất bại** của lần đẩy, và phản ứng ấy
/// thường phải bù lại một thay đổi cục bộ mà chính máy này vừa ghi. Nhánh kéo
/// về ở giữa có thể đã thay đúng hàng ấy bằng bản của server — khi đó phép bù
/// cộng vào một con số **không hề chứa** thay đổi cần bù.
///
/// ⚠️ ĐÃ VẤP THẬT trên hai máy ảo ngày 2026-09-13, và không một ca test nào
/// trong 2303 ca thấy được — đúng **loại lỗi thứ ba** ở mục "Ba loại lỗi
/// `flutter test` KHÔNG bắt được" của `CLAUDE.md`: thứ tự thực tế giữa hai
/// luồng bất đồng bộ.
///
/// Chuỗi đo được, hoá đơn tự động trả trên hai máy cùng một tài khoản:
///   1. máy trả hoá đơn  → ví bị trừ 350.000, còn 1.650.000 (`pending`);
///   2. push ví → **xung đột**, server giữ 2.000.000 và client `markSynced`;
///   3. pull ghi đè ví về **2.000.000** — lần trừ biến mất không dấu vết;
///   4. `pushResultStream` phát `BILL_ALREADY_PAID`, resolver hoàn 350.000
///      → ví thành **2.350.000**.
/// Ví phình thêm đúng một lần trả, im lặng, không lỗi nào báo ra.
library;

import 'dart:async';
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

const accountId = 7;
const idVi = '11111111-1111-4111-8111-111111111111';

/// Số dư mà **máy này** vừa ghi sau khi trả hoá đơn.
const soDuCucBo = 1650000.0;

/// Số dư mà **server** còn giữ — bản chưa biết tới lần trả ấy.
const soDuServer = 2000000.0;

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

/// Server trả về đúng hình dạng đã gây ra sự việc: pull mang số dư CŨ về, còn
/// push thì từ chối.
class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/pull')) {
      return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'wallets': [
              {
                'idwallet': idVi,
                'idaccount': accountId,
                'name': 'Tiền mặt',
                'type': 'Cash',
                'balance': soDuServer,
                'update_at': DateTime.now().toIso8601String(),
              }
            ],
          }
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    if (o.path.contains('/sync/push')) {
      final ops =
          (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': ops
              .map((op) => {
                    'localId': op['localId'],
                    'status': 'failed',
                    'code': 'BILL_ALREADY_PAID',
                    'message': 'Hóa đơn đã được thanh toán bằng một giao dịch khác',
                  })
              .toList(),
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString('{}', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late _Client client;
  late SyncEngine engine;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = _Client();
    engine = SyncEngine(dioClient: client, db: db, connectivity: _Online());

    await db.walletDao.insert(WalletsCompanion(
      id: const Value(idVi),
      idaccount: const Value(accountId),
      name: const Value('Tiền mặt'),
      type: const Value('cash'),
      balance: const Value(soDuCucBo),
      syncStatus: const Value('pending'),
      updatedAt: Value(DateTime.now()),
    ));
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  test('lúc kết quả đẩy được phát, nhánh kéo về CHƯA ghi đè số dư ví', () async {
    // Người nghe đọc SQLite ngay tại khoảnh khắc nhận sự kiện — đúng những gì
    // `BillPaymentConflictResolver` làm.
    double? soDuLucNhan;
    final sub = engine.pushResultStream.listen((_) async {
      soDuLucNhan ??= (await db.walletDao.getById(idVi))?.balance;
    });

    final xong = engine.statusStream.where((s) => s.isTerminal).first;
    engine.start(idaccount: accountId);
    await xong.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(soDuLucNhan, soDuCucBo,
        reason: 'Người nghe phải thấy số dư mà MÁY NÀY vừa ghi, chưa bị bản của '
            'server đè lên. Thấy $soDuServer nghĩa là nhánh kéo về đã chạy '
            'trước, và mọi phép bù dựa trên nó đều cộng vào một con số không '
            'chứa thay đổi cần bù — ví phình thêm đúng một lần trả, im lặng.');
  });

  test('kết quả đẩy vẫn được phát đủ, không mất sự kiện nào', () async {
    final thu = <SyncResult>[];
    final sub = engine.pushResultStream.listen(thu.add);

    final xong = engine.statusStream.where((s) => s.isTerminal).first;
    engine.start(idaccount: accountId);
    await xong.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(thu, isNotEmpty,
        reason: 'Đổi thời điểm phát không được làm mất kênh: giao diện dựa vào '
            'nó để nói "đã đưa N thay đổi lên server", và resolver dựa vào nó '
            'để biết khoản trả nào bị từ chối.');
    expect(thu.first.failed, greaterThan(0),
        reason: 'Và nội dung phải là kết quả THẬT của lần đẩy.');
  });
}
