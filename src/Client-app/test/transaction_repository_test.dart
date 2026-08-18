import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/transaction/data/datasources/transaction_local_data_source.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';

class DummySyncEngine implements SyncEngine {
  bool syncScheduled = false;
  @override
  Future<void> scheduleSync() async {
    syncScheduled = true;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late TransactionLocalDataSource localDataSource;
  late DummySyncEngine syncEngine;
  late TransactionRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    localDataSource = TransactionLocalDataSourceImpl(db);
    syncEngine = DummySyncEngine();
    repository = TransactionRepositoryImpl(
      localDataSource: localDataSource,
      walletDao: db.walletDao,
      syncEngine: syncEngine,
    );

    // Create initial wallet
    await db.walletDao.insert(
      WalletsCompanion(
        id: const Value('w1'),
        idaccount: const Value(1),
        name: const Value('Ví Tiền Mặt'),
        type: const Value('cash'),
        balance: const Value(1000000.0),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Create destination wallet for transfer
    await db.walletDao.insert(
      WalletsCompanion(
        id: const Value('w2'),
        idaccount: const Value(1),
        name: const Value('Ví Ngan Hang'),
        type: const Value('bank'),
        balance: const Value(500000.0),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Adding expense (chi) transaction deducts balance from wallet', () async {
    final tx = TransactionEntity(
      id: 't1',
      walletId: 'w1',
      idaccount: 1,
      categoryId: 'c1',
      amount: 100000.0,
      type: 'chi',
      note: 'Coffee',
      date: DateTime.now(),
      images: const [],
      syncStatus: 'pending',
      isDeleted: false,
      updatedAt: DateTime.now(),
    );

    await repository.addTransaction(tx);

    final wallet = await db.walletDao.getById('w1');
    expect(wallet?.balance, equals(900000.0));
    expect(syncEngine.syncScheduled, isTrue);
  });

  test('Adding income (thu) transaction increases balance of wallet', () async {
    final tx = TransactionEntity(
      id: 't2',
      walletId: 'w1',
      idaccount: 1,
      categoryId: 'c2',
      amount: 500000.0,
      type: 'thu',
      note: 'Bonus',
      date: DateTime.now(),
      images: const [],
      syncStatus: 'pending',
      isDeleted: false,
      updatedAt: DateTime.now(),
    );

    await repository.addTransaction(tx);

    final wallet = await db.walletDao.getById('w1');
    expect(wallet?.balance, equals(1500000.0));
  });

  test('Transfer transaction moves balance between source and destination wallets', () async {
    final tx = TransactionEntity(
      id: 't3',
      walletId: 'w1',
      idaccount: 1,
      categoryId: 'cat_transfer',
      amount: 200000.0,
      type: 'transfer',
      note: 'Chuyen tien',
      date: DateTime.now(),
      images: const [],
      syncStatus: 'pending',
      isDeleted: false,
      updatedAt: DateTime.now(),
    );

    await repository.addTransaction(tx, destinationWalletId: 'w2');

    final w1 = await db.walletDao.getById('w1');
    final w2 = await db.walletDao.getById('w2');
    expect(w1?.balance, equals(800000.0));
    expect(w2?.balance, equals(700000.0));
  });
}
