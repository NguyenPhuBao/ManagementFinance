/// `getAll` / `watchAll` của `TransactionRepository` — Entity qua datasource (spec Entity Giao dịch + Ví 2026-10-14, 4.3), cho Trang chủ, Sổ giao dịch và màn Thêm giao dịch.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';

class _SyncEngineGia implements SyncEngine {
  @override
  void scheduleSync() {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl repo;
  final moc = DateTime(2026, 10, 10);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TransactionRepositoryImpl(
      localDataSource: TransactionLocalDataSourceImpl(db),
      syncEngine: _SyncEngineGia(),
      soDuVi: SoDuViService(db: db),
    );
    await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: 'w1', idaccount: 10, name: 'Tiền mặt', updatedAt: moc));
    for (final (id, acc) in [('t1', 10), ('t2', 10), ('t3', 11)]) {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: id,
            idaccount: acc,
            walletId: 'w1',
            amount: 50000,
            type: 'chi',
            date: moc,
            updatedAt: moc,
          ));
    }
  });
  tearDown(() => db.close());

  test('getAll / watchAll lọc theo tài khoản, trả Entity', () async {
    expect((await repo.getAll(10)).map((t) => t.id), containsAll(['t1', 't2']));
    expect((await repo.getAll(10)).length, 2);
    expect((await repo.watchAll(10).first).length, 2);
    expect(await repo.getAll(11), hasLength(1));
  });
}
