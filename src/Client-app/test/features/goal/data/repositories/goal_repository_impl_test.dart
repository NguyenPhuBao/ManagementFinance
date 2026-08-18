import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/goal/data/datasources/goal_local_data_source.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository_impl.dart';

void main() {
  late AppDatabase db;
  late GoalRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = GoalRepositoryImpl(
      localDataSource: GoalLocalDataSourceImpl(db: db),
      db: db,
    );

    // Setup initial wallet & goal
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w1',
        idaccount: 1,
        name: 'Ví Tết',
        balance: const Value(5000000.0),
        updatedAt: DateTime.now(),
      ),
    );

    await db.goalDao.insert(
      GoalsCompanion.insert(
        id: 'g1',
        idaccount: 1,
        name: 'Mua Laptop',
        targetAmount: 20000000.0,
        currentAmount: const Value(2000000.0),
        targetDate: DateTime.now().add(const Duration(days: 90)),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('depositToGoal updates goal currentAmount, deducts wallet balance, creates transaction', () async {
    await repository.depositToGoal(
      goalId: 'g1',
      goalName: 'Mua Laptop',
      depositAmount: 1000000.0,
      walletId: 'w1',
      idaccount: 1,
    );

    final goal = await repository.getGoalById('g1');
    expect(goal?.currentAmount, 3000000.0);

    final wallet = await db.walletDao.getById('w1');
    expect(wallet?.balance, 4000000.0);

    final txs = await db.transactionDao.getAll(1);
    expect(txs.length, 1);
    expect(txs.first.amount, 1000000.0);
    expect(txs.first.note, 'Tích lũy mục tiêu: Mua Laptop');
  });

  test('depositToGoal with targetWalletId deducts source wallet and credits target wallet', () async {
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w2_savings',
        idaccount: 1,
        name: 'Ví Tiết Kiệm',
        balance: const Value(1000000.0),
        updatedAt: DateTime.now(),
      ),
    );

    await repository.depositToGoal(
      goalId: 'g1',
      goalName: 'Mua Laptop',
      depositAmount: 1000000.0,
      walletId: 'w1',
      targetWalletId: 'w2_savings',
      idaccount: 1,
    );

    final sourceWallet = await db.walletDao.getById('w1');
    expect(sourceWallet?.balance, 4000000.0);

    final targetWallet = await db.walletDao.getById('w2_savings');
    expect(targetWallet?.balance, 2000000.0);

    final txs = await db.transactionDao.getAll(1);
    expect(txs.length, 2);
  });
}
