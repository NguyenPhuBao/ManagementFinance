import '../../../../core/database/app_database.dart';
import '../models/goal_entity.dart';

abstract class GoalLocalDataSource {
  Future<List<GoalEntity>> getGoals(int idaccount);
  Stream<List<GoalEntity>> watchGoals(int idaccount);
  Future<void> addGoal(GoalEntity goal);
  Future<void> updateGoalAmount(String id, double newAmount);
  Future<void> deleteGoal(String id);
}

class GoalLocalDataSourceImpl implements GoalLocalDataSource {
  final AppDatabase db;

  GoalLocalDataSourceImpl({required this.db});

  @override
  Future<List<GoalEntity>> getGoals(int idaccount) async {
    final list = await db.goalDao.getAll(idaccount);
    return list.map((g) => GoalEntity.fromDrift(g)).toList();
  }

  @override
  Stream<List<GoalEntity>> watchGoals(int idaccount) {
    return db.goalDao.watchAll(idaccount).map(
          (list) => list.map((g) => GoalEntity.fromDrift(g)).toList(),
        );
  }

  @override
  Future<void> addGoal(GoalEntity goal) async {
    await db.goalDao.insert(goal.toCompanion());
  }

  @override
  Future<void> updateGoalAmount(String id, double newAmount) async {
    await db.goalDao.updateAmount(id, newAmount);
  }

  @override
  Future<void> deleteGoal(String id) async {
    await db.goalDao.softDelete(id);
  }
}
