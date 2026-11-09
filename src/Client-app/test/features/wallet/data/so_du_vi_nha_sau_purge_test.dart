/// Ví nhà được `purgeDataForOtherAccounts` giữ (hàng chưa đẩy của tôi, khi chưa biết nhà) nhưng sổ giao dịch đã đồng bộ của
/// nó bị cắt — `wallets.balance` còn là số CŨ. Lượt kéo toàn bộ đầu tiên đặt neo `balance − Σ sổ còn lại` (một khoản `thu`
/// `pending` có `idhousehold`), rồi sổ thật về → tiền cộng hai lần, và neo ấy còn bị đẩy cho cả nhà (đo của người soát
/// Task 4: 550.000 thay vì 250.000; 600.000 thay vì 300.000). Chữa: sau purge, [SoDuViService.tinhLaiViNha] tính lại số dư
/// mọi ví nhà theo sổ còn lại, để `balance − Σ sổ = 0` và không neo nào được đẻ.
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
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';

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
  const toi = 10, nguoiKhac = 20, nha = 7;
  final ngay = DateTime(2026, 10, 20);
  late AppDatabase db;
  late SoDuViService soDuVi;

  Future<void> dung({required String stVi, required bool coGdPending}) async {
    await db.walletDao.insert(WalletsCompanion(
        id: const Value('vn'),
        idaccount: const Value(toi),
        name: const Value('Quy chung'),
        idhousehold: const Value(nha),
        balance: Value(coGdPending ? 250000.0 : 300000.0),
        syncStatus: Value(stVi),
        updatedAt: Value(ngay)));
    await db.transactionDao.insert(TransactionsCompanion(
        id: const Value('g1'),
        idaccount: const Value(nguoiKhac),
        walletId: const Value('vn'),
        amount: const Value(300000),
        type: const Value('thu'),
        date: Value(ngay),
        idhousehold: const Value(nha),
        syncStatus: const Value('synced'),
        updatedAt: Value(ngay)));
    if (coGdPending) {
      await db.transactionDao.insert(TransactionsCompanion(
          id: const Value('p'),
          idaccount: const Value(toi),
          walletId: const Value('vn'),
          amount: const Value(50000),
          type: const Value('chi'),
          date: Value(ngay),
          idhousehold: const Value(nha),
          syncStatus: const Value('pending'),
          updatedAt: Value(ngay)));
    }
  }

  Future<void> keoToanBo() => ApDuLieuKeoVe(
        dioClient: _Client({
          'wallets': [
            {
              'idwallet': 'vn',
              'idaccount': toi,
              'idhousehold': nha,
              'name': 'Quy chung',
              'type': 'Cash',
              'update_at': '2026-10-20T00:00:00.000Z',
            }
          ],
          'transactions': [
            {
              'idtran': 'g1',
              'idaccount': nguoiKhac,
              'idhousehold': nha,
              'idwallet': 'vn',
              'amount': 300000,
              'type': 'Transaction',
              'date_transaction': '2026-10-20T00:00:00.000Z',
              'update_at': '2026-10-20T00:00:00.000Z',
            }
          ],
        }),
        db: db,
        soDuVi: soDuVi,
      ).pullFromBackend(toi);

  Future<Wallet> vi() async => (await db.walletDao.getById('vn'))!;
  Future<bool> coNeo() async => (await db.transactionDao.getById(idKhoanMoSo('vn'))) != null;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    soDuVi = SoDuViService(db: db, taiKhoanPhien: () => toi);
  });
  tearDown(() => db.close());

  test('ví nhà có khoản chưa đẩy: purge → tính lại → kéo toàn bộ = 250.000, không neo mới', () async {
    await dung(stVi: 'synced', coGdPending: true);
    await db.purgeDataForOtherAccounts(toi);
    await soDuVi.tinhLaiViNha();
    expect((await vi()).balance, -50000, reason: 'chỉ còn khoản chi chưa đẩy trong sổ');
    await keoToanBo();
    expect((await vi()).balance, 250000, reason: '300.000 thu của người khác + (−50.000) chưa đẩy; 550.000 là cộng hai lần');
    expect(await coNeo(), isFalse, reason: 'neo pending mới sẽ bị đẩy cho cả nhà');
    final hang = await db.select(db.transactions).get();
    expect(hang.where((t) => t.syncStatus == 'pending').map((t) => t.id), ['p'], reason: 'ngoài khoản của tôi không hàng pending nào mới');
  });

  test('chính ví đang pending, không khoản chưa đẩy: purge → tính lại → kéo toàn bộ = 300.000', () async {
    await dung(stVi: 'pending', coGdPending: false);
    await db.purgeDataForOtherAccounts(toi);
    await soDuVi.tinhLaiViNha();
    expect((await vi()).syncStatus, 'pending', reason: 'ví vẫn pending như trước — tính lại không được đổi trạng thái đồng bộ');
    await keoToanBo();
    expect((await vi()).balance, 300000, reason: '600.000 là số cũ + sổ thật');
    expect(await coNeo(), isFalse);
  });

  test('tính lại KHÔNG đánh pending ví đã synced (cucBo)', () async {
    await dung(stVi: 'synced', coGdPending: true);
    await db.purgeDataForOtherAccounts(toi);
    // Ví synced không được giữ nếu không có giao dịch chưa đẩy trỏ tới; ở đây có (p) nên được giữ.
    await soDuVi.tinhLaiViNha();
    expect((await vi()).syncStatus, 'synced');
  });

  test('luỹ đẳng: purge và tính lại hai lần ra cùng kết quả', () async {
    await dung(stVi: 'synced', coGdPending: true);
    await db.purgeDataForOtherAccounts(toi);
    await soDuVi.tinhLaiViNha();
    await db.purgeDataForOtherAccounts(toi);
    await soDuVi.tinhLaiViNha();
    await soDuVi.tinhLaiViNha();
    await keoToanBo();
    expect((await vi()).balance, 250000);
    expect(await coNeo(), isFalse);
  });

  test('tiến trình chết giữa chừng (purge xong, chưa tính lại): lần mở sau làm lại, kết quả đúng', () async {
    await dung(stVi: 'synced', coGdPending: true);
    await db.purgeDataForOtherAccounts(toi); // chết ở đây — balance còn số cũ 250.000
    expect((await vi()).balance, 250000);
    // Lần mở sau: kho vẫn vắng → purge (không xoá gì thêm) rồi tính lại, bất kể số hàng đã dọn.
    final daDon = await db.purgeDataForOtherAccounts(toi);
    expect(daDon, 0, reason: 'tiền đề: lần dọn thứ hai không xoá gì — tính lại không được phụ thuộc số này');
    await soDuVi.tinhLaiViNha();
    await keoToanBo();
    expect((await vi()).balance, 250000);
    expect(await coNeo(), isFalse);
  });
}
