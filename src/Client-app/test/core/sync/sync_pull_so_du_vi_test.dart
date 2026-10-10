/// Nhánh kéo về **không** ghi đè `wallets.balance`, và **có** tính lại số dư
/// cho ví có giao dịch vừa về.
///
/// Đây là hai nửa của **G37**, đo thật trên hai máy ảo ngày 2026-09-13:
///
/// - nửa đầu — máy trả hoá đơn → ví bị trừ còn 1.650.000 → push ví **xung đột**
///   → pull ghi đè về 2.000.000 → **lần trừ biến mất không dấu vết**, mà hàng
///   vừa bị đánh dấu `synced` nên cũng không còn gì để đẩy lại;
/// - nửa sau — nhánh pull giao dịch chỉ `upsertAll` vào bảng, **không đụng số
///   dư** (đo: 0 dòng), nên giao dịch của máy khác về tới nơi mà số dư máy này
///   không đổi. Số dư khi ấy chỉ đúng nhờ đồng bộ chính cột `balance` theo LWW
///   — đúng thứ nửa đầu vừa bỏ.
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
import 'package:flowmoney/features/wallet/data/services/so_du_vi_service.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';

const accountId = 7;
const idVi = '11111111-1111-4111-8111-111111111111';

/// Số dư máy này vừa ghi sau khi trả hoá đơn.
const soDuCucBo = 1650000.0;

/// Số dư server còn giữ — bản chưa biết tới lần trả ấy.
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
  _Client(this.adapter) {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
  final _Adapter adapter;
}

class _Adapter implements HttpClientAdapter {
  _Adapter({this.giaoDichTuMayKhac, this.coVi = true});

  /// `false` = lượt kéo không trả ví nào (chỉ giao dịch).
  final bool coVi;

  /// Khoản chi mà "máy khác" vừa ghi, nếu có.
  final Map<String, dynamic>? giaoDichTuMayKhac;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/pull')) {
      return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'wallets': [
              if (coVi)
                {
                  'idwallet': idVi,
                  'idaccount': accountId,
                  'name': 'Tiền mặt',
                  'type': 'Cash',
                  'balance': soDuServer,
                  'update_at': DateTime.now().toIso8601String(),
                }
            ],
            if (giaoDichTuMayKhac != null)
              'transactions': [giaoDichTuMayKhac],
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
              .map((op) => {'localId': op['localId'], 'status': 'synced'})
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

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.walletDao.insert(WalletsCompanion(
      id: const Value(idVi),
      idaccount: const Value(accountId),
      name: const Value('Tiền mặt'),
      type: const Value('cash'),
      balance: const Value(soDuCucBo),
      syncStatus: const Value('synced'),
      updatedAt: Value(DateTime.now()),
    ));
  });

  tearDown(() => db.close());

  Future<void> chayMotChuKy(_Adapter adapter) async {
    final engine = SyncEngine(
      dioClient: _Client(adapter),
      db: db,
      connectivity: _Online(),
      soDuVi: SoDuViService(db: db),
    );
    final xong = engine.statusStream.where((s) => s.isTerminal).first;
    engine.start(idaccount: accountId);
    await xong.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    engine.dispose();
  }

  test('pull KHÔNG ghi đè số dư bằng con số của server', () async {
    await chayMotChuKy(_Adapter());

    expect((await db.walletDao.getById(idVi))!.balance, soDuCucBo,
        reason: 'Số dư nay suy từ sổ giao dịch, nên con số của server chỉ là '
            'ảnh chụp cũ. Đọc nó về là nuốt mọi thay đổi cục bộ chưa kịp đẩy — '
            'đúng cơ chế của G37: ví bị trừ còn 1.650.000, push xung đột, pull '
            'ghi đè về 2.000.000, lần trừ biến mất.');
  });

  test('giao dịch của MÁY KHÁC về thì số dư máy này đổi theo', () async {
    // Ví có neo 1.650.000 trước đã, đúng như mọi ví thật.
    await SoDuViService(db: db).datNeoNhieuVi({idVi});

    await chayMotChuKy(_Adapter(giaoDichTuMayKhac: {
      'idtran': 'tx-may-khac',
      'idaccount': accountId,
      'idwallet': idVi,
      'amount': -350000,
      'type': 'Transaction',
      'DateTransaction': DateTime(2026, 9, 13).toIso8601String(),
      'update_at': DateTime.now().toIso8601String(),
    }));

    expect((await db.walletDao.getById(idVi))!.balance, 1300000.0,
        reason: 'ĐÂY LÀ CA ĐÓNG G37. Trước bản này, giao dịch của máy khác về '
            'tới SQLite mà số dư không hề đổi — nhánh pull chỉ `upsertAll` vào '
            'bảng giao dịch, không đụng `balance`. Số dư chỉ đúng nhờ đồng bộ '
            'chính cột `balance` theo LWW, và đó là thứ ca trên vừa bỏ.');
  });

  test('khoản mở sổ vẫn còn nguyên sau một chu kỳ', () async {
    await SoDuViService(db: db).datNeoNhieuVi({idVi});
    await chayMotChuKy(_Adapter());

    final neo = await db.transactionDao.getById(idKhoanMoSo(idVi));
    expect(neo, isNotNull,
        reason: 'Neo là một giao dịch bình thường; một chu kỳ đồng bộ không '
            'được làm gì nó. Mất neo là số dư tụt đúng bằng số dư ban đầu.');
  });

  // ── Nghiệm thu G67 trên hai máy ảo, 2026-10-08 ──────────────────────────
  //
  // Ví seed (server tạo khi đăng ký) KHÔNG có khoản mở sổ trên máy nào. Máy B
  // chi 11.000 lúc offline; bật mạng, kéo về khoản 22.000 của máy A. Vá neo SAU
  // khi ghi sổ cho neo = −11.000 − (−33.000) = +22.000: khoản chi của máy kia
  // biến mất, cả hai máy hiện −11.000.
  test('⭐ ví CHƯA có neo nhận giao dịch máy khác: neo không nuốt giao dịch ấy',
      () async {
    await (db.update(db.wallets)..where((w) => w.id.equals(idVi)))
        .write(const WalletsCompanion(balance: Value(-11000)));
    await db.transactionDao.insert(TransactionsCompanion.insert(
      id: 'tx-may-nay',
      walletId: idVi,
      idaccount: accountId,
      amount: 11000,
      type: 'chi',
      date: DateTime(2026, 10, 8),
      syncStatus: const Value('synced'),
      updatedAt: DateTime.now(),
    ));

    await chayMotChuKy(_Adapter(giaoDichTuMayKhac: {
      'idtran': 'tx-may-khac',
      'idaccount': accountId,
      'idwallet': idVi,
      'amount': -22000,
      'type': 'Transaction',
      'DateTransaction': DateTime(2026, 10, 8).toIso8601String(),
      'update_at': DateTime.now().toIso8601String(),
    }));

    expect(await db.transactionDao.getById(idKhoanMoSo(idVi)), isNull,
        reason: 'Sổ máy này đã khớp số dư (−11.000) trước lượt kéo — không có '
            'số dư ban đầu nào để neo.');
    expect((await db.walletDao.getById(idVi))!.balance, -33000.0,
        reason: 'Vá neo sau khi ghi sổ là neo +22.000 nuốt khoản chi của máy '
            'kia — đo thật trên hai máy ảo.');
  });

  test('khoản CHUYỂN từ máy khác về: ví ĐÍCH cũng được tính lại', () async {
    await SoDuViService(db: db).datNeoNhieuVi({idVi});
    await db.walletDao.insert(WalletsCompanion(
      id: const Value('33333333-3333-4333-8333-333333333333'),
      idaccount: const Value(accountId),
      name: const Value('Ngân hàng'),
      type: const Value('bank'),
      balance: const Value(0),
      syncStatus: const Value('synced'),
      updatedAt: Value(DateTime.now()),
    ));

    await chayMotChuKy(_Adapter(coVi: false, giaoDichTuMayKhac: {
      'idtran': 'tx-chuyen-den',
      'idaccount': accountId,
      'idwallet': '33333333-3333-4333-8333-333333333333',
      'idwallet_transfer': idVi,
      'amount': 100000,
      'type': 'Transfer',
      'DateTransaction': DateTime(2026, 10, 8).toIso8601String(),
      'update_at': DateTime.now().toIso8601String(),
    }));

    expect((await db.walletDao.getById(idVi))!.balance, 1750000.0,
        reason: '`tongTheoVi` cộng khoản chuyển đến, nên ví đích phải nằm trong '
            'tập tính lại — trước đây chỉ ví nguồn được tính.');
  });

  test('ví MỚI về từ máy khác KHÔNG bị vá neo — nếu không số dư về 0', () async {
    // Ví này chưa có trên máy: nó đến cùng lượt pull, kèm cả sổ của nó.
    const idViMoi = '22222222-2222-4222-8222-222222222222';
    final adapter = _AdapterViMoi(idViMoi);

    await chayMotChuKy2(db, adapter);

    expect((await db.walletDao.getById(idViMoi))!.balance, 2000000.0,
        reason: 'ĐÃ VẤP THẬT trên hai máy ảo ngày 2026-09-13: ví vừa INSERT '
            'mang `balance = 0` (nhánh pull thôi đọc cột ấy) trong khi sổ của '
            'nó đã đầy đủ. Vá neo cho nó là sinh một khoản CHI đúng bằng cả '
            'tổng sổ — ví 2.000.000 hiện thành 0đ ngay sau lần pull đầu.');
  });
}

/// Server trả về một ví CHƯA có trên máy, kèm khoản mở sổ của chính nó.
class _AdapterViMoi implements HttpClientAdapter {
  _AdapterViMoi(this.idViMoi);
  final String idViMoi;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path.contains('/sync/pull')) {
      return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'wallets': [
              {
                'idwallet': idViMoi,
                'idaccount': accountId,
                'name': 'Ví từ máy khác',
                'type': 'Cash',
                'balance': 2000000,
                'update_at': DateTime.now().toIso8601String(),
              }
            ],
            'transactions': [
              {
                'idtran': idKhoanMoSo(idViMoi),
                'idaccount': accountId,
                'idwallet': idViMoi,
                'amount': 2000000,
                'type': 'Transaction',
                'note': tienToMoSo,
                'DateTransaction': DateTime(2026, 9, 13).toIso8601String(),
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
    return ResponseBody.fromString(
      jsonEncode({'status': 'success', 'results': []}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json']
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Chạy một chu kỳ với adapter bất kỳ.
Future<void> chayMotChuKy2(AppDatabase db, HttpClientAdapter adapter) async {
  final client = _ClientChung(adapter);
  final engine = SyncEngine(
    dioClient: client,
    db: db,
    connectivity: _Online(),
    soDuVi: SoDuViService(db: db),
  );
  final xong = engine.statusStream.where((s) => s.isTerminal).first;
  engine.start(idaccount: accountId);
  await xong.timeout(const Duration(seconds: 5));
  await Future<void>.delayed(const Duration(milliseconds: 50));
  engine.dispose();
}

class _ClientChung implements DioClient {
  _ClientChung(HttpClientAdapter adapter) {
    dio.httpClientAdapter = adapter;
  }
  @override
  final Dio dio = Dio();
}
