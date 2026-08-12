import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/goal/data/datasources/goal_local_data_source.dart';
import 'package:flowmoney/features/goal/data/repositories/goal_repository_impl.dart';

void main() {
  late AppDatabase db;
  late GoalRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = GoalRepositoryImpl(
      localDataSource: GoalLocalDataSourceImpl(db: db),
      db: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Full Goal Lifecycle: Create -> Deposit -> Wallet Deduction -> Pending Sync check', () async {
    // 1. Setup Wallet
    await db.walletDao.insert(
      WalletsCompanion.insert(
        id: 'w10',
        idaccount: 1,
        name: 'Ví Tiết Kiệm',
        balance: const Value(10000000.0),
        updatedAt: DateTime.now(),
      ),
    );

    // 2. Add Goal
    final goal = await repository.addGoal(
      idaccount: 1,
      name: 'Mua Quà Tết',
      targetAmount: 5000000.0,
      targetDate: DateTime.now().add(const Duration(days: 60)),
    );

    // 3. Deposit money into goal
    await repository.depositToGoal(
      goalId: goal.id,
      goalName: goal.name,
      depositAmount: 2000000.0,
      walletId: 'w10',
      idaccount: 1,
    );

    // 4. Verify Goal amount updated
    final updatedGoal = await repository.getGoalById(goal.id);
    expect(updatedGoal?.currentAmount, 2000000.0);

    // 5. Verify Wallet balance deducted
    final wallet = await db.walletDao.getById('w10');
    expect(wallet?.balance, 8000000.0);

    // 6. Verify Pending Goal & Transaction status for SyncEngine
    final pendingGoals = await db.goalDao.getPending();
    expect(pendingGoals.isNotEmpty, true);

    final pendingTxs = await db.transactionDao.getPending();
    expect(pendingTxs.isNotEmpty, true);
  });
}
