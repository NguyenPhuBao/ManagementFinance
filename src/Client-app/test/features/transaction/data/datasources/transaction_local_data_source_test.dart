/// `getAll` / `watchAll` của `TransactionLocalDataSource` (spec Entity Giao dịch + Ví 2026-10-14, 4.2): map
/// `transactionDao.getAll` / `watchAll` sang Entity — DAO đã lọc tài khoản, bỏ hàng `deletedAt`, xếp `date` giảm dần;
/// ba điều ấy canh ở đây vì datasource dựa vào chúng.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TransactionLocalDataSourceImpl ds;
  final moc = DateTime(2026, 10, 10);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = TransactionLocalDataSourceImpl(db);
    await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: 'w1', idaccount: 10, name: 'Tiền mặt', updatedAt: moc));
    for (final (id, acc, ngay, xoa) in [
      ('t1', 10, moc, false),
      ('t2', 10, moc.add(const Duration(days: 1)), false),
      ('t3', 11, moc, false),
      ('t4', 10, moc, true),
    ]) {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: id,
            idaccount: acc,
            walletId: 'w1',
            amount: 50000,
            type: 'chi',
            date: ngay,
            updatedAt: moc,
            deletedAt: Value(xoa ? moc : null),
          ));
    }
  });
  tearDown(() => db.close());

  test('getAll: đúng tài khoản, bỏ hàng deletedAt, date giảm dần, trả Entity',
      () async {
    final ds10 = await ds.getAll(10);
    expect(ds10.map((t) => t.id), ['t2', 't1']);
    expect(await ds.getAll(11), hasLength(1));
  });

  test('watchAll: cùng luật, dạng stream', () async {
    expect((await ds.watchAll(10).first).map((t) => t.id), ['t2', 't1']);
  });
}
