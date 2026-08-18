import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/errors/app_exceptions.dart';
import 'package:flowmoney/features/wallet/data/datasources/wallet_local_data_source.dart';

void main() {
  late AppDatabase db;
  late WalletLocalDataSourceImpl dataSource;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = WalletLocalDataSourceImpl(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Cannot delete wallet with non-zero balance', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_balance',
        idaccount: 1,
        name: 'Ví Có Tiền',
        balance: const Value(500000.0),
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      () => dataSource.softDelete('w_balance'),
      throwsA(isA<CacheException>().having(
        (e) => e.message,
        'message',
        contains('đang có số dư'),
      )),
    );
  });

  test('Cannot delete wallet with existing transactions', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_tx',
        idaccount: 1,
        name: 'Ví Có Giao Dịch',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );

    await db.transactionDao.insert(
      TransactionsCompanion.insert(
        id: 'tx_1',
        idaccount: 1,
        walletId: 'w_tx',
        amount: 50000.0,
        type: 'chi',
        date: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      () => dataSource.softDelete('w_tx'),
      throwsA(isA<CacheException>().having(
        (e) => e.message,
        'message',
        contains('đã có 1 giao dịch phát sinh'),
      )),
    );
  });

  test('Cannot delete wallet linked to a Savings Goal', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_goal',
        idaccount: 1,
        name: 'Ví Mục Tiêu',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );

    await db.goalDao.insert(
      GoalsCompanion.insert(
        id: 'g_1',
        idaccount: 1,
        name: 'Mua Xe Máy',
        targetAmount: 30000000.0,
        targetDate: DateTime.now().add(const Duration(days: 30)),
        walletId: const Value('w_goal'),
        updatedAt: DateTime.now(),
      ),
    );

    expect(
      () => dataSource.softDelete('w_goal'),
      throwsA(isA<CacheException>().having(
        (e) => e.message,
        'message',
        contains('đang liên kết với mục tiêu "Mua Xe Máy"'),
      )),
    );
  });

  test('Successfully delete empty wallet with no transactions or linked goals', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w_empty',
        idaccount: 1,
        name: 'Ví Rỗng',
        balance: const Value(0.0),
        updatedAt: DateTime.now(),
      ),
    );

    await dataSource.softDelete('w_empty');

    final wallet = await db.walletDao.getById('w_empty');
    expect(wallet?.isDeleted, true);
  });
}
