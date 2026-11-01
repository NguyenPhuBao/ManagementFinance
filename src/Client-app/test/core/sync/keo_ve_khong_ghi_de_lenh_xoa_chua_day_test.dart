/// Kéo về không được ghi đè lệnh xoá còn chờ đẩy (vòng sửa 1 của Task 9): xoá mềm GIỮA lượt đẩy và lượt kéo — server còn bản
/// sống nên `/sync/pull` trả nó về, `upsertAll` ghi `isDeleted: false, deletedAt: null, synced` và lệnh xoá mất; số dư tính
/// lại trừ lần nữa. Không dính gia đình: bất kỳ giao dịch nào cũng vậy.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/ap_du_lieu_keo_ve.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';

class _Client implements DioClient {
  _Client(Map<String, dynamic> pull) {
    dio.httpClientAdapter = _Adapter(pull);
  }
  @override
  final Dio dio = Dio();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.pull);
  final Map<String, dynamic> pull;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode({'data': pull}), 200, headers: {
        Headers.contentTypeHeader: ['application/json']
      });
  @override
  void close({bool force = false}) {}
}

void main() {
  const toi = 10;
  late AppDatabase db;
  late SoDuViService soDuVi;
  final ngay = DateTime(2026, 11, 1, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    soDuVi = SoDuViService(db: db, taiKhoanPhien: () => toi);
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'v', idaccount: toi, name: 'Ví', balance: const Value(1000), updatedAt: DateTime(2026, 10, 1)));
  });
  tearDown(() => db.close());

  Future<void> themGd(String id, {required bool xoa, required String trangThai}) =>
      db.transactionDao.insert(TransactionsCompanion(
        id: Value(id),
        idaccount: const Value(toi),
        walletId: const Value('v'),
        amount: const Value(500),
        type: const Value('chi'),
        date: Value(ngay),
        isDeleted: Value(xoa),
        deletedAt: Value(xoa ? ngay : null),
        syncStatus: Value(trangThai),
        updatedAt: Value(ngay),
      ));

  Future<void> keo(List<String> ids) => ApDuLieuKeoVe(
        dioClient: _Client({
          'transactions': [
            for (final id in ids)
              {
                'idtran': id,
                'idaccount': toi,
                'idwallet': 'v',
                'amount': -500,
                'type': 'Transaction',
                'date_transaction': ngay.toUtc().toIso8601String(),
                'update_at': ngay.toUtc().toIso8601String(),
              }
          ],
        }),
        db: db,
        soDuVi: soDuVi,
      ).pullFromBackend(toi);

  test('hàng đã xoá mềm và lệnh xoá còn pending: kéo về bản sống KHÔNG làm nó sống lại, vẫn pending để đẩy', () async {
    await themGd('a', xoa: true, trangThai: 'pending');
    await keo(['a']);
    final a = (await db.transactionDao.getById('a'))!;
    expect(a.isDeleted, isTrue, reason: 'lệnh xoá chưa đẩy thắng bản sống server trả về');
    expect(a.deletedAt, isNotNull);
    expect(a.syncStatus, 'pending', reason: 'còn pending thì lượt đẩy sau mang lệnh xoá lên');
  });

  test('chỉ bỏ hàng xoá-chưa-đẩy: hàng khác trong cùng lô vẫn được ghi, hàng xoá đã đẩy (synced) vẫn bị bản server ghi đè', () async {
    await themGd('a', xoa: true, trangThai: 'pending');
    await themGd('b', xoa: true, trangThai: 'synced');
    await keo(['a', 'b', 'moi']);
    expect((await db.transactionDao.getById('a'))!.isDeleted, isTrue);
    expect((await db.transactionDao.getById('b'))!.isDeleted, isFalse, reason: 'lệnh xoá đã lên server mà server vẫn trả sống: server thắng như cũ');
    expect(await db.transactionDao.getById('moi'), isNotNull, reason: 'hàng mới vẫn về');
  });
}
