import 'package:uuid/uuid.dart';
import '../../../../core/sync/sync_engine.dart';
import '../datasources/goal_local_data_source.dart';
import '../models/goal_entity.dart';
import 'goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final GoalLocalDataSource localDataSource;
  final SyncEngine syncEngine;

  GoalRepositoryImpl({
    required this.localDataSource,
    required this.syncEngine,
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
  Future<GoalEntity> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String icon = 'flag',
    String colour = '#4CAF50',
    String note = '',
  }) async {
    final goal = GoalEntity(
      id: const Uuid().v4(),
      idaccount: idaccount,
      name: name,
      targetAmount: targetAmount,
      currentAmount: 0.0,
      targetDate: targetDate,
      icon: icon,
      colour: colour,
      note: note,
      syncStatus: 'pending',
      updatedAt: DateTime.now(),
    );

    await localDataSource.insertGoal(goal);
    syncEngine.scheduleSync();
    return goal;
  }

  @override
  Future<void> updateAmount({required String id, required double newAmount}) async {
    await localDataSource.updateGoalAmount(id, newAmount);
    syncEngine.scheduleSync();
  }

  @override
  Future<void> deleteGoal(String id) async {
    await localDataSource.deleteGoal(id);
    syncEngine.scheduleSync();
  }
}
