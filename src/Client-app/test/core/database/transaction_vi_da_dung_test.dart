/// `TransactionDao.viDaDung` — id các ví đã có ít nhất một giao dịch còn sống, theo **bất kỳ vai** nào.
///
/// Nó là đầu vào của luật "Số dư ví sắp cạn": ví chưa từng dùng (tạo mới 0 đ) thì chưa từng có tiền để cạn,
/// nên không báo (đo Realme 2026-09-30 — tạo "Ví MB Bank" 0 đ là bị báo "chỉ còn 0 đồng" ngay). Hai vế dễ
/// sót, cùng họ lỗi mà `demGiaoDichLienQuan` đã vấp ngày 2026-09-18: ví **chỉ nhận tiền chuyển vào** vẫn là
/// ví đã dùng, và hàng **đã xoá mềm** không tính.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final id in ['a', 'b', 'c', 'd']) {
      await db.walletDao.insert(
          WalletsCompanion.insert(id: id, idaccount: 7, name: 'Ví $id', updatedAt: DateTime(2026, 9, 1)));
    }
  });

  tearDown(() => db.close());

  Future<void> them(String id, String vi, {String? viDen, bool daXoa = false, int idaccount = 7}) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: vi,
        idaccount: idaccount,
        amount: 10000,
        type: viDen == null ? 'chi' : 'transfer',
        walletTransfer: Value(viDen),
        date: DateTime(2026, 9, 2),
        isDeleted: Value(daXoa),
        deletedAt: daXoa ? Value(DateTime(2026, 9, 3)) : const Value.absent(),
        updatedAt: DateTime(2026, 9, 2),
      ));

  test('⭐ gồm ví nguồn VÀ ví đích của khoản chuyển; bỏ hàng đã xoá mềm và tài khoản khác', () async {
    await them('t1', 'a');
    await them('t2', 'a', viDen: 'b');
    await them('t3', 'c', daXoa: true);
    await them('t4', 'd', idaccount: 8);

    expect(await db.transactionDao.viDaDung(7), {'a', 'b'},
        reason: 'b chỉ NHẬN tiền chuyển vào vẫn là ví đã dùng; c chỉ có hàng đã xoá; d thuộc tài khoản khác');
  });

  test('tài khoản chưa có giao dịch nào → tập rỗng', () async {
    expect(await db.transactionDao.viDaDung(7), isEmpty);
  });
}
