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
    required int idaccount,
  }) async {
    final goal = await localDataSource.getGoalById(goalId);
    if (goal != null) {
      final newGoalAmount = goal.currentAmount + depositAmount;
      await localDataSource.updateGoalAmount(goalId, newGoalAmount);
    }

    if (db != null) {
      final wallet = await db!.walletDao.getById(walletId);
      if (wallet != null) {
        final newBalance = wallet.balance - depositAmount;
        await db!.walletDao.updateBalance(walletId, newBalance);
      }

      final transactionId = const Uuid().v4();
      final now = DateTime.now();
      await db!.transactionDao.insert(
        TransactionsCompanion.insert(
          id: transactionId,
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
