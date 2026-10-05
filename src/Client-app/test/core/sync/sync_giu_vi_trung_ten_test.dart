/// G63 — `_collectPendingOps` GIỮ ví bị từ chối vì trùng tên cùng mọi thứ dính tới nó (spec mục 4.4).
///
/// Trước bản này: ví R bị `WALLET_NAME_DUPLICATE` chặn theo giờ rồi gửi lại mãi, còn giao dịch của R vỡ khoá ngoại
/// (`transient`) và được gửi lại ở MỌI chu kỳ — mỗi chu kỳ kết thúc bằng lỗi, giãn cách luỹ tiến làm chậm mọi dữ liệu
/// khác (đo trên Realme 2026-10-03: "10 failed" từ 28/09).
library;

import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

const acc = 7;
const idP = 'aaaaaaaa-0000-4000-8000-000000000001';
const idR = 'aaaaaaaa-0000-4000-8000-000000000002';

class _Online implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Adapter implements HttpClientAdapter {
  final daDay = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    const json = {
      Headers.contentTypeHeader: ['application/json']
    };
    if (o.path.contains('/sync/pull')) {
      return ResponseBody.fromString(jsonEncode({'data': {}}), 200, headers: json);
    }
    if (o.path.contains('/sync/push')) {
      final ops = (o.data as Map<String, dynamic>)['operations'] as List<dynamic>;
      daDay.addAll(ops.map((op) => op['localId'] as String));
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'results': [
            for (final op in ops) {'localId': op['localId'], 'status': 'synced'}
          ],
        }),
        200,
        headers: json,
      );
    }
    return ResponseBody.fromString('{}', 404);
  }

  @override
  void close({bool force = false}) {}
}

class _Client implements DioClient {
  _Client(HttpClientAdapter a) {
    dio.httpClientAdapter = a;
  }
  @override
  final Dio dio = Dio();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final ngay = DateTime(2026, 10, 5);

  Future<void> vi(String id, String ten, {String sync = 'pending'}) => db.walletDao.insert(
      WalletsCompanion.insert(id: id, idaccount: acc, name: ten, syncStatus: Value(sync), updatedAt: ngay));

  Future<void> gd(String id, String viNguon, {String? viNhan, String? billId, String? goalId}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: viNguon,
        idaccount: acc,
        amount: 1000,
        type: viNhan == null ? 'chi' : 'transfer',
        date: ngay,
        walletTransfer: Value(viNhan),
        billId: Value(billId),
        goalId: Value(goalId),
        syncStatus: const Value('pending'),
        updatedAt: ngay,
      ));

  Future<void> hd(String id, String viTra, {String? truocDo}) => db.billDao.insert(BillsCompanion.insert(
        id: id,
        idaccount: acc,
        name: 'Hoá đơn $id',
        amount: 1000,
        dueDate: ngay,
        walletId: Value(viTra),
        generatedFromBillId: Value(truocDo),
        syncStatus: const Value('pending'),
        updatedAt: ngay,
      ));

  Future<void> mt(String id, String viNhan, {String? viNguon}) => db.goalDao.insert(GoalsCompanion.insert(
        id: id,
        idaccount: acc,
        name: 'Mục tiêu $id',
        targetAmount: 1000000,
        targetDate: DateTime(2027, 1, 1),
        walletId: Value(viNhan),
        autoDepositWalletId: Value(viNguon),
        autoDepositAmount: Value(viNguon == null ? null : 100000),
        autoDepositLastRun: Value(viNguon == null ? null : ngay),
        syncStatus: const Value('pending'),
        updatedAt: ngay,
      ));

  Future<List<String>> chayMotChuKy() async {
    final a = _Adapter();
    final engine = SyncEngine(dioClient: _Client(a), db: db, connectivity: _Online());
    final xong = engine.statusStream.where((s) => s.isTerminal).first;
    unawaited(engine.start(idaccount: acc));
    await xong.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    engine.dispose();
    return a.daDay;
  }

  test('⭐ ví bị giữ và MỌI thứ dính tới nó không lên lô; thứ không dính thì lên', () async {
    await vi(idP, 'Ví MB Bank', sync: 'synced');
    await vi(idR, 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen(idR);

    await gd('t-r', idR); // ví nguồn bị giữ
    await gd('t-den-r', idP, viNhan: idR); // ví nhận bị giữ
    await hd('b-r', idR); // hoá đơn ở ví bị giữ
    await hd('b-sau', idP, truocDo: 'b-r'); // kỳ sau nối từ hoá đơn bị giữ
    await gd('t-b-sau', idP, billId: 'b-sau'); // khoản trả của hoá đơn bị giữ
    await mt('g-nguon-r', idP, viNguon: idR); // mục tiêu trích từ ví bị giữ
    await gd('t-g', idP, goalId: 'g-nguon-r'); // khoản nạp của mục tiêu bị giữ

    await gd('t-p', idP); // không dính → phải lên
    await hd('b-p', idP);
    await mt('g-p', idP);

    final daDay = await chayMotChuKy();

    expect(daDay.toSet(), {'t-p', 'b-p', 'g-p'},
        reason: 'Gửi bất cứ thứ gì dính tới ví bị giữ là vỡ khoá ngoại ở MỌI chu kỳ — đúng vòng lặp G63.');
  });

  test('cờ mà KHÔNG còn ví cùng tên → ví được đẩy (bẫy 2)', () async {
    await vi(idR, 'Ví MB Bank');
    await db.walletDao.danhDauTrungTen(idR);
    await gd('t-r', idR);

    final daDay = await chayMotChuKy();

    expect(daDay, containsAll([idR, 't-r']));
  });

  test('hai ví cùng tên mà KHÔNG mang cờ → ví được đẩy như thường', () async {
    await vi(idP, 'Ví MB Bank', sync: 'synced');
    await vi(idR, 'Ví MB Bank');

    final daDay = await chayMotChuKy();

    expect(daDay, contains(idR),
        reason: 'Chưa bị server từ chối thì chưa có gì để giữ — giữ ở đây là ví không bao giờ được thử.');
  });
}
