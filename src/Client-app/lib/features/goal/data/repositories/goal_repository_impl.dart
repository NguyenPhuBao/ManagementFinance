import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_engine.dart';
import '../datasources/goal_local_data_source.dart';
import '../models/goal_entity.dart';
import 'goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final GoalLocalDataSource localDataSource;
  final AppDatabase? db;
  final SyncEngine? syncEngine;

  GoalRepositoryImpl({
    required this.localDataSource,
    this.db,
    this.syncEngine,
  });

  @override
  Future<List<GoalEntity>> getGoals(int idaccount) {
    return localDataSource.getGoals(idaccount);
  }

  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) {
    return localDataSource.watchGoals(idaccount);
  }

  @override
  Future<GoalEntity?> getGoalById(String id) {
    return localDataSource.getGoalById(id);
  }

  @override
  Future<GoalEntity> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String? icon,
    String? colour,
    String? note,
  }) async {
    final goal = GoalEntity(
      id: const Uuid().v4(),
      idaccount: idaccount,
      name: name,
      targetAmount: targetAmount,
      currentAmount: 0.0,
      targetDate: targetDate,
      icon: icon ?? 'flag',
      colour: colour ?? '#4CAF50',
      note: note ?? '',
      isCompleted: false,
      isDeleted: false,
      syncStatus: 'pending',
      updatedAt: DateTime.now(),
    );

    await localDataSource.addGoal(goal);
    syncEngine?.scheduleSync();
    return goal;
  }

  @override
  Future<void> updateAmount({
    required String id,
    required double newAmount,
  }) async {
    await localDataSource.updateGoalAmount(id, newAmount);
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> depositToGoal({
    required String goalId,
    required String goalName,
    required double depositAmount,
    required String walletId,
    String? targetWalletId,
    required int idaccount,
  }) async {
    final goal = await localDataSource.getGoalById(goalId);
    if (goal != null) {
      final newGoalAmount = goal.currentAmount + depositAmount;
      await localDataSource.updateGoalAmount(goalId, newGoalAmount);
    }

    if (db != null) {
      final now = DateTime.now();

      // 1. Deduct from Source Wallet
      final sourceWallet = await db!.walletDao.getById(walletId);
      if (sourceWallet != null) {
        final newBalance = sourceWallet.balance - depositAmount;
        await db!.walletDao.updateBalance(walletId, newBalance);
      }

      await db!.transactionDao.insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          idaccount: idaccount,
          walletId: walletId,
          amount: depositAmount,
          type: 'chi',
          note: Value('Tích lũy mục tiêu: $goalName'),
          date: now,
          syncStatus: const Value('pending'),
          updatedAt: now,
        ),
      );

      // 2. Add to Target / Savings Wallet (if selected & different from source wallet)
      if (targetWalletId != null && targetWalletId.isNotEmpty && targetWalletId != walletId) {
        final targetWallet = await db!.walletDao.getById(targetWalletId);
        if (targetWallet != null) {
          final newTargetBalance = targetWallet.balance + depositAmount;
          await db!.walletDao.updateBalance(targetWalletId, newTargetBalance);
        }

        await db!.transactionDao.insert(
          TransactionsCompanion.insert(
            id: const Uuid().v4(),
            idaccount: idaccount,
            walletId: targetWalletId,
            amount: depositAmount,
            type: 'thu',
            note: Value('Tích lũy nhận từ ${sourceWallet?.name ?? 'Ví nguồn'}: $goalName'),
            date: now,
            syncStatus: const Value('pending'),
            updatedAt: now,
          ),
        );
      }
    }

    syncEngine?.scheduleSync();
  }

  @override
  Stream<dynamic> watchGoalTransactions(int idaccount, String goalName) {
    if (db != null) {
      return db!.transactionDao.watchByNotePattern(idaccount, 'Tích lũy mục tiêu: $goalName');
    }
    return Stream.value([]);
  }

  @override
  Future<void> deleteGoal(String id) async {
    await localDataSource.deleteGoal(id);
    syncEngine?.scheduleSync();
  }
}
