import '../models/goal_entity.dart';

abstract class GoalRepository {
  Future<List<GoalEntity>> getGoals(int idaccount);
  Stream<List<GoalEntity>> watchGoals(int idaccount);
  Future<GoalEntity?> getGoalById(String id);
  Future<GoalEntity> addGoal({
    required int idaccount,
    required String name,
    required double targetAmount,
    required DateTime targetDate,
    String? icon,
    String? colour,
    String? note,
  });
  Future<void> updateAmount({
    required String id,
    required double newAmount,
  });
  Future<void> depositToGoal({
    required String goalId,
    required String goalName,
    required double depositAmount,
    required String walletId,
    required int idaccount,
  });
  Stream<dynamic> watchGoalTransactions(int idaccount, String goalName);
  Future<void> deleteGoal(String id);
}
