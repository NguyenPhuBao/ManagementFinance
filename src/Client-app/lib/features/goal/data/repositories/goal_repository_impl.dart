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
    String? walletId,
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
      walletId: walletId,
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

      // Đánh dấu hoàn thành nếu đã đạt mục tiêu
      if (newGoalAmount >= goal.targetAmount && db != null) {
        await (db!.update(db!.goals)..where((t) => t.id.equals(goalId))).write(
          const GoalsCompanion(
            isCompleted: Value(true),
            syncStatus: Value('pending'),
          ),
        );
      }
    }

    var effectiveTargetWalletId = (targetWalletId != null && targetWalletId.isNotEmpty)
        ? targetWalletId
        : goal?.walletId;

    if (db != null) {
      final now = DateTime.now();

      // Fallback: If effectiveTargetWalletId is null, find target wallet and link to goal
      if (effectiveTargetWalletId == null || effectiveTargetWalletId.isEmpty) {
        // Bỏ nhánh `getAllNonDeleted()`: nó không lọc tài khoản, nên khi tài
        // khoản hiện tại chưa có ví, mục tiêu sẽ bị nối vào ví của tài khoản
        // khác từng đăng nhập trên cùng máy.
        final allWallets = await db!.walletDao.getAll(idaccount);
        final otherWallets = allWallets.where((w) => w.id != walletId).toList();
        if (otherWallets.isNotEmpty) {
          final foundWallet = otherWallets.firstWhere(
            (w) => (w.type == 'investment' || w.type == 'bank'),
            orElse: () => otherWallets.first,
          );
          effectiveTargetWalletId = foundWallet.id;

          // Permanently link this walletId to the goal in SQLite
          await (db!.update(db!.goals)..where((t) => t.id.equals(goalId))).write(
            GoalsCompanion(walletId: Value(effectiveTargetWalletId)),
          );
        }
      }

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

      // 2. Add to Target / Savings Wallet
      if (effectiveTargetWalletId != null && effectiveTargetWalletId.isNotEmpty) {
        final targetWallet = await db!.walletDao.getById(effectiveTargetWalletId);
        if (targetWallet != null) {
          final newTargetBalance = targetWallet.balance + depositAmount;
          await db!.walletDao.updateBalance(effectiveTargetWalletId, newTargetBalance);
        }

        if (effectiveTargetWalletId != walletId) {
          await db!.transactionDao.insert(
            TransactionsCompanion.insert(
              id: const Uuid().v4(),
              idaccount: idaccount,
              walletId: effectiveTargetWalletId,
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
